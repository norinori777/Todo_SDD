---
description: "Todo作成画面の実装タスク"
---

# Tasks: Todo作成画面

**Input**: Design documents from `/specs/002-todo-create/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/todo-create.md, quickstart.md

**TDD**: 振る舞いを変更する各タスクで `.github/skills/tdd/SKILL.md` に従う。要件からテストリストを作り、各タスク内で一つずつRed（期待する振る舞いの失敗を実測）→Green（最小実装）→Refactorを完了する。Redを実測できない場合は実装に進まず、理由と残るリスクを報告する。Setupとドキュメント・設定のみのタスクはRedサイクルを要しない。

**Organization**: タスクは優先度順のユーザーストーリーごとに整理する。既存のFlutterアプリと読込境界を再利用し、Todo固有の作成処理は `lib/features/todo/`、SAFの作成処理はAndroid MethodChannel境界に置く。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 別ファイルを扱い、未完了タスクへの依存がない場合に限る。
- **[Story]**: ユーザーストーリータスクに `[US1]`、`[US2]`、`[US3]` を付ける。
- 各タスクに変更対象またはテスト対象の正確なファイルパスを記載する。

## Phase 1: Setup

**Purpose**: 作成画面のMarkdownプレビュー依存を整える。

- [X] T001 `pubspec.yaml` に `flutter_markdown_plus` を追加し、依存解決結果を `pubspec.lock` に反映する（設定作業のためRedサイクル不要）。

---

## Phase 2: Foundational

**Purpose**: 全ユーザーストーリーをブロックする新規の共通振る舞いがある場合に実装する。

既存のFlutterアプリ、Todo一覧、フォルダー読込境界、テスト基盤を再利用できるため、この機能で独立したFoundationalタスクは設けない。新しい作成・書込振る舞いは、それを必要とするUS1のTDDサイクルで実装する。

**Checkpoint**: T001完了後、US1に着手できる。

---

## Phase 3: User Story 1 - Todoを作成する (Priority: P1) 🎯 MVP

**Goal**: 一覧から作成画面を開き、タイトルと任意の本文を持つ新しいTodoを保存して一覧に反映する。既存ファイルを変更せず、失敗時は入力を保持する。

**Independent Test**: 保存先を設定したAndroid環境で、タイトルのみ／本文ありのTodoを作成する。保存先直下に `<title>.md` が1件作られ、`#todo` により一覧に表示されること、空白・不正タイトル、同名ファイル、書込権限不足、書込失敗では既存内容が変わらず画面に理由が表示されることを確認する。

### TDD cycles for User Story 1

- [X] T002 [US1] TDD: `test/features/todo/todo_create_repository_test.dart` でRedとして空・空白タイトル、`.`、`..`、`/`、`\`、U+0000〜U+001F、U+007Fを拒否する失敗を確認し、`lib/features/todo/todo_create_repository.dart` でGreen、Refactorする。タイトルを自動変更せず、Windows固有の禁止文字・予約名を一律拒否しないこともテストする。
- [X] T003 [US1] TDD: `test/features/todo/todo_create_repository_test.dart` でRedとして本文先頭の独立した `#todo` 行の欠落・重複を検出し、`lib/features/todo/todo_create_repository.dart` でGreen、Refactorする。空本文、既に先頭の独立行が `#todo` の本文、コードフェンスから始まる本文を含め、入力本文を正規化・書き換えないことを確認する。
- [X] T004 [US1] TDD: `test/features/todo/todo_create_repository_test.dart` でRedとして保存先直下の同名 `.md` を拒否できない失敗を確認し、`lib/features/todo/todo_create_repository.dart` でGreen、Refactorする。直下の既存ファイル内容を保持し、サブフォルダーにだけ同名Markdownがある場合は作成を許可する。
- [X] T005 [US1] TDD: `test/features/todo/todo_create_repository_test.dart` でRedとして保存先未設定、権限拒否、書込失敗が成功結果になるケースを確認し、`lib/features/todo/todo_create_repository.dart` と `lib/features/todo/android_todo_writer.dart` でGreen、Refactorする。`TodoCreateOutcome` の `FolderUnavailable`、`PermissionDenied`、`WriteFailure` を区別し、失敗理由を呼出元へ伝える。
- [X] T006 [P] [US1] TDD: `integration_test/todo_create_test.dart` でRedとしてフォルダー選択時にSAFの読取・書込権限を要求・永続化できない失敗を確認し、`lib/features/settings/folder_access.dart` と `android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt` でGreen、Refactorする。Android結合検証で選択直後とアプリ再起動後の権限保持、権限拒否・失効時の失敗通知を確認する。既存の読取専用URIから作成を試みた場合は作成画面から再選択でき、選択キャンセル時は旧URIを維持し、新しい読取・書込権限の永続化後にのみ保存先を更新することも検証する。併せて不正／非対応provider、直下以外の相対パス、既存名への作成を拒否し、既存Documentを開いたり上書きしたりしないことを確認する。
- [X] T007 [US1] TDD: `integration_test/todo_create_test.dart` でRedとして新規Markdownが要求名・相対パス・UTF-8内容で作成されず、提供元が作成を拒否した理由が返らない失敗を確認し、`android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt` と `lib/features/todo/android_todo_writer.dart` でGreen、Refactorする。SAFの作成Document名が要求名と一致することを確認し、成功時は作成相対パスを返し、提供元の拒否は分類・詳細を保って呼出元へ返す。
- [X] T008 [US1] TDD: `integration_test/todo_create_test.dart` でRedとしてopen/write/close失敗や要求名と異なるDocument作成時の後始末・状態通知を検出し、`android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt` と `lib/features/todo/android_todo_writer.dart` でGreen、Refactorする。今回作成したDocumentだけを削除し、削除失敗時は残存Documentの相対パスを含む失敗結果を返す。残存状態を成功扱いしない。
- [X] T009 [US1] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとして一覧の作成操作から画面が開かず、作成成功後に閉じて一覧を再読込できない失敗を確認し、`lib/features/todo/create_todo_screen.dart` と `lib/main.dart` でGreen、Refactorする。既存の一覧 `onCreate` 境界と再読込動作を維持する。
- [X] T010 [US1] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとして一般的な作成失敗時に画面が閉じる、入力が消える、または提供元の拒否理由が伝わらない失敗を確認し、`lib/features/todo/create_todo_screen.dart` でGreen、Refactorする。タイトルと本文を保持して失敗を表示し、保存中の重複送信を防ぎ、失敗後は再試行できることを確認する。
- [X] T011 [US1] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとして読取専用／失効URIから再選択を開始できず、キャンセル時に旧設定または入力を失う失敗を確認し、`lib/features/todo/create_todo_screen.dart` と `lib/features/settings/folder_access.dart` でGreen、Refactorする。既存のフォルダー選択フローを開き、新しい読取・書込権限の永続化後にのみ設定URIを更新する。
- [X] T012 [US1] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとして後始末失敗後に残ったDocumentの場所・状態を利用者が確認できない失敗を確認し、`lib/features/todo/create_todo_screen.dart` でGreen、Refactorする。残存相対パス、不完全ファイルであること、保存先での確認・手動削除を案内し、作成成功として画面を閉じない。

**Checkpoint**: US1単独で保存成功・一覧反映および代表的な入力、競合、権限、I/O失敗を検証できる。

---

## Phase 4: User Story 2 - 内容を編集・プレビューする (Priority: P2)

**Goal**: Markdown本文を入力し、内容を失わずに編集表示とプレビュー表示を切り替える。

**Independent Test**: 見出し、リスト、コードブロックを含む本文を入力し、プレビューを確認して編集表示へ戻す。本文とタイトルが保持され、プレビュー中に本文を編集できず、空本文でも画面操作・作成を妨げないことを確認する。

### TDD cycles for User Story 2

- [X] T013 [US2] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとしてMarkdown本文がプレビュー表示されず、空本文のプレビューが失敗するケースを確認し、`lib/features/todo/create_todo_screen.dart` でGreen、Refactorする。`flutter_markdown_plus` を使い、空本文でもタイトル入力・作成を可能にする。
- [X] T014 [US2] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとして表示切替でタイトル・本文が失われる、またはプレビュー中に編集できる失敗を確認し、`lib/features/todo/create_todo_screen.dart` でGreen、Refactorする。入力／プレビューを往復した後も値を保持し、プレビューでは本文を編集不可にする。

**Checkpoint**: US2の独立テストでMarkdown表示、空本文、値の保持、プレビュー中の編集不可を確認できる。

---

## Phase 5: User Story 3 - タグや既存ノートへのリンクを入力する (Priority: P2)

**Goal**: 保存先とサブフォルダー内の既存Markdownからタグ・ノート候補を表示し、選択またはタグの新規入力を本文へ反映する。

**Independent Test**: タグ階層を含むMarkdownと同名タイトルを含む複数Markdownを用意し、部分一致候補、選択時の挿入、候補なしEnter時のタグとWikiリンクの異なる動作をWidgetテストで確認する。

### TDD cycles for User Story 3

- [X] T015 [P] [US3] TDD: `test/features/todo/todo_create_repository_test.dart` でRedとして登録済みタグとMarkdownタイトル候補が取得・抽出されない失敗を確認し、`lib/features/todo/todo_create_repository.dart` でGreen、Refactorする。タグ階層全体を候補として扱い、保存先とサブフォルダーを対象にし、重複タイトルのノートは個別候補として保持する。
- [X] T016 [US3] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとして本文先頭または空白後の未エスケープ`#`で候補が表示・絞り込みされず、コード内・エスケープ内または非空白文字直後で誤って候補が表示される失敗を確認する。検索文字列を`#`から空白または本文末尾までとし、候補選択でカーソルを含むタグトークン全体を`#<タグ>`に置換して周囲の本文を保持することをテストし、`lib/features/todo/create_todo_screen.dart` でGreen、Refactorする。一致候補なしのEnterでは入力中タグを新しいタグとして本文に確定する。
- [X] T017 [US3] TDD: `test/features/todo/create_todo_screen_test.dart` でRedとして未エスケープ`[[`によるタイトル候補の絞り込み・挿入ができず、コード内・エスケープ内でも候補が表示される、または候補なしEnterでリンクが追加される失敗を確認する。検索文字列を`[[`から同じ行の最初の`]]`または行末までとし、候補選択でカーソルを含むWikiリンクトークン全体を`[[<タイトル>]]`に置換して周囲の本文を保持することをテストし、`lib/features/todo/create_todo_screen.dart` でGreen、Refactorする。候補なしEnterでは何も挿入しない。

**Checkpoint**: US3の独立テストでタグとノートの候補・選択・候補なし時の動作をそれぞれ確認できる。

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 検証資料を実装に合わせ、全体の回帰と静的解析を確認する。

- [X] T018 `specs/002-todo-create/quickstart.md` の前提条件、対象テスト、SAF読取・書込権限と失敗ケースの記載を実装結果に合わせて更新する。
- [X] T019 `specs/002-todo-create/quickstart.md` の手順に従い、対象Flutterテスト、`flutter analyze`、Android環境で `flutter test integration_test` を実行して結果を確認する。Android実機・エミュレーターを利用できない場合は、未実施項目と残るリスクを記録する。

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001は依存追加のみで、ストーリーの振る舞い変更には依存しない。
- **Foundational (Phase 2)**: 独立した新規タスクなし。既存アプリ・読込・テスト基盤を利用する。
- **User Stories (Phase 3+)**: US1はT001完了後に開始する。US2とUS3はUS1の作成画面・Repository境界が成立した後に開始する。
- **Polish (Phase 6)**: 対象とする全ストーリーの完了後に行う。

### User Story Dependencies

- **US1 (P1)**: T001後に開始可能。US2・US3には依存しない。T006は仕様化済みのMethodChannel契約に基づき、T002～T005のDart Repositoryサイクルと別ファイルで並行可能。T007・T008はT006完了後、T009・T010はDart作成結果とSAF書込境界が揃ってから実施する。
- **US2 (P2)**: US1で作成画面の骨格ができた後に開始する。T013とT014は同じ画面・Widgetテストを変更するため順番に実施する。
- **US3 (P2)**: US1の作成Repositoryと画面ができた後に開始する。T015はUS2のプレビュー用画面変更（T013・T014）とファイルが分離しているため並行可能。T016とT017は同じ画面・Widgetテストを変更するため順番に実施する。

### Within Each User Story

- 要件・契約から正常系、境界値、失敗系、既存データ保護のテストリストを作る。
- 一度に一つの振る舞いだけを選び、期待する失敗を実測してから最小実装し、Greenを保ってRefactorする。
- テスト失敗がコンパイルエラーや環境エラーの場合はRedとして扱わず、原因を解決するか制約とリスクを報告する。
- 既存のMarkdown・一覧動作を維持する回帰確認を各該当サイクルに含める。

### Parallel Opportunities

- US1: T006（Android SAF境界）は、T001完了後、T002～T005のRepositoryテスト・実装と別ファイルで並行できる。例:
  - `T002` → `T003` → `T004` → `T005`: `lib/features/todo/todo_create_repository.dart` と `test/features/todo/todo_create_repository_test.dart` を順番に実施
  - `T006`: `lib/features/settings/folder_access.dart`、`android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt`、`integration_test/todo_create_test.dart`
- US2: 同じWidgetと画面ファイルを使うため、T013・T014間の安全な並行タスクはない。
- US3: US1完了後、T015（Repository候補抽出）とT013～T014（プレビュー画面）は別ファイルで並行できる。T016・T017は同じ画面ファイルを変更するため直列にする。
- ストーリー全体を無条件に並列化しない。共有ファイルと上記依存を避けて実行する。

---

## Parallel Examples

### User Story 1

```text
並行可能（T001完了後）:
- T002 → T003 → T004 → T005: Dart Repositoryの検証・本文構築・競合・失敗結果を直列に実施
- T006: Android SAFの権限・範囲・既存Document拒否

直列: T006 → T007 → T008 → T009 → T010
```

### User Story 2

```text
T013 → T014 の順に実行する（同じWidgetテストと画面ファイルを変更）。
```

### User Story 3

```text
US1完了後、T015（候補抽出）はT013～T014（プレビュー）と並行可能。
T015完了後、T016 → T017 の順に実行する。
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001でMarkdownプレビュー依存を準備する。
2. Foundationalに新規タスクがないことを確認し、US1を完了する。
3. **STOP and VALIDATE**: タイトルのみ／本文ありの作成、一覧反映、空白・不正タイトル、直下競合、サブフォルダー同名、保存先・権限・書込失敗をUS1単独で検証する。
4. Android統合検証が利用可能な環境でSAFの直下作成・UTF-8書込・失敗時の後始末を確認する。

### Incremental Delivery

1. T001とUS1を完了し、作成のMVPを検証する。
2. US2を追加し、Markdownプレビューと入力保持を独立検証する。
3. US3を追加し、タグ・ノート候補を独立検証する。
4. T018～T019で検証資料と全体の回帰を確認する。

---

## Notes

- `[P]` は異なるファイルを使い、未完了タスクへの依存がないタスクだけに付ける。
- `[US1]`、`[US2]`、`[US3]` はそれぞれspec.mdのストーリーに対応する。
- 各TDDタスクは記載されたテストパスでRedを実測し、実装パスでGreen、Refactorを完了する。
- 既存ファイルは上書き・破壊しない。失敗時の残存状態も検証する。
