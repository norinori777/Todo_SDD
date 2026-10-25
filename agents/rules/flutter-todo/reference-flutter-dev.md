---
title: Flutterローカル開発と検証
impact: LOW
impactDescription: Flutter開発に必要な基本コマンドを確認できる
tags: reference, flutter, development, setup
---

# Flutterローカル開発と検証

## 環境の確認

```bash
flutter doctor
```

## 依存関係と品質チェック

```bash
flutter pub get
flutter analyze
flutter test
```

結合テストがある場合は、プロジェクトでサポートするAndroidエミュレーターまたは端末上で実行します。

```bash
flutter test integration_test
```

## Androidビルド

```bash
flutter build apk
```

## ファイルアクセス確認

- アプリ設定で選択されたMarkdownフォルダー以外を読み書きしない
- アクセス権限が取り消された場合やフォルダーが利用できない場合は、状況と再設定方法をユーザーに示す
- Markdownの内容やファイル情報を外部送信する仕組みを、別途承認された要件なしに追加しない
