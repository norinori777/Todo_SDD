import 'dart:convert';

import 'package:path/path.dart' as path;

class Note {
  Note({required this.id, required this.content, List<int>? originalBytes})
    : originalBytes = List<int>.unmodifiable(
        originalBytes ?? utf8.encode(content),
      );

  final NoteId id;
  final String content;
  final List<int> originalBytes;

  String get title => path.posix.basenameWithoutExtension(id.relativePath);
}

class NoteId {
  factory NoteId(String relativePath) {
    final normalized = path.posix.normalize(relativePath);
    if (normalized == '.' ||
        path.posix.isAbsolute(normalized) ||
        path.windows.rootPrefix(relativePath).isNotEmpty ||
        RegExp(r'^[A-Za-z]:').hasMatch(relativePath) ||
        path.posix.split(normalized).first == '..' ||
        path.windows.split(path.windows.normalize(relativePath)).first ==
            '..') {
      throw ArgumentError.value(relativePath, 'relativePath', 'ルート外のパスです');
    }
    return NoteId._(normalized);
  }

  const NoteId._(this.relativePath);

  final String relativePath;
}
