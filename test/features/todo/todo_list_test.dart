import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_list.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';

void main() {
  test('タイトルをUnicodeコードポイント順で並べる', () {
    final supplementary = Todo(
      note: Note(id: NoteId('notes/\u{10000}.md'), content: '#todo'),
      tags: const ['todo'],
    );
    final privateUse = Todo(
      note: Note(id: NoteId('notes/\uE000.md'), content: '#todo'),
      tags: const ['todo'],
    );

    expect(
      sortTodosByTitle([supplementary, privateUse]).map((todo) => todo.title),
      ['\uE000', '\u{10000}'],
    );
  });

  test('ASCIIと日本語の順序は言語設定に依存しない', () {
    final todos = [
      _todo('ア'),
      _todo('あ'),
      _todo('a'),
      _todo('A'),
    ];

    expect(
      sortTodosByTitle(todos).map((todo) => todo.title),
      ['A', 'a', 'あ', 'ア'],
    );
  });

  test('同名タイトルは相対パスのUnicodeコードポイント順で並べる', () {
    final laterPath = Todo(
      note: Note(id: NoteId('z/task.md'), content: '#todo'),
      tags: const ['todo'],
    );
    final earlierPath = Todo(
      note: Note(id: NoteId('a/task.md'), content: '#todo'),
      tags: const ['todo'],
    );

    expect(
      sortTodosByTitle([
        laterPath,
        earlierPath,
      ]).map((todo) => todo.note.id.relativePath),
      ['a/task.md', 'z/task.md'],
    );
  });
}

Todo _todo(String title) => Todo(
  note: Note(id: NoteId('notes/$title.md'), content: '#todo'),
  tags: const ['todo'],
);
