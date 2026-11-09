---
description: "Todo詳細画面の実装タスク"
---

# Tasks: Todo詳細画面

**Input**: 設計成果物 `specs/004-todo-detail/` の `plan.md`、`spec.md`、`data-model.md`、`contracts/todo-detail.md`、`research.md`、`quickstart.md`

**前提**: 既存のFlutterアプリ、Todo一覧、Markdown読込境界、`flutter_markdown_plus`を利用する。新規依存、永続ストレージ、Androidネイティブ変更は追加しない。

**TDD**: 振る舞い変更は `.github/skills/tdd/SKILL.md` に従う。各タスクで要件に基づくテストを一つずつRed（期待する振る舞いによる失敗を実測）→ Green（最小実装）→ Refactor（テスト成功を維持）で完了する。コンパイルエラーや環境エラーをRedとみなさない。

## Phase 1: Setup

**目的**: 既存プロジェクト構成と依存を再利用する。

追加のプロジェクト初期化、新規依存、環境設定は不要。共有Setupタスクなし。

---

## Phase 2: Foundational

**目的**: 全ストーリーをブロックする共通基盤を整える。

既存のTodo・Note・フォルダー読込境界を利用できるため、独立したFoundational変更は不要。詳細固有の読込とリンク処理は各ユーザーストーリーのTDDサイクルで実装する。

**Checkpoint**: 共有基盤タスクなし。User Story 1から開始できる。

---

## Phase 3: User Story 1 - Todoの内容を確認する (Priority: P1) 🎯 MVP

**Goal**: 一覧で選択したTodoだけを参照専用の詳細画面に表示し、戻ると検索状態を維持した一覧へ戻す。

**Independent Test**: 複数のTodo（同名を含む）から一件を開き、選択したNoteIdのタイトル・本文・タグだけが表示されること、本文や操作項目を編集できないこと、戻ると同じ検索状態の一覧へ戻ることを確認する。

### TDD cycles for User Story 1

- [X] T001 [US1] 選択された`NoteId`と一致するTodoだけを再読込し、同名の別Todoを返さない振る舞いを`test/features/todo/todo_detail_repository_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_repository.dart`に実装する。
- [X] T002 [US1] 選択Todoの欠落・読込不能・解析失敗を空の正常データにせず失敗として返す振る舞いを`test/features/todo/todo_detail_repository_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_repository.dart`に実装する。
- [X] T003 [US1] 詳細画面に選択Todoのタイトル・Markdown本文・階層タグを表示し、編集・削除・関連情報作成の操作を出さない振る舞いを`test/features/todo/todo_detail_screen_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_detail_screen.dart`に実装する。
- [X] T004 [US1] 本文またはタグがない場合に空の項目を表示せず、長い本文でも画面をスクロールして戻れる振る舞いを`test/features/todo/todo_detail_screen_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_detail_screen.dart`に実装する。
- [X] T005 [US1] 一覧の詳細コールバックを詳細画面への遷移に接続し、失敗を通知しつつ戻ると検索条件を維持して一覧を再読込する振る舞いを`integration_test/todo_detail_test.dart`でRed→Green→Refactorし、`lib/main.dart`と`lib/features/todo/todo_list.dart`に実装する。

**Checkpoint**: US1は関連Markdownリンクやタグ絞り込みなしで独立して確認可能。

---

## Phase 4: User Story 2 - 関連するMarkdownを開く (Priority: P2)

**Goal**: Todo本文の直接Wikiリンクから関連Markdownを特定し、アプリ内の参照専用プレビューで表示する。

**Independent Test**: 有効なリンク、同一対象への重複リンク、同名対象、未解決・曖昧・フォルダー外・読込不能リンクを含むTodoを用意し、正しい文書だけが一回のタップで開くこと、誤った文書や外部宛先を開かないことを確認する。

### TDD cycles for User Story 2

- [X] T006 [US2] Todo本文の直接Wikiリンクを設定フォルダー内で解決し、同じ`NoteId`を一件にまとめ、同名文書は相対パスで区別する振る舞いを`test/features/todo/todo_detail_repository_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_repository.dart`のデータ境界に実装する。
- [X] T007 [US2] Wikiリンクが未解決・複数候補・フォルダー外・読込不能の場合に候補を推測せず失敗として扱い、リンクがない場合は関連情報を出さない振る舞いを`test/features/todo/todo_detail_repository_test.dart`と`test/features/todo/todo_detail_screen_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_repository.dart`と`lib/features/todo/todo_detail_screen.dart`に実装する。
- [X] T008 [US2] 解決済み関連タイトルのタップで対応するMarkdownプレビューを開き、戻るとTodo詳細へ復帰し、標準Markdownリンクなど未対応・外部宛先を起動しない振る舞いを`test/features/todo/todo_detail_screen_test.dart`と`integration_test/todo_detail_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_detail_screen.dart`と`lib/main.dart`に実装する。

**Checkpoint**: US1の詳細表示を保ったまま、有効・無効な関連リンクを独立して確認可能。

---

## Phase 5: User Story 3 - タグでTodoを絞り込む (Priority: P2)

**Goal**: 詳細画面のタグから、そのタグに完全一致するTodo一覧へ移動する。

**Independent Test**: 階層タグを持つTodoの詳細からタグを選び、同じタグを持つTodoだけが一覧に表示されること、類似タグや別階層のタグが混ざらないことを確認する。

### TDD cycles for User Story 3

- [X] T009 [US3] 詳細画面のタグ選択で一覧を`#タグ`検索に設定し、階層全体・既存のNFC正規化・完全一致規則を保って絞り込む振る舞いを`test/features/todo/todo_detail_screen_test.dart`、`test/features/todo/todo_list_widget_test.dart`、`integration_test/todo_detail_test.dart`でRed→Green→Refactorし、`lib/features/todo/todo_detail_screen.dart`、`lib/features/todo/todo_list.dart`、`lib/main.dart`に実装する。

**Checkpoint**: US1の戻る動作を維持しながら、タグ選択による一覧遷移を確認可能。

---

## Phase 6: Polish & Cross-Cutting Concerns

**目的**: 検証手順と全体の回帰確認を仕上げる。

- [X] T010 実装したテストファイル・フォルダーピッカー条件・手動確認手順を`specs/004-todo-detail/quickstart.md`へ反映し、自動テストで代替できないSC-003・SC-004の利用者評価を別途記録する手順を明記する。
- [X] T011 `specs/004-todo-detail/quickstart.md`の手順に従い`flutter analyze`、詳細Repository・画面テスト、`flutter test integration_test`を実行し、20件以上のTodoでSC-001と有効リンク全件でSC-002を確認する。未実施の実機・利用者評価は成功扱いにせず残課題として報告する。

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 追加作業なし。
- **Foundational (Phase 2)**: 追加作業なし。機能固有の基盤は各ストーリーに含める。
- **User Stories**: US1（P1）を先に完了する。US2とUS3はUS1の詳細画面・遷移を利用するためUS1に依存する。US2とUS3は同じ画面・遷移ファイルを変更するため、競合を避けて順次実装する。
- **Polish (Phase 6)**: US1〜US3完了後に実施する。

### User Story Dependencies

```text
US1 (P1, MVP)
├── US2 (P2)
└── US3 (P2)
    ↓
Polish
```

US2とUS3はUS1完了後に着手可能だが、`todo_detail_screen.dart`と`main.dart`を共有するため同時のコード変更は避ける。

### Parallel Opportunities

- 実装タスクは同一Repository・画面・遷移のTDDサイクルを順に積み上げるため、`[P]`対象は設けない。
- 各ストーリー内の実装完了後、独立したRepositoryテストとWidgetテストは別々に実行できる。Android統合テストは別の実行枠で行う。

### Parallel Example: User Story 1

US1の実装サイクル完了後、別々のテスト実行として並行可能:

```powershell
flutter test test/features/todo/todo_detail_repository_test.dart
flutter test test/features/todo/todo_detail_screen_test.dart
```

### Parallel Example: User Story 2

US2の実装サイクル完了後、Repositoryと画面テストを独立に実行可能:

```powershell
flutter test test/features/todo/todo_detail_repository_test.dart
flutter test test/features/todo/todo_detail_screen_test.dart
```

### Parallel Example: User Story 3

US3の実装サイクル完了後、画面と一覧検索のWidgetテストを独立に実行可能:

```powershell
flutter test test/features/todo/todo_detail_screen_test.dart
flutter test test/features/todo/todo_list_widget_test.dart
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Setup・Foundationalに追加タスクがないことを確認する。
2. T001〜T005を一つずつRed→Green→Refactorで完了する。
3. US1を独立テストし、Todo詳細の表示、空データ・読込失敗、戻る・一覧検索維持を確認する。
4. US1だけで参照専用詳細のMVPを提示できる。US2・US3はMVP後に追加する。

### Incremental Delivery

1. US1完了・検証後にUS2を追加し、有効・不正Wikiリンクと関連文書への遷移を検証する。
2. US3を追加し、タグ完全一致の一覧絞り込みと既存検索回帰を検証する。
3. Polishで静的解析・対象テスト・Android統合テストを実行する。
4. 利用者評価のSC-003・SC-004は自動テストと区別して記録する。

---

## Notes

- `[P]`は異なるファイルを変更し、未完了タスクへの依存がない場合のみ付与する。本計画の実装タスクは共有ファイルを変更するため並列化しない。
- `[US1]`〜`[US3]`は`spec.md`のユーザーストーリーに対応する。
- 各TDDタスクは対象テストで振る舞いによるRedを確認してから実装し、Refactor中もGreenを維持する。
- Android統合テストはテスト用接頭辞の専用フォルダーと既存debug専用ピッカーチャネルを使い、通常の保存先設定を変更しない。
