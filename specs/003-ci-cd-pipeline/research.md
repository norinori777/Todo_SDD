# 調査結果: CI/CD Validation and Review Gate

## 1. CI runner と検査コマンド

- **Decision**: Flutter analyze と debug APK build は Ubuntu、unit test は Windows の GitHub-hosted runner 上で個別の job として実行する。Flutter / Dart のバージョンは `pubspec.yaml` の制約（Flutter 3.41.7、Dart 3.11.5）に合わせ、Android Gradle build に JDK 17 を使う。
- **Rationale**: `SecureFileReader` は Win32 API により安全なファイル読み込みを実装し、Windows 以外では意図的に失敗するため、unit test は Windows runner が必要である。`android/app/build.gradle.kts` は Java/Kotlin target 17、debug signing を使うため、Ubuntu 上で `flutter build apk --debug` が署名鍵を追加せず Android build を検証できる。個別 job にすれば失敗した検査を特定できる。
- **Alternatives considered**: release APK は release signing 設定・秘密鍵を必要とするため対象外。全検査を単一 job にまとめると早期失敗で後続検査が実行されず、個別の結果も得にくいため不採用。

## 2. イベントと最新変更の扱い

- **Decision**: CI workflow は全ブランチの `push` と Pull Request の作成・更新イベントで起動する。PR checks は workflow が検証した最新 PR revision に結び付け、キャンセルされた・失敗した・未完了の実行を必須 check の成功にしない。
- **Rationale**: spec FR-001〜FR-005 が明示するイベント範囲と最新変更の保証に合致する。GitHub は status check を commit SHA ごとに記録するため、required checks は PR の最新 revision に対応する check を評価する。PR が更新されても古い revision の成功は新しい revision の成功にはならない。
- **Alternatives considered**: branch filter はすべての branch を対象とする要件に反する。PR event のみでは PR 前の push を検査できず、push event のみでは PR の merge gate に対する PR checks として不十分なため不採用。

## 3. Pull Request custom-agent review

- **Decision**: PR review workflow は GitHub Copilot CLI を非対話実行し、ファイル名由来の agent ID `pr-review` を `--agent` に指定して `.github/agents/pr-review.agent.md` を選択する（frontmatter の表示名は `pr-reviewer`）。読み取り専用の review job がコメント本文を生成し、別の comment job がPRの現在のhead SHAを再確認して通常コメントを投稿する。最後の `pr-review` job は両処理の成功時だけ成功する。
- **Rationale**: GitHub 公式資料は repository-level custom agent の配置先を `.github/agents/` とし、Copilot CLI の programmatic mode と `GITHUB_TOKEN` 認証を説明している。PR由来workflowがsecretを読むリスクを避けるためreview workflowは `pull_request_target` で起動し、`github.workflow_sha` のtrusted agent設定のみをcheckoutする。PR headのコードやworkflowはcheckout・実行しない。Copilot CLIには `gh pr view` / `gh pr diff` のみを許可し、PR由来secretは渡さない。comment jobはREST issue-comment endpointを使う。`gh pr comment` のGraphQL `addComment` とREST endpointのどちらも `issues: write` では403となり、`pull-requests: write` で投稿できた。既存agentは自動workflow出力モードではコメント本文のみを返し、通常の対話利用では従来どおり投稿する。
- **Alternatives considered**: GitHub Agentic Workflows は Actions での agent 実行をより強く保護する公式推奨経路だが、別形式の workflow とコンパイル済み lock workflow の追加が必要で、既存 `.agent.md` の直接実行経路としては Copilot CLI custom agent が明確なため、本機能では採用しない。通常の GitHub Actions に Copilot CLI を直接組み込む方法には prompt injection 等のリスクがあるため、PR 内容を信頼しない指示、レビュー job の分離、最小権限、明示的な失敗扱いを必須とする。
- **Authentication**: `copilot-requests: write` はCopilot CLIのrequest権限であり、リポジトリを書き換える権限ではない。検証対象の個人所有repositoryでは、`copilot-requests: write` を持つ `GITHUB_TOKEN` によるCopilot CLI認証が成功した。認証できない場合、review jobは失敗し、必須checkを成功扱いしない。
- **Operational prerequisite**: Copilot CLI の利用と課金policyを有効にする。認証には `GITHUB_TOKEN` を利用し、PR由来の任意secretをworkflowへ渡さない。認証失敗、agent実行失敗、PRが別SHAへ進行した場合、またはコメント投稿失敗はいずれも `pr-review` check の失敗とする。CI検査、review、comment投稿はそれぞれ別job/workflowで分離する。

## 4. Merge gate

- **Decision**: 対象ブランチの GitHub branch protection / ruleset に、Flutter analyze、Flutter test、Android build、PR review の4つの安定した check を required checks として登録し、PR 更新後の承認済み最新結果だけを merge 条件とする。自動 merge は設定しない。
- **Rationale**: workflow 定義だけではブランチへの merge を禁止できない。spec はすべての必須 check 成功を merge の前提にし、人間が最終判断することを要求するため、repository settings が必要である。
- **Alternatives considered**: workflow の success 結果だけに依存する方法は merge を強制できないため不採用。自動レビューの承認イベントだけを merge 条件にする方法も、レビュー未完了やコメント失敗を明確な required check として扱いにくいため不採用。

## 参照資料

- Repository: `pubspec.yaml`、`android/app/build.gradle.kts`、`.github/agents/pr-review.agent.md`、`specs/003-ci-cd-pipeline/spec.md`
- GitHub Docs, [Invoking custom agents](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/invoke-custom-agents) — custom agent の repository path と `copilot --agent=... --prompt ...` の例。
- GitHub Docs, [Automating tasks with Copilot CLI and GitHub Actions](https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-copilot-cli/automate-with-actions) — Actions 上での programmatic mode、認証と tool permission。
- GitHub Docs, [Copilot CLI in GitHub Actions](https://docs.github.com/en/copilot/concepts/agent-capabilities/agent-powered-workflows-and-operations/copilot-cli-in-github-actions) — `GITHUB_TOKEN` 利用、課金、Agentic Workflows 推奨、workflow security consideration。
- GitHub Docs, [Develop agentic workflows in GitHub Actions](https://docs.github.com/en/actions/tutorials/develop-agentic-workflows-in-github-actions) — `gh-aw` の別方式と生成/compile workflow。
- GitHub Docs, [Securely using pull_request_target](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target) — default branchの信頼済みworkflowを実行し、PR由来コードをcheckout・実行しないための制約。
