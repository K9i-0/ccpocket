# Contributing to CC Pocket

Thank you for your interest in contributing to CC Pocket!

## Quick start: submitting a PR

1. Start from `main` and keep one goal per PR. Agree on non-trivial scope in an
   Issue or Prompt Request before implementing it (see [quality bar](#contribution-quality-bar)).
2. Follow [setup and pre-PR checks](docs/development-testing.md#before-opening-a-pr)
   for each area you changed. For Bridge changes, run targeted tests during
   development, then the **full Bridge suite, type check, and build** before submitting.
3. Fill out the PR template with exact commands and actual results, plus UI or
   target-platform evidence where applicable. Adding a test does not mean it passed.
   If a check could not run, state which check and why; do not report it as successful.
4. Check the latest commit's `Test` workflow and address failures and CodeRabbit
   findings before requesting maintainer review. CI success and
   [review readiness](#automated-review-readiness) are separate requirements.

If you cannot prepare a validated code change, share the goal and findings in an
Issue or Prompt Request instead.

## Prompt Request — Contributing in the AI Era

CC Pocket is a mobile client for Claude / Codex.
Given the nature of the project, we embrace an **AI-driven contribution style**.

In traditional OSS, the standard workflow is "write code and send a Pull Request."
In CC Pocket, we encourage **Prompt Requests** instead.

### What is a Prompt Request?

> A way to contribute by sharing "I achieved this feature/fix using this prompt" via a GitHub Issue.

Rather than sharing code diffs, you share the **instructions you gave to an AI** (intent, constraints, assumptions). This means:

- You can contribute without deep knowledge of the project's architecture
- Maintainers can re-run and adjust the prompt to fit the codebase
- Reviews focus on **what you intended to achieve** rather than implementation details

### How to Contribute

1. **Create an Issue** — Use the [Prompt Request template](https://github.com/K9i-0/ccpocket/issues/new?template=prompt_request.yml)
2. **Describe the prompt and results** — The actual prompt you used, what it achieved, screenshots, etc.
3. **Maintainers verify and apply** — We re-run the prompt, adjust as needed, and merge

### What to Include in a Prompt Request

- **Goal**: What you wanted to achieve
- **Prompt**: The exact instructions you gave to the AI (in a copy-pasteable format)
- **Result**: What worked, screenshots, etc.
- **Environment**: The AI tool you used (Claude, Codex, etc.)

## Bug Reports / Feature Requests

In addition to Prompt Requests, regular Issues are always welcome.

- [Bug Report](https://github.com/K9i-0/ccpocket/issues/new?template=bug_report.yml) — Report a bug
- [Feature Request](https://github.com/K9i-0/ccpocket/issues/new?template=feature_request.yml) — Suggest a feature

### Platform Support Status

CC Pocket is developed primarily on macOS.
Some environments are currently handled on a best-effort basis rather than as fully supported targets.

- Bridge Server on Windows: experimental / best-effort
- Flutter mobile app on macOS: experimental / best-effort

For these environments:

- Bug reports are welcome, but maintainers may not be able to reproduce or verify fixes locally
- An Issue alone does not guarantee maintainer implementation
- The best path to getting a fix merged is a focused PR with tests and reporter-side validation

If a fix can be scoped cleanly to the Bridge Server, please also consider
whether a fork is a better fit than asking the main project to carry long-term
support for a niche environment. The MIT license allows compatibility forks,
but they should remain clearly separate from official CC Pocket releases unless
the changes are merged upstream.

If you file an Issue for one of these environments, please include:

- Exact OS and version
- Tool versions involved
- Clear reproduction steps
- Logs, screenshots, or terminal output
- Any workaround you found

## Pull Requests

### Contribution License

By contributing to this repository, you agree that your contribution is
licensed under the same license as the repository, unless explicitly stated
otherwise in writing.

### Preferred PR Shape

For most contributions, the easiest PR to review is:

- One user-visible goal per PR
- Small enough that the intent is obvious from the diff
- Built on `main`, not on top of another open PR
- Accompanied by tests or concrete validation notes
- Titled with Conventional Commits syntax: `type(scope): concise description`

As a rule of thumb, if your change introduces a new feature, a new package,
multiple architectural ideas at once, or a large amount of design/docs/code in
one PR, please open a **Prompt Request** or **Issue** first and align on scope
before sending code.

If a PR depends on another open PR, say so clearly and link the base PR.
Otherwise, we may ask you to restack it onto `main`, split it up, or close it
and continue discussion in an Issue instead.

### Review Expectations

CC Pocket is maintained as a personal project.
PR review happens on an availability basis, not in submission order.

Opening a PR does **not** guarantee review or acceptance. Authors prepare the
contribution with CI and CodeRabbit before maintainer review begins. Maintainers
do not provide an implementation coaching loop for unready PRs.

### Contribution Quality Bar

AI-assisted contributions are welcome. We judge the submitted change by concrete
evidence and maintenance cost:

- **Focused scope:** every changed area supports one agreed goal, its tests, or
  necessary documentation. External non-trivial features, new packages,
  architecture changes, and all PRs over 50 files need prior maintainer agreement in an Issue or
  Prompt Request; a link alone is not agreement. Small self-contained fixes may
  explain why no prior Issue is needed. For maintainer-authored PRs up to 50 files,
  the scope decision may be documented in the PR itself; no separate Issue is needed.
- **Necessary implementation:** use existing patterns. Remove unused code and
  dependencies, duplicate implementations, speculative extension points, and
  fallbacks that hide failure. Style preferences alone are not blockers.
- **Credible validation:** give commands and results that support the claimed
  behavior. Bug fixes need a regression test or reproducible before/after
  validation when automation is impractical. Tests must check useful behavior.
  Documentation-only and similarly low-impact changes may explain why tests do
  not apply. OS-dependent changes need validation on the target environment.

CodeRabbit checks these criteria before handoff. Address its concrete findings
and explain disagreements there; do not manufacture validation results or add
unrelated code just to satisfy a suggestion. Maintainer review focuses on
product fit and risk that automation cannot settle.

### Automated Review Readiness

Maintainer review starts only after all of these gates pass:

1. The PR is marked ready for review and its template is complete
2. The scope and validation evidence pass the `PR Readiness` check
3. The `Test` workflow passes
4. CodeRabbit completes its review and explicitly approves the latest commit,
   with required feedback resolved and required pre-merge checks passing
5. No `status:quality-hold` label is present

PR Readiness adds `ready-for-maintainer-review` and requests maintainer review
only after every gate passes. A new commit clears readiness until CI and
CodeRabbit approve the new head commit.

A green `CodeRabbit` status or `Review completed` message alone is insufficient.
Do not use top-level `@coderabbitai approve` or `@coderabbitai resolve` commands
to bypass review or pre-merge checks. Missing, inconclusive, or ignored required
checks need maintainer assessment; they are not evidence that the criteria pass.
Custom pre-merge checks require a CodeRabbit plan that supports them. Maintainers
must verify that the configured checks actually run before relying on this gate.

CodeRabbit's initial full review can flag low-quality submissions with
`status:quality-hold`. PR Readiness then excludes them from the maintainer queue,
even if CI is green. This signal does not automatically close a PR or prove AI
authorship. A maintainer can remove the label after correction or a false-positive
assessment; `review:override` cannot bypass it, and ordinary readiness
synchronization never removes it. Incremental
reviews do not rerun Slop Detection. See the [CodeRabbit Slop Detection
documentation](https://docs.coderabbit.ai/pr-reviews/slop-detection) and
[pre-merge check requirements](https://docs.coderabbit.ai/pr-reviews/pre-merge-checks).

The file-count policy is intentionally strict:

- 1-50 changed files: normal intake
- 51-150 changed files: a prior Issue or Prompt Request is required, and the PR
  may still be returned for splitting
- More than 150 changed files: the PR is labeled `status:needs-split`, given a
  split request, and closed without a detailed review

Generated files count toward the hard limit. A maintainer may apply
`review:override` only for exceptional repository maintenance; it is not a way
for contributors to bypass the review policy.

Changes to CodeRabbit configuration, GitHub workflows, the PR template, the PR
readiness checker, or agent instructions/configuration do not enter the
automated maintainer queue when authored externally. They require a
maintainer-authored PR or an explicit `review:override`, because those files
define the review gate itself.

For visual or interaction UI changes, attach Before and After evidence in the PR
body. An After image or recording is required. Before may be written as
`N/A — <reason>` only for a new UI. Changes under the mobile UI area that are
not visible must explain why no visual evidence is needed. Text-only changes may
instead provide a successful `flutter test ...` command and result, plus a reason
images are unnecessary.

For small low-risk PRs (10 files or fewer), supporting rationale, out-of-scope
notes, split plans, manual validation, and platform details are advisory. The
primary goal, automated evidence or a concrete reason it does not apply, risk,
rollback, and author checklist remain required. UI and OS-dependent changes
still need their relevant evidence.

### Maintainer Handoff and Merge

After readiness passes, maintainers may use Codex to finish integration. We make
bounded fixes ourselves, including small design adjustments, missing tests, and
conflict resolution, then validate and merge. We do not send the contributor
through another Request Changes round at this stage. If a fork cannot be edited,
we can incorporate the contribution on a maintainer branch with attribution.

Readiness is an entry criterion, not a promise to merge. We decline changes when
product fit is poor or correction, verification, or long-term support costs
outweigh their value. We do not undertake an open-ended rewrite to rescue every
PR. Maintainer fixes must pass CI and CodeRabbit on the actual branch and latest
commit being merged; approval of the original commit does not carry forward.

### Environment-Dependent PRs — Especially Welcome

We develop primarily on macOS and don't always have easy access to Linux, WSL, or Windows environments.
If you can **test on a platform we can't**, your PR is especially valuable.

Examples:

- Linux / systemd integration fixes
- WSL-specific workarounds
- Cross-platform compatibility improvements

For these cases, please include:

- What platform and version you tested on
- Steps to reproduce the issue (if it's a fix)
- Test results or logs

For experimental / best-effort platforms such as Windows Bridge or macOS mobile:

- Keep the change narrowly scoped
- Add automated tests where possible
- Describe exactly what you validated on the target platform
- Avoid broad refactors unless they are required for the fix

For Bridge-only compatibility work, we may decide that a separate fork is the
more sustainable outcome than ongoing first-party support in the main project.

PRs for these platforms are reviewed on a best-effort basis.
We are more likely to merge changes that are easy to reason about and low risk for supported platforms.

### Other PRs

For changes that don't require a specific environment, we recommend opening a **Prompt Request** or **Issue** first.

Please treat this as effectively required for large or architectural changes.
In particular, open an Issue / Prompt Request before sending a PR if any of
these apply:

- The PR adds a new package, app surface, or workflow
- The PR mixes CLI, Bridge, mobile, and docs changes in one branch
- The PR is difficult to review commit-by-commit without prior context
- The PR is stacked on another unmerged PR
- The main value is the idea / prompt / workflow, not a narrowly scoped fix

If you do send a PR, we may close it and re-implement the change ourselves to fit the codebase's conventions and architecture. In that case:

- Your contribution will be credited via `Co-authored-by` in the commit
- The commit or PR description will explain what we incorporated and adjusted

This isn't a rejection of your work — it's how we maintain consistency while honoring your contribution.

We may also ask for a PR to be split before review if it combines multiple
independent ideas, broad refactors, or large planning/spec documentation that
isn't required to validate the change.

### Labels You May See

Maintainers may apply labels like these when triaging Issues and PRs:

- `platform:windows` — Windows-specific report or change
- `platform:macos` — macOS-specific report or change
- `status:experimental` — best-effort area, not continuously verified by maintainers
- `status:unsupported` — outside the project's current support commitment
- `needs-repro` — more precise reproduction details are needed
- `needs-test` — automated tests or validation evidence are needed
- `help wanted` — contributions are welcome
- `status:needs-author` — the automated intake, CI, or CodeRabbit gate needs author action
- `status:needs-split` — the PR is too large and must be split
- `status:quality-hold` — CodeRabbit flagged quality; maintainer assessment is needed to clear the hold
- `review:coderabbit` — intake passed and CodeRabbit review is enabled
- `ready-for-maintainer-review` — intake, CI, and CodeRabbit approval all passed
- `risk:high` — the PR touches a security, protocol, process, or release boundary

## Security

If you discover a vulnerability, please report it privately via [GitHub Security Advisories](https://github.com/K9i-0/ccpocket/security/advisories/new) rather than opening a public Issue. See [SECURITY.md](./SECURITY.md) for details.

---

## 日本語 / Japanese

### PR 提出までの最短手順

1. `main` を起点に、1PR 1テーマに絞ります。非自明な変更は実装前に Issue / Prompt Request
   でスコープを合意してください（[品質基準](#コントリビューションの品質基準)を参照）。
2. [環境準備と提出前チェック](docs/development-testing.md#before-opening-a-pr)で変更領域ごとの
   コマンドを実行します。Bridge は開発中に対象テストを使い、提出前に **Bridge 全体のテスト・
   型チェック・ビルド**を実行してください。
3. PR テンプレートに実際のコマンドと結果を記載し、必要な UI・対象環境の検証証拠を添えます。
   テストを追加しただけでは実行成功の証拠になりません。実行できないチェックは名前と理由を
   明記し、成功扱いにしないでください。
4. 最新コミットの `Test` Workflow を確認し、失敗と CodeRabbit の指摘に対応してから
   メンテナレビューへ進みます。CI 成功と[レビュー準備判定](#自動レビュー準備判定)は別の条件です。

検証済みのコード変更を用意できない場合は、Issue / Prompt Request で目的と調査結果を共有してください。

### Prompt Request（プロンプトリクエスト）とは？

> 「こういうプロンプトで、こういう機能追加／修正ができた」を Issue で共有する貢献方法です。

コードの差分ではなく、**AI に渡した指示（意図・制約・前提）** を共有することで：

- プロジェクトのアーキテクチャを深く理解していなくても貢献できる
- メンテナがプロンプトを再実行・調整してコードベースに適合させられる
- レビューの焦点が「何を実現したいか」という意図に集中する

### 貢献の流れ

1. **Issue を作成する** — [Prompt Request テンプレート](https://github.com/K9i-0/ccpocket/issues/new?template=prompt_request.yml) を使用
2. **プロンプトと結果を記載する** — 実際に使ったプロンプト、実現できたこと、スクリーンショットなど
3. **メンテナが検証・適用する** — プロンプトを再実行し、必要に応じて調整してマージ

### Pull Request

#### 環境依存の PR — 特に歓迎

開発は主に macOS で行っており、Linux・WSL・Windows 環境を常に手元で用意できるわけではありません。
**メンテナが検証しづらいプラットフォームでテストできる方からの PR** は特に歓迎します。

例:

- Linux / systemd 関連の修正
- WSL 固有のワークアラウンド
- クロスプラットフォーム互換性の改善

#### その他の PR

環境依存でない変更は、先に **Prompt Request** や **Issue** で相談いただくのがスムーズです。

特に、次のような変更は **事前相談をほぼ必須** と考えてください:

- 新しい package / workflow / UI 導線を追加する
- CLI / Bridge / mobile / docs をまとめて大きく変える
- 事前文脈なしだと commit 単位でもレビューが重い
- 未マージの別PRの上に積んでいる
- 狭いバグ修正というより、アイデアやプロンプト共有の価値が中心である

PR を送っていただいた場合でも、コードベースの規約やアーキテクチャに合わせるため、クローズした上でメンテナ側で再実装することがあります。その際は:

- コミットに `Co-authored-by` を付与して貢献をクレジットします
- コミットや PR 説明に、何を取り込み何を調整したかを残します

これは PR の否定ではなく、一貫性を保ちつつ貢献を活かすための運用です。

また、複数の独立した変更や広いリファクタ、検証に必須ではない大量の設計ドキュメントを
1本のPRにまとめた場合は、レビュー前に分割をお願いすることがあります。

#### 望ましい PR の形

レビューしやすい PR の目安は次の通りです。

- 1PR 1テーマで、ユーザー価値が明確
- 差分を読むだけで意図が追える規模
- `main` ベースで、未マージPRの上に積まない
- テストまたは具体的な検証結果が付いている
- PRタイトルがConventional Commits形式: `type(scope): concise description`

未マージPRに依存する場合は、そのことを本文に明記して base PR をリンクしてください。
明記がない stacked PR については、`main` に積み直すか、分割するか、Issue での相談に
切り替えていただくことがあります。

#### レビュー方針

CC Pocket は個人プロジェクトとして運営しており、PR レビューは投稿順ではなく
メンテナの余力ベースで行います。

PR を開いただけでは、すぐにレビューが始まるとは限りません。
PR の提出はレビューや採用を保証しません。投稿者が CI と CodeRabbit で受付条件を
満たしてからメンテナレビューへ進みます。未準備の PR の実装を何往復も指導する
運用は行いません。

#### コントリビューションの品質基準

AI を利用した投稿は歓迎します。提出物の根拠と保守負担で判断します。

- **スコープ:** 合意した一つの目的、テスト、必要な説明に変更を絞る。外部PRの非自明な機能、
  新パッケージ、設計変更、および全投稿者の50ファイル超の PR は Issue / Prompt Request で事前合意が必要。
  リンクだけでは合意とみなさない。小さな独立した修正は Issue 不要の理由で代替可能。
  メンテナ自身の50ファイル以下の PR は、本文にスコープ判断を記載すれば別Issueは不要。
- **必要な実装:** 既存パターンを使い、未使用コード・依存、重複実装、現在の利用箇所がない
  拡張点、失敗を隠すフォールバックを持ち込まない。スタイルの好みだけでは止めない。
- **検証根拠:** 主張する動作を確かめるコマンドと結果を示す。バグ修正には回帰テスト、
  自動化が難しければ再現可能な修正前後の検証を示す。docs など低影響の変更はテスト不要の
  具体的な理由を許可する。OS 依存の変更は対象環境での検証を必要とする。

CodeRabbit がこれらを確認します。具体的な指摘への対応や異論の説明はそこで済ませ、
メンテナは製品への適合性と残るリスクに集中します。

#### 自動レビュー準備判定

メンテナによるレビューは、次の条件がすべて揃ってから開始します。

1. Draft が解除され、PR テンプレートが記入済み
2. スコープと検証証拠が `PR Readiness` を通過
3. `Test` Workflow が成功
4. 最新コミットの CodeRabbit レビューが完了し、明示的な Approve、指摘の解決、必須チェックの通過が揃う
5. `status:quality-hold` が付いていない

すべて通過すると `ready-for-maintainer-review` が付き、メンテナへレビューが
依頼されます。新しいコミットを push すると、CI と CodeRabbit がそのコミットを
確認するまで Ready 状態は解除されます。

緑の status や `Review completed` だけでは通過しません。トップレベルの
`@coderabbitai approve` / `@coderabbitai resolve` でレビューや必須チェックを迂回しないでください。
必須チェックが未実行、Inconclusive、ignored の場合はメンテナ判断が必要です。
カスタムチェックを使える CodeRabbit プランと、設定したチェックの実行結果を
メンテナが確認してから運用します。

CodeRabbit の初回フルレビューで品質上の疑いを検出すると `status:quality-hold` が付き、
CI が成功していても Readiness はメンテナ待ちへ進めません。自動クローズや AI 利用の
断定は行いません。訂正後や誤検出時はメンテナがラベルを解除します。`review:override` では
迂回できません。通常のラベル同期で
自動解除せず、incremental review では Slop Detection 自体も再実行されません。

変更ファイル数は次の基準で扱います。

- 1〜50ファイル: 通常受付
- 51〜150ファイル: 事前の Issue / Prompt Request が必須。さらに分割をお願いする場合があります
- 150ファイル超: `status:needs-split` を付け、詳細レビューを行わず分割依頼とともにクローズ

生成ファイルも上限に含みます。例外的なリポジトリ保守ではメンテナが
`review:override` を付けられますが、通常のコントリビューションで上限を回避する
ためのものではありません。

CodeRabbit 設定、GitHub Workflow、PR テンプレート、PR Readiness checker、
エージェントの指示・設定はレビューゲート自体を定義します。これらを変更する
外部PRは自動でメンテナレビュー待ちには進まず、メンテナ作成のPRまたは明示的な
`review:override` が必要です。

レイアウト・外観・操作の UI 変更では PR 本文に Before / After を添付してください。
After の画像または動画は必須です。新規 UI に限り、Before は
`N/A — <理由>` と記載できます。mobile UI 領域を変更して見た目が変わらない場合は、
スクリーンショットが不要な理由を記載してください。
文言だけの変更は、成功した `flutter test ...` のコマンド・結果と画像不要理由で代替できます。

10ファイル以下かつ低リスクなら、補足理由、対象外、分割計画、手動検証、platform は
助言項目です。主目的、自動検証または不要理由、リスク、ロールバック、Author Checklist は
必須です。UI・OS 依存の変更ではそれぞれの検証証拠が必要です。

#### メンテナへの引き継ぎとマージ

Ready 通過後はメンテナ / Codex が取り込みを担当します。小さな設計調整、不足テスト、
競合解消はまとめてこちらで直し、検証してマージします。この段階で投稿者へ
Request Changes を返して往復を増やしません。fork を編集できなければ、クレジットを
残してメンテナブランチへ取り込めます。

Ready は受付条件であり採用の約束ではありません。目的が合わない、修正・検証・継続保守の
負担が価値を上回る場合は見送ります。全 PR の救済や全面再実装は行いません。
こちらで修正した場合も、実際にマージするブランチの最新コミットで CI と CodeRabbit の
通過を確認し、元コミットの Approve を流用しません。

### バグ報告・機能提案

- [Bug Report](https://github.com/K9i-0/ccpocket/issues/new?template=bug_report.yml) — バグの報告
- [Feature Request](https://github.com/K9i-0/ccpocket/issues/new?template=feature_request.yml) — 機能の提案

### プラットフォームのサポート状況

CC Pocket は主に macOS 上で開発しています。
一部の環境は正式サポートではなく、`best-effort` で扱っています。

- Windows 上の Bridge Server: experimental / best-effort
- macOS 上の Flutter mobile app: experimental / best-effort

これらの環境については:

- バグ報告は歓迎しますが、メンテナ側で再現や修正確認ができない場合があります
- Issue だけでメンテナ実装を約束するものではありません
- 修正を通す最短経路は、テストと投稿者側の検証結果つきの小さな PR です

また、修正が Bridge Server の範囲にきれいに閉じる場合は、メインプロジェクトが
特殊環境を長期サポートし続ける前提にするのではなく、fork の方が適切かも併せて
検討してください。MIT ライセンスでは互換性対応の fork が可能ですが、upstream に
取り込まれていない変更は公式 CC Pocket リリースとは明確に分けて扱ってください。

該当環境の Issue では、次の情報を含めてください:

- OS とバージョン
- 関連ツールのバージョン
- 明確な再現手順
- ログ、スクリーンショット、ターミナル出力
- 回避策があればその内容

### Pull Request

#### 貢献のライセンス

このリポジトリに貢献する場合、書面で明示されていない限り、その貢献はリポジトリと同じライセンスで提供されるものとします。

#### 環境依存の PR — 特に歓迎

Windows の Bridge や macOS 版 mobile のような experimental / best-effort 環境向け PR では、特に次を重視します:

- 変更範囲を小さく閉じる
- 可能なら自動テストを追加する
- 対象環境で何を確認したかを明記する
- 必要以上に広いリファクタを避ける

これらの PR は best-effort でレビューします。
正式サポート環境へのリスクが低く、意図が明確なものほど取り込みやすくなります。
Bridge に閉じた互換対応については、メインブランチで恒常的に抱えるより、
別 fork として扱う判断をすることがあります。

### トリアージで使うラベル

Issue / PR には次のようなラベルを付けることがあります:

- `platform:windows` — Windows 固有の報告や変更
- `platform:macos` — macOS 固有の報告や変更
- `status:experimental` — メンテナが継続検証していない best-effort 領域
- `status:unsupported` — 現時点ではサポート対象外
- `needs-repro` — 再現手順の追加が必要
- `needs-test` — 自動テストや検証結果の追加が必要
- `help wanted` — コントリビューション歓迎
- `status:needs-author` — 自動受付、CI、CodeRabbit のいずれかで投稿者の対応が必要
- `status:needs-split` — PR が大きすぎるため分割が必要
- `status:quality-hold` — CodeRabbit の品質検出で保留。解除にはメンテナ判断が必要
- `review:coderabbit` — 受付条件を満たし、CodeRabbit レビュー対象になった
- `ready-for-maintainer-review` — 受付、CI、CodeRabbit Approve をすべて通過
- `risk:high` — セキュリティ、プロトコル、プロセス、リリース境界を変更

### セキュリティ

脆弱性を発見した場合は、公開 Issue ではなく [GitHub Security Advisories](https://github.com/K9i-0/ccpocket/security/advisories/new) から非公開で報告してください。詳細は [SECURITY.md](./SECURITY.md) を参照してください。
