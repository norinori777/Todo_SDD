import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/windows_volume_policy.dart';
import 'package:win32/win32.dart';

void main() {
  test('検証対象の固定NTFSボリュームは読み込みを許可する', () {
    expect(isVerifiedWindowsVolume(DRIVE_FIXED, 'NTFS'), isTrue);
  });

  test('ネットワークドライブや未検証ファイルシステムを拒否する', () {
    expect(isVerifiedWindowsVolume(DRIVE_REMOTE, 'NTFS'), isFalse);
    expect(isVerifiedWindowsVolume(DRIVE_FIXED, 'ReFS'), isFalse);
    expect(isVerifiedWindowsVolume(DRIVE_REMOVABLE, 'NTFS'), isFalse);
  });

  test('ボリュームGUIDが一致するファイルだけを許可する', () {
    const root = r'\\?\Volume{11111111-1111-1111-1111-111111111111}\root';
    const file = r'\\?\Volume{11111111-1111-1111-1111-111111111111}\root\a.md';
    const other = r'\\?\Volume{22222222-2222-2222-2222-222222222222}\root\a.md';

    expect(isSameWindowsVolume(root, file), isTrue);
    expect(isSameWindowsVolume(root, other), isFalse);
  });

  test('GUIDを含まないパスではボリュームの同一性を保証しない', () {
    expect(isSameWindowsVolume(r'C:\root', r'C:\root\a.md'), isFalse);
  });
}
