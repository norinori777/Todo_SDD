import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_sdd/features/todo/tag_normalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('todo_sdd/folder_access');

  test('タグ群をAndroid境界でNFC正規化する', () async {
    List<String>? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'normalizeNfc');
          received = List<String>.from(call.arguments as List);
          return ['が', 'todo'];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final normalized = await TagNormalizer(
      channel: channel,
    ).normalize(['か\u3099', 'todo']);

    expect(received, ['か\u3099', 'todo']);
    expect(normalized, ['が', 'todo']);
  });
}
