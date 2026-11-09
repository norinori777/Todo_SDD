import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/folder_reader.dart';
import 'package:todo_sdd/features/todo/note.dart';
import 'package:todo_sdd/features/todo/todo_repository.dart';

void main() {
  test('選択したNoteIdのTodoだけを返し、同名の別Todoを混在させない', () async {
    final selectedId = NoteId('selected/task.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(NoteId('other/task.md'), '---\ntags: [todo, 別]\n---\n別の内容\n'),
        ReadNote(selectedId, '---\ntags: [todo, 選択]\n---\n選択した内容\n'),
      ], const []),
    ).loadTodoDetail(selectedId);

    expect(
      result,
      isA<TodoDetailLoadSuccess>()
          .having(
            (loaded) => loaded.detail.todo.note.id.relativePath,
            'selected path',
            'selected/task.md',
          )
          .having(
            (loaded) => loaded.detail.todo.note.content,
            'selected content',
            contains('選択した内容'),
          )
          .having((loaded) => loaded.detail.todo.tags, 'selected tags', [
            'todo',
            '選択',
          ]),
    );
  });

  test('選択したTodoが見つからない場合は識別子付きの失敗を返す', () async {
    final selectedId = NoteId('missing/task.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(NoteId('other/task.md'), '---\ntags: [todo]\n---\n'),
      ], const []),
    ).loadTodoDetail(selectedId);

    expect(
      result,
      isA<TodoDetailLoadError>()
          .having((error) => error.path, 'path', 'missing/task.md')
          .having((error) => error.cause, 'cause', isA<StateError>()),
    );
  });

  test('選択したTodoの読み込み失敗を空データに置き換えない', () async {
    final selectedId = NoteId('broken/task.md');
    final cause = const FormatException('UTF-8を読み取れません');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess(const [], [
        FolderReadFailure(selectedId.relativePath, cause),
      ]),
    ).loadTodoDetail(selectedId);

    expect(
      result,
      isA<TodoDetailLoadError>()
          .having((error) => error.path, 'path', 'broken/task.md')
          .having((error) => error.cause, 'cause', same(cause)),
    );
  });

  test('選択したTodoのMarkdown解析失敗を詳細成功にしない', () async {
    final selectedId = NoteId('broken/task.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(selectedId, '---\ntags: [todo, 123]\n---\n'),
      ], const []),
    ).loadTodoDetail(selectedId);

    expect(
      result,
      isA<TodoDetailLoadError>()
          .having((error) => error.path, 'path', 'broken/task.md')
          .having(
            (error) => error.cause,
            'cause',
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('tags'),
            ),
          ),
    );
  });

  test('本文のWikiリンクをフォルダー内で解決し同じ参照を重複表示しない', () async {
    final selectedId = NoteId('tasks/current.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(
          selectedId,
          '---\ntags: [todo]\n---\n[[a/ref]] [[a/ref#section|別名]] [[b/ref]]',
        ),
        ReadNote(NoteId('a/ref.md'), '# 参照A\n'),
        ReadNote(NoteId('b/ref.md'), '# 参照B\n'),
      ], const []),
    ).loadTodoDetail(selectedId);

    expect(
      result,
      isA<TodoDetailLoadSuccess>().having(
        (loaded) =>
            loaded.detail.related.map((reference) => reference.title).toList(),
        'related titles',
        ['ref (a/ref.md)', 'ref (b/ref.md)'],
      ),
    );
    final loaded = result as TodoDetailLoadSuccess;
    expect(
      loaded.detail.related.map((reference) => reference.note?.id.relativePath),
      ['a/ref.md', 'b/ref.md'],
    );
  });

  test('未解決Wikiリンクを開けない参照として返す', () async {
    final selectedId = NoteId('tasks/current.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(selectedId, '---\ntags: [todo]\n---\n[[missing]]'),
      ], const []),
    ).loadTodoDetail(selectedId);

    expect(
      result,
      isA<TodoDetailLoadSuccess>().having(
        (loaded) => loaded.detail.related,
        'related',
        hasLength(1),
      ),
    );
    final reference = (result as TodoDetailLoadSuccess).detail.related.single;
    expect(reference.canOpen, isFalse);
    expect(reference.failure, contains('見つかりません'));
  });

  test('同名候補が複数あるWikiリンクは任意の文書を選ばない', () async {
    final selectedId = NoteId('tasks/current.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(selectedId, '---\ntags: [todo]\n---\n[[ref]]'),
        ReadNote(NoteId('a/ref.md'), '参照A'),
        ReadNote(NoteId('b/ref.md'), '参照B'),
      ], const []),
    ).loadTodoDetail(selectedId);
    final reference = (result as TodoDetailLoadSuccess).detail.related.single;

    expect(reference.canOpen, isFalse);
    expect(reference.note, isNull);
    expect(reference.failure, contains('一意'));
  });

  test('フォルダー外を指すWikiリンクを拒否する', () async {
    final selectedId = NoteId('tasks/current.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(selectedId, '---\ntags: [todo]\n---\n[[../outside]]'),
      ], const []),
    ).loadTodoDetail(selectedId);
    final reference = (result as TodoDetailLoadSuccess).detail.related.single;

    expect(reference.canOpen, isFalse);
    expect(reference.failure, contains('フォルダーの外'));
  });

  test('読み込み失敗したリンク先はエラー付きで開けない', () async {
    final selectedId = NoteId('tasks/current.md');
    final cause = const FileSystemException('permission denied');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess(
        [ReadNote(selectedId, '---\ntags: [todo]\n---\n[[docs/ref]]')],
        [FolderReadFailure('docs/ref.md', cause)],
      ),
    ).loadTodoDetail(selectedId);
    final reference = (result as TodoDetailLoadSuccess).detail.related.single;

    expect(reference.canOpen, isFalse);
    expect(reference.failure, contains('permission denied'));
  });

  test('タイトル形式リンクに一致する読込失敗も見つからない扱いにしない', () async {
    final selectedId = NoteId('tasks/current.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess(
        [ReadNote(selectedId, '---\ntags: [todo]\n---\n[[ref]]')],
        [
          FolderReadFailure(
            'docs/ref.md',
            const FileSystemException('permission denied'),
          ),
        ],
      ),
    ).loadTodoDetail(selectedId);
    final reference = (result as TodoDetailLoadSuccess).detail.related.single;

    expect(reference.canOpen, isFalse);
    expect(reference.failure, contains('permission denied'));
  });

  test('frontmatter・コード・HTMLコメント内のWiki記法は関連情報にしない', () async {
    final selectedId = NoteId('tasks/current.md');
    final result = await TodoRepository(
      read: () async => FolderReadSuccess([
        ReadNote(
          selectedId,
          '---\ntags: [todo]\nreference: [[frontmatter]]\n---\n'
          '`[[inline]]`\n\n'
          '```md\n[[fenced]]\n```\n\n'
          '<!-- [[comment]] -->\n'
          r'\[[escaped]]',
        ),
        ReadNote(NoteId('frontmatter.md'), 'frontmatter'),
        ReadNote(NoteId('inline.md'), 'inline'),
        ReadNote(NoteId('fenced.md'), 'fenced'),
        ReadNote(NoteId('comment.md'), 'comment'),
        ReadNote(NoteId('escaped.md'), 'escaped'),
      ], const []),
    ).loadTodoDetail(selectedId);

    expect((result as TodoDetailLoadSuccess).detail.related, isEmpty);
  });
}
