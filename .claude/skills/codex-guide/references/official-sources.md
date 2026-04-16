# Official Sources

Codex について案内するときは、まず OpenAI の一次情報を使う。

## Docs Hub

- Codex docs hub  
  `https://developers.openai.com/codex`
  用途: 入口。CLI / Rules / Skills / Subagents / Config / Hooks / AGENTS.md / MCP など全体の導線確認

- Codex product page  
  `https://openai.com/codex`
  用途: プロダクトの大枠、位置づけ、最新の紹介文

## CLI / Usage

- Codex CLI  
  `https://developers.openai.com/codex/cli`
  用途: CLI の概要、基本的な使い方

- Codex CLI command line options  
  `https://developers.openai.com/codex/cli/reference`
  用途: CLI オプション、フラグ、起動方法

- Codex CLI slash commands  
  `https://developers.openai.com/codex/cli/slash-commands`
  用途: slash command の確認

## Configuration / Policy

- Rules  
  `https://developers.openai.com/codex/rules`
  用途: `prefix_rule`, `decision`, shell wrapper, `codex execpolicy check`

- Config basics  
  `https://developers.openai.com/codex/config-basic`
  用途: `config.toml` の基本

- Advanced configuration  
  `https://developers.openai.com/codex/config-advanced`
  用途: 高度な設定、運用よりの構成

- Configuration reference  
  `https://developers.openai.com/codex/config-reference`
  用途: 設定項目の正確な意味を確認するとき

- Sample configuration  
  `https://developers.openai.com/codex/config-sample`
  用途: 実例ベースで設定を組むとき

## Customization

- Skills  
  `https://developers.openai.com/codex/skills`
  用途: skills の仕組み、書き方、運用

- Subagents  
  `https://developers.openai.com/codex/subagents`
  用途: subagent の概念と設定

- AGENTS.md  
  `https://developers.openai.com/codex/guides/agents-md`
  用途: カスタム指示ファイルの使い方

- Hooks  
  `https://developers.openai.com/codex/hooks`
  用途: hook の構成と運用

- MCP  
  `https://developers.openai.com/codex/mcp`
  用途: MCP の統合、設定、考え方

## Prompting / Workflows

- Codex Prompting Guide  
  `https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide`
  用途: Codex への依頼の組み立て、プロンプトの指針

- Codex use cases  
  `https://developers.openai.com/codex/use-cases`
  用途: 実タスクのやらせ方、典型ワークフロー

- OpenAI Academy: Codex  
  `https://openai.com/academy/codex/`
  用途: 実践寄りの学習導線、ワークフロー理解

## Open Source Repos

- `openai/codex`  
  `https://github.com/openai/codex`
  用途: OSS CLI 本体、issue、実装寄りの確認

- `openai/skills`  
  `https://github.com/openai/skills`
  用途: Codex 向け skill の参考実装

## 運用メモ

- URL が変わっていそうなら、まず `https://developers.openai.com/codex` から辿り直す。
- rules/approval 相談は docs を読んだだけで終わらせず、必ず `codex execpolicy check` で確認する。
- 仕様説明に迷ったら、docs hub → 該当ページ → 実コマンド検証の順で進める。
