# Quickstart: CI/CD Validation and Review Gate

## 前提条件

- GitHub Actions が repository で有効である。
- Actions が使用する Flutter `3.41.7` / Dart `3.11.5`、Android SDK、JDK 17 を利用できる。
- PR review の Copilot CLI 利用が有効で、必要な Copilot 利用・課金ポリシーが設定されている。workflow はまず `GITHUB_TOKEN` を使用する。
- Copilot CLIにはworkflow-generated `GITHUB_TOKEN` を使い、任意のPR secretは設定・受け渡ししない。
- 対象ブランチの branch protection / ruleset を編集できる repository 管理者がいる。

## ローカル検査

repository root で実行:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

**期待結果**: 3コマンドが成功する。CI でもそれぞれ個別の check として同じ結果になる。Android build は既存 Gradle 設定に沿った debug APK を生成し、release signing secret を必要としない。

**注意**: `flutter test` は `SecureFileReader` が Win32 API を使うため Windows で実行する。CI では `flutter-test` job が Windows runner を使い、一時フォルダーも実体パスに設定する。

## Push 検証

1. 変更を任意のブランチへ push する。
2. GitHub Actions の実行を開く。
3. push した commit SHA の実行が作成され、`flutter-analyze`、`flutter-test`、`android-build` の3つの独立したcheckを確認する。

**期待結果**: 3つの結果が表示される。いずれかを失敗させた検証では該当 check と workflow が success にならない。

## Pull Request 検証

1. PR を作成し、後からコミットを追加して更新する。
2. PR作成時と更新時のそれぞれで `pull_request` workflow run が作成されることを確認する。
3. PR Checks を開き、最新 revision SHA に対する3検査と `pr-review` を確認する。更新前のSHAにだけ成功checkがある場合は失敗とする。
4. 指摘のあるPRと指摘のないPR（例: 独立した文書のみの変更）の両方で、review comment に対象 PR、確認範囲、指摘または「指摘なし」が記録されていることを確認する。レビューworkflowは `github.workflow_sha` のagent定義を使い、PR headをcheckoutせず、コメントはREST issue-comment endpoint経由で投稿する。`pull_request_target` はworkflowがdefault branchに存在する場合に起動する。

**期待結果**: 最新 SHA に対する4つの必須 check が表示される。レビューまたはコメント投稿に失敗した場合、`pr-review` は success にならない。古い SHA の成功だけでは更新後の PR をマージできない。

## Merge gate の設定と確認

1. `develop` ブランチの GitHub branch protection / ruleset に、[GitHub Actions 契約](./contracts/github-actions.md)の4つの check 名を required checks として設定する。
2. 直接 push/merge による保護の回避を禁止し、自動 merge が有効化されていないことを確認する。
3. 1つの必須 check が失敗中または未完了の PR で merge がブロックされることを確認する。
4. 4つすべてが最新 SHA で成功した後、人間が PR とレビューコメントを確認して手動で merge する。

**期待結果**: 必須 check の失敗・未完了では merge 不可。すべて成功しても自動 merge は行われず、人間の判断が必要。

## 失敗経路の確認

一時ブランチで analyze/test/build の各失敗を個別に起こし、該当 check が success にならないことを確認してから変更を破棄する。PR review も一時ブランチで、Copilot CLI実行失敗、無効な認証、PR特定失敗、コメント投稿失敗をそれぞれ起こし、いずれも `pr-review` が成功しないことを確認する。確認用の失敗を main や共有ブランチへ push しない。

各CI jobについて、一時ブランチのworkflow内で対応するコマンドを一時的に非0終了させてpushし、該当jobがfailure、他のjobが独立して完了することを確認する。検証後は一時変更を戻す。
