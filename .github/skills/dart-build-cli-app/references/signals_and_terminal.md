# シグナル処理、ターミナルの復元、ストリームの堅牢性

Dart CLI アプリケーションにおけるクロスプラットフォームのシグナル監視、ターミナルモードの復元、ネットワークリソースの解放、パイプ切断への対処方法を説明します。

---

## 1. クロスプラットフォームのシグナル処理

Windows では POSIX の `SIGTERM` が実装されていないため、標準 POSIX シグナル（`SIGINT`、`SIGTERM`）にはプラットフォーム固有のガードが必要です。

### Windows での `SIGTERM` ガード規則
Windows で `ProcessSignal.sigterm.watch()` を呼び出すと、捕捉されない `UnsupportedError` が発生します。複数プラットフォームに対応するシグナルハンドラーでは、必ず `sigterm` をガードしてください。

```dart
import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';

/// Windows、macOS、Linux でプロセス終了シグナルを監視します。
Stream<ProcessSignal> watchTerminationSignals() {
  if (Platform.isWindows) {
    return ProcessSignal.sigint.watch();
  }
  return StreamGroup.merge([
    ProcessSignal.sigint.watch(),
    ProcessSignal.sigterm.watch(),
  ]);
}
```

---

## 2. ターミナルモードとカーソルの復元

CLI がターミナルの状態を変更する場合（対話型メニュー、パスワード入力プロンプト、進行状況スピナーなど）は、次の点に注意してください。

### A. Raw モードの解除（`echoMode` と `lineMode`）
`stdin.echoMode = false` または `stdin.lineMode = false` を設定する場合、ユーザーによるキャンセル（`Ctrl+C` / `SIGINT`）時に元へ戻すシグナルハンドラーを登録してください。そうしないと、終了後もホストシェルが raw モードのままになり、キー入力が表示されなくなります。

```dart
import 'dart:io';

void enableInteractiveMode() {
  // 標準入力が対話型 TTY の場合に限り、ターミナルモードを設定します。
  if (!stdin.hasTerminal) return;
  stdin.echoMode = false;
  stdin.lineMode = false;

  // Ctrl+C を受けたときにターミナルの状態を同期的に復元します。
  final sub = ProcessSignal.sigint.watch().listen((_) {
    restoreTerminal();
    // 128 + SIGINT (2) = 130 で終了するのは、非同期シグナルハンドラーが
    // シグナルによる中断をホストシェルへ伝える標準的な POSIX の方式です。
    exit(130);
  });

  try {
    // Run interactive loop...
  } finally {
    sub.cancel();
    restoreTerminal();
  }
}

void restoreTerminal() {
  if (stdin.hasTerminal) {
    stdin.lineMode = true;
    stdin.echoMode = true;
  }
}
```

### B. カーソルの表示（スピナーと進行状況バー）
カーソルを隠す ANSI エスケープコード（`\x1B[?25l`）を出力する場合は、`finally` ブロックとシグナルハンドラー内で必ずカーソル表示（`\x1B[?25h`）を復元してください。

```dart
void showCursor() {
  if (useAnsi) {
    stdout.write('\x1B[?25h');
  }
}

/// NO_COLOR 標準に従って ANSI 対応状況を判定します。
bool get useAnsi =>
    stdout.hasTerminal &&
    stdout.supportsAnsiEscapes &&
    !Platform.environment.containsKey('NO_COLOR');
```

---

## 3. サーバーソケットと子プロセスの終了処理

* **リッスン中のソケット**: CLI が `HttpServer` または TCP `ServerSocket` を起動する場合、終了シグナルを監視して直ちにソケットを閉じてください（`server.close(force: true)`）。カーネルのソケットタイムアウトを待たずに、OS がポートの割り当てを解放できます。
* **子プロセス**: 長時間実行される子プロセスを起動する場合は、親プロセスの終了前にシグナルを転送する終了リスナー（`childProcess.kill(ProcessSignal.sigterm)`）を登録し、孤立したバックグラウンドプロセスが残らないようにしてください。

---

## 4. Broken pipe（`EPIPE` / `SocketException`）への対処

CLI の出力を早期に終了する後続コマンドへパイプで渡す場合（例: `my_cli | head -n 5`、`my_cli | grep -q foo`）、後続プロセスがパイプを閉じます。その後 `stdout` へ書き込むと、`SocketException: Broken pipe (errno = 32)` がスローされます。

不要なクラッシュトレースを `stderr` に出力せずに、broken pipe の例外を処理します。

```dart
import 'dart:io';

Future<void> safeWriteln(String line) async {
  try {
    stdout.writeln(line);
  } on SocketException catch (e) {
    // EPIPE / Broken pipe: 後続プロセスが標準入力を閉じました。
    if (e.osError?.errorCode == 32 || e.message.contains('Broken pipe')) {
      await stdout.close().catchError((_) {});
      // 大量のデータをストリーミングしている場合、後続プロセスがパイプを閉じた時点で
      // exit(0) を呼び出すと、生成側のループを直ちに停止できます。
      exit(0);
    }
    rethrow;
  }
}
```
