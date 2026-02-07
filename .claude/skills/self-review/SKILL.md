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

### Phase 2: Claude subagent レビュー（別コンテキスト視点）

Task toolで別コンテキストのレビューエージェントを起動:

```
subagent_type: general-purpose

プロンプト:
---
以下のコード変更をレビューしてください。

## 変更ファイル
[git diff --name-only HEADの結果]

## 変更内容
[git diff HEADの結果]

## レビュー観点（すべてチェック）

### 共通観点
1. コード品質（可読性、命名、構造化）
2. バグ・エラー（null安全性、エッジケース、例外処理、メモリリーク）
3. 設計パターン（アーキテクチャ整合性、依存関係、重複コード）

### Dart/Flutter固有
4. Bloc/Cubitパターンの適切な使用
5. Freezed状態クラスの設計
6. Widget分割（_buildXxxメソッド禁止）
7. ValueKey命名（MCP自動テスト対応）

### TypeScript固有（Bridge Server変更時）
8. ESM + strict mode 準拠
9. NodeNext module resolution (.js拡張子)
10. stream-json パース処理の正確性

## 出力形式
- 重大な問題: [ファイル:行] [問題の説明と修正提案]
- 軽微な問題: [ファイル:行] [問題の説明]
- 問題なし: 'LGTM'

日本語で回答してください。
---
```

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
| 中 | 31-100行 | subagentレビュー |
| 大 | 100行以上 | subagentレビュー + 詳細分析 |

## 出力テンプレート

```markdown
## Self Review Result

### Claude subagent Review
[subagentからの出力]

### 判定: [PASS/MINOR/FAIL]

#### 問題点（該当する場合）
- [ ] [ファイル:行] [問題の説明]

#### 次のアクション
- [タスク完了可 / 修正必要]
```
