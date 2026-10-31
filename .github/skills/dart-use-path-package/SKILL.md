---
name: dart-use-path-package
description: >-
  `package:path` と `package:file` を使った、クロスプラットフォーム対応のファイル／ディレクトリパス操作、セグメント分割、拡張子抽出、コンテキスト変換。ファイルパス、ディレクトリ名、拡張子の作成、調査、結合、分割、リファクタリングや、生の文字列によるパス操作（`.split('/')`、`'$dir/$file'`、`.endsWith('.ext')`、`.replaceAll('\\', '/')`）の置き換えに使用します。HTTP ネットワーク URI のルーティング、データベースのクエリ文字列、パス以外の文字列処理には使用しないでください。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Wed, 23 Sep 2026 22:10:00 GMT
---

# Dart での安全なクロスプラットフォームパス操作

## 目次
* [1. 基本原則とクロスプラットフォーム規則](#1-core-principles--cross-platform-rules)
* [2. 推奨する package:path の慣用表現と文字列操作のアンチパターン](#2-recommended-packagepath-idioms-vs-string-anti-patterns)
* [3. ネイティブパスから POSIX、Git、URL コンテキストへの変換](#3-bridging-native-paths-to-posix-git--url-contexts)
* [4. モック可能なファイルシステム（`package:file` とグローバル `p.*`）](#4-mockable-file-systems-packagefile-vs-global-p)
* [5. 拡張子、複合拡張子、ベース名の抽出](#5-extensions-compound-extensions--stem-extraction)
* [6. ワークフローと監査チェックリスト](#6-workflows--audit-checklist)
* [参考資料と例](#references--examples)

---

## 1. 基本原則とクロスプラットフォーム規則

### ファイルパスを生の文字列として扱わない
* Windows のネイティブファイルパスではバックスラッシュ（`\`）を、macOS と Linux ではスラッシュ（`/`）を使用します。
* `.contains('foo/')`、`.startsWith('foo/')`、`.split('/')` のような文字列操作は、Windows のネイティブパスでは気付かないまま失敗します。
* `'$dir/$file'` のような文字列補間は Windows でもスラッシュを挿入し、`$dir` が末尾の区切り文字で終わる場合は重複したスラッシュ（`//`）を生成します。

**規則:** ディレクトリ階層やセグメント名を調べる前に、必ず `p.split(path)` でパスをセグメントに分解し、パス要素の結合には常に `p.join(...)` を使います。

### 境界での実用的な結合と複数セグメントへの分解（`p.join`）
* **クロスプラットフォームライブラリ（Windows + POSIX）:** 個別のパスセグメントを `p.join(dir, 'sub', 'file.json')` に渡すと、`package:path` が各要素の間に OS ネイティブの区切り文字（Windows では `\`、POSIX では `/`）を挿入します。
* **POSIX 専用ツールと静的サブパスの検索性:** Linux／macOS のみを対象とするコードベース（または動的なベースパスを既知の静的サブパスと結合する場合）では、5～6 個の静的セグメントを個別の引数（`p.join(home, '.local', 'share', 'app', 'bin', 'config.json')`）に分けると、`dart format` によって 6～8 行に折り返され、部分文字列の検索性（`.local/share/app/bin` に対する `grep`／`code_search`）が**損なわれます**。
* **POSIX 対象の規則:** **2 引数で境界を結合する方法**（`p.join(home, '.local/share/app/bin/config.json')`）を優先します。これにより、変数の境界で重複スラッシュ（`//`）が発生するバグを防ぎつつ、1 行で読みやすく、文字列全体を正確に検索できる状態を保てます。

### 正規化と正準化（`p.normalize` と `p.canonicalize`）
* `p.normalize(path)` はファイルシステムを参照したり大文字・小文字を統一したりせず、`.` と `..` のセグメントを字句的に解決します。
* ディレクトリパスの重複を排除するときや、シンボリックリンク、相対ルート、大文字・小文字を区別しないファイルシステムをまたいで実ファイルの同一性を比較するときは、`p.canonicalize(path)` を使用します。

### 位置指定子の除去と URI の安全な変換
* `<path>:<line>-<col>` または `<path>:<line>` 形式の文字列は純粋なファイルパスではありません。そのまま `p.normalize` や `Uri.parse` に渡すとバグになります（Windows では `Uri.parse` が `C:` を URI スキーム、`:line` をポートと誤認します）。
* ファイルパスを `package:path` に渡す**前に**、正規表現（`RegExp(r'^(.*?):(\d+(?:-\d+)?)$')`）を使って末尾の `:line-col` 接尾辞を取り除きます。
* **URI 境界での変換:** ファイルパスと `Uri` オブジェクトを相互変換する場合は、`Uri.parse(path)` や手作業による文字列連結ではなく、必ず `p.toUri(path)` と `p.fromUri(uri)` を使用します。

---

## 2. 推奨する package:path の慣用表現と文字列操作のアンチパターン

### パスの結合
* **推奨:** `p.join(dir, file)`
* **避ける:** `'$dir/$file'` または `'a/$b'`
* **理由:** 文字列補間は Windows でも `/` を挿入し、`$dir` が末尾の区切り文字で終わる場合は重複したスラッシュ（`//`）を生成します。

### セグメントの照合
* **推奨:** `p.split(path).contains('foo')`
* **避ける:** `path.contains('foo/')`
* **理由:** 文字列照合は Windows のバックスラッシュ（`foo\bar`）では失敗し、部分文字列の名前（例: `barfoo/`）を誤って一致と判定します。

### ルートとディレクトリのプレフィックス
* **推奨:** `if (p.split(path) case ['foo', ...])`（末尾のセグメントを取り出す場合は `case ['foo', ...final rest]`）、または `p.isWithin('foo', path)`
* **避ける:** `path.startsWith('foo/')` または `p.split(path).first == 'foo'`
* **理由:** 文字列によるプレフィックス照合は Windows の区切り文字（`foo\bar`）では失敗します。`p.split(path).first` はリストが空の場合に `StateError` をスローし、別途 `.skip(1)` でスライスする必要があります。一方、リストパターンは空でないことを安全に確認し、複数セグメントのプレフィックスに一致し、必要なら `...final rest` も一度に束縛できます。`./foo/bar` のような正規化されていない相対プレフィックスが含まれる可能性がある場合は、`p.isWithin('foo', path)`（または `p.split(p.normalize(path))`）を使用します。

### ファイル拡張子
* **推奨:** `p.extension(path) == '.wasm'`
* **避ける:** `path.endsWith('.wasm')`
* **理由:** 部分文字列による接尾辞照合では、ディレクトリ（`foo.wasm/`）や拡張子ではない接尾辞も誤って一致します。

### 拡張子の切り出しと複合拡張子
* **推奨:** `p.withoutExtension(path)` と `p.extension(path, 2)`
* **避ける:** `path.lastIndexOf('.')` と手動の `substring` による切り出し
* **理由:** 手動計算は隠しドットファイル（`.gitignore`）や複合拡張子（`.js.map`、`.tar.gz`）で正しく動作しません。

### POSIX パスと URL パスの変換
* **推奨:** `p.posix.joinAll(p.split(path))` または `p.url.joinAll(p.split(path))`
* **避ける:** `path.replaceAll(r'\', '/')`
* **理由:** その場しのぎの区切り文字置換はルートドライブで失敗し、OS のパスコンテキストと POSIX／URL の変換先を混同します。

### URI 変換
* **推奨:** `p.toUri(path)` と `p.fromUri(uri)`
* **避ける:** `Uri.parse(path)` と `uri.path`
* **理由:** URI の直接解析は Windows のドライブ文字（`C:`）で失敗し、パーセントエンコーディング（空白の `%20` など）がそのまま残ります。

### ディレクトリのベース名ヘルパー
* **推奨:**
  `String canonicalDirName(Directory d) => p.basename(p.normalize(d.absolute.path));`
* **避ける:** ファイルごとに `p.basename(p.normalize(dir.absolute.path))` をインラインで繰り返すこと。
* **理由:** ディレクトリ名の正準化ロジックを一元化し、定型コードを減らせます。

---

## 3. ネイティブパスから POSIX、Git、URL コンテキストへの変換

OS ネイティブパスを POSIX パス（Git、YAML、アーカイブマニフェスト用）や URL セグメントに変換するために、`.replaceAll('\\', '/')` や `.replaceAll(r'\', '/')` を呼び出すのは避けてください。

**規則:** ネイティブの相対パスを `p.split(...)` で分割し、**Dart 3 のリストパターンマッチング**でセグメントを調べて、`p.posix.joinAll(...)` または `p.url.joinAll(...)` で結合します。先頭のルートセグメント（POSIX では `'/'`、Windows では `r'C:\'`）が相対プレフィックスのパターンに干渉しないよう、必ず先に `p.relative(filePath, from: root)` を呼び出します。

```dart
import 'package:path/path.dart' as p;

String computeWebAssetKey(String filePath, String projectRoot) {
  final relative = p.relative(filePath, from: projectRoot);
  final segments = p.split(relative);
  return switch (segments) {
    ['assets', ...] => p.posix.joinAll(segments),
    _ => p.posix.joinAll(['assets', ...segments]),
  };
}
```

### Git のパスとリポジトリメタデータ
* Git リポジトリのツリーオブジェクト、`.gitignore` のパターン規則、`.gitattributes`、Git 管理対象のシンボリックリンクでは、Windows 上でも POSIX のスラッシュ（`/`）のみを使用します。
* `.gitignore` や Git コマンドに Windows ネイティブのバックスラッシュ（`\`）を入れると、Git はこれをディレクトリ区切り文字ではなくエスケープ文字として扱い、パターン照合が気付かないうちに壊れます。
* ネイティブファイルパスから `.gitignore` のエントリ、リポジトリマニフェスト、またはシンボリックリンクの参照先をプログラムで生成する場合は、`p.posix.joinAll(p.split(relativePath))` または `p.posix.join(...)` でネイティブの相対パスを変換します。

---

## 4. モック可能なファイルシステム（`package:file` とグローバル `p.*`）

`package:file` を使用するコードベース（例: CLI アプリケーション、または `MemoryFileSystem` でテストするサービス）では、`File` や `Directory` のパスにトップレベルの `p.*` 関数を呼び出さないでください。

* トップレベルの `p.*` 関数は、テストを実行する**ホスト OS** に結び付いています。
* Linux または macOS のランナーで単体テストが `MemoryFileSystem(style: FileSystemStyle.windows)` を作成すると、グローバルな `p.split(file.path)` は `\` ではなく `/` で分割してしまい、テストが壊れます。

**規則:** 必ず `FileSystem` に関連付けられた `Context`（`file.fileSystem.path`）を使用します。

```dart
import 'package:file/file.dart';

List<String> listSubdirectoryNames(Directory dir) {
  final pathContext = dir.fileSystem.path;
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => pathContext.basename(d.path))
      .toList();
}
```

---

## 5. 拡張子、複合拡張子、ベース名の抽出

ファイル拡張子の抽出やコンテンツハッシュの挿入に、手動の `.lastIndexOf('.')` や `.substring()` による計算を使わないでください。`p.extension` はオプションの `level` パラメーターで複数階層の拡張子を標準でサポートします。

* **複数のドットを含むベース名に関する注意:** `p.extension('main.dart.wasm', 2)` は、最後の 2 つのドット区切りセグメントをそのまま取得するため、`'.dart.wasm'` を返します。複数ドットを含むベース名を持つ可能性のあるファイル（例: `main.dart.wasm` と `main.dart.js.map`）のハッシュ化や拡張子除去を行う場合は、単一階層の `p.extension(filename)` にフォールバックする前に、`p.extension(filename, 2)` が既知の複合拡張子（または `.endsWith('.map')`）に一致するか確認します。

```dart
import 'package:path/path.dart' as p;

String insertContentHash(String filename, String hash) {
  final compoundExt = p.extension(filename, 2);
  // 2 階層の拡張子は、実際に複合接尾辞の場合（例: '.js.map'）にのみ使用する
  final ext = compoundExt.endsWith('.map')
      ? compoundExt
      : p.extension(filename);
  final stem = filename.substring(0, filename.length - ext.length);
  return '$stem.$hash$ext';
}
```

---

## 6. ワークフローと監査チェックリスト

### パスのリファクタリングチェックリスト
- [ ] 文字列補間（`'$dir/$file'`）を `p.join(dir, file)` に置き換える。
- [ ] `.contains('dir/')` と `.startsWith('dir/')` を、`p.split(path)` のリストパターン照合（`case ['dir', ...final rest]`）または `p.isWithin(parent, child)` に置き換える。
- [ ] `.replaceAll(r'\', '/')` を `p.posix.joinAll(p.split(path))`（または `p.url.joinAll`）に置き換える。
- [ ] ファイルパスに対する `.endsWith('.ext')` を `p.extension(path) == '.ext'` に置き換える。
- [ ] 手動のドット位置による切り出しを `p.withoutExtension(path)` と `p.extension(path, [level])` に置き換える。
- [ ] `package:file` を使うコードが、グローバルな `p.*` ではなく `fileSystem.path` にアクセスしていることを確認する。
- [ ] Git のパス、`.gitignore` のエントリ、シンボリックリンクの参照先に `p.posix` のスラッシュが使われていることを確認する。

---

## 参考資料と例

* **クロスプラットフォームパスと POSIX 変換の例:** [examples/cross_platform_paths.dart](examples/cross_platform_paths.dart)
* **モック可能な FileSystem パスコンテキストの例:** [examples/file_system_context.dart](examples/file_system_context.dart)
