---
name: dart-use-primary-constructors
description: >
  Dart で構文的にも意味的にも正しいプライマリコンストラクターを記述できるよう支援し、新しいコンストラクター構文、空の本体にセミコロンを使う構文、本体内の初期化リスト構文、短縮コンストラクター構文への移行や使用をサポートします。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Thu, 09 Jul 2026 23:13:25 GMT
---

# Dart のプライマリコンストラクターと新しいコンストラクター構文に関するスキル

Dart の **プライマリコンストラクター**機能を使うコードの記述、リファクタリング、デバッグを支援する場合にこのスキルを使用します。

### Dart のバージョン要件
*   **Dart 3.13 以降:** プライマリコンストラクターはデフォルトで有効です。
*   **Dart 3.12:** この機能は利用できますが、実験段階です。`--enable-experiment=primary-constructors` を指定するか、`analysis_options.yaml` で実験フラグ `primary-constructors` を明示的に有効にする必要があります。
```yaml
analyzer:
  enable-experiment:
    - primary-constructors
```
*   **Dart 3.11 以前:** プライマリコンストラクターはサポートされていません。

---

## 1. 概要
プライマリコンストラクターを使うと、リダイレクトしない生成コンストラクターと複数のインスタンス変数をクラスヘッダーに直接宣言できます。定型コードを大幅に減らし、コードの可読性を高めます。

### 主な利点
- フィールド宣言、パラメーター宣言、初期化を、宣言パラメーター宣言と呼ばれる1つの宣言にまとめられます。
- `late` ではないフィールド初期化子で、コンストラクターパラメーターを安全に参照できます（プライマリ初期化スコープ）。
- 宣言本体が空の場合、セミコロン（`;`）で簡潔に表現できます。
- クラス本体内のコンストラクターに短縮構文が導入されます。

---

## 2. 構文リファレンス

### 2.1 クラスヘッダーの基本構文
プライマリコンストラクターを宣言するには、型名（および任意の型パラメーター）の直後にパラメーターリストを置きます。

```dart
// フィールド x、y と、生成コンストラクター Point(this.x, this.y) を宣言する
class Point(var int x, var int y);

// final フィールドを宣言する
class PointFinal(final int x, final int y);
```

### 2.2 宣言パラメーター、初期化パラメーター、通常のパラメーター
プライマリコンストラクターのパラメーターリストでは、次の3種類のパラメーターを区別します。
1. **宣言パラメーター:** `var` または `final` 修飾子（例: `final int x`）で示します。対応するインスタンスフィールドがクラス内に暗黙的に作成されます。
2. **初期化パラメーター:** `this.` または `super.` 接頭辞（例: `this.x`、`super.x`）で示します。それぞれ、既存のフィールドまたはスーパークラスのコンストラクターパラメーターを初期化します。
3. **通常のパラメーター:** 修飾子なしで宣言します（例: `int y`）。フィールドにはならず、初期化中（例: フィールド初期化子やクラス本体内の `this :` 初期化リスト）にのみ使用できます。

```dart
// `x` は `final` キーワードを持つため、フィールドでありパラメーターでもある。特に、プライマリコンストラクターの本体内にある初期化リストで `x` という名前を使える。`y` は `final` も `var` も持たないためパラメーターにすぎないが、`this :` 初期化リストを介してスーパークラスのコンストラクターに渡される。
class C(final int x, int y) extends Base {
  this : super(y);
}
```

宣言パラメーターと初期化パラメーターは、コンストラクターで設定されるインスタンスフィールドを持つクラスを宣言する、同じ目的を実現する2つの方法です。通常のパラメーターは、値がインスタンスフィールドに自動的に割り当てられない点が異なります。

### 2.3 const プライマリコンストラクター
プライマリコンストラクターを `const` にするには、宣言ヘッダーでクラス／型名の前に `const` キーワードを置きます。

```dart
class const Point(final int x, final int y);
extension type const Ext(int x);
enum const MyEnum(final int x) {
  entry(1);
}
```

### 2.4 拡張型
拡張型は**必ず**プライマリコンストラクターを使います。
- ヘッダー内の単一パラメーターが表現フィールドです。
- 表現変数には `var` 修飾子を使えません（`var` を使うと `representation_field_modifier` エラーになります）。
- 表現変数には任意で `final` 修飾子を付けられます。`final` がない場合は推論されます。つまり、パラメーターは明示的に `final` かどうかを宣言します。

### 2.5 空の本体をセミコロンで省略する構文（`;`）
クラス、mixin クラス、mixin、extension、または拡張型の本体が空の場合、`{}` の代わりにセミコロン（`;`）を使えます。

```dart
class C(int x);
mixin class MC;
extension type ET(int x);
mixin M;
extension Ext on C;
```

### 2.6 プライマリコンストラクターの本体部分（`this ...`）
プライマリコンストラクターにアサーションやカスタムフィールド初期化が必要な場合、本体内で `this :` 構文を使って宣言できます。

```dart
class Point(var int x, var int y) {
  // クラス本体内の初期化リスト
  this : assert(x >= 0), y = y * 2;
}
```

この構文（`this {...}`）を使ってコンストラクター本体を記述することもできます。

### 2.7 短縮コンストラクター構文
クラス本体内で宣言するコンストラクターでは、クラス名を省略し、`new` または `factory` キーワードに置き換えられます。

| Traditional Syntax | Abbreviated Concise Syntax |
| :--- | :--- |
| `MyClass() {}` | `new() {}` |
| `MyClass.name() {}` | `new name() {}` |
| `const MyClass();` | `const new();` |
| `const MyClass.name();` | `const new name();` |
| `factory MyClass() => ...` | `factory() => ...` |
| `factory MyClass.name() => ...` | `factory name() => ...` |

---

## 3. 意味とスコープ規則

### 3.1 プライマリ初期化スコープ
プライマリコンストラクターを宣言すると、その仮パラメーターは**プライマリ初期化スコープ**に導入されます。このスコープは、クラス本体内の `late` ではないフィールド初期化子と、プライマリコンストラクターの初期化リスト（`this :` の後）における現在のスコープです。
これにより、`late` ではないフィールドの宣言時に、コンストラクターパラメーターを直接参照できます。
  ```dart
  class DeltaPoint(final int x, int delta) {
    // ここでは 'x' と 'delta' がスコープ内にある
    final int y = x + delta;
  }
  ```

### 3.2 late インスタンス変数の制限
プライマリ初期化スコープは、`late` インスタンス変数の初期化子では**有効になりません**。
- `late` 変数は構築完了後に評価される場合があるため、その初期化子からコンストラクターパラメーターに安全にアクセスすることはできません。
- `late` フィールド初期化子でプライマリコンストラクターパラメーターにアクセスしようとすると、コンパイル時エラーになります。

### 3.3 シャドーイング
プライマリ初期化スコープ内では、プライマリコンストラクターパラメーターが同名のクラスメンバー（フィールド）を隠します。
- `late` ではない初期化子では、`int y = x` の `x` はパラメーターを参照します。
- `late` 初期化子ではパラメーター `x` がスコープ外になるため、`late int y = x` の `x` は（存在する場合）フィールドを参照します。

### 3.4 生成コンストラクターの制約
プライマリコンストラクター（および関連する初期化スコープ）が必ず実行されるようにするため、次の制約があります。
- プライマリコンストラクターを持つクラス、mixin クラス、enum 宣言では、（拡張型を除き）ほかのリダイレクトしない生成コンストラクターを宣言**できません**。
- 本体内で宣言するほかの生成コンストラクターは、すべてプライマリコンストラクターに（直接または間接的に）リダイレクト**する必要があります**。

### 3.5 パラメーター変更エラー
初期化フェーズ内では、プライマリコンストラクターパラメーターに代入できません。
- フィールド初期化子または `this :` 初期化リスト内でパラメーターに代入すると（例: `p = value`、`p++`）、コンパイル時エラーになります。

### 3.6 二重初期化エラー
フィールドを2回初期化すると（例: フィールド宣言／初期化子で1回、`this :` 初期化リストまたは初期化形式パラメーターで1回）、コンパイル時エラーになります。

---

## 4. 診断とトラブルシューティング

多くのエラーや lint にはクイックフィックスが用意されています。`dart fix` を実行して修正してください。その他の一般的なエラーは、次の表を参考に修正します。

| エラー／Lint コード | 主な原因 | 解決方法 |
| :--- | :--- | :--- |
| **Invalid Late Access** | `late` フィールド初期化子内でプライマリコンストラクターパラメーターを参照している。 | フィールドを `late` ではなくするか、別の `late` ではないフィールドを介して値を渡します。 |
| `fieldInitializedInInitializerAndDeclaration` | 変数を宣言時と `this :` リストの両方で初期化している。 | どちらか一方の初期化を削除します。 |
| `nonRedirectingGenerativeConstructorWithPrimary` | 本体内の生成コンストラクターが、プライマリコンストラクターにリダイレクトせずに宣言されている。 | 本体内のコンストラクターをリダイレクトするように変更する（例: `this(...)`）か、削除します。 |

---

## 5. 段階的なリファクタリングのワークフロー

### ワークフロー 5.1: クラスをプライマリコンストラクターに移行する

冗長なクラスを新しいプライマリコンストラクター構文に移行するには、次の手順に従います。

1. **対象となるフィールドとコンストラクターを特定する:**
   生成コンストラクターと、それらが初期化するフィールドを探します。この例では `name` と `age` フィールドが該当します。
   ```dart
   // 変更前
   class User {
     final String name;
     final int age;
     User(this.name, this.age);
   }
   ```

2. **フィールドをヘッダーに移動する:**
   `final` または `var` 修飾子を付けてフィールドをヘッダーに配置し、本体が空であればセミコロン（`;`）を末尾に付けます。ここでは `name` と `age` フィールドを、それぞれ宣言パラメーター `final String name` と `final int age` としてプライマリコンストラクターに記述します。
   ```dart
   // 変更後
   class User(final String name, final int age);
   ```

3. **カスタム初期化子とアサーションを処理する:**
   初期化リストまたは assert ブロックがある場合は、本体内の `this` ブロックに移動します。
   ```dart
   // 変更前
   class Point {
     final int x;
     final int y;
     Point(this.x, this.y) : assert(x >= 0);
   }

   // 変更後
   class Point(final int x, final int y) {
     this : assert(x >= 0);
   }
   ```

4. **計算にプライマリ初期化スコープを活用する:**
   フィールド値をパラメーターから計算する場合は、本体内でフィールドを宣言し、パラメーターを直接使って代入します。
   ```dart
   // 変更前
   class Rect {
     final double width;
     final double height;
     final double area;
     Rect(this.width, this.height) : area = width * height;
   }

   // 変更後
   class Rect(final double width, final double height) {
     // ここでは 'width' と 'height' がスコープ内にある
     final double area = width * height;
   }
   ```

5. **本体内のコンストラクターをリダイレクト形式に変換する:**
   本体内の生成コンストラクターがすべてプライマリコンストラクターにリダイレクトすることを確認します。
   ```dart
   // 変更前
   class Point {
     final int x;
     final int y;
     Point(this.x, this.y);
     Point.zero() : x = 0, y = 0;
   }

   // 変更後
   class Point(final int x, final int y) {
     new zero() : this(0, 0); // プライマリコンストラクターにリダイレクトする
   }
   ```

### ワークフロー 5.2: 短縮形式の本体内コンストラクターを適用する

コンストラクターをクラス本体内に残しつつ記述を簡潔にしたい場合は、短縮コンストラクター構文を提案します。

```dart
// 変更前
class DatabaseService {
  final String url;
  DatabaseService(this.url);
  DatabaseService.local() : url = 'localhost';
  factory DatabaseService.create() => DatabaseService('default');
}

// 変更後
class DatabaseService {
  final String url;
  new(this.url); // クラス名を省略し、'new' を使う
  new local() : url = 'localhost'; // 名前付きコンストラクターには 'new local' を使う
  factory create() => DatabaseService('default'); // factory からクラス名を省略する
}
```
