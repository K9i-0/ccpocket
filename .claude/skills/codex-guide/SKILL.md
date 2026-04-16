---
name: codex-guide
description: Codex の使い方、CLI/app/IDE、rules・hooks・AGENTS.md・skills・subagents・config などを案内する。Codex や OpenAI 製品の仕様を答える前に必ず公式ドキュメントを確認し、rules/approval は `codex execpolicy check` で実検証すること。
---

# Codex Guide

Codex の使い方や仕様を案内するときのガイド。

## この skill を使う場面

- ユーザーが Codex CLI / app / IDE extension の使い方を聞いたとき
- `rules`, `execpolicy`, approvals, hooks, `AGENTS.md`, skills, subagents, MCP, config を説明するとき
- Codex のモデル、設定、コマンド、slash command、運用方法を案内するとき
- Codex について「本当にそういう仕様か」を確認したいとき

## 基本方針

- **記憶で断定しない。** まず OpenAI の公式 Codex docs を確認する。
- **仕様説明は一次情報優先。** 非公式ブログや推測をベースにしない。
- **rules / approvals は docs だけで終わらせない。** `codex execpolicy check` で実際の判定を確認する。
- **コマンド挙動は再現確認する。** 可能なら軽い実コマンドで `allow` / `prompt` / `forbidden` を確かめる。
- **変わりやすい情報は公式 docs hub から辿る。** 直リンクが変わっていそうなら Codex docs トップから探し直す。

## 標準ワークフロー

### 1. まず公式 docs を探す

用途ごとに `references/official-sources.md` の該当ページを開く。

- Codex 全体像: docs hub / CLI / Academy
- 設定: Config basics / advanced / reference / sample
- approvals / rules: Rules
- カスタマイズ: Skills / Subagents / AGENTS.md / Hooks / MCP
- 実践例: Academy / Use cases / `openai/codex`

### 2. rules / execpolicy の相談なら必ず検証する

変更提案前に、少なくとも以下を実行する。

```bash
codex execpolicy check --pretty --rules <rules-file> -- <command...>
```

最低 2 パターン確認すること。

- 許可したいコマンド
- 止めたい、または prompt にしたいコマンド

部分許可を設計するときは、重なる rule も確認する。

### 3. 実運用に近いコマンドで再確認する

`execpolicy check` だけでなく、可能なら軽い実コマンドでも確認する。

例:

- `allow` 想定の軽いコマンドを 1 本
- `prompt` 想定の軽いコマンドを 1 本

## 特に注意すること

- `prefix_rule` は複数一致する。最終判定は **より厳しい decision が勝つ**。
- 部分 `allow` を書いても、より広い `prompt` が同時一致すると最終的に `prompt` になる。
- 迷ったら「広く `allow`、危ないサブコマンドだけ `prompt`」か、「全部明示列挙」のどちらかで設計する。
- `match` / `not_match` を書ける場面では書く。意図ミスの早期発見に使う。

## 返答のしかた

- 公式 docs を見てわかったことと、ローカルで検証したことを分けて書く。
- 推測が混じる場合は、それが推測だと明示する。
- ルール提案時は、提案内容だけでなく「なぜその rule が最終判定になるか」も書く。

## 参照先

詳細な URL と用途は `references/official-sources.md` を見る。
