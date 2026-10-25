---
title: コードコメントのガイドライン
impact: MEDIUM
impactDescription: コメントのノイズを抑え、重要な理由や制約を記録する
tags: comments, documentation, readability, dart
---

# コードコメントのガイドライン

## 基本原則

コメントは「何をするか」ではなく「なぜそうするか」を説明するために使います。コードから明らかな処理を言い換えるコメントは避けてください。

## コメントを付ける場合

- ObsidianのMarkdown形式を保持する必要など、コードだけでは明らかでないドメイン上の理由
- ファイルアクセスやプラットフォームAPIに関する非自明な制約
- 必要性が明確な回避策
- データ保護に影響する重要な判断

## コメントを避ける例

```dart
// Todoを読み込む
final todos = await repository.loadTodos();
```

## 適切なコメントの例

```dart
// 未知のMarkdown記法もユーザーの他のツールで使われる可能性があるため、
// 編集対象外の行は再生成せず元の内容を保持する
final updatedMarkdown = preserveUnchangedSections(original, editedFields);
```
