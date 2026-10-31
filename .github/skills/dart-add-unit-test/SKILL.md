---
name: dart-add-unit-test
description: `package:test` を使った関数、メソッド、クラスの単体テストを作成・整理します。新しいロジックを作成する場合やバグを修正する場合に、コードの正しさを保ち、リグレッションを防ぐために使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Mon, 03 Aug 2026 21:51:24 GMT
---
# Dart と Flutter アプリケーションのテスト

## 目次
- [テストファイルの構成](#テストファイルの構成)
- [テストの記述](#テストの記述)
- [テストの実行](#テストの実行)
- [テスト実装のワークフロー](#テスト実装のワークフロー)
- [例](#例)

## テストファイルの構成
予測しやすい構成にするため、テストファイルは `lib` ディレクトリの構造を反映させます。

* すべてのテストコードは、パッケージルートの `test` ディレクトリに配置します。
* すべてのテストファイル名の末尾に `_test.dart` を付けます（例: `lib/src/utils.dart` のテストは `test/src/utils_test.dart` に配置します）。
* 統合テストを作成する場合は、パッケージルートの `integration_test` ディレクトリに配置します。

## テストの記述
Dart アプリケーションの標準テストライブラリとして `package:test` を使用します。

* `package:test/test.dart` をインポートします（Flutter の場合は `package:flutter_test/flutter_test.dart`）。
* `group()` 関数を使って関連するテストをまとめ、共通のコンテキストを設定します。
* `test()` 関数を使って個々のテストケースを定義します。
* `expect()` 関数とマッチャー（例: `equals()`、`isTrue`、`throwsA()`）を使って結果を検証します。
* 非同期テストは標準の `async` / `await` 構文で記述します。テストランナーは `Future` の完了を自動的に待機します。
* `setUp()` と `tearDown()` コールバックを使って、テストのセットアップと後処理を管理します。
* 依存性注入を使うコードでは、まず公開インターフェースを実装するFakeで必要な振る舞いを検証できるか検討します。相互作用の検証などで必要な場合に限り `package:mockito` などのMockを使います。[Fakeのルール](../../../agents/rules/flutter-todo/testing-fakes.md)も参照してください。

## テストの実行
プロジェクトの種類とテストの場所に応じて、適切なテストランナーを選択します。

* 純粋な Dart プロジェクトの場合は、`dart test` コマンドでテストを実行します。
* Flutter プロジェクトの場合は、`flutter test` コマンドでテストを実行します。
* 統合テストを実行する場合、標準のランナーはそのディレクトリを無視するため、パスを明示します: `dart test integration_test` または `flutter test integration_test`。

## テスト実装のワークフロー

新しいテストスイートを実装するときは、次の順序でワークフローに従います。進捗を追跡するにはチェックリストをコピーしてください。

### 作業の進捗
- [ ] 1. `_test.dart` の接尾辞を付けて、`test/` ディレクトリにテストファイルを作成する。
- [ ] 2. `package:test/test.dart`（Flutterでは `package:flutter_test/flutter_test.dart`）と対象ライブラリをインポートする。
- [ ] 3. `main()` 関数を定義する。
- [ ] 4. `setUp()` を使って共有リソースやモックを初期化する。
- [ ] 5. `group()` を使って機能ごとにまとめた `test()` ケースを記述する。
- [ ] 6. 適切な CLI コマンドでテストスイートを実行する。
- [ ] 7. **フィードバックループ:** テストを実行 -> 失敗時のスタックトレースを確認 -> 実装またはアサーションを修正 -> 成功するまで再実行する。

## 例

### 標準的な単体テストスイート
テストのグループ化、セットアップ、同期テスト、非同期テストの例です。

```dart
import 'package:test/test.dart';
import 'package:my_package/calculator.dart';

void main() {
  group('計算機', () {
    late Calculator calc;

    setUp(() {
      calc = Calculator();
    });

    test('2つの数値を正しく加算する', () {
      expect(calc.add(2, 3), equals(5));
    });

    test('非同期処理を実行する', () async {
      final result = await calc.fetchRemoteValue();
      expect(result, isNotNull);
      expect(result, greaterThan(0));
    });
  });
}
```

### Mockito を使ったモック
Fakeでは不十分で、相互作用の検証が必要な場合にモックオブジェクトを設定する例です。

```dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:my_package/api_client.dart';
import 'package:my_package/data_service.dart';

// build_runner を使ってモックを生成します: dart run build_runner build
@GenerateNiceMocks([MockSpec<ApiClient>()])
import 'data_service_test.mocks.dart';

void main() {
  group('データサービス', () {
    late MockApiClient mockApiClient;
    late DataService dataService;

    setUp(() {
      mockApiClient = MockApiClient();
      dataService = DataService(apiClient: mockApiClient);
    });

    test('API 呼び出し成功時に解析済みデータを返す', () async {
      // モックを設定
      when(mockApiClient.get('/data')).thenAnswer((_) async => '{"id": 1}');

      // テスト対象を実行
      final result = await dataService.fetchData();

      // 結果と相互作用を検証
      expect(result.id, equals(1));
      verify(mockApiClient.get('/data')).called(1);
    });
  });
}
```
