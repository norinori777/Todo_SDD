import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_list.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';

void main() {
  testWidgets('詳細画面から戻ると検索条件を維持して再読込する', (tester) async {
    var loadCount = 0;
    Todo createTodo(String title) => Todo(
      note: Note(id: NoteId('notes/$title.md'), content: '#todo'),
      tags: const ['todo'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodoListScreen(
          loadTodos: () async {
            loadCount++;
            return TodoLoadSuccess([
              createTodo(loadCount == 1 ? 'task-old' : 'task-new'),
            ], const []);
          },
          onOpenDetails: (_) async {},
          onOpenEdit: (_) {},
          onCreate: () {},
          normalizeTags: (tags) async => tags,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'task');
    await tester.pumpAndSettle();
    await tester.tap(find.text('task-old'));
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('task-new'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'task',
    );
  });
}
