// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// 単一コマンドの Dart CLI スクリプトまたはユーティリティのテンプレート例です。
///
/// `ArgParser` による引数解析、標準 I/O ストリームの振り分け、
/// および `exitCode` を使った非破壊的な終了コードの設定方法を示します。
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: '使用方法を表示します。')
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: '致命的なエラー時に詳細なスタックトレースを表示します。',
    )
    ..addOption('input', abbr: 'i', mandatory: true, help: '処理する入力ファイルのパス。');

  try {
    final results = parser.parse(args);

    if (results.flag('help')) {
      // ユーザーがヘルプを明示的に要求した場合は、使用方法を stdout に出力します。
      stdout
        ..writeln('使用方法: tool [options]')
        ..writeln(parser.usage);
      return;
    }

    await _runTool(results);
  } on FormatException catch (e) {
    // 引数の解析エラーでは、エラーメッセージと使用方法を stderr に出力します。
    stderr
      ..writeln('エラー: ${e.message}')
      ..writeln(parser.usage);
    exitCode = ExitCode.usage.code;
  } on ArgumentError catch (e) {
    // 必須オプションがない場合に results.option() がスローします。
    stderr
      ..writeln('エラー: ${e.message}')
      ..writeln(parser.usage);
    exitCode = ExitCode.usage.code;
  } catch (e, st) {
    stderr.writeln('致命的なエラー: $e');
    if (args.contains('-v') || args.contains('--verbose')) {
      stderr.writeln(Trace.from(st).terse);
    }
    exitCode = ExitCode.software.code;
  }
}

/// ツールの中核となるビジネスロジックをカプセル化します。
///
/// 大規模なアプリケーションでは、このロジックを `bin/` に直接置かず
/// `lib/src/` に配置してください。そうすれば OS のサブプロセスを起動せずに、
/// 単体テストから関数を直接インポートしてテストできます。
Future<void> _runTool(ArgResults args) async {
  final inputPath = args.option('input')!;
  stdout.writeln('$inputPath を処理しています...');
}
