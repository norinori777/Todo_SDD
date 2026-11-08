import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'note.dart';

sealed class MarkdownDecodeResult {
  const MarkdownDecodeResult();
}

class MarkdownDecodeSuccess extends MarkdownDecodeResult {
  const MarkdownDecodeSuccess({
    required this.content,
    required this.originalBytes,
    required this.hasUtf8Bom,
  });

  final String content;
  final List<int> originalBytes;
  final bool hasUtf8Bom;
}

class MarkdownDecodeFailure extends MarkdownDecodeResult {
  const MarkdownDecodeFailure(this.reason);

  final MarkdownDecodeFailureReason reason;
}

enum MarkdownDecodeFailureReason { unsupportedBom, invalidUtf8 }

MarkdownDecodeResult decodeMarkdownBytes(List<int> bytes) {
  final hasUtf8Bom = _startsWith(bytes, const [0xef, 0xbb, 0xbf]);
  if (!hasUtf8Bom &&
      (_startsWith(bytes, const [0x00, 0x00, 0xfe, 0xff]) ||
          _startsWith(bytes, const [0xff, 0xfe, 0x00, 0x00]) ||
          _startsWith(bytes, const [0xfe, 0xff]) ||
          _startsWith(bytes, const [0xff, 0xfe]))) {
    return const MarkdownDecodeFailure(
      MarkdownDecodeFailureReason.unsupportedBom,
    );
  }

  try {
    final content = utf8.decode(hasUtf8Bom ? bytes.skip(3).toList() : bytes);
    return MarkdownDecodeSuccess(
      content: content,
      originalBytes: List<int>.unmodifiable(bytes),
      hasUtf8Bom: hasUtf8Bom,
    );
  } on FormatException {
    return const MarkdownDecodeFailure(MarkdownDecodeFailureReason.invalidUtf8);
  }
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) return false;
  }
  return true;
}

sealed class MarkdownParseResult {
  const MarkdownParseResult();
}

class MarkdownParseSuccess extends MarkdownParseResult {
  const MarkdownParseSuccess(this.frontmatterTags, {this.bodyTags = const []});

  final List<String> frontmatterTags;
  final List<String> bodyTags;

  List<String> get tags => [...frontmatterTags, ...bodyTags];

  bool get isTodo => tags.contains('todo');
}

class MarkdownParseFailure extends MarkdownParseResult {
  const MarkdownParseFailure(this.reason);

  final String reason;
}

MarkdownParseResult parseMarkdownNote(Note note) {
  final content = note.content.startsWith('\uFEFF')
      ? note.content.substring(1)
      : note.content;
  final lines = content.split(RegExp(r'\r\n|\n|\r'));
  var frontmatterTags = <String>[];
  var bodyStart = 0;
  if (lines.isNotEmpty && lines.first == '---') {
    final closingIndex = lines.indexOf('---', 1);
    if (closingIndex < 0) {
      return const MarkdownParseFailure('frontmatterの終了区切りがありません');
    }

    final Object? metadata;
    try {
      metadata = loadYaml(lines.sublist(1, closingIndex).join('\n'));
    } on YamlException catch (error) {
      return MarkdownParseFailure('frontmatterのYAMLが不正です: $error');
    }
    if (metadata is! Map) {
      return const MarkdownParseFailure('frontmatterはマップ形式ではありません');
    }
    if (metadata.containsKey('tags')) {
      final Object? rawTags = metadata['tags'];
      if (rawTags is String) {
        frontmatterTags = [_normalizeFrontmatterTag(rawTags)];
      } else if (rawTags is List && rawTags.every((tag) => tag is String)) {
        frontmatterTags = rawTags
            .cast<String>()
            .map(_normalizeFrontmatterTag)
            .toList();
      } else {
        return const MarkdownParseFailure('frontmatterのtags形式に対応していません');
      }
    }
    bodyStart = closingIndex + 1;
  }

  return MarkdownParseSuccess(
    List<String>.unmodifiable(frontmatterTags),
    bodyTags: _extractTags(lines.skip(bodyStart).join('\n')),
  );
}

String _normalizeFrontmatterTag(String tag) =>
    tag.startsWith('#') ? tag.substring(1) : tag;

List<String> _extractTags(String content) {
  final visibleContent = _maskUrls(
    _maskHtmlComments(
      _maskReferenceLinkTargets(
        _maskMarkdownLinkDestinations(
          _maskWikiLinkTargets(
            _maskHtmlTags(_maskInlineCode(_maskFencedCode(content))),
          ),
        ),
      ),
    ),
  );
  final tagName = RegExp(r'[\p{L}\p{M}\p{N}_/-]', unicode: true);
  final matches = RegExp(
    r'#([\p{L}\p{M}\p{N}_/-]+)',
    unicode: true,
  ).allMatches(visibleContent);
  final codeUnits = visibleContent.codeUnits;
  final tags = <String>[];
  for (final match in matches) {
    final start = match.start;
    if (_isEscaped(codeUnits, start)) continue;
    if (start > 0) {
      final prefix = visibleContent.substring(0, start);
      final previousRune = prefix.runes.last;
      if (tagName.hasMatch(String.fromCharCode(previousRune))) continue;
    }
    tags.add(match.group(1)!);
  }
  return List<String>.unmodifiable(tags);
}

String _maskHtmlComments(String source) {
  final codeUnits = source.codeUnits.toList();
  for (final match in RegExp(
    r'<!--.*?(?:-->|$)',
    dotAll: true,
  ).allMatches(source)) {
    _maskRange(codeUnits, match.start, match.end);
  }
  return String.fromCharCodes(codeUnits);
}

String _maskWikiLinkTargets(String source) {
  final codeUnits = source.codeUnits.toList();
  var index = 0;
  while (index + 1 < codeUnits.length) {
    if (codeUnits[index] != 0x5b ||
        codeUnits[index + 1] != 0x5b ||
        _isEscaped(codeUnits, index)) {
      index++;
      continue;
    }
    var close = index + 2;
    while (close + 1 < codeUnits.length &&
        !(codeUnits[close] == 0x5d && codeUnits[close + 1] == 0x5d)) {
      close++;
    }
    if (close + 1 >= codeUnits.length) {
      index += 2;
      continue;
    }
    var separator = index + 2;
    while (separator < close && codeUnits[separator] != 0x7c) {
      separator++;
    }
    final end = separator < close ? separator + 1 : close + 2;
    _maskRange(codeUnits, index, end);
    index = end;
  }
  return String.fromCharCodes(codeUnits);
}

String _maskMarkdownLinkDestinations(String source) {
  final codeUnits = source.codeUnits.toList();
  var index = 0;
  while (index < codeUnits.length) {
    if (codeUnits[index] != 0x5b || _isEscaped(codeUnits, index)) {
      index++;
      continue;
    }

    var closeBracket = index + 1;
    var bracketDepth = 1;
    while (closeBracket < codeUnits.length && bracketDepth > 0) {
      if (_isEscaped(codeUnits, closeBracket)) {
        closeBracket += 2;
        continue;
      }
      if (codeUnits[closeBracket] == 0x5b) bracketDepth++;
      if (codeUnits[closeBracket] == 0x5d) bracketDepth--;
      closeBracket++;
    }
    if (bracketDepth != 0 ||
        closeBracket >= codeUnits.length ||
        codeUnits[closeBracket] != 0x28) {
      index++;
      continue;
    }

    var closeParen = closeBracket + 1;
    var parenDepth = 1;
    while (closeParen < codeUnits.length && parenDepth > 0) {
      if (_isEscaped(codeUnits, closeParen)) {
        closeParen += 2;
        continue;
      }
      if (codeUnits[closeParen] == 0x28) parenDepth++;
      if (codeUnits[closeParen] == 0x29) parenDepth--;
      closeParen++;
    }
    if (parenDepth == 0) {
      _maskRange(codeUnits, closeBracket, closeParen);
      index = closeParen;
    } else {
      index++;
    }
  }
  return String.fromCharCodes(codeUnits);
}

String _maskReferenceLinkTargets(String source) {
  final codeUnits = source.codeUnits.toList();
  for (final definition in RegExp(
    r'^[ \t]{0,3}\[[^\r\n]*?\]:[^\r\n]*',
    multiLine: true,
  ).allMatches(source)) {
    _maskRange(codeUnits, definition.start, definition.end);
  }

  var index = 0;
  while (index < codeUnits.length) {
    if (codeUnits[index] != 0x5b || _isEscaped(codeUnits, index)) {
      index++;
      continue;
    }
    var closeLabel = index + 1;
    while (closeLabel < codeUnits.length &&
        (codeUnits[closeLabel] != 0x5d || _isEscaped(codeUnits, closeLabel))) {
      closeLabel++;
    }
    if (closeLabel >= codeUnits.length) break;

    var next = closeLabel + 1;
    while (next < codeUnits.length &&
        (codeUnits[next] == 0x20 || codeUnits[next] == 0x09)) {
      next++;
    }
    if (next >= codeUnits.length || codeUnits[next] != 0x5b) {
      index = closeLabel + 1;
      continue;
    }
    var closeTarget = next + 1;
    while (closeTarget < codeUnits.length &&
        (codeUnits[closeTarget] != 0x5d ||
            _isEscaped(codeUnits, closeTarget))) {
      closeTarget++;
    }
    if (closeTarget < codeUnits.length) {
      _maskRange(codeUnits, closeLabel + 1, closeTarget + 1);
      index = closeTarget + 1;
    } else {
      index = closeLabel + 1;
    }
  }
  return String.fromCharCodes(codeUnits);
}

String _maskUrls(String source) {
  final codeUnits = source.codeUnits.toList();
  for (final match in RegExp(
    r'\b(?:https?|ftp)://[^\s<>]+',
    caseSensitive: false,
  ).allMatches(source)) {
    _maskRange(codeUnits, match.start, match.end);
  }
  return String.fromCharCodes(codeUnits);
}

String _maskHtmlTags(String source) {
  final codeUnits = source.codeUnits.toList();
  var index = 0;
  while (index < codeUnits.length) {
    if (codeUnits[index] != 0x3c) {
      index++;
      continue;
    }
    var cursor = index + 1;
    if (cursor < codeUnits.length && codeUnits[cursor] == 0x2f) cursor++;
    if (cursor >= codeUnits.length || !_isAsciiLetter(codeUnits[cursor])) {
      index++;
      continue;
    }

    int? quote;
    while (cursor < codeUnits.length) {
      final current = codeUnits[cursor];
      if ((current == 0x22 || current == 0x27) && quote == null) {
        quote = current;
      } else if (current == quote) {
        quote = null;
      } else if (current == 0x3e && quote == null) {
        _maskRange(codeUnits, index, cursor + 1);
        index = cursor + 1;
        break;
      }
      cursor++;
    }
    if (cursor >= codeUnits.length) index++;
  }
  return String.fromCharCodes(codeUnits);
}

bool _isAsciiLetter(int codeUnit) =>
    (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
    (codeUnit >= 0x61 && codeUnit <= 0x7a);

String _maskFencedCode(String source) {
  final codeUnits = source.codeUnits.toList();
  var offset = 0;
  String? fenceCharacter;
  var fenceLength = 0;
  var fenceStart = -1;

  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    final leadingSpaces = line.length - trimmed.length;
    final match = RegExp(r'^(`{3,}|~{3,})').firstMatch(trimmed);
    final closingFence = fenceCharacter == null
        ? null
        : RegExp('^${RegExp.escape(fenceCharacter)}{$fenceLength,}');
    if (fenceCharacter == null &&
        leadingSpaces <= 3 &&
        match != null &&
        (trimmed.startsWith('`') || trimmed.startsWith('~'))) {
      fenceCharacter = match.group(1)![0];
      fenceLength = match.group(1)!.length;
      fenceStart = offset;
    } else if (fenceCharacter != null &&
        leadingSpaces <= 3 &&
        closingFence!.hasMatch(trimmed)) {
      final end = offset + line.length;
      _maskRange(codeUnits, fenceStart, end);
      fenceCharacter = null;
      fenceLength = 0;
      fenceStart = -1;
    }
    offset += line.length + 1;
  }
  if (fenceStart >= 0) _maskRange(codeUnits, fenceStart, codeUnits.length);
  return String.fromCharCodes(codeUnits);
}

String _maskInlineCode(String source) {
  final codeUnits = source.codeUnits.toList();
  var index = 0;
  while (index < codeUnits.length) {
    if (codeUnits[index] != 0x60 ||
        _isEscaped(codeUnits, index) ||
        codeUnits[index] == 0x20) {
      index++;
      continue;
    }
    final delimiterLength = _runLength(codeUnits, index, 0x60);
    var closing = index + delimiterLength;
    var end = -1;
    while (closing < codeUnits.length) {
      if (codeUnits[closing] != 0x60 || _isEscaped(codeUnits, closing)) {
        closing++;
        continue;
      }
      final closingLength = _runLength(codeUnits, closing, 0x60);
      if (closingLength == delimiterLength) {
        end = closing + closingLength;
        break;
      }
      closing += closingLength;
    }
    if (end < 0) {
      index += delimiterLength;
      continue;
    }
    _maskRange(codeUnits, index, end);
    index = end;
  }
  return String.fromCharCodes(codeUnits);
}

int _runLength(List<int> codeUnits, int start, int character) {
  var end = start;
  while (end < codeUnits.length && codeUnits[end] == character) {
    end++;
  }
  return end - start;
}

bool _isEscaped(List<int> codeUnits, int index) {
  var backslashes = 0;
  for (
    var previous = index - 1;
    previous >= 0 && codeUnits[previous] == 0x5c;
    previous--
  ) {
    backslashes++;
  }
  return backslashes.isOdd;
}

void _maskRange(List<int> codeUnits, int start, int end) {
  for (var index = start; index < end; index++) {
    if (codeUnits[index] != 0x0a && codeUnits[index] != 0x0d) {
      codeUnits[index] = 0x20;
    }
  }
}
