# 実装計画: CI/CD Validation and Review Gate

**Branch**: `003-ci-cd-pipeline` | **Date**: 2026-11-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-ci-cd-pipeline/spec.md`

## Summary

全ブランチへの push と Pull Request の作成・更新で、Flutter analyze・unit test・Android APK build を独立した必須チェックとして実行する。Pull Request ではdefault branch上の信頼済み `pull_request_target` workflowからCopilot CLIで既存の `.github/agents/pr-review.agent.md` を選択してレビューし、PR headをcheckoutせず、最新SHAを再確認して通常コメントを投稿する。レビュー処理とコメント投稿を別jobに分け、対象ブランチの保護設定で4チェックを必須にして、人間によるマージ判断を維持する。

## Technical Context

**Language/Version**: Dart 3.11.5 / Flutter 3.41.7（`pubspec.yaml` の制約）

**Primary Dependencies**: GitHub Actions、Flutter SDK、Android SDK、JDK 17、GitHub Copilot CLI

**Storage**: N/A（ワークフロー実行結果は GitHub Checks、レビュー結果は Pull Request コメント）

**Testing**: `flutter analyze`、`flutter test`、`flutter build apk --debug`。各ジョブを個別に実行し、失敗・起動不能を成功にしない。

**Target Platform**: GitHub-hosted Ubuntu runner（analyze / Android build）、Windows runner（Win32に依存するテスト）、Android debug APK

**Project Type**: Flutter Android mobile app と GitHub Actions workflow

**Performance Goals**: 各イベントで3つのビルド検査が個別に結果を出し、Pull Request のレビューが成功または失敗として終端する。時間目標は未指定。

**Constraints**: push は全ブランチ対象。PR 更新では最新の PR revision に対するチェックを要求し、古い実行を最新変更の成功とみなさない。解析・テスト用 token は read-only。review jobはCopilot requestと読み取り権限のみを持ち、comment jobはGitHubがPRコメント投稿に要求する `pull-requests: write` を持つ。PRコメント専用のActions permissionはないため、comment jobはdefault branchのtrusted workflowでのみ実行し、PR headのコードやworkflowをcheckout・実行しない。必須チェックと人間によるマージは GitHub のブランチ保護設定も必要。

**Scale/Scope**: `.github/workflows/` の workflow と、対象ブランチに対する GitHub repository ruleset / branch protection 設定。Flutter アプリの実装コードは変更しない。

## Constitution Check

*Gate: Phase 0 research 前と Phase 1 design 後に確認*

- **I. 要件とユーザーデータの保護**: Pass — CI はソース・ユーザーデータを書き換えず、検査失敗やレビュー投稿失敗を成功として扱わない。
- **II. 機能単位のアーキテクチャ**: Pass — 変更は CI の `.github/workflows/` に閉じ、アプリの機能コードやデータ境界を変更しない。
- **III. シンプルで保守しやすい実装**: Pass — 既存 GitHub Actions / Flutter toolchain と repository custom agent を利用し、新しいアプリ依存やサーバーを追加しない。
- **IV. 振る舞いとデータ保護を重視したテスト**: Pass — 正常・失敗・未実行を workflow checks で検証し、実際の Flutter analyze、test、Android build を実行する。振る舞いを変更しない CI 設定のため TDD は対象外。
- **V. 日本語でのコミュニケーション**: Pass — 計画・設計資料は日本語で作成する。

**Phase 0 gate**: Pass — spec の必須要件と clarification は記載済み。CI runner、Flutter version、Android build command、レビュー実行経路を既存ファイルと公式資料で決定した。

**Post-design gate**: Pass — design はアプリコードを変更せず、最小権限の検査・レビュー分離、失敗の明示、最新 SHA のチェック、および人間の merge gate を定義する。追加の例外・複雑性違反なし。

## Project Structure

### Documentation (this feature)

```text
specs/003-ci-cd-pipeline/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── github-actions.md
└── tasks.md
```

### Source Code (repository root)

```text
.github/
├── agents/
│   └── pr-review.agent.md      # 既存のレビュー手順
└── workflows/
    ├── ci.yml                  # push / pull_request 検査
    └── pr-review.yml           # PR レビュー・コメント

android/
└── app/build.gradle.kts        # 既存の Android build 設定

lib/
test/
```

**Structure Decision**: CI は既存アプリ構造と分離して `.github/workflows/` に配置する。Flutter コード・テストのディレクトリは維持する。Pull Request のステータスチェックは workflow job 単位で安定した名前を付け、ブランチ保護設定に登録する。

## Complexity Tracking

憲法違反なし。複雑性の例外は不要。
