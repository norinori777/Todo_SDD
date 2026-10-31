---
name: dart-fix-runtime-errors
description: get_runtime_errors と lsp を使って実行中のスタックトレースを取得し、失敗箇所を特定して修正を適用し、hot_reload で解消を確認します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:13:22 GMT
---
# Dart の静的解析エラーを解決する

## 目次
- [基本概念とガイドライン](#core-concepts--guidelines)
  - [型システムと健全性](#type-system--soundness)
  - [Null Safety](#null-safety)
  - [エラー処理](#error-handling)
- [ワークフロー](#workflows)
  - [ワークフロー: 静的解析エラーの解決](#workflow-static-analysis-resolution)
- [例](#examples)

## 基本概念とガイドライン

### 型システムと健全性
Dart の健全な型システムを徹底し、実行時に不正な状態になるのを防ぎます。

*   **メソッドのオーバーライド:** 戻り値の型（共変）とパラメーターの型（反変）の健全性を保ちます。`covariant` キーワードを明示しない限り、サブクラスでパラメーターの型を狭めてはいけません。
*   **ジェネリクスとコレクション:** ジェネリッククラスには明示的な型注釈を追加します（例: `List<T>`、`Map<K, V>`）。`List<dynamic>` を型付きリスト（例: `List<Cat>`）に代入してはいけません。
*   **ダウンキャスト:** `dynamic` からの暗黙のダウンキャストを避けます。必要な場合は明示的にキャストします（例: `as List<Cat>`）。ただし、`TypeError` を防ぐため、実行時の実際の型が一致することを確認してください。
*   **厳密なキャスト:** `analysis_options.yaml` の `analyzer: language:` の下で `strict-casts: true` を有効にし、明示的なキャストを必須にして、暗黙のダウンキャストエラーをコンパイル時に検出します。

### Null Safety
変数の初期化と nullable 性を適切に管理し、null safety に関する静的エラーをなくします。

*   **修飾子:** nullable 型には `?`、null アサーションには `!`、null を許容できない名前付きパラメーターには `required` を使用します。
*   **遅延初期化:** 使用前に初期化されることが保証された non-nullable 変数には `late` キーワードを使用します。特に、Dart の制御フロー解析で初期化を確実に証明できないトップレベル変数やインスタンス変数に適用します。
*   **ワイルドカード:** 未使用変数の警告を避けるため、値を束縛しないローカル変数やパラメーターには `_` ワイルドカード変数（Dart 3.7 以降）を使用します。

### エラー処理
回復可能な例外と回復不能なエラーを区別します。

*   **捕捉:** 回復可能な失敗については `Exception` のサブタイプを捕捉します。
*   **Error:** `Error` やそのサブタイプ（例: `TypeError`、`ArgumentError`）を明示的に捕捉してはいけません。Error は捕捉すべき例外ではなく、修正が必要なプログラミング上のバグを示します。`avoid_catching_errors` lint ルールを有効にして徹底します。
*   **再スロー:** 例外を元のスタックトレースを保ったまま伝播させるには、`catch` ブロック内で `rethrow` を使用します。

## ワークフロー

### ワークフロー: 静的解析エラーの解決

次の手順で Dart プロジェクトの静的解析エラーを特定、修正、検証します。進捗を追跡するにはチェックリストをコピーしてください。

**作業の進捗:**
- [ ] 1. 静的解析を実行する。
- [ ] 2. 自動修正を適用する。
- [ ] 3. 残りのエラーを手動で解決する。
- [ ] 4. 修正を検証する（フィードバックループ）。

**1. 静的解析を実行する**
対象のディレクトリまたはファイルにある静的エラーをすべて特定するため、Dart アナライザーを実行します。
```bash
dart analyze . --fatal-infos
```

**2. 自動修正を適用する**
`dart fix` ツールを使用して、一般的な lint および解析上の問題を自動的に解決します。
```bash
# 変更をプレビュー
dart fix --dry-run
# 変更を適用
dart fix --apply
```

**3. 残りのエラーを手動で解決する**
アナライザーの残りの出力を確認し、エラーの種類に応じて次の対応を行います。

*   **Null Safety の問題の場合（例: "Property cannot be accessed on a nullable receiver"）:**
    *   その変数が論理的に null になり得るか確認します。
    *   null になり得る場合は、null-aware 演算子 (`?.`) を使うか、フォールバック (`??`) を指定します。
    *   null にならず、別の箇所で初期化されることが保証されている場合は、宣言に `late` を付けます。
*   **型の不一致の場合（例: "The argument type 'List<dynamic>' can't be assigned..."）:**
    *   変数の初期化箇所を追跡します。
    *   インスタンス化時に明示的なジェネリック型注釈を追加します（例: `[]` ではなく `<int>[]`）。
*   **無効なオーバーライドの場合（例: "The parameter type doesn't match the overridden method"）:**
    *   パラメーターの型をスーパークラスと一致するように広げるか、
    *   ドメインロジック上、型を狭める必要がある場合は、パラメーターに `covariant` キーワードを追加します。

**4. 修正を検証する（フィードバックループ）**
検証ツールを実行し、エラーを確認して修正します。
```bash
dart analyze .
dart test
```
*   **`dart analyze` がエラーを報告した場合:** 手順3に戻ります。
*   **`dart test` が `TypeError` で失敗する場合:** 不正な明示的キャスト (`as T`) を追加したか、未初期化の `late` 変数にアクセスしています。実行時エラーの箇所を特定し、型階層または初期化順序を修正します。

## 例

### 例: dynamic リストの代入を修正する
**入力（静的解析に失敗）:**
```dart
void printInts(List<int> a) => print(a);

void main() {
  final list = []; // List<dynamic> と推論される
  list.add(1);
  list.add(2);
  printInts(list); // エラー: List<dynamic> は List<int> に代入できない
}
```

**出力（静的解析に合格）:**
```dart
void printInts(List<int> a) => print(a);

void main() {
  final list = <int>[]; // 型を明示
  list.add(1);
  list.add(2);
  printInts(list);
}
```

### 例: メソッドのオーバーライドを修正する（反変性）
**入力（静的解析に失敗）:**
```dart
class Animal {
  void chase(Animal a) {}
}

class Cat extends Animal {
  @override
  void chase(Mouse a) {} // エラー: パラメーターの型を狭めている
}
```

**出力（静的解析に合格）:**
```dart
class Animal {
  void chase(Animal a) {}
}

class Cat extends Animal {
  @override
  void chase(covariant Mouse a) {} // 共変であることを明示
}
```

### 例: `late` で Null Safety の問題を修正する
**入力（静的解析に失敗）:**
```dart
class Thermometer {
  String temperature; // エラー: non-nullable のインスタンスフィールドは初期化が必要

  void read() {
    temperature = '20C';
  }
}
```

**出力（静的解析に合格）:**
```dart
class Thermometer {
  late String temperature; // 初期化の確認を実行時まで遅らせる

  void read() {
    temperature = '20C';
  }
}
```
