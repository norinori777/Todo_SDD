---
name: dart-collect-coverage
description: coverage パッケージを使ってカバレッジを収集し、LCOV レポートを作成します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:14:32 GMT
---
# Dart および Flutter のテストカバレッジの実装

## 目次
- [テストの基礎](#testing-fundamentals)
- [カバレッジディレクティブ](#coverage-directives)
- [ワークフロー: カバレッジレポートの構成と生成](#workflow-configuring-and-generating-coverage-reports)
- [ワークフロー: 高度な手動カバレッジ収集](#workflow-advanced-manual-coverage-collection)
- [例](#examples)

## テストの基礎

標準的な Dart のテスト手法に従ってテストスイートを構成します。Dart プロジェクトでは `package:test` を、Flutter プロジェクトでは `flutter_test` を使用します。

- **単体テスト:** 個々の関数、メソッド、またはクラスを検証します。
- **コンポーネント／ウィジェットテスト:** モックオブジェクト（`package:mockito`）を使って、コンポーネントの動作、レイアウト、インタラクションを検証します。
- **統合テスト:** シミュレーターまたは実機で、アプリ全体のフローを検証します。

## カバレッジディレクティブ

インラインコメントを使って、特定の行、ブロック、またはファイル全体をカバレッジ指標から除外します。フォーマット時に `--check-ignore` フラグを渡すと、これらのディレクティブをチェックできます。

- 1 行を無視する: `// coverage:ignore-line`
- コードブロックを無視する: `// coverage:ignore-start` と `// coverage:ignore-end`
- ファイル全体を無視する: `// coverage:ignore-file`

## ワークフロー: カバレッジレポートの構成と生成

次の手順に沿って coverage パッケージを追加し、テストを実行して、LCOV レポートを生成します。

**作業の進捗チェックリスト:**
- [ ] 1. `coverage` を `dev_dependency` として追加する。
- [ ] 2. 自動カバレッジスクリプトを実行する。
- [ ] 3. LCOV 出力を検証する。

### 1. 依存関係の追加
`coverage` パッケージをプロジェクトの `dev_dependency` として追加します。通常の依存関係には追加しないでください。

標準的な Dart プロジェクトの場合:
```bash
dart pub add dev:coverage
```

Flutter プロジェクトの場合:
```bash
flutter pub add dev:coverage
```

### 2. カバレッジの収集と LCOV の生成
同梱の `test_with_coverage` スクリプトを使用します。このスクリプトは、すべてのテストを自動実行し、Dart VM から JSON 形式のカバレッジデータを収集して、LCOV レポートに整形します。

```bash
dart run coverage:test_with_coverage
```
*注: Dart workspace（モノレポ）で作業する場合は、テストディレクトリを明示的に指定します（例: `dart run coverage:test_with_coverage -- pkgs/foo/test pkgs/bar/test`）。*

### 3. フィードバックループ: 出力の検証
**検証を実行 -> エラーを確認 -> 修正:**
1. プロジェクトルートに `coverage/` ディレクトリが作成されたことを確認します。
2. `coverage/coverage.json`（生データ）と `coverage/lcov.info`（整形済みレポート）が存在することを確認します。
3. 特定のファイルのカバレッジがない場合は、テストファイルからインポートされ実行されていることを確認します。意図的に除外する場合は `// coverage:ignore-file` を追加します。

## ワークフロー: 高度な手動カバレッジ収集

VM サービスを細かく制御する必要がある場合、isolate の一時停止を制御する場合、または分岐／関数単位のカバレッジが必要な場合は、手動収集ワークフローを使用します。

**作業の進捗チェックリスト:**
- [ ] 1. VM サービスを有効にしてテストを実行する。
- [ ] 2. 生の JSON カバレッジを収集する。
- [ ] 3. JSON を LCOV に整形する。

### 1. VM サービスを使ったテストの実行
終了時に isolate を一時停止し、特定のポート（例: 8181）で VM サービスを公開しながらテストを実行します。

```bash
dart run --pause-isolates-on-exit --disable-service-auth-codes --enable-vm-service=8181 test &
```

### 2. 生のカバレッジの収集
実行中の VM サービスからカバレッジデータを取得し、JSON ファイルに出力します。

```bash
dart run coverage:collect_coverage --wait-paused --uri=http://127.0.0.1:8181/ -o coverage/coverage.json --resume-isolates
```
*任意: より詳細な指標を収集するには `--function-coverage` と `--branch-coverage` を追加します（Dart VM 2.17.0 以降が必要です）。*

### 3. LCOV への整形
生の JSON データを標準の LCOV 形式に変換します。

```bash
dart run coverage:format_coverage --packages=.dart_tool/package_config.json --lcov -i coverage/coverage.json -o coverage/lcov.info --check-ignore
```

## 例

### 例: `pubspec.yaml` の構成
`coverage` パッケージが `pubspec.yaml` の `dev_dependencies` のみに含まれていることを確認します。

```yaml
name: my_dart_app
environment:
  sdk: ^3.0.0

dependencies:
  path: ^1.8.0

dev_dependencies:
  test: ^1.24.0
  coverage: ^1.15.0
```

### 例: 無視ディレクティブの適用
生成コードやテストできないエッジケースによってカバレッジスコアが低下しないよう、無視ディレクティブを使用します。

```dart
// coverage:ignore-file
import 'package:meta/meta.dart';

class SystemConfig {
  final String env;

  SystemConfig(this.env);

  // coverage:ignore-start
  void legacyInit() {
    print('非推奨の初期化');
  }
  // coverage:ignore-end

  bool isProduction() {
    if (env == 'prod') return true;
    return false; // coverage:ignore-line
  }
}
```
