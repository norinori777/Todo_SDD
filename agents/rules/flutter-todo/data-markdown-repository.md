---
title: Markdownファイルアクセスをリポジトリに集約する
impact: HIGH
impactDescription: ファイル形式と画面ロジックの結合を防ぎ、安全な保存を実現する
tags: data, repository, markdown, filesystem, flutter
---

## Markdownファイルアクセスをリポジトリに集約する

Markdownファイルの探索、読み込み、作成、更新は、画面から直接行わず、明確なデータアクセス境界に集約してください。画面やドメイン処理はファイルシステムAPIやMarkdown文字列の解析詳細を知る必要はありません。

**避ける例:**

```dart
// Widget内でファイルを読み、Markdown文字列を直接解析している
final content = await File(path).readAsString();
final title = content.split('\n').first.replaceFirst('# ', '');
```

**推奨する例:**

```dart
abstract interface class TodoRepository {
  Future<List<Todo>> loadTodos();
  Future<Todo> createTodo(TodoDraft draft);
  Future<void> updateTodo(Todo todo);
  Future<void> completeTodo(TodoId id);
}
```

Markdownファイルを扱う実装は、この契約を実装し、ファイルの読み書きと解析・直列化を担います。具体的なフォルダー選択やアクセス許可の扱いは、既存のFlutterプラットフォーム構成に沿って実装してください。

## ルール

- リポジトリはファイルアクセスとMarkdown形式との変換を担当する
- ビジネスルールや画面表示の判断をリポジトリに埋め込まない
- 読み込み、解析、書き込みの失敗を成功扱いにせず、呼び出し側で適切に表示できるエラーとして伝える
- 複数ファイルを更新する操作では、部分保存や失敗時の状態を考慮し、整合性を保つ方法を明示する
- データベースやサーバーAPIを、要件上必要でない限り追加しない
