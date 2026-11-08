import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';
import 'package:todo_sdd/features/todo/todo_search.dart';

void main() {
  test('空の検索条件は未完了Todoだけを返す', () async {
    final openTodo = _todo('notes/open.md', ['todo']);
    final completedTodo = _todo('notes/done.md', ['todo', '完了']);

    final results = await TodoSearch(
      normalizeTags: (tags) async => tags,
    ).apply([openTodo, completedTodo], '');

    expect(results, [same(openTodo)]);
  });

  test('タイトルの部分一致は英字の大小文字を区別しない', () async {
    final match = _todo('notes/Task.md', ['todo']);
    final nonMatch = _todo('notes/other.md', ['todo']);

    final results = await TodoSearch(
      normalizeTags: (tags) async => tags,
    ).apply([match, nonMatch], 'task');

    expect(results, [same(match)]);
  });

  test('タグ検索は完全一致かつ大文字小文字を区別する', () async {
    final exact = _todo('notes/exact.md', ['todo', '仕事']);
    final child = _todo('notes/child.md', ['todo', '仕事/会議']);
    final differentCase = _todo('notes/case.md', ['todo', 'Todo']);

    final results = await TodoSearch(
      normalizeTags: (tags) async => tags,
    ).apply([exact, child, differentCase], '#仕事');

    expect(results, [same(exact)]);
  });

  test('#完了検索は完了Todoだけを返す', () async {
    final openTodo = _todo('notes/open.md', ['todo']);
    final completedTodo = _todo('notes/done.md', ['todo', '完了']);

    final results = await TodoSearch(
      normalizeTags: (tags) async => tags,
    ).apply([openTodo, completedTodo], '#完了');

    expect(results, [same(completedTodo)]);
  });

  test('NFCで異なる表記を一致させるが元タグを変更しない', () async {
    final decomposed = 'か\u3099';
    final todo = _todo('notes/task.md', ['todo', decomposed]);

    final results = await TodoSearch(
      normalizeTags: (tags) async => [
        for (final tag in tags)
          if (tag == decomposed) 'が' else tag,
      ],
    ).apply([todo], '#が');

    expect(results, [same(todo)]);
    expect(todo.tags.last, decomposed);
  });
}

Todo _todo(String path, List<String> tags) => Todo(
  note: Note(id: NoteId(path), content: ''),
  tags: tags,
);
