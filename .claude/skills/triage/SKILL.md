---
name: triage
description: GitHub Issue・PRの対応判断、優先度付け、依頼されたPRの取り込みを行う。
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
- 品質基準は `CONTRIBUTING.md` と `.coderabbit.yaml`。AI利用や文章の雰囲気ではなく、スコープ、実装の必要性、検証証拠で判断する。
- Codexフェーズでは投稿者へRequest Changesや修正ラリーを返さない。取り込めるならこちらで直し、費用対効果が悪ければ見送る。
- サブエージェントはMedium/High以上で独立した調査面がある場合だけ使う。
- `--force`時は、バイパスした条件と理由をレポートする。
- `/triage <number>`単独は判断を返す。取り込み・マージまで依頼済みなら修正、検証、マージまで進め、同じ許可を再確認しない。コメント投稿は明示依頼がある場合だけ行う。

## Phase 0: 種別判定

共通のIssue APIで種別を判定する。APIエラーをPR扱いしない。PR判定前にコメントを取得しない。

```bash
gh api "repos/{owner}/{repo}/issues/<number>" \
  --jq '{number,title,body,labels:[.labels[].name],state,author:.user.login,isPR:(.pull_request != null)}'
# PRの場合だけ追加取得。bodyは再取得しない。
gh pr view <number> --json number,isDraft,changedFiles,additions,deletions,headRefOid,reviewDecision,statusCheckRollup
```

Issueなら [references/issue.md](references/issue.md)、PRなら [references/pr.md](references/pr.md) を読む。コメント投稿を依頼された場合だけ [references/comments.md](references/comments.md) を読む。
