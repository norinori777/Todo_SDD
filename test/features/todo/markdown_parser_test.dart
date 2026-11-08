import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/markdown_parser.dart';
import 'package:todo_sdd/features/todo/note.dart';

void main() {
  test('本文の完全一致todoタグでTodoと判定する', () {
    final result = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '#todo\n本文\n'),
    );

    expect(result, isA<MarkdownParseSuccess>());
    expect((result as MarkdownParseSuccess).isTodo, isTrue);
  });

  test('見出しのTODO表記だけではTodoと判定しない', () {
    final result = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '# TODO\n'),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('インラインコード内のtodo表記をタグとして判定しない', () {
    final result = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '`#todo`\n'),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('フェンス付きコードブロック内のtodo表記をタグとして判定しない', () {
    final result = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '```md\n#todo\n```\n'),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('エスケープされたtodo表記をタグとして判定しない', () {
    final result = parseMarkdownNote(
      Note(
        id: NoteId('notes/task.md'),
        content:
            r'\#todo'
            '\n',
      ),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('HTMLコメント内のtodo表記をタグとして判定しない', () {
    final result = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '<!-- #todo -->\n'),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('HTML属性内のtodo表記は除外し要素内の表示文字は判定する', () {
    final attributeOnly = parseMarkdownNote(
      Note(
        id: NoteId('notes/task.md'),
        content: '<div data-tag="#todo">text</div>\n',
      ),
    );
    final visibleText = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '<div>#todo</div>\n'),
    );

    expect(
      attributeOnly,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
    expect(
      visibleText,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isTrue,
      ),
    );
  });

  test('Wikiリンクのリンク先は除外し表示文字のタグは判定する', () {
    final linkTarget = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '[[#todo]]\n'),
    );
    final displayText = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '[[note|#todo]]\n'),
    );

    expect(
      linkTarget,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
    expect(
      displayText,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isTrue,
      ),
    );
  });

  test('通常リンクのリンク先は除外し表示文字のタグは判定する', () {
    final linkTarget = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '[label](#todo)\n'),
    );
    final displayText = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '[#todo](note.md)\n'),
    );

    expect(
      linkTarget,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
    expect(
      displayText,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isTrue,
      ),
    );
  });

  test('URL内のtodo表記をタグとして判定しない', () {
    final result = parseMarkdownNote(
      Note(
        id: NoteId('notes/task.md'),
        content: 'https://example.test/?tag=#todo\n',
      ),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('参照形式リンクの定義先をタグとして判定しない', () {
    final result = parseMarkdownNote(
      Note(
        id: NoteId('notes/task.md'),
        content: '[label][target]\n\n[target]: #todo\n',
      ),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('タグ名の区切りと直前文字の条件を適用する', () {
    final cases = <String, bool>{
      '#todo,': true,
      '#todo作業': false,
      '#todo-作業': false,
      '文章#todo': false,
      '（#todo）': true,
      '文章。#todo': true,
      '作業-#todo': false,
      '作業/#todo': false,
    };

    for (final entry in cases.entries) {
      final result = parseMarkdownNote(
        Note(id: NoteId('notes/task.md'), content: entry.key),
      );
      expect(
        result,
        isA<MarkdownParseSuccess>().having(
          (parsed) => parsed.isTodo,
          entry.key,
          entry.value,
        ),
      );
    }
  });

  test('階層の子タグだけではTodoと判定しない', () {
    final result = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '#todo/子\n'),
    );

    expect(
      result,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });

  test('Unicodeの直前文字と結合文字を含むタグ境界を守る', () {
    final attachedToWord = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '文章#todo\n'),
    );
    final afterPunctuation = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '文章。#todo\n'),
    );
    final combiningMark = parseMarkdownNote(
      Note(id: NoteId('notes/task.md'), content: '#todo\u0301\n'),
    );

    expect(
      attachedToWord,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
    expect(
      afterPunctuation,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isTrue,
      ),
    );
    expect(
      combiningMark,
      isA<MarkdownParseSuccess>().having(
        (parsed) => parsed.isTodo,
        'isTodo',
        isFalse,
      ),
    );
  });
}
