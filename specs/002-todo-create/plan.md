# Implementation Plan: Todo作成画面

**Branch**: `002-todo-create` | **Date**: 2026-11-08 | **Spec**: [spec.md](./spec.md)

**Input**: [Feature specification](./spec.md)

## Summary

Todo一覧の作成操作から、タイトル・Markdown本文の入力、入力／プレビュー切替、タグと既存Markdownの候補選択を備えた作成画面を開く。Todoデータ境界でタイトルを検証し、本文先頭の独立した`#todo`タグを重複なく付与して、設定済みフォルダー直下に新しい`.md`ファイルを作成する。既存ファイルを上書きしないため、AndroidのStorage Access Framework (SAF) 書き込みをネイティブ境界に集約し、失敗理由を画面へ返す。

保存済みURIが読取専用または書込権限を失っている場合は、作成画面から既存のフォルダー選択フローを開いて再選択できるようにする。書込失敗後の後始末にも失敗してDocumentが残った場合は、その場所を示して利用者に確認・削除を案内する。

## Technical Context

**Language/Version**: Dart 3.11.5 / Flutter 3.41.7、Androidネイティブ連携は既存Kotlin

**Primary Dependencies**: Flutter Material、既存の`path`・`yaml`、Markdownプレビュー用の`flutter_markdown_plus`（採用候補。実装時に現在のSDKで依存解決と解析を確認する）

**Storage**: 設定済みAndroid SAFツリーフォルダー内のMarkdownファイル。Markdownを永続データの正本とする

**Testing**: `flutter_test`によるユニット／Widgetテスト、`integration_test`によるAndroid SAF保存フロー、`flutter analyze`

**Target Platform**: Android

**Project Type**: Flutterモバイルアプリ

**Performance Goals**: 候補表示・絞り込みに固定時間基準を設けない。仕様の上限例であるMarkdown 1,000件を候補データに含めても入力と作成を継続できる

**Constraints**: 保存先直下のみへ新規作成し、既存ノートを上書きしない。保存先外へのアクセス、タイトルの自動変更、保存失敗の成功扱いを禁止する。保存先未設定・権限不足・提供元エラーを利用者に伝え、入力値を保つ。既存の読取専用URIは作成画面から再選択を案内し、新しい読取・書込権限の永続化に成功するまで設定と入力を保持する。書込失敗後に残存Documentの削除にも失敗した場合は相対パスを示し、利用者による確認・削除を案内する

**Scale/Scope**: 作成画面、既存Todo一覧からの遷移、タグ／ノート候補、Markdownプレビュー、保存境界とテスト。設定画面や詳細・編集画面の新規実装は対象外

### Existing Integration Findings

- `TodoListScreen`には`onCreate`境界があり、現在の`main.dart`は作成操作を未実装通知に接続している。作成画面へ遷移し、成功後に一覧を再読込する。
- `TodoRepository`、Markdown解析、`AndroidFolderReader`、`AndroidFolderAccessSource`は`features/todo/`と`features/settings/`にある。候補データとTodo作成処理はこの機能境界を再利用し、Widgetへファイル操作を持ち込まない。
- 現在のAndroid `MainActivity`は保存済みURIの読取権限とフォルダー読込を扱うが、書込操作はない。作成に必要なSAFの読取・書込権限確認、新規Document作成、書込失敗の返却を追加する。既存のフォルダー選択／設定UIを新設するのではなく、既存の保存先設定境界で書込権限を取得・永続保持する。以前に読取専用で保存したURIでは、作成画面から既存のフォルダー選択フローを開いて再選択を案内し、新しい権限の取得・永続化後にのみ設定URIを更新する。キャンセル時は旧設定と入力を保つ。タスクT006で`folder_access.dart`と`MainActivity.kt`の取得処理、既存URIからの再選択、および再起動後を含む権限保持を検証する。
- 書込失敗や不一致Documentの後始末に失敗した場合は、残存Documentの相対パスを型付きエラーで画面まで返し、利用者に不完全ファイルの確認・手動削除を案内する。作成成功へ遷移せず、タイトルと本文を保持する。
- 仕様が参照する既存資料は[要件](../../docs/requirements/requirements.md)、[作成画面イメージ](../../docs/screen_image/02-todo-create.svg)、[プレビュー画面イメージ](../../docs/screen_image/03-todo-preview.svg)。仕様本文の画像ディレクトリ名は実ファイルの`screen_image`に合わせる。

## Constitution Check

### Pre-Design Gate

| 原則 | 判定 | 計画への反映 |
|---|---|---|
| I. 要件とユーザーデータの保護 | PASS | 保存先直下のみ作成し、同名ファイルを拒否する。SAFの権限・範囲をネイティブ境界で検証し、失敗を明示する |
| II. 機能単位のアーキテクチャ | PASS | Todo固有の画面・モデル・Repositoryを`lib/features/todo/`に置き、Androidファイル操作は既存のプラットフォーム境界に集約する |
| III. シンプルで保守しやすい実装 | PASS | サーバーやDBを追加しない。Markdown表示は標準構文を自作せず、拡張可能な小規模レンダラーを利用する |
| IV. 振る舞いとデータ保護を重視したテスト | PASS | 実装時はTDDスキルに従い、タイトル検証、タグ挿入、重複拒否、書込失敗、Widget、Android保存を段階的に検証する |
| V. 日本語でのコミュニケーション | PASS | 計画・契約・検証ガイドを日本語で作成する |

## Project Structure

### Documentation (this feature)

```text
specs/002-todo-create/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── todo-create.md
```

### Source Code (repository root)

```text
lib/
├── main.dart
└── features/
    ├── settings/
    │   └── folder_access.dart
    └── todo/
        ├── create_todo_screen.dart
        ├── todo_repository.dart
        ├── android_folder_reader.dart
        └── android_todo_writer.dart

android/app/src/main/kotlin/com/example/todo_sdd/
└── MainActivity.kt

test/features/todo/
├── create_todo_screen_test.dart
└── todo_create_repository_test.dart

integration_test/
└── todo_create_test.dart
```

**Structure Decision**: 既存のFlutter単一アプリ構成と機能単位の配置を維持する。Todo画面とTodo作成用データ契約は`features/todo/`に置き、SAFのDocument作成は既存のMethodChannel境界を通してAndroidネイティブ層で行う。上記は計画上の対象候補であり、実装時に既存ファイルへ統合できる小さな責務は不要な分割を避ける。

## Post-Design Constitution Check

| 原則 | 判定 | 設計後の確認 |
|---|---|---|
| I. 要件とユーザーデータの保護 | PASS | `TodoCreateOutcome`で競合・権限・保存失敗を成功と分離する。ネイティブ側で保存先ツリー内の直下だけを扱い、作成時は既存Documentを書き換えない |
| II. 機能単位のアーキテクチャ | PASS | 画面は候補と作成の型付き境界を利用し、URI・ContentResolver・Markdown直列化の詳細を持たない |
| III. シンプルで保守しやすい実装 | PASS | Markdown依存はプレビューに限定し、既存の保存方式・ファイル形式・機能分割を維持する |
| IV. 振る舞いとデータ保護を重視したテスト | PASS | 失敗経路を含む単体・Widget・Android結合検証を定義した。実装時にTDDを実施する |
| V. 日本語でのコミュニケーション | PASS | 成果物を日本語で統一する |

**Gate Result**: 設計上の憲法違反はない。既存のSAF設定が読取専用である場合、作成画面から既存のフォルダー選択フローを開いて再選択させ、読取・書込権限の永続化が成功するまで旧設定を保持する。書込失敗後に残存Documentの削除にも失敗した場合は、その相対パスと手動削除の案内を利用者に示す。これらの復旧・通知と再起動後の権限保持は契約およびタスクT006、T008、T010の検証ゲートとし、権限不足や残存状態を成功扱いしない。
