# ccpocket

Claude Code専用モバイルクライアント。Bridge Server経由でClaude Code CLIをiPhone/Androidから操作できます。

<!-- screenshots -->

## 主な機能

- **チャット** — Claude Codeとリアルタイムでやりとり (ストリーミング対応)
- **セッション管理** — 複数セッションの作成・切替・履歴閲覧
- **ツール承認** — ファイル編集やコマンド実行の承認/拒否をモバイルから
- **Diff表示** — プロジェクトのgit diffをシンタックスハイライト付きで確認
- **ギャラリー** — セッション中の画像やスクリーンショットを一覧表示
- **音声入力** — 音声でプロンプトを入力
- **QR接続** — QRコードでBridge ServerのURLを簡単に設定

## アーキテクチャ

```
┌─────────────┐     WebSocket      ┌────────────────┐     stdio      ┌──────────────┐
│  Flutter App │ ◄──────────────► │  Bridge Server  │ ◄────────────► │  Claude CLI   │
│  (iOS/Android)│                   │  (TypeScript)   │                │              │
└─────────────┘                    └────────────────┘                └──────────────┘
```

Bridge Serverがモバイルアプリとclaude CLIプロセスの間に立ち、WebSocketでメッセージを中継します。

## 技術スタック

| 層 | 技術 |
|---|---|
| Mobile App | Flutter / Dart |
| Bridge Server | TypeScript / Node.js / ws |
| パッケージ管理 | npm workspaces |

## 前提条件

- [Node.js](https://nodejs.org/) v18以上
- [Flutter SDK](https://flutter.dev/) 3.x
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` コマンドが使える状態)

## セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/K9i/ccpocket.git
cd ccpocket

# 依存関係をインストール
npm install
cd apps/mobile && flutter pub get && cd ../..
```

## 使い方

### 1. Bridge Serverを起動

```bash
npm run bridge
```

デフォルトで `ws://0.0.0.0:8765` で起動します。

### 2. Flutter Appを起動

```bash
cd apps/mobile
flutter run
```

アプリのServer URL設定にBridge ServerのURLを入力して接続します。

### 3. 開発用一括起動

```bash
npm run dev              # Bridge再起動 + Flutter起動
npm run dev -- <device>  # デバイス指定
```

## リモートアクセス (Tailscale)

Mac (サーバー) とiPhone (クライアント) の両方に[Tailscale](https://tailscale.com/)をインストールすると、外出先からもBridge Serverに接続できます。

1. Mac・iPhoneにTailscaleをインストールし、同じネットワークに参加
2. Bridge Serverを起動 (`BRIDGE_HOST=0.0.0.0`)
3. Flutter AppのServer URLに `ws://<MacのTailscale IP>:8765` を入力

## 開発コマンド

| コマンド | 説明 |
|---------|------|
| `npm run bridge` | Bridge Server起動 (開発モード) |
| `npm run bridge:build` | Bridge Serverビルド |
| `npm run dev` | Bridge + Flutter一括起動 |
| `npm run test:bridge` | Bridge Serverテスト |
| `cd apps/mobile && flutter test` | Flutterテスト |
| `cd apps/mobile && dart analyze` | Dart静的解析 |

## 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `BRIDGE_PORT` | `8765` | WebSocketポート |
| `BRIDGE_HOST` | `0.0.0.0` | バインドアドレス |
| `BRIDGE_API_KEY` | (なし) | APIキー認証 (設定時に有効化) |

## ライセンス

[MIT](LICENSE)
