import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/note.dart';

void main() {
  test('ノートのタイトルには見出しでなく拡張子を除くファイル名を使う', () {
    final note = Note(
      id: NoteId('notes/file-name.md'),
      content: '# Markdown heading\n本文\n',
    );

    expect(note.title, 'file-name');
  });

  test('同名ノートを別識別子で保持し元の内容を変更しない', () {
    const source = '\uFEFF---\ntags: [todo]\n---\n# 見出し\n本文\n';
    final first = Note(id: NoteId('first/task.md'), content: source);
    final second = Note(id: NoteId('second/task.md'), content: source);

    expect(first.title, 'task');
    expect(second.title, 'task');
    expect(first.id, isNot(second.id));
    expect(first.content, source);
  });
}
