# AOT / JIT 環境での Dart SDK 検出とサブプロセスの起動

JIT（`dart run`、`pub global activate`）およびスタンドアロン AOT（`dart compile exe`、`dart install`）の実行モードで、Dart SDK を検出し、Dart の子プロセスを起動する方法を説明します。

---

## 1. AOT での SDK 検出に関する落とし穴

`dart` の子プロセスを起動する CLI 開発ツール（`build_runner`、`dart format`、`dart test`、コードアナライザーなど）を書く際、次のようなコードをよく見かけます。

```dart
// ❌ WRONG: Breaks when compiled to AOT
final dart = Platform.resolvedExecutable;
final sdkDir = path.dirname(path.dirname(dart));
```

### スタンドアロン AOT で失敗する理由
* **JIT VM（`dart run`、`pub global activate`）**: `Platform.resolvedExecutable` は `<dart-sdk>/bin/dart` を直接指します。`dirname(dirname(...))` を呼び出すと、有効な SDK のルートディレクトリになります。
* **AOT バイナリ（`dart compile exe`、`dart install`）**: `Platform.resolvedExecutable` はコンパイル済みアプリケーションのバイナリ（例: `~/.dart/install/app-bundles/my_cli/.../bin/my_cli`）を指します。

### 単純なパス解決による問題
1. **サブプロセスの再帰的なループ**: `dart` VM を起動するつもりでアプリケーションが `Platform.resolvedExecutable` を実行すると、自分自身を再帰的に起動します。
2. **フラグ拒否によるクラッシュ**: 子プロセスに VM フラグ（`--observe`、`--enable-vm-service` など）やツールのサブコマンド（`run`、`format`、`test` など）を渡すと、コンパイル済みバイナリは不明なオプションのエラーを出して即座に失敗します。
3. **誤った SDK ルート**: SDK のリソース（`libraries.json` など）を探すために `Platform.resolvedExecutable` から親ディレクトリをたどっても、バイナリは Dart SDK のインストール先ではなくアプリケーションのバンドル内にあるため、正しい場所を見つけられません。

---

## 2. 解決策: `package:cli_util`（`^0.6.0`）

独自の SDK 検出処理を実装しないでください。JIT と AOT の両環境で Dart SDK を検出する、メモ化された nullable getter（`dartExecutable`、`sdkPath`）を備える `package:cli_util`（バージョン 0.6.0 以降）に依存してください。

```dart
import 'dart:io' as io;
import 'package:cli_util/cli_util.dart' as cli_util;

Future<void> runSubprocess() async {
  // JIT と AOT の両環境で dart 実行ファイルを解決します。
  final dartExe = cli_util.dartExecutable;
  if (dartExe == null) {
    io.stderr.writeln('エラー: PATH 上に Dart SDK が見つかりません。');
    io.exitCode = 1;
    return;
  }

  final result = await io.Process.run(dartExe, ['format', '.']);
  io.stdout.write(result.stdout);
  io.stderr.write(result.stderr);
}
```

### Dart SDK が配置されている可能性のある場所
Dart SDK と `dart` 実行ファイルは、開発環境によって次のような場所に存在します。
* **実行中の VM（`Platform.resolvedExecutable`）**: JIT VM（`dart run`）で実行している場合、`resolvedExecutable` は `<dart-sdk>/bin/dart` を直接指します。
* **明示的な環境変数（`DART_SDK`）**: 開発者が SDK のインストールディレクトリを `DART_SDK` に明示的に指定している場合です。
* **システムの `PATH`**: シンボリックリンクを解決し、Flutter のインストールでは `bin/cache/dart-sdk` も確認しながら、システムの `PATH` エントリー（`dart`、`dart.exe`、`dart.bat`）から解決します。
* **Flutter ルート（`FLUTTER_ROOT`）**: `FLUTTER_ROOT/bin/cache/dart-sdk` にバンドルされています。

検索順序や SDK ディレクトリの検証ロジックをアプリケーションコードで再実装せず、`package:cli_util` に委ねてください。

---

## 3. サブプロセス起動時の必須事項

Dart CLI から子プロセスを実行する場合は、次のルールに従ってください。

1. **必ず `cli_util.dartExecutable` を使う**: `Platform.executable` や `Platform.resolvedExecutable` を渡さないでください。
2. **`PATH` 上の `'dart'` にフォールバックする**: `package:cli_util` を使用できない場合は、`Process.start('dart', [...], runInShell: Platform.isWindows)` を使い、文字列 `'dart'` を直接実行してください。
3. **Windows のバッチファイルを扱う**: Windows では Flutter が `flutter/bin` に `dart.bat` をインストールします。解決済みの `dart.exe` を指定する場合を除き、`Process.start` でバッチファイルを直接起動するには `runInShell: true` が必要です。
