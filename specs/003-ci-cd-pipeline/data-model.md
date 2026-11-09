# データモデル: CI/CD Validation and Review Gate

この機能はアプリ用データベースを追加しない。以下は GitHub Actions が識別・公開する論理エンティティと状態である。

## 検証対象変更 (Validated Change)

| Field | Type | Constraints |
|---|---|---|
| commit SHA | Git commit SHA | 不変の検証対象。PR の場合は workflow が検証した PR revision |
| branch | branch name | push 元、または PR head branch |
| event | `push` / `pull_request` / `pull_request_target` | CI は `pull_request`、review は `pull_request_target` |
| pull request number | integer, optional | `pull_request` または `pull_request_target` の場合に必須 |

**Relationships**: 1つの検証対象変更に3つの CI 検査結果が紐付く。PR の検証対象は、その PR の最新 revision と関連する commit SHA で識別される。

## CI 検査結果 (CI Check Result)

| Field | Type | Constraints |
|---|---|---|
| check name | `flutter-analyze` / `flutter-test` / `android-build` | ブランチ保護設定で参照する安定名 |
| target SHA | Git commit SHA | 検証対象変更の SHA と一致 |
| state | `queued` / `in_progress` / `success` / `failure` / `cancelled` | 起動不能、失敗、キャンセル、未完了は成功以外 |
| conclusion | GitHub check conclusion | 必須 check は `success` のときだけ通過 |

**State transitions**: `queued → in_progress → success | failure | cancelled`. Workflow/job の起動不能または異常終了は成功状態に遷移させない。新しい PR SHA には新しい check 結果を作り、過去 SHA の成功状態を流用しない。

**Validation**: analyze、test、Android build は別々に可視化される。いずれかが `success` 以外なら、その SHA の検証は merge 不可。

## Pull Request review result (PR Review Result)

| Field | Type | Constraints |
|---|---|---|
| pull request number | integer | 対象 PR |
| target SHA | Git commit SHA | コメントのレビュー対象 |
| state | `queued` / `in_progress` / `success` / `failure` | agent 実行・コメント投稿の両方が完了した場合のみ `success` |
| comment | GitHub issue comment | 指摘がない場合も完了を示すコメントを1件投稿 |

**Relationships**: 1つの PR review result は1つの PR とそのレビュー対象 SHA に属する。

**Validation**: レビューまたはコメント投稿が失敗・未完了なら review check は成功しない。コメントに source change/merge を含めず、自動 merge は行わない。

## Merge eligibility

PR の最新 revision に対する `flutter-analyze`、`flutter-test`、`android-build`、PR review のすべてが `success` であることを branch protection / ruleset が確認する。すべて成功した後も merge 操作は人間が行う。
