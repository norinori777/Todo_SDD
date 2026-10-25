---
title: 機能間の依存境界を守る
impact: HIGH
impactDescription: 機能間の密結合を防ぎ、変更の影響範囲を限定する
tags: architecture, flutter, boundaries, coupling
---

## 機能間の依存境界を守る

Todo機能と設定機能など、機能間の連携は明確な公開インターフェースを通じて行います。他の機能の内部実装ファイルを直接参照しないでください。

**避ける例:**

```dart
// todo機能がsettings機能の内部実装に直接依存する
import '../../settings/data/internal/folder_settings_storage.dart';
```

**推奨する例:**

```dart
// 必要な設定へのアクセスは、公開された契約を通じて行う
import '../../settings/domain/folder_location.dart';
```

ファイルアクセスやMarkdown解析など、複数機能で共有する処理は `core/` に配置します。共有コードを特定機能の内部から別機能へ逆向きに依存させないでください。

## 依存関係の方針

- 画面は必要な機能の公開契約に依存し、他機能の内部実装には依存しない
- データアクセスの具体実装は、ドメインや画面に逆向きの依存を持ち込まない
- 小規模な機能では、境界を維持できる範囲でファイル数を抑える
- 境界を機械的に強制する仕組みが存在しない場合、import構造のレビューで確認する
