---
name: merge
description: 作業ブランチを main にマージして push し、ブランチと worktree を片付ける
allowed-tools: Bash(git:*)
---

# ブランチマージ

作業ブランチを main に `--no-ff` でマージし、push して片付ける。

## 方針

- 検証は必須にしない。マージ直前に足りないと判断したものだけ確認する（例: 未検証の変更、main との競合解消後の該当テスト）。作業中に通った検証は繰り返さない。
- 共有の作業ディレクトリが他のブランチを checkout している場合は、そのブランチを切り替えない。main 用の一時 worktree でマージする。

## 手順

```bash
git fetch origin
git status --short   # 今回の作業の未コミット変更があればコミットする
```

```bash
git worktree add ../<repo>-merge main   # main を checkout できる場所があればそこを使う
cd ../<repo>-merge
git merge --ff-only origin/main
git merge --no-ff <branch>
git push origin main
```

- コンフリクトは両側の意図を確認して解消し、影響範囲だけ検証する。判断できない場合だけユーザーに確認する。
- 後片付け: `git worktree remove` で一時 worktree と `<branch>` の worktree を削除し、`git branch -d <branch>` でブランチを消す。
- 最後に `git log --oneline -3` でマージ結果を報告する。
