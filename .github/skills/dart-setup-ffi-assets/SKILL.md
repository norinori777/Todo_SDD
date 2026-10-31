---
name: dart-setup-ffi-assets
description: "Dart の Native Assets フックシステム（package:hooks と package:native_toolchain_c を利用する hook/build.dart および hook/link.dart）を使って、C/C++ ソースコードを動的または静的ライブラリ（Code Assets）としてコンパイル、パッケージ化する方法を案内します。「native assets のセットアップ」「C/C++ ソースコードのコンパイル」「動的ライブラリのバンドル」「ネイティブ C コードのビルド」「native assets のリンク」「build.dart または link.dart フックの実装」「Dart/Flutter への C/C++ 相互運用の統合」を依頼された場合に使用します。手動でのツールチェーン制御を避ける方法、ハッシュ検証付きの安全なバイナリダウンロードの設定、package:record_use のマッピングによる高度なリンカーのツリーシェイキングも案内します。"
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 29 May 2026 09:10:00 GMT
---
# Native Assets フックで C コードを Code Assets にコンパイルする

ビルドフックとリンクフックを使って、Dart の包括的な **Native Assets** 機能のもとで、ネイティブ C/C++ ソースコードを **Code Assets** としてコンパイルおよびパッケージ化する処理を統合・自動化します。

## 目次
- [概要](#introduction)
- [制約](#constraints)
- [ネイティブ相互運用パッケージ](#native-interop-packages)
- [手順](#step-by-step-workflow)
- [統合方式の選択](#choosing-an-integration-approach)
- [方式1: リンカーのツリーシェイキングを用いたローカルコンパイル（推奨）](#method-1-local-compilation-with-linker-tree-shaking-recommended)
  - [ホストコンパイラツールチェーンの前提条件](#prerequisite-host-compiler-toolchains)
  - [C ソースとバインディングの設定](#c-source-and-bindings-setup)
  - [C ライブラリのビルド仕様を定義する](#defining-the-c-library-build-spec)
  - [hook/build.dart を実装する](#implementing-hookbuilddart)
  - [hook/link.dart を実装する](#implementing-hooklinkdart)
- [方式2: プリコンパイル済み動的ライブラリのダウンロード](#method-2-downloading-precompiled-dynamic-libraries)
  - [プリコンパイル済みバイナリをダウンロードする理由](#why-download-precompiled-binaries)
  - [プリコンパイル済みバイナリのダウンロードを実装する](#implementing-precompiled-dynamic-downloads)
- [検証チェックリスト](#verification-checklist)
  - [1. ローカル実行環境](#1-local-execution-sandbox)
  - [2. ターゲット出力の検証](#2-verify-target-outputs)
  - [3. ツリーシェイキングによる除去の検証](#3-verify-tree-shaking-stripping)
  - [4. オフライン対応の検証（ユーザー定義）](#4-verify-offline-compliance-user-defines)

---

## 概要

Dart の **Native Assets** 機能では、パッケージはネイティブコード（C/C++ ライブラリなど）を **Code Assets** としてパッケージ化し、標準的な開発サイクル（例: `dart run`、`dart test`、`dart build`、`flutter run`）で自動的にバンドルできます。**Code Assets** のパッケージ化は、パッケージの `hook/` フォルダーに配置する次の2つのプログラム可能なフックスクリプトによって制御されます。

1.  `hook/build.dart`: ローカルの C ソースをマシンコードにコンパイルするか、特定のホスト/ターゲットアーキテクチャ向けのプリビルド済みネイティブバイナリを Code Assets としてバンドルします。
2.  `hook/link.dart`: ビルド済み Code Assets をリンクし、高度なツリーシェイキング最適化を適用して未使用のネイティブシンボルを除去し、実行時バイナリのサイズを縮小します。

---

## 制約

> [!IMPORTANT]
> すべてのファイル解決処理をプラットフォーム非依存にしてください。絶対ターゲットパス、シェルスクリプト、システムコマンド変数をハードコードしてはいけません。スクリプトの完全な移植性を確保するため、常に `Platform.script.resolve()` または `Uri` ベースの解決を使用してください。

*   **フックの配置場所:** コンパイルおよびパッケージ化フックは、パッケージルートの `hook/` ディレクトリ内に配置する必要があります。
    *   `hook/build.dart`（ビルド実行フェーズ）
    *   `hook/link.dart`（任意のパッケージ化/リンク/ツリーシェイキングフェーズ）
*   **コンパイルツールチェーンの標準:** コンパイルツールチェーンを実行するには、`package:native_toolchain_c` のプログラム API（例: `CBuilder`、`CLibrary`）を使用します。シェルコマンドで `gcc`、`clang`、`msvc` を直接呼び出してはいけません。
*   **ライセンスヘッダー:** 手書きまたは生成されたすべてのソースファイル（バインディング、ヘルパー、フックを含む）に、対象パッケージの著作権およびライセンスヘッダーを必ず含めます。
*   **ツリーシェイキングのマッピング:** コンパイラのツリーシェイキングを利用する場合は、FFIgen が生成した record use マッピングを使って、対象の Dart メソッド名（例: `Method.name`）をネイティブ C シンボル名に対応付ける必要があります。マッピングファイルは `lib/src/third_party/` に置き、拡張子を必ず `.g.dart` にします（例: `sqlite3.record_use_mapping.g.dart`）。
*   **プリコンパイル済みライブラリの完全性保護:** 動的ダウンロード方式を採用する場合:
    *   **暗号学的検証:** ダウンロードしたプリビルド済みバイナリは、あらかじめ設定した MD5 または SHA-256 ハッシュの検索テーブルと照合し、バイナリの完全性を保証して改ざんを防ぐ必要があります。
    *   **適切なフォールバック:** `local_build` などのフラグによるローカルコンパイルをフォールバックとして提供し、オフラインの開発者にも対応します。

---

## ネイティブ相互運用パッケージ

**Code Assets** 用のプログラム可能なビルドおよびリンクフックでは、次の3つの専用ネイティブ相互運用パッケージを利用します。

| 依存関係 | 用途 | 主な API 抽象 |
| :--- | :--- | :--- |
| **`package:hooks`** | 実行範囲を定義する主要なオーケストレーター。 | `build(args, callback)`, `link(args, callback)` |
| **`package:native_toolchain_c`** | ローカルコンパイラ（MSVC、Xcode/Clang、GCC）を検出し、ビルドツールチェーンを実行する。 | `CLibrary`, `CBuilder`, `LinkerOptions.treeshake` |
| **`package:code_assets`** | 動的ローダーに渡されるコードメタデータレコードをモデル化する。 | `CodeAsset`, `DynamicLoadingBundled` |

---

## 手順

### 手順1: 依存関係を追加する
Code Assets のフックおよびツールチェーンの依存関係をパッケージに追加します。これらの依存関係は **pub.dev** から直接取得する必要があります。

CLI を使って自動的に追加できます。
```bash
dart pub add code_assets hooks native_toolchain_c record_use dev:ffigen
```

または、対象パッケージの `pubspec.yaml` に手動で宣言します。
```yaml
dependencies:
  code_assets: ^1.0.0
  hooks: ^0.1.0
  native_toolchain_c: ^0.1.0
  record_use: ^0.6.0

dev_dependencies:
  ffigen: ^20.1.1
```

### 手順2: C の仕様を定義する
対象の C ライブラリのコンパイルメタデータを `lib/src/c_library.dart` 内に定義します。これにより、ビルドフックとリンクフックの両方で、アセット、名前、ソースの信頼できる唯一の情報源を共有できます。

### 手順3: ビルドフックとリンクフックを実装する
コンパイルを調整するスクリプトを `hook/build.dart` に、デッドコード除去のロジックを `hook/link.dart` に記述します。

### 手順4: フックのサイクルを実行する
標準のテストスイートを実行すると、ビルドフックとリンクフックのライフサイクルがバックグラウンドで動的に開始されます。
```bash
dart test
```

---

## 統合方式の選択

Dart で C/C++ のネイティブアセットを統合および配布する方法は、主に2つあります。プロジェクトの要件に合う方式を選択してください。

| 項目 | 方式1: ローカルコンパイルとツリーシェイキング | 方式2: プリコンパイル済みバイナリのダウンロード |
| :--- | :--- | :--- |
| **主な用途** | C/C++ ソースコードがパッケージに直接含まれ、最大限のサイズ最適化が必要な場合。 | ローカルコンパイルが遅い/複雑な場合や、開発者側のホストツールチェーン要件をなくしたい場合。 |
| **ホストツールチェーンの要件** | プラットフォーム用 C コンパイラ（Xcode ツール、MSVC、GCC）の事前インストールが必要。 | 開発者/ユーザーのマシンでコンパイラのセットアップは不要。 |
| **バイナリの最適化** | 高度。未使用シンボルを完全にツリーシェイキングし、ライブラリサイズを縮小。 | 標準。通常どおりコンパイルされたバイナリをそのまま配布。 |
| **オフラインでのセットアップ** | 完全対応。完全にオフラインで動作。 | ライブラリのダウンロードにネットワークが必要だが、オフライン用フォールバックあり。 |

---

## 方式1: リンカーのツリーシェイキングを用いたローカルコンパイル（推奨）

この方式では、ビルドフックがローカルツールチェーン（GCC、Clang、MSVC）を呼び出してソースファイルを直接コンパイルします。その後、リンクフックがコンパイラオプションを使って出力シンボルをフィルタリングし、ユーザーコードから呼び出される対象メソッドだけを保持します。これは `pkgs/code_assets/example/sqlite` にある、標準的で堅牢な SQLite のパターンです。

### ホストコンパイラツールチェーンの前提条件

`package:native_toolchain_c` は実際の動的コンパイルをホスト OS の既定ツールチェーンに委譲するため、開発マシンには次のコンパイラパッケージのいずれかが事前にインストールされている**必要があります**。

*   **macOS**: Xcode Command Line Tools。次のコマンドでインストールします。
    ```bash
    xcode-select --install
    ```
*   **Linux**: GCC または Clang。次のコマンドでインストールします。
    ```bash
    sudo apt install build-essential
    ```
*   **Windows**: MSVC（Microsoft Visual C++）。**Visual Studio Installer** をインストールし、**C++ によるデスクトップ開発**ワークロードを選択します。

*注: ホストの PATH 上で互換性のあるツールチェーンが見つからない場合、ビルドフックスクリプトはコンパイル実行例外をスローします。ツールチェーンを確保できない場合は、コンパイラの制約を指定するか、方式2を採用してください。*

### C ソースとバインディングの設定

`third_party/sqlite/sqlite3.c` に単純な数学関数を定義する C ソースがあり、そのエントリーポイントのヘッダーが `third_party/sqlite/sqlite3.h` にあるとします。

```c
#ifndef SQLITE3_H_
#define SQLITE3_H_

const char *sqlite3_libversion(void);

#endif // SQLITE3_H_
```

プログラム可能な FFIgen スクリプト（`tool/ffigen.dart`）を使って `lib/src/third_party/sqlite3.g.dart` に FFI バインディングを作成します。これにより、使用状況の記録が可能になり、検索用メタデータマップが `lib/src/third_party/sqlite3.record_use_mapping.g.dart` に生成されます。

```dart
// 自動生成ファイル - 編集しないでください。
// ffigen によって生成。

const recordUseMapping = {
  'sqlite3_libversion': 'sqlite3_libversion',
};
```

### C ライブラリのビルド仕様を定義する

一元管理するライブラリ仕様を `lib/src/c_library.dart` に定義します。

```dart
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// sqlite ライブラリの C ビルド仕様。
final cLibrary = CLibrary(
  name: 'sqlite3',
  assetName: 'src/third_party/sqlite3.g.dart',
  sources: ['third_party/sqlite/sqlite3.c'],
);
```

### `hook/build.dart` を実装する

`CLibrary.build` を使って `hook/build.dart` を実装します。これにより、フックのターゲットディレクトリ内に動的ライブラリ（例: `.so`、`.dylib`、`.dll`）としてライブラリがビルドされます。

```dart
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:sqlite/src/c_library.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await cLibrary.build(
        input: input,
        output: output,
        defines: {
          if (input.config.code.targetOS == OS.windows)
            // Windows DLL で C 関数が明示的にエクスポートされるようにする
            'SQLITE_API': '__declspec(dllexport)',
        },
      );
    }
  });
}
```

### `hook/link.dart` を実装する

`hook/link.dart` にリンク最適化フェーズを実装します。コンパイラのツリーシェイキングオプション（`LinkerOptions.treeshake`）を利用し、シンボル使用記録に基づいて最小化とデッドコード除去を行ったバイナリをコンパイルします。

```dart
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';
import 'package:sqlite/src/c_library.dart';
import 'package:sqlite/src/third_party/sqlite3.record_use_mapping.g.dart';

void main(List<String> arguments) async {
  await link(arguments, (input, output) async {
    await cLibrary.link(
      input: input,
      output: output,
      linkerOptions: LinkerOptions.treeshake(
        // Dart Method 参照を C のシンボル名に対応付ける
        symbolsToKeep: input.recordedUses?.calls.keys.cast<Method>().map(
          (e) => recordUseMapping[e.name]!,
        ),
      ),
    );
  });
}
```

---

## 方式2: プリコンパイル済み動的ライブラリのダウンロード

別の方法として、中央のビルドマシンでバイナリを事前にコンパイルしてアーカイブし、ビルドフックの実行中に対象バイナリをダウンロードします。これは `download_asset` フックパッケージで示されている方式です。

### プリコンパイル済みバイナリをダウンロードする理由

*   **ホスト環境の制約:** 大規模な C/C++ ライブラリをローカルでコンパイルするには、エンド開発者のホストマシンにない可能性がある完全なコンパイラ環境（GCC、Xcode/SDK、Visual Studio）が必要です。
*   **コンパイル速度:** プリコンパイル済みバイナリのダウンロードは数ミリ秒で完了しますが、コンパイルには数分かかる場合があります。
*   **プラットフォーム間の橋渡し:** ホストアーキテクチャが限られている場合に、クロスコンパイルの制約を回避できます。

---

### プリコンパイル済みバイナリのダウンロードを実装する

ビルドフックでローカルコンパイルのフラグ（例: `local_build`）を検出するように設定します。指定がない場合、フックは `HttpClient` を使ってプラットフォーム固有のライブラリを取得し、MD5 ハッシュを計算して設定済みのハッシュ検索テーブルと照合し、ダウンロードの安全性を確認したうえで、バイナリファイルを `CodeAsset` として登録します。

#### 1. ターゲットのハッシュを定義する（`lib/src/hook_helpers/hashes.dart`）
パッケージのソース内で、プラットフォームごとのファイルに対する MD5 ハッシュ検証を定義します。

```dart
const assetHashes = {
  'libnative_add_macos_arm64.dylib': '4a88f50438a98402db2dbd47b59eb412',
  'libnative_add_linux_x64.so': '9f5e15043aa98402dcdbbd47b59ea520',
  'native_add_windows_x64.dll': 'a881e5043ba98402acdebd47b59fa321',
};
```

#### 2. フックのダウンロードヘルパー（`lib/src/hook_helpers/download.dart`）
ターゲットのファイル名を動的に照合するダウンロード処理と完全性検証を実装します。

```dart
import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';

const version = '1.0.0';

Uri downloadUri(String target) => Uri.parse(
  'https://github.com/my-org/my-native-repo/releases/download/$version/$target',
);

Future<File> downloadAsset(
  OS targetOS,
  Architecture targetArchitecture,
  Directory outputDir,
) async {
  final fileName = targetOS.dylibFileName('native_add_${targetOS.name}_${targetArchitecture.name}');
  final uri = downloadUri(fileName);
  
  final client = HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;
  final request = await client.getUrl(uri);
  final response = await request.close();
  
  if (response.statusCode != 200) {
    throw ArgumentError('ダウンロード先 $uri が失敗しました: コード ${response.statusCode}');
  }
  
  final targetFile = File.fromUri(outputDir.uri.resolve(fileName));
  await targetFile.create(recursive: true);
  await response.pipe(targetFile.openWrite());
  
  return targetFile;
}

Future<String> hashAsset(File file) async {
  return md5.convert(await file.readAsBytes()).toString();
}
```

#### 3. `hook/build.dart` を実装する

ローカルコンパイルへのフォールバックを含めた、最終的なダウンロード用ビルドフックを記述します。

```dart
import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:my_download_package/src/hook_helpers/hashes.dart';
import 'package:my_download_package/src/hook_helpers/download.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final localBuild = input.userDefines['local_build'] as bool? ?? false;

    if (localBuild) {
      final name = 'native_add_${input.config.code.targetOS.name}_${input.config.code.targetArchitecture.name}';
      final builder = CBuilder.library(
        name: name,
        assetName: 'native_add.dart',
        sources: ['src/native_add.c'],
      );
      await builder.run(input: input, output: output);
    } else {
      final targetOS = input.config.code.targetOS;
      final targetArch = input.config.code.targetArchitecture;
      final outputDir = Directory.fromUri(input.outputDirectory);

      final file = await downloadAsset(targetOS, targetArch, outputDir);

      final fileHash = await hashAsset(file);
      final expectedFileName = targetOS.dylibFileName('native_add_${targetOS.name}_${targetArch.name}');
      final expectedHash = assetHashes[expectedFileName];

      if (fileHash != expectedHash) {
        throw Exception(
          'セキュリティ検証エラー: ファイル $expectedFileName のハッシュ検証に失敗しました。'
          '検出したハッシュ: $fileHash、期待値: $expectedHash。'
        );
      }

      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: 'native_add.dart',
          linkMode: DynamicLoadingBundled(),
          file: file.uri,
        ),
      );
    }
  });
}
```

---

## 検証チェックリスト

ビルドフックまたはリンクフックの実装を完了とする前に、必ず次の項目を確認してください。

### 1. ローカル実行環境
ユニットテストを実行し、ネイティブアセットのコンパイル/リンク処理が、実行時例外やビルドツール例外を発生させずに完了することを確認します。
```bash
dart test
```

### 2. ターゲット出力の検証
パッケージのターゲットディレクトリに移動し、ホストシステム向けの動的バイナリアセットが作成されていることを確認します。
*   **macOS**: `.dart_tool/resources/` またはターゲットディレクトリに `.dylib` ファイルがあることを確認します。
*   **Linux**: `.dart_tool/resources/` またはターゲットディレクトリに `.so` ファイルがあることを確認します。
*   **Windows**: `.dart_tool/resources/` またはターゲットディレクトリに `.dll` ファイルがあることを確認します。

### 3. ツリーシェイキングによる除去の検証
リンクフックによって未使用のネイティブシンボルが実際に除去され、バイナリパッケージが縮小されていることを確認するには、次の検証を行います。

1. CLI/アプリの本番用バンドルをコンパイルします。
   ```bash
   dart build cli bin/main.dart
   ```
2. 動的ライブラリを含む、コンパイル済みビルドディレクトリに移動します。
3. エクスポートされた動的シンボルテーブルを照会します。
   *   **macOS**:
       ```bash
       nm -gU build/cli/lib/libsqlite3.dylib
       ```
   *   **Linux**:
       ```bash
       nm -D build/cli/lib/libsqlite3.so
       ```
   *   **Windows**（MSVC Developer Command Prompt を使用）:
       ```cmd
       dumpbin /EXPORTS build\cli\lib\sqlite3.dll
       ```
4. **対象のエクスポートを確認:** コマンド出力が、明示的に保持したエントリーポイント関数（例: `sqlite3_libversion`）**のみ**であり、参照されていない/除去されたシンボルが出力されないことを確認します。
5. **バンドルがない場合:** アプリケーションがネイティブライブラリのメソッドをインポートも呼び出しもしない場合:
   - リンクフックが「保持対象のシンボルがないため、リンクをスキップします。」とログ出力することを確認します。
   - 本番用バンドルにライブラリがビルド/配置されていない（`.dylib`/`.so`/`.dll` ファイルが生成されず、バンドルサイズが削減される）ことを確認します。

### 4. オフライン対応の検証（ユーザー定義）
オフライン対応が完全に有効で、ダウンロードのフォールバックが完全オフラインでも実行できることを確認します。

1. パッケージの `pubspec.yaml`（またはワークスペースルートの `pubspec.yaml`）で、パッケージ用の `local_build: true` define を設定します。
   ```yaml
   hooks:
     user_defines:
       <your_package_name>:
         local_build: true
   ```
2. マシンのネットワークアダプターを無効にするか、ネットワークから隔離されたシェルで実行します。
3. ユニットテストを開始します。
   ```bash
   dart test
   ```
4. テストスイートがホストコンパイラを使ってローカルソースファイルを正常にコンパイルし、コンパイルエラーがなく、ネットワーク経由のダウンロードを一切試みないことを確認します。
