import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/note.dart';

void main() {
  test('ルート内の相対パスをノートの識別子にする', () {
    expect(NoteId('notes/task.md').relativePath, 'notes/task.md');
  });

  test('親ディレクトリに脱出するパスを拒否する', () {
    expect(() => NoteId('../task.md'), throwsArgumentError);
  });

  test('ルート外の絶対パスを拒否する', () {
    expect(() => NoteId('/outside/task.md'), throwsArgumentError);
  });

  test('Windows形式のルート外パスを拒否する', () {
    expect(() => NoteId(r'C:\outside\task.md'), throwsArgumentError);
  });

  test('Windows形式で親ディレクトリに脱出するパスを拒否する', () {
    expect(() => NoteId(r'..\task.md'), throwsArgumentError);
  });

  test('ルート自体をノートの識別子として拒否する', () {
    expect(() => NoteId('.'), throwsArgumentError);
  });

  test('ドライブ相対パスを拒否する', () {
    expect(() => NoteId(r'C:outside.md'), throwsArgumentError);
  });
}
