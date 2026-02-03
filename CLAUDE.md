# ccpocket

Claude Code専用モバイルクライアント

## プロジェクト構成

```
ccpocket/
├── packages/bridge/    # Bridge Server (TypeScript, WebSocket)
│   └── src/
│       ├── index.ts           # エントリーポイント
│       ├── websocket.ts       # WebSocket接続管理・マルチセッション
│       ├── session.ts         # セッション管理 (SessionManager)
│       ├── claude-process.ts  # Claude CLIプロセス管理
│       └── parser.ts          # stream-json パース・型定義
├── apps/mobile/        # Flutter Mobile App
│   └── lib/
│       ├── main.dart
│       ├── features/                      # Feature-first ディレクトリ
│       │   ├── chat/                      # チャット画面
│       │   │   ├── chat_screen.dart
│       │   │   ├── state/                 # Freezed state + Notifier
│       │   │   └── widgets/               # 抽出Widget
│       │   ├── session_list/              # セッション一覧 (ホーム)
│       │   │   ├── session_list_screen.dart
│       │   │   ├── state/
│       │   │   └── widgets/
│       │   ├── diff/                      # Diff表示画面
│       │   │   ├── diff_screen.dart
│       │   │   ├── state/
│       │   │   └── widgets/
│       │   └── gallery/                   # ギャラリー画面
│       │       ├── gallery_screen.dart
│       │       └── widgets/
│       ├── models/messages.dart           # メッセージ型定義
│       ├── providers/                     # グローバルprovider
│       ├── services/bridge_service.dart   # WebSocketクライアント
│       ├── utils/diff_parser.dart         # Unified diffパーサー
│       └── widgets/                       # 共有Widget
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

### 開発用一括再起動
```bash
npm run dev                      # Bridge再起動 + Flutter (marionette) 起動
npm run dev -- <device-id>       # デバイス指定付き
```

Bridge Serverの停止→再起動とFlutterアプリの起動を一括で行う。
Flutterアプリ終了時にBridge Serverも自動停止する。
スクリプト本体: `scripts/dev-restart.sh`

## 技術スタック

- **Bridge Server**: TypeScript, WebSocket (ws), Node.js
- **Mobile App**: Flutter/Dart, shared_preferences
- **パッケージ管理**: npm workspaces

## Bridge Server アーキテクチャ

```
Flutter App ←WebSocket→ websocket.ts ←→ session.ts ←→ claude-process.ts ←stdio→ Claude CLI
                                              ↕
                                          parser.ts
```

- `parser.ts` - Claude CLI stream-json出力のパースと型定義 (stream_event含む)
- `claude-process.ts` - Claude CLIプロセスのライフサイクル管理 (approve/reject/sendToolResult)
- `session.ts` - マルチセッション管理 (SessionManager)
- `websocket.ts` - WebSocket接続管理・認証・メッセージルーティング
- `index.ts` - エントリーポイント

## 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `BRIDGE_PORT` | `8765` | WebSocketポート |
| `BRIDGE_HOST` | `0.0.0.0` | バインドアドレス |
| `BRIDGE_API_KEY` | (なし) | APIキー認証 (設定時に有効化) |

## WebSocket プロトコル

### Client → Server メッセージ
- `start` - 新規セッション開始 (projectPath, sessionId?, continue?, permissionMode?)
- `input` - ユーザーメッセージ送信 (text, sessionId?)
- `approve` - ツール実行承認 (id, sessionId?)
- `reject` - ツール実行拒否 (id, message?, sessionId?)
- `answer` - AskUserQuestion応答 (toolUseId, result, sessionId?)
- `list_sessions` - セッション一覧取得
- `stop_session` - セッション停止 (sessionId)
- `get_history` - セッション履歴取得 (sessionId)
- `get_diff` - プロジェクトのgit diff取得 (projectPath)

### Server → Client メッセージ
- `system` - システムイベント (init, session_created)
- `assistant` - Claudeの応答メッセージ
- `tool_result` - ツール実行結果
- `result` - 最終結果 (コスト・所要時間含む)
- `error` - エラー通知
- `status` - プロセスステータス (idle/running/waiting_approval)
- `history` - メッセージ履歴
- `permission_request` - パーミッション要求
- `stream_delta` - ストリーミングテキスト差分
- `session_list` - セッション一覧
- `diff_result` - git diff結果 (diff, error?)

## リモートアクセス設定

### Tailscale経由
1. Mac・iPhoneの両方にTailscaleをインストール
2. Bridge Serverを起動 (`BRIDGE_HOST=0.0.0.0`)
3. Flutter AppのServer URLに `ws://<Mac_Tailscale_IP>:8765` を入力

### launchd永続化
```bash
# 1. テンプレートを編集
cp packages/bridge/com.ccpocket.bridge.plist ~/Library/LaunchAgents/
# パスとAPIキーを実際の値に更新

# 2. ビルド
npm run bridge:build

# 3. サービス登録
launchctl load ~/Library/LaunchAgents/com.ccpocket.bridge.plist

# 4. 確認
launchctl list | grep ccpocket

# アンロード
launchctl unload ~/Library/LaunchAgents/com.ccpocket.bridge.plist
```

## 開発ワークフロー

### 1. 設計フェーズ
- 複雑な実装はプロトコル仕様・設計ドキュメント作成から始める
- `docs/` 配下に仕様を残し、再調査コストを下げる

### 2. 実装フェーズ
- こまめにコミット (機能単位で分割)

### 3. 静的検証
```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json   # TypeScript型チェック
dart analyze apps/mobile                              # Dart静的解析
dart format apps/mobile                               # フォーマット
flutter test apps/mobile                              # ユニットテスト
```

### 4. 動作確認 (シミュレーター/実機)
状況に応じてモック確認とE2Eを選択する。

#### エントリポイント一覧

| ファイル | 用途 | 起動コマンド |
|---------|------|-------------|
| `lib/main.dart` | 通常起動 (本番/開発) | `flutter run` |
| `lib/driver_main.dart` | Flutter Driver (MCP `flutter_driver`) | `flutter run -t lib/driver_main.dart` |
| `lib/marionette_main.dart` | Marionette MCP | `flutter run -t lib/marionette_main.dart` |

**注意**: `MarionetteBinding` と `enableFlutterDriverExtension()` は同時に使用不可 (バインディングの競合)。そのためエントリポイントを分離している。

#### モック確認 (UI単体)
- `lib/driver_main.dart` でFlutter Driver有効化済みアプリを起動
- AppBarのモックプレビューボタンでモックデータ付きチャット画面を表示
- MCP `flutter_driver` の `screenshot` コマンドでスクリーンショット取得・目視確認
- ウィジェットテスト (`flutter test`) で自動検証

#### E2E確認 (Bridge Server接続)
- Bridge Serverを起動 (`npm run bridge`)
- シミュレーターでアプリ起動し、実際のClaude CLIセッションで動作確認
- 承認フロー、AskUserQuestion、ストリーミング等の実際の挙動を検証

#### Marionette MCP によるUI検証 (推奨)

**起動手順**:
1. `flutter run -t lib/marionette_main.dart` でアプリ起動
2. Marionette MCPサーバーが自動でアプリのVM Serviceに接続

**主要ツール (優先度順)**:
- `get_interactive_elements` — タップ可能なボタン・入力欄等の一覧取得。**最優先で使う**
- `get_logs` — アプリのログ取得
- `tap` — 要素をタップ
- `enter_text` — テキスト入力
- `get_semantics_tree` — セマンティクスツリー取得
- `screenshot` — スクリーンショット取得 (**最後の手段として使用**)

**重要: スクリーンショットの使用制限**:
- スクリーンショットは画像データをAPIに送信するため、**Claude CodeのAPI使用量を大幅に消費する**
- 多用するとAPI制限に到達し、セッション全体が使用不能になる
- **まず `get_interactive_elements` や `get_semantics_tree` でUI構造を把握** し、テキストベースで検証する
- スクリーンショットはレイアウト・ビジュアル確認が本当に必要な場面のみに限定する

#### MCP Flutter Driver利用時の注意
- `tap` コマンドはタイムアウトしやすい (デフォルト5秒)
- `screenshot` と `get_health` は安定して動作する
- タップが失敗する場合は `ensureVisible` → `tap` の順で試す
- ウィジェットテストの方が信頼性が高い

## カスタムスキル

`.claude/skills/` にプロジェクト固有のスキル (スラッシュコマンド) を配置している。

| スキル | 呼び出し | 説明 |
|--------|---------|------|
| test-bridge | `/test-bridge` | Bridge Server の Vitest テスト実行・TypeScript型チェック・テスト記述規約 |
| test-flutter | `/test-flutter` | Flutter App のテスト実行・dart analyze・format・テスト記述規約 |
| impl-flutter-ui | `/impl-flutter-ui` | Flutter UI実装のアーキテクチャ規約・コンポーネント分割・状態管理ガイド |

実装後の検証では、変更領域に応じて対応するスキルを実行する。
Bridge と Flutter の両方に影響がある場合は両方実行する。

## 規約

- コミット: Conventional Commits (`type(scope): description`)
- TypeScript: ESM, strict mode, NodeNext module resolution
- Bridge ServerのデフォルトPort: 8765
