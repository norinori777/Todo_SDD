import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_list.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';

void main() {
  testWidgets('タイトル検索を大文字小文字を区別せず一覧に適用する', (tester) async {
    final todos = [
      Todo(
        note: Note(id: NoteId('notes/Task.md'), content: '#todo'),
        tags: ['todo'],
      ),
      Todo(
        note: Note(id: NoteId('notes/other.md'), content: '#todo'),
        tags: const ['todo'],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess(todos, const []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
          normalizeTags: (tags) async => tags,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'task');
    await tester.pumpAndSettle();

    expect(find.text('Task'), findsOneWidget);
    expect(find.text('other'), findsNothing);
  });

  testWidgets('タグの完全一致検索を適用し、消去で一覧に戻す', (tester) async {
    final todos = [
      Todo(
        note: Note(id: NoteId('notes/work.md'), content: '#todo'),
        tags: const ['todo', '仕事'],
      ),
      Todo(
        note: Note(id: NoteId('notes/meeting.md'), content: '#todo'),
        tags: const ['todo', '仕事/会議'],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess(todos, const []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
          normalizeTags: (tags) async => tags,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '#仕事');
    await tester.pumpAndSettle();

    expect(find.text('work'), findsOneWidget);
    expect(find.text('meeting'), findsNothing);
    await tester.tap(find.byTooltip('検索をクリア'));
    await tester.pumpAndSettle();
    expect(find.text('work'), findsOneWidget);
    expect(find.text('meeting'), findsOneWidget);
  });

  testWidgets('タグ正規化の失敗を検索失敗として通知する', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/task.md'), content: '#todo'),
      tags: const ['todo', 'work'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess([todo], const []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
          normalizeTags: (_) async => throw const FormatException('正規化不可'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '#work');
    await tester.pumpAndSettle();

    expect(find.text('タグ検索に失敗しました'), findsOneWidget);
    expect(find.textContaining('正規化不可'), findsOneWidget);
    expect(find.text('task'), findsNothing);
  });

  testWidgets('検索結果がないことを表示する', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/task.md'), content: '#todo'),
      tags: const ['todo'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess([todo], const []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
          normalizeTags: (tags) async => tags,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();

    expect(find.text('検索結果がありません'), findsOneWidget);
  });
}
