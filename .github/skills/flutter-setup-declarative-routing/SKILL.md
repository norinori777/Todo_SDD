---
name: flutter-setup-declarative-routing
description: `go_router` などのパッケージを使って `MaterialApp.router` を構成し、高度な URL ベースのナビゲーションを実現します。特定のディープリンクやブラウザー履歴のサポートが必要な Web アプリケーションまたはモバイルアプリの開発時に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 21:08:03 GMT
---
# ルーティングとディープリンクの実装

## 目次
- [基本概念](#core-concepts)
- [ワークフロー: アプリケーションとルーターの初期化](#workflow-initializing-the-application-and-router)
- [ワークフロー: プラットフォームのディープリンク構成](#workflow-configuring-platform-deep-linking)
- [ワークフロー: 入れ子のナビゲーションの実装](#workflow-implementing-nested-navigation)
- [例](#examples)

## 基本概念

Flutter の宣言的ルーティングには `go_router` パッケージを使用します。複雑なルーティング、ディープリンク、入れ子のナビゲーションに対応する堅牢な API を提供します。

- **GoRouter:** アプリケーションのルートツリーを定義する中心的な構成オブジェクト。
- **GoRoute:** URL パスを Flutter 画面に対応付ける標準ルート。
- **ShellRoute / StatefulShellRoute:** 子ルートを永続的な UI シェル（例: `BottomNavigationBar`）でラップします。`StatefulShellRoute` は並列のナビゲーションブランチの状態を保持します。
- **Path URL Strategy:** Web URL から既定の `#` フラグメントを取り除きます。プラットフォームをまたいだクリーンなディープリンクに不可欠です。

## ワークフロー: アプリケーションとルーターの初期化

このワークフローに沿って `go_router` を使った新しい Flutter アプリケーションを立ち上げ、ルートのルーティング機構を構成します。

### 作業の進捗
- [ ] Flutter アプリケーションを作成する。
- [ ] `go_router` 依存関係を追加する。
- [ ] Web／ディープリンク用の URL strategy を構成する。
- [ ] `GoRouter` の構成を実装する。
- [ ] ルーターを `MaterialApp.router` にバインドする。

### 1. アプリケーションのひな型を作成する
次のコマンドを実行してアプリを作成し、必要なルーティングパッケージを追加します。
```bash
flutter create <app-name>
cd <app-name>
flutter pub add go_router
```

### 2. ルーターの構成
Define a top-level `GoRouter` instance. Handle authentication or state-based routing using the `redirect` parameter.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  // Path URL strategy を使って Web URL から '#' を取り除く
  usePathUrlStrategy();
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'details/:id',
          builder: (context, state) => DetailsScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => ErrorScreen(error: state.error),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'ルーティングアプリ',
    );
  }
}
```

## ワークフロー: プラットフォームのディープリンク構成

特定の URL をネイティブプラットフォームで受け取り、Flutter アプリケーションにルーティングするよう構成します。

### 作業の進捗
- [ ] 対象プラットフォーム（iOS、Android、または両方）を決める。
- [ ] Android の条件付き構成（Manifest + Asset Links）を適用する。
- [ ] iOS の条件付き構成（Plist + Entitlements + AASA）を適用する。
- [ ] 検証を実行 -> エラーを確認 -> 修正する。

### Android を構成する場合:
1. **`AndroidManifest.xml` の変更:** `.MainActivity` の `<activity>` タグ内に intent filter を追加します。
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="http" android:host="yourdomain.com" />
    <data android:scheme="https" />
</intent-filter>
```
2. **`assetlinks.json` の配置:** 次の JSON を `https://yourdomain.com/.well-known/assetlinks.json` で配信します。
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.yourcompany.yourapp",
    "sha256_cert_fingerprints": ["YOUR_SHA256_FINGERPRINT"]
  }
}]
```

### iOS を構成する場合:
1. **`Info.plist` の変更:** Flutter の既定ディープリンクハンドラーを有効にします。
*注: サードパーティのディープリンクプラグイン（例: `app_links`）を使用する場合は、競合を避けるため `NO` に設定します。*
```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
```
2. **`Runner.entitlements` の変更:** 関連付けるドメインを追加します。
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:yourdomain.com</string>
</array>
```
3. **`apple-app-site-association` の配置:** `.json` 拡張子を付けずに、次の JSON を `https://yourdomain.com/.well-known/apple-app-site-association` で配信します。
```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appIDs": ["TEAM_ID.com.yourcompany.yourapp"],
      "paths": ["*"],
      "components": [{"/": "/*"}]
    }]
  }
}
```

### 検証ループ
検証を実行 -> エラーを確認 -> 修正します。
- **Android:** ADB を使ってテストします。
  ```bash
  adb shell 'am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://yourdomain.com/details/123"' com.yourcompany.yourapp
  ```
- **iOS:** 起動済みシミュレーター上で `xcrun` を使ってテストします。
  ```bash
  xcrun simctl openurl booted https://yourdomain.com/details/123
  ```

## ワークフロー: 入れ子のナビゲーションの実装

`StatefulShellRoute` を使って、子ルートの状態を保持する永続的な UI シェル（ボトムナビゲーションバーなど）を実装します。

### 作業の進捗
- [ ] `GoRouter` の構成で `StatefulShellRoute.indexedStack` を定義する。
- [ ] ナビゲーションタブごとに `StatefulShellBranch` インスタンスを作成する。
- [ ] `StatefulNavigationShell` を使ってシェルウィジェットを実装する。

```dart
final GoRouter _router = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
```

## 例

### 実用的なシェルウィジェットの実装
`StatefulNavigationShell` を受け取り、ブランチ切り替えを処理する UI シェルを実装します。

```dart
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // 選択中のタブをタップしたとき、初期位置に移動できるようにする。
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}
```

### プログラムによるナビゲーション
`go_router` が提供する `context.go()` と `context.push()` の拡張メソッドを使用します。

```dart
// 現在のルートスタックを対象のルートに置き換える（宣言的）
context.go('/details/123');

// 対象ルートを既存のスタックに追加する（命令的）
context.push('/details/123');

// 名前付きルートとパスパラメーターを使って移動する
context.goNamed('details', pathParameters: {'id': '123'});

// 現在のルートをスタックから取り除く
context.pop();
```
