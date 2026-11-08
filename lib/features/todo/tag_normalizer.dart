import 'package:flutter/services.dart';

class TagNormalizer {
  const TagNormalizer({
    this.channel = const MethodChannel('todo_sdd/folder_access'),
  });

  final MethodChannel channel;

  Future<List<String>> normalize(List<String> tags) async {
    final result = await channel.invokeListMethod<Object?>(
      'normalizeNfc',
      tags,
    );
    if (result == null || result.length != tags.length) {
      throw const FormatException('タグ正規化の結果が不正です');
    }
    final normalized = <String>[];
    for (final tag in result) {
      if (tag is! String) {
        throw const FormatException('タグ正規化の結果に文字列以外が含まれています');
      }
      normalized.add(tag);
    }
    return List<String>.unmodifiable(normalized);
  }
}
