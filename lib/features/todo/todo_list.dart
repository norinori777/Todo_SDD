import 'dart:async';

import 'package:flutter/material.dart';

import 'tag_normalizer.dart';
import 'todo_repository.dart';
import 'todo_search.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({
    required this.loadTodos,
    required this.onOpenDetails,
    required this.onOpenEdit,
    required this.onCreate,
    this.initialSearchQuery = '',
    this.normalizeTags = _normalizeTags,
    super.key,
  });

  final Future<TodoLoadResult> Function() loadTodos;
  final FutureOr<void> Function(Todo) onOpenDetails;
  final FutureOr<void> Function(Todo) onOpenEdit;
  final FutureOr<void> Function() onCreate;
  final String initialSearchQuery;
  final Future<List<String>> Function(List<String>) normalizeTags;

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late Future<TodoLoadResult> _loadFuture;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String? _lastSearchQuery;
  List<Todo>? _lastSearchTodos;
  Future<List<Todo>>? _searchFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loadTodos();
    _searchQuery = widget.initialSearchQuery;
    _searchController = TextEditingController(text: widget.initialSearchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDetails(Todo todo) async {
    await widget.onOpenDetails(todo);
    _reload();
  }

  Future<void> _openEdit(Todo todo) async {
    await widget.onOpenEdit(todo);
    _reload();
  }

  Future<void> _openCreate() async {
    await widget.onCreate();
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _loadFuture = widget.loadTodos();
      _searchFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Todo一覧')),
    floatingActionButton: FloatingActionButton(
      onPressed: _openCreate,
      tooltip: 'Todoを作成',
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<TodoLoadResult>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('読み込み中'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _loadError('一覧を読み込めませんでした', snapshot.error.toString());
        }
        return switch (snapshot.data!) {
          TodoLoadError(:final cause) => _loadError(
            '一覧を読み込めませんでした',
            cause.toString(),
          ),
          TodoLoadSuccess(:final todos, :final failures) => _todoResults(
            todos,
            failures,
          ),
        };
      },
    ),
  );

  Widget _todoResults(List<Todo> todos, List<TodoLoadFailure> failures) {
    final searchFuture = _searchFor(todos);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Todoを検索',
              hintText: 'タイトルまたは #タグ',
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '検索をクリア',
                      onPressed: () {
                        _searchController.clear();
                        _updateSearch('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            controller: _searchController,
            onChanged: _updateSearch,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Todo>>(
            future: searchFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('検索中'),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return _searchError(snapshot.error.toString());
              }
              final sortedTodos = snapshot.data!;
              if (sortedTodos.isEmpty && failures.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'Todoはありません' : '検索結果がありません',
                  ),
                );
              }
              return _todoList(sortedTodos, failures);
            },
          ),
        ),
      ],
    );
  }

  Future<List<Todo>> _searchFor(List<Todo> todos) {
    if (_searchFuture == null ||
        _lastSearchQuery != _searchQuery ||
        !identical(_lastSearchTodos, todos)) {
      _lastSearchQuery = _searchQuery;
      _lastSearchTodos = todos;
      _searchFuture = TodoSearch(
        normalizeTags: widget.normalizeTags,
      ).apply(todos, _searchQuery).then(sortTodosByTitle);
    }
    return _searchFuture!;
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchFuture = null;
    });
  }

  Widget _searchError(String detail) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('タグ検索に失敗しました'),
            Text(detail),
            const Text('検索をやり直すか、フォルダーの状態を確認してください。'),
          ],
        ),
      ),
    ),
  );

  Widget _todoList(List<Todo> sortedTodos, List<TodoLoadFailure> failures) {
    final titleCounts = <String, int>{};
    for (final todo in sortedTodos) {
      titleCounts.update(todo.title, (count) => count + 1, ifAbsent: () => 1);
    }
    return ListView(
      children: [
        if (failures.isNotEmpty) _partialFailure(failures),
        for (final todo in sortedTodos)
          ListTile(
            title: Text(todo.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titleCounts[todo.title]! > 1)
                  Text(todo.note.id.relativePath),
                if (todo.tags.isNotEmpty)
                  Text(todo.tags.map((tag) => '#$tag').join(' ')),
              ],
            ),
            trailing: PopupMenuButton<String>(
              tooltip: '${todo.title}の操作メニュー',
              onSelected: (action) {
                if (action == 'edit') _openEdit(todo);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('編集')),
              ],
            ),
            onTap: () => _openDetails(todo),
            onLongPress: () => _openEdit(todo),
          ),
      ],
    );
  }

  Widget _partialFailure(List<TodoLoadFailure> failures) => Padding(
    padding: const EdgeInsets.all(16),
    child: Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('一部のノートを読み込めませんでした。権限とファイルを確認してください。'),
          for (final failure in failures)
            Text('${failure.path}: ${failure.reason}'),
        ],
      ),
    ),
  );

  Widget _loadError(String title, String detail) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Text(detail),
            const SizedBox(height: 8),
            const Text('フォルダーの設定とアクセス権を確認してください。'),
          ],
        ),
      ),
    ),
  );
}

Future<List<String>> _normalizeTags(List<String> tags) =>
    const TagNormalizer().normalize(tags);

List<Todo> sortTodosByTitle(List<Todo> todos) {
  final sorted = List<Todo>.of(todos);
  sorted.sort((left, right) {
    final titleOrder = _compareCodePoints(left.title, right.title);
    if (titleOrder != 0) return titleOrder;
    return _compareCodePoints(
      left.note.id.relativePath,
      right.note.id.relativePath,
    );
  });
  return List<Todo>.unmodifiable(sorted);
}

int _compareCodePoints(String left, String right) {
  final leftRunes = left.runes.iterator;
  final rightRunes = right.runes.iterator;
  while (leftRunes.moveNext()) {
    if (!rightRunes.moveNext()) return 1;
    final comparison = leftRunes.current.compareTo(rightRunes.current);
    if (comparison != 0) return comparison;
  }
  return rightRunes.moveNext() ? -1 : 0;
}
