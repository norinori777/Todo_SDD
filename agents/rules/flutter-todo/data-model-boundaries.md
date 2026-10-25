---
title: Markdownデータと画面モデルの境界を明確にする
impact: HIGH
impactDescription: 解析・保存形式の変更を画面に波及させず、型安全性を保つ
tags: data, models, markdown, types, flutter
---

## Markdownデータと画面モデルの境界を明確にする

画面にMarkdownの生文字列や解析途中のMapをそのまま渡さず、タイトル、内容、タグ、関連リンク、完了状態などを表す型付きモデルを使用してください。

**避ける例:**

```dart
// UIがMarkdownの書式を直接解析し、Mapのキーにも依存している
final title = rawMarkdown.split('\n').first;
final isTodo = metadata['todo'] == true;
```

**推奨する例:**

```dart
class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.relatedLinks,
    required this.isCompleted,
  });

  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final List<String> relatedLinks;
  final bool isCompleted;
}
```

Markdownの解析・生成はデータ境界で行い、モデル変換を型付きのDartコードで明示します。API用DTO、Prisma型、Zodなどのサーバー技術は導入しません。

元ファイルに存在する未対応のMarkdown要素は、仕様上必要な変換でない限り保持し、モデル変換時に黙って破棄しないでください。
