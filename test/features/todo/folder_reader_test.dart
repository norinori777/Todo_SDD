import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:todo_sdd/features/todo/folder_reader.dart';

class FakeDirectory extends Fake implements Directory {
  FakeDirectory(this.path, this.entries);

  @override
  final String path;
  final Stream<FileSystemEntity> Function() entries;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => entries();
}

class FakeFile extends Fake implements File {
  FakeFile(this.path);

  @override
  final String path;
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('todo_sdd_reader_');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('サブフォルダーのMarkdownを列挙する', () async {
    final subdir = await Directory(path.join(root.path, 'sub')).create();
    await File(path.join(subdir.path, 'task.md')).writeAsString('#todo');

    final notes = await listMarkdown(root);

    expect(notes.map((note) => note.relativePath), ['sub/task.md']);
  });

  test('Markdown以外を列挙しない', () async {
    await File(path.join(root.path, 'task.txt')).writeAsString('#todo');
    await File(path.join(root.path, 'task.md')).writeAsString('#todo');

    final notes = await listMarkdown(root);

    expect(notes.map((note) => note.relativePath), ['task.md']);
  });

  test('ルート外へのシンボリックリンクをたどらない', () async {
    final outside = await Directory.systemTemp.createTemp('todo_sdd_outside_');
    try {
      await File(path.join(outside.path, 'outside.md')).writeAsString('#todo');
      await Link(path.join(root.path, 'external')).create(outside.path);

      expect(await listMarkdown(root), isEmpty);
    } finally {
      await outside.delete(recursive: true);
    }
  });

  test('空フォルダーを失敗ではなく空の成功として返す', () async {
    final result = await readFolder(root);

    expect(result, isA<FolderReadSuccess>());
    final success = result as FolderReadSuccess;
    expect(success.notes, isEmpty);
    expect(success.failures, isEmpty);
  });

  test('正常なMarkdownの識別子と内容を返す', () async {
    await File(path.join(root.path, 'task.md')).writeAsString('#todo');

    final result = await readFolder(root) as FolderReadSuccess;

    expect(result.notes, hasLength(1));
    expect(result.notes.single.id.relativePath, 'task.md');
    expect(result.notes.single.content, '#todo');
    expect(result.failures, isEmpty);
  });

  test('複数バッファーにまたがるMarkdownの内容を保持する', () async {
    final content = '${'a' * 65536}${'b' * 4096}';
    await File(path.join(root.path, 'large.md')).writeAsString(content);

    final result = await readFolder(root) as FolderReadSuccess;

    expect(result.notes.single.content.length, content.length);
    expect(result.notes.single.content.startsWith('a' * 4096), isTrue);
    expect(result.notes.single.content.endsWith('b' * 4096), isTrue);
  });

  test('読めないMarkdownの対象と原因を保持して他のMarkdownを返す', () async {
    await File(path.join(root.path, 'good.md')).writeAsString('#todo');
    await File(path.join(root.path, 'invalid.md')).writeAsBytes([0xff]);

    final result = await readFolder(root) as FolderReadSuccess;

    expect(result.notes.map((note) => note.id.relativePath), ['good.md']);
    expect(result.failures, hasLength(1));
    expect(result.failures.single.path, 'invalid.md');
    expect(result.failures.single.cause, isA<FileSystemException>());
  });

  test('ルートを読めない場合は空結果ではなく全体失敗を返す', () async {
    final missing = Directory(path.join(root.path, 'missing'));

    final result = await readFolder(missing);

    expect(result, isA<FolderReadError>());
    expect((result as FolderReadError).cause.path, contains(missing.path));
  });

  test('ルートがシンボリックリンクの場合は安全を保証できず拒否する', () async {
    final link = Link(path.join(root.path, 'linked-root'));
    final target = await Directory(path.join(root.path, 'target')).create();
    await link.create(target.path);

    final result = await readFolder(Directory(link.path));

    expect(result, isA<FolderReadError>());
  });

  test('ルートの祖先を差し替えて指定外のフォルダーを探索できない', () async {
    final outside = await Directory.systemTemp.createTemp('todo_sdd_outside_');
    final parent = await Directory(path.join(root.path, 'parent')).create();
    final selected = await Directory(
      path.join(parent.path, 'selected'),
    ).create();
    final outsideSelected = await Directory(
      path.join(outside.path, 'selected'),
    ).create();
    await File(
      path.join(outsideSelected.path, 'external.md'),
    ).writeAsString('#todo');
    var parentMoved = false;
    final fakeRoot = FakeDirectory(selected.path, () async* {
      await parent.rename(path.join(root.path, 'moved'));
      parentMoved = true;
      await Link(parent.path).create(outside.path);
      yield* selected.list(followLinks: false);
    });

    try {
      final result = await readFolder(fakeRoot);
      expect(result, isA<FolderReadError>());
      expect(parentMoved, isFalse);
    } finally {
      await outside.delete(recursive: true);
    }
  });

  test('サブフォルダーの列挙失敗を部分失敗として保持する', () async {
    final good = File(path.join(root.path, 'good.md'));
    await good.writeAsString('#todo');
    final blockedPath = path.join(root.path, 'blocked');
    final blocked = FakeDirectory(
      blockedPath,
      () => Stream.error(FileSystemException('アクセス拒否', blockedPath)),
    );
    final fakeRoot = FakeDirectory(
      root.path,
      () => Stream.fromIterable([good, blocked]),
    );

    final result = await readFolder(fakeRoot) as FolderReadSuccess;

    expect(result.notes.map((note) => note.id.relativePath), ['good.md']);
    expect(result.failures, hasLength(1));
    expect(result.failures.single.path, 'blocked');
    expect(result.failures.single.cause, isA<FileSystemException>());
  });

  test('識別子にできないMarkdownを対象別失敗として通知する', () async {
    final invalid = FakeFile(path.join(root.path, 'C:invalid.md'));
    final fakeRoot = FakeDirectory(root.path, () => Stream.value(invalid));

    final result = await readFolder(fakeRoot) as FolderReadSuccess;

    expect(result.notes, isEmpty);
    expect(result.failures.single.path, 'C:invalid.md');
    expect(result.failures.single.cause, isA<ArgumentError>());
  });

  test('列挙後にルート外へのリンクに差し替えられたファイルを読まない', () async {
    final outside = await Directory.systemTemp.createTemp('todo_sdd_outside_');
    try {
      final external = File(path.join(outside.path, 'external.md'));
      await external.writeAsString('outside');
      final original = File(path.join(root.path, 'task.md'));
      await original.writeAsString('#todo');
      final fakeRoot = FakeDirectory(root.path, () async* {
        yield original;
        await original.delete();
        await Link(original.path).create(external.path);
      });

      final result = await readFolder(fakeRoot) as FolderReadSuccess;

      expect(result.notes, isEmpty);
      expect(result.failures.single.path, 'task.md');
    } finally {
      await outside.delete(recursive: true);
    }
  });

  test('列挙前にルート外へのリンクに差し替えられたサブフォルダーを探索しない', () async {
    final outside = await Directory.systemTemp.createTemp('todo_sdd_outside_');
    try {
      await File(path.join(outside.path, 'external.md')).writeAsString('#todo');
      final child = await Directory(path.join(root.path, 'sub')).create();
      final fakeRoot = FakeDirectory(root.path, () async* {
        await child.delete();
        await Link(child.path).create(outside.path);
        yield child;
      });

      final result = await readFolder(fakeRoot) as FolderReadSuccess;

      expect(result.notes, isEmpty);
      expect(result.failures.single.path, 'sub');
    } finally {
      await outside.delete(recursive: true);
    }
  });
}
