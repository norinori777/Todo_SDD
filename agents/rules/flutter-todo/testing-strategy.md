---
title: Flutterの各層に応じてテストする
impact: HIGH
impactDescription: Markdown処理、UI操作、ファイル連携の回帰を防ぐ
tags: testing, flutter, dart, widget-tests, integration
---

## Flutterの各層に応じてテストする

Flutter標準の `flutter_test` と `integration_test` を使い、変更した振る舞いに合った範囲で検証してください。別の言語やテストランナー向けのコマンド・モック方式を持ち込まないでください。

## テスト対象

- **単体テスト:** MarkdownのTodo判定、タグ階層、Wikiリンクの抽出、内容の保持、完了状態の変換
- **Widgetテスト:** Todo一覧、関連情報の展開、作成・編集フォーム、詳細プレビュー、入力検証
- **結合テスト:** フォルダー選択後の読み込み、作成・編集・完了保存、保存失敗時のエラー表示など主要フロー

## データ保護の確認

- 既存のMarkdownに対する更新は、対象外の内容を保持することを確認する
- 読み込み不可、書き込み不可、形式不正などの失敗をテストする
- 関連情報の作成で両方のノートを更新する場合は、片方のみ成功する失敗ケースも確認する
- プラットフォーム依存のファイル選択は、単体テストでは境界を置き換え、対応する結合テストで実機能を検証する

新規コードの一律なカバレッジ率を前提にせず、重要な振る舞いと失敗経路を意味のあるアサーションで検証してください。

## 主なコマンド

```bash
flutter analyze
flutter test
flutter test integration_test
```
