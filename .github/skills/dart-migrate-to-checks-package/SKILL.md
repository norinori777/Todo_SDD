---
name: dart-migrate-to-checks-package
description: |-
  `package:matcher` の `expect` などの関数を、
  `package:checks` の同等機能に置き換えます。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 09 Jun 2026 19:30:00 GMT
---
# Dart テストを package:checks に移行する

レガシーな `package:matcher`（`package:test/test.dart` からデフォルトでエクスポートされる）から、最新の型安全で記述的なアサーションライブラリ `package:checks` へ Dart のテストスイートを移行する場合に、このスキルを使用します。

## 目次
- [このスキルを使用する場面](#when-to-use-this-skill)
- [このスキルの使用方法（ワークフロー）](#how-to-use-this-skill-the-workflow)
- [主な構文の違いと注意点](#key-syntax-differences-and-pitfalls)
- [Matcher と Checks の対応表](#matcher-to-checks-mapping-table)
- [直接置き換えられない Matcher](#matchers-with-no-direct-replacements)
- [対象を見つける方法](#strategies-for-discovery)
- [例](#examples)

---

## このスキルを使用する場面
- 「テストを checks に移行する」「package:checks を使う」「テストアサーションを最新化する」と依頼された場合。
- 静的型安全性、IDE の補完機能の向上、詳細な失敗診断が求められるレガシーなテストスイートを更新する場合。

---

## このスキルの使用方法（ワークフロー）

次の手順に従って、テストスイートを安全かつ体系的に移行します。

### 1. 依存関係の設定
- `pubspec.yaml` の `dev_dependency` として `package:checks` を追加します。
  ```bash
  dart pub add dev:checks
  ```
- `package:matcher` が `dev_dependencies` に明示的に記載されている場合は削除します（通常は `package:test` の推移的依存関係として含まれるため、そのままで問題ありません）。

### 2. 対象ファイルを特定して計画する
- [対象を見つける方法](#strategies-for-discovery)の grep パターンを使い、レガシーな `expect` や `expectLater` 呼び出しを含むテストファイルをすべて特定します。
- ファイル単位で一括移行するか、段階的に移行するかを決めます。

### 3. ファイルを移行する（一括または段階的）
対象となるテストファイルごとに、次の操作を行います。
1. **インポートを更新する:**
   - 汎用の `import 'package:test/test.dart';` を次の内容に置き換えます。
     ```dart
     import 'package:test/scaffolding.dart';
     import 'package:checks/checks.dart';
     ```
   - **段階的に移行する場合:** ファイル内の一部のテストケースだけを移行する場合や、一度に少しずつ移行する場合は、次を追加します。
     ```dart
     import 'package:test/expect.dart'; // 一時的にレガシーな expect() を使用可能にする
     ```
2. **アサーションを置き換える:** [主な構文の違いと注意点](#key-syntax-differences-and-pitfalls)および[Matcher と Checks の対応表](#matcher-to-checks-mapping-table)に従い、レガシーな `expect` と `expectLater` の呼び出しを `check` 構文に書き換えます。
3. **コンパイラーで検証する:** 一括移行する場合は、`import 'package:test/expect.dart';` の行を削除します。移行されていない `expect` 呼び出しが残っていれば、コンパイルエラーとしてすぐに表示されるため、簡単に見つけて修正できます。

### 4. 検証とフィードバックループ
- **静的解析:** 対象パッケージで静的解析を実行します。
  ```bash
  dart analyze
  ```
  `.isA<Type>()` のジェネリック型パラメーターに注意し、非同期アサーションが適切に await されていることを確認します（`unawaited_futures` 警告も確認してください）。
- **テストを実行:** テストを実行し、動作とアサーションの実行時ロジックの両方を検証します。
  ```bash
  dart test
  ```
  テストが失敗した場合は、`package:checks` の非常に詳細な失敗出力を確認し、テスト自体が実際に失敗しているのか、期待値の置き換えを誤ったのかを診断します。

---

## 主な構文の違いと注意点

> [!IMPORTANT]
> 1行ずつ機械的に置き換えると、微妙なバグや誤った成功判定につながることがあります。次の主な違いを必ず慎重に確認してください。

### 1. コレクションの等価性に関する注意点（`equals` と `deepEquals`）
- **レガシー Matcher:** `expect(actual, expected)` または `expect(actual, equals(expected))` は、引数がコレクション（List、Map、Set）の場合、**深い等価性のチェック**を行っていました。
- **Package Checks:** `.equals(expected)` は厳密に `operator ==` に対応します。Dart のコレクションは要素ごとの比較用に `operator ==` をオーバーライドしないため、コレクションに `.equals` を使うと、実行時にほぼ確実に失敗する*同一性*チェックになります。
- **対処方法:** コレクションの等価性アサーションは、必ず `.deepEquals(expected)` に置き換えてください。
  ```dart
  // 変更前（Matcher）
  expect(myList, [1, 2, 3]);

  // 変更後（Checks）
  check(myList).deepEquals([1, 2, 3]);
  ```

### 2. `reason` パラメーターは `because` に変更
- **レガシー Matcher:** 説明は末尾の名前付き引数 `reason` として `expect` に渡していました。
  ```dart
  expect(actual, expectation, reason: 'Explanation');
  ```
- **Package Checks:** 説明は `check` 関数の名前付き引数 `because` として、対象の値より*前に*渡します。
  ```dart
  check(because: 'Explanation', actual).expectation();
  ```

### 3. 正規表現による照合（`matches` と `matchesPattern`）
- **レガシー Matcher:** `matches(pattern)` matcher は、文字列の引数を自動的に `RegExp` に変換していました（例: `matches(r'\d')` は `'1'` に一致）。
- **Package Checks:** `.matchesPattern(pattern)` は、文字列の引数をリテラル文字列のパターンとして扱います。
- **対処方法:** 正規表現で照合するには、`RegExp` オブジェクトを明示的に渡す必要があります。
  ```dart
  // 変更前（Matcher）
  expect(someString, matches(r'\d+'));

  // 変更後（Checks）
  check(someString).matchesPattern(RegExp(r'\d+'));
  ```

### 4. プロパティの抽出（`TypeMatcher.having` と `.has`）
- **レガシー Matcher:** フィールドやプロパティに対するアサーションの連結には、`TypeMatcher.having(feature, description, matcher)` を使用していました。
  ```dart
  expect(actual, isA<Person>().having((p) => p.name, 'name', startsWith('A')));
  ```
- **Package Checks:** `.has(feature, description)` 拡張はすべての `Subject` で利用でき、引数が1つ少なく、そのプロパティを表す新しい `Subject` を返します。そこから直接アサーションを連結できます。
  ```dart
  check(actual).isA<Person>().has((p) => p.name, 'name').startsWith('A');
  ```

### 5. 同期と非同期の `throws`
- **レガシー Matcher:** `package:matcher` の `throwsA` は、`expect` または `expectLater` でラップした場合、同期クロージャーと非同期 Future の両方で同様に動作していました。
- **Package Checks:** `.throws<E>()` アサーションは、対象が同期か非同期かによって動作と戻り値の型が異なります。
  - **同期**（`Subject<T Function()>`）: `.throws<E>()` は同期的に `Subject<E>` を返します。コールバック引数は**受け取りません**。返された `Subject<E>` に対して直接アサーションを連結するか、カスケードします。
    ```dart
    // 可（同期チェーン）
    check(() => triggerSyncError()).throws<ArgumentError>()
      ..has((e) => e.message, 'message').equals('invalid input');

    // 不可（同期 throws にコールバックを渡すとコンパイルエラーになる）
    check(() => triggerSync").throws<ArgumentError>((it) => ...); // エラー！
    ```
  - **非同期**（`Subject<Future<T>>`）: `.throws<E>()` は `Future<void>` を返します。`Future<void>` から直接アサーションを連結できないため、検査用コールバックが**必要**です。
    ```dart
    // 可（非同期コールバック）
    await check(triggerAsyncError()).throws<ArgumentError>((it) => it
      ..has((e) => e.message, 'message').equals('invalid input'));
    ```
  - **重要な注意点:** 非同期 `.throws<E>()` を await した後に直接アサーションを連結しようとすると（例: `await check(future).throws<E>().equals(...)`）、`Future<void>` が返されるためコンパイルに失敗します。

### 6. RegExp / Pattern の等価性
- **レガシー Matcher:** `package:matcher` では matcher の比較規則が RegExp インスタンスを扱うため、`expect(myPattern, equals(RegExp('Hello')))` が機能していました。
- **Package Checks:** `.equals()` は Dart の厳密な `==` 等価性を使用します。別々の `RegExp` インスタンスは `==` を満たさないため、`.equals()` は実行時に失敗します。
- **対処方法:** `.isA<RegExp>()` による型の絞り込みとカスケードを使い、RegExp オブジェクトのプロパティを明示的に検証します。
  ```dart
  check(myPattern).isA<RegExp>()
    ..has((r) => r.pattern, 'pattern').equals('Hello')
    ..has((r) => r.isMultiLine, 'isMultiLine').isTrue();
  ```

### 7. nullable Boolean（`bool?` フィールド）の厳密な安全性
- **レガシー Matcher:** `isTrue` と `isFalse` は実行時に緩い動的チェックを行い、nullable Boolean（`bool?`）も暗黙的に受け入れていました。
- **Package Checks:** `.isTrue()` と `.isFalse()` は non-nullable の `Subject<bool>` に対してのみ定義されています。`Subject<bool?>` では使用**できません**。
- **対処方法:** `bool?` として宣言されたフィールドでは、対象を絞り込む（例: `.isNotNull().isTrue()`）か、すべての型で使えるジェネリックな `.equals(true)` および `.equals(false)` を使用します。
  ```dart
  // options.flagOutdated が bool? の場合
  check(options.flagOutdated).equals(true);
  check(options.flagOutdated).equals(false);
  ```

### 8. Map のキー包含（`containsKey` と `contains`）
- **レガシー Matcher:** `package:matcher` では、Map に特定のキーがあることを検証するために `contains(key)` を使用していました。
- **Package Checks:** `Subject<Map>` に対する `.contains(...)` の呼び出しは定義されていないため、コンパイルに失敗します。
- **対処方法:** 代わりに Map 専用の `.containsKey(key)` matcher を使用します。
  ```dart
  // 変更前（Matcher）
  expect(myMap, contains('my_key'));

  // 変更後（Checks）
  check(myMap).containsKey('my_key');
  ```

### 9. 拡張型に対するジェネリック型パラメーターの明示
- **レガシー Matcher:** 動的な等価性チェックが緩いため、`expect(extensionTypeConst, 3)` はコンパイルできました。
- **Package Checks:** `QrEciValue` が `int` の拡張型表現である場合（例: `extension type const QrEciValue(int value) implements int`）、`Subject<QrEciValue>` に対する `.equals(3)` は失敗します。`3`（`int`）は `QrEciValue` に代入できないためです。`QrEciValue` は静的に `int` を実装しているため、`as int` によるキャストは静的解析で「不要なキャスト」の警告を発生させます。
- **対処方法:** `check` 関数にジェネリック型パラメーターを明示し、Checks がプリミティブ型として扱うようにします。
  ```dart
  // 可（型安全で警告なし）
  check<int>(QrEciValue.iso8859_1).equals(3);
  ```

### 10. Dynamic Map / JSON 検索結果のキャスト
- **レガシー Matcher:** 動的型付けが緩いため、`dynamic` として静的に型付けされたネストした JSON 検索結果を、リストや Map と直接比較できました。
- **Package Checks:** 厳密な型安全性により、`.deepEquals(...)` 内で `dynamic` を `Iterable<Object?>` に暗黙的に代入することはできません。
- **対処方法:** dynamic の検索結果を `List` または Map に静的にキャストします。
  ```dart
  // 可（List に明示的にキャスト）
  check(myIterable).deepEquals(json['data']['items'] as List);
  ```

---

## Matcher と Checks の対応表

matcher を直接置き換える際の早見表として使用してください。

| レガシー Matcher | Package Checks での対応 | 注記 |
| :--- | :--- | :--- |
| `expect(actual, expected)` | `check(actual).equals(expected)` | コレクションには `.deepEquals` を使用 |
| `expect(actual, equals(expected))` | `check(actual).equals(expected)` | コレクションには `.deepEquals` を使用 |
| `isA<T>()` | `check(actual).isA<T>()` | 直接チェーン可能 |
| `same(expected)` | `check(actual).identicalTo(expected)` | 同一性を検証 |
| `anyElement(matcher)` | `check(iterable).any(conditionCallback)` | 例: `check(list).any((e) => e.equals(1))` |
| `everyElement(matcher)` | `check(iterable).every(conditionCallback)` | 例: `check(list).every((e) => e.isGreaterThan(0))` |
| `hasLength(expected)` | `check(actual).length.equals(expected)` | String、Map、Iterable などで使用可能 |
| `isNot(matcher)` | `check(actual).not(conditionCallback)` | 例: `check(val).not((it) => it.equals(5))` |
| `contains(element)` | `check(actual).contains(element)` | String、Iterable で使用可能（Map には `containsKey` を使用） |
| `contains(key)`（Map の場合） | `check(map).containsKey(key)` | Map のキー包含 |
| `startsWith(prefix)` | `check(string).startsWith(prefix)` | String のみ |
| `endsWith(suffix)` | `check(string).endsWith(suffix)` | String のみ |
| `isEmpty` | `check(actual).isEmpty()` | String、Map、Iterable で使用可能 |
| `isNotEmpty` | `check(actual).isNotEmpty()` | String、Map、Iterable で使用可能 |
| `isNull` | `check(actual).isNull()` | |
| `isNotNull` | `check(actual).isNotNull()` | |
| `isTrue` / `true` | `check(actual).isTrue()` | non-nullable の `bool` のみで使用可能 |
| `isFalse` / `false` | `check(actual).isFalse()` | non-nullable の `bool` のみで使用可能 |
| `completion(matcher)` | `await check(future).completes(conditionCallback)` | await が必要 |
| `throwsA(matcher)` | `await check(future).throws<Type>()` | await が必要 |
| `emits(value)` | `await check(streamQueue).emits(conditionCallback)` | await が必要 |
| `emitsThrough(value)` | `await check(streamQueue).emitsThrough(conditionCallback)` | await が必要 |
| `stringContainsInOrder(list)` | `check(string).containsInOrder(list)` | String のみ |
| `pairwiseCompare(...)` | `check(actual).pairwiseMatches(...)` | |

---

## 直接置き換えられない Matcher

API の整理により、一部のレガシー matcher には `package:checks` に一対一で対応する機能がありません。次の標準的な代替方法を使用してください。

### 1. 特定のエラー用 Matcher
- **レガシー:** `throwsArgumentError`、`throwsStateError`、`throwsUnsupportedError` など。
- **Checks:** 対象のエラー型を指定して `.throws<T>()` を使用します。
  ```dart
  await check(triggerError()).throws<ArgumentError>();
  ```

### 2. `anything` Matcher
- **レガシー:** `expect(actual, anything)`
- **Checks:** 構文上条件コールバックが必要な場合は、空のコールバック `(_) {}` を渡します。
  ```dart
  await check(someFuture).completes((_) {});
  ```

### 3. 数値に関する特定の判定
- **レガシー:** `isPositive`、`isNegative`、`isZero`、`isNonPositive`、`isNonNegative`、`isNonZero`
- **Checks:** 比較アサーションを明示的に使用します。
  - `isPositive` $\rightarrow$ `isGreaterThan(0)`
  - `isNegative` $\rightarrow$ `isLessThan(0)`
  - `isZero` $\rightarrow$ `equals(0)`
  - `isNonNegative` $\rightarrow$ `isGreaterOrEqual(0)`

### 4. 数値範囲
- **レガシー:** `inClosedOpenRange(min, max)`、`inInclusiveRange(min, max)` など。
- **Checks:** カスケード演算子 (`..`) を使って範囲の境界を連結します。
  ```dart
  check(actualValue)
    ..isGreaterOrEqual(min)
    ..isLessThan(max);
  ```

---

## 独自のアサーションを書く（独自 Matcher の置き換え）

レガシーなコードベースを移行する際、独自の `Matcher` サブクラスが見つかることがあります。`package:checks` では、独自アサーションを `Subject<T>` に対する `extension` メソッドとして実装します。

独自の期待値検証を書くには、checks context API をインポートする必要があります。
```dart
import 'package:checks/context.dart';
```

### 1. 単純な独自アサーション（`expect` を使用）
`context.expect` を使ってプロパティを検査し、失敗時には `Rejection` を返します。
```dart
extension CustomPersonChecks on Subject<Person> {
  void isAdult() {
    context.expect(
      () => ['成人である（年齢 >= 18）'],
      (actual) {
        if (actual.age >= 18) return null; // 成功
        return Rejection(
          which: ['年齢は ${actual.age} 歳のみ'],
        );
      },
    );
  }
}
```

### 2. ネストされたプロパティの抽出（`nest` または `has` を使用）
プロパティを抽出してさらにアサーションを連結できるようにするには、`nest` または、より簡潔な `has` ヘルパーを使用します。
- **`has` を使う（単純で失敗しないフィールドアクセスに推奨）:**
  ```dart
  extension CustomPersonChecks on Subject<Person> {
    Subject<Address> get address => has((p) => p.address, 'address');
  }
  ```
- **`nest` を使う（失敗または拒否があり得るプロパティ抽出向け）:**
  ```dart
  extension CustomPersonChecks on Subject<Person> {
    Subject<String> get ssn => context.nest(
      '有効な SSN がある',
      (actual) {
        final ssnValue = actual.ssn;
        if (ssnValue == null) {
          return Extracted.rejection(which: ['SSN がない']);
        }
        return Extracted.value(ssnValue);
      },
    );
  }
  ```

### 3. 非同期の独自アサーション
Future や Stream の検査など、アサーションが非同期の場合は `context.expectAsync` または `context.nestAsync` を使い、結果の `Future` を返します。
```dart
extension CustomFutureChecks<T> on Subject<Future<T>> {
  Future<void> completesNormally() {
    return context.expectAsync(
      () => ['例外をスローせずに完了する'],
      (actual) async {
        try {
          await actual;
          return null; // 成功
        } catch (e) {
          return Rejection(which: ['例外をスロー: $e']);
        }
      },
    );
  }
}
```

---

## 対象を見つける方法

ターミナルで次のコマンドを実行し、移行が必要なレガシー matcher とファイルを特定します。

```bash
# 1. レガシーな expect() または expectLater() を含むテストファイルをすべて検索
grep -rn "expect(" test/
grep -rn "expectLater(" test/

# 2. コレクションの等価性に関する注意箇所（リストまたは Map のリテラル）を検索
grep -rn "expect(.*, \[" test/
grep -rn "expect(.*, {" test/

# 3. matches() の呼び出しを検索（RegExp + matchesPattern への変換が必要）
grep -rn "matches(" test/

# 4. レガシーな TypeMatcher.having() の呼び出しを検索（.has() への変換が必要）
grep -rn "having(" test/
```

---

## 例

### 基本的なアサーション
**変更前（Matcher）:**
```dart
expect(someValue, isNotNull);
expect(result, isTrue, reason: 'should be successful');
expect(myString, startsWith('hello'));
```

**変更後（Checks）:**
```dart
check(someValue).isNotNull();
check(because: '成功するはず', result).isTrue();
check(myString).startsWith('hello');
```

### コレクションと深い等価性
**変更前（Matcher）:**
```dart
expect(items, [1, 2, 3]);
expect(configMap, equals({'port': 8080}));
```

**変更後（Checks）:**
```dart
check(items).deepEquals([1, 2, 3]);
check(configMap).deepEquals({'port': 8080});
```

### チェーンとカスケード
**変更前（Matcher）:**
```dart
expect(someString, allOf([
  startsWith('a'),
  contains('b'),
  endsWith('c'),
]));
```

**変更後（Checks）:**
```dart
check(someString)
  ..startsWith('a')
  ..contains('b')
  ..endsWith('c');
```

### 複雑なプロパティ照合（has）
**変更前（Matcher）:**
```dart
expect(response, isA<Response>()
    .having((r) => r.statusCode, 'statusCode', 200)
    .having((r) => r.body, 'body', contains('success')));
```

**変更後（Checks）:**
```dart
check(response).isA<Response>()
  ..has((r) => r.statusCode, 'statusCode').equals(200)
  ..has((r) => r.body, 'body').contains('success');
```

### 非同期 Future
**変更前（Matcher）:**
```dart
expect(fetchData(), completes);
expect(fetchData(), completion(equals('data')));
expect(failingCall(), throwsA(isA<StateError>()));
```

**変更後（Checks）:**
```dart
await check(fetchData()).completes();
await check(fetchData()).completes((it) => it.equals('data'));
await check(failingCall()).throws<StateError>();
```

### 非同期 Stream
**変更前（Matcher）:**
```dart
var queue = StreamQueue(Stream.fromIterable([1, 2, 3]));
await expectLater(queue, emitsInOrder([1, 2, 3]));
```

**変更後（Checks）:**
```dart
var queue = StreamQueue(Stream.fromIterable([1, 2, 3]));
await check(queue).inOrder([
  (s) => s.emits((e) => e.equals(1)),
  (s) => s.emits((e) => e.equals(2)),
  (s) => s.emits((e) => e.equals(3)),
]);
```
