---
name: flutter-setup-localization
description: `flutter_localizations` と `intl` の依存関係を追加し、`pubspec.yaml` で `generate: true` を有効にして、`l10n.yaml` 設定ファイルを作成します。新しい Flutter プロジェクトでローカライズ機能を初期化する場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 21:27:35 GMT
---
# Flutter アプリケーションの国際化

## 目次
- [基本概念](#core-concepts)
- [セットアップのワークフロー](#setup-workflow)
- [実装のワークフロー](#implementation-workflow)
- [高度な書式設定](#advanced-formatting)
- [例](#examples)

## 基本概念
Flutter では、`flutter_localizations` パッケージと `intl` パッケージを使って国際化（i18n）とローカライズ（l10n）を行います。標準的な方法では、App Resource Bundle（`.arb`）ファイルにローカライズ対象の文字列を定義し、それらを生成される `AppLocalizations` クラスにコンパイルして、ウィジェットツリー内から型安全に利用します。

## セットアップのワークフロー

Flutter プロジェクトで国際化を初期化する際は、このチェックリストをコピーして進捗を管理します。

- [ ] **作業の進捗**
  - [ ] 1. `pubspec.yaml` に依存関係を追加する。
  - [ ] 2. `generate` フラグを有効にする。
  - [ ] 3. `l10n.yaml` 設定ファイルを作成する。
  - [ ] 4. `MaterialApp` または `CupertinoApp` を設定する。

### 1. 依存関係を追加する
必要なローカライズ用パッケージをプロジェクトに追加します。ターミナルで次のコマンドを実行します。
```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

`pubspec.yaml` の `dependencies` に次の設定が含まれていることを確認します。
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
```

### 2. コード生成を有効にする
`pubspec.yaml` を開き、`flutter` セクションで `generate` フラグを有効にして、ローカライズ処理を自動化します。
```yaml
flutter:
  generate: true
```

### 3. 設定ファイルを作成する
Flutter プロジェクトのルートディレクトリに `l10n.yaml` という名前の新しいファイルを作成します。入力ディレクトリ、テンプレートファイル、出力ファイルを定義します。
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
synthetic-package: true
```

### 4. アプリのエントリーポイントを設定する
`main.dart` で生成されたローカライズクラスと `flutter_localizations` ライブラリをインポートします。delegate とサポート対象のロケールを `MaterialApp` または `CupertinoApp` に渡します。

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // synthetic-package が false の場合はパスを調整

// ... build メソッド内
return MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('en'), // 英語
    Locale('es'), // スペイン語
  ],
  home: const MyHomePage(),
);
```

## 実装のワークフロー

ローカライズ対象のコンテンツを追加または変更する場合は、次の手順に従います。

### 1. ARB ファイルを定義する
*   **新しいコンテンツを作成する場合:** テンプレートファイル（`lib/l10n/app_en.arb`）に基準となる文字列を追加します。文脈がわかる説明も含めます。
*   **既存のコンテンツを編集する場合:** サポート対象のすべての `.arb` ファイルでキーを探し、値を更新します。

```json
{
  "helloWorld": "こんにちは、世界！",
  "@helloWorld": {
    "description": "プログラミングを始めたばかりの人への定番のあいさつ"
  }
}
```

他のロケール用の対応ファイル（例: `app_es.arb`）を作成します。
```json
{
  "helloWorld": "¡Hola Mundo!"
}
```

### 2. ローカライズクラスを生成する
コード生成を開始するには、次のコマンドを実行します。
```bash
flutter pub get
```
*フィードバックループ:* 検証ツールを実行 -> ターミナル出力で ARB 構文エラーを確認 -> カンマの不足やプレースホルダーの不一致を修正 -> `flutter pub get` を再実行します。

### 3. ローカライズ済み文字列を利用する
`AppLocalizations.of(context)` を使って、ウィジェットツリー内からローカライズ済み文字列にアクセスします。これを呼び出すウィジェットが `MaterialApp` の子孫であることを確認します。

```dart
Text(AppLocalizations.of(context)!.helloWorld)
```

## 高度な書式設定

プレースホルダーを使って、動的データ、複数形、条件付きの選択表現を扱います。

### プレースホルダー
波括弧内にパラメーターを定義し、メタデータオブジェクトでその型を指定します。
```json
"hello": "こんにちは、{userName}さん",
"@hello": {
  "description": "パラメーターを1つ含むメッセージ",
  "placeholders": {
    "userName": {
      "type": "String",
      "example": "Bob"
    }
  }
}
```

### 複数形
数量に応じた文字列の変化を扱うには、`plural` 構文を使用します。`other` ケースは必須です。
```json
"nWombats": "{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}",
"@nWombats": {
  "description": "A plural message",
  "placeholders": {
    "count": {
      "type": "num",
      "format": "compact"
    }
  }
}
```

### 選択表現
性別に応じたテキストなど、条件に応じて文字列を切り替えるには `select` 構文を使用します。
```json
"pronoun": "{gender, select, male{he} female{she} other{they}}",
"@pronoun": {
  "description": "A gendered message",
  "placeholders": {
    "gender": {
      "type": "String"
    }
  }
}
```

## 例

### `l10n.yaml` の全体例
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
synthetic-package: true
use-escaping: true
```

### ウィジェット実装の全体例
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class GreetingWidget extends StatelessWidget {
  final String userName;
  final int notificationCount;

  const GreetingWidget({
    super.key, 
    required this.userName, 
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(l10n.hello(userName)),
        Text(l10n.nWombats(notificationCount)),
      ],
    );
  }
}
```
