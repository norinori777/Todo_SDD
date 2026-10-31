---
name: flutter-add-widget-test
description: `WidgetTester` を使って、UI の描画とユーザー操作（タップ、スクロール、テキスト入力）を検証するコンポーネントレベルのテストを実装します。特定のウィジェットが正しいデータを表示し、期待どおりのイベントに応答するかを検証する場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 21:15:41 GMT
---
# Flutter ウィジェットテストの記述

## 目次
- [セットアップと構成](#セットアップと構成)
- [主要なコンポーネント](#主要なコンポーネント)
- [ワークフロー: ウィジェットテストの実装](#ワークフロー-ウィジェットテストの実装)
- [操作と状態管理](#操作と状態管理)
- [例](#例)

## セットアップと構成

ウィジェットテストを書く前に、テスト環境が正しく構成されていることを確認します。

1. `pubspec.yaml` の `dev_dependencies` セクションに `flutter_test` 依存関係を追加します。
2. すべてのテストファイルをプロジェクトルートの `test/` ディレクトリに配置します。
3. すべてのテストファイル名の末尾に `_test.dart` を付けます（例: `widget_test.dart`）。

## 主要なコンポーネント

次の `flutter_test` コンポーネントを使って、ウィジェットツリーを操作し検証します。

*   **`WidgetTester`**: テスト環境でウィジェットを構築し、操作するための主要なインターフェースです。`testWidgets()` 関数から自動的に提供されます。
*   **`Finder`**: テスト環境内のウィジェットを検索します（例: `find.text('送信')`、`find.byType(TextField)`、`find.byKey(Key('submit_btn'))`）。
*   **`Matcher`**: `Finder` で見つかったウィジェットの存在や状態を検証します（例: `findsOneWidget`、`findsNothing`、`findsNWidgets(2)`、`matchesGoldenFile`）。

## ワークフロー: ウィジェットテストの実装

新しいウィジェットテストを実装する際は、次のチェックリストをコピーして進捗を記録します。

### 作業の進捗
- [ ] **ステップ 1: テストを定義する。** `testWidgets('説明', (WidgetTester tester) async { ... })` を使います。
- [ ] **ステップ 2: ウィジェットを構築する。** `await tester.pumpWidget(MyWidget())` を呼び出して UI を描画します。継承された方向情報やテーマデータが必要な場合は、ウィジェットを `MaterialApp` または `Directionality` で囲みます。
- [ ] **ステップ 3: 要素を検索する。** 対象ウィジェットを検索する `Finder` オブジェクトを作成します。
- [ ] **ステップ 4: 初期状態を検証する。** `expect(finder, matcher)` を使って初期描画を検証します。
- [ ] **ステップ 5: 操作をシミュレートする。** ジェスチャーや入力を実行します（例: `await tester.tap(buttonFinder)`）。
- [ ] **ステップ 6: ツリーを再構築する。** `await tester.pump()` または `await tester.pumpAndSettle()` を呼び出して状態変更を処理します。
- [ ] **ステップ 7: 更新後の状態を検証する。** `expect()` を使って操作後の UI を検証します。
- [ ] **ステップ 8: 実行して検証する。** `flutter test test/your_test_file_test.dart` を実行します。
- [ ] **ステップ 9: フィードバックループ。** テスト出力を確認 -> 失敗したマッチャーを特定 -> ウィジェットのロジックまたはテストアサーションを調整 -> 成功するまで再実行します。

## 操作と状態管理

テスト対象の操作または状態変更の種類に応じて、次の条件付き手順を適用します。

*   **静的な描画をテストする場合:** `await tester.pumpWidget()` を一度呼び出し、すぐに `expect()` アサーションを実行します。
*   **一般的な状態変更（例: ボタンのタップ）をテストする場合:**
    1. `await tester.tap(finder)` を呼び出します。
    2. `await tester.pump()` を呼び出し、1フレーム分の再構築を実行します。
*   **アニメーション、遷移、非同期 UI 更新をテストする場合:**
    1. 操作を実行します（例: `await tester.drag(finder, Offset(500, 0))`）。
    2. アニメーションが完了して新しいフレームがスケジュールされなくなるまで、`await tester.pumpAndSettle()` を呼び出してフレームを繰り返し処理します。
*   **テキスト入力をテストする場合:** `await tester.enterText(textFieldFinder, '入力文字列')` を呼び出します。
*   **動的なリストや長いリストの項目をテストする場合:** 対象ウィジェットが描画されてから操作できるように、`await tester.scrollUntilVisible(itemFinder, 500.0, scrollable: listFinder)` を呼び出します。

## 例

### 詳細なウィジェットテスト実装の例

**対象ウィジェット (`lib/todo_list.dart`):**
```dart
import 'package:flutter/material.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final todos = <String>[];
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(controller: controller),
            Expanded(
              child: ListView.builder(
                itemCount: todos.length,
                itemBuilder: (context, index) {
                  final todo = todos[index];
                  return Dismissible(
                    key: Key('$todo$index'),
                    onDismissed: (_) => setState(() => todos.removeAt(index)),
                    child: ListTile(title: Text(todo)),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              todos.add(controller.text);
              controller.clear();
            });
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

**テスト実装 (`test/todo_list_test.dart`):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/todo_list.dart';

void main() {
  testWidgets('ToDo 項目を追加して削除する', (WidgetTester tester) async {
    // 1. ウィジェットを構築する
    await tester.pumpWidget(const TodoList());

    // 2. 初期状態を検証する
    expect(find.byType(ListTile), findsNothing);

    // 3. TextField にテキストを入力する
    await tester.enterText(find.byType(TextField), '食料品を買う');

    // 4. 追加ボタンをタップする
    await tester.tap(find.byType(FloatingActionButton));

    // 5. 新しい状態を反映するためにウィジェットを再構築する
    await tester.pump();

    // 6. 項目が追加されたことを検証する
    expect(find.text('食料品を買う'), findsOneWidget);

    // 7. 項目をスワイプして削除する
    await tester.drag(find.byType(Dismissible), const Offset(500, 0));

    // 8. 削除アニメーションが終わるまでウィジェットを構築する
    await tester.pumpAndSettle();

    // 9. 項目が削除されたことを検証する
    expect(find.text('食料品を買う'), findsNothing);
  });
}
```
