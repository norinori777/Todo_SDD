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

class TodoRepository {
  const TodoRepository({required this.read});

  final Future<FolderReadResult> Function() read;

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
