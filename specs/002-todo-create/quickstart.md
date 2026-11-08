# Todo作成画面の検証ガイド

## 前提条件

- Flutter 3.41.7 / Dart 3.11.5を利用できる環境。
- Android実機またはエミュレーターで統合テストを行う場合は、テスト対象のMarkdownフォルダーが利用可能で、読取・書込権限を保持していること。
- 保存先には、タグ候補用のMarkdown、Wikiリンク候補用のMarkdown、および同名競合を試すための既存ファイルを用意する。
- テストの具体的なエンティティと保存契約は[data-model.md](./data-model.md)と[contracts/todo-create.md](./contracts/todo-create.md)を参照する。

## 自動検証

依存関係を解決する。

```powershell
flutter pub get
```

作成RepositoryとWidgetの対象テストを実行する。

```powershell
flutter test test/features/todo/todo_create_repository_test.dart test/features/todo/create_todo_screen_test.dart
```

静的解析を実行する。

```powershell
flutter analyze
```

Android端末またはエミュレーターを接続し、SAFを含む統合テストを実行する。

```powershell
flutter test integration_test
```

SAFの権限永続化をアプリプロセス再起動後にも検証する場合は、Pixel 9aなどの実機で次を実行する。2回目はアプリを強制停止した後に別プロセスでテストを起動する。

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/todo_create_test.dart -d 54271JEBF09451 --dart-define=todoCreateTestMode=permission-selection --keep-app-running
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb -s 54271JEBF09451 shell am force-stop com.example.todo_sdd
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/todo_create_test.dart -d 54271JEBF09451 --dart-define=todoCreateTestMode=permission-restart --keep-app-running
```

作成・失敗後始末の実機テストでは、次を実行する。失敗注入はdebug buildでのみ有効で、専用テストフォルダー内に限定される。

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/todo_create_test.dart -d 54271JEBF09451 --keep-app-running
```

### 期待結果

- すべてのコマンドが成功し、静的解析に新しい警告・エラーがない。
- 正常系では保存先直下に`<title>.md`が一つ作成され、Todo一覧に一度だけ表示される。
- タイトル空白、無効文字、直下の同名ファイル、書込権限不足、書込失敗では作成成功にならず、既存Markdownの内容が変わらない。
- 入力／プレビュー切替と候補選択後もタイトルおよび本文が保持される。
- タグ候補は本文先頭または空白後の有効な`#`でのみ表示され、Wikiリンク候補は有効な`[[`で表示される。コード・エスケープ内に候補を表示せず、候補のないタグとWikiリンクでEnterの動作を区別する。

## 手動シナリオ

1. 一覧の作成ボタンから作成画面を開き、タイトルだけを入力して保存する。戻った一覧に新しいTodoが一つ表示されることを確認する。
2. Markdown本文を入力し、入力／プレビューを往復する。本文が維持され、プレビュー中に編集できないことを確認する。
3. 本文先頭または空白の後に`#`と既存タグの一部を入力し、部分一致候補を選ぶ。カーソルをタグの途中に置いてもタグ全体が置換され、前後の本文が保たれることを確認する。エスケープされた`#`、非空白文字直後の`#`、インライン／複数行コードスパン／コードフェンス内では候補が表示されないことも確認する。候補がない値でEnterを押すと入力中のタグが確定し、改行が追加されないことを確認する。
4. `[[`と既存Markdownタイトルの一部を入力して候補を選ぶ。カーソルをリンク途中に置いても最初の`]]`までのトークン全体が`[[タイトル]]`に置換され、前後の本文が保たれることを確認する。エスケープ内またはMarkdownコード内では候補が表示されず、候補なしのEnterではリンクが追加されないことを確認する。
5. 空白タイトル、無効なファイル名、保存先直下の同名Markdownで保存を試す。入力値が残り、エラーが示され、既存内容が変わらないことを確認する。
6. 保存先サブフォルダーだけに同名Markdownがある状態で保存する。直下にTodoが作られ、サブフォルダーのファイルが変わらないことを確認する。
7. 本文がコードフェンスから始まる場合に作成する。`#todo`が独立した先頭行となり、一覧でTodoとして認識されることを確認する。
8. 保存先未設定／書込権限なし／I/O失敗をそれぞれ確認し、成功扱いにならず、入力が保たれて必要な対処が表示されることを確認する。読取専用で保存済みのURIからは作成画面で再選択を開始し、キャンセル時に旧設定が保たれ、新しい読取・書込権限の永続化後にのみ設定が更新されることを確認する。
9. 書込失敗後に後始末も失敗するケースを確認する。作成画面に留まり、入力が保たれ、残存Documentの相対パス、不完全ファイルであること、保存先で確認・手動削除する案内が表示されることを確認する。

## 実行記録

- `flutter test test/features/todo/todo_create_repository_test.dart test/features/todo/create_todo_screen_test.dart`: 成功。
- `flutter analyze`: 問題なし。
- Pixel 9a（`54271JEBF09451`）でフォルダー選択後にアプリを強制停止し、別プロセスから再起動後もSAF権限で保存先を読み取れることを確認。
- 同端末の`folder_access_test.dart`（4件）と`todo_create_test.dart`（7件）が成功。未設定／権限のないURI／不正な提供元の拒否、UTF-8 Markdown作成、同名Documentを変更しない競合、open/write/close失敗と別名Document作成後の対象Document削除、後始末失敗時の残存相対パス通知を確認。既存のテスト用sentinelも変更されないことを確認。
- SAFの手動キャンセルは、Androidが前回選択したテストフォルダーを自動返却してピッカーを閉じたため実機では確認できなかった。テスト中に一時設定されたURIと権限を解除し、`folder_access_test.dart`の再実行で「未設定」に戻ったことを確認。キャンセル時の画面入力保持はWidgetテストで確認。
- Pixel 9aの統合テストで生成された4つの一時Markdownだけを削除し、以前からテストフォルダーにあったファイルは保持。
