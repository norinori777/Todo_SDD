---
name: flutter-add-widget-preview
description: previews.dart システムを使用して、プロジェクトにインタラクティブなウィジェットプレビューを追加します。一貫したデザインとインタラクティブなテストを実現するため、新しい UI コンポーネントの作成時や既存画面の更新時に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 20:05:23 GMT
---
# Flutter ウィジェットのプレビュー

## 目次
- [プレビューのガイドライン](#preview-guidelines)
- [プレビューのパラメーター](#preview-parameters)
- [制約への対処](#handling-limitations)
- [ワークフロー](#workflows)
- [例](#examples)

## プレビューのガイドライン

Flutter Widget Previewer を使用すると、アプリケーション全体のコンテキストから切り離して、ウィジェットをリアルタイムに描画できます。

- **対象要素:** 必須引数がなく、`Widget` または `WidgetBuilder` を返すトップレベル関数、クラス内の静的メソッド、または公開ウィジェットのコンストラクター／ファクトリーに `@Preview` アノテーションを適用します。
- **インポート:** プレビュー用アノテーションを利用するには、必ず `package:flutter/widget_previews.dart` をインポートします。
- **カスタムアノテーション:** `Preview` クラスを拡張し、複数のウィジェットに共通プロパティ（カスタムテーマ、ラッパー、サイズなど）を注入するカスタムアノテーションを作成します。
- **複数の構成:** 1 つの対象に複数の `@Preview` アノテーションを適用すると、複数のプレビューインスタンスを生成できます。または、`MultiPreview` を拡張して共通の複数プレビュー構成をまとめることもできます。
- **実行時の変換:** カスタム `Preview` または `MultiPreview` クラスで `transform()` メソッドをオーバーライドすると、実行時にプレビュー構成を動的に変更できます（例: `const` コンストラクターではできない、パラメーターに基づく名前の動的生成）。

## プレビューのパラメーター

`@Preview` アノテーションは、プレビュー環境を調整するために次のパラメーターをサポートします。

- `name`: プレビューインスタンスの説明的な名前。
- `group`: Previewer 内で関連するプレビューをまとめるための名前。
- `size`: `Size` オブジェクトによる人工的な制約。
- `textScaleFactor`: カスタムフォント倍率。
- `wrapper`: プレビュー対象のウィジェットを特定のウィジェットツリーでラップする関数（状態や継承ウィジェットの注入など）。
- `theme`: `PreviewThemeData` のサブクラスのインスタンスを返す関数。テーマを順に重ねる機能を使って、カスタムテーマを提供します。
- `brightness`: 初期テーマの `Brightness`（`Brightness.light` または `Brightness.dark`）。
- `localizations`: ローカライズ設定を適用する関数。

## 制約への対処

Widget Previewer は Web 環境で動作するため、プレビュー可能なウィジェットを作成する際は次の制約を守ってください。

- **ネイティブ API の禁止:** ネイティブプラグインや `dart:io`、`dart:ffi` の API は使用しないでください。これらに間接的に依存するウィジェットは、呼び出し時に例外をスローします。プレビューモードでは条件付きインポートやラッパーを使ってモック化するか、該当機能を回避してください。
- **アセットのパス:** `dart:ui` の `fromAsset` API で読み込むアセットには、パッケージベースのパスを使用します（例: `assets/my_image.png` ではなく `packages/my_package_name/assets/my_image.png`）。
- **公開コールバック:** コード生成要件を満たすため、プレビューアノテーションに指定するコールバック引数はすべて公開かつ定数であることを確認します。
- **制約:** ウィジェットに制約がない場合、既定ではビューポートのおよそ半分のサイズになります。`@Preview` アノテーションの `size` パラメーターを使って明示的な制約を適用してください。
- **ビルドキャッシュ:** Previewer はプロジェクトルートの `.widget_preview/` フォルダーにビルドをキャッシュします。

## ワークフロー

### ウィジェットプレビューの作成
新しいウィジェットプレビューを実装する際は、このチェックリストをコピーして進捗を管理します。

- [ ] `package:flutter/widget_previews.dart` をインポートする。
- [ ] 有効な対象（トップレベル関数、静的メソッド、または引数を持たない公開コンストラクター）を特定する。
- [ ] 対象に `@Preview` アノテーションを適用する。
- [ ] 必要に応じてプレビューのパラメーター（`name`、`group`、`size`、`textScaleFactor`、`wrapper`、`theme`、`brightness`、`localizations`）を設定する。
- [ ] 複数のウィジェットに同じ構成を適用する場合は、`Preview` または `MultiPreview` を拡張するカスタムクラスに構成を切り出す。

### プレビューの操作
Widget Previewer の起動と操作には、該当する条件付きワークフローを使用します。

**対応 IDE（Android Studio、IntelliJ、Flutter 3.47 以降を搭載した VS Code）を使用する場合:**
1. IDE を起動します。Widget Previewer は自動的に起動します。
2. サイドバーの「Flutter Widget Preview」タブを開きます。
3. 現在のファイル以外のプレビューも表示するには、左下の「Filter previews by selected file」を切り替えます。

**コマンドラインを使用する場合:**
1. Flutter プロジェクトのルートディレクトリに移動します。
2. `flutter widget-preview start` を実行します。
3. 自動的に開く Chrome 環境でプレビューを確認します。

**フィードバックループ: プレビューの反復**
1. ウィジェットのコードまたはプレビュー構成を変更します。
2. Widget Previewer で自動更新を確認します。
3. グローバル状態（静的初期化子など）を変更した場合は、右下のグローバルホットリスタートボタンをクリックします。
4. ローカルのウィジェット状態だけをリセットする場合は、対象のプレビューカードにある個別のホットリスタートボタンをクリックします。
5. IDE／CLI のコンソールでエラーを確認し、修正して、手順を繰り返します。

## 例

### 基本的なプレビュー
```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter/material.dart';

@Preview(name: '送信ボタン', group: 'フォームコントロール')
Widget submitButtonPreview() => const ElevatedButton(
      onPressed: null,
      child: Text('送信'),
    );
```

### PreviewThemeData と変換を使ったカスタムプレビュー
```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter/material.dart';

final class ThemedPreview extends Preview {
  const ThemedPreview({
    super.name,
    super.group,
    super.brightness,
  });

  PreviewThemeData _themeBuilder() =>
      CustomThemeData(brightness: brightness);

  @override
  Preview transform() {
    final originalPreview = super.transform();
    final themeVariant = switch (brightness) {
      null => 'レスポンシブ',
      final b => b.name,
    };

    final builder = originalPreview.toBuilder();
    final baseName = originalPreview.name ?? 'プレビュー';
    builder
      ..name = '$baseName [$themeVariant]'
      ..theme = _themeBuilder;

    return builder.build();
  }
}

final class CustomThemeData extends PreviewThemeData {
  const CustomThemeData({this.brightness});

  final Brightness? brightness;

  @override
  Widget apply(BuildContext context, Widget child) {
    return Theme(
      data: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness ??
              MediaQuery.maybePlatformBrightnessOf(context) ??
              Brightness.light,
        ),
      ),
      child: child,
    );
  }
}

@ThemedPreview(name: 'テーマ付きアクションボタン', brightness: Brightness.dark)
Widget themedButtonPreview() => const ElevatedButton(
      onPressed: null,
      child: Text('アクション'),
    );
```

### MultiPreview の実装
```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter/material.dart';

/// ライトモードとダークモードのプレビューを自動的に作成します。
final class MultiBrightnessPreview extends MultiPreview {
  const MultiBrightnessPreview({required this.name});

  final String name;

  @override
  List<Preview> get previews => const [
        Preview(brightness: Brightness.light),
        Preview(brightness: Brightness.dark),
      ];

  @override
  List<Preview> transform() {
    final previews = super.transform();
    return previews.map((preview) {
      final builder = preview.toBuilder()
        ..group = '明るさ'
        ..name = '$name - ${preview.brightness!.name}';
      return builder.toPreview();
    }).toList();
  }
}

@MultiBrightnessPreview(name: 'プライマリカード')
Widget cardPreview() => const Card(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('コンテンツ'),
      ),
    );
```
