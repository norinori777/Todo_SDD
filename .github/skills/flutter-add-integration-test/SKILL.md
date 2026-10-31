---
name: flutter-add-integration-test
description: Flutter の integration_test と flutter_test を使ってユーザーフローを永続的な統合テストにします。プロジェクトに統合テストを追加する場合や、対応するMCPツールでUIを調査する場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 18:29:20 GMT
---
# Flutter 統合テストの実装

## 目次
- [プロジェクトのセットアップと依存関係](#project-setup-and-dependencies)
- [MCP を使った対話的な調査](#interactive-exploration-via-mcp)
- [テスト作成のガイドライン](#test-authoring-guidelines)
- [テストの実行](#テストの実行)
- [ワークフロー: エンドツーエンド統合テスト](#workflow-end-to-end-integration-testing)
- [例](#examples)

## プロジェクトのセットアップと依存関係

Flutter標準の `integration_test` と `flutter_test` を使い、[テスト戦略](../../../agents/rules/flutter-todo/testing-strategy.md)に従ってプロジェクトを構成します。通常の統合テストのためにFlutter Driver拡張を有効にする必要はありません。

1. `pubspec.yaml` に必要な開発依存関係がない場合は追加します。
   ```bash
   flutter pub add 'dev:integration_test:{"sdk":"flutter"}'
   flutter pub add 'dev:flutter_test:{"sdk":"flutter"}'
   ```
2. 必要に応じて、アプリケーションコードの重要なウィジェットに `Key` パラメーター（例: `ValueKey('login_button')`）を追加します。

## MCP を使った対話的な調査

利用可能な場合は、Dart／Flutter MCP サーバーツールを使ってアプリケーションの状態を対話的に調査・操作します。利用できない場合も通常の統合テストを作成・実行します。

- **起動:** プロジェクトのアプリケーションエントリーポイントを指定して `launch_app` を実行し、アプリケーションを起動して DTD URI を取得します。
- **調査:** `get_widget_tree` を実行し、利用可能な `Key`、`Text` ノード、ウィジェットの `Type` を調べます。
- **操作:** `tap`、`enter_text`、`scroll` を実行してユーザーフローをシミュレートします。
- **待機:** 画面遷移やアニメーション開始時は、必ず `waitFor` を実行するか、`get_health` で状態を検証します。
- **未マウントのウィジェットのトラブルシューティング:** ツリーにウィジェットが見つからない場合、`SliverList` または `ListView` で遅延読み込みされている可能性があります。操作する前に `scroll` または `scrollIntoView` を実行し、ウィジェットをマウントします。

## テスト作成のガイドライン

`flutter_test` API の方式に従って統合テストを構成します。

- プロジェクトルートに専用の `integration_test/` ディレクトリを作成します。
- すべてのテストファイルを `<name>_test.dart` という規則に従って命名します。
- `main()` の先頭で `IntegrationTestWidgetsFlutterBinding.ensureInitialized();` を呼び出してバインディングを初期化します。
- `await tester.pumpWidget(MyApp());` を使ってアプリケーション UI を読み込みます。
- `tester.tap()` などの操作後に `await tester.pumpAndSettle();` を使ってフレームを進め、アニメーションの完了を待ちます。
- `expect(find.byKey(ValueKey('foo')), findsOneWidget);` または `findsNothing` を使って、ウィジェットの表示をアサートします。
- `await tester.scrollUntilVisible(itemFinder, 500.0, scrollable: listFinder);` を使って、画面外にある特定のウィジェットまでスクロールします。

## テストの実行

対象のデバイスを接続または起動し、プロジェクトルートで `flutter test integration_test` を実行します。対象を絞る場合は `flutter test integration_test/app_test.dart` を使用します。必要に応じて `-d <device-id>` でデバイスを指定します。

## ワークフロー: エンドツーエンド統合テスト

このチェックリストをコピーして、統合テストの実装と検証に使用します。

- [ ] **作業の進捗: セットアップ**
  - [ ] `integration_test` と `flutter_test` が `pubspec.yaml` にあることを確認し、なければ追加する。
  - [ ] 必要に応じて対象ウィジェットに `ValueKey` を割り当てる。
- [ ] **作業の進捗: 調査（MCPを利用できる場合）**
  - [ ] MCP 経由で `launch_app` を実行する。
  - [ ] `get_widget_tree` を使ってウィジェットツリーを把握する。
  - [ ] MCP ツール（`tap`、`enter_text`）を使って操作経路を検証する。
- [ ] **作業の進捗: テスト作成**
  - [ ] `integration_test/app_test.dart` を作成する。
  - [ ] `WidgetTester` API を使ってテストケースを記述する。
- [ ] **作業の進捗: 実行とフィードバックループ**
  - [ ] `flutter test integration_test` を実行する。
  - [ ] **フィードバックループ:** テスト出力を確認します -> `PumpAndSettleTimedOutException` が発生した場合は無限アニメーションを確認します -> ウィジェットが見つからない場合は `scrollUntilVisible` を追加します -> テストが成功するまで再実行します。

## 例

### 標準的な統合テスト (`integration_test/app_test.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('エンドツーエンドテスト', () {
    testWidgets('フローティングアクションボタンをタップしてカウンターを確認する', (tester) async {
      // アプリのウィジェットを読み込む。
      await tester.pumpWidget(const MyApp());

      // カウンターの初期値が 0 であることを確認する。
      expect(find.text('0'), findsOneWidget);

      // タップするフローティングアクションボタンを検索する。
      final fab = find.byKey(const ValueKey('increment'));

      // フローティングアクションボタンのタップをシミュレートする。
      await tester.tap(fab);

      // フレームを進め、アニメーションの完了を待つ。
      await tester.pumpAndSettle();

      // カウンターが 1 増えたことを確認する。
      expect(find.text('1'), findsOneWidget);
    });
  });
}
```
