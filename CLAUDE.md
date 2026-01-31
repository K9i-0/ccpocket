# ccpocket

Claude Code専用モバイルクライアント

## プロジェクト構成

```
ccpocket/
├── packages/bridge/    # Bridge Server (TypeScript, WebSocket)
├── apps/mobile/        # Flutter Mobile App
└── package.json        # npm workspaces root
```

## コマンド

### Bridge Server
```bash
npm run bridge          # 開発サーバー起動 (tsx)
npm run bridge:build    # TypeScriptビルド
```

### Flutter App
```bash
cd apps/mobile && flutter run    # アプリ起動
cd apps/mobile && flutter test   # テスト実行
```

## 技術スタック

- **Bridge Server**: TypeScript, WebSocket (ws), Node.js
- **Mobile App**: Flutter/Dart
- **パッケージ管理**: npm workspaces

## Bridge Server アーキテクチャ

```
Flutter App ←WebSocket→ websocket.ts ←→ claude-process.ts ←stdio→ Claude CLI
                                              ↕
                                          parser.ts
```

- `parser.ts` - Claude CLI stream-json出力のパースと型定義
- `claude-process.ts` - Claude CLIプロセスのライフサイクル管理
- `websocket.ts` - WebSocket接続管理とメッセージルーティング
- `index.ts` - エントリーポイント

## 規約

- コミット: Conventional Commits (`type(scope): description`)
- TypeScript: ESM, strict mode, NodeNext module resolution
- Bridge ServerのデフォルトPort: 8765
