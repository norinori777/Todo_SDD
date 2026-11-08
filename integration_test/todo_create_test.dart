import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_sdd/features/todo/android_folder_reader.dart';
import 'package:todo_sdd/features/todo/android_todo_writer.dart';
import 'package:todo_sdd/features/todo/folder_reader.dart';
import 'package:todo_sdd/features/todo/todo_create_repository.dart';

const _channel = MethodChannel('todo_sdd/folder_access');
const _testFolderDocumentId =
    'primary:Documents/TodoSdd_IntegrationTest_20261102';
final _testFolderUri = Uri.parse(
  'content://com.android.externalstorage.documents/tree/${Uri.encodeComponent(_testFolderDocumentId)}',
);
const _testMode = String.fromEnvironment('todoCreateTestMode');

Future<Uri> _ensureTestFolderAccess() async {
  final hasAccess = await _channel.invokeMethod<bool>(
    'hasAccess',
    _testFolderUri.toString(),
  );
  if (hasAccess == true) return _testFolderUri;

  final selected = await _channel.invokeMethod<String>(
    'pickTestFolder',
    _testFolderDocumentId,
  );
  if (selected != _testFolderUri.toString()) {
    throw StateError('指定したSAFテストフォルダーを選択できませんでした');
  }
  return _testFolderUri;
}

Future<PlatformException> _expectInjectedFailure({
  required Uri folder,
  required String fileName,
  required String failure,
}) async {
  try {
    await _channel.invokeMapMethod<String, String>('testCreateMarkdown', {
      'uri': folder.toString(),
      'name': fileName,
      'content': '#todo\nテスト用の失敗注入\n',
      'failure': failure,
    });
  } on PlatformException catch (error) {
    return error;
  }
  throw StateError('失敗注入 "$failure" が成功として返されました');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (_testMode == 'permission-selection') {
    testWidgets('選択した保存先の読取・書込権限を永続化する', (tester) async {
      await _channel.invokeMethod<void>(
        'releaseTestFolder',
        _testFolderUri.toString(),
      );
      final selected = await _channel.invokeMethod<String>(
        'pickTestFolder',
        _testFolderDocumentId,
      );

      expect(selected, _testFolderUri.toString());
      expect(await _channel.invokeMethod<bool>('hasAccess', selected), isTrue);
      expect(
        await AndroidFolderReader().read(_testFolderUri),
        isA<FolderReadSuccess>(),
      );
    });
  } else if (_testMode == 'permission-restart') {
    testWidgets('アプリ再起動後も永続権限から保存先を読み取れる', (tester) async {
      expect(
        await _channel.invokeMethod<bool>(
          'hasAccess',
          _testFolderUri.toString(),
        ),
        isTrue,
      );
      expect(
        await AndroidFolderReader().read(_testFolderUri),
        isA<FolderReadSuccess>(),
      );
    });
  } else {
    testWidgets('選択した保存先の読取・書込権限を永続化する', (tester) async {
      await _channel.invokeMethod<void>(
        'releaseTestFolder',
        _testFolderUri.toString(),
      );
      final selected = await _channel.invokeMethod<String>(
        'pickTestFolder',
        _testFolderDocumentId,
      );

      expect(selected, _testFolderUri.toString());
      expect(await _channel.invokeMethod<bool>('hasAccess', selected), isTrue);
      expect(
        await AndroidFolderReader().read(_testFolderUri),
        isA<FolderReadSuccess>(),
      );
    });

    testWidgets('SAF直下にUTF-8 Markdownを作り相対パスを返す', (tester) async {
      final folder = await _ensureTestFolderAccess();
      final fileName =
          'todo_create_test_${DateTime.now().microsecondsSinceEpoch}.md';
      const content = '#todo\n日本語の実機作成テスト\n';

      final relativePath = await AndroidTodoWriter().createMarkdown(
        folder,
        fileName,
        content,
      );

      expect(relativePath, fileName);
      final readResult = await AndroidFolderReader().read(folder);
      expect(readResult, isA<FolderReadSuccess>());
      expect(
        (readResult as FolderReadSuccess).notes
            .singleWhere((note) => note.id.relativePath == fileName)
            .content,
        content,
      );
    });

    testWidgets('直下の同名Documentを上書きせず競合として返す', (tester) async {
      final folder = await _ensureTestFolderAccess();
      final fileName =
          'todo_create_collision_${DateTime.now().microsecondsSinceEpoch}.md';
      const originalContent = '#todo\n変更してはいけない元データ\n';
      final writer = AndroidTodoWriter();

      await writer.createMarkdown(folder, fileName, originalContent);
      await expectLater(
        writer.createMarkdown(folder, fileName, '#todo\n上書きしてはいけない\n'),
        throwsA(
          isA<TodoWriterException>().having(
            (error) => error.code,
            'code',
            TodoWriterErrorCode.alreadyExists,
          ),
        ),
      );

      final readResult = await AndroidFolderReader().read(folder);
      expect(readResult, isA<FolderReadSuccess>());
      expect(
        (readResult as FolderReadSuccess).notes
            .singleWhere((note) => note.id.relativePath == fileName)
            .content,
        originalContent,
      );
    });

    testWidgets('不正な提供元と相対パス名を拒否する', (tester) async {
      final folder = await _ensureTestFolderAccess();
      final writer = AndroidTodoWriter();

      await expectLater(
        writer.createMarkdown(
          Uri.parse('content://unsupported.documents/tree/primary%3ADocuments'),
          'invalid.md',
          '#todo\n',
        ),
        throwsA(
          isA<TodoWriterException>().having(
            (error) => error.code,
            'code',
            TodoWriterErrorCode.unsupportedProvider,
          ),
        ),
      );
      await expectLater(
        writer.createMarkdown(folder, '../outside.md', '#todo\n'),
        throwsA(
          isA<TodoWriterException>().having(
            (error) => error.code,
            'code',
            TodoWriterErrorCode.invalidName,
          ),
        ),
      );
    });

    testWidgets('永続権限が失効した保存先への作成を拒否する', (tester) async {
      final folder = await _ensureTestFolderAccess();
      await _channel.invokeMethod<void>('releaseTestFolder', folder.toString());

      await expectLater(
        AndroidTodoWriter().createMarkdown(
          folder,
          'todo_create_revoked.md',
          '#todo\n',
        ),
        throwsA(
          isA<TodoWriterException>().having(
            (error) => error.code,
            'code',
            TodoWriterErrorCode.permissionDenied,
          ),
        ),
      );
    });

    testWidgets('open/write/close失敗と別名作成時は今回のDocumentだけを削除する', (tester) async {
      final folder = await _ensureTestFolderAccess();
      final sentinelName =
          'todo_create_cleanup_sentinel_${DateTime.now().microsecondsSinceEpoch}.md';
      const sentinelContent = '#todo\n保持する既存データ\n';
      await AndroidTodoWriter().createMarkdown(
        folder,
        sentinelName,
        sentinelContent,
      );

      for (final failure in ['open', 'write', 'close', 'renamed']) {
        final fileName =
            'todo_create_${failure}_failure_${DateTime.now().microsecondsSinceEpoch}.md';
        final error = await _expectInjectedFailure(
          folder: folder,
          fileName: fileName,
          failure: failure,
        );
        expect(
          error.code,
          failure == 'renamed' ? 'already_exists' : 'write_failed',
        );

        final readResult = await AndroidFolderReader().read(folder);
        expect(readResult, isA<FolderReadSuccess>());
        final notes = (readResult as FolderReadSuccess).notes;
        expect(notes.any((note) => note.id.relativePath == fileName), isFalse);
        expect(
          notes
              .singleWhere((note) => note.id.relativePath == sentinelName)
              .content,
          sentinelContent,
        );
      }
    });

    testWidgets('後始末失敗時は残存Documentの相対パスを返す', (tester) async {
      final folder = await _ensureTestFolderAccess();
      final fileName =
          'todo_create_cleanup_residual_${DateTime.now().microsecondsSinceEpoch}.md';
      final error = await _expectInjectedFailure(
        folder: folder,
        fileName: fileName,
        failure: 'cleanup',
      );

      expect(error.code, 'write_failed');
      expect(error.message, contains(fileName));
      expect(error.details, containsPair('residualPath', fileName));

      final readResult = await AndroidFolderReader().read(folder);
      expect(readResult, isA<FolderReadSuccess>());
      expect(
        (readResult as FolderReadSuccess).notes.any(
          (note) => note.id.relativePath == fileName,
        ),
        isTrue,
      );
    });
  }
}
