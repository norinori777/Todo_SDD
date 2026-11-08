---
description: "Todo一覧画面の実装タスク"
---

# Tasks: Todo一覧画面

**入力**: `specs/001-todo-list/plan.md`、`specs/001-todo-list/spec.md`、`specs/001-todo-list/data-model.md`、`specs/001-todo-list/research.md`、`specs/001-todo-list/contracts/todo-list.md`、`specs/001-todo-list/quickstart.md`

**進捗の扱い**: 既存の完了印を保持する。追加された最新仕様の作業は未完了とし、完了済み項目の実績を新たな要件の検証済みとみなさない。

**TDD**: 振る舞いを変更する各タスクは `.github/skills/tdd/SKILL.md` と `agents/rules/flutter-todo/testing-strategy.md` に従う。各フェーズのテストリストから1件を選び、指定テストで期待する振る舞いの失敗を実測（Red）、指定実装で最小限の成功を確認（Green）、テストを通したまま整理（Refactor）し、次のケースへ進む。コンパイル・環境エラーはRedではない。Redを実測できない場合は実装を止め、理由とリスクを報告する。実装済みの振る舞いは既存テストを確認し、弱いアサーションによる見かけの成功を避ける。

**形式**: `- [ ] T番号 [P?] [US番号?] 説明とパス`。`[P]` は前提完了後に他の `[P]` タスクと別ファイルで実行できる作業のみ。各パスはリポジトリルートからの相対パス。

## 対象外

- T010（廃止）: シンボリックリンクの検出・追跡防止・除外通知、およびAndroid提供元での当該動作の検証。ユーザー決定により、現行開発と今後の移行開発のどちらでも実施しない。リンクを含むフォルダーに対する安全性は保証しない。既存コード・テストは変更せず保持する。

## Phase 1: Setup

**目的**: Android向けFlutterプロジェクトの土台を作る。利用可能な安定版を固定し、不要な依存は追加しない。

- [X] T001 `specs/001-todo-list/plan.md` と `agents/rules/flutter-todo/README.md` を確認し、利用可能なFlutter安定版とAndroid開発環境を `flutter doctor` で確認して、バージョンと不足事項を `specs/001-todo-list/quickstart.md` に記録する。
- [X] T002 `pubspec.yaml`、`analysis_options.yaml`、`android/`、`lib/`、`test/`、`integration_test/` をFlutterの標準手順で初期化し、Flutter SDK、`flutter_test`、`integration_test` を設定する。既存の設計資料や未コミット変更を上書きしない。
- [X] T003 Markdown/YAMLの構文検証・位置情報・原文保持とAndroidフォルダーアクセスの選択肢を評価し、採用理由、ライセンス、Android対応、未対応時の拒否方針を `specs/001-todo-list/research.md` に追記する。必要な依存のみ `pubspec.yaml` に追加する。
- [X] T004 Android 17（API 37）以降を最低対応にするため `android/app/build.gradle.kts` の `minSdk` と必要なコンパイル設定を確認・設定し、SDKの不足とビルド結果を `specs/001-todo-list/quickstart.md` に記録する。Android 17での実動作はSC-007で別途検証する。

## Phase 2: Foundational

**目的**: 全ストーリーが利用する型付き境界と安全な読込基盤を確立する。

**テストリスト**: 未設定・権限失効・空フォルダーを区別／設定ルート内外の識別子／全サブフォルダー／対象別の読込失敗と全体失敗／実ファイル・Android提供元の権限。

- [X] T005 設定機能からのフォルダーアクセス情報について、未設定・失効・権限不足を正常な空フォルダーと区別するケースを `test/features/todo/folder_access_test.dart` でRed → `lib/features/settings/folder_access.dart` の公開境界と `lib/features/todo/folder_access.dart` の利用側でGreen → Refactorする。設定画面の内部実装は作らない。
- [X] T006 ノート識別子の制約「設定フォルダー内の対象を一意に開くための識別子。相対パスは表示・並び替えにも使用し、フォルダー外を指すものを拒否する。」を、ルート内・親への脱出・ルート外のケースについて `test/features/todo/note_id_test.dart` でRed → `lib/features/todo/note.dart` でGreen → Refactorする。
- [X] T007 指定フォルダーから全サブフォルダーのMarkdownを列挙し、他の拡張子と指定フォルダー外を対象にしないケースを `test/features/todo/folder_reader_test.dart` の一時ディレクトリ実ファイルでRed → `lib/features/todo/folder_reader.dart` でGreen → Refactorする。列挙後の差し替え競合によるルート外アクセスの防止も検証する。
- [X] T008 正常・空・対象別読込失敗・全体失敗を区別し、対象と原因を保持する型付き結果を `test/features/todo/folder_reader_test.dart` でRed → `lib/features/todo/folder_reader.dart` でGreen → Refactorする。失敗を空成功に変換せず、識別子を作れない対象の失敗も通知する。
- [X] T009 Androidのフォルダー公開境界でユーザーが選択した提供元の永続権限と再帰読込を扱い、未設定・拒否・失効時に明示的に失敗するケースを `integration_test/folder_access_test.dart` と `test/features/todo/android_folder_reader_test.dart` でRed → `lib/features/settings/folder_access.dart`、`lib/features/todo/android_folder_reader.dart`、`android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt` のプラットフォーム実装でGreen → Refactorする。選択画面自体は別機能の公開境界とする。
**チェックポイント**: 境界をFakeに置換でき、Androidでも失敗と空結果を区別できる。実機でRedを実測できないときは該当実装を進めない。

## Phase 3: User Story 1 - Todoを一覧で確認する (P1) 🎯 MVP

**目標**: 指定フォルダーの未完了Todo、階層タグと重複タイトルを表示し、対象の詳細を開く。

**独立テスト**: 10件のTodo・10件の非Todoとサブフォルダー、同名ファイル、不正ファイルを用意し、表示漏れ・誤表示0件、順序、部分失敗の通知、正しい識別子での詳細遷移と空結果を確認する（SC-001）。

**テストリスト**: `#todo`完全一致と `# TODO`／`#todo/子` の除外、タグ文字列・リスト・空リスト・不正型、除外領域・Wiki表示名、タイトルと同名、完了除外、読み込み状態・部分失敗・詳細遷移。

- [X] T011 [US1] モデルの制約「拡張子を除くファイル名。同名でも別ノートとして保持する。」と「変更判定と部分編集のための元テキストと比較可能な内容。表示や外部送信には使用しない。」を、見出しとファイル名の相違・同名・元データ保持の各ケースについて `test/features/todo/note_test.dart` でRed → `lib/features/todo/note.dart` でGreen → Refactorする。
- [X] T012 [US1] 「対象はUTF-8であり、UTF-8 BOMは許容して保持する。別形式のBOMや不正なUTF-8、frontmatterが不正、`tags`が非対応型またはリスト内に文字列以外を含む場合はノートを対象から除外し、識別情報と理由を読込結果に残す。」のうち文字コードを、BOMなし正常・UTF-8 BOM・UTF-16等別BOM・不正なUTF-8と読めるファイルの混在について `test/features/todo/markdown_encoding_test.dart` で1件ずつRed → `lib/features/todo/markdown_parser.dart`、`lib/features/todo/note.dart` でGreen → Refactorする。完全な元バイト列を保持し文字コードを推測しない。
- [X] T013 [US1] frontmatterの制約「`tags`は文字列、文字列のみのインライン・複数行リスト、空リストを受け付ける。」と「frontmatterが不正、`tags`が非対応型またはリスト内に文字列以外を含む場合はノートを対象から除外し、識別情報と理由を読込結果に残す。」を各形式・`[todo, 123]`・不正YAMLについて `test/features/todo/markdown_parser_test.dart` でRed → `lib/features/todo/markdown_parser.dart` でGreen → Refactorする。
- [X] T014 [US1] タグの制約「本文とfrontmatterの対象タグ。先頭の`#`を正規化し階層は保持する。コード・コメント・HTMLのタグと属性・エスケープ・URLおよびWikiリンクと通常のMarkdownリンクのリンク先は対象外、HTML要素内および各リンクの表示文字は対象。階層タグは`#仕事/会議`のように全体を表示する。」を、各除外領域と両リンク形式の表示文字・リンク先、`#todo,`／`#todo作業`／`#todo-作業`／`文章#todo`／`（#todo）`／`文章。#todo`／`作業-#todo`／`作業/#todo`／`#todo`直後のU+0301、HTML属性と要素内の表示文字の各ケースについて `test/features/todo/markdown_parser_test.dart` で1件ずつRed → `lib/features/todo/markdown_parser.dart` でGreen → Refactorする。
- [X] T015 [US1] Todoの制約「ノートのタグに完全一致の`todo`がある場合に成立する。`todo/子`だけでは成立しない。タグに完全一致の`完了`がある場合は完了、それ以外は未完了。」を `# TODO`・本文・frontmatter・階層タグを含め `test/features/todo/markdown_parser_test.dart` でRed → `lib/features/todo/markdown_parser.dart` と `lib/features/todo/note.dart` でGreen → Refactorする。
- [X] T016 [US1] 再帰読込結果をTodoに投影し、読めた項目と対象別の解析・読込失敗を同時に返すケースを `test/features/todo/todo_repository_test.dart` でRed → `lib/features/todo/todo_repository.dart` でGreen → Refactorする。書式を正しく判定できずTodoのタグを特定できないファイルを除外して対象と理由を返し、全体失敗と空結果を区別する。
- [X] T017 [US1] 表示項目の制約「タイトルはUnicodeコードポイントの辞書順で昇順、同名は相対パス昇順。重複タイトルには相対パスを表示する。」を、未完了のみの通常一覧、`A`／`a`／`あ`／`ア`、U+E000とU+10000、同名の相対パス、階層タグ表示の各ケースについて `test/features/todo/todo_list_test.dart` でRed → `lib/features/todo/todo_list.dart` でGreen → Refactorする。端末の言語設定に依存させない。
- [X] T018 [US1] 読込中・空結果・部分失敗・全体失敗を区別して対象、状況、対処を日本語で表示するケースを `test/features/todo/todo_list_test.dart` でRed → `lib/features/todo/todo_list.dart` でGreen → Refactorする。
- [ ] T019 [US1] Todoタップ時に選択したノート識別子を詳細機能の公開境界へ渡すケースを `test/features/todo/todo_list_navigation_test.dart` でRed → `lib/features/todo/todo_list.dart`、`lib/app/todo_navigation.dart` でGreen → Refactorする。詳細画面の内部は実装しない。
- [ ] T020 [US1] 実ファイルの10 Todo・10非Todo、ネスト・同名・不正ファイルを使いSC-001と表示・詳細遷移を `integration_test/todo_list_test.dart` でRed → 必要な `lib/features/todo/` と `lib/app/` の結合をGreen → Refactorする。詳細は公開境界のFakeで検証できる。

**チェックポイント**: US1単独で表示、エラー通知、詳細遷移を検証できる。

## Phase 4: User Story 2 - Todoを検索する (P1)

**目標**: 通常一覧のタイトル部分一致・タグ完全一致と完了Todo検索を提供する。

**独立テスト**: 異なるタイトル・本文/frontmatterタグ・完了状態を持つTodoで、大小文字、部分一致、完全一致、`#完了`、入力消去、空結果と順序を検証する。

**テストリスト**: 空／タイトル部分一致と大小文字／タグ完全一致と階層／frontmatterの`#`正規化／NFCでの結合文字の同一視と元表記保持／正規化失敗／完了検索／該当なし／消去と並び順。

- [ ] T021 [P] [US2] タグ検索の制約「タグ検索はNFCに正規化して比較し、元ファイルは変更しない。」を、結合濁点と合成済み文字、大小文字の非一致、変換失敗と未対応プラットフォームの明示的な失敗について `test/features/todo/tag_normalizer_test.dart`、`integration_test/tag_normalizer_test.dart` で1件ずつRed → `lib/features/todo/tag_normalizer.dart`、`android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt` の `java.text.Normalizer` 一括変換境界でGreen → Refactorする。元の表示とバイト列は保持し、失敗時に未正規化の成功結果を返さない。
- [X] T022 [P] [US2] 検索条件の制約「空、タイトル部分一致、`#`から始まるタグ完全一致。タイトルの英字は大文字・小文字を区別せず、タグは区別する。`#完了`のみ完了Todoを対象とする。」を `test/features/todo/todo_search_test.dart` で各正常・境界・大小文字のケースごとにRed → `lib/features/todo/todo_search.dart` でGreen → Refactorする。本文とfrontmatterのタグ、`todo`と`todo/子`の非一致、通常Markdownリンク先だけにあるタグの除外を含める。
- [ ] T023 [US2] 検索境界でNFC変換を使い、`#か`＋U+3099を`#が`で検索すると一致し、変換失敗を利用者に通知して成功扱いせず、元表記・ファイルを変更しないケースを `test/features/todo/todo_search_test.dart`、`test/features/todo/todo_search_widget_test.dart` で1件ずつRed → `lib/features/todo/todo_search.dart`、`lib/features/todo/todo_list.dart` でGreen → Refactorする。
- [X] T024 [US2] 入力変更・消去で検索を適用し、該当なしを表示し、結果のタイトル・相対パス順を維持するケースを `test/features/todo/todo_search_widget_test.dart` でRed → `lib/features/todo/todo_list.dart` と `lib/features/todo/todo_search.dart` の結合でGreen → Refactorする。
- [ ] T025 [US2] 10件のTodoを使いタイトル・タグ・完了検索と消去を `integration_test/todo_search_test.dart` でRed → `lib/features/todo/todo_list.dart` の結合をGreen → Refactorする。SC-002の利用者評価は最終フェーズで別途測定する。

**チェックポイント**: US1の読込基盤に対して検索を独立してテストできる。

## Phase 5: User Story 3 - Todoを完了にする (P1)

**目標**: 左スワイプまたは読み上げ可能なメニューで、元データを守りながら完了・未完了を永続化する。

**独立テスト**: 両状態のTodoを更新し再読込で状態と対象外のバイト列を検証する。競合・権限・保存失敗・保証不能時は成功表示せず元データを保持する。

**テストリスト**: 追加位置・改行・BOM／本文・frontmatter全タグ除去と空リスト／リンク表示名と除外領域保持／実ファイルの原文保持／外部変更・保存中競合・部分書込・権限不足・保証不能／復旧領域の耐久化と片付け／各中断段階と復旧競合・全文表示・選択後の再競合／スワイプ・メニュー・再読込。

- [ ] T026 [P] [US3] 完了操作の制約「frontmatter直後、またはfrontmatterがないとき先頭に独立した`#完了`行を追加。」を、両位置と既存改行・対象外内容の保持について `test/features/todo/completion_editor_test.dart` でRed → `lib/features/todo/completion_editor.dart` でGreen → Refactorする。
- [ ] T027 [US3] 未完了への制約「判定対象の本文とfrontmatterの完了タグをすべて削除。`tags`が空なら`tags: []`。Wikiリンク表示名が`#完了`のみの場合は表示名部分を除去しリンク先を保持。」を、文字列・インライン/複数行リスト・複数タグ・`"#完了"`・Wikiリンクで `test/features/todo/completion_editor_test.dart` のRed → `lib/features/todo/completion_editor.dart` のGreen → Refactorにより満たす。
- [ ] T028 [US3] 制約「通常のMarkdownリンク表示文字が`#完了`のみの場合はリンク先を表示文字に使い、表示文字中の`#`をエスケープしてリンク先を保持する。」を、`[#完了](ノート.md)` → `[ノート.md](ノート.md)`、`[#完了](ノート.md#完了)` → `[ノート.md\#完了](ノート.md#完了)`、角括弧・バックスラッシュ・リンクタイトル・参照形式の各ケースで `test/features/todo/completion_editor_test.dart` のRed → `lib/features/todo/completion_editor.dart` のGreen → Refactorにより満たす。エスケープ・URL・コード・コメント・Wikiリンクと通常リンクのリンク先、他タグ・書式・参照定義を保持し、安全に位置や保存後のリンク先を確認できない場合は理由付きで更新を拒否する。
- [ ] T029 [US3] `specs/001-todo-list/research.md` にAndroid保存先候補とAPIの公式契約・適用範囲、外部アプリを含む条件付き確定、耐久化、復旧領域、権限の根拠および実験方法を記録する。一般SAFの事前比較や実験成功のみを保証とみなさず、根拠を示せない候補は閲覧専用・SC-003公開不可とする。
- [ ] T030 [P] [US3] 保存境界が読み込み時の版と現在の内容の不一致、権限不足、読込/書込失敗、原子性・排他または同等の保証不足を区別し、成功として返さないケースを `test/features/todo/safe_writer_test.dart` でRed → `lib/features/todo/safe_writer.dart` でGreen → Refactorする。事前比較だけを競合防止の保証とみなさない。
- [ ] T031 [US3] 一時ディレクトリの実ファイルで成功時の対象外バイト保持、外部変更、書込途中の障害と保存拒否時の元データ保持を `test/features/todo/safe_writer_file_test.dart` でRed → `lib/features/todo/safe_writer.dart` の安全な保存方式でGreen → Refactorする。保証できなければ書込を拒否する。
- [ ] T032 [US3] UTF-8 BOMを保持してfrontmatterの有無による追加位置を守り、完了・未完了の往復で対象外バイトとHTML属性内の`#完了`を保持するケースを `test/features/todo/completion_editor_test.dart` と `test/features/todo/safe_writer_file_test.dart` で1件ずつRed → `lib/features/todo/completion_editor.dart`、`lib/features/todo/safe_writer.dart` でGreen → Refactorする。
- [ ] T033 [US3] 保存操作の状態制約「選択フォルダー内の識別可能な復旧領域に、対象、更新前・更新後の完全なバイト列と操作状態を耐久化する。準備できなければ対象を変更しない。」と「更新後の完全な内容と耐久性を確認後にのみ成功を返す。復旧情報の安全な片付けにも途中失敗時の再開方法を設ける。」を、領域の名前衝突・探索除外・準備失敗・条件付き確定・片付け中断の各ケースについて `test/features/todo/recovery_store_test.dart`、`test/features/todo/safe_writer_file_test.dart` で1件ずつRed → `lib/features/todo/recovery_store.dart`、`lib/features/todo/safe_writer.dart`、`lib/features/todo/folder_reader.dart` でGreen → Refactorする。保証のない提供元では書き込みを拒否する。
- [ ] T034 [US3] 復旧の制約「中断後に対象と復旧情報を読む。元または更新後の完全な内容に安全に戻せる場合を除き、自動上書きしない。判定不能や外部変更は競合として扱う。」を、準備・確定・片付けの各段階での中断、外部変更なし、外部変更あり、読み取り失敗について `test/features/todo/recovery_test.dart`、`test/features/todo/safe_writer_file_test.dart` で1件ずつRed → `lib/features/todo/recovery_store.dart`、`lib/features/todo/safe_writer.dart` でGreen → Refactorする。競合時は両方を保持し復旧待ちを返す。
- [ ] T035 [US3] 復旧競合の制約「現在と復旧用の内容を保持して各全文を表示する。正しい文字列でなければ全バイトの16進数を表示する。どちらか読めなければ理由・対処を通知して選択を無効化する。」と「現在を残す、または復旧用を適用する。いずれも確認後の外部変更を再検査し、競合時は保持して再確認する。安全な確定ができるまで復旧情報を残す。」を正常UTF-8・不正UTF-8・権限喪失・両選択・再競合について `test/features/todo/recovery_test.dart`、`test/features/todo/recovery_widget_test.dart` で1件ずつRed → `lib/features/todo/recovery_store.dart`、`lib/features/todo/safe_writer.dart`、`lib/features/todo/todo_list.dart` でGreen → Refactorする。
- [ ] T036 [US3] 更新成功後のみ一覧状態を確定し、外部変更は再読込・再操作、権限・保存失敗・保証不能は理由と対処を返すケースを `test/features/todo/todo_update_test.dart` でRed → `lib/features/todo/todo_repository.dart` と `lib/features/todo/safe_writer.dart` でGreen → Refactorする。
- [ ] T037 [US3] 左スワイプと読み上げ可能な操作メニューで両方向に切り替え、成功後の通常/完了一覧移動と失敗時の項目維持・日本語通知を `test/features/todo/todo_completion_widget_test.dart` でRed → `lib/features/todo/todo_list.dart` でGreen → Refactorする。
- [ ] T038 [US3] Android対象提供元について保存中の競合・失敗と元データ保持、保証不足時の拒否を `integration_test/todo_save_safety_test.dart` でRed → `lib/features/todo/safe_writer.dart`、`lib/features/todo/android_folder_reader.dart` と `android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt` の保存境界でGreen → Refactorする。提供元の明示的な条件付き確定・耐久性等の保証と実験の両方を確認できない場合は保存を有効化しない。
- [ ] T039 [US3] 安全性を検証した実Android提供元で両方向の更新それぞれについて、保存の複数段階でアプリ強制終了・端末再起動を行い、外部変更なしの完全復元、外部変更との競合、全文・全バイト16進表示、読取不能時の選択禁止、選択後の再競合と復旧情報の保持を `integration_test/todo_recovery_test.dart` で1件ずつRed → `lib/features/todo/recovery_store.dart`、`lib/features/todo/safe_writer.dart`、`android/app/src/main/kotlin/com/example/todo_sdd/MainActivity.kt` でGreen → Refactorする。実行不能・保証不足の場合は成功を偽装せず公開条件未達として記録する。
- [ ] T040 [US3] 少なくとも一つの安全性を検証した実際のAndroid提供元で、完了と未完了の各10件を更新・再読込し状態維持、保存失敗時の破壊0件を `integration_test/todo_completion_test.dart` でRed → `lib/features/todo/` の結合でGreen → Refactorする（SC-003）。安全性未検証の提供元では成功テストを偽装せず拒否を検証し、成功可能な提供元がない場合は未達を報告する。

**チェックポイント**: 保存機能は保証を検証できた提供元でのみ成功し、その他は明示的に拒否する。

## Phase 6: User Story 4 - 関連情報をたどる (P2)

**目標**: 直接Wikiリンクによる双方向の関連情報を開閉し、正しいノートだけを開く。

**独立テスト**: 双方向、ルート起点パス、見出し・表示名、frontmatter、同名・未解決・読込不能を用意し、初期非表示、開閉、重複除去と正しい詳細遷移を確認する。

**テストリスト**: 本文/frontmatterリンク抽出と除外領域／パス起点／直接のみ・双方向重複排除／同名・曖昧・未解決・読込不能／開閉と詳細。

- [ ] T041 [P] [US4] Wikiリンクの制約「本文およびfrontmatterの対象リンク。ノート名、ルート起点パス、見出し、表示名を分離して扱う。コード・HTMLコメント内は除外する。」を `test/features/todo/wiki_link_parser_test.dart` でRed → `lib/features/todo/wiki_link_parser.dart` でGreen → Refactorする。インラインコードとコードブロックも除外する。
- [ ] T042 [US4] 関連情報の制約「Todoと他のノート間の直接Wikiリンクを方向に関係なく1件として表す。リンク先が見出し・表示名付きでもノート自体を参照する。パス付きリンクは指定フォルダー起点。」を `test/features/todo/related_notes_test.dart` でRed → `lib/features/todo/related_notes.dart` でGreen → Refactorする。間接リンクと通常Markdownリンクを除外する。
- [ ] T043 [US4] 関連情報の制約「未解決・読込不能・複数候補は解決済みのノートと区別して表示・通知し、任意の候補を開かない。同名の関連項目には相対パスを表示する。」を `test/features/todo/related_notes_test.dart` でRed → `lib/features/todo/related_notes.dart` でGreen → Refactorする。
- [ ] T044 [US4] Todoごとの関連情報を初期状態で閉じ、展開・折りたたみ、同名パス、解決済み項目の詳細遷移と未解決時の通知を `test/features/todo/related_notes_widget_test.dart` でRed → `lib/features/todo/todo_list.dart` と `lib/app/todo_navigation.dart` でGreen → Refactorする。
- [ ] T045 [US4] サブフォルダー・双方向・曖昧/未解決リンクを含む実ファイルで開閉と選択対象を `integration_test/related_notes_test.dart` でRed → `lib/features/todo/` の結合でGreen → Refactorする。SC-004の利用者評価は最終フェーズで別途測定する。

**チェックポイント**: US1の一覧と詳細境界を使用し、検索や状態更新なしでも関連情報を検証できる。

## Phase 7: User Story 5 - 作成・編集画面を開く (P2)

**目標**: 作成・編集への公開境界を提供し、別画面から戻るたびに検索条件を維持して再読込する。

**独立テスト**: 作成ボタン、長押し、操作メニューからFakeの遷移先へ進み、戻る際の最新データ・検索条件維持と再読込失敗を確認する。

**テストリスト**: 作成は識別子なし／長押し・メニューは選択識別子／作成・編集・Todo詳細・関連詳細から復帰／検索維持／復帰時の全体・部分失敗。

- [ ] T046 [P] [US5] 作成は既存識別子なし、編集は選択したノート識別子を受け取る公開遷移境界を `test/app/todo_navigation_test.dart` でRed → `lib/app/todo_navigation.dart` でGreen → Refactorする。遷移先の内部仕様は実装しない。
- [ ] T047 [US5] 作成ボタン、Todo長押し、読み上げ可能な操作メニューの編集から正しい遷移先と対象を開くケースを `test/features/todo/todo_edit_navigation_test.dart` でRed → `lib/features/todo/todo_list.dart` でGreen → Refactorする。
- [ ] T048 [US5] 画面復帰の制約「作成・編集・詳細から戻るたびに再読込し、検索条件を維持する。再読込失敗も通知する。」を、各遷移先と関連詳細、データ変更、部分・全体失敗について `test/features/todo/todo_return_test.dart` でRed → `lib/features/todo/todo_list.dart` でGreen → Refactorする。失敗を空成功に変換しない。
- [ ] T049 [US5] 検索後の作成・編集・詳細から復帰し、最新結果・検索条件・失敗通知を `integration_test/todo_navigation_test.dart` でRed → `lib/features/todo/todo_list.dart` と `lib/app/todo_navigation.dart` の結合でGreen → Refactorする。

**チェックポイント**: 外部画面は公開境界のFakeで代替でき、画面内部の実装に依存しない。

## Phase 8: Polish & Cross-Cutting Concerns

**目的**: 実機・利用者評価を含めた受け入れとリリースゲートを確認する。

- [ ] T050 `specs/001-todo-list/quickstart.md` の手順に従い `flutter analyze`、`flutter test`、Androidで `flutter test integration_test` を実行し、失敗・未実行の理由と残るリスクを `specs/001-todo-list/quickstart.md` に記録する。修正が振る舞いを変える場合はTDDで行う。
- [ ] T051 `specs/001-todo-list/quickstart.md` に従い、10件のTodoを用いた10人の利用者評価でSC-002のタイトル・タグ・完了の各検索操作の初回成功率90%以上、SC-004の関連詳細を30秒以内に開ける割合90%以上を測定し、参加者数・各成功数・結果を同ファイルに記録する。
- [ ] T052 `specs/001-todo-list/quickstart.md` に従いSC-005の未設定・読込失敗・保存失敗の全ケースで状況と対処の表示を確認し、画面読み上げによる状態変更・編集をAndroidで検証して同ファイルに結果を記録する。
- [ ] T053 `specs/001-todo-list/quickstart.md` と `specs/001-todo-list/spec.md` のSC-006に従い、Core i7-13700H・16GB・Windows 11、Android 17のPixel 9aエミュレーター（仮想CPU 4・4GB・GPUハードウェア支援）のローカルストレージで、`00`〜`09`の各100件・各20,000バイト・LF・`#todo`・次の2件を循環参照するルート起点Wikiリンク2件・残りは `a` の固定データ1,000件を検証する。測定ごとに再起動し、全件読込・並べ替え後に操作可能になるまで3回測り全回10秒以内を確認、環境・提供元・各測定値を同ファイルに記録する。性能修正はTDDで回帰を防ぐ。
- [ ] T054 `specs/001-todo-list/quickstart.md` にAndroid提供元ごとの競合検出と保存中障害時の保護・権限検証の結果を記録し、未検証または保証不能な提供元で `lib/features/todo/safe_writer.dart` が保存を拒否すること、および少なくとも一つの実際のAndroid提供元で安全な両方向の更新と再読込が成功することをリリース条件として確認する。
- [ ] T055 `specs/001-todo-list/quickstart.md` に従いAndroid 17（API 37）の実端末またはエミュレーターで一覧表示、タイトル・タグ・完了検索、両方向の更新、読込・保存失敗の全受け入れシナリオを実行し、対象端末・提供元・各結果と未実施理由を同ファイルに記録する（SC-007）。Android 17より古い端末を代用しない。

## 依存関係と実行順

```text
Phase 1 → Phase 2 → US1 ┬→ US2 ─→ US3
                         ├→ US4
                         └→ US5 (検索条件の復帰検証はUS2にも依存)
US1 + US2 + US3 + US4 + US5 → Phase 8
```

- US2はUS1の一覧・モデルに依存し、T023はT021とT022に依存する。US3はUS1の読込とUS2の完了検索に依存し、T032はT026〜T028・T031、T033はT029〜T031、T034はT033、T035はT034、T039はT035・T038に依存する。US4とUS5はUS1の一覧・公開遷移境界に依存し、US5のT048・T049はUS2の検索実装にも依存する。
- US3のT026とT030はUS1/US2完了後、別ファイルで並行可能。T031はT030、T036はT026〜T035、T037〜T040は該当する保存・UI結合と提供元の保証確認の完了後。US4のT042〜T045、US5のT047〜T049はそれぞれ前のタスクに依存する。
- `lib/features/todo/todo_list.dart` や `lib/app/todo_navigation.dart` を同時に変更するタスクは `[P]` の有無にかかわらず直列化する。統合テストは対象の実装と前提が揃ってから開始する。

## ストーリー別の並行実行例

- **US1**: T011〜T020はモデル・解析・Repository・画面の順に依存するため、同一ストーリー内では並列化しない。
- **US2**: US1完了後のT021とT022は別ファイルで並行でき、US4のT041およびUS5のT046とも並行できる。T023はT021・T022の後、T024・T025はその後に直列実行する。
- **US3**: US1/US2完了後、T026とT030は別のテスト・実装ファイルで並行できる。T027・T028とT031以降は各前提完了後に実行する。
- **US4**: US1完了後のT041は、US2のT021・T022およびUS5のT046と並行できる。T042〜T045は依存順に実行する。
- **US5**: US1完了後のT046は、US2のT021・T022およびUS4のT041と並行できる。T047〜T049は依存順に実行し、T048・T049はUS2完了後に行う。

## 実装戦略

1. Phase 1・2を完了し、US1を実装・独立検証してMVPとする。実際の設定・詳細画面が未提供なら公開境界のFakeを使用し、未結合を明示する。
2. US2を追加して検索を検証し、US3の安全な保存を対象提供元ごとに検証する。保証できない場合は拒否したままにする。
3. US4・US5を追加し、それぞれ独立検証する。共通画面ファイルの競合を避けて結合する。
4. Phase 8でSC-001〜007、Android提供元、アクセシビリティを検証する。未達・未実施は完了扱いせず理由と残リスクを報告する。
