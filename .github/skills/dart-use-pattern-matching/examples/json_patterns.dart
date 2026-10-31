// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// JSON 処理における Dart のパターンマッチングの例です。
/// - 多態的な JSON デシリアライズ（判別共用体）
/// - 省略可能なキーや欠落したキーを含む、ネストされた JSON の検証
library;

/// シールド階層の API レスポンスを表します。
sealed class ApiResponse {}

/// データを保持する成功時の API レスポンスです。
class SuccessResponse implements ApiResponse {
  final Map<String, dynamic> data;
  SuccessResponse(this.data);
}

/// エラーメッセージとコードを保持するエラー時の API レスポンスです。
class ErrorResponse implements ApiResponse {
  final String message;
  final int code;
  ErrorResponse(this.message, this.code);
}

/// 生の JSON マップを [ApiResponse] のサブタイプに解析します。
ApiResponse parseApiResponse(Map<String, dynamic> json) => switch (json) {
  {'status': 'ok', 'data': Map<String, dynamic> data} => SuccessResponse(data),
  {'status': 'error', 'message': String msg, 'code': int code} => ErrorResponse(
    msg,
    code,
  ),
  _ => throw FormatException('無効または認識できない API レスポンス: $json'),
};

/// 必須スキーマと省略可能なキーを含む、ネストされたユーザーペイロードを検証します。
void processUserPayload(Map<String, dynamic> json) {
  if (json case {
    'id': String id,
    'profile':
        {'name': String name, 'email': String email} &&
        final Map<String, dynamic> profile,
    'tags': [String primaryTag, ...], // 1 要素以上に一致し、残りの要素は無視します。
  }) {
    // 検証済みのサブマップから、省略可能または欠落しているフィールドを直接読み取ります。
    // Map パターンはキーの存在（containsKey）を確認するため、String? 型であっても
    // キーが省略されている場合はパターンマッチに失敗します。
    final avatarUrl = profile['avatarUrl'] as String?;
    print('ユーザー $name（$id、$email、アバター: $avatarUrl）- 主なタグ: $primaryTag');
  } else {
    throw FormatException('ユーザーペイロードの構造が不正です: $json');
  }
}

void main() {
  // 多態的なデシリアライズをテストします。
  final success = parseApiResponse({
    'status': 'ok',
    'data': {'userId': '123'},
  });
  print('成功レスポンスの解析結果: $success');

  final error = parseApiResponse({
    'status': 'error',
    'message': 'Not found',
    'code': 404,
  });
  print('エラーレスポンスの解析結果: $error');

  // ネストされたデータの検証をテストします。
  processUserPayload({
    'id': 'u100',
    'profile': {
      'name': 'Alice',
      'email': 'alice@example.com',
      'avatarUrl': 'https://example.com/avatar.png',
    },
    'tags': ['admin', 'staff'],
  });
}
