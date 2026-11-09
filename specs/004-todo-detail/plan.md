# 実装計画: Todo詳細画面

**ブランチ**: `004-todo-detail` | **日付**: 2026-11-09 | **仕様**: [spec.md](./spec.md)

## 概要

Todo一覧で選択したTodoを参照専用の詳細画面に表示し、タイトル、Markdown本文、タグと、本文から参照される関連Markdownのタイトルを確認できるようにする。既存のTodo機能境界、Markdown読込、`flutter_markdown_plus`を再利用し、Wikiリンクの解決・失敗通知はデータアクセス境界に置く。関連文書は詳細プレビューで開き、戻る操作は画面スタックを通じて直前の画面へ戻す。タグ操作ではTodo一覧をそのタグで絞り込む。

詳細画面ではファイルを変更せず、編集・削除・関連情報の作成、外部リンクの起動は行わない。

## 技術コンテキスト

- **言語 / バージョン**: Dart 3.11.5、Flutter 3.41.7。既存のAndroidネイティブ連携はKotlin。
- **主な依存**: Flutter Material、既存の`flutter_markdown_plus`、`path`、`yaml`、`flutter_test`、`integration_test`。新規依存は追加しない。
- **保存**: 設定済みフォルダー内のMarkdownを正本として読み取る。詳細画面からの保存、DB、サーバー、外部送信はない。
- **テスト**: `flutter_test`の単体・Widgetテスト、`flutter test integration_test`によるAndroid利用者フロー、`flutter analyze`。
- **対象 / 種別**: Android API 37以降のFlutterモバイルアプリ。API 37は現在の`android/app/build.gradle.kts`の`minSdk`、`targetSdk`、`compileSdk`に基づく。
- **性能**: 詳細画面固有の遅延目標は仕様にない。SC-001の20件以上のTodoで選択内容の対応を検証する。描画時に一覧全体を再解析せず、詳細に必要な対象だけを表示する。
- **制約**: 選択されたTodoの内容と指定フォルダー内のMarkdownのみ参照する。読み込み失敗を空データとして扱わず、曖昧なリンク先を勝手に選ばない。表示は参照専用とし、外部リンクを起動しない。
- **規模 / 範囲**: Todo一覧からの遷移、Todo詳細、直接参照されたMarkdownの詳細プレビュー、タグによる一覧絞り込み。CRUDの新規実装やAndroidネイティブのファイルアクセス変更は対象外。

### 既存統合の調査結果

- `TodoListScreen`は選択された`Todo`を`onOpenDetails`境界へ渡し、詳細から戻ると検索条件を維持して一覧を再読込する。`main.dart`の詳細遷移は現在未実装通知のため、詳細画面への遷移に置き換える。詳細Repositoryは選択Todoを指定フォルダーから再読込し、同じ`NoteId`の内容を表示する。見つからない・読めない場合は空表示や別Todoへの差し替えをせず失敗状態にする。
- `Todo`は`Note`、`NoteId`、タグを持ち、本文は`Note.content`にある。既存の`AndroidFolderReader`は読込成功、部分失敗、全体失敗を区別して返す。
- 作成画面は`flutter_markdown_plus`の`MarkdownBody`でプレビューする。同パッケージはインラインHTMLを描画せず、リンクを自動で開かない。Wikiリンクはデータ境界で別に抽出し、関連情報一覧からアプリ内遷移させる。Markdown本文中の標準リンクなど、仕様で定義されない宛先は開かない。
- 一覧機能のリンク契約にある、設定フォルダー起点の直接リンク解決、複数候補の識別、未解決・読込不能時に誤ったノートを開かない規則を共有する。現状のコードにはWikiリンク解決器がないため、実装時に既存のMarkdownデータ境界へ最小限の解析・解決処理を追加する。
- 詳細からのタグ操作は一覧検索の`#タグ`形式と既存のタグ照合規則を使う。通常の戻る操作では現在の一覧インスタンスと検索条件を維持する。

## 憲章チェック

### Phase 0 前ゲート

| 原則 | 判定 | 計画への反映 |
|---|---|---|
| I. 要件とユーザーデータの保護 | PASS | 指定フォルダー内を読み取り、リンク不解決・読み込み失敗を通知する。データを書き換えず、外部送信もしない。 |
| II. 機能単位のアーキテクチャ | PASS | 画面とTodo固有のデータ処理を`lib/features/todo/`に置き、`main.dart`は遷移を接続する。 |
| III. シンプルで保守しやすい実装 | PASS | 既存のMarkdown表示依存とファイルアクセス境界を再利用し、DB・サーバー・外部リンク起動を追加しない。 |
| IV. 振る舞いとデータ保護を重視したテスト | PASS | 実装時はTDDに従い、表示、誤リンク防止、失敗状態、戻る・タグ遷移を単体・Widget・Android結合で検証する。 |
| V. 日本語でのコミュニケーション | PASS | 計画、契約、検証ガイドと利用者向けエラーを日本語にする。 |

**ゲート結果**: Phase 0前の憲章違反なし。仕様の未解決事項はなく、SDK、既存依存、ストレージ境界、テスト手段はリポジトリ内で確認済み。

## プロジェクト構成

### 設計成果物

```text
specs/004-todo-detail/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── todo-detail.md
└── tasks.md              # /speckit-tasksで作成
```

### ソース構成（既存・予定）

```text
lib/
├── main.dart
└── features/
    └── todo/
        ├── todo_list.dart
        ├── todo_repository.dart
        ├── note.dart
        ├── folder_reader.dart
        ├── markdown_parser.dart
        ├── todo_detail_screen.dart       # 予定
        └── todo_detail_repository.dart   # 必要な場合のみ追加

test/features/todo/
├── todo_detail_screen_test.dart          # 予定
└── todo_detail_repository_test.dart      # 予定

integration_test/
└── todo_detail_test.dart                 # 予定
```

**構成判断**: 既存のFlutter単一アプリと`features/todo/`の機能境界を維持する。詳細画面のUI、リンク抽出・解決、およびタグ選択時の一覧遷移を既存の公開境界に統合する。実装時に既存Repositoryで表現できる小さな責務のために新規クラスやファイルを増やさず、Markdown解析・ファイル操作をWidgetへ持ち込まない。画面遷移は既存のNavigator構成を使い、Androidネイティブ層は変更しない。

## 設計後の憲章チェック

| 原則 | 判定 | 設計後の確認 |
|---|---|---|
| I. 要件とユーザーデータの保護 | PASS | 画面は読み取り専用。Wikiリンクは指定フォルダー内で解決し、未解決・複数候補・読み込み失敗では誤った内容を表示しない。外部宛先は起動しない。 |
| II. 機能単位のアーキテクチャ | PASS | Todo詳細とMarkdownリンク解決をTodo機能内に配置し、画面は型付きモデルとコールバック境界を利用する。 |
| III. シンプルで保守しやすい実装 | PASS | 既存のMarkdown表示パッケージとSAF読取実装を再利用する。別DB、API、Markdown全体の独自レンダラーは作らない。 |
| IV. 振る舞いとデータ保護を重視したテスト | PASS | Todo選択、空データ、リンク解決失敗、タグ階層、一覧復帰をRed-Green-Refactorで検証し、実機フローも確認する。 |
| V. 日本語でのコミュニケーション | PASS | 成果物と失敗時の状況・対処表示は日本語とする。 |

**設計後ゲート結果**: 憲章違反なし。追加パッケージ、ネイティブ保存処理、外部インターフェースを必要としない。

## 複雑さの記録

憲章違反なし。追加の複雑さを正当化する項目はない。
