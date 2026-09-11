---
name: mobile-automation
description: FlutterアプリのUI動作をシミュレーターで検証する、またはBridgeとのE2Eを確認するときに使う。
---

# Mobile Automation

検証対象に応じて必要な参照だけ読む。dart-mcp / Marionette で実行時の状態を確認する。

- 起動・接続・CLIとMCPの使い分け: [references/startup.md](references/startup.md)
- Bridge不要のMock UI検証と要素キー: [references/mock-and-keys.md](references/mock-and-keys.md)
- 実際のBridge通信を含む検証: [references/e2e.md](references/e2e.md)
- 接続・ジェスチャー・モック制限の問題: [references/troubleshooting.md](references/troubleshooting.md)

## 実行範囲

- 既定はiOSシミュレーターとテスト用Bridge `8766`。ユーザーが指定したデバイス・接続先を優先する。本番 `8765` のプロセスを停止しない。
- プロジェクトルートは `git rev-parse --show-toplevel`、アプリはその配下の `apps/mobile`。
- 検証する挙動と期待結果を決め、関連するシナリオを選ぶ。単純なUI確認は直接操作する。複数画面の独立した検証は、利用可能なら `e2e-verifier` 等へ委譲できる。
- 操作には現在の `get_interactive_elements` のキー・boundsを使う。画面遷移やジェスチャー後は結果を確認する。
- 要素・ログで挙動を確認し、外観・レイアウトの変更はスクリーンショットで目視する。枚数は検証対象に応じて選ぶ。
- 終了時は自分が起動したアプリ・BridgeだけPIDを指定して停止する。プレビュー継続を依頼されている場合は残し、接続方法を報告する。
- 検証結果と未確認の範囲を報告する。Mock表示の成功を実通信の成功として扱わない。
