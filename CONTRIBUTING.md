# Contributing to CC Pocket

Thank you for your interest in contributing to CC Pocket!

## Prompt Request — Contributing in the AI Era

CC Pocket is a mobile client for Claude Code / Codex.
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
- **Environment**: The AI tool you used (Claude Code, Codex, etc.)

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
whether unofficial Bridge redistribution is a better fit than asking the main
project to carry long-term support for a niche environment. The project license
explicitly allows unofficial Bridge redistributions for these compatibility
cases, as long as they remain clearly unofficial and unsupported.

If you file an Issue for one of these environments, please include:

- Exact OS and version
- Tool versions involved
- Clear reproduction steps
- Logs, screenshots, or terminal output
- Any workaround you found

## Pull Requests

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

For Bridge-only compatibility work, we may decide that redistribution of an
unofficial Bridge build or fork is the more sustainable outcome than ongoing
first-party support in the main project.

PRs for these platforms are reviewed on a best-effort basis.
We are more likely to merge changes that are easy to reason about and low risk for supported platforms.

### Other PRs

For changes that don't require a specific environment, we recommend opening a **Prompt Request** or **Issue** first.

If you do send a PR, we may close it and re-implement the change ourselves to fit the codebase's conventions and architecture. In that case:

- Your contribution will be credited via `Co-authored-by` in the commit
- We'll comment on the PR explaining what we incorporated and what we adjusted

This isn't a rejection of your work — it's how we maintain consistency while honoring your contribution.

### Labels You May See

Maintainers may apply labels like these when triaging Issues and PRs:

- `platform:windows` — Windows-specific report or change
- `platform:macos` — macOS-specific report or change
- `status:experimental` — best-effort area, not continuously verified by maintainers
- `status:unsupported` — outside the project's current support commitment
- `needs-repro` — more precise reproduction details are needed
- `needs-test` — automated tests or validation evidence are needed
- `help wanted` — contributions are welcome

## Security

If you discover a vulnerability, please report it privately via [GitHub Security Advisories](https://github.com/K9i-0/ccpocket/security/advisories/new) rather than opening a public Issue. See [SECURITY.md](./SECURITY.md) for details.

---

## 日本語 / Japanese

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

PR を送っていただいた場合でも、コードベースの規約やアーキテクチャに合わせるため、クローズした上でメンテナ側で再実装することがあります。その際は:

- コミットに `Co-authored-by` を付与して貢献をクレジットします
- PR コメントで、何を取り込み何を調整したかを説明します

これは PR の否定ではなく、一貫性を保ちつつ貢献を活かすための運用です。

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
特殊環境を長期サポートし続ける前提にするのではなく、非公式 Bridge 再配布の
方が適切かも併せて検討してください。ライセンス上、その種の互換性対応を目的と
した Bridge の非公式再配布は、非公式かつ無保証であることを明示する限り許可
されています。

該当環境の Issue では、次の情報を含めてください:

- OS とバージョン
- 関連ツールのバージョン
- 明確な再現手順
- ログ、スクリーンショット、ターミナル出力
- 回避策があればその内容

### Pull Request

#### 環境依存の PR — 特に歓迎

Windows の Bridge や macOS 版 mobile のような experimental / best-effort 環境向け PR では、特に次を重視します:

- 変更範囲を小さく閉じる
- 可能なら自動テストを追加する
- 対象環境で何を確認したかを明記する
- 必要以上に広いリファクタを避ける

これらの PR は best-effort でレビューします。
正式サポート環境へのリスクが低く、意図が明確なものほど取り込みやすくなります。
Bridge に閉じた互換対応については、メインブランチで恒常的に抱えるより、
非公式 build / fork の再配布を選ぶ判断をすることがあります。

### トリアージで使うラベル

Issue / PR には次のようなラベルを付けることがあります:

- `platform:windows` — Windows 固有の報告や変更
- `platform:macos` — macOS 固有の報告や変更
- `status:experimental` — メンテナが継続検証していない best-effort 領域
- `status:unsupported` — 現時点ではサポート対象外
- `needs-repro` — 再現手順の追加が必要
- `needs-test` — 自動テストや検証結果の追加が必要
- `help wanted` — コントリビューション歓迎

### セキュリティ

脆弱性を発見した場合は、公開 Issue ではなく [GitHub Security Advisories](https://github.com/K9i-0/ccpocket/security/advisories/new) から非公開で報告してください。詳細は [SECURITY.md](./SECURITY.md) を参照してください。
