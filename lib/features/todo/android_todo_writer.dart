import 'package:flutter/services.dart';

import 'todo_create_repository.dart';

class AndroidTodoWriter {
  static const _channel = MethodChannel('todo_sdd/folder_access');

  Future<String> createMarkdown(
    Uri folder,
    String fileName,
    String content,
  ) async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'createMarkdown',
        {
          'uri': folder.toString(),
          'name': fileName,
          'content': content,
        },
      );
      if (response == null || response['path'] is! String) {
        throw const TodoWriterException(
          TodoWriterErrorCode.writeFailed,
          '保存先から不正な作成結果が返されました。',
        );
      }
      final path = response['path'] as String;
      if (path != fileName) {
        throw TodoWriterException(
          TodoWriterErrorCode.writeFailed,
          '要求した名前と異なるファイル「$path」が作成されました。保存先で確認してください。',
          residualPath: path,
        );
      }
      return path;
    } on PlatformException catch (error) {
      final details = error.details;
      final residualPath = details is Map && details['residualPath'] is String
          ? details['residualPath'] as String
          : null;
      throw TodoWriterException(
        _errorCode(error.code),
        error.message ?? '保存先でのMarkdown作成に失敗しました（${error.code}）。',
        residualPath: residualPath,
      );
    }
  }

  TodoWriterErrorCode _errorCode(String code) => switch (code) {
    'permission_denied' => TodoWriterErrorCode.permissionDenied,
    'invalid_uri' => TodoWriterErrorCode.folderUnavailable,
    'unsupported_provider' => TodoWriterErrorCode.unsupportedProvider,
    'already_exists' => TodoWriterErrorCode.alreadyExists,
    'invalid_name' => TodoWriterErrorCode.invalidName,
    'write_failed' => TodoWriterErrorCode.writeFailed,
    _ => TodoWriterErrorCode.writeFailed,
  };
}
