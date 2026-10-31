# Flutter Markdown Todoアプリ向けルール

このプロファイルは、`docs/requirements/requirements.md` に記載されたFlutter製Markdown Todoアプリに適用します。アプリはユーザーが指定したフォルダー内のMarkdownを参照・編集します。サーバー、API、認証、リレーショナルデータベースは前提としません。

## 適用ルール

作業対象に応じて、次のルールを適用します。複数該当する場合はすべて適用してください。

| 対象 | 適用ルール |
| --- | --- |
| `lib/**` の構成・機能間連携 | [architecture-vertical-slices.md](./architecture-vertical-slices.md)、[architecture-feature-boundaries.md](./architecture-feature-boundaries.md) |
| Markdown解析、ファイル入出力、データモデル | [data-markdown-repository.md](./data-markdown-repository.md)、[data-model-boundaries.md](./data-model-boundaries.md)、[data-markdown-compatibility.md](./data-markdown-compatibility.md) |
| Dart/Flutterコード全般 | [quality-simplicity.md](./quality-simplicity.md)、[quality-code-comments.md](./quality-code-comments.md) |
| 機能追加・バグ修正、`test/**`、`integration_test/**`、テスト変更 | [testing-strategy.md](./testing-strategy.md)、[testing-fakes.md](./testing-fakes.md) |
| 開発・検証コマンド | [reference-flutter-dev.md](./reference-flutter-dev.md) |

## 技術・要件との整合

- FlutterとDartを使用し、Androidアプリを対象とします。
- 永続データの正本は指定フォルダー内のMarkdownファイルです。
- Obsidian互換の `# TODO` タグ、階層タグ、`[[タイトル]]` リンクを保護します。
- Prisma、PostgreSQL、Node.js、React、tRPC、Trigger.devなど、このアプリに不要な技術やCal.diy固有のパス・コマンドは適用しません。
- 要件で保存形式や動作が定義されていない場合、既存のMarkdownを破壊する推測をせず、仕様で決めるべき事項として扱います。

## 適用外の参考ルール

`../` 直下には他の技術スタック向けの参考ルールが残っています。特にAPI、Prisma、Next.js、App Store連携、Trigger.devに関する内容は、このアプリに該当する仕様が追加されない限り適用しません。
