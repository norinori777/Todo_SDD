// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';

/// ホスト OS のグローバルな `p.*` 関数ではなく、[FileSystem] 自身のパスコンテキストを使ってサブディレクトリ名を列挙します。
List<String> listSubdirectoryNames(Directory dir) {
  final pathContext = dir.fileSystem.path;
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => pathContext.basename(d.path))
      .toList();
}

void main() {
  // Linux/macOS 上の単体テスト内で Windows ファイルシステムをシミュレートします。
  final fs = MemoryFileSystem(style: FileSystemStyle.windows);
  final projectDir = fs.directory(r'C:\workspace\app\lib')
    ..createSync(recursive: true);
  fs.directory(r'C:\workspace\app\lib\src').createSync();

  final subdirs = listSubdirectoryNames(projectDir);
  print('サブディレクトリ: $subdirs');
}
