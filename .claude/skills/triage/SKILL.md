---
name: triage
description: GitHub Issueの対応判断と、PRの調査・手直し・検証・マージを行う。PR指定時は取り込みまで進めるのが既定。
---

# Issue / PR Triage

番号またはURLからIssue / PRを判定する。

```text
/triage 42
/triage https://github.com/K9i-0/ccpocket/pull/42
/triage 42 内容だけ教えて
```

## 既定動作

- **PRを指定されたら、必要な修正・検証をこちらで引き受け、マージとお礼コメントまで進める。** 判断や推奨だけで止めず、同じ取り込み許可を再確認しない。
- 「内容だけ」「レビューだけ」「まだマージしない」など明示された範囲を優先する。スキル自体の相談・改善は、例示されたPRの取り込み依頼ではない。
- Issue単独は対応判断を返す。実装は依頼範囲に含まれる場合に進める。
- Readiness、ラベル、テンプレートの充足、CodeRabbitのApproveを調査開始・採用の条件にしない。旧`--force`は不要で、付いていても同じ手順を使う。
- ユーザーが `/triage`、`$triage`、または自然文でtriageを明示的に依頼した場合、対象PRの旧 `PR Readiness` のバイパスは継続承認済みとして扱い、再確認せず取り込む。レビュー・検証は省略せず、実行方法と範囲は [references/pr.md](references/pr.md) に従う。「内容だけ」などの範囲指定は引き続き優先する。
- CodeRabbitは調査負荷を減らす参考情報。具体的な指摘を必要に応じて検証し、未完了・未承認だけでは待たない。
- 実装・コードレビュー・テスト操作をAIに任せることは問題にしない。投稿者が示した目的、修正方針の判断、実際の検証結果と限界を確認する。人柄や「本気度」を点数化しない。
- 不足テスト、小さな設計調整、競合は原則こちらで処理する。重大な目的不一致や取り込みに見合わない再実装は、具体的な理由を示して見送る。

## 種別判定と参照

URL指定ならそのリポジトリを使う。番号のみなら現在のリポジトリを使う。APIエラーをPR扱いしない。

```bash
gh api "repos/{owner}/{repo}/issues/<number>" \
  --jq '{number,title,body,labels:[.labels[].name],state,author:.user.login,isPR:(.pull_request != null)}'
```

- Issue: [references/issue.md](references/issue.md)
- PR: [references/pr.md](references/pr.md)
- マージ後のお礼、または依頼されたコメント: [references/comments.md](references/comments.md)
