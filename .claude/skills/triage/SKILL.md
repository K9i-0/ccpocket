---
name: triage
description: "GitHub Issue・PRを低トークンでトリアージし、要望、実現難易度、重複、リスク、対応判断をレポートする。Issue/PR番号、トリアージ、優先度、対応判断、PRレビュー準備判定を依頼されたときに使用する。PRはReadiness、CI、CodeRabbitを先に確認し、未通過ならdiffを読まず終了する。"
---

# Issue / PR Triage

番号からIssueまたはPRを判定し、対応判断に必要な最小限の調査を行う。

```text
/triage 42
/triage #8
/triage #8 --force  # CodeRabbit障害や緊急時のメンテナ例外
```

## 原則

- PRでは必ずReadiness判定を最初に行う。
- ReadyでないPRのdiff、全コメント、コードベースを読まない。
- CodeRabbitの指摘を再レビューせず、製品判断・設計・高リスク箇所に集中する。
- サブエージェントはMedium/High以上で独立した調査面がある場合だけ使う。
- `--force`時は、バイパスした条件と理由をレポートする。
- コメント投稿、ラベル変更、クローズなどのGitHub更新は、ユーザーが依頼した場合だけ行う。

## Phase 0: 種別判定

まずIssueとして取得し、取得できなければPRとして扱う。

```bash
gh issue view <number> --json number,title,body,labels,state,comments,author,createdAt
gh pr view <number> --json number,title,body,labels,state,isDraft,author,createdAt,changedFiles,additions,deletions,headRefOid,reviewDecision,statusCheckRollup
```

Issueなら「Issueフロー」、PRなら「PRフロー」へ進む。

## PRフロー

### Phase 1: Intake / Ready判定

このPhaseではPR本文、件数、ラベル、チェック状態だけを見る。ファイル内容や全diffは取得しない。

次を順番に確認する。

1. **ファイル数**
   - 1〜50: 通常
   - 51〜150: 関連Issue / Prompt Requestと分割不能理由を必須とする
   - 150超: `NOT READY`。Size以外のgateは判定せず、分割依頼とクローズだけを推奨して、ここで終了する
2. **Draft**: Draftなら`NOT READY`
3. **レビュー基盤**: 外部PRが`.coderabbit.yaml`、`.github/workflows/**`、PRテンプレート、PR Readiness checker、エージェント指示・設定を変更する場合、メンテナの`review:override`がなければ`NOT READY`
4. **PR本文**: テンプレートの必須欄とAuthor Checklistを確認する
5. **UI証拠**
   - visible UI変更: Before / Afterとdevice/platformを必須とする
   - 新規UI: Beforeは`N/A — 理由`を許可する
   - mobile UI領域の非表示変更: スクリーンショット不要理由を必須とする
6. **PR Readiness status**: 最新head commitで成功していることを確認する
7. **CI**: `Test` workflowが成功していることを確認する
8. **CodeRabbit**: 最新head commitがApprove済みで、未解決のRequest Changesがないことを確認する
9. **Ready label**: `ready-for-maintainer-review`が付いていることを確認する

必要ならレビュー状態だけを小さく取得する。本文は取得しない。

```bash
gh pr view <number> --json files --jq '[.files[].path]'
gh pr view <number> --json statusCheckRollup --jq '.statusCheckRollup'
gh api "repos/{owner}/{repo}/pulls/<number>/reviews?per_page=100" --paginate \
  --jq '[.[] | {author: .user.login, state, commitId: .commit_id, submittedAt: .submitted_at}]'
```

いずれかが未通過なら、次の短い形式で終了する。diff取得、既存コード調査、サブエージェント起動を禁止する。

150ファイル超では次の最小形式を使う。投稿者へCI、CodeRabbit、テンプレート、Ready labelの対応を同時に求めない。Ready labelは自動化が付けるため、投稿者に手動付与を求めない。

```markdown
## PR Readiness: NOT READY — #<number> <title>

- Size: ❌ <count> files（上限150超）
- 対応: 現PRをクローズし、150ファイル以下に分割して再提出する

Size gateで終了し、他のgateとdiffは確認していません。
```

```markdown
## PR Readiness: NOT READY — #<number> <title>

| Gate | Status |
| --- | --- |
| Size | [status] |
| Template | [status] |
| UI evidence | [status] |
| CI | [status] |
| CodeRabbit | [status] |

### 投稿者に必要な対応
- [不足項目だけを列挙]

深掘りレビューはまだ実施していません。
```

`--force`が指定された場合だけPhase 2へ進み、未通過条件を冒頭に残す。

### Phase 2: Risk map

ReadyなPRだけ、変更ファイル名とCodeRabbitのwalkthrough・指摘要約を確認する。

```bash
gh pr view <number> --json files --jq '.files[] | {path, additions, deletions}'
gh pr view <number> --json comments,reviews --jq '{comments, reviews}'
```

変更を次のリスクに分類する。

| リスク | 例 | 深掘り方針 |
| --- | --- | --- |
| Low | docs、単純UI、既存パターン | CodeRabbitとの差分だけ確認 |
| Medium | 複数モジュール、状態管理、API拡張 | 関連patchとテストを確認 |
| High | 認証、filesystem、process、protocol、Functions | 境界と失敗経路を詳細確認 |
| Very High | release/signing、権限モデル、アーキテクチャ | メンテナ判断を優先し広く確認 |

常に高リスクとして扱うパス:

- Phase 1の「レビュー基盤」に該当する全パス（`.coderabbit.yaml`、PRテンプレート、PR Readiness checker、エージェント指示・設定）
- `.github/workflows/**`
- `packages/bridge/src/websocket.ts`
- `packages/bridge/src/*process.ts`
- `functions/**`
- `firestore.rules`, `firebase.json`
- release / patch / submit / signing関連スクリプト

### Phase 3: Targeted review

Risk mapで選んだファイルとテストから読む。REST APIのfile patchを優先し、必要な場合だけ全diffを取得する。

```bash
gh api "repos/{owner}/{repo}/pulls/<number>/files?per_page=100" --paginate --slurp \
  --jq '.[][] | select(.filename == "<selected-path>") | {filename, status, additions, deletions, patch}'

# patchが欠落・切り詰められ、判断できない場合のみ
gh pr diff <number>
```

確認観点:

- 変更の目的と実装が一致しているか
- 既存機能との重複がないか
- CodeRabbitが扱いにくい製品判断・UX・保守負荷
- テストが意図と失敗経路を担保しているか
- Bridge + Flutter間のプロトコル互換性
- 認証、許可ディレクトリ、path traversal、process cleanup、secret
- 正式サポート環境への回帰リスク

Medium/High以上でBridgeとFlutterなど独立した調査面がある場合だけ、Exploreサブエージェントへ対象を限定して依頼する。Lowまたは単一ファイルでは使わない。

### Phase 4: PRレポート

```markdown
## Triage Report: #<number> <title>

### Review Readiness: READY / FORCED
[CI、CodeRabbit、UI証拠、override理由]

### 概要・種別・プラットフォーム
[1〜3文]

### 変更規模・リスク
- Files: [count]
- Risk: [Low / Medium / High / Very High]
- High-risk areas: [paths or none]

### 既存機能・重複
[結果]

### 主な確認結果
- [CodeRabbitと重複しない重要事項]

### 対応判断
| 観点 | 評価 |
| --- | --- |
| ユーザー価値 | [高/中/低 — 理由] |
| 取り込みコスト | [高/中/低 — 理由] |
| 回帰・保守リスク | [高/中/低 — 理由] |
| 推奨 | [直接マージ / 修正依頼 / 部分取り込み / 再実装 / 見送り] |

### 推奨アクション
- [具体的な次の手順]
```

## Issueフロー

### 情報収集

- タイトル、本文、ラベル、コメントからBug / Feature / Prompt Requestを判定する。
- 再現手順、期待結果、実際の結果、環境、ログを確認する。
- 関連コードはキーワードと機能単位で絞って調査する。
- 既存機能、重複Issue、上流のClaude Code / Codex起因を確認する。

### プラットフォーム判定

- 正式サポート: メンテナが日常的に検証できる
- experimental / best-effort: Windows Bridge、macOS mobileなど
- 未サポート: 再現・修正・保守を約束しない

experimental / 未サポート環境では次を追加で見る。

- 投稿者が対象環境で検証したか
- 純粋関数や自動テストで担保できるか
- spawn、shell、filesystem、GUI、OS APIに依存するか
- 正式サポート環境へ影響するか

### 難易度

| 難易度 | 基準 | 目安 |
| --- | --- | --- |
| Low | 単一ファイル、既存パターン | 〜1時間 |
| Medium | 複数ファイル、Widget/API拡張 | 数時間 |
| High | Bridge + Flutter、protocol変更 | 1日以上 |
| Very High | アーキテクチャ、外部依存、権限モデル | 数日以上 |

### Issueレポート

```markdown
## Triage Report: #<number> <title>

### 概要・種別・プラットフォーム
[要約]

### 推奨ラベル
- [labels]

### 既存機能・重複
[結果]

### 実現難易度: [Low / Medium / High / Very High]
[根拠となるファイル、protocol変更、影響範囲]

### 対応判断
| 観点 | 評価 |
| --- | --- |
| ユーザー価値 | [高/中/低 — 理由] |
| 実装コスト | [高/中/低 — 理由] |
| リスク | [高/中/低 — 理由] |
| 推奨 | [対応 / 外部PR待ち / 保留 / 見送り] |

### 推奨アクション
- [具体的な次の手順]
```

## 種別ごとの補足

### Bug

- 再現性、影響範囲、回避策、上流起因を確認する。
- 未サポート環境で再現不能なら`needs-repro`、`needs-test`、`help wanted`を検討する。
- 実環境依存の修正は投稿者側の検証結果を必須にする。

### Feature / Prompt Request

- 方向性、ユーザー価値、代替手段、プロンプトの再現性を確認する。
- 大規模なコードPRより、Issue / Prompt Requestでの合意を優先する。

### Dependabot

- breaking changes、upstream changelog、CIを確認する。
- major updateまたは高リスク依存だけ深掘りする。

### 外部PRの取り込み

全PRを再実装しない。品質とリスクで選ぶ。

- 小規模、Ready、規約準拠: 直接マージ候補
- 一部調整が必要: 投稿者へ修正依頼または部分取り込み
- 設計不一致、大規模、高リスク: Prompt Requestへ戻すか参考にして再実装

投稿者のコードを部分取り込みまたは再実装した場合は`Co-authored-by`でクレジットし、取り込んだ点と調整点を説明する。

```bash
gh api users/<username> --jq '.name, .email, .id'
```

公開メールがなければ`<id>+<username>@users.noreply.github.com`を使う。

## コメント言語と投稿

- 英語の投稿には英語だけで返信する。
- 英語以外には元の言語を先に書き、`---`の後に英語を付ける。
- 複数段落は一時ファイルを`--body-file`で渡す。
- 投稿後に取得し直し、Markdownを確認する。

```bash
gh pr comment <number> --body-file /tmp/ccpocket-pr-comment.md
gh issue comment <number> --body-file /tmp/ccpocket-issue-comment.md
```
