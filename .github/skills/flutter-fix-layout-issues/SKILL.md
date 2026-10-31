---
name: flutter-fix-layout-issues
description: Dart および Flutter MCP ツールを使って、Flutter のレイアウトエラー（オーバーフロー、上限のない制約）を修正します。「RenderFlex overflowed」「Vertical viewport was given unbounded height」などのレイアウト問題に対処する場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 19:45:59 GMT
---
# Flutter レイアウトエラーの解決

## 目次
- [制約違反の診断](#制約違反の診断)
- [レイアウトエラー解決のワークフロー](#レイアウトエラー解決のワークフロー)
- [例](#例)

## 制約違反の診断

Flutter のレイアウトは、次の厳密なルールに基づいています。**制約は親から子へ、サイズは子から親へ、位置は親が決めます。** この調整が失敗するとレイアウトエラーが発生します。多くの場合、制約が無制限であるか、子ウィジェットに制約がないことが原因です。

次のエラーメッセージを手がかりに、レイアウト失敗を診断します。

*   **"Vertical viewport was given unbounded height"**: スクロール可能なウィジェット（`ListView`、`GridView`）を、制約のない垂直方向の親（`Column`）内に配置すると発生します。親が無限の高さを渡し、子が無限に広がろうとします。
*   **"An InputDecorator...cannot have an unbounded width"**: `TextField` または `TextFormField` を、制約のない水平方向の親（`Row`）内に配置すると発生します。テキストフィールドが、無限に利用できる領域を基に幅を決めようとします。
*   **"RenderFlex overflowed"**: `Row` または `Column` の子が、親から割り当てられた制約を超えるサイズを要求すると発生します。画面上では黄色と黒の警告ストライプで示されます。
*   **"Incorrect use of ParentData widget"**: `ParentDataWidget` が必要な祖先ウィジェットの直接の子孫でない場合に発生します（例: `Flex` の外にある `Expanded`、`Stack` の外にある `Positioned`）。
*   **"RenderBox was not laid out"**: 連鎖的に発生する二次エラーです。このエラーは無視して、スタックトレースをさかのぼり、根本的な制約違反（通常は高さまたは幅が無制限であるエラー）を探してください。

## レイアウトエラー解決のワークフロー

レイアウト制約違反を体系的に解決するには、このチェックリストをコピーして使用します。

### 作業の進捗
- [ ] アプリケーションをデバッグモードで実行し、正確なレイアウト例外をコンソールに出力する。
- [ ] 根本的なエラーメッセージを特定する（連鎖して発生した「RenderBox was not laid out」エラーは無視する）。
- [ ] エラーの種類に応じて修正方法を適用する。
  - **「Vertical viewport was given unbounded height」の場合:** スクロール可能な子（`ListView`、`GridView`）を `Expanded` で囲んで残りの領域を使うか、`SizedBox` で囲んで固定の高さ制約を与えます。
  - **「An InputDecorator...cannot have an unbounded width」の場合:** `TextField` または `TextFormField` を `Expanded` または `Flexible` で囲みます。
  - **「RenderFlex overflowed」の場合:** オーバーフローする子を `Expanded` で囲んで収まるようにするか、`Flexible` で囲んで割り当てられた領域より小さくできるように制約します。
  - **「Incorrect use of ParentData widget」の場合:** `ParentDataWidget` を必要な親の直接の子に移動します。`Expanded`／`Flexible` が `Row`／`Column`／`Flex` の直接の子であること、`Positioned` が `Stack` の直接の子であることを確認します。
- [ ] Flutter のホットリロードを実行する。
- [ ] バリデーターを実行 -> エラーを確認 -> 修正する: UI を調べ、赤／灰色のエラー画面や黄色／黒のオーバーフローストライプが解消されたことを確認します。新しいレイアウトエラーが発生した場合は、ワークフローを繰り返します。

## 例

### 高さの制約がない場合の修正（Column 内の ListView）

**入力（エラー状態）:**
```dart
// 「Vertical viewport was given unbounded height」が発生する
Column(
  children: <Widget>[
    const Text('ヘッダー'),
    ListView(
      children: const <Widget>[
        ListTile(title: Text('項目 1')),
        ListTile(title: Text('項目 2')),
      ],
    ),
  ],
)
```

**出力（解決後）:**
```dart
// ListView を Expanded で囲み、Column 内の残り領域に高さを制限する
Column(
  children: <Widget>[
    const Text('ヘッダー'),
    Expanded(
      child: ListView(
        children: const <Widget>[
          ListTile(title: Text('項目 1')),
          ListTile(title: Text('項目 2')),
        ],
      ),
    ),
  ],
)
```

### 幅の制約がない場合の修正（Row 内の TextField）

**入力（エラー状態）:**
```dart
// 「An InputDecorator...cannot have an unbounded width」が発生する
Row(
  children: [
    const Icon(Icons.search),
    TextField(), 
  ],
)
```

**出力（解決後）:**
```dart
// TextField を Expanded で囲み、Row 内の残り領域に幅を制限する
Row(
  children: [
    const Icon(Icons.search),
    Expanded(
      child: TextField(),
    ),
  ],
)
```

### RenderFlex のオーバーフローを修正する

**入力（エラー状態）:**
```dart
// 「A RenderFlex overflowed by X pixels on the right」が発生する
Row(
  children: [
    const Icon(Icons.info),
    const Text('このテキストは非常に長いため、画面の利用可能な幅を確実に超え、RenderFlex エラーを引き起こします。'),
  ],
)
```

**出力（解決後）:**
```dart
// Text ウィジェットを Expanded で囲み、利用可能な制約内で折り返すようにする
Row(
  children: [
    const Icon(Icons.info),
    Expanded(
      child: const Text('このテキストは非常に長いため、画面の利用可能な幅を確実に超え、RenderFlex エラーを引き起こします。'),
    ),
  ],
)
```
