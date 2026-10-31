---
name: dart-build-cli-app
description: >-
  Dart コマンドラインインターフェイス（CLI）アプリケーションのアーキテクチャパターン、エントリーポイント構成、終了コード、ストリームの振り分け、サブプロセスの起動方法を説明します。CLI ツール、コンソールユーティリティ、スクリプトの構築、`package:args`（ArgParser または CommandRunner）による引数解析、終了コードの処理、pubspec.yaml での実行ファイル設定、Dart サブプロセスの起動、ネイティブ CLI バイナリのコンパイルに使用します。Flutter UI ウィジェット、Web アプリケーション、単独の HTTP バックエンドサーバーには使用しません。
---

# Dart CLI アプリケーションの構築

## 目次
* [1. 基本アーキテクチャとプロセスのライフサイクル](#1-core-architecture--process-lifecycle)
* [2. ストリーム、診断、書式設定](#2-streams-diagnostics--formatting)
* [3. プロジェクトの設定とパッケージング](#3-project-configuration--packaging)
* [4. 引数解析とコマンドの振り分け](#4-argument-parsing--command-routing)
* [5. ネイティブな非同期処理と最新のスタックトレース](#5-native-async--modern-stack-traces)
* [6. サブプロセスの起動と AOT 対応](#6-subprocess-spawning--aot-resilience)
* [7. シグナル処理とターミナルの後処理](#7-signal-handling--terminal-teardown)
* [8. CLI アプリケーションのテスト](#8-testing-cli-applications)
* [9. 最新のコンパイルと配布](#9-modern-compilation--distribution)
* [10. ワークフローと監査チェックリスト](#10-workflows--audit-checklist)
* [参考資料と例](#references--examples)

---

## 1. 基本アーキテクチャとプロセスのライフサイクル

### プロセスを強制終了する `exit(N)` を避ける
`dart:io` の `exit(int code)` を呼び出すと、C++ ランタイム内の `Platform::Exit(code)` が実行されます。Dart スタックを巻き戻すことなく、OS プロセスを直ちに終了します。
* **デバッガーの切断:** `--pause-isolates-on-exit` を指定して起動すると、IDE で調査できるよう終了前に VM Service が isolate を一時停止します。`exit()` は VM Service が一時停止や状態の確認を行う前に OS プロセスを終了させます。
* **カバレッジの損失:** `package:coverage` は終了時に一時停止した状態で VM Service RPC を使って実行行を取得します。`exit()` は RPC による取得前にプロセスを破棄するため、カバレッジが 0% になります。
* **バッファーの切り捨て:** `stdout` と `stderr` はバッファー付きの非同期 `IOSink` ストリームです。`exit()` はフラッシュされていないバイトを破棄します。
* **リソースリーク:** `finally` ブロック（ロックの解放、一時ディレクトリの削除など）が実行されません。

**原則:** 通常の実行中に `exit(code)` を直接呼び出すのは避けます。`exitCode = code` を設定するか、`package:args` の `CommandRunner<int>` から整数の終了コードを返し、非同期 `main()` 関数が自然に終了するようにします。未処理エラー時にも `exit()` を呼び出さず、未処理の `Error` または例外をスローして、ランタイムが正常にスタックを巻き戻し、ゼロ以外のステータスで終了するようにします。

標準 POSIX 終了コード (`/usr/include/sysexits.h`):
* `0`: 成功 (`EX_OK` / `ExitCode.success.code`)
* `64`: コマンドラインの使用方法エラー (`EX_USAGE` / `ExitCode.usage.code`)
* `65`: データ形式エラー (`EX_DATAERR` / `ExitCode.data.code`)
* `70`: 内部ソフトウェアエラー (`EX_SOFTWARE` / `ExitCode.software.code`)
* `78`: 設定エラー (`EX_CONFIG` / `ExitCode.config.code`)

*注:* マジックナンバーの整数リテラルではなく、`package:io/io.dart` をインポートして `ExitCode` 定数（例: `ExitCode.usage.code`、`ExitCode.software.code`）を使うことを推奨します。パッケージ依存関係を持たない最小限の単独スクリプトでは、標準 POSIX 整数リテラル（`0`、`64`、`70`）を使用できます。

```dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:io/io.dart' show ExitCode; // 標準 POSIX ExitCode 定数を提供する

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>('tool', 'CLI ツールの説明。');
  try {
    final status = await runner.run(args);
    exitCode = status ?? ExitCode.success.code;
  } on UsageException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(e.usage);
    exitCode = ExitCode.usage.code;
  }
}
```

### 薄いエントリーポイントのパターン（`bin/` と `lib/src/`）
`bin/*.dart` ファイルは、runner の生成、`args` の受け渡し、終了コードの待機だけを行う最小限のエントリーポイントにします。コマンド定義、引数パーサー、フォーマッター、ビジネスロジックはすべて `lib/src/` に配置します。

* **理由:** `bin/` 内のコードは `package:` URI で適切にインポートできません。ロジックを `lib/src/` に移すと、OS サブプロセスを起動せず、コマンド runner、サブコマンド階層、ビジネスロジック全体をメモリー内で数ミリ秒（`< 2ms`）でユニットテストできます。

```dart
// bin/my_cli.dart — 薄いエントリーポイント
import 'dart:io';
import 'package:my_cli/src/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
```

---

## 2. 出力、診断、書式設定

* **データと診断情報:** プログラム結果や機械可読データは `stdout` のみに出力します。警告、エラーメッセージ、デバッグログは `stderr` のみに出力します。
* **エラー時の使用方法表示:** 引数解析エラーや必須オプションのエラー（`FormatException`、`UsageException`、または `results.option(...)` で `mandatory: true` の未指定オプションにアクセスした際にスローされる `ArgumentError`）が発生した場合、エラーメッセージと使用方法のテキストの**両方を `stderr` に出力し**、終了コード `64`（`EX_USAGE` / `ExitCode.usage.code`）を返す必要があります。`stdout` に使用方法を出力するのは、ユーザーが `--help` または `-h` で明示的に要求した場合に限ります。
* **エラーハンドラーで `print()` を使わない:** `print()` は `stdout` に出力します。失敗の通知にはすべて `stderr.writeln()` を使います。標準出力には `print()` ではなく `stdout.writeln()` を優先し、[`avoid_print`](https://dart.dev/tools/linter-rules/avoid_print) lint ルールに従います（`analysis_options.yaml` で `avoid_print: false` が明示的に設定されている場合を除く）。
* **ターミナル機能と `NO_COLOR` の検出:** ANSI カラーやカーソルのエスケープコードを出力する前に、`stdout.hasTerminal`、`stdout.supportsAnsiEscapes`、および `!Platform.environment.containsKey('NO_COLOR')` を確認します。
  ```dart
  bool get useAnsi =>
      stdout.hasTerminal &&
      stdout.supportsAnsiEscapes &&
      !Platform.environment.containsKey('NO_COLOR');
  ```
* **機械可読モード:** `--json` または `--machine` フラグが渡された場合は、データを JSON として `stdout` に出力し、ログは `stderr` に出力します。

---

## 3. プロジェクトの設定とパッケージング

### プロジェクトのひな形と pubspec の実行ファイル対応付け（`executables:`）
`dart create -t console <package_name>` を使って新しいコマンドラインプロジェクトのひな形を作成すると、標準の `bin/` および `lib/` 構成が初期化されます。必ず `pubspec.yaml` の `executables:` に実行ファイルを宣言してコマンド名と `bin/` 内のスクリプトを対応付けます。これにより `bin/...dart` を指定せずに `dart run <command>` で実行でき、`dart install` 用のグローバル実行ファイルのシンボリックリンクも設定できます。

```yaml
name: my_cli
description: 高性能な CLI ツール。
version: 1.0.0

executables:
  my_cli: # bin/my_cli.dart に対応
  secondary_cmd: helper # bin/helper.dart に対応
```

### バージョン情報の一元管理（`package:build_version`）
`bin/*.dart` に `--version` の文字列をハードコードしたり、定数ファイルを手動で同期したりするのは避けます。ビルド時に `pubspec.yaml` から `const packageVersion = 'x.y.z';` を含む `lib/src/version.dart` を生成するには、`package:build_version` を使用します。

### キャッシュの規約
一時キャッシュファイルは `.dart_tool/<package_name>/` に保存します。永続的なキャッシュファイルをプロジェクトルートに直接書き込んではいけません。

---

## 4. 引数解析とコマンドの振り分け

コマンドライン引数を管理するには `package:args` をインポートします。

* **単純なスクリプト:** `ArgParser` と `addFlag()`、`addOption()` を直接使用します。
* **複数コマンドのツール:** `CommandRunner<int>` を実装し、各サブコマンド用に `Command<int>` を拡張して、POSIX 終了コードを直接返します。
* **型安全なアクセサー:** 手動の型キャスト（`as bool`、`as String?`）をなくすため、map の `operator []` によるインデックス参照ではなく、`results.flag('name')`、`results.option('name')`、`results.multiOption('name')`（`package:args` 2.5 以降で利用可能）を使用します。
* **複雑なオプションモデル:** フラグが多数あるアプリケーションでは、`package:build_cli` を使って型安全なオプションクラスを生成します。名前付きの既定値オーバーライド（例: `{String? hostDefaultOverride}`）を活用すると、設定ファイルと CLI フラグをすっきり統合できます。

---

## 5. ネイティブな非同期処理と最新のスタックトレース

* **`Chain.capture()` を避ける:** Dart VM は `await` による中断をまたいで非同期スタックフレームをネイティブに保持します。`Chain.capture` はイベントループを独自の Zone でラップするため、割り当てのオーバーヘッドが大きく、Zone の境界を越えてエラーを捕捉します。
* **`Trace.from(st).terse` で簡潔化する:** Zone を捕捉せずに、未処理エラーに対して `package:stack_trace` の静的ユーティリティを使用します。

```dart
import 'dart:io';
import 'package:io/io.dart' show ExitCode;
import 'package:stack_trace/stack_trace.dart';

Future<void> runMain(List<String> args) async {
  try {
    await executeLogic(args);
    exitCode = ExitCode.success.code;
  } catch (e, st) {
    stderr.writeln('致命的なエラー: $e');
    if (args.contains('-v') || args.contains('--verbose')) {
      stderr.writeln(Trace.from(st).terse);
    }
    exitCode = ExitCode.software.code;
  }
}
```

---

## 6. サブプロセスの起動と AOT 対応

補助プロセスとして Dart SDK を起動したり、他の Dart ツール（例: `dart format`、`dart test`、`build_runner`）を実行したりする場合:

* **`Platform.resolvedExecutable` や `Platform.executable` が `dart` コマンドライン実行ファイルを指すとは限りません:** 単独の AOT コンパイル済みバイナリ（`dart install` / `dart compile exe`）では、`resolvedExecutable` はコンパイルされたアプリケーション自体を指します。その結果、自己再帰的な起動ループやフラグ拒否によるクラッシュが起こる可能性があります。
* **`package:cli_util` を使用する:** 独自の PATH 検索やディレクトリ走査を実装するのではなく、`cli_util.dartExecutable` または `cli_util.sdkPath` で Dart SDK の実行ファイルを解決します。
* バージョン要件と詳しい技術ガイドについては、[references/aot_sdk_discovery.md](references/aot_sdk_discovery.md) を参照してください。

---

## 7. シグナル処理とターミナルの後処理

CLI がターミナルモードを変更する、スピナーを表示する、または待ち受けソケットを開く場合:

* **Windows でのシグナル保護:** Windows では `ProcessSignal.sigterm.watch()` が `UnsupportedError` をスローします。`if (!Platform.isWindows)` で `sigterm` を保護します。
* **エコーと行モードの復元:** `stdin.echoMode = false` または `stdin.lineMode = false` を設定する場合、まず `if (!stdin.hasTerminal) return;` を確認し、`SIGINT` リスナーと `finally` ブロックを設定して状態を復元します。これにより終了後もユーザーのキー入力が表示されます。
* **カーソルの表示:** ANSI のカーソル非表示コード（`\x1B[?25l`）を出力する場合は、終了時またはキャンセル時に必ずカーソル表示（`\x1B[?25h`）を復元します。
* **ソケットのクリーンアップ:** 終了シグナル時に待ち受け中の `HttpServer` または `ServerSocket` インスタンス（`server.close(force: true)`）を明示的に閉じ、OS のポートをすぐに解放します。
* 詳細なパターンについては、[references/signals_and_terminal.md](references/signals_and_terminal.md) を参照してください。

---

## 8. CLI アプリケーションのテスト

テストは次の2つのレイヤーに分けて構成します。

1. **ユニットテスト（メモリー内、`< 5ms`）:** `test/` から `package:<pkg>/src/...` をインポートし、コマンドクラス、オプション解析、ビジネスロジックを直接テストします。
2. **統合テスト（サブプロセス）:** `package:test_process` と `package:test_descriptor` を使って、バイナリのエンドツーエンド実行、プロセス I/O ストリーミング、OS 終了コードを検証します。

```dart
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

void main() {
  test('CLI が入力を処理し正常に終了する', () async {
    await d.file('input.txt', 'hello').create();

    final process = await TestProcess.start('dart', [
      'run',
      'bin/my_cli.dart',
      '--input',
      d.path('input.txt'),
    ]);

    await expectLater(process.stdout, emitsThrough('処理が完了しました。'));
    await process.shouldExit(0);
  });
}
```

---

## 9. 最新のコンパイルと配布

Dart 3.12 以降では、CLI の配布方法が `dart run` と `dart install` を中心に標準化されています（`dart pub global activate` から移行）。

* **一時実行（JIT）:** `dart run <package>@<version> [args]` は必要に応じて CLI をダウンロードして実行します。
* **グローバルインストール（ネイティブ AOT）:** `dart install <package>` はパッケージのエントリーポイントを、`~/.dart/install/bin/` に高速なネイティブ単独バイナリとしてコンパイルします。
* **ローカル開発:** `dart run <command>`（`pubspec.yaml` の `executables:` で解決）または `dart run bin/cli.dart` を使用します。
* **動的ライブラリと Code Assets のバンドル:** `dart build cli` を使用します。出力バンドルは `build/cli/_/bundle/` に生成されます。
* **単独実行ファイルのコンパイル:** `dart compile exe bin/cli.dart -o <output_path>` を使用します。

---

## 10. ワークフローと監査チェックリスト

### 実装ワークフロー
- [ ] `pubspec.yaml` の `executables:` にエントリーポイントを宣言する。
- [ ] `bin/*.dart` は薄いエントリーポイントに保ち、コマンドロジックを `lib/src/` に配置する。
- [ ] 整数の終了コードを返すか `exitCode = N` を設定し、`exit(N)` の直接呼び出しを避ける。
- [ ] 解析失敗時のエラー、警告、使用方法を `stderr` に出力する。
- [ ] 型安全性のため `results.flag()`、`results.option()`、`results.multiOption()` を使用する。
- [ ] ANSI コードを出力する前に `useAnsi` を検証する（`stdout.hasTerminal`、`supportsAnsiEscapes`、`NO_COLOR` を確認）。
- [ ] 子プロセスのツールは `cli_util.dartExecutable` を使って起動し、`Platform.resolvedExecutable` は使用しない。
- [ ] コマンド runner をメモリー内でユニットテストし、`test_process` でバイナリ実行をエンドツーエンドテストする。

---

## 参考資料と例

* **単一コマンドツールのテンプレート:** [examples/single_command_tool.dart](examples/single_command_tool.dart)
* **複数コマンド runner のテンプレート:** [examples/multi_command_runner.dart](examples/multi_command_runner.dart)
* **AOT での SDK 検出とサブプロセス起動:** [references/aot_sdk_discovery.md](references/aot_sdk_discovery.md)
* **シグナル処理とターミナルの後処理:** [references/signals_and_terminal.md](references/signals_and_terminal.md)
