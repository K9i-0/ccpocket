---
name: self-review
description: タスク完了前のセルフレビュー。Claude subagentで別コンテキストから客観的にコード変更を検証。
---

# Self Review

タスク完了前に実行するセルフレビュー手順。

## トリガー条件

- ユーザーから `/self-review` コマンドで呼び出された場合
- 大きな変更をコミットする前

## レビュー手順

### Phase 1: 変更差分の収集

```bash
# 変更されたファイル一覧
git diff --name-only HEAD

# 変更内容の取得
git diff HEAD

# 変更行数で規模判定
git diff --stat HEAD | tail -1
```

### Phase 2: サブエージェントレビュー（`code-reviewer` エージェント）

**`code-reviewer` サブエージェント**を使ってレビューを実行する。

```
Task tool で code-reviewer サブエージェントを起動:

subagent_type: code-reviewer
model: opus

プロンプト:
---
以下のコード変更をレビューしてください。

## 変更ファイル
[git diff --name-only HEADの結果]

## 変更内容
[git diff HEADの結果]

重大な問題がなければ 'LGTM' と回答してください。
日本語で回答してください。
---
```

**注意:** 変更規模が小（~30行以下）の場合はサブエージェント不要、自己レビューのみでOK。

### Phase 3: 判定

| 判定 | 条件 | アクション |
|------|------|----------|
| PASS | LGTM | タスク完了可 |
| MINOR | 軽微な問題のみ | 警告表示後、タスク完了可 |
| FAIL | 重大な問題あり | 修正後に再レビュー |

### Phase 4: フィードバックループ

FAIL判定の場合:
1. 指摘された問題箇所を修正
2. Phase 1-3 を再実行
3. PASSになるまで繰り返し

## 変更規模による調整

```bash
git diff --stat HEAD | tail -1
```

| 変更規模 | 行数目安 | レビュー方法 |
|---------|---------|-------------|
| 小 | ~30行 | 自己レビューのみ（subagent不要） |
| 中 | 31-100行 | code-reviewer サブエージェント |
| 大 | 100行以上 | code-reviewer サブエージェント + 詳細分析 |

## 出力テンプレート

```markdown
## Self Review Result

### Claude subagent Review
[code-reviewer サブエージェントからの出力]

### 判定: [PASS/MINOR/FAIL]

#### 問題点（該当する場合）
- [ ] [ファイル:行] [問題の説明]

#### 次のアクション
- [タスク完了可 / 修正必要]
```
