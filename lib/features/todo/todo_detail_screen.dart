import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'note.dart';
import 'todo_repository.dart';

class TodoDetailScreen extends StatefulWidget {
  const TodoDetailScreen({
    required this.loadDetail,
    required this.onTagSelected,
    required this.onOpenRelated,
    super.key,
  });

  final Future<TodoDetailLoadResult> Function() loadDetail;
  final ValueChanged<String> onTagSelected;
  final ValueChanged<TodoRelatedMarkdown> onOpenRelated;

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late final Future<TodoDetailLoadResult> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.loadDetail();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TodoDetailLoadResult>(
    future: _detailFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          appBar: AppBar(title: const Text('Todo詳細')),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('詳細を読み込み中'),
              ],
            ),
          ),
        );
      }

      if (snapshot.hasError) {
        return _loadError(context, snapshot.error.toString());
      }
      return switch (snapshot.data!) {
        TodoDetailLoadError(:final cause, :final path) => _loadError(
          context,
          [?path, cause].join(': '),
        ),
        TodoDetailLoadSuccess(:final detail) => _detail(context, detail),
      };
    },
  );

  Widget _loadError(BuildContext context, String detail) => Scaffold(
    appBar: AppBar(title: const Text('Todo詳細')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Todo詳細を読み込めませんでした'),
              const SizedBox(height: 8),
              Text(detail),
              const SizedBox(height: 8),
              const Text('フォルダーの設定とアクセス権を確認してください。'),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _detail(BuildContext context, TodoDetail detail) {
    final todo = detail.todo;
    return Scaffold(
      appBar: AppBar(title: Text(todo.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (todo.note.content.trim().isNotEmpty)
            MarkdownBody(
              data: todo.note.content,
              onTapLink: (text, href, title) {},
            ),
          if (todo.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in todo.tags)
                  ActionChip(
                    label: Text('#$tag'),
                    onPressed: () => widget.onTagSelected(tag),
                  ),
              ],
            ),
          ],
          if (detail.related.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('関連情報', style: Theme.of(context).textTheme.titleMedium),
            for (final reference in detail.related)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reference.title),
                subtitle: reference.failure == null
                    ? null
                    : Text('対象を開けませんでした: ${reference.failure}'),
                enabled: reference.canOpen,
                onTap: reference.canOpen
                    ? () => widget.onOpenRelated(reference)
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}

class TodoMarkdownPreviewScreen extends StatelessWidget {
  const TodoMarkdownPreviewScreen({required this.note, super.key});

  final Note note;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(note.title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (note.content.trim().isNotEmpty)
          MarkdownBody(data: note.content, onTapLink: (text, href, title) {}),
      ],
    ),
  );
}
