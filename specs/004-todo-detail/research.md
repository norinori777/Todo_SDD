# Phase 0 調査: Todo詳細画面

## Markdownプレビュー

- **決定**: 既存の`flutter_markdown_plus`と`MarkdownBody`を読み取り専用プレビューに再利用する。詳細画面の既存スクロール領域内に置き、Markdown自身の入れ子スクロールを避ける。Wikiリンクはデータ境界で別に抽出し、関連情報一覧からアプリ内遷移させる。本文中の標準Markdownリンクなど、仕様で定義されない宛先は開かない。新しいMarkdownレンダリング依存は追加しない。
- **理由**: 作成画面が同じ依存の`MarkdownBody`でプレビューしている。公式ドキュメントではインラインHTMLを描画せず、リンクは自動遷移せず、標準Markdownリンクの操作は`onTapLink(text, href, title)`を通じてアプリに委ねる。Wikiリンクは別の構文として解析し、関連情報一覧に表示する。詳細画面は参照対象フォルダーに限定し、外部送信しない憲章にも合う。
- **代替案**: リンク先を一律に外部ブラウザーへ渡す方法は、仕様外の外部遷移となるため採用しない。MarkdownをHTMLへ変換する別依存も不要である。
- **根拠**: [`flutter_markdown_plus`パッケージ](https://pub.dev/packages/flutter_markdown_plus)、[Markdown API](https://pub.dev/documentation/flutter_markdown_plus/latest/flutter_markdown_plus/Markdown-class.html)、[リンクコールバックAPI](https://pub.dev/documentation/flutter_markdown_plus/latest/flutter_markdown_plus/MarkdownTapLinkCallback.html)。

## Todoと関連Markdownの読み込み

- **決定**: 一覧で選択された`Todo`とその`NoteId`を画面遷移の入力とする。詳細Repositoryは指定フォルダーからTodoを再読込し、同じ`NoteId`の内容だけを返す。選択Todoがない・読み込めない場合は失敗とする。RepositoryはTodo本文の直接Wikiリンクを抽出・解決し、関連情報には解決済みノートのタイトルを表示する。同一対象は重複表示しない。別名やパスを含むWikiリンクの識別、複数候補・未解決・読込失敗の扱いはTodo一覧機能のリンク解決契約と揃える。
- **理由**: `TodoListScreen`は選択`Todo`を詳細境界へ渡し、`Todo`は`Note`、`NoteId`、タグを保持する。既存の`AndroidFolderReader`は部分失敗と全体失敗を区別する。再読込により仕様のTodo読込失敗を明示し、現在のTodoだけを表示できる。既存の一覧設計にもリンクの誤解決を防ぐ規則がある。
- **代替案**: 画面内でファイル探索やWikiリンク解析を行う方法はデータアクセス詳細をUIへ持ち込み、既存の機能境界に反する。曖昧なリンクを最初の候補で開く方法は別のMarkdownを誤表示するため採用しない。
- **根拠**: [Todo一覧の利用者・機能間契約](../001-todo-list/contracts/todo-list.md)、[Todo一覧のデータモデル](../001-todo-list/data-model.md)、`lib/features/todo/todo_repository.dart`、`lib/features/todo/folder_reader.dart`。

## 画面遷移とエラー表示

- **決定**: 一覧の`onOpenDetails`境界を既存のNavigator遷移へ接続する。通常の戻る操作は詳細を閉じ、一覧の検索条件を維持したまま再読込する。タグタップは一覧検索の`#タグ`形式でそのタグのTodoへ絞り込む。詳細Todoまたは関連Markdownの読み込み失敗を空の正常データとして扱わず、ユーザーに失敗と確認・対処を伝える。
- **理由**: 既存一覧には詳細遷移コールバックと、復帰時に検索条件を維持して再読込する振る舞いがある。仕様FR-003、FR-005、FR-008およびEdge Casesはタグ遷移、復帰、失敗表示を求める。
- **代替案**: 詳細内容をNavigator外の一時状態へ保存する方法は既存のスタック遷移と復帰挙動を重複させる。失敗を空表示に変換する方法は読み込み成功と誤認させるため採用しない。

## 検証方針

- **決定**: `flutter_test`でデータ境界と画面の正常系・失敗系を検証し、Android `integration_test`で一覧→詳細→関連文書／タグ→戻るの導線を検証する。既存の`flutter_markdown_plus`、SAF読取境界、タグ検索を再利用し、振る舞い変更はTDDで実装する。
- **理由**: 憲章IVと仕様の独立テスト・成功基準に沿い、Widget単体では確認できないAndroidフォルダーアクセスや画面遷移も検証する。
- **代替案**: 手動確認のみでは、選択データの取り違え、失敗時の誤表示、一覧復帰時の検索状態を繰り返し検証できない。

詳細な利用者操作と検証コマンドは[契約](./contracts/todo-detail.md)および[quickstart](./quickstart.md)を参照。
