import 'package:flutter/material.dart';

import 'features/todo/android_todo_writer.dart';
import 'features/todo/android_folder_reader.dart';
import 'features/todo/create_todo_screen.dart';
import 'features/todo/folder_access.dart';
import 'features/todo/todo_list.dart';
import 'features/todo/todo_create_repository.dart';
import 'features/todo/todo_repository.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Todo一覧',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: Builder(
      builder: (context) => TodoListScreen(
        loadTodos: _loadTodos,
        onOpenDetails: (_) => _showUnavailable(context, '詳細'),
        onOpenEdit: (_) => _showUnavailable(context, '編集'),
        onCreate: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => CreateTodoScreen(
              repository: _createTodoRepository(),
              onReselectFolder: () async {
                await AndroidFolderAccessSource().pickAndPersistFolder();
              },
            ),
          ),
        ),
      ),
    ),
  );
}

TodoCreateRepository _createTodoRepository() {
  return TodoCreateRepository(
    currentFolder: AndroidFolderAccessSource().currentFolder,
    readFolder: AndroidFolderReader().read,
    writeMarkdown: AndroidTodoWriter().createMarkdown,
  );
}

Future<TodoLoadResult> _loadTodos() async {
  final uri = await requireFolderAccess(AndroidFolderAccessSource());
  return TodoRepository(
    read: () => AndroidFolderReader().read(uri),
  ).loadTodos();
}

void _showUnavailable(BuildContext context, String featureName) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$featureName画面は別機能の公開境界で提供されます。')));
}
