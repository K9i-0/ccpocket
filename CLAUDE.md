# ccpocket

Claude Code / Codex 対応モバイルクライアント。Bridge は `packages/bridge/`（TypeScript / WebSocket）、アプリは `apps/mobile/`（Flutter / Dart）。npm workspaces を使う。

## 作業と完了条件

- 依頼された変更に必要な実装・検証・不具合修正まで継続する。指定済みの対象や承認を繰り返し確認しない。
- 計画には、その変更に必要な実装・検証・レビューを含める。調査や文書編集にアプリ起動・E2E・Webビルドを一律に追加しない。
- プロトコルやサービス境界を変更する複雑な実装では、判断と互換性方針を `docs/` に残す。
- 検証は変更範囲とリスクに応じて選ぶ。成功済みの検証は、新たな変更・失敗・未解決の懸念がなければ繰り返さない。
- 関連するローカル検証と、今回の変更に起因する失敗の修正・再検証は続けて行う。既存の無関係な問題は報告し、作業範囲を広げない。
- 機能単位でコミットする。Conventional Commits (`type(scope): description`) を使う。

## 変更対象ごとの参照

- Bridge のテスト・型チェック: [.claude/skills/test-bridge/SKILL.md](.claude/skills/test-bridge/SKILL.md)
- Flutter のテスト・解析・整形: [.claude/skills/test-flutter/SKILL.md](.claude/skills/test-flutter/SKILL.md)
- Flutter UI の構成・状態管理: [.claude/skills/flutter-ui-design/SKILL.md](.claude/skills/flutter-ui-design/SKILL.md)
- UIの実行時検証・Bridgeとの統合検証が必要な場合: [.claude/skills/mobile-automation/SKILL.md](.claude/skills/mobile-automation/SKILL.md)
- 独立レビューが有効な変更、またはレビュー依頼: [.claude/skills/self-review/SKILL.md](.claude/skills/self-review/SKILL.md)
- ブラウザでのプレビューが必要な場合: [.claude/skills/web-preview/SKILL.md](.claude/skills/web-preview/SKILL.md)
- シミュレーターをリモートで見せる場合: [.claude/skills/sim-preview/SKILL.md](.claude/skills/sim-preview/SKILL.md)
- プロジェクト構成・接続設定・環境変数・プロトコルの概要: [docs/agent-project-reference.md](docs/agent-project-reference.md)。実際の型・設定はコードと照合する。

Bridge と Flutter の両方を変更する場合は両方の検証を選ぶ。文書のみの変更は参照・形式・内容を検証する。

## 運用上の制約

- 本番Bridgeの既定ポートは `8765`。E2Eでは別のテスト用Bridge（既定 `8766`）を使い、本番を停止・再起動しない。終了時は自分が起動したプロセスだけ停止する。
- ランタイム操作は dart-mcp / Marionette、テスト・静的解析・フォーマットはCLIを使う。詳細は `mobile-automation` を参照。
- 新しいクライアントメッセージは古いBridgeの `unsupported_message` に対応する。通常チャットは `_unsupportedActions`、直接応答を待つ専用UIはそのUI内で更新案内を扱う。
- TypeScript は ESM / strict / NodeNext module resolution。

## リリース・配布

依頼された操作に対応するスキルを読む。リリース作成と既存ビルドの審査提出は別の操作。

- Bridgeリリース: [.claude/skills/release-bridge/SKILL.md](.claude/skills/release-bridge/SKILL.md)
- アプリリリース: [.claude/skills/release-app/SKILL.md](.claude/skills/release-app/SKILL.md)
- 既存ビルドの審査提出: [.claude/skills/submit-store-review/SKILL.md](.claude/skills/submit-store-review/SKILL.md)
- OTAパッチ: [.claude/skills/shorebird-patch/SKILL.md](.claude/skills/shorebird-patch/SKILL.md)。既定はstaging。stable昇格はユーザーが行う。
- ストア素材・説明文: [.claude/skills/update-store/SKILL.md](.claude/skills/update-store/SKILL.md)
- ブランチのマージ: [.claude/skills/merge/SKILL.md](.claude/skills/merge/SKILL.md)

## ローカル補助

`.claude/agents/` に `code-reviewer` と `e2e-verifier` がある。利用できる環境で、独立したレビュー・検証が有効な場合に使う。

Claude用のhookは `.claude/settings.json` と `.claude/hooks/` を参照する。`post-edit-analyze` は対象Dartファイルを解析し、`pre-stop-check` は `lib/` の解析と条件付きテストを行う。実際に実行された検証結果を確認し、重複実行を避ける。
