import '../settings/folder_access.dart';
import 'folder_reader.dart';
import 'markdown_parser.dart';
import 'note.dart';

String? validateTodoTitle(String title) {
  if (title.trim().isEmpty) return 'タイトルは必須です。';
  if (title == '.' || title == '..') {
    return 'タイトルに「$title」は使用できません。';
  }
  if (title.contains('/') || title.contains(r'\')) {
    return 'タイトルにパス区切り文字「/」「\\」は使用できません。';
  }
  for (final codeUnit in title.codeUnits) {
    if (codeUnit <= 0x1f || codeUnit == 0x7f) {
      final codePoint = codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase();
      return 'タイトルに制御文字 U+$codePoint は使用できません。';
    }
  }
  return null;
}

String buildTodoContent(String content) {
  if (RegExp(r'^#todo(?:\r\n|\n|\r|$)').hasMatch(content)) return content;
  return '#todo\n$content';
}

class TodoDraft {
  const TodoDraft({required this.title, required this.content});

  final String title;
  final String content;
}

sealed class TodoCreateOutcome {
  const TodoCreateOutcome();
}

class TodoCreateSuccess extends TodoCreateOutcome {
  const TodoCreateSuccess(this.relativePath);

  final String relativePath;
}

class TodoInvalidTitle extends TodoCreateOutcome {
  const TodoInvalidTitle(this.message);

  final String message;
}

class TodoAlreadyExists extends TodoCreateOutcome {
  const TodoAlreadyExists(this.fileName);

  final String fileName;
}

class TodoFolderUnavailable extends TodoCreateOutcome {
  const TodoFolderUnavailable(this.reason, {this.message});

  final FolderUnavailableReason reason;
  final String? message;
}

class TodoPermissionDenied extends TodoCreateOutcome {
  const TodoPermissionDenied(this.message);

  final String message;
}

class TodoWriteFailure extends TodoCreateOutcome {
  const TodoWriteFailure(this.message, {this.residualPath});

  final String message;
  final String? residualPath;
}

enum TodoWriterErrorCode {
  permissionDenied,
  folderUnavailable,
  alreadyExists,
  invalidName,
  unsupportedProvider,
  writeFailed,
}

class TodoWriterException implements Exception {
  const TodoWriterException(
    this.code,
    this.message, {
    this.residualPath,
  });

  final TodoWriterErrorCode code;
  final String message;
  final String? residualPath;
}

class RegisteredTagCandidate {
  const RegisteredTagCandidate(this.tag);

  final String tag;
}

class ExistingMarkdownCandidate {
  const ExistingMarkdownCandidate({required this.noteId, required this.title});

  final NoteId noteId;
  final String title;
}

class TodoCreateCandidates {
  const TodoCreateCandidates({
    required this.tags,
    required this.notes,
    this.issues = const [],
  });

  final List<RegisteredTagCandidate> tags;
  final List<ExistingMarkdownCandidate> notes;
  final List<String> issues;
}

typedef TodoMarkdownWriter =
    Future<String> Function(Uri folder, String fileName, String content);

class TodoCreateRepository {
  const TodoCreateRepository({
    required this.currentFolder,
    required this.readFolder,
    required this.writeMarkdown,
  });

  final Future<FolderAccess> Function() currentFolder;
  final Future<FolderReadResult> Function(Uri folder) readFolder;
  final TodoMarkdownWriter writeMarkdown;

  Future<TodoCreateOutcome> create(TodoDraft draft) async {
    final titleError = validateTodoTitle(draft.title);
    if (titleError != null) return TodoInvalidTitle(titleError);

    final access = await currentFolder();
    late final Uri folderUri;
    switch (access) {
      case FolderAvailable(:final uri):
        folderUri = uri;
      case FolderUnavailable(
        reason: FolderUnavailableReason.permissionDenied,
      ):
        return const TodoPermissionDenied('保存先の書込権限がありません。');
      case FolderUnavailable(:final reason):
        return TodoFolderUnavailable(reason);
    }

    final fileName = '${draft.title}.md';
    final folderResult = await readFolder(folderUri);
    if (folderResult is FolderReadError) {
      return TodoFolderUnavailable(
        FolderUnavailableReason.expired,
        message: folderResult.cause.message,
      );
    }
    final readSuccess = folderResult as FolderReadSuccess;
    if (readSuccess.notes.any(
      (note) => note.id.relativePath == fileName,
    )) {
      return TodoAlreadyExists(fileName);
    }

    try {
      final relativePath = await writeMarkdown(
        folderUri,
        fileName,
        buildTodoContent(draft.content),
      );
      return TodoCreateSuccess(relativePath);
    } on TodoWriterException catch (error) {
      return switch (error.code) {
        TodoWriterErrorCode.permissionDenied =>
          TodoPermissionDenied(error.message),
        TodoWriterErrorCode.folderUnavailable ||
        TodoWriterErrorCode.unsupportedProvider => TodoFolderUnavailable(
          FolderUnavailableReason.expired,
          message: error.message,
        ),
        TodoWriterErrorCode.alreadyExists => TodoAlreadyExists(fileName),
        TodoWriterErrorCode.invalidName ||
        TodoWriterErrorCode.writeFailed => TodoWriteFailure(
          error.message,
          residualPath: error.residualPath,
        ),
      };
    }
  }

  Future<TodoCreateCandidates> loadCandidates() async {
    final access = await currentFolder();
    late final Uri folderUri;
    switch (access) {
      case FolderAvailable(:final uri):
        folderUri = uri;
      case FolderUnavailable(:final reason):
        return TodoCreateCandidates(
          tags: const [],
          notes: const [],
          issues: [
            switch (reason) {
              FolderUnavailableReason.notConfigured =>
                '保存先フォルダーが設定されていません。',
              FolderUnavailableReason.expired =>
                '保存先フォルダーへのアクセス権が失効しています。',
              FolderUnavailableReason.permissionDenied =>
                '保存先フォルダーのアクセス権がありません。',
            },
          ],
        );
    }

    final folderResult = await readFolder(folderUri);
    if (folderResult is FolderReadError) {
      return TodoCreateCandidates(
        tags: const [],
        notes: const [],
        issues: [folderResult.cause.message],
      );
    }

    final readSuccess = folderResult as FolderReadSuccess;
    final registeredTags = <String>{};
    final notes = <ExistingMarkdownCandidate>[];
    final issues = <String>[
      for (final failure in readSuccess.failures)
        '${failure.path}: ${failure.cause}',
    ];
    for (final readNote in readSuccess.notes) {
      final note = Note(id: readNote.id, content: readNote.content);
      notes.add(ExistingMarkdownCandidate(noteId: note.id, title: note.title));

      final parsed = parseMarkdownNote(note);
      switch (parsed) {
        case MarkdownParseSuccess(:final tags):
          registeredTags.addAll(tags);
        case MarkdownParseFailure(:final reason):
          issues.add('${readNote.id.relativePath}: $reason');
      }
    }
    return TodoCreateCandidates(
      tags: List.unmodifiable(registeredTags.map(RegisteredTagCandidate.new)),
      notes: List.unmodifiable(notes),
      issues: List.unmodifiable(issues),
    );
  }
}
