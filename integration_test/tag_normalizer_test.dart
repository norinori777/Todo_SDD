import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_sdd/features/todo/tag_normalizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AndroidのNormalizerでタグ群をNFC正規化する', (tester) async {
    final normalized = await const TagNormalizer().normalize([
      'か\u3099',
      'todo',
    ]);

    expect(normalized, ['が', 'todo']);
  });
}
