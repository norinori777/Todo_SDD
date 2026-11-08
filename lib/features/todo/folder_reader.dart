import 'dart:io';

import 'package:path/path.dart' as path;

import 'note.dart';
import 'secure_file_reader.dart';

sealed class FolderReadResult {
  const FolderReadResult();
}

class FolderReadSuccess extends FolderReadResult {
  const FolderReadSuccess(this.notes, this.failures);

  final List<ReadNote> notes;
  final List<FolderReadFailure> failures;
}

class FolderReadError extends FolderReadResult {
  const FolderReadError(this.cause);

  final FileSystemException cause;
}

class ReadNote {
  const ReadNote(this.id, this.content);

  final NoteId id;
  final String content;
}

class FolderReadFailure {
  const FolderReadFailure(this.path, this.cause);

  final String path;
  final Object cause;
}

Future<FolderReadResult> readFolder(Directory root) async {
  final SecureFileReader reader;
  try {
    reader = SecureFileReader.open(root);
  } on FileSystemException catch (error) {
    return FolderReadError(error);
  }
  try {
    return await _readFolder(root, reader);
  } finally {
    reader.close();
  }
}

Future<FolderReadResult> _readFolder(
  Directory root,
  SecureFileReader reader,
) async {
  final _Discovery discovery;
  try {
    discovery = await _discover(root, reader);
  } on FileSystemException catch (error) {
    return FolderReadError(error);
  }
  final notes = <ReadNote>[];
  final failures = discovery.failures;
  for (final id in discovery.ids) {
    try {
      notes.add(ReadNote(id, reader.read(id.relativePath)));
    } on FileSystemException catch (error) {
      failures.add(FolderReadFailure(id.relativePath, error));
    } on FormatException catch (error) {
      failures.add(FolderReadFailure(id.relativePath, error));
    }
  }
  return FolderReadSuccess(notes, failures);
}

Future<List<NoteId>> listMarkdown(Directory root) async {
  final reader = SecureFileReader.open(root);
  try {
    final discovery = await _discover(root, reader);
    if (discovery.failures.isNotEmpty) {
      throw discovery.failures.first.cause;
    }
    return discovery.ids;
  } finally {
    reader.close();
  }
}

class _Discovery {
  final ids = <NoteId>[];
  final failures = <FolderReadFailure>[];
}

Future<_Discovery> _discover(Directory root, SecureFileReader reader) async {
  final discovery = _Discovery();

  String relativePath(String entry) =>
      path.posix.joinAll(path.split(path.relative(entry, from: root.path)));

  Future<void> visit(Directory directory, {required bool isRoot}) async {
    int? handle;
    try {
      if (!isRoot) {
        handle = reader.openDirectory(relativePath(directory.path));
      }
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is Directory) {
          await visit(entity, isRoot: false);
        } else if (entity is File &&
            path.extension(entity.path).toLowerCase() == '.md') {
          final relative = relativePath(entity.path);
          try {
            discovery.ids.add(NoteId(relative));
          } on ArgumentError catch (error) {
            discovery.failures.add(FolderReadFailure(relative, error));
          }
        }
      }
    } on FileSystemException catch (error) {
      if (isRoot) rethrow;
      discovery.failures.add(
        FolderReadFailure(relativePath(directory.path), error),
      );
    } finally {
      if (handle != null) {
        reader.closeDirectory(handle);
      }
    }
  }

  await visit(root, isRoot: true);
  return discovery;
}
