---
title: 機能単位でコードを整理する
impact: HIGH
impactDescription: 関連コードをまとめ、変更やテストを容易にする
tags: architecture, flutter, features, organization
---

## 機能単位でコードを整理する

コードは技術レイヤーだけでなく、ユーザーが認識する機能ごとに整理します。Todoと設定に関する処理を各機能の範囲にまとめ、共通処理だけを共通領域に置いてください。

**避ける構成:**

```text
lib/
  all_screens/
  all_models/
  all_services/
  all_repositories/
```

この構成では、ひとつの機能に必要なコードが複数の場所に散らばり、変更範囲や依存関係を追いにくくなります。

**推奨する構成例:**

```text
lib/
  core/
    markdown/
    file_access/
  features/
    todo/
      data/
      domain/
      presentation/
    settings/
      data/
      domain/
      presentation/
```

実際の構成は既存のプロジェクト規約に合わせます。小さな機能に不要な層やファイルを作らず、次の責務が追跡できることを優先してください。

- ドメイン: Todoや関連情報のルールと型
- データ: Markdownの解析、保存、ファイル操作
- 画面: 一覧、作成、詳細、編集、設定のUI
- テスト: 対象機能の単体・Widget・結合テスト

## 基本方針

- 機能固有のコードは、その機能のディレクトリ内に置く
- Markdown解析や選択フォルダーへのアクセスなど、機能横断の処理は `core/` に置く
- 実際に必要な複雑さに合わせて構成し、将来の仮定だけで抽象化を増やさない
