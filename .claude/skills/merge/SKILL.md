---
name: merge
description: ブランチをメインにマージしてお掃除する
disable-model-invocation: true
allowed-tools: Bash(git:*)
---

# ブランチマージ & クリーンアップ

作業ブランチを main にマージし、不要になったブランチと worktree を削除する。

## 前提条件

- 作業ブランチで全ての変更がコミット済みであること
- 現在のブランチが main **でない**こと

## 手順

### 1. 事前確認

```bash
git branch --show-current
```

- 現在のブランチ名を記録する（= `<branch>` とする）
- `main` の場合はマージ対象がないため中断する

```bash
git status --short
```

- 未コミットの変更がある場合は中断し、先にコミットするよう促す

### 2. main に切り替え

```bash
git checkout main
```

### 3. マージ (--no-ff)

```bash
git merge --no-ff <branch>
```

- マージコンフリクトが発生した場合は中断してユーザーに報告する

### 4. 作業ブランチの削除

```bash
git branch -d <branch>
```

### 5. worktree のクリーンアップ

```bash
git worktree list
```

- `<branch>` に紐づく worktree がある場合のみ以下を実行:

```bash
git worktree remove <worktree-path>
```

- worktree ディレクトリが残っている場合は手動削除が必要な旨を通知する

### 6. 完了報告

最終状態を表示する:

```bash
git log --oneline -5
git branch
git worktree list
```
