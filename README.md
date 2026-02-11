# ccpocket

Claude Code専用モバイルクライアント。Bridge Server経由でClaude Code CLIをiPhone/Androidから操作できます。

<!-- screenshots -->

## 主な機能

- **チャット** — Claude Codeとリアルタイムでやりとり (ストリーミング対応)
- **セッション管理** — 複数セッションの作成・切替・履歴閲覧・Resume
- **ツール承認** — ファイル編集やコマンド実行の承認/拒否をモバイルから
- **マシン管理** — 複数マシンの登録・ステータス監視・SSH経由のリモート起動/停止
- **Diff表示** — プロジェクトのgit diffをシンタックスハイライト付きで確認
- **ギャラリー** — セッション中の画像やスクリーンショットを一覧表示
- **音声入力** — 音声でプロンプトを入力
- **複数の接続方法** — 保存済みマシン・QRコード・mDNS自動発見・手動入力

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

デフォルトで `ws://0.0.0.0:8765` で起動します。起動時にQRコードがターミナルに表示されます。

### 2. Flutter Appを起動

```bash
cd apps/mobile
flutter run
```

### 3. 接続

以下の4つの方法でBridge Serverに接続できます。

#### 保存済みマシン (推奨)

マシンをあらかじめ登録しておくと、ワンタップで接続できます。オンライン/オフラインのステータスが自動で表示され、お気に入りにピン留めすることもできます。マシンの登録方法は「マシン管理とSSHリモート起動」セクションを参照してください。

#### QRコード

Bridge Server起動時にターミナルに表示されるQRコードをアプリでスキャンします。URLとAPIキーが自動入力されます。

ディープリンク形式: `ccpocket://connect?url=ws://IP:PORT&token=API_KEY`

#### mDNS自動発見

同一ネットワーク上のBridge Serverを自動検出します（サービスタイプ: `_ccpocket._tcp`）。検出されたサーバーは接続画面に一覧表示され、タップするだけで接続できます。

#### 手動入力

接続画面のURL欄に直接入力します。以下の形式に対応しています:

- `ws://192.168.1.5:8765` — フルURL
- `192.168.1.5:8765` — ショートハンド (`ws://` が自動補完)

### 4. 開発用一括起動

```bash
npm run dev              # Bridge再起動 + Flutter起動
npm run dev -- <device>  # デバイス指定
```

## マシン管理とSSHリモート起動

マシンを登録すると、接続先の管理やSSH経由でのBridge Serverのリモート操作が可能になります。

### マシン登録

接続画面の「Add Machine」からマシンを追加します。

| 項目 | 説明 |
|------|------|
| Name | 表示名 (省略時はhost:portで表示) |
| Host | IPアドレスまたはホスト名 |
| Port | Bridge Serverのポート (デフォルト: 8765) |
| API Key | Bridge ServerのAPIキー (設定時) |
| SSH | SSHリモート操作を有効化 (後述) |

### SSH設定

SSHを有効にすると、アプリからBridge Serverのリモート起動・停止・セットアップが可能になります。

- **SSH Username** — リモートマシンのユーザー名
- **SSH Port** — SSHポート (デフォルト: 22)
- **認証方式** — パスワード認証 または 秘密鍵認証を選択
- **Test Connection** — 設定を保存する前にSSH接続をテスト可能

### SSHリモート操作

マシンカードのメニュー (⋯) から以下の操作ができます:

| 操作 | 説明 |
|------|------|
| **Start** | `launchctl start` でBridge Serverを起動 (オフライン時にカードのボタンからも実行可能) |
| **Stop Server** | `launchctl stop` でBridge Serverを停止 |
| **Setup Bridge** | launchdのワンタップ初期設定。プロジェクトパスを指定すると、plistの生成・配置・サービス登録を自動で行う |
| **Update Bridge** | `git pull` → ビルド → サービス再起動を一括実行。バージョン差分がある場合にカードに表示される |

> **前提**: リモートマシンはmacOS (launchd対応) で、SSH接続が可能であること。Tailscale等のVPN経由での利用を推奨。

## リモートアクセス (Tailscale)

Mac (サーバー) とiPhone (クライアント) の両方に[Tailscale](https://tailscale.com/)をインストールすると、外出先からもBridge Serverに接続できます。

1. Mac・iPhoneにTailscaleをインストールし、同じネットワークに参加
2. Bridge Serverを起動 (`BRIDGE_HOST=0.0.0.0`)
3. Flutter AppのServer URLに `ws://<MacのTailscale IP>:8765` を入力

### launchd永続化

Bridge ServerをmacOSのlaunchdで常駐させると、再起動後も自動で起動します。

#### アプリから設定 (推奨)

1. マシンを登録し、SSH設定を有効化
2. マシンカードのメニュー → **Setup Bridge** を選択
3. プロジェクトパスを入力して実行

plistの生成・配置・サービス登録が自動で行われます。

#### 手動で設定

```bash
# 1. テンプレートをコピー・編集
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

## セッション管理

### 新規セッション

接続後、「+」ボタンから新しいセッションを作成します。

1. **プロジェクト選択** — 最近使ったプロジェクト一覧から選択、またはパスを直接入力
2. **パーミッションモード選択** — Claudeのツール実行許可レベルを設定

| モード | 説明 |
|--------|------|
| Accept Edits | ファイル編集は自動承認、その他は確認 (デフォルト) |
| Plan Only | 計画の提示のみ。実行前にすべて承認が必要 |
| Bypass All | すべてのツール実行を自動承認 |
| Delegate | サブエージェントへの委任を許可 |
| Don't Ask | 確認なしでツールを実行 |

3. **Worktree** (オプション) — 有効にするとgit worktreeを作成してブランチを分離した状態で開発。ブランチ名を指定可能 (未指定時は自動生成)

### Resume (過去セッションの再開)

ホーム画面の「Recent Sessions」一覧から、過去のセッションをタップするとResumeできます。プロジェクトフィルタや検索で絞り込みも可能です。

### プロジェクトフィルタ

ホーム画面上部のプロジェクトチップをタップすると、セッション一覧を特定のプロジェクトでフィルタリングできます。

## ツール承認

Claudeがファイル編集やコマンド実行を行う際、パーミッションモードに応じて承認リクエストが表示されます。

- **ツール名と入力内容**を確認し、Approve (承認) / Reject (拒否) を選択
- Plan Modeの場合は、Claudeが提示するプランを確認・編集してから承認

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
