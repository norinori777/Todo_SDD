import 'dart:io';

import 'package:flutter/services.dart';

import '../settings/folder_access.dart';
import 'folder_reader.dart';
import 'note.dart';

class AndroidFolderAccessSource implements FolderAccessSource {
  static const _channel = MethodChannel('todo_sdd/folder_access');

  Future<void> persistFolder(Uri uri) =>
      _channel.invokeMethod<void>('persistFolder', uri.toString());

  @override
  Future<FolderAccess> currentFolder() async {
    final uri = await _channel.invokeMethod<String>('getFolder');
    if (uri == null) {
      return const FolderUnavailable(FolderUnavailableReason.notConfigured);
    }

    final bool? hasAccess;
    try {
      hasAccess = await _channel.invokeMethod<bool>('hasAccess', uri);
    } on PlatformException catch (error) {
      if (error.code != 'permission_denied') rethrow;
      return const FolderUnavailable(FolderUnavailableReason.permissionDenied);
    }
    if (hasAccess == null) {
      throw PlatformException(
        code: 'invalid_response',
        message: 'フォルダーの権限状態を取得できませんでした',
      );
    }
    if (!hasAccess) {
      return const FolderUnavailable(FolderUnavailableReason.expired);
    }
    return FolderAvailable(Uri.parse(uri));
  }
}

class AndroidFolderReader {
  static const _channel = MethodChannel('todo_sdd/folder_access');

  Future<FolderReadResult> read(Uri uri) async {
    final Map<String, Object?>? response;
    try {
      response = await _channel.invokeMapMethod<String, Object?>(
        'readFolder',
        uri.toString(),
      );
    } on PlatformException catch (error) {
      if (error.code != 'read_failed' && error.code != 'permission_denied') {
        rethrow;
      }
      return FolderReadError(
        FileSystemException(error.message ?? error.code, uri.toString()),
      );
    }
    if (response == null ||
        response['notes'] is! List ||
        response['failures'] is! List) {
      throw const FormatException('Androidフォルダーの読込結果が不正です');
    }
    final rawNotes = response['notes'] as List;
    final rawFailures = response['failures'] as List;
    final notes = <ReadNote>[];
    final failures = <FolderReadFailure>[];
    for (final item in rawNotes) {
      if (item is! Map ||
          item['path'] is! String ||
          item['content'] is! String) {
        throw const FormatException('Androidノートの読込結果が不正です');
      }
      final path = item['path'] as String;
      try {
        notes.add(ReadNote(NoteId(path), item['content'] as String));
      } on ArgumentError catch (error) {
        failures.add(FolderReadFailure(path, error));
      }
    }
    for (final item in rawFailures) {
      if (item is! Map ||
          item['path'] is! String ||
          item['message'] is! String) {
        throw const FormatException('Androidの個別失敗が不正です');
      }
      final path = item['path'] as String;
      failures.add(
        FolderReadFailure(
          path,
          FileSystemException(item['message'] as String, path),
        ),
      );
    }
    return FolderReadSuccess(notes, failures);
  }
}
