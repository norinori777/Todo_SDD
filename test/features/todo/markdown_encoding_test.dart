import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/markdown_parser.dart';
import 'package:todo_sdd/features/todo/note.dart';

void main() {
  test('UTF-8のMarkdownを元バイト列を保持して読み取る', () {
    final bytes = utf8.encode('#todo\n本文\n');

    final result = decodeMarkdownBytes(bytes);

    expect(
      result,
      isA<MarkdownDecodeSuccess>()
          .having((value) => value.content, 'content', '#todo\n本文\n')
          .having((value) => value.originalBytes, 'originalBytes', bytes)
          .having((value) => value.hasUtf8Bom, 'hasUtf8Bom', isFalse),
    );
  });

  test('UTF-8 BOMを認識し元バイト列に保持する', () {
    final bytes = [
      ...[0xef, 0xbb, 0xbf],
      ...utf8.encode('#todo\n'),
    ];

    final result = decodeMarkdownBytes(bytes);

    expect(
      result,
      isA<MarkdownDecodeSuccess>()
          .having((value) => value.content, 'content', '#todo\n')
          .having((value) => value.originalBytes, 'originalBytes', bytes)
          .having((value) => value.hasUtf8Bom, 'hasUtf8Bom', isTrue),
    );
  });

  test('Note上のUTF-8 BOMより後ろのfrontmatterを読み取る', () {
    final result = parseMarkdownNote(
      Note(
        id: NoteId('notes/task.md'),
        content: '\uFEFF---\ntags: todo\n---\n',
      ),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.frontmatterTags,
        'frontmatterTags',
        ['todo'],
      ),
    );
  });

  test('UTF-8以外のBOMを持つMarkdownを理由付きで除外する', () {
    final result = decodeMarkdownBytes([0xff, 0xfe, 0x23, 0x00]);

    expect(
      result,
      isA<MarkdownDecodeFailure>().having(
        (failure) => failure.reason,
        'reason',
        MarkdownDecodeFailureReason.unsupportedBom,
      ),
    );
  });

  test('不正なUTF-8を持つMarkdownを理由付きで除外する', () {
    final result = decodeMarkdownBytes([0x23, 0x74, 0xff]);

    expect(
      result,
      isA<MarkdownDecodeFailure>().having(
        (failure) => failure.reason,
        'reason',
        MarkdownDecodeFailureReason.invalidUtf8,
      ),
    );
  });

  test('frontmatterの単一tags文字列をタグとして読み取る', () {
    final note = Note(
      id: NoteId('notes/task.md'),
      content: '---\ntags: todo\n---\n本文\n',
    );

    final result = parseMarkdownNote(note);

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.frontmatterTags,
        'frontmatterTags',
        ['todo'],
      ),
    );
  });

  test('frontmatterのインラインリストを正規化して読み取る', () {
    final note = Note(
      id: NoteId('notes/task.md'),
      content: '---\ntags: ["#todo", "仕事/会議"]\n---\n本文\n',
    );

    final result = parseMarkdownNote(note);

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.frontmatterTags,
        'frontmatterTags',
        ['todo', '仕事/会議'],
      ),
    );
  });

  test('frontmatterの複数行リストと空リストを読み取る', () {
    final multipleTags = parseMarkdownNote(
      Note(
        id: NoteId('notes/task.md'),
        content: '---\ntags:\n  - todo\n  - "仕事/会議"\n---\n',
      ),
    );
    final emptyTags = parseMarkdownNote(
      Note(id: NoteId('notes/empty.md'), content: '---\ntags: []\n---\n'),
    );

    expect(
      multipleTags,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.frontmatterTags,
        'frontmatterTags',
        ['todo', '仕事/会議'],
      ),
    );
    expect(
      emptyTags,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.frontmatterTags,
        'frontmatterTags',
        isEmpty,
      ),
    );
  });

  test('不正YAMLと文字列以外を含むtagsリストを除外する', () {
    final invalidYaml = parseMarkdownNote(
      Note(id: NoteId('notes/invalid.md'), content: '---\ntags: [todo\n---\n'),
    );
    final invalidTags = parseMarkdownNote(
      Note(
        id: NoteId('notes/invalid-tags.md'),
        content: '---\ntags: [todo, 123]\n---\n',
      ),
    );

    expect(invalidYaml, isA<MarkdownParseFailure>());
    expect(invalidTags, isA<MarkdownParseFailure>());
  });
}
