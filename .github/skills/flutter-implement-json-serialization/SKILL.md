---
name: flutter-implement-json-serialization
description: `dart:convert` を使って `fromJson` メソッドと `toJson` メソッドを持つモデルクラスを作成します。単純なデータ構造で JSON キーをクラスプロパティに手動で対応付ける場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 21:44:50 GMT
---
# Flutter での JSON の手動シリアライズ

## 目次
- [基本ガイドライン](#基本ガイドライン)
- [ワークフロー: シリアライズ可能なモデルの実装](#ワークフロー-シリアライズ可能なモデルの実装)
- [ワークフロー: JSON の取得と解析](#ワークフロー-json-の取得と解析)
- [例](#例)

## 基本ガイドライン

- **`dart:convert` をインポートする:** Flutter 組み込みの `dart:convert` ライブラリを使い、JSON の手動エンコード（`jsonEncode`）とデコード（`jsonDecode`）を行います。
- **型安全性を確保する:** `jsonDecode()` の `dynamic` な戻り値は、必ず期待する型にキャストします。通常、オブジェクトには `Map<String, dynamic>`、配列には `List<dynamic>` を使用します。
- **シリアライズ処理をカプセル化する:** JSON 構造に対応するプロパティを持つプレーンなモデルクラスを定義します。モデル内に `fromJson` ファクトリーコンストラクターと `toJson` メソッドを実装します。
- **バックグラウンド解析に対応する:** 大きな JSON ドキュメントの解析に16ミリ秒を超える時間がかかる場合は、UI のカクつきを防ぐため、Flutter の `compute()` 関数を使って解析処理を別のアイソレートに移します。
- **失敗時は例外をスローする:** HTTP レスポンスを処理するとき、ステータスコードが成功を示さない場合（例: 200 OK または 201 Created 以外）は例外をスローします。`null` は返さないでください。

## ワークフロー: シリアライズ可能なモデルの実装

データモデルの JSON 手動シリアライズを実装する際は、このチェックリストを使います。

**作業の進捗:**
- [ ] `final` プロパティを持つプレーンなモデルクラスを定義する。
- [ ] `factory Model.fromJson(Map<String, dynamic> json)` コンストラクターを実装する。
- [ ] `Map<String, dynamic> toJson()` メソッドを実装する。
- [ ] 2つのシリアライズメソッドの単体テストを作成する。
- [ ] バリデーターを実行 -> 型の不一致エラーを確認 -> キャスト処理を修正する。

1. **モデルを定義する:** JSON キーに対応するプロパティを持つクラスを作成します。
2. **`fromJson` を実装する:** `Map` から値を取り出し、適切な Dart 型にキャストします。パターンマッチングまたは明示的なキャストを使います。
3. **`toJson` を実装する:** クラスのプロパティを対応する JSON 文字列キーに戻す `Map<String, dynamic>` を返します。
4. **検証する:** 単体テストを実行し、型安全性、補完、コンパイル時の例外処理が正しく機能することを確認します。

## ワークフロー: JSON の取得と解析

ネットワークリクエストから JSON を取得して解析するときは、次の条件付きワークフローを使います。

**作業の進捗:**
- [ ] HTTP リクエストを実行する。
- [ ] レスポンスのステータスコードを検証する。
- [ ] 解析方法（同期処理またはアイソレート）を決定する。
- [ ] JSON をデコードしてモデルに対応付ける。

1. **リクエストを実行する:** `http` パッケージを使ってネットワーク呼び出しを行います。
2. **レスポンスを検証する:**
   - `response.statusCode == 200`（POST の場合は 201）なら解析に進みます。
   - ステータスコードが失敗を示す場合は `Exception` をスローします。
3. **解析方法を決める:**
   - **小さなペイロード**（例: 単一オブジェクト）の解析は、メインスレッドで同期的に行います。
   - **大きなペイロード**（例: 数千個のオブジェクトの配列）の解析には、`compute(parseFunction, response.body)` を使ってバックグラウンドのアイソレートで処理します。
4. **デコードして対応付ける:** デコードした JSON をモデルの `fromJson` コンストラクターに渡します。

## 例

### 詳細なモデル実装の例

```dart
import 'dart:convert';

class User {
  final int id;
  final String name;
  final String email;

  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  // デシリアライズ用ファクトリーコンストラクター
  factory User.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': int id,
        'name': String name,
        'email': String email,
      } => 
        User(
          id: id,
          name: name,
          email: email,
        ),
      _ => throw const FormatException('ユーザーの読み込みに失敗しました。'),
    };
  }

  // シリアライズ用メソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}
```

### 同期解析（小さなペイロード）

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<User> fetchUser(http.Client client, int userId) async {
  final response = await client.get(
    Uri.parse('https://api.example.com/users/$userId'),
    headers: {'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    // デコード結果は dynamic なので、Map<String, dynamic> にキャストする
    final Map<String, dynamic> jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson(jsonMap);
  } else {
    throw Exception('ユーザーの読み込みに失敗しました');
  }
}
```

### バックグラウンド解析（大きなペイロード）

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// compute() に必要なトップレベル関数
List<User> parseUsers(String responseBody) {
  final parsed = (jsonDecode(responseBody) as List<dynamic>).cast<Map<String, dynamic>>();
  return parsed.map<User>((json) => User.fromJson(json)).toList();
}

Future<List<User>> fetchUsers(http.Client client) async {
  final response = await client.get(
    Uri.parse('https://api.example.com/users'),
    headers: {'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    // 負荷の高い解析をバックグラウンドのアイソレートに移す
    return compute(parseUsers, response.body);
  } else {
    throw Exception('ユーザー一覧の読み込みに失敗しました');
  }
}
```
