// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// 本番環境向けの複数コマンド Dart CLI アプリケーションのテンプレート例です。
///
/// `CommandRunner<int>` を使った構造化サブコマンド、`package:io` の標準 POSIX
/// 終了コード定数、および `stderr` への適切な使用方法の出力を示します。
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> args) async {
  final runner = ToolCommandRunner();

  try {
    final status = await runner.run(args);
    exitCode = status ?? ExitCode.success.code;
  } on UsageException catch (e) {
    // 使用方法に関するエラー（無効なフラグや引数）は stderr に出力します。
    stderr
      ..writeln(e.message)
      ..writeln(e.usage);
    exitCode = ExitCode.usage.code;
  } catch (e, st) {
    stderr.writeln('Fatal error: $e');
    if (args.contains('-v') || args.contains('--verbose')) {
      stderr.writeln(Trace.from(st).terse);
    }
    exitCode = ExitCode.software.code;
  }
}

class ToolCommandRunner extends CommandRunner<int> {
  ToolCommandRunner() : super('tool', '本番環境向けの複数コマンド CLI ユーティリティ。') {
    argParser
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: '失敗時に詳細なスタックトレースを表示します。',
      )
      ..addFlag('version', negatable: false, help: 'ツールのバージョンを表示します。');

    addCommand(ProcessCommand());
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.flag('version')) {
      // 本番環境では、生成された lib/src/version.dart の packageVersion を
      // (package:build_version 経由で) 参照します。
      stdout.writeln('tool のバージョン 1.0.0');
      return ExitCode.success.code;
    }
    return super.runCommand(topLevelResults);
  }
}

class ProcessCommand extends Command<int> {
  @override
  final String name = 'process';

  @override
  final String description = '入力ファイルを処理します。';

  ProcessCommand() {
    argParser.addOption(
      'input',
      abbr: 'i',
      mandatory: true,
      help: '入力ファイルのパス。',
    );
  }

  @override
  Future<int> run() async {
    final input = argResults!.option('input')!;
    stdout.writeln('$input を処理しています...');
    return ExitCode.success.code;
  }
}
