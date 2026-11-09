import 'package:path/path.dart' as path;

import 'folder_reader.dart';
import 'markdown_parser.dart';
import 'note.dart';

class Todo {
  const Todo({required this.note, required this.tags});

  final Note note;
  final List<String> tags;

  String get title => note.title;
  bool get isCompleted => tags.contains('完了');
}

sealed class TodoLoadResult {
  const TodoLoadResult();
}

class TodoLoadSuccess extends TodoLoadResult {
  const TodoLoadSuccess(this.todos, this.failures);

  final List<Todo> todos;
  final List<TodoLoadFailure> failures;
}

class TodoLoadError extends TodoLoadResult {
  const TodoLoadError(this.cause);

  final Object cause;
}

class TodoLoadFailure {
  const TodoLoadFailure(this.path, this.reason);

  final String path;
  final String reason;
}

class TodoDetail {
  const TodoDetail({required this.todo, this.related = const []});

  final Todo todo;
  final List<TodoRelatedMarkdown> related;
}

class TodoRelatedMarkdown {
  const TodoRelatedMarkdown({
    required this.target,
    required this.title,
    this.note,
    this.failure,
  });

  final String target;
  final String title;
  final Note? note;
  final String? failure;

  bool get canOpen => note != null;
}

sealed class TodoDetailLoadResult {
  const TodoDetailLoadResult();
}

class TodoDetailLoadSuccess extends TodoDetailLoadResult {
  const TodoDetailLoadSuccess(this.detail);

  final TodoDetail detail;
}

class TodoDetailLoadError extends TodoDetailLoadResult {
  const TodoDetailLoadError(this.cause, {this.path});

  final Object cause;
  final String? path;
}

class TodoRepository {
  const TodoRepository({required this.read});

  final Future<FolderReadResult> Function() read;

  Future<TodoDetailLoadResult> loadTodoDetail(NoteId selectedId) async {
    final folderResult = await read();
    switch (folderResult) {
      case FolderReadError(:final cause):
        return TodoDetailLoadError(cause, path: selectedId.relativePath);
      case FolderReadSuccess(:final notes, :final failures):
        final matchingFailure = failures
            .where((failure) => failure.path == selectedId.relativePath)
            .firstOrNull;
        if (matchingFailure != null) {
          return TodoDetailLoadError(
            matchingFailure.cause,
            path: matchingFailure.path,
          );
        }

        final selectedNote = notes
            .where((note) => note.id.relativePath == selectedId.relativePath)
            .firstOrNull;
        if (selectedNote == null) {
          return TodoDetailLoadError(
            StateError('選択したTodoが見つかりません'),
            path: selectedId.relativePath,
          );
        }

        final note = Note(id: selectedNote.id, content: selectedNote.content);
        final parsed = parseMarkdownNote(note);
        if (parsed case MarkdownParseFailure(:final reason)) {
          return TodoDetailLoadError(
            FormatException(reason),
            path: selectedId.relativePath,
          );
        }
        if (parsed is! MarkdownParseSuccess || !parsed.isTodo) {
          return TodoDetailLoadError(
            StateError('選択したノートはTodoではありません'),
            path: selectedId.relativePath,
          );
        }
        return TodoDetailLoadSuccess(
          TodoDetail(
            todo: Todo(note: note, tags: parsed.tags),
            related: _resolveTodoReferences(
              extractWikiLinkTargets(selectedNote.content),
              notes,
              failures,
            ),
          ),
        );
    }
  }

  List<TodoRelatedMarkdown> _resolveTodoReferences(
    List<String> targets,
    List<ReadNote> notes,
    List<FolderReadFailure> failures,
  ) {
    final notesByPath = {for (final note in notes) note.id.relativePath: note};
    final notesByTitle = <String, List<ReadNote>>{};
    for (final note in notes) {
      final title = Note(id: note.id, content: note.content).title;
      notesByTitle.putIfAbsent(title, () => []).add(note);
    }
    final failuresByPath = {
      for (final failure in failures) failure.path: failure,
    };
    final failuresByTitle = <String, List<FolderReadFailure>>{};
    for (final failure in failures) {
      final title = path.posix.basenameWithoutExtension(failure.path);
      failuresByTitle.putIfAbsent(title, () => []).add(failure);
    }
    final resolved = <String, TodoRelatedMarkdown>{};
    final unresolved = <TodoRelatedMarkdown>[];

    for (final target in targets) {
      final hasExtension = path.posix.extension(target).toLowerCase() == '.md';
      final isPath = path.posix.split(target).length > 1 || hasExtension;
      final String? pathTarget;
      if (isPath) {
        final pathValue = hasExtension ? target : '$target.md';
        try {
          pathTarget = NoteId(pathValue).relativePath;
        } on ArgumentError {
          unresolved.add(
            TodoRelatedMarkdown(
              target: target,
              title: target,
              failure: 'リンク先が指定フォルダーの外です',
            ),
          );
          continue;
        }
      } else {
        pathTarget = null;
      }

      final candidates = pathTarget == null
          ? notesByTitle[target] ?? const <ReadNote>[]
          : [?notesByPath[pathTarget]];
      final matchingFailures = pathTarget == null
          ? failuresByTitle[target] ?? const <FolderReadFailure>[]
          : [?failuresByPath[pathTarget]];
      if (matchingFailures.isNotEmpty) {
        unresolved.add(
          TodoRelatedMarkdown(
            target: target,
            title: target,
            failure: candidates.isNotEmpty || matchingFailures.length > 1
                ? 'リンク先を一意に決められません'
                : 'リンク先を読み込めません: ${matchingFailures.first.cause}',
          ),
        );
        continue;
      }
      if (candidates.length > 1) {
        unresolved.add(
          TodoRelatedMarkdown(
            target: target,
            title: target,
            failure: 'リンク先を一意に決められません',
          ),
        );
        continue;
      }
      if (candidates.isEmpty) {
        unresolved.add(
          TodoRelatedMarkdown(
            target: target,
            title: target,
            failure: 'リンク先が見つかりません',
          ),
        );
        continue;
      }

      final note = candidates.single;
      resolved.putIfAbsent(
        note.id.relativePath,
        () => TodoRelatedMarkdown(
          target: target,
          title: Note(id: note.id, content: note.content).title,
          note: Note(id: note.id, content: note.content),
        ),
      );
    }

    final titleCounts = <String, int>{};
    for (final reference in resolved.values) {
      titleCounts.update(
        reference.title,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return List<TodoRelatedMarkdown>.unmodifiable([
      for (final reference in resolved.values)
        if (titleCounts[reference.title]! > 1)
          TodoRelatedMarkdown(
            target: reference.target,
            title: '${reference.title} (${reference.note!.id.relativePath})',
            note: reference.note,
          )
        else
          reference,
      ...unresolved,
    ]);
  }

  Future<TodoLoadResult> loadTodos() async {
    final folderResult = await read();
    switch (folderResult) {
      case FolderReadError(:final cause):
        return TodoLoadError(cause);
      case FolderReadSuccess(:final notes, :final failures):
        final todos = <Todo>[];
        final loadFailures = [
          for (final failure in failures)
            TodoLoadFailure(failure.path, failure.cause.toString()),
        ];
        for (final readNote in notes) {
          final parsed = parseMarkdownNote(
            Note(id: readNote.id, content: readNote.content),
          );
          switch (parsed) {
            case MarkdownParseFailure(:final reason):
              loadFailures.add(
                TodoLoadFailure(readNote.id.relativePath, reason),
              );
            case MarkdownParseSuccess(:final tags):
              if (parsed.isTodo) {
                todos.add(
                  Todo(
                    note: Note(id: readNote.id, content: readNote.content),
                    tags: tags,
                  ),
                );
              }
          }
        }
        return TodoLoadSuccess(
          List<Todo>.unmodifiable(todos),
          List<TodoLoadFailure>.unmodifiable(loadFailures),
        );
    }
  }
}
