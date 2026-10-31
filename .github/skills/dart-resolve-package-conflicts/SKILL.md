---
name: dart-resolve-package-conflicts
description: パッケージのバージョン競合を修正するワークフロー。互換性のないパッケージバージョンが原因で `pub get` が失敗した場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:11:14 GMT
---
# Dart の依存関係を管理する

## 目次
- [基本概念](#core-concepts)
- [バージョン制約](#version-constraints)
- [ワークフロー: 依存関係の監査](#workflow-auditing-dependencies)
- [ワークフロー: 依存関係のアップグレード](#workflow-upgrading-dependencies)
- [ワークフロー: バージョン競合の解決](#workflow-resolving-version-conflicts)
- [例](#examples)

## 基本概念
Dart は依存関係に厳格な単一バージョン規則を適用します。プロジェクトとすべての推移的依存関係は、各パッケージについて1つの共通バージョンに解決されなければなりません。これにより実行時の型不一致を防げますが、「バージョンロック」が発生するリスクがあります。

バージョンロックを軽減するため、Dart は `pubspec.yaml` で固定バージョンではなくバージョン制約を使用します。`pubspec.lock` ファイルには、再現可能なビルドのために解決された正確なバージョンが記録されます。

`dart pub outdated` の出力列の意味を理解しておきます。
*   **Current:** 現在 `pubspec.lock` に記録されているバージョン。
*   **Upgradable:** `pubspec.yaml` の制約で許可される最新バージョン。`dart pub upgrade` はこのバージョンに解決します。
*   **Resolvable:** プロジェクト内の他のすべての依存関係を考慮したうえで、解決可能な最も新しいバージョン。
*   **Latest:** パッケージの公開済み最新バージョン（プレリリースを除く）。

## バージョン制約

*   **キャレット構文を使用:** `pubspec.yaml` の依存関係には常にキャレット構文（例: `^1.2.3`）を使用します。これにより、解決時に `pub` が新しい互換バージョン（次のメジャーバージョン未満）を選択できます。
*   **開発依存関係の下限を引き上げる:** `dev_dependencies` の下限を現在使用中の正確なバージョンに設定します。これにより解決が簡素化され、古く互換性のない開発ツールが選択されるのを防ぎます。
*   **CI で lockfile を強制:** CI/CD パイプラインで `dart pub get --enforce-lockfile` を使用し、本番環境でもローカルでテストした正確なバージョンを使うようにします。

## ワークフロー: 依存関係の監査

安定性やパフォーマンスに影響する可能性のある古いパッケージを特定するため、このワークフローを定期的に実行します。

**作業の進捗:**
- [ ] `dart pub outdated` を実行する。
- [ ] **Upgradable** 列を確認し、`pubspec.yaml` を変更せずに更新できるパッケージを特定する。
- [ ] **Resolvable** 列を確認し、更新に `pubspec.yaml` の制約変更が必要なパッケージを特定する。
- [ ] 取り下げ済みまたは提供終了と表示されたパッケージを特定する。

## ワークフロー: 依存関係のアップグレード

監査結果に基づく条件分岐を使って依存関係をアップグレードします。

**作業の進捗:**
- [ ] **「Upgradable」バージョンに更新する場合:**
  - [ ] `dart pub upgrade` を実行する。
  - [ ] `dart pub upgrade --tighten` を実行し、新たに解決されたバージョンに合わせて `pubspec.yaml` の下限を自動更新する。
- [ ] **「Resolvable」バージョン（メジャーアップデート）に更新する場合:**
  - [ ] `pubspec.yaml` を手動で編集し、バージョン制約を「Resolvable」列に合わせて引き上げる（例: `^0.11.0` を `^0.12.1` に変更する）。
  - [ ] `dart pub upgrade` を実行して新しい制約を解決し、`pubspec.lock` を更新する。
- [ ] **フィードバックループ:**
  - [ ] `dart analyze` を実行 -> エラーを確認 -> 破壊的な API 変更を修正する。
  - [ ] `dart test` を実行 -> 失敗を確認 -> リグレッションを修正する。

## ワークフロー: バージョン競合の解決

`pub` がすべての制約を満たす具体的なバージョンの組み合わせを見つけられない場合や、取り下げ済みのパッケージバージョンに対処する場合は、lockfile を必要最小限だけ編集します。

`pubspec.lock` ファイル全体を削除して `dart pub get` を実行しては**いけません**。依存関係グラフ全体で、制御されないアップグレードが発生します。

**作業の進捗:**
- [ ] `pubspec.lock` を開く。
- [ ] 競合中または取り下げ済みのパッケージに該当する YAML ブロックを見つける。
- [ ] lockfile からそのパッケージのエントリー**だけ**を削除する。
- [ ] `dart pub get` を実行し、そのパッケージで互換性があり取り下げられていない最新バージョンを取得する。
- [ ] **フィードバックループ:**
  - [ ] `dart pub deps` を実行し -> 依存関係グラフが正しく解決されることを確認する。
  - [ ] 解決に失敗した場合、ロックの原因となっている推移的依存関係を特定し、`pubspec.yaml` の制約を更新して再試行する。

## 例

### 制約の下限を引き上げる
`dart pub outdated` でパッケージがより新しいマイナー/パッチバージョンに解決可能と表示された場合は、`--tighten` フラグを使って `pubspec.yaml` を自動更新します。

**入力 (`pubspec.yaml`):**
```yaml
dependencies:
  http: ^0.13.0
```

**コマンド:**
```bash
dart pub upgrade --tighten http
```

**出力 (`pubspec.yaml`):**
```yaml
dependencies:
  http: ^0.13.5
```

### lockfile の必要な箇所だけを削除する
`package_a` が取り下げ済み、または競合によってロックされている場合は、`pubspec.lock` からそのブロックだけを削除します。

**Before (`pubspec.lock`):**
```yaml
packages:
  package_a:
    dependency: "direct main"
    description:
      name: package_a
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0" # 取り下げ済みバージョン
  package_b:
    dependency: "direct main"
    # ...
```

**操作:** `package_a` のブロック全体を削除します。`package_b` には手を加えません。その後 `dart pub get` を実行します。
