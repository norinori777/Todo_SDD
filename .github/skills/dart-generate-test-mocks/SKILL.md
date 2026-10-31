---
name: dart-generate-test-mocks
description: `package:mockito` と `build_runner` を使って、外部依存のモックオブジェクトを定義・生成します。API やデータベースなどの複雑な外部サービスに依存するクラスを単体テストする際に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:13:58 GMT
---
# Dart アプリケーションのテストとモック

このプロジェクトでは、依存を置き換える場合、まず公開インターフェースを実装するFakeを検討します。相互作用の検証などでFakeでは不十分な場合に、このスキルのMock生成手順を使います。[Fakeのルール](../../../agents/rules/flutter-todo/testing-fakes.md)に従い、不要な依存関係は追加しません。

## 目次
- [テスト可能なコードの構成](#structuring-code-for-testability)
- [依存関係の管理](#managing-dependencies)
- [モックの生成](#generating-mocks)
- [単体テストの実装](#implementing-unit-tests)
- [ワークフロー: モックを使ったテストの作成と実行](#workflow-creating-and-running-mocked-tests)
- [例](#examples)

## テスト可能なコードの構成
Dart クラスは依存性注入をサポートするように設計します。API クライアントやデータベースなどの複雑な外部依存を分離し、テスト時にモックオブジェクトへ置き換えられるようにします。

- 外部サービス（例: `http.Client`）はクラスのコンストラクターを通じて注入します。
- `Uri.parse(string)` を使い、URL は必ず `Uri` オブジェクトとして表します。
- Dart のオブジェクト指向機能（クラス、mixin）を活用して、外部とのやり取りに明確なインターフェースを定義します。

## 依存関係の管理
必要なテストおよびコード生成パッケージを `pubspec.yaml` ファイルに設定します。

- HTTP通信が実際に必要な場合に限り、`dart pub add http` で実行時依存関係を追加します。
- Mock生成に必要な場合に限り、`dart pub add dev:mockito dev:build_runner` でテスト依存関係を追加します。純粋なDartプロジェクトでは必要に応じて `dev:test` も追加し、Flutterでは `flutter_test` を使います。
- 名前空間の衝突を避けるため、HTTP ライブラリはプレフィックス付きでインポートします: `import 'package:http/http.dart' as http;`。

## モックの生成
`package:mockito` と `build_runner` を使って、固定シナリオ用のモッククラスを自動生成し、動作を検証します。

- スタブ未設定の例外を避けるため、`@GenerateMocks` よりも `@GenerateNiceMocks` アノテーションを常に使用します。
- テストファイルにアノテーションを置き、`MockSpec<Type>()` オブジェクトのリストを渡します。
- `.mocks.dart` 拡張子を使って生成ファイルをインポートします。
- `dart run build_runner build` を実行してモックファイルを生成します。

## 単体テストの実装
生成したモックオブジェクトを使って、テスト対象システムを分離します。純粋なDartでは `package:test`、Flutterでは `package:flutter_test` でテストスイートを構成します。

- **スタブの設定:** テスト対象システムとやり取りする前に、モックの動作を設定します。
  - 同期メソッドには `when(mock.method()).thenReturn(value)` を使います。
  - **重要:** `Future` または `Stream` を返すメソッドには、必ず `thenAnswer((_) async => value)` を使います。非同期の戻り値に `thenReturn` は使わないでください。
- **検証:** テスト対象システムがモックオブジェクトと正しくやり取りしたことをアサートします。
  - 正確な呼び出し回数の確認には `verify(mock.method()).called(1)` を使います。
  - 柔軟に検証するには、`any`、`anyNamed`、`captureAny` などの引数マッチャーを使います。

## ワークフロー: モックを使ったテストの作成と実行

Fakeでは不十分と判断した場合に、次のチェックリストに沿ってモックを使った単体テストを実装・検証します。

### 作業の進捗
- [ ] 1. モック化する外部依存（例: `http.Client`）を特定する。
- [ ] 2. 対象クラスのコンストラクターに依存関係を注入する。
- [ ] 3. テストファイル（例: `target_test.dart`）を作成し、`@GenerateNiceMocks([MockSpec<Dependency>()])` を追加する。
- [ ] 4. 生成される `.mocks.dart` ファイルの `part` または `import` ディレクティブを追加する。
- [ ] 5. `dart run build_runner build` を実行してモッククラスを生成する。
- [ ] 6. `group()` と `test()` を使ってテストケースを記述する。
- [ ] 7. `when()` を使って必要な動作をスタブ設定する。
- [ ] 8. 対象のメソッドを実行する。
- [ ] 9. `verify()` でやり取りを検証し、`expect()` で結果をアサートする。
- [ ] 10. 純粋なDartでは `dart test`、Flutterでは `flutter test` でテストスイートを実行する。

### フィードバックループ: テストの失敗
テストが失敗する場合や `build_runner` でエラーが発生する場合:
1. **検証を実行:** プロジェクトに応じて `dart test` または `flutter test`、生成の確認には `dart run build_runner build` を実行します。
2. **エラーを確認:** スタブの設定漏れ、引数マッチャーの不一致、生成ファイルの構文エラーがないか確認します。
3. **修正:**
   - モックメソッドが予期しない null エラーをスローする場合は、`@GenerateNiceMocks` を使っていることを確認します。
   - 非同期スタブが `ArgumentError` をスローする場合は、`thenReturn` を `thenAnswer` に変更します。
   - `build_runner` が失敗する場合は、`.mocks.dart` のインポート名がファイル名と完全に一致することを確認します。
4. すべてのテストが成功するまで繰り返します。

## 例

### 高精度なモックとテストの例

**1. テスト対象システム (`lib/api_service.dart`)**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client client;

  ApiService(this.client);

  Future<String> fetchData(String urlString) async {
    final uri = Uri.parse(urlString);
    final response = await client.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('データの読み込みに失敗しました');
    }
  }
}
```

**2. テストの実装 (`test/api_service_test.dart`)**
```dart
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/api_service.dart';

// http.Client のモッククラスを生成
@GenerateNiceMocks([MockSpec<http.Client>()])
import 'api_service_test.mocks.dart';

void main() {
  group('ApiService', () {
    late ApiService apiService;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient();
      apiService = ApiService(mockHttpClient);
    });

    test('HTTP リクエストが成功した場合にデータを返す', () async {
      // 準備: thenAnswer を使って非同期 HTTP GET リクエストをスタブ設定する
      when(mockHttpClient.get(any)).thenAnswer(
        (_) async => http.Response('{"data": "成功"}', 200),
      );

      // 実行
      final result = await apiService.fetchData('https://api.example.com/data');

      // 検証
      expect(result, '成功');

      // 正しい Uri でモックが呼び出されたことを検証
      verify(mockHttpClient.get(Uri.parse('https://api.example.com/data'))).called(1);
    });

    test('HTTP リクエストがエラーで終了した場合に例外をスローする', () {
      // 準備
      when(mockHttpClient.get(any)).thenAnswer(
        (_) async => http.Response('見つかりません', 404),
      );

      // 実行と検証
      expect(
        apiService.fetchData('https://api.example.com/data'),
        throwsException,
      );
    });
  });
}
```
