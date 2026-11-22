import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_list.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';

void main() {
  testWidgets('読込中であることを表示する', (tester) async {
    final pendingLoad = Completer<TodoLoadResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () => pendingLoad.future,
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
        ),
      ),
    );

    expect(find.text('読み込み中'), findsOneWidget);
    pendingLoad.complete(const TodoLoadSuccess([], []));
  });

  testWidgets('空の成功結果は読込失敗と区別して表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => const TodoLoadSuccess([], []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todoはありません'), findsOneWidget);
    expect(find.text('一覧を読み込めませんでした'), findsNothing);
  });

  testWidgets('全体読込失敗と対処方法を表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadError(StateError('フォルダー権限がありません')),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一覧を読み込めませんでした'), findsOneWidget);
    expect(find.textContaining('フォルダー権限がありません'), findsOneWidget);
    expect(find.textContaining('アクセス権を確認してください'), findsOneWidget);
    expect(find.text('Todoはありません'), findsNothing);
  });

  testWidgets('部分読込失敗を読み込めた項目と併せて表示する', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/task.md'), content: '#todo'),
      tags: const ['todo', '仕事/会議'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess(
            [todo],
            const [TodoLoadFailure('notes/broken.md', 'UTF-8を読み取れません')],
          ),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('task'), findsOneWidget);
    expect(find.textContaining('notes/broken.md'), findsOneWidget);
    expect(find.textContaining('UTF-8を読み取れません'), findsOneWidget);
    expect(find.textContaining('#仕事/会議'), findsOneWidget);
  });

  testWidgets('同名Todoは相対パスを併記する', (tester) async {
    final todos = [
      Todo(
        note: Note(id: NoteId('b/task.md'), content: '#todo'),
        tags: const ['todo'],
      ),
      Todo(
        note: Note(id: NoteId('a/task.md'), content: '#todo'),
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('a/task.md'), findsOneWidget);
    expect(find.text('b/task.md'), findsOneWidget);
  });

  testWidgets('初期一覧から完了済みTodoを除外する', (tester) async {
    final todos = [
      Todo(
        note: Note(id: NoteId('notes/open.md'), content: '#todo'),
        tags: const ['todo'],
      ),
      Todo(
        note: Note(id: NoteId('notes/done.md'), content: '#todo #完了'),
        tags: const ['todo', '完了'],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess(todos, const []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('done'), findsNothing);
  });

  testWidgets('Todoの操作メニューから対象を編集できる', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/task.md'), content: '#todo'),
      tags: const ['todo'],
    );
    Todo? editedTodo;
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess([todo], const []),
          onOpenDetails: (_) {},
          onOpenEdit: (selected) => editedTodo = selected,
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('taskの操作メニュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));

    expect(editedTodo, same(todo));
  });

  testWidgets('Todoタップで選択した識別子の公開境界を呼び出す', (tester) async {
    final todo = Todo(
      note: Note(id: NoteId('notes/task.md'), content: '#todo'),
      tags: const ['todo'],
    );
    Todo? openedTodo;
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => TodoLoadSuccess([todo], const []),
          onOpenDetails: (selected) => openedTodo = selected,
          onOpenEdit: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('task'));

    expect(openedTodo, same(todo));
  });

  testWidgets('初期タグ検索は階層を含めて完全一致のTodoだけを表示する', (tester) async {
    final todos = [
      Todo(
        note: Note(id: NoteId('notes/exact.md'), content: '#todo'),
        tags: const ['todo', '仕事/会議'],
      ),
      Todo(
        note: Note(id: NoteId('notes/parent.md'), content: '#todo'),
        tags: const ['todo', '仕事'],
      ),
      Todo(
        note: Note(id: NoteId('notes/child.md'), content: '#todo'),
        tags: const ['todo', '仕事/会議/補助'],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          initialSearchQuery: '#仕事/会議',
          loadTodos: () async => TodoLoadSuccess(todos, const []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () {},
          normalizeTags: (tags) async => tags,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('exact'), findsOneWidget);
    expect(find.text('parent'), findsNothing);
    expect(find.text('child'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '#仕事/会議',
    );
  });

  testWidgets('作成ボタンで作成画面の公開境界を呼び出す', (tester) async {
    var createRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async => const TodoLoadSuccess([], []),
          onOpenDetails: (_) {},
          onOpenEdit: (_) {},
          onCreate: () => createRequested = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Todoを作成'));

    expect(createRequested, isTrue);
  });
}
