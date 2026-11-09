---
description: "Task list for CI/CD Validation and Review Gate"
---

# Tasks: CI/CD Validation and Review Gate

**Input**: Design documents from `specs/003-ci-cd-pipeline/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/github-actions.md`, `quickstart.md`

**TDD**: 振る舞いを変更する各タスクで `.github/skills/tdd/SKILL.md` を使用する。`quickstart.md` に正常系・失敗系のテスト手順を追加し、各タスクで1つの振る舞いについて Red → Green → Refactor を完了する。Red は未実装の挙動による失敗を実測し、コンパイルエラーや構文エラーを Red とみなさない。

**Organization**: ユーザーストーリーごとに実装・検証する。GitHub Actions の実行確認には、共有ブランチを避けた一時ブランチと一時 Pull Request を使う。

## Phase 1: Setup

**Purpose**: 既存リポジトリに GitHub Actions workflow の配置先を用意する。

- [X] T001 [P] `.github/workflows/ci.yml` にイベント・jobをまだ定義しないCI workflowの骨組みを作成する
- [X] T002 [P] `.github/workflows/pr-review.yml` にイベント・jobをまだ定義しないPR review workflowの骨組みを作成する

---

## Phase 2: Foundational

**Purpose**: 全ユーザーストーリーをブロックするアプリ共通コードや実行基盤の変更はない。必要な振る舞いとテストは各ストーリーのTDDサイクルで追加する。

**Checkpoint**: Setup完了後、User Story 1から実装できる。

---

## Phase 3: User Story 1 - Pushした変更を検証する (Priority: P1) 🎯 MVP

**Goal**: すべてのブランチへのpushでFlutter analyze、Flutter test、Android debug buildを独立した結果として表示し、失敗を成功扱いしない。

**Independent Test**: 任意の非デフォルトブランチへ一時的な変更をpushし、3つのcheckが個別に表示されることを確認する。各検査を一つずつ失敗させ、該当checkと実行全体が成功にならないことも確認する。

### TDD cycles for User Story 1

- [X] T003 [US1] Pushイベントのテストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、workflow未設定時に任意ブランチpushでcheckが作られないRedを確認してから、全ブランチ対象の `push` triggerを `.github/workflows/ci.yml` に実装し、同じシナリオでGreenを確認してtrigger設定をRefactorする
- [X] T004 [US1] 独立した検査結果のテストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、3検査を個別に識別できないRedを確認してから、安定したjob名 `flutter-analyze`、`flutter-test`、`android-build` とそれぞれの `flutter analyze`、`flutter test`、`flutter build apk --debug` を `.github/workflows/ci.yml` に実装し、3つのcheckでGreenを確認して重複設定をRefactorする
- [X] T005 [US1] 各検査の失敗状態のテストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、検査失敗を成功扱いするRedを確認してから、3 jobそれぞれで失敗がjob/workflowの失敗として残る設定を `.github/workflows/ci.yml` に実装し、検査を一つずつ失敗させてGreenを確認し、`continue-on-error` 等の成功扱いを生む設定がないことをRefactorで確認する

**Checkpoint**: Pushのたびに3検査が個別に実行され、失敗結果が成功扱いされない。

---

## Phase 4: User Story 2 - Pull Requestを検証して人間が判断する (Priority: P1)

**Goal**: Pull Requestの最新変更に対する3検査と `pr-review.agent.md` によるレビューコメントを必須にし、すべて成功した後も人間がマージを判断する。

**Independent Test**: 一時Pull Requestを作成・更新して最新revisionに対する4つの必須checkとレビューコメントを確認する。check失敗・レビュー失敗・未完了でマージがブロックされ、全check成功後は人間による操作だけでマージ可能になることを確認する。

### TDD cycles for User Story 2

- [X] T006 [US2] Pull Requestの作成・更新と最新revisionのテストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、PRイベントでcheckが開始されない／更新前のSHAの成功が最新結果に見えるRedを確認してから、`opened`、`synchronize`、`reopened` を対象とする `pull_request` triggerと古い実行を最新結果として流用しない設定を `.github/workflows/ci.yml` に実装し、一時PRを更新して最新revisionの3 checkでGreenを確認した後にイベント設定をRefactorする
- [ ] T007 [US2] 指摘あり・指摘なし両方のレビューコメントのテストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、レビュー完了コメントが投稿されないRedを確認してから、default branch上の信頼済み定義で動く `pull_request_target` workflow、`github.workflow_sha` のagent定義、RESTコメント投稿を実装し、両ケースのコメント投稿でGreenを確認して実行・投稿手順をRefactorする
- [ ] T008 [US2] Copilot CLI実行・認証・PR特定・コメント投稿の各失敗テストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、失敗が成功checkになるRedを確認してから、いずれかの処理が失敗または未完了なら `pr-review` が成功しない明示的な失敗処理を `.github/workflows/pr-review.yml` に実装し、各失敗でGreenを確認して成功扱いの経路がないことをRefactorで確認する
- [ ] T009 [US2] 権限境界のテストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、`issues: write` でのコメント投稿が403になるRedを確認してから、CIを `contents: read` のみ、reviewを読み取り権限と `copilot-requests: write`、comment jobを `pull-requests: write` のみに分離する。PRコメント専用scopeがないため `pull_request_target` と `github.workflow_sha` checkoutでPR headのコード・workflowを実行しない境界を実装し、実効権限のテストでGreenを確認する
- [ ] T010 [US2] 必須checkと人間によるmergeのテストを `specs/003-ci-cd-pipeline/quickstart.md` に追加し、未成功checkでもmergeが許可されるRedを確認してから、`develop` branchのrulesetまたはbranch protectionに `flutter-analyze`、`flutter-test`、`android-build`、`pr-review` を必須登録し、直接mergeを禁止して自動mergeを無効にする設定を行い、失敗・未完了時のmergeブロックと全成功後の手動mergeのテストでGreenを確認して設定手順をRefactorする

**Checkpoint**: 最新revisionの4 checkとレビューコメントが確認でき、必須checkの失敗・未完了時はmergeできず、成功後も自動mergeされない。

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: 変更全体をquickstartと契約に照合し、運用手順と実際のworkflowを一致させる。

- [ ] T011 Run `specs/003-ci-cd-pipeline/quickstart.md` のpush・PR作成・PR更新・各失敗経路・merge gateの検証を一時ブランチと一時PRで実施し、契約との差異があれば `.github/workflows/ci.yml`、`.github/workflows/pr-review.yml`、`specs/003-ci-cd-pipeline/quickstart.md` を修正する

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし。2つのworkflow骨組みは別ファイルのため並行作業可能。
- **Foundational (Phase 2)**: アプリ共通の前提作業なし。Setup完了後に各ストーリーを開始できる。
- **User Stories (Phase 3+)**: US1はSetup後に開始できる。US2はUS1のCI job名・失敗状態を利用するため、T003〜T005の後に進める。
- **Polish (Phase 5)**: US1、US2の実装とrepository保護設定の完了後に実施する。

### User Story Dependencies

- **User Story 1 (P1)**: Setup完了後に開始できる。他ストーリーに依存しない。
- **User Story 2 (P1)**: 3つのCI checkをrequired checksとして参照するため、US1のT003〜T005完了後に開始する。レビューworkflow自体は別ファイルだが、テスト手順を共有するためストーリー間での並行変更は避ける。

### Within Each User Story

- 要件から正常系、境界・更新、失敗系、既存挙動の回帰を含むテストリストを作り、1件ずつRed → Green → Refactorを完了する。
- Redは期待する挙動の不足による失敗として実測し、構文・設定エラーをRedとみなさない。
- 既存のFlutterバージョン、JDK、Android debug build設定とレビューagentを再利用し、アプリ実装コードは変更しない。

### Parallel Opportunities

- Phase 1のT001とT002は異なるworkflowファイルを作成するため並行可能。
- US1のanalyze、test、Android buildはGitHub Actions上で独立jobとして並行実行できる。実装作業は同じworkflowファイルを変更するためタスク単位では並行させない。
- US2ではreview workflowとCI workflowはファイル上独立しているが、quickstartテスト手順とUS1のcheck依存があるため、T006〜T010は記載順に進める。

## Parallel Example: User Story 1

```text
Runtime parallelism: .github/workflows/ci.yml の flutter-analyze、flutter-test、android-build jobを独立して実行する。
Implementation: T003〜T005は同じworkflowとquickstartの検証手順に依存するため、順番に完了する。
```

## Parallel Example: User Story 2

```text
Runtime validation: 3つのCI jobとpr-review jobは独立したcheckとして結果を表示する。
Implementation: US2はUS1のcheck名を使い、quickstart.mdも共有するため、T006〜T010を順番に完了する。
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1のworkflow骨組みを作成する。
2. Phase 2の共有前提が不要であることを確認する。
3. Phase 3のUS1を完成し、任意ブランチpushで3検査と個別の失敗結果を検証する。
4. **STOP and VALIDATE**: Push検証を独立して確認する。これはpush時の品質ゲートMVPであり、PRレビュー／merge gateの提供にはUS2が必要。

### Incremental Delivery

1. Setupを完了してworkflow配置先を用意する。
2. US1を追加し、push時の品質検査を独立して検証する。
3. US2を追加し、PR最新revision、レビューコメント、最小権限、merge gateを検証する。
4. Polishでquickstart全体を実行し、全要件と失敗経路を確認する。

### Parallel Team Strategy

1. チームでPhase 1を完了する。
2. US1を実装して安定したcheck名と失敗動作を確定する。
3. US1完了後、別担当が `.github/workflows/pr-review.yml` のレビュー実装を先行可能だが、quickstartとCI workflowの統合は順番に行う。
4. 両ストーリー完了後に一時PRでmerge gateと最新revisionの動作を検証する。

## Notes

- `[P]` は別ファイルを変更し、未完了タスクへの依存がない作業に限る。
- `[US1]` / `[US2]` はspec.mdのユーザーストーリーに対応する。
- 失敗注入とbranch protectionの確認は共有ブランチで行わず、一時ブランチ／一時PRを用いる。
- GitHub branch protection / rulesetの変更にはrepository管理者権限が必要。権限がない場合は未完了として報告する。
- TDDのRedを実測できない場合は実装を進めず、理由と残るリスクを報告する。
