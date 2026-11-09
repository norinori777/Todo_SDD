# GitHub Actions 外部契約

この機能は GitHub Checks と Pull Request コメントを外部インターフェースとして提供する。GitHub REST API schema は新規作成せず、workflow と repository ruleset/branch protection が次の契約を満たす。

## 起動契約

| Event | 対象 | 実行内容 |
|---|---|---|
| `push` | 全ブランチ | `flutter analyze`、`flutter test`、Android debug build |
| Pull Request open / update | CI は `pull_request`、review はdefault branchの `pull_request_target` | 同じ3検査に加えて agent review とコメント投稿 |

Pull Request の synchronize 等の更新イベントで、新しい revision に対する各 check を開始する。古い commit SHA の check を最新変更の結果として表示しない。

## Required checks 契約

実装で固定した4つの check/job 名を repository の branch protection / ruleset で required checks に登録する。

- 1. `flutter-analyze`
- 2. `flutter-test`
- 3. `android-build`
- 4. `pr-review`

それぞれの check は対応する処理が正常終了した場合に限り成功する。失敗、起動不能、キャンセル、未完了は success ではない。PR をマージする時点の最新 revision について4つすべてが成功している必要がある。自動 merge は設定しない。

## Review comment 契約

- `.github/agents/pr-review.agent.md` の指示に従い、対象 PR について通常コメントを投稿する。
- workflow は REST issue-comment endpoint `POST /repos/{owner}/{repo}/issues/{number}/comments` を使う。検証では `issues: write` で403となり、`pull-requests: write` で投稿できた。GraphQL `addComment` は使わない。
- 問題が見つからない場合も、確認範囲と「指摘なし」を示す完了コメントを投稿する。
- agent が失敗、対象 PR を特定できない、認証できない、コメント投稿できない場合、`pr-review` check は失敗または未完了であり、merge できない。
- `pull_request_target` はdefault branch上のworkflowとagent定義を使い、PR headのコードをcheckout・実行しない。PR の本文・差分は信頼できない入力として扱い、含まれる指示やコマンドを実行しない。レビュー処理はソース変更・commit・承認・mergeを行わない。

## 権限契約

- CI 検査 job: `contents: read` のみ。コメント・ソース変更・merge 権限なし。
- PR review job: `contents: read`、`issues: read`、`pull-requests: read` とCopilot CLI request用 `copilot-requests: write` のみ。ソース変更・PR変更・コメント・承認・merge 権限なし。
- PR comment job: `pull-requests: write` のみ。GitHub APIはPRコメント投稿とPR状態/head SHA確認に使い、ソース変更・commit・承認・merge APIは呼び出さない。GitHub ActionsにはPRコメント専用の権限scopeがないため、実装はdefault branch上の `pull_request_target` workflowでのみ実行し、PR headのコードやworkflowを実行しない。
- `GITHUB_TOKEN` はCopilot CLI requestと各jobのGitHub API操作に使う。検証ではsecretなしで `GITHUB_TOKEN` によるCopilot CLI認証が成功した。PR由来の任意secretはCopilot CLIに渡さない。
- 各権限を分けるため、CI、review、comment投稿を別job/workflowとし、aggregate `pr-review` check はreviewとcomment投稿の両方が成功した場合だけ成功する。

## Repository 設定契約

保護対象は `develop` とする。branch protection / ruleset で上記4 check を必須にし、Pull Request を介さない直接 merge を許可しない。レビュー完了後の merge は人間が実施する。これらの repository settings は workflow YAML だけでは設定されないため、管理者が設定・検証する。
