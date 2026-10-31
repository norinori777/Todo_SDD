---
name: dart-use-doc-examples
description: "Dartdoc の {@example} ディレクティブを使って外部コード例を埋め込み、#hide、#region、#endregion タグで対象ファイルを絞り込む方法。"
---

# Dartdoc でのコード例の使用

## 目次
*   [1. `{@example}` ディレクティブ](#1-the-example-directive)
*   [2. リージョンの使用](#2-using-regions)
*   [3. セットアップコードを隠す](#3-hiding-setup-code)
*   [4. マーカーによるフィルタリング規則](#4-marker-filtering-rules)
*   [5. 配置とパス解決](#5-placement-and-path-resolution)
*   [6. 検証](#6-verification)

複数行のコード例を含むドキュメントを書く場合は、通常、例を独立した `.dart` ファイルに切り出し、`///` コメント内に直接記述するのではなく、`{@example}` ディレクティブを使って埋め込みます。これにより、例を解析、lint、および実行できるようになります。

## 1. `{@example}` ディレクティブ
`{@example}` ディレクティブは外部ファイルを解析し、生成されるドキュメント内の Markdown フェンス付きコードブロックとして展開します。

**構文:** `{@example <path>[#<region>] [lang=LANGUAGE] [indent=keep|strip]}`

*   **`<path>`**: ファイルへのパス。先頭が `/` の場合はパッケージルートを基準に解決します。それ以外は現在のファイルからの相対パスです。
*   **`lang`**: Markdown フェンスに指定する言語。ファイル拡張子（例: `dart`）から自動判定されますが、明示的に指定することもできます（例: `lang=text`）。
*   **`indent`**: `strip`（既定値）は、コードブロック内で共通する先頭インデントを積極的に削除します。

*悪い例（Markdown への直接記述）:*
```dart
/// Makes a client service request to the backend.
///
/// ```dart
/// final client = Client();
/// client.send();
/// ```
```

*良い例（外部ファイルの埋め込み）:*
```dart
/// Makes a client service request to the backend.
///
/// {@example /example/client_request.dart}
```

## 2. リージョンの使用
外部のコード例ファイルには、ドキュメントに表示したくない import、セットアップコード、`void main()` のラッパーなどが含まれていることがよくあります。`{@example}` ディレクティブのパス末尾に `#<region>` を付け、対象ファイル内の該当コードを `#region` と `#endregion` コメントで囲むと、特定のコードブロックだけを抽出できます。

**Dart コード（例: `/example/client.dart`）:**
```dart
import 'package:http/http.dart';

void main() {
  // #region request_snippet
  final client = Client();
  client.send();
  // #endregion request_snippet
}
```

**Dartdoc での使用例:**
```dart
/// Connects the client to the server and sends a request.
///
/// {@example /example/client.dart#request_snippet}
```

## 3. セットアップコードを隠す
抽出するリージョン内に、コンパイラーやアナライザーを通すために必要でも、ドキュメントの読者には不要（または読者の注意をそらす）コード行がある場合、その行末に `#hide` を付けます。

**Dart コード:**
```dart
final mockServer = startServer(); // #hide
final data = await fetch(mockServer.url);
```
生成されたドキュメントには `final data = await fetch(mockServer.url);` だけが表示されます。`#hide` が付いた行は完全に除外されます。

## 4. マーカーによるフィルタリング規則
`#hide`、`#region`、`#endregion` マーカーを使う場合は、次の2つの技術的な制約に従う必要があります。

*   **リージョンの指定が必要:** マーカーが処理・除去されるのは、特定のリージョンを接尾辞で指定した場合（例: `{@example file.dart#region_name}`）だけです。リージョンを指定せずにファイル全体を埋め込むと、`// #hide` のようなマーカー文字列も含め、ソースの内容がそのまま埋め込まれます。
*   **形式に依存しない:** マーカーシステムは形式に完全に依存しません。Dartdoc はマーカー文字列を含む行を正規表現で除去するだけなので、Dart 以外のファイル（例: YAML コメント内の `# #region`、HTML コメント内の `<!-- #region -->`）でも同様に機能します。

## 5. 配置とパス解決
`{@example}` ディレクティブはブロックレベルのディレクティブです。`///` を付けて単独の行に記述する必要があります。内部の `<path>` パーサーは URI 参照の厳密な規則に従います。

*   **パッケージルートからのパス (`/`)**: 先頭がスラッシュのパスは、Dart パッケージのルートに直接解決されます。配置先ファイルが深い階層にある場合に使用します。
    *   *例:* `{@example /test/data/sample.txt}` は `<package_root>/test/data/sample.txt` に対応します。
*   **相対パス**: 先頭にスラッシュがないパスは、ドキュメントコメントを含むファイルのディレクトリを基準に解決されます。
    *   *例:* `{@example ../utils/demo.dart}`
*   **境界の適用:** `..` セグメントで上位ディレクトリに移動しても問題ありませんが、dartdoc はパッケージルートでディレクトリ走査を停止するため、パッケージの外に出ることはありません。
*   **ネットワーク URL は不可:** `https://` などで始まる絶対 URI はサポートされません。コード例ファイルはローカルファイルシステム内に存在する必要があります。
*   **区切り文字とエンコード:** dartdoc はパスを URI として解決するため、フォルダー区切りには（Windows でも）常にスラッシュ (`/`) を使用してください。URI 参照規則に従い、空白を表す `%20` などの URI エンコード文字も使用できます。

## 6. 検証
コード例を埋め込んだ後、次を実行します。
1.  コード例ファイルに対して `dart analyze` を実行し、非表示のセットアップコードも含めてコンパイルできることを確認します。
2.  （任意）`dart doc` を実行し、「Failed to read file」や「missing region」警告を出さずに dartdoc がディレクティブを解析できることを確認します。
