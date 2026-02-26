# ccpocket

Claude Code / Codex 対応モバイルクライアント

## プロジェクト構成

```
ccpocket/
├── packages/bridge/    # Bridge Server (TypeScript, WebSocket)
│   └── src/
│       ├── index.ts           # エントリーポイント
│       ├── websocket.ts       # WebSocket接続管理・マルチセッション
│       ├── session.ts         # セッション管理 (SessionManager)
│       ├── claude-process.ts  # Claude CLIプロセス管理 (SDK経由)
│       ├── codex-process.ts   # Codex CLIプロセス管理 (SDK経由)
│       └── parser.ts          # stream-json パース・型定義
├── apps/mobile/        # Flutter Mobile App
│   └── lib/
│       ├── main.dart
│       ├── features/                      # Feature-first ディレクトリ
│       │   ├── chat_session/              # 共通チャットセッション (state/widgets)
│       │   ├── claude_session/            # Claude Code セッション画面
│       │   ├── codex_session/             # Codex セッション画面
│       │   ├── session_list/              # セッション一覧 (ホーム)
│       │   ├── connection/                # 接続・マシン管理
│       │   ├── diff/                      # Diff表示画面
│       │   ├── gallery/                   # ギャラリー画面
│       │   ├── message_images/            # メッセージ画像ビューア
│       │   ├── prompt_history/            # プロンプト履歴
│       │   ├── settings/                  # 設定画面
│       │   ├── setup_guide/               # 初回セットアップガイド
│       │   └── debug/                     # デバッグ画面
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
npm run dev                      # Bridge再起動 + Flutterアプリ起動
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
                                         ┌→ claude-process.ts ←SDK→ Claude Code CLI
Flutter App ←WebSocket→ websocket.ts ←→ session.ts ─┤
                                              ↕      └→ codex-process.ts ←SDK→ Codex CLI
                                          parser.ts
```

- `parser.ts` - Claude CLI stream-json出力のパースと型定義 (stream_event含む)
- `claude-process.ts` - Claude Code CLIプロセス管理 (Claude Agent SDK経由)
- `codex-process.ts` - Codex CLIプロセス管理 (Codex SDK経由)
- `session.ts` - マルチセッション管理 (SessionManager)
- `websocket.ts` - WebSocket接続管理・認証・メッセージルーティング
- `index.ts` - エントリーポイント

## 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `BRIDGE_PORT` | `8765` | WebSocketポート |
| `BRIDGE_HOST` | `0.0.0.0` | バインドアドレス |
| `BRIDGE_API_KEY` | (なし) | APIキー認証 (設定時に有効化) |
| `DIFF_IMAGE_AUTO_DISPLAY_KB` | `1024` (1MB) | Diff画像の自動表示閾値 (KB単位) |
| `DIFF_IMAGE_MAX_SIZE_MB` | `5` (5MB) | Diff画像の最大サイズ (MB単位、超過はテキストのみ) |

### プッシュ通知 (FCM)

Bridge起動時にFirebase Anonymous Authで自動認証される。環境変数の設定は不要。
Cloud Functions (relay) がFCMトークンの管理とプッシュ送信を担当する。

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
- `assistant` - エージェントの応答メッセージ (Claude Code / Codex)
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

plistテンプレートは `zsh -li -c "exec node ..."` でBridge Serverを起動する。
ログイン+インタラクティブシェル経由で起動することで、Terminal.appと同じ環境
（nvm, pyenv, Homebrew等の初期化を含む）が反映される。
`exec` によりzshプロセスはnodeに置き換わるため、余分なプロセスは残らない。

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

## MCP ツール使い分け

### 原則: DTD/VM Service接続が必要 = MCP、それ以外 = CLI

| 操作 | 推奨 | ツール |
|------|------|--------|
| アプリ起動 | **MCP** | dart-mcp `launch_app` |
| アプリ停止 | **MCP** | dart-mcp `stop_app` |
| ホットリロード | **MCP** | dart-mcp `hot_reload` |
| ランタイムエラー | **MCP** | dart-mcp `get_runtime_errors` |
| ウィジェットツリー | **MCP** | dart-mcp `get_widget_tree` |
| UI要素一覧 | **MCP** | marionette `get_interactive_elements` |
| UI操作 | **MCP** | marionette `tap` / `enter_text` |
| デバイス一覧 | CLI | `flutter devices` |
| 静的解析 | CLI | `dart analyze apps/mobile` |
| フォーマット | CLI | `dart format apps/mobile` |
| テスト | CLI | `cd apps/mobile && flutter test` |
| 依存関係 | CLI | `cd apps/mobile && flutter pub get` |

詳細は `/mobile-automation` スキルを参照。

## 開発ワークフロー

### Plan Mode 要件

**全てのPlan Modeは以下3フェーズを含むこと:**

1. **実装フェーズ** — コード変更
2. **検証フェーズ** — 静的検証 + E2Eテスト（`/mobile-automation` スキル参照）
3. **レビューフェーズ** — セルフレビュー（`/self-review` スキル参照）

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
cd apps/mobile && flutter test                        # ユニットテスト
```

### 4. 動作確認 (シミュレーター/実機)

エントリポイント: `lib/main.dart`（デバッグモードでMarionetteBinding自動有効化）

#### モック確認 (UI単体・Bridge不要)
- AppBarのモックプレビューボタンで10種のモックシナリオを表示可能
- Marionette MCPの `get_interactive_elements` でUI構造を検証
- 詳細は `/mobile-automation` スキルの「Mock UIテスト」セクション参照

#### E2E確認 (Bridge Server接続)
- Bridge Serverを起動 (`npm run bridge`)
- シミュレーターでアプリ起動し、実際のClaude Code / Codexセッションで動作確認
- 承認フロー、AskUserQuestion、ストリーミング等の実際の挙動を検証

**本番Bridgeが稼働中の場合**: ポートを分けてテスト用Bridgeを起動する
```bash
BRIDGE_PORT=8766 npm run bridge
```
シミュレーターアプリの接続画面で `ws://localhost:8766` を指定して接続する。
本番Bridge（8765）に影響を与えずにテストできる。

### 5. Web確認 (ユーザー向けプレビュー)

実装完了後、ユーザーがブラウザで確認できるようWebビルドを行う。

```bash
cd apps/mobile && flutter build web --release
```

**Webサーバー起動 (初回のみ)**
```bash
cd apps/mobile/build/web && python3 -m http.server 8888
```

**アクセスURL (Tailscale経由)**
- `http://<Mac_Tailscale_IP>:8888`

**注意**: ビルド更新後はブラウザキャッシュをクリア (Cmd+Shift+R) してリロードすること。

## カスタムサブエージェント

`.claude/agents/` にプロジェクト固有のサブエージェントを定義している。

| エージェント | モデル | メモリ | 説明 |
|-------------|--------|--------|------|
| code-reviewer | opus | local | コードレビュー専門。`/self-review` スキルから利用 |
| e2e-verifier | opus | local | E2E動作検証。`/mobile-automation` スキルから利用 |

サブエージェントは独立したコンテキストで実行され、永続メモリ（`.claude/agent-memory-local/`）にプロジェクト固有の知識を蓄積する。

## カスタムスキル

`.claude/skills/` にプロジェクト固有のスキル (スラッシュコマンド) を配置している。

| スキル | 呼び出し | 説明 |
|--------|---------|------|
| release-bridge | `/release-bridge` | Bridge Server リリース（version bump + CHANGELOG + タグ → npm publish） |
| release-mobile | `/release-mobile` | モバイルアプリ リリース（version bump + CHANGELOG + タグ → Shorebird + ストア配布） |
| shorebird-patch | `/shorebird-patch` | Shorebird OTA パッチ作成（staging → promote → stable） |
| test-bridge | `/test-bridge` | Bridge Server の Vitest テスト実行・TypeScript型チェック |
| test-flutter | `/test-flutter` | Flutter App のテスト実行・dart analyze・format |
| mobile-automation | `/mobile-automation` | MCP (dart-mcp + Marionette) E2E自動化・UI検証ガイド |
| self-review | `/self-review` | タスク完了前のセルフレビュー |
| web-preview | `/web-preview` | Web版ビルド・サーバー起動・Playwrightアクセス確認・URL案内 |
| flutter-ui-design | `/flutter-ui-design` | Flutter UI実装規約 (Bloc/Cubit + Freezed) |
| merge | `/merge` | 作業ブランチをmainにマージ |

実装後の検証では、変更領域に応じて対応するスキルを実行する。
Bridge と Flutter の両方に影響がある場合は両方実行する。

## Hooks（自動品質ゲート）

| Hook | トリガー | 内容 |
|------|---------|------|
| post-edit-analyze | Dartファイル編集後 | `dart analyze` 自動実行 |
| pre-stop-check | タスク完了前 | `dart analyze` + `flutter test` で品質チェック |

## リリース & パッチ

### リリース（タグ駆動 → GH Actions 自動実行）

```bash
# Bridge Server リリース → npm publish + GitHub Release
/release-bridge

# モバイルアプリ リリース → Shorebird release + ストア配布 + GitHub Release
/release-mobile
```

### OTA パッチ（staging → promote → stable）

```bash
# パッチ作成 (staging)
bash .claude/skills/shorebird-patch/patch.sh ios <version>
bash .claude/skills/shorebird-patch/patch.sh android <version>

# 検証後に stable へ昇格
bash .claude/skills/shorebird-patch/promote.sh <version> <patch-number>
```

- パッチはデフォルトで **staging** に配信される
- アプリのデバッグ画面（ロゴ5連打）で Update Track を Staging に変更して検証可能
- パッチスクリプトは `--allow-asset-diffs` を常時付与し、非TTY環境でも安定動作する
- `shorebird` コマンドを直接実行する場合は `--release-version` フラグ必須
- 詳細は `/shorebird-patch` スキルを参照

## 規約

- コミット: Conventional Commits (`type(scope): description`)
- TypeScript: ESM, strict mode, NodeNext module resolution
- Bridge ServerのデフォルトPort: 8765
