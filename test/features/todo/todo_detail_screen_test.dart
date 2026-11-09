import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_detail_screen.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';

void main() {
  testWidgets('画面の再ビルドで詳細Repositoryを再読込しない', (tester) async {
    var loadCount = 0;
    final todo = Todo(
      note: Note(id: NoteId('notes/selected.md'), content: '#todo'),
      tags: const ['todo'],
    );
    TodoDetailScreen screen() => TodoDetailScreen(
      key: const ValueKey('detail'),
      loadDetail: () async {
        loadCount++;
        return TodoDetailLoadSuccess(TodoDetail(todo: todo));
      },
      onTagSelected: (_) {},
      onOpenRelated: (_) {},
    );

    await tester.pumpWidget(MaterialApp(home: screen()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(home: screen()));
    await tester.pumpAndSettle();

    expect(loadCount, 1);
  });

  testWidgets('参照専用詳細に選択TodoのMarkdown本文と階層タグを表示する', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/selected.md'), content: '#todo\n\n選択した本文\n'),
      tags: const ['todo', '仕事/会議'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TodoDetailScreen(
          loadDetail: () async => TodoDetailLoadSuccess(TodoDetail(todo: todo)),
          onTagSelected: (_) {},
          onOpenRelated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('selected'), findsOneWidget);
    expect(find.text('選択した本文'), findsOneWidget);
    expect(find.text('#仕事/会議'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('編集'), findsNothing);
    expect(find.text('削除'), findsNothing);
    expect(find.text('関連情報を作成'), findsNothing);
  });

  testWidgets('本文とタグが空なら空の表示項目を追加しない', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/empty.md'), content: ''),
      tags: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TodoDetailScreen(
          loadDetail: () async => TodoDetailLoadSuccess(TodoDetail(todo: todo)),
          onTagSelected: (_) {},
          onOpenRelated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('empty'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('関連情報'), findsNothing);
  });

  testWidgets('長い本文をスクロールして確認した後に戻れる', (tester) async {
    final todo = Todo(
      note: Note(
        id: NoteId('notes/long.md'),
        content:
            '#todo\n${List.generate(80, (index) => '本文 $index').join('\n\n')}',
      ),
      tags: const ['todo'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => TodoDetailScreen(
                  loadDetail: () async =>
                      TodoDetailLoadSuccess(TodoDetail(todo: todo)),
                  onTagSelected: (_) {},
                  onOpenRelated: (_) {},
                ),
              ),
            ),
            child: const Text('一覧'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('一覧'));
    await tester.pumpAndSettle();

    expect(find.text('本文 79'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('本文 79'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('一覧'), findsOneWidget);
  });

  testWidgets('通常のMarkdownリンクをタップしても外部遷移しない', (tester) async {
    final todo = Todo(
      note: Note(
        id: NoteId('notes/selected.md'),
        content: '#todo\n[外部リンク](https://example.com)\n',
      ),
      tags: const ['todo'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TodoDetailScreen(
          loadDetail: () async => TodoDetailLoadSuccess(TodoDetail(todo: todo)),
          onTagSelected: (_) {},
          onOpenRelated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('外部リンク'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('開けない関連情報は理由を表示し別ノートを開かない', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/selected.md'), content: '#todo'),
      tags: const ['todo'],
    );
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TodoDetailScreen(
          loadDetail: () async => TodoDetailLoadSuccess(
            TodoDetail(
              todo: todo,
              related: const [
                TodoRelatedMarkdown(
                  target: 'missing',
                  title: 'missing',
                  failure: 'リンク先が見つかりません',
                ),
              ],
            ),
          ),
          onTagSelected: (_) {},
          onOpenRelated: (_) => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('関連情報'), findsOneWidget);
    expect(find.textContaining('リンク先が見つかりません'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
    expect(opened, isFalse);
  });
}
