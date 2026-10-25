---
title: 気の利いた複雑さより明快さを優先する
impact: HIGH
impactDescription: 認知負荷を減らし、保守性を高める
tags: quality, simplicity, readability, dart
---

## 気の利いた複雑さより明快さを優先する

目指すのは、短く見せるための技巧ではなく、すばやく読んで理解できるDartコードです。単純なMarkdown Todoアプリに、要件のないサーバー層、データベース、汎用プラグイン基盤を追加しないでください。

実装前に確認します。
- 今必要なユーザー要件を解決しているか
- 根拠のない将来のユースケースを作り込んでいないか
- より単純で安全な代替案がないか

**避ける例:**

```dart
// 読みづらい処理を一つの式に詰め込む
final grouped = items.fold(<String, List<Todo>>{}, (map, item) =>
  map..putIfAbsent(item.tag, () => []).add(item));
```

**推奨する例:**

```dart
final Map<String, List<Todo>> todosByTag = {};

for (final todo in todos) {
  todosByTag.putIfAbsent(todo.primaryTag, () => <Todo>[]).add(todo);
}
```

シンプルさは必要な機能を省くことではありません。要件を満たし、エラーやデータ保護を適切に扱う範囲で、最も分かりやすい設計を選んでください。
