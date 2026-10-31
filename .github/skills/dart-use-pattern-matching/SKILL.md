---
name: dart-use-pattern-matching
description: >-
  Dart 3 のパターンマッチング、switch 式、分割代入を慣用的に適用し、データスキーマの検証、代数的データ型の処理、制御フローの分解を行います。複雑な if-else チェーンのリファクタリング、多態的な JSON や API レスポンスの解析、List、URI／パスセグメント、String.split() のトークン、Record、Map の分割代入、sealed クラスの網羅性の保証に使用します。単純な真偽値条件、単一変数の型昇格（`is` を使用）、基本的なコレクションのフィルタリングには使用しないでください。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 13 Oct 2026 19:45:00 GMT
---
# Dart のパターンの実装

## 目次
- [パターン選択の方針](#pattern-selection-strategy)
- [Switch 文と式](#switch-statements-vs-expressions)
- [基本的なパターンの実装](#core-pattern-implementations)
- [実用性のバランスとアンチパターン](#pragmatic-balance--anti-patterns)
- [ワークフロー](#workflows)
- [例](#examples)

## パターン選択の方針

データ構造と求める結果に応じて、適切な種類のパターンを適用します。次の条件別ガイドラインに従ってください。

*   **デシリアライズ済みデータ（例: JSON）を検証・抽出する場合:** Map、List、Object パターンを使って、スキーマ構造の検証とプロパティの分割代入を一度に行います。
*   **URL／パスセグメント（`uri.pathSegments`、`p.split(path)`）や `String.split()` のトークンを調べる場合:** 手動の `.length` チェック、`.first`、`.skip(1)`、`length - N` によるインデックス計算の代わりに、残余要素を含む List パターン（`['api', 'comments', ...]`、`['assets', ...final rest]`、`[..., final parent, _]`）を使います。
*   **多態的なペイロードやレスポンスを処理する場合:** Map の判別キーに対する `switch` 式を使い、`sealed` クラス階層にデシリアライズします。
*   **複数の戻り値を処理する場合:** Record パターンでフィールドをローカル変数に直接分割代入します。
*   **オブジェクトまたは `MapEntry` から複数のフィールドを取り出す場合:** nullable プロパティを型昇格させる場合、または複数の文で使う 3 個以上のフィールドを取り出す場合は、単一呼び出しにそのまま渡す用途ではなく、Object パターン（`final Spec(:field1, :field2!) = spec;`、`for (final MapEntry(:key, :value) in map.entries)`）を使います。
*   **型ごとの動作（代数的データ型）を実行する場合:** Object パターンを `sealed` クラスと組み合わせ、網羅性を保証します。
*   **数値範囲や条件を照合する場合:** switch のアーム内で Relational（`>=`、`<=`）パターンと Logical-and（`&&`）パターンを使います。
*   **複数のケースでロジックを共有する場合:** Logical-or（`||`）パターンを使って、1 つのケース本体またはガード節を共有します。
*   **特定の値を無視する場合:** Wildcard パターン（`_`）またはコレクション内で一致させない Rest 要素（`...`）を使います。

## Switch 文と式

実行コンテキストに応じて、適切な switch 構文を選択します。

*   **値を生成する場合:** **switch 式**を使用します。
    *   構文: `switch (value) { pattern => expression, }`
    *   規則: 各ケースは単一の式でなければなりません。暗黙のフォールスルーはありません。すべてのケースを網羅する必要があります。
*   **文や副作用を実行する場合:** **switch 文**を使用します。
    *   構文: `switch (value) { case pattern: statements; }`
    *   規則: 空のケースは次のケースへフォールスルーします。空でないケースは暗黙に break するため、`break` キーワードは不要です。

## 基本的なパターンの実装

次の構文と規則に従ってパターンを実装します。

* **Logical-or（`||`）:** `pattern1 || pattern2`。両方の分岐で、まったく同じ変数セットを定義する必要があります。
* **Logical-and（`&&`）:** `pattern1 && pattern2`。分岐間で変数が重複してはなりません。
* **Relational:** `==`、`!=`、`<`、`>`、`<=`、`>=` の後に定数式を指定します。
* **Cast（`as`）:** `pattern as Type`。値が型に一致しない場合はスローします。分割代入時に型を強制的にアサートするために使います。
* **Null-check（`?`）:** `pattern?`。値が null の場合は一致しません。変数を null 非許容の基底型に束縛します。
* **Null-assert（`!`）:** `pattern!`。値が null の場合はスローします。
* **Variable:** `var name` または `Type name`。一致した値を新しいローカル変数に束縛します。
* **Wildcard（`_`）:** 任意の値に一致し、その値を破棄します。
* **List:** `[pattern1, pattern2]`。Rest 要素（`...` または `...var rest`）を使わない限り、要素数が完全に一致するリストに一致します。
* **Map:** `{"key": pattern}`。指定されたキーを含むマップに一致します。一致しないキーは無視します。
* **Record:** `(pattern1, named: pattern2)`。形状が完全に一致するレコードに一致します。`:var name` を使うと getter 名を推論できます。
* **Object:** `ClassName(field: pattern)`。`ClassName` のインスタンスに一致します。`:var field` を使うと getter 名を推論できます。

## 実用性のバランスとアンチパターン

パターンマッチングと switch 式は、構文上の負担を増やすのではなく、コードを簡潔にするために使います。次の境界に注意してください。

### 1. 型昇格可能な単一変数では `if-case` より `is` による型昇格を優先する
単一の変数をチェックまたは型昇格させる場合は、別名のシャドウ変数を導入する `if-case` パターンではなく、標準の `is` チェックを使います。

*   **推奨:**
    ```dart
    // ✅ 余分な変数を作らずに `key` をその場で型昇格させる
    for (final MapEntry(:key, :value) in map.entries) {
      if (key is String && value != null) {
        process(key, value);
      }
    }
    ```
*   **Avoid:**
    ```dart
    // ❌ アンチパターン: 不要な別名変数 `k` を導入する
    for (final MapEntry(:key, :value) in map.entries) {
      if (key case final String k when value != null) {
        process(k, value);
      }
    }
    ```

### 2. Switch アームで nullable 型をまとめる
`null` と型 `T` の両方が有効で同じように処理される値をマッピングまたは返す場合は、冗長な `null` アームを作らず、nullable 型 `T?` を直接照合します。

*   **Prefer:**
    ```dart
    // ✅ 簡潔な nullable パターンマッチ
    switch (value) {
      final String? s => s,
      _ => throw FormatException('無効な値です: $value'),
    }
    ```
*   **避ける:**
    ```dart
    // ❌ 冗長な null 専用アーム
    switch (value) {
      final String s => s,
      null => null,
      _ => throw FormatException('無効な値です: $value'),
    }
    ```

### 3. 速やかに失敗する検証を維持する（データを黙って破棄しない）
不正なデータでエラーまたは診断警告を発生させる必要がある場合、ループやデシリアライズで要素をフィルタリングするために `if-case` を使わないでください。

*   **推奨:**
    ```dart
    // ✅ 診断エラーを明示して速やかに失敗させる
    for (final raw in rawTasks) {
      if (raw is! Map<String, dynamic>) {
        throw FormatException('Map の要素を想定していましたが、${raw.runtimeType} を受け取りました: $raw');
      }
      _applyTask(raw);
    }
    ```
*   **避ける:**
    ```dart
    // ❌ 不正な要素を黙って無視する
    for (final raw in rawTasks) {
      if (raw case final Map<String, dynamic> taskMap) {
        _applyTask(taskMap);
      }
    }
    ```

### 4. 単一ケースや真偽値だけの switch を避ける
* ケースが 1 つだけで `default: break;` を持つ switch 文ではなく、`if (x is T)` を使います。
* `switch (condition) { true => a, false => b }` ではなく、標準の条件付き三項演算子（`condition ? a : b`）を使います。

### 5. 単一プロパティや値の受け渡しではなく、複数フィールドの取り出しに Object 分割代入を使う
複数の文で使う 3 個以上のフィールドの抽出、`map.entries` のループでの `MapEntry(:key, :value)` の反復、1 回しか使わない中間変数の削除、nullable フィールドのローカル変数への型昇格（`:field!` または `!= null` を伴う `:field`）には、Object または Record の分割代入を使います。次の場合は標準のプロパティ／要素アクセス（`config.field`）を維持します。
*   単一プロパティの読み取り（`user.name`、または `ProfileNode(callFrame: ...)` と入れ子にせず `final CpuCallFrame(:url, :line) = node.callFrame;` とする場合）。
*   短い getter／メソッドで 1～2 個のフィールドだけを取り出す場合、または 1 つのコンストラクター／関数呼び出しに直接渡すだけの場合。
*   明示的なローカル型注釈（`specify_nonobvious_local_variable_types`）のために、フィールドの再利用がわずか（1～2 回）なのに新しいライブラリをインポートする必要がある場合。
*   getter 名を変更した長いクラス名のために、2 フィールドの分割代入が 3 行以上に折り返される場合。
*   対象の変数が外側スコープの変数に代入される場合（例: `finally` の前に `db = res.$1;` とする場合、`final (db, ...)` は外側の `db` をシャドウする）、または `final` と変更可能な `var` のローカル変数が混在する場合。
*   長さが 1 かもしれないリストで `.first` と `.last` を読む場合（`[first, ..., last]` には `length >= 2` が必要です。複数分岐の `if-case` に置き換えないでください）。

*   **推奨:**
    ```dart
    // ✅ 1 つの宣言で複数のフィールドを取り出し、非 null をアサートする
    final RunSpec(:target, :device!, :verbose) = spec;
    ```
*   **避ける:**
    ```dart
    // ❌ プロパティを複数行にわたって繰り返し抽出する
    final target = spec.target;
    final device = spec.device!;
    final verbose = spec.verbose;
    ```

### 6. 単独のスカラー比較に `if-case` を使わない
単独の条件では `if (code case >= 200 && < 300)` ではなく、標準の論理演算子（`if (code >= 200 && code < 300)`）を使います。Relational パターンは複数アームの switch 表に限定します。

## ワークフロー

### 作業の進捗: パターンマッチングの実装
複雑なパターンマッチングロジックを実装する際は、このチェックリストをコピーして進捗を管理します。

- [ ] 評価対象のデータ構造（JSON、List／セグメント、Record、Class、Enum）を特定する。
- [ ] 適切な switch 構文（値には式、副作用には文）を選択する。
- [ ] 必要なパターン（Object、Map、List、Record）を定義する。
- [ ] Variable パターン（`var x`、`:var y`、`...final rest`）を使って必要なデータを抽出する。
- [ ] パターンで表現できないロジックには Guard 節（`when condition`）を適用する。
- [ ] Wildcard（`_`）または `default` 節（sealed クラスを使わない場合）で一致しないケースを処理する。
- [ ] 網羅性とデッドコードについて静的解析を実行する（`dart analyze`）。
- [ ] Map／JSON のパターンでキーが省略された場合（`containsKey` の動作）と、値が明示的に `null` の場合の実行時動作を確認する。

### フィードバックループ 1: 網羅性チェック（静的検証）
`sealed` クラスまたは enum を switch で処理するときは、すべてのサブタイプがコンパイル時に処理されることを確認します。

1. **Analyzer を実行:** `dart analyze` を実行します。
2. **エラーを確認:** 「The type 'X' is not exhaustively matched by the switch cases」や到達不能なパターンアームの警告を探します。
3. **修正:** 未処理のサブタイプに対する不足している Object パターンを追加します。既定のフォールバックまたはエラーを許容できる場合は、明示的な Wildcard（`_`）アームを追加します。

### フィードバックループ 2: Map と JSON パターンの実行時検証
`dart analyze` では動的な `Map<String, dynamic>` のキーを静的に検証できないため、実行時のパターンの動作を明示的に確認します。

1. **キーの省略と明示的な `null` の違い:** Map パターン `{'key': String? val}` は `map.containsKey('key')` を確認します。JSON ペイロードから `'key'` が省略されている場合、`String?` が nullable であっても実行時にパターンは一致しません。オプションのキーは検証済みマップから直接取り出します（`map['key'] as String?`）。
2. **速やかに失敗するフォールバック:** 一致しないマップ構造や不正なマップ構造が、`if-case` チェックで黙って失敗するのではなく、明示的な `_ => throw FormatException(...)` アームに到達することを確認します。

## 例

### 多態的な JSON のデシリアライズ（判別共用体）
Map パターンと switch 式を使ってタグ付き JSON ペイロードを検証し、`sealed` クラス階層を構築します。タグ付き `ApiResponse` を解析して `SuccessResponse` と `ErrorResponse` に変換する実行可能な実装については、[examples/json_patterns.dart](examples/json_patterns.dart) を参照してください。

### 入れ子の JSON 検証とオプションフィールド
入れ子の Map および List パターンを使って、必須スキーマ構造の検証とコレクションの抽出を一度に行います。`processUserPayload` の実行可能な実装については、[examples/json_patterns.dart](examples/json_patterns.dart) を参照してください。

Map パターンはキーの存在（`containsKey`）を確認します。オプションの JSON キーがペイロードから完全に省略される可能性がある場合（`'key': null` と明示的に渡される場合とは異なります）、必須キーはパターンで分割代入し、オプションフィールドは一致したサブマップから直接取り出します。

### List とパスセグメントの分割代入
リストの Rest 要素（`...final rest`）と `if-case` を使うと、2 アームの `_ => null` switch や手動の `.first`／`.skip(1)` によるインデックス操作を使わずに、プレフィックスを検証して残りの要素を取り出せます。

```dart
String? resolveAllowedAssetSubpath(List<String> segments) {
  if (segments case ['assets', ...final rest]
      when rest.isNotEmpty && !rest.contains('..')) {
    return rest.join('/');
  }
  return null;
}
```

### 代数的データ型（Sealed クラス）
Object パターンと switch 式を使って、型の一群を網羅的に処理します。

```dart
sealed class Shape {}

class Square implements Shape {
  final double length;
  Square(this.length);
}

class Circle implements Shape {
  final double radius;
  Circle(this.radius);
}

// `sealed` 修飾子により、switch 式の網羅性が保証される。
double calculateArea(Shape shape) => switch (shape) {
  Square(length: var l) => l * l,
  Circle(:var radius)   => math.pi * radius * radius,
};
```

### 変数の入れ替えと分割代入
変数代入パターンを使うと、一時変数を使わずに値を入れ替えたり、レコードフィールドを取り出したりできます。

```dart
var (a, b) = ('左', '右');
(b, a) = (a, b); // Swap values

// 関数の戻り値を分割代入する
var (name, age) = getUserInfo();
```

### Guard 節と Logical-or
パターンが一致した後に任意の条件を評価するには `when` を使います。

```dart
switch (shape) {
  case Square(length: var s) || Circle(radius: var s) when s > 0:
    print('寸法が $s の正の有効な形状');
  case Square() || Circle():
    print('寸法がゼロまたは負の形状');
}
```
