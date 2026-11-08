import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/settings/folder_access.dart';
import 'package:todo_sdd/features/todo/folder_access.dart';

class FakeFolderAccessSource implements FolderAccessSource {
  FakeFolderAccessSource(this.access);

  final FolderAccess access;

  @override
  Future<FolderAccess> currentFolder() async => access;
}

void main() {
  test('利用可能なフォルダーのURIを返す', () async {
    final uri = Uri.parse('content://provider/tree/example');
    final source = FakeFolderAccessSource(FolderAvailable(uri));

    expect(await requireFolderAccess(source), uri);
  });

  test('未設定フォルダーを空フォルダーと区別する', () async {
    final source = FakeFolderAccessSource(
      const FolderUnavailable(FolderUnavailableReason.notConfigured),
    );

    await expectLater(
      () => requireFolderAccess(source),
      throwsA(
        isA<FolderAccessException>().having(
          (error) => error.reason,
          'reason',
          FolderUnavailableReason.notConfigured,
        ),
      ),
    );
  });

  test('失効したフォルダーの理由を保持する', () async {
    final source = FakeFolderAccessSource(
      const FolderUnavailable(FolderUnavailableReason.expired),
    );

    await expectLater(
      () => requireFolderAccess(source),
      throwsA(
        isA<FolderAccessException>().having(
          (error) => error.reason,
          'reason',
          FolderUnavailableReason.expired,
        ),
      ),
    );
  });

  test('権限不足のフォルダーの理由を保持する', () async {
    final source = FakeFolderAccessSource(
      const FolderUnavailable(FolderUnavailableReason.permissionDenied),
    );

    await expectLater(
      () => requireFolderAccess(source),
      throwsA(
        isA<FolderAccessException>().having(
          (error) => error.reason,
          'reason',
          FolderUnavailableReason.permissionDenied,
        ),
      ),
    );
  });
}
