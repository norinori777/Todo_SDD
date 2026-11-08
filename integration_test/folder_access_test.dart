import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_sdd/features/settings/folder_access.dart';
import 'package:todo_sdd/features/todo/android_folder_reader.dart';
import 'package:todo_sdd/features/todo/folder_reader.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('未設定のAndroidフォルダーを空フォルダーと区別する', (tester) async {
    final access = await AndroidFolderAccessSource().currentFolder();

    expect(access, isA<FolderUnavailable>());
    expect(
      (access as FolderUnavailable).reason,
      FolderUnavailableReason.notConfigured,
    );
  });

  testWidgets('テスト用フォルダーを選択してサブフォルダーを再帰読込する', (tester) async {
    const channel = MethodChannel('todo_sdd/folder_access');
    const documentId = 'primary:Documents/TodoSdd_IntegrationTest_20261102';
    final selectedUri = await channel.invokeMethod<String>(
      'pickTestFolder',
      documentId,
    );
    expect(selectedUri, isNotNull);

    final uri = Uri.parse(selectedUri!);
    try {
      final hasAccess = await channel.invokeMethod<bool>(
        'hasAccess',
        selectedUri,
      );
      expect(hasAccess, isTrue);

      final result = await AndroidFolderReader().read(uri);
      expect(result, isA<FolderReadSuccess>());
      final success = result as FolderReadSuccess;
      expect(
        success.notes.map((note) => note.id.relativePath),
        contains('sub/task.md'),
      );
      expect(
        success.notes
            .singleWhere((note) => note.id.relativePath == 'sub/task.md')
            .content,
        'todo',
      );
    } finally {
      await channel.invokeMethod<void>('releaseTestFolder', selectedUri);
    }
  });

  testWidgets('権限のないURIは保存せず拒否する', (tester) async {
    final source = AndroidFolderAccessSource();

    await expectLater(
      source.persistFolder(
        Uri.parse(
          'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FUntrusted',
        ),
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'permission_denied',
        ),
      ),
    );
    final access = await source.currentFolder();
    expect(
      (access as FolderUnavailable).reason,
      FolderUnavailableReason.notConfigured,
    );
  });

  testWidgets('権限のない提供元は読み取らず全体失敗を返す', (tester) async {
    final result = await AndroidFolderReader().read(
      Uri.parse('content://ungranted/tree/example'),
    );

    expect(result, isA<FolderReadError>());
  });
}
