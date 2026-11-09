import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_sdd/main.dart' as app;

const _channel = MethodChannel('todo_sdd/folder_access');
const _folder = 'content://provider/tree/todo-detail-test';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  testWidgets('選択Todoの詳細を開いて戻ると検索条件を維持して一覧を再読込する', (tester) async {
    var readCount = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return _folder;
        case 'hasAccess':
          return true;
        case 'readFolder':
          readCount++;
          return {
            'notes': [
              {'path': 'selected.md', 'content': '#todo\n選択した本文\n'},
              {'path': 'other.md', 'content': '#todo\n別の本文\n'},
            ],
            'failures': <Object>[],
          };
        default:
          throw MissingPluginException();
      }
    });

    await tester.pumpWidget(const app.MainApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('selected'), matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todo詳細を読み込めませんでした'), findsNothing);
    expect(readCount, greaterThanOrEqualTo(2));
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
      contains('選択した本文'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(readCount, greaterThanOrEqualTo(3));
    expect(find.text('selected'), findsOneWidget);
  });

  testWidgets('選択Todoを読み込めない場合は失敗を表示して一覧へ戻れる', (tester) async {
    var readCount = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return _folder;
        case 'hasAccess':
          return true;
        case 'readFolder':
          readCount++;
          if (readCount == 2) {
            return {
              'notes': <Object>[],
              'failures': [
                {'path': 'selected.md', 'message': 'テスト読込失敗'},
              ],
            };
          }
          return {
            'notes': [
              {'path': 'selected.md', 'content': '#todo\n本文\n'},
            ],
            'failures': <Object>[],
          };
        default:
          throw MissingPluginException();
      }
    });

    await tester.pumpWidget(const app.MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Todo詳細を読み込めませんでした'), findsOneWidget);
    expect(find.textContaining('テスト読込失敗'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('selected'), findsOneWidget);
  });

  testWidgets('関連タイトルから参照Markdownを開き戻るとTodo詳細に戻る', (tester) async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return _folder;
        case 'hasAccess':
          return true;
        case 'readFolder':
          return {
            'notes': [
              {'path': 'selected.md', 'content': '#todo\n[[docs/reference]]\n'},
              {
                'path': 'docs/reference.md',
                'content': '# Reference\n関連Markdownの本文\n',
              },
            ],
            'failures': <Object>[],
          };
        default:
          throw MissingPluginException();
      }
    });

    await tester.pumpWidget(const app.MainApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('selected'), matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();
    expect(find.text('reference'), findsOneWidget);
    await tester.tap(find.text('reference'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
      contains('関連Markdownの本文'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('selected'), findsOneWidget);
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
      contains('[[docs/reference]]'),
    );
  });

  testWidgets('詳細の階層タグから完全一致するTodo一覧へ移動する', (tester) async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return _folder;
        case 'hasAccess':
          return true;
        case 'normalizeNfc':
          return call.arguments;
        case 'readFolder':
          return {
            'notes': [
              {
                'path': 'selected.md',
                'content': '---\ntags: [todo, "仕事/会議"]\n---\n',
              },
              {
                'path': 'exact.md',
                'content': '---\ntags: [todo, "仕事/会議"]\n---\n',
              },
              {
                'path': 'parent.md',
                'content': '---\ntags: [todo, "仕事"]\n---\n',
              },
              {
                'path': 'child.md',
                'content': '---\ntags: [todo, "仕事/会議/補助"]\n---\n',
              },
            ],
            'failures': <Object>[],
          };
        default:
          throw MissingPluginException();
      }
    });

    await tester.pumpWidget(const app.MainApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('selected'), matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('#仕事/会議'));
    await tester.pumpAndSettle();

    expect(find.text('exact'), findsOneWidget);
    expect(find.text('selected'), findsOneWidget);
    expect(find.text('parent'), findsNothing);
    expect(find.text('child'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '#仕事/会議',
    );
  });

  testWidgets('20件以上のTodoから選択内容を確認し有効リンクを開ける', (tester) async {
    final notes = [
      for (var index = 0; index < 20; index++)
        {
          'path': 'todo_${index.toString().padLeft(2, '0')}.md',
          'content': index == 17
              ? '---\ntags: [todo]\n---\n選択した本文17\n[[references/guide]]\n'
              : '---\ntags: [todo]\n---\n本文 $index\n',
        },
      {'path': 'references/guide.md', 'content': '# Guide\n有効な参照本文\n'},
    ];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return _folder;
        case 'hasAccess':
          return true;
        case 'readFolder':
          return {'notes': notes, 'failures': <Object>[]};
        default:
          throw MissingPluginException();
      }
    });

    await tester.pumpWidget(const app.MainApp());
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    for (
      var attempt = 0;
      attempt < 10 && find.text('todo_17').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(find.text('todo_17'), findsOneWidget);
    await tester.tap(
      find.ancestor(of: find.text('todo_17'), matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
      contains('選択した本文17'),
    );

    await tester.tap(find.text('guide'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
      contains('有効な参照本文'),
    );
  });
}
