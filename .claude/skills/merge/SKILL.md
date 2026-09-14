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

- 未コミットの変更があれば、今回の作業に属する変更だけを検証してコミットする。無関係な変更は混ぜず、上書きせずにマージできる作業場所を使う。変更の帰属が判断できずマージを妨げる場合だけ確認する。

### 2. main に切り替え

```bash
git checkout main
```

### 3. マージ (--no-ff)

```bash
git merge --no-ff <branch>
```

- マージコンフリクトは両側の変更意図を調べて解消し、関連する検証を実施してマージを完了する。意図が両立せず、コードや依頼から判断できない場合だけ、競合箇所と選択による違いを示して確認する。

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
