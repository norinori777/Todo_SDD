# Todo詳細画面の検証ガイド

## 前提条件

- Flutter 3.41.7とDart 3.11.5を利用できること。
- Android SDK API 37と接続済みのAndroidエミュレーターまたは端末があること。
- アプリでMarkdownフォルダーを選択し、読み取り権限を許可していること。
- テスト用フォルダーに少なくとも20件のTodoを用意する。正常系Todoにはタイトル、Markdown本文、階層タグを含め、複数件には既存MarkdownへのWikiリンクを含める。

## 自動テスト

```powershell
flutter analyze
flutter test test/features/todo/todo_detail_repository_test.dart test/features/todo/todo_detail_screen_test.dart test/features/todo/todo_list_widget_test.dart test/features/todo/todo_return_test.dart
flutter test integration_test/todo_detail_test.dart
```

詳細Repository・画面・タグ絞り込みテストはFakeのフォルダー読込結果を使う。Android結合テストはフォルダーアクセスMethodChannelをテスト内で差し替え、20件のTodo・リンク先の選択、読込失敗、タグ遷移、画面復帰を検証する。保存先設定や実ファイルは変更しない。実際のSAFフォルダー選択を手動確認する場合は、既存のdebug専用`pickTestFolder` / `releaseTestFolder`チャネルを使い、`TodoSdd_IntegrationTest_`接頭辞の専用フォルダーだけを対象にする。

## 利用者フローの確認

1. アプリを起動し、テスト用Markdownフォルダーを開く。
2. Todo一覧で検索条件を入力してからTodoをタップする。
3. タイトル、本文プレビュー、階層タグが選択Todoの内容と一致し、編集・削除・関連情報作成の操作がないことを確認する。
4. 関連情報一覧のタイトルをタップし、対応するMarkdownだけが開くことを確認する。戻る操作で元のTodo詳細へ戻ることを確認する。
5. 詳細のタグをタップし、そのタグに一致するTodoだけの一覧が表示されることを確認する。
6. 通常の戻る操作では前の一覧へ戻り、検索条件が維持されて一覧が再読込されることを確認する。
7. 本文、タグ、関連リンクがないTodoでは存在しない内容を表示せず、残っている内容を表示することを確認する。
8. 存在しないリンク、曖昧なリンク、読み込み不能なTodoまたは参照先を用意し、失敗を通知し、別のMarkdownを誤表示しないことを確認する。
9. 通常のMarkdown URLをタップしても外部アプリやブラウザーが起動しないことを確認する。

## 合格条件

- 20件以上のTodoで、選択したタイトルと取得可能な本文が正しく対応し、画面から編集できない（SC-001）。
- 有効な関連リンクは表示タイトルから1回のタップで対応文書を開ける（SC-002）。
- 一覧から詳細を開いて確認し、元の一覧へ戻るフローは10人中9人以上が30秒以内に完了する（SC-003）。
- 利用者がタグ階層と関連情報の有無を正しく識別できる割合が90%以上となる（SC-004）。

SC-003は10人それぞれに一覧から詳細を開き内容を確認して元の一覧へ戻る操作を行ってもらい、開始から完了までを計測する。SC-004は同じ利用者に階層タグと関連情報の有無を識別してもらい、各回答の正誤を記録する。個人を特定する情報は記録せず、参加者ごとの所要時間・判定と合計結果を記録する。両評価はWidgetテストやAndroid結合テストで代替せず、未実施なら未検証として残す。
