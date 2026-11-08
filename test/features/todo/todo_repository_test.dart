import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/folder_reader.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';

void main() {
  test('Todoタグを持つMarkdownだけをTodoとして返す', () async {
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(NoteId('notes/task.md'), '---\ntags: [todo]\n---\n# 見出し\n'),
        ReadNote(NoteId('notes/reference.md'), '# 参考\n'),
      ], []),
    ).loadTodos();

    expect(
      result,
      isA<TodoLoadSuccess>().having(
        (loaded) => loaded.todos.map((todo) => todo.title).toList(),
        'titles',
        ['task'],
      ),
    );
  });

  test('部分読込失敗をTodo結果と区別して返す', () async {
    final result = await TodoRepository(
      read: () async => FolderReadSuccess(
        [ReadNote(NoteId('notes/task.md'), '#todo\n')],
        [
          FolderReadFailure(
            'notes/broken.md',
            const FormatException('UTF-8をデコードできません'),
          ),
        ],
      ),
    ).loadTodos();

    expect(
      result,
      isA<TodoLoadSuccess>()
          .having((loaded) => loaded.todos, 'todos', hasLength(1))
          .having(
            (loaded) => loaded.failures.single.path,
            'failure path',
            'notes/broken.md',
          ),
    );
  });

  test('フォルダー全体の読込失敗を空結果にしない', () async {
    final result = await TodoRepository(
      read: () async =>
          FolderReadError(FileSystemException('permission denied')),
    ).loadTodos();

    expect(result, isA<TodoLoadError>());
  });

  test('解析できないノートを識別子と理由付きで部分失敗にする', () async {
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(NoteId('notes/broken.md'), '---\ntags: [todo, 123]\n---\n'),
      ], const []),
    ).loadTodos();

    expect(
      result,
      isA<TodoLoadSuccess>()
          .having((loaded) => loaded.todos, 'todos', isEmpty)
          .having(
            (loaded) => loaded.failures.single.path,
            'failure path',
            'notes/broken.md',
          )
          .having(
            (loaded) => loaded.failures.single.reason,
            'failure reason',
            contains('tags'),
          ),
    );
  });

  test('完了タグがあるTodoを完了済みとして返す', () async {
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(NoteId('notes/done.md'), '---\ntags: [todo, "#完了"]\n---\n'),
      ], const []),
    ).loadTodos();

    expect(
      result,
      isA<TodoLoadSuccess>().having(
        (loaded) => loaded.todos.single.isCompleted,
        'isCompleted',
        isTrue,
      ),
    );
  });
}
