import 'todo_repository.dart';

class TodoSearch {
  const TodoSearch({required this.normalizeTags});

  final Future<List<String>> Function(List<String> tags) normalizeTags;

  Future<List<Todo>> apply(List<Todo> todos, String query) async {
    if (query.isEmpty) {
      return List<Todo>.unmodifiable(todos.where((todo) => !todo.isCompleted));
    }
    if (!query.startsWith('#')) {
      final needle = query.toLowerCase();
      return List<Todo>.unmodifiable(
        todos.where(
          (todo) =>
              !todo.isCompleted && todo.title.toLowerCase().contains(needle),
        ),
      );
    }
    if (query == '#完了') {
      return List<Todo>.unmodifiable(todos.where((todo) => todo.isCompleted));
    }

    final tagQuery = query.substring(1);
    if (tagQuery.isEmpty) return const [];
    final openTodos = todos.where((todo) => !todo.isCompleted).toList();
    final tagValues = [tagQuery, for (final todo in openTodos) ...todo.tags];
    final normalizedTags = await normalizeTags(tagValues);
    if (normalizedTags.length != tagValues.length) {
      throw const FormatException('タグ正規化の結果の数が一致しません');
    }
    final normalizedQuery = normalizedTags.first;
    var offset = 1;
    final matches = <Todo>[];
    for (final todo in openTodos) {
      final normalizedTodoTags = normalizedTags
          .skip(offset)
          .take(todo.tags.length);
      if (normalizedTodoTags.contains(normalizedQuery)) matches.add(todo);
      offset += todo.tags.length;
    }
    return List<Todo>.unmodifiable(matches);
  }
}
