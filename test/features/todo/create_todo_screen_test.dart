import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:todo_sdd/features/settings/folder_access.dart';
import 'package:todo_sdd/features/todo/create_todo_screen.dart';
import 'package:todo_sdd/features/todo/folder_reader.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_create_repository.dart';
import 'package:todo_sdd/features/todo/todo_list.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';
import 'package:todo_sdd/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('todo_sdd/folder_access');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('一覧から作成画面を開き成功後に戻って一覧を再読込する', (tester) async {
    var loadCount = 0;
    final uri = Uri.parse('content://provider/tree/example');
    final repository = TodoCreateRepository(
      currentFolder: () async => FolderAvailable(uri),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TodoListScreen(
            loadTodos: () async {
              loadCount++;
              return const TodoLoadSuccess([], []);
            },
            onOpenDetails: (_) {},
            onOpenEdit: (_) {},
            onCreate: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CreateTodoScreen(repository: repository),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Todoを作成'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTodoScreen), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'created');
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTodoScreen), findsNothing);
    expect(loadCount, 2);
  });

  testWidgets('アプリの一覧から作成ボタンでTodo作成画面を開く', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return 'content://provider/tree/example';
        case 'hasAccess':
          return true;
        case 'readFolder':
          return <String, Object>{'notes': <Object>[], 'failures': <Object>[]};
        default:
          throw MissingPluginException();
      }
    });

    await tester.pumpWidget(const app.MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Todoを作成'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTodoScreen), findsOneWidget);
  });

  testWidgets('書込失敗の理由を表示し入力を保持して再試行できる', (tester) async {
    final uri = Uri.parse('content://provider/tree/example');
    final repository = TodoCreateRepository(
      currentFolder: () async => FolderAvailable(uri),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, _, _) async => throw const TodoWriterException(
        TodoWriterErrorCode.writeFailed,
        '保存先が書き込みを拒否しました',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'task');
    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '本文を保持する',
    );
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.textContaining('保存先が書き込みを拒否しました'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-title')))
          .controller!
          .text,
      'task',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '本文を保持する',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('保存中の予期しない例外を表示し入力を保持して再試行できる', (tester) async {
    var currentFolderCalls = 0;
    final uri = Uri.parse('content://provider/tree/example');
    final repository = TodoCreateRepository(
      currentFolder: () async {
        currentFolderCalls++;
        if (currentFolderCalls == 2) {
          throw const FormatException('malformed folder response');
        }
        return FolderAvailable(uri);
      },
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'task');
    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '本文を保持する',
    );
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('malformed folder response'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-title')))
          .controller!
          .text,
      'task',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '本文を保持する',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('書込権限がないときに再選択を提示しキャンセル後も入力を保持する', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          const FolderUnavailable(FolderUnavailableReason.permissionDenied),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CreateTodoScreen(
          repository: repository,
          onReselectFolder: () async {
            throw PlatformException(
              code: 'selection_cancelled',
              message: 'フォルダー選択がキャンセルされました',
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'task');
    await tester.enterText(find.byKey(const ValueKey('todo-content')), '本文');
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.text('保存先を再選択'), findsOneWidget);
    await tester.tap(find.text('保存先を再選択'));
    await tester.pumpAndSettle();

    expect(find.textContaining('キャンセル'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-title')))
          .controller!
          .text,
      'task',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '本文',
    );
  });

  testWidgets('保存先再選択後にタグ候補を新しいフォルダーから読み込む', (tester) async {
    final oldUri = Uri.parse('content://provider/tree/old');
    final newUri = Uri.parse('content://provider/tree/new');
    var selectedUri = oldUri;
    var reselectRequired = false;
    final repository = TodoCreateRepository(
      currentFolder: () async => reselectRequired
          ? const FolderUnavailable(FolderUnavailableReason.permissionDenied)
          : FolderAvailable(selectedUri),
      readFolder: (folder) async => FolderReadSuccess([
        if (folder == oldUri)
          ReadNote(NoteId('old-tags.md'), '#old\n')
        else
          ReadNote(NoteId('new-tags.md'), '#new\n'),
      ], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CreateTodoScreen(
          repository: repository,
          onReselectFolder: () async {
            selectedUri = newUri;
            reselectRequired = false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'task');
    final contentField = find.byKey(const ValueKey('todo-content'));
    await tester.enterText(contentField, '#old');
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('#old')),
      findsOneWidget,
    );

    reselectRequired = true;
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存先を再選択'));
    await tester.pumpAndSettle();

    await tester.enterText(contentField, '#new');
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('#new')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('#old')),
      findsNothing,
    );
  });

  testWidgets('後始末に失敗した不完全ファイルの場所と削除方法を案内する', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, _, _) async => throw const TodoWriterException(
        TodoWriterErrorCode.writeFailed,
        '書き込みに失敗しました',
        residualPath: 'task.md',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'task');
    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.textContaining('task.md'), findsOneWidget);
    expect(find.textContaining('不完全'), findsOneWidget);
    expect(find.textContaining('手動で削除'), findsOneWidget);
    expect(find.byType(CreateTodoScreen), findsOneWidget);
  });

  testWidgets('空本文でもMarkdownプレビューを表示して作成操作を利用できる', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'empty');

    expect(find.text('プレビュー'), findsOneWidget);
    await tester.tap(find.text('プレビュー'));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('プレビューと入力を往復してタイトル・本文を保持し本文は編集不可にする', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.enterText(find.byKey(const ValueKey('todo-title')), 'plan');
    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '## 見出し\n本文です',
    );
    await tester.tap(find.text('プレビュー'));
    await tester.pumpAndSettle();

    expect(find.text('本文です'), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-content')), findsNothing);
    await tester.tap(find.text('入力'));
    await tester.pumpAndSettle();

    expect(find.text('本文です'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-title')))
          .controller!
          .text,
      'plan',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '## 見出し\n本文です',
    );
  });

  testWidgets('タグ候補を部分一致で絞り選択時に入力トークンを置き換える', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadSuccess([
        ReadNote(NoteId('tags.md'), '#仕事/企画\n#仕事/会議\n'),
      ], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('todo-content')), '#企画');
    await tester.pumpAndSettle();

    expect(find.text('#仕事/企画'), findsOneWidget);
    expect(find.text('#仕事/会議'), findsNothing);
    await tester.tap(find.text('#仕事/企画'));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '#仕事/企画',
    );

    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '本文 #企画',
    );
    await tester.pumpAndSettle();
    expect(find.text('#仕事/企画'), findsOneWidget);
    await tester.tap(find.text('#仕事/企画'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '本文 #仕事/企画',
    );
  });

  testWidgets('候補がないタグはEnterで確定し改行を追加しない', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadSuccess(const [], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '#new-tag',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final content = tester
        .widget<TextField>(find.byKey(const ValueKey('todo-content')))
        .controller!
        .text;
    expect(content, '#new-tag');
    expect(find.text('一致するタグはありません。Enterで入力中のタグを確定できます。'), findsNothing);
  });

  testWidgets('複数行にまたがるMarkdownコードスパン内ではタグ候補を表示しない', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async =>
          FolderReadSuccess([ReadNote(NoteId('tags.md'), '#仕事\n')], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '`code\n#仕事 x`',
    );
    tester
        .widget<TextField>(find.byKey(const ValueKey('todo-content')))
        .controller!
        .selection = const TextSelection.collapsed(
      offset: 9,
    );
    await tester.pumpAndSettle();

    expect(find.text('#仕事'), findsNothing);
  });

  testWidgets('エスケープまたは非空白文字直後の#では候補を表示しない', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async =>
          FolderReadSuccess([ReadNote(NoteId('tags.md'), '#仕事\n')], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    for (final content in [r'\#仕事', '文字#仕事']) {
      await tester.enterText(
        find.byKey(const ValueKey('todo-content')),
        content,
      );
      await tester.pumpAndSettle();
      expect(find.text('#仕事'), findsNothing, reason: content);
    }
  });

  testWidgets('カーソル位置にかかわらずタグトークン全体を置換し周囲を保つ', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadSuccess([
        ReadNote(NoteId('tags.md'), '#仕事/企画/old\n'),
      ], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '前 #仕事/企画 後',
    );
    tester
        .widget<TextField>(find.byKey(const ValueKey('todo-content')))
        .controller!
        .selection = const TextSelection.collapsed(
      offset: 5,
    );
    await tester.pumpAndSettle();

    expect(find.text('#仕事/企画/old'), findsOneWidget);
    await tester.tap(find.text('#仕事/企画/old'));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '前 #仕事/企画/old 後',
    );
  });

  testWidgets('Wikiリンク候補を部分一致で表示し選択時にリンクを挿入する', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async => FolderReadSuccess([
        ReadNote(NoteId('sub/設計メモ.md'), '#設計\n'),
      ], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-content')),
      '参照 [[設計',
    );
    await tester.pumpAndSettle();

    expect(find.text('設計メモ'), findsOneWidget);
    await tester.tap(find.text('設計メモ'));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('todo-content')))
          .controller!
          .text,
      '参照 [[設計メモ]]',
    );
  });

  testWidgets('エスケープまたはMarkdownコード内のWiki記号では候補を表示しない', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async =>
          FolderReadSuccess([ReadNote(NoteId('設計メモ.md'), '')], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    final contentField = find.byKey(const ValueKey('todo-content'));
    for (final (content, cursor) in [
      (r'\[[設計', 5),
      ('`[[設計]] x`', 7),
      ('```\n[[設計]] x\n```', 10),
    ]) {
      await tester.enterText(contentField, content);
      tester.widget<TextField>(contentField).controller!.selection =
          TextSelection.collapsed(offset: cursor);
      await tester.pumpAndSettle();
      expect(find.text('設計メモ'), findsNothing, reason: content);
    }
  });

  testWidgets('カーソル位置にかかわらずWikiリンク全体を置換し周囲を保つ', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async =>
          FolderReadSuccess([ReadNote(NoteId('設計メモ.md'), '')], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    final contentField = find.byKey(const ValueKey('todo-content'));
    await tester.enterText(contentField, '前 [[設計]] 後');
    tester.widget<TextField>(contentField).controller!.selection =
        const TextSelection.collapsed(offset: 5);
    await tester.pumpAndSettle();

    expect(find.text('設計メモ'), findsOneWidget);
    await tester.tap(find.text('設計メモ'));
    await tester.pump();

    expect(
      tester.widget<TextField>(contentField).controller!.text,
      '前 [[設計メモ]] 後',
    );
  });

  testWidgets('候補がないWikiリンクでEnterを押してもリンクを追加しない', (tester) async {
    final repository = TodoCreateRepository(
      currentFolder: () async =>
          FolderAvailable(Uri.parse('content://provider/tree/example')),
      readFolder: (_) async =>
          FolderReadSuccess([ReadNote(NoteId('設計メモ.md'), '')], const []),
      writeMarkdown: (_, fileName, _) async => fileName,
    );

    await tester.pumpWidget(
      MaterialApp(home: CreateTodoScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    final contentField = find.byKey(const ValueKey('todo-content'));
    await tester.enterText(contentField, '[[存在しないノート');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      tester.widget<TextField>(contentField).controller!.text,
      isNot(contains(']]')),
    );
  });
}
