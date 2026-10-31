// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

/// [file] が `canvaskit` ディレクトリ内にあり、拡張子が `.wasm` かどうかを確認します。
bool isCanvasKitWasmAsset(File file) {
  final segments = p.split(file.path);
  return segments.contains('canvaskit') && p.extension(file.path) == '.wasm';
}

/// OS 固有のファイルパスを POSIX 形式の Web アセットキーに変換します。
String computeWebAssetKey(String filePath, String projectRoot) {
  final relative = p.relative(filePath, from: projectRoot);
  final segments = p.split(relative);
  return switch (segments) {
    ['assets', ...] => p.posix.joinAll(segments),
    _ => p.posix.joinAll(['assets', ...segments]),
  };
}

/// 複合拡張子（例: `.js.map`）と複数のドットを含むファイル名（例: `main.dart.wasm`）を適切に扱い、拡張子の前にコンテンツハッシュを挿入します。
String insertContentHash(String filename, String hash) {
  final compoundExt = p.extension(filename, 2);
  final ext = compoundExt.endsWith('.map')
      ? compoundExt
      : p.extension(filename);
  final stem = filename.substring(0, filename.length - ext.length);
  return '$stem.$hash$ext';
}

/// OS 固有の相対パスを、`.gitignore`、`.gitattributes`、Git ツリーオブジェクトに適した POSIX 形式のパスへ変換します。
String toGitPath(String relativeNativePath) =>
    p.posix.joinAll(p.split(relativeNativePath));

void main() {
  final nativeSamplePath = p.join('lib', 'src', 'file.dart');
  print('Git パス: ${toGitPath(nativeSamplePath)}');
  print('アセットキー: ${computeWebAssetKey(p.join('assets', 'icon.png'), '.')}');
  print('コンテンツハッシュ: ${insertContentHash('main.dart.js.map', 'a1b2c3')}');
}
