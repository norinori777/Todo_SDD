---
name: flutter-use-http-package
description: `http` パッケージを使って GET、POST、PUT、DELETE リクエストを実行します。REST API からデータを取得または送信する場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 21:36:42 GMT
---
# Flutter のネットワーク通信を実装する

## 目次
- [設定と権限](#configuration--permissions)
- [リクエストの実行とレスポンス処理](#request-execution--response-handling)
- [バックグラウンドでの解析](#background-parsing)
- [ワークフロー: ネットワーク操作の実行](#workflow-executing-network-operations)
- [例](#examples)

## 設定と権限

ネットワークアクセスに必要な環境とプラットフォーム固有の権限を設定します。

1. ターミナルから `http` パッケージを依存関係に追加します。
   ```bash
   flutter pub add http
   ```
2. Dart ファイルでパッケージをインポートします。
   ```dart
   import 'package:http/http.dart' as http;
   ```
3. `android/app/src/main/AndroidManifest.xml` に Internet 権限を追加し、Android の権限を設定します。
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```
4. `macos/Runner/DebugProfile.entitlements` と `macos/Runner/Release.entitlements` の両方にネットワーククライアントのキーを追加し、macOS のエンタイトルメントを設定します。
   ```xml
   <key>com.apple.security.network.client</key>
   <true/>
   ```

## リクエストの実行とレスポンス処理

HTTP 操作を実行し、レスポンスを型安全な Dart オブジェクトに変換します。

*   **URI:** URL 文字列は必ず `Uri.parse('your_url')` で解析します。
*   **ヘッダー:** `headers` パラメーターの map を使って、認証ヘッダーと content-type ヘッダーを設定します。認証トークンには `HttpHeaders.authorizationHeader` を使用します。
*   **ペイロード:** POST および PUT リクエストでは、`dart:convert` の `jsonEncode()` を使って body をエンコードします。
*   **ステータスの検証:** `response.statusCode` を確認します。`200 OK`（GET/PUT/DELETE）および `201 CREATED`（POST）を成功として扱います。
*   **エラー処理:** 成功以外のステータスコードでは明示的に例外をスローします。失敗時に `null` を返すと、`FutureBuilder` がエラー状態にならず、ローディング表示が終わらなくなるため、`null` を返してはいけません。
*   **デシリアライズ:** `jsonDecode(response.body)` で生の文字列を解析し、ファクトリーコンストラクター（例: `fromJson`）を使って独自の Dart オブジェクトに変換します。

## バックグラウンドでの解析

UI のカクつき（フレーム落ち）を防ぐため、負荷の高い JSON 解析を別の Isolate に委譲します。

* `package:flutter/foundation.dart` をインポートします。
* `compute()` 関数を使って、バックグラウンド isolate で解析処理を実行します。
* クロージャーやインスタンスメソッドは isolate 間で渡せないため、`compute()` に渡す解析関数はトップレベル関数または static メソッドにしてください。

## ワークフロー: ネットワーク操作の実行

次のチェックリストに従って、ネットワーク操作を実装し検証します。

**作業の進捗:**
- [ ] 1. `fromJson` ファクトリーコンストラクターを持つ、型安全な Dart モデルを定義する。
- [ ] 2. `Future<Model>` を返すネットワークリクエストメソッドを実装する。
- [ ] 3. 操作の種類に応じた条件分岐を適用する。
  - **データを取得する場合（GET）:** URI にクエリパラメーターを追加する。
  - **データを変更する場合（POST/PUT）:** `'Content-Type': 'application/json; charset=UTF-8'` を設定し、`jsonEncode` した body を付ける。
  - **データを削除する場合（DELETE）:** 成功時（`200 OK`）に空のモデルインスタンスを返す。
- [ ] 4. `statusCode` を検証し、失敗時に `Exception` をスローする。
- [ ] 5. `FutureBuilder` を使って `Future` を UI に組み込む。
- [ ] 6. `snapshot.hasData` と `snapshot.hasError` を処理し、それ以外では `CircularProgressIndicator` を表示する。
- [ ] 7. **フィードバックループ:** アプリを実行 -> ネットワークリクエストを発生させる -> コンソールで未処理例外を確認する -> 解析または権限のエラーを修正する。

## 例

### 実践的な実装例: バックグラウンドでの取得と解析

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 1. Isolate 用のトップレベル解析関数
List<Photo> parsePhotos(String responseBody) {
  final parsed = (jsonDecode(responseBody) as List<Object?>)
      .cast<Map<String, Object?>>();
  return parsed.map<Photo>(Photo.fromJson).toList();
}

// 2. バックグラウンド解析を伴うネットワーク処理
Future<List<Photo>> fetchPhotos() async {
  final response = await http.get(
    Uri.parse('https://jsonplaceholder.typicode.com/photos'),
    headers: {
      HttpHeaders.authorizationHeader: 'Bearer your_token_here',
      HttpHeaders.acceptHeader: 'application/json',
    },
  );

  if (response.statusCode == 200) {
    // 負荷の高い解析をバックグラウンド isolate に委譲
    return compute(parsePhotos, response.body);
  } else {
    throw Exception('写真の読み込みに失敗しました。ステータス: ${response.statusCode}');
  }
}

// 3. 型安全なモデル
class Photo {
  final int id;
  final String title;
  final String thumbnailUrl;

  const Photo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as int,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
    );
  }
}

// 4. UI への組み込み
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key});

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  late Future<List<Photo>> _futurePhotos;

  @override
  void initState() {
    super.initState();
    // 再ビルド時に再取得しないよう、Future を一度だけ初期化
    _futurePhotos = fetchPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Photo>>(
      future: _futurePhotos,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final photos = snapshot.data!;
          return ListView.builder(
            itemCount: photos.length,
            itemBuilder: (context, index) => ListTile(
              leading: Image.network(photos[index].thumbnailUrl),
              title: Text(photos[index].title),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        
        // 既定の読み込み状態
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
```
