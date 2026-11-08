import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/settings/folder_access.dart';
import 'package:todo_sdd/features/todo/android_todo_writer.dart';
import 'package:todo_sdd/features/todo/folder_reader.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_create_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('todo_sdd/folder_access');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('空白タイトルを拒否して必須であることを示す', () {
    expect(validateTodoTitle(' \t\n'), contains('タイトル'));
  });

  test('パス区切り・単独ドット・ASCII制御文字を拒否しWindows名は事前拒否しない', () {
    for (final title in [
      '.',
      '..',
      'a/b',
      r'a\b',
      'a\u0000b',
      'a\u0001b',
      'a\u001fb',
      'a\u007fb',
    ]) {
      expect(validateTodoTitle(title), isNotNull, reason: title);
    }

    expect(validateTodoTitle('CON'), isNull);
    expect(validateTodoTitle('a:b?c'), isNull);
  });

  test('空本文にはTodoタグ行だけを作る', () {
    expect(buildTodoContent(''), '#todo\n');
  });

  test('Todoタグをコードフェンスより前に置き本文を保持する', () {
    const body = '```dart\nprint("todo");\n```\n';
    expect(buildTodoContent(body), '#todo\n$body');
  });

  test('先頭の独立Todoタグを重複させず入力を保持する', () {
    const body = '#todo\r\n本文\n';
    expect(buildTodoContent(body), body);
  });

  test('保存先直下の同名Markdownを拒否して書き込まない', () async {
    final uri = Uri.parse('content://provider/tree/example');
    var writeCalled = false;
    final repository = TodoCreateRepository(
      currentFolder: () async => FolderAvailable(uri),
      readFolder: (_) async => FolderReadSuccess([
        ReadNote(NoteId('task.md'), '既存の内容'),
      ], const []),
      writeMarkdown: (_, _, _) async {
        writeCalled = true;
        return 'task.md';
      },
    );

    final outcome = await repository.create(
      const TodoDraft(title: 'task', content: 'new'),
    );

    expect(outcome, isA<TodoAlreadyExists>());
    expect(writeCalled, isFalse);
  });

  test('サブフォルダーの同名Markdownを競合にせず直下に作成する', () async {
    final uri = Uri.parse('content://provider/tree/example');
    String? writtenPath;
    final repository = TodoCreateRepository(
      currentFolder: () async => FolderAvailable(uri),
      readFolder: (_) async => FolderReadSuccess([
        ReadNote(NoteId('sub/task.md'), '既存の内容'),
      ], const []),
      writeMarkdown: (_, fileName, _) async {
        writtenPath = fileName;
        return fileName;
      },
    );

    final outcome = await repository.create(
      const TodoDraft(title: 'task', content: 'new'),
    );

    expect(outcome, isA<TodoCreateSuccess>());
    expect((outcome as TodoCreateSuccess).relativePath, 'task.md');
    expect(writtenPath, 'task.md');
  });

  test('保存先の権限拒否をフォルダー未設定と区別する', () async {
    final repository = TodoCreateRepository(
      currentFolder: () async => const FolderUnavailable(
        FolderUnavailableReason.permissionDenied,
      ),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, _, _) async => 'task.md',
    );

    final outcome = await repository.create(
      const TodoDraft(title: 'task', content: ''),
    );

    expect(outcome, isA<TodoPermissionDenied>());
  });

  test('未設定の保存先を利用不可として返す', () async {
    final repository = TodoCreateRepository(
      currentFolder: () async => const FolderUnavailable(
        FolderUnavailableReason.notConfigured,
      ),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, _, _) async => 'task.md',
    );

    final outcome = await repository.create(
      const TodoDraft(title: 'task', content: ''),
    );

    expect(
      outcome,
      isA<TodoFolderUnavailable>().having(
        (failure) => failure.reason,
        'reason',
        FolderUnavailableReason.notConfigured,
      ),
    );
  });

  test('書込失敗を型付き結果として理由付きで返す', () async {
    final uri = Uri.parse('content://provider/tree/example');
    final repository = TodoCreateRepository(
      currentFolder: () async => FolderAvailable(uri),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, _, _) async => throw const TodoWriterException(
        TodoWriterErrorCode.writeFailed,
        '保存先が書き込みを拒否しました',
      ),
    );

    final outcome = await repository.create(
      const TodoDraft(title: 'task', content: ''),
    );

    expect(
      outcome,
      isA<TodoWriteFailure>().having(
        (failure) => failure.message,
        'message',
        contains('書き込みを拒否'),
      ),
    );
  });

  test('Android書込の権限エラーを型付きエラーに変換する', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'createMarkdown');
      throw PlatformException(
        code: 'permission_denied',
        message: '永続書込権限がありません',
      );
    });

    await expectLater(
      AndroidTodoWriter().createMarkdown(
        Uri.parse('content://provider/tree/example'),
        'task.md',
        '#todo\n',
      ),
      throwsA(
        isA<TodoWriterException>().having(
          (error) => error.code,
          'code',
          TodoWriterErrorCode.permissionDenied,
        ),
      ),
    );
  });

  test('要求名と異なる作成パスを成功扱いせず残存パスにする', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'createMarkdown');
      return <String, Object?>{'path': 'task (1).md'};
    });

    await expectLater(
      AndroidTodoWriter().createMarkdown(
        Uri.parse('content://provider/tree/example'),
        'task.md',
        '#todo\n',
      ),
      throwsA(
        isA<TodoWriterException>()
            .having(
              (error) => error.code,
              'code',
              TodoWriterErrorCode.writeFailed,
            )
            .having(
              (error) => error.residualPath,
              'residualPath',
              'task (1).md',
            ),
      ),
    );
  });

  test('保存先の読込失敗を理由付きで返す', () async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadError(
        const FileSystemException('保存先にアクセスできません'),
      ),
      writeMarkdown: (_, _, _) async => 'task.md',
    );

    final outcome = await repository.create(
      const TodoDraft(title: 'task', content: ''),
    );

    expect(
      outcome,
      isA<TodoFolderUnavailable>().having(
        (failure) => failure.message,
        'message',
        contains('保存先にアクセスできません'),
      ),
    );
  });

  test('候補として階層タグと同名Markdownを個別に返す', () async {
    final uri = Uri.parse('content://provider/tree/example');
    final repository = TodoCreateRepository(
      currentFolder: () async => FolderAvailable(uri),
      readFolder: (_) async => FolderReadSuccess([
        ReadNote(NoteId('root.md'), '#仕事/企画\n'),
        ReadNote(NoteId('sub/資料.md'), '#仕事/会議\n'),
        ReadNote(NoteId('other/資料.md'), '#参考\n'),
      ], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    final candidates = await repository.loadCandidates();

    expect(
      candidates.tags.map((candidate) => candidate.tag),
      containsAll(['仕事/企画', '仕事/会議', '参考']),
    );
    expect(
      candidates.notes.where((candidate) => candidate.title == '資料'),
      hasLength(2),
    );
    expect(
      candidates.notes.map((candidate) => candidate.noteId.relativePath),
      containsAll(['sub/資料.md', 'other/資料.md']),
    );
  });
}
