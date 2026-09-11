## PRフロー

### Phase 1: Intake / Ready判定

このPhaseではPR本文、件数、ラベル、チェック状態だけを見る。ファイル内容や全diffは取得しない。

次を順番に確認する。

1. **ファイル数**
   - 1〜50: 通常
   - 51〜150: 関連Issue / Prompt Requestと分割不能理由を必須とする
   - 150超: `NOT READY`。Size以外のgateは判定せず、分割依頼とクローズだけを推奨して、ここで終了する
2. **Draft**: Draftなら`NOT READY`
3. **品質保留**: `status:quality-hold`があれば`NOT READY`として終了。`--force`や`review:override`でも進めず、訂正後・誤検出時にメンテナがラベルを明示解除する。自動クローズやAI利用だけを理由とした拒否はしない。
4. **レビュー基盤**: 外部PRが`.coderabbit.yaml`、`.github/workflows/**`、PRテンプレート、PR Readiness checker、エージェント指示・設定を変更する場合、メンテナの`review:override`がなければ`NOT READY`
5. **PR本文**: テンプレートの必須欄とAuthor Checklistを確認する。10ファイル以下かつ低リスクでは、補足理由、対象外、分割計画、手動検証、platformはReadiness上の助言項目。OS依存の変更では対象環境の検証証拠を必須とする。
   - メンテナ自身の50ファイル以下のPRは、スコープ判断を本文に残せば別Issue不要。外部PRの非自明な変更と全投稿者の50ファイル超にはIssue / Prompt Requestでの合意を求める。
6. **UI証拠**
   - レイアウト・外観・操作変更: Before / Afterとdevice/platformを必須とする
   - 新規UI: Beforeは`N/A — 理由`を許可する
   - 文言のみ: 成功した `flutter test ...` のコマンド・結果と画像不要理由で代替可能
   - mobile UI領域の非表示変更: スクリーンショット不要理由を必須とする
7. **PR Readiness status**: 最新head commitで成功していることを確認する
8. **CI**: `Test` workflowが成功していることを確認する
9. **CodeRabbit**: 最新headのレビュー完了と明示的なApprove、未解決Request Changesなしを必須とする。`Review completed`や緑のstatusだけでは不足。
10. **Ready label**: `ready-for-maintainer-review`が付いていることを確認する

必要ならレビュー状態だけを小さく取得する。本文は取得しない。

```bash
gh pr view <number> --json files --jq '[.files[].path]'
gh pr view <number> --json statusCheckRollup --jq '.statusCheckRollup'
gh api "repos/{owner}/{repo}/pulls/<number>/reviews?per_page=100" --paginate \
  --jq '[.[] | {author: .user.login, state, commitId: .commit_id, submittedAt: .submitted_at}]'
```

自動Readinessが成功していても、CodeRabbit walkthroughの設定済み必須チェックが未実行、Inconclusive、無断でignoredなら通常のReadyとして扱わない。詳細な指摘の再レビューは不要。利用プラン・障害でチェックできない場合は基盤の問題として報告し、投稿者に同じ修正を繰り返させない。

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
| Quality hold | [status] |
| Template | [status] |
| UI evidence | [status] |
| CI | [status] |
| CodeRabbit | [status] |

### 投稿者に必要な対応
- [不足項目だけを列挙]

深掘りレビューはまだ実施していません。
```

品質保留を除き、`--force`、またはメンテナの理由付き`review:override`がある場合だけ未通過でもPhase 2へ進み、未通過条件を冒頭に残す。通常の取り込み修正のためにoverrideを使わない。

### Phase 2: Risk map

ReadyなPRだけ、変更ファイル名とCodeRabbitの最新walkthrough・指摘要約を確認する。Phase 1で取得済みの情報は再利用する。

```bash
gh pr view <number> --json files --jq '.files[] | {path, additions, deletions}'
# Phase 1の必須チェック確認でもこれを使い、最新のbotコメントだけ出力する。
gh api "repos/{owner}/{repo}/issues/<number>/comments?per_page=100" --paginate --slurp \
  --jq '[.[][] | select(.user.login == "coderabbitai[bot]" or .user.login == "coderabbitai") | select(.body | contains("<!-- walkthrough_start -->"))] | max_by(.updated_at) | {body,html_url}'
```

walkthroughの形式が変わった場合も最新のbot要約だけを取得し、全コメント・全レビュー本文を出力しない。製品価値が低い、合意した目的と違う、保守できないことがここで明白なら`見送り`で終了する。

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

読む範囲を広げるのは未解決の具体的な疑問がある場合だけ。Lowでは目的と関連patchが一致し、既存パターン・検証証拠に問題がなければ終了する。CodeRabbitの全指摘の追認や全リポジトリ再レビューをしない。

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
| 推奨 | [直接マージ / こちらで修正してマージ / 部分取り込み / 見送り] |

### 推奨アクション
- [具体的な次の手順]
```

Lowでは「Ready根拠・目的・リスク・判断・こちらで直す点」を数行で返せばよい。形式を埋めるための追加調査をしない。

### 外部PRの取り込み

Ready通過後の担当はメンテナ / Codex。投稿者へのRequest Changes、修正依頼コメント、細かな再提出要求を選択肢にしない。事前ゲートへの対応は投稿者とCodeRabbitに任せる。

- 小規模、Ready、規約準拠: 直接マージ候補
- 目的に合い、残作業と検証方法が具体的: こちらで修正してマージ。命名・小さな設計調整・不足テスト・競合解消はまとめて処理する
- 一部だけ有用: 小さなメンテナブランチに部分取り込みして検証する
- 価値より修正・検証・継続保守の負担が大きい、目的不一致、対象環境で検証不能: 見送り。救済のための全面再実装や無期限の修正を始めない

取り込みまで依頼されている場合:

1. 対象head SHAを記録し、隔離したブランチ / worktreeで修正する。forkの更新権限がなければメンテナブランチへ取り込み、投稿者への依頼待ちにしない。
2. 必要な修正を一度にまとめ、変更領域に応じた検証とセルフレビューを行う。修正でReadyが外れても対応担当はCodexのまま。
3. 実際にマージするブランチの最新headでCI、CodeRabbit、必要なUI証拠を再確認する。古いApproveを流用せず、リモートheadが変わったら差分を確認する。
4. マージ依頼があれば検証済みheadに限定してマージする。別PRで取り込んだ場合の元PRのクローズは取り込みの完了処理として行い、コメントは明示依頼時だけ投稿する。

CodeRabbitの `approve` / トップレベルの `resolve` コマンドはレビュー完了や必須チェックを迂回し得るため、通常の通過手段に使わない。

投稿者のコードを部分取り込みまたは再実装した場合は`Co-authored-by`でクレジットし、取り込んだ点と調整点をコミット / PR説明に残す。

```bash
gh api users/<username> --jq '.name, .email, .id'
```

公開メールがなければ`<id>+<username>@users.noreply.github.com`を使う。
