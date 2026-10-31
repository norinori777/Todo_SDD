---
name: flutter-build-responsive-layout
description: `LayoutBuilder`、`MediaQuery`、`Expanded` / `Flexible` を使用して、さまざまな画面サイズに適応するレイアウトを作成します。モバイルとタブレット／デスクトップの両方で UI を適切に表示する必要がある場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 20:17:40 GMT
---
# アダプティブレイアウトの実装

## 目次
- [利用可能な領域の測定ガイドライン](#利用可能な領域の測定ガイドライン)
- [ウィジェットのサイズと制約](#ウィジェットのサイズと制約)
- [デバイスと画面の向きに関する動作](#デバイスと画面の向きに関する動作)
- [ワークフロー: アダプティブレイアウトの構築](#ワークフロー-アダプティブレイアウトの構築)
- [ワークフロー: 大画面向けの最適化](#ワークフロー-大画面向けの最適化)
- [例](#例)

## 利用可能な領域の測定ガイドライン
レイアウトが物理デバイスではなくアプリウィンドウに適応するよう、利用可能な領域を正確に把握します。

*   **アプリウィンドウ全体のサイズを取得するには `MediaQuery.sizeOf(context)` を使います。**
*   **親ウィジェットから割り当てられた領域に基づいてレイアウトを決めるには `LayoutBuilder` を使います。** `constraints.maxWidth` を評価し、適切なウィジェットツリーを返します。
*   **ウィジェットツリー上部でレイアウトを切り替えるために `MediaQuery.orientationOf` や `OrientationBuilder` を使わないでください。** デバイスの向きは、アプリウィンドウで利用できる領域を正確に表しません。
*   **ハードウェアの種類（例: 「スマートフォン」と「タブレット」）を判定しないでください。** Flutter アプリはサイズ変更可能なウィンドウ、マルチウィンドウモード、ピクチャーインピクチャーで実行されます。すべてのレイアウト判断は、利用可能なウィンドウ領域だけに基づいて行います。

## ウィジェットのサイズと制約
Flutter の基本レイアウトルールを理解し、適用します。**制約は親から子へ、サイズは子から親へ、位置は親が決めます。**

*   **領域を配分する:** `Row`、`Column`、`Flex` ウィジェット内で `Expanded` と `Flexible` を使います。
    *   `Expanded` は、子ウィジェットに残りの領域をすべて使わせる場合に使います（`fit: FlexFit.tight`、`flex` 係数 1.0 の `Flexible` と同等です）。
    *   `Flexible` は、子ウィジェットが指定範囲内でサイズを決めながら、必要に応じて拡大・縮小できるようにする場合に使います。兄弟ウィジェット間で領域を配分する比率は `flex` 係数で指定します。
*   **幅を制約する:** 大画面でウィジェットが横方向の領域を使い切らないようにします。`GridView` や `ListView` などを `ConstrainedBox` または `Container` で囲み、`BoxConstraints` に `maxWidth` を指定します。
*   **遅延描画:** 件数が不明または多いリストを描画する場合は、必ず `ListView.builder` または `GridView.builder` を使います。

## デバイスと画面の向きに関する動作
あらゆるデバイスのフォームファクターと入力方法で、アプリが正しく動作するようにします。

*   **画面の向きを固定しないでください。** 向きを固定すると折りたたみ式デバイスで深刻なレイアウト問題が発生し、アプリが黒い枠の中に中央配置されるレターボックス表示になることがあります。Android の大画面デバイスでは、縦向きと横向きの両方をサポートする必要があります。
*   **向きの固定が必要な場合:** 業務要件で画面の向きを厳密に固定する必要がある場合は、`MediaQuery` ではなく `Display API` を使って物理画面の寸法を取得します。互換モードでは `MediaQuery` が大きなウィンドウサイズを取得できないためです。
*   **複数の入力方法をサポートする:** 基本的なマウス、トラックパッド、キーボードショートカットに対応します。タッチ対象が適切な大きさで、キーボード操作が可能であることを確認します。

## ワークフロー: アダプティブレイアウトの構築

利用可能な `BoxConstraints` に適応するレイアウトを実装するには、次のワークフローに従います。

**作業の進捗:**
- [ ] アダプティブな動作が必要な対象ウィジェットを特定する。
- [ ] ウィジェットツリーを `LayoutBuilder` で囲む。
- [ ] builder コールバックから `constraints.maxWidth` を取得する。
- [ ] アダプティブなブレークポイント（例: `largeScreenMinWidth = 600`）を定義する。
- [ ] **`maxWidth > largeScreenMinWidth` の場合:** 大画面向けレイアウトを返す（例: ナビゲーションサイドバーとコンテンツ領域を横並びにする `Row`）。
- [ ] **`maxWidth <= largeScreenMinWidth` の場合:** 小画面向けレイアウトを返す（例: `Column` または一般的なナビゲーション方式）。
- [ ] バリデーターを実行 -> アプリウィンドウのサイズを変更 -> レイアウトの切り替わりを確認 -> オーバーフローエラーを修正する。

## ワークフロー: 大画面向けの最適化

大画面で UI 要素が不自然に引き伸ばされないよう、次のワークフローに従います。

**作業の進捗:**
- [ ] 全幅のコンポーネント（例: `ListView`、テキストブロック、フォーム）を特定する。
- [ ] **リストを最適化する場合:** `SliverGridDelegateWithMaxCrossAxisExtent` を使って `ListView.builder` を `GridView.builder` に変更し、ウィンドウサイズに応じて列数が自動調整されるようにする。
- [ ] **フォームまたはテキストブロックを最適化する場合:** コンポーネントを `ConstrainedBox` で囲む。
- [ ] `ConstrainedBox` に `BoxConstraints(maxWidth: [optimal_width])` を設定する。
- [ ] `ConstrainedBox` を `Center` ウィジェットで囲み、大画面で制約対象のコンテンツが中央に配置されるようにする。
- [ ] バリデーターを実行 -> デスクトップ／タブレット向けターゲットでテスト -> 横方向への引き伸ばしを確認 -> `maxWidth` またはグリッド範囲を調整する。

## 例

### LayoutBuilder を使ったアダプティブレイアウト
利用可能な幅に基づいて、モバイル向けとデスクトップ向けのレイアウトを切り替える例です。

```dart
import 'package:flutter/material.dart';

const double largeScreenMinWidth = 600.0;

class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > largeScreenMinWidth) {
          return _buildLargeScreenLayout();
        } else {
          return _buildSmallScreenLayout();
        }
      },
    );
  }

  Widget _buildLargeScreenLayout() {
    return Row(
      children: [
        const SizedBox(width: 250, child: Placeholder(color: Colors.blue)),
        const VerticalDivider(width: 1),
        Expanded(child: const Placeholder(color: Colors.green)),
      ],
    );
  }

  Widget _buildSmallScreenLayout() {
    return const Placeholder(color: Colors.green);
  }
}
```

### 大画面で幅を制限する
ウィジェットが横方向の領域を使い切らないようにする例です。

```dart
import 'package:flutter/material.dart';

class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 800.0, // 読みやすさを保つための最大幅
          ),
          child: ListView.builder(
            itemCount: 50,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text('Item $index'),
              );
            },
          ),
        ),
      ),
    );
  }
}
```
