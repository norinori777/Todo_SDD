import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/settings/folder_access.dart';
import 'package:todo_sdd/features/todo/android_folder_reader.dart';
import 'package:todo_sdd/features/todo/folder_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('todo_sdd/folder_access');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('保存済みURIの永続読取権限があれば利用可能として返す', () async {
    const saved = 'content://provider/tree/example';
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return saved;
        case 'hasAccess':
          expect(call.arguments, saved);
          return true;
        default:
          throw MissingPluginException();
      }
    });

    final access = await AndroidFolderAccessSource().currentFolder();

    expect(access, isA<FolderAvailable>());
    expect((access as FolderAvailable).uri, Uri.parse(saved));
  });

  test('永続読取権限が失効した場合は空結果ではなく失効を返す', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getFolder':
          return 'content://provider/tree/example';
        case 'hasAccess':
          return false;
        default:
          throw MissingPluginException();
      }
    });

    final access = await AndroidFolderAccessSource().currentFolder();

    expect(access, isA<FolderUnavailable>());
    expect(
      (access as FolderUnavailable).reason,
      FolderUnavailableReason.expired,
    );
  });

  test('権限確認が拒否された場合は権限不足として返す', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getFolder') {
        return 'content://provider/tree/example';
      }
      throw PlatformException(code: 'permission_denied', message: '権限不足');
    });

    final access = await AndroidFolderAccessSource().currentFolder();

    expect(access, isA<FolderUnavailable>());
    expect(
      (access as FolderUnavailable).reason,
      FolderUnavailableReason.permissionDenied,
    );
  });

  test('選択済みフォルダーのURIを永続権限付きで保存する', () async {
    const saved = 'content://provider/tree/example';
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await AndroidFolderAccessSource().persistFolder(Uri.parse(saved));

    expect(calls, hasLength(1));
    expect(calls.single.method, 'persistFolder');
    expect(calls.single.arguments, saved);
  });

  test('Android提供元の空フォルダーを空の成功として返す', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readFolder');
      return <String, Object>{'notes': <Object>[], 'failures': <Object>[]};
    });

    final result = await AndroidFolderReader().read(
      Uri.parse('content://provider/tree/example'),
    );

    expect(result, isA<FolderReadSuccess>());
    expect((result as FolderReadSuccess).notes, isEmpty);
    expect(result.failures, isEmpty);
  });

  test('Android提供元のサブフォルダーにあるMarkdownの内容を返す', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object>{
        'notes': [
          {'path': 'sub/task.md', 'content': '#todo'},
        ],
        'failures': <Object>[],
      };
    });

    final result =
        await AndroidFolderReader().read(
              Uri.parse('content://provider/tree/example'),
            )
            as FolderReadSuccess;

    expect(result.notes.single.id.relativePath, 'sub/task.md');
    expect(result.notes.single.content, '#todo');
  });

  test('Android提供元の個別失敗を読み取れたノートと共に返す', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object>{
        'notes': [
          {'path': 'good.md', 'content': '#todo'},
        ],
        'failures': [
          {'path': 'bad.md', 'message': '読み取りを拒否されました'},
        ],
      };
    });

    final result =
        await AndroidFolderReader().read(
              Uri.parse('content://provider/tree/example'),
            )
            as FolderReadSuccess;

    expect(result.notes.single.id.relativePath, 'good.md');
    expect(result.failures.single.path, 'bad.md');
    expect(result.failures.single.cause.toString(), contains('読み取りを拒否されました'));
  });

  test('Android提供元全体の読込失敗を空成功にしない', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'read_failed', message: '権限がありません');
    });

    final result = await AndroidFolderReader().read(
      Uri.parse('content://provider/tree/example'),
    );

    expect(result, isA<FolderReadError>());
    expect((result as FolderReadError).cause.message, contains('権限がありません'));
  });

  test('Android提供元の不正な識別子を個別失敗として扱う', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object>{
        'notes': [
          {'path': 'good.md', 'content': '#todo'},
          {'path': '../outside.md', 'content': '#todo'},
        ],
        'failures': <Object>[],
      };
    });

    final result =
        await AndroidFolderReader().read(
              Uri.parse('content://provider/tree/example'),
            )
            as FolderReadSuccess;

    expect(result.notes.single.id.relativePath, 'good.md');
    expect(result.failures.single.path, '../outside.md');
    expect(result.failures.single.cause, isA<ArgumentError>());
  });
}
