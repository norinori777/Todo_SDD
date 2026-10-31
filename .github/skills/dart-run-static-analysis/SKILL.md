---
name: dart-run-static-analysis
description: `dart analyze` を実行して警告やエラーを特定し、`dart fix --apply` を使って機械的な lint の問題を自動修正します。開発中のコード品質の確保や、変更のコミット前に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:09:34 GMT
---
# Dart コードの解析と修正

## 目次
- [解析の構成](#analysis-configuration)
- [診断の抑制](#diagnostic-suppression)
- [ワークフロー: 静的解析の実行](#workflow-executing-static-analysis)
- [ワークフロー: 自動修正の適用](#workflow-applying-automated-fixes)
- [例](#examples)

## 解析の構成

パッケージルートにある `analysis_options.yaml` ファイルで Dart analyzer を構成します。

- **基本構成:** `include:` ディレクティブを使って、標準ルールセット（例: `package:lints/recommended.yaml` または `package:flutter_lints/flutter.yaml`）を必ず読み込みます。
- **厳密な型チェック:** 暗黙のダウンキャストや `dynamic` の推論を防ぐため、`analyzer: language:` ノードで厳密な型チェックを有効にします。`strict-casts: true`、`strict-inference: true`、`strict-raw-types: true` を設定します。
- **Linter ルール:** `linter: rules:` ノードで個別のルールを明示的に有効または無効にします。読み込み済みルールを上書きする場合はキーと値のマップ（`rule_name: true/false`）を、新しいルールセットを定義する場合はリスト（`- rule_name`）を使います。同じ `rules` ブロックでリスト構文とマップ構文を混在させないでください。
- **フォーマッターの構成:** `formatter:` ノードで `dart format` の動作を設定します。`page_width`（既定値 80）と `trailing_commas`（`automate` または `preserve`）を指定します。
- **Analyzer プラグイン:** `analyzer: plugins:` ノードにプラグインを追加して、カスタム診断を有効にします。プラグインパッケージが `pubspec.yaml` の `dev_dependency` に追加されていることを確認します。

## 診断の抑制

診断（lint または警告）が誤検知である場合や、生成コードに適用される場合は、明示的に抑制します。

- **ファイル単位の除外:** `analysis_options.yaml` の `analyzer: exclude:` ノードで glob パターンを使い、ファイルやディレクトリ全体（例: `**/*.g.dart`）を除外します。
- **ファイル単位の抑制:** Dart ファイルの先頭に `// ignore_for_file: <diagnostic_code>` を追加すると、そのファイル全体で特定の診断を抑制できます。すべての Linter ルールを抑制するには `// ignore_for_file: type=lint` を使います。
- **行単位の抑制:** 問題のコードの直前の行、または問題の行の末尾に `// ignore: <diagnostic_code>` を追加します。
- **Pubspec の抑制:** `pubspec.yaml` ファイルで問題の行の上に `# ignore: <diagnostic_code>` を追加します（例: `# ignore: sort_pub_dependencies`）。
- **プラグイン診断:** プラグイン固有の問題を抑制する場合は、診断コードの前にプラグイン名を付けます（例: `// ignore: some_plugin/some_code`）。

## ワークフロー: 静的解析の実行

このワークフローで、型に関するバグ、スタイル違反、実行時エラーの可能性を特定します。

**作業の進捗:**
- [ ] 1. プロジェクトルートに `analysis_options.yaml` が存在することを確認する。
- [ ] 2. `analyze_files` MCP ツール（利用可能な場合）または CLI コマンド `dart analyze <target_directory>` で analyzer を実行する。
- [ ] 3. 診断結果を確認する。
- [ ] 4. info レベルの問題も失敗として扱う必要がある場合は、`--fatal-infos` フラグを追加する。
- [ ] 5. 報告されたエラーを手動で解決するか、「自動修正の適用」ワークフローに進む。

## ワークフロー: 自動修正の適用

このワークフローを使って、古い API の使用を解消し、クイックフィックスを適用し、コードを移行します（例: Dart 3 への移行）。

**作業の進捗:**
- [ ] 1. `dart_fix` MCP ツールまたは CLI コマンド `dart fix --dry-run` でドライランを実行し、変更案を確認する。
- [ ] 2. 修正案が意図したアーキテクチャに沿っていることを確認する。
- [ ] 3. 追加の修正が必要な場合は、該当する Linter ルールが `analysis_options.yaml` で有効になっていることを確認する。
- [ ] 4. `dart_fix` MCP ツールまたは CLI コマンド `dart fix --apply` で修正を適用する。
- [ ] 5. `dart_format` MCP ツールまたは CLI コマンド `dart format .` で変更したコードをフォーマットする。
- [ ] 6. 静的解析ワークフローを実行し、すべての診断が解消されたことを確認する。

## 例

### 網羅的な `analysis_options.yaml`

```yaml
include: package:flutter_lints/recommended.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "lib/generated/**"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    todo: ignore
    invalid_assignment: warning
    missing_return: error

linter:
  rules:
    avoid_shadowing_type_parameters: false
    await_only_futures: true
    use_super_parameters: true

formatter:
  page_width: 100
  trailing_commas: preserve
```

### 診断のインライン抑制

```dart
// ファイル全体で抑制
// ignore_for_file: unused_local_variable, dead_code

void processData() {
  // 特定の行で抑制
  // ignore: invalid_assignment
  int x = '';
  
  const y = 10; // ignore: constant_identifier_names
}
```
