# CC Pocket

CC Pocket は、Codex / Claude のセッションをスマホだけで開始・完結できるアプリです。ラップトップを開く必要なし。アプリを開いて、プロジェクトを選んで、どこからでもコーディング。

[English README](README.md) | [简体中文版 README](README.zh-CN.md)

<p align="center">
  <img src="docs/images/screenshots-ja.png" alt="CC Pocket screenshots" width="800">
</p>

CC Pocket は Anthropic / OpenAI とは無関係であり、承認・提携・公式提供を受けたものではありません。

## なぜ CC Pocket？

AI コーディングエージェントは、機能まるごと自律的に書けるレベルに進化しています。開発者の役割は、コードを書くことから「判断」へ — ツールの承認、質問への回答、差分のレビュー。

判断にキーボードは要りません。画面と親指があれば十分です。

CC Pocket はこのワークフローのために作りました。スマホからセッションを開始し、自分のマシンの Codex / Claude に作業を任せ、どこにいても判断だけ行う。

## こんな人向け

CC Pocket は、すでにコーディングエージェントを実用的に使っていて、席を離れている間もセッションを追いたい人向けのアプリです。

- **長時間のエージェント実行を回す個人開発者** — Mac mini、Raspberry Pi、Linux サーバーなど
- **移動中や外出中でも開発を止めたくないインディーハッカーや創業者**
- **複数セッションと承認依頼を捌きたい AI ネイティブな開発者**
- **コードをホスト型 IDE ではなく自分のマシンに置いておきたいセルフホスター**

「エージェントを走らせて、必要なときだけ介入したい」という使い方に向いています。

## 何が便利か

- **スマホからセッション開始・再開** ができる
- **承認依頼を素早く処理** できる
- **ストリーミング出力をリアルタイムで確認** できる
- **シンタックスハイライト付きで差分レビュー** できる
- **Markdown や画像添付で質の高いプロンプト** を送れる
- **複数セッションをプロジェクト単位で整理** できる
- **承認待ちや完了をプッシュ通知** で受け取れる
- **保存済みマシン、QR、mDNS、手入力** で接続できる
- **SSH でリモートホストを管理** できる（macOS / Linux 対応）

## CC Pocket と Remote Control の違い

Claude Code の Remote Control は、Mac で始めたターミナルセッションをスマホに引き継ぐ機能です。

CC Pocket はアプローチが異なります。**セッションはスマホから始まり、スマホで完結します。** Mac はバックグラウンドで動くだけで、スマホがメインのインターフェースです。

| | Remote Control | CC Pocket |
|---|---------------|-----------|
| セッション起点 | Mac で開始 → スマホに引き継ぎ | スマホから開始 |
| 主たるデバイス | Mac（スマホは途中参加） | スマホ（Mac はバックグラウンド） |
| ユースケース | デスクの作業を移動中に続ける | どこからでもコーディングを始める |
| セットアップ | Claude Code に内蔵 | セルフホスト Bridge Server |

**具体的にできること・できないこと:**
- スマホから新規セッションを開始し、最後まで完結 → **できる**
- Mac に保存された過去のセッション履歴から再開 → **できる**
- Mac で直接開始したライブセッションに途中参加 → **できない**

## はじめかた

<p align="center">
  <img src="docs/images/install-banner-ja.png" alt="CC Pocket — 30秒でセットアップ" width="720">
</p>

### 1. Bridge Server を起動

ホストマシンに [Node.js](https://nodejs.org/) 18 以上と CLI プロバイダ（[Codex](https://github.com/openai/codex) または [Claude Code](https://docs.anthropic.com/en/docs/claude-code)）をインストールし、以下を実行:

```bash
npx @ccpocket/bridge@latest
```

ターミナルに QR コードが表示されます。アプリからスキャンすればすぐに接続できます。

> Warning
> `@ccpocket/bridge` バージョン `1.25.0` 未満は、Anthropic の現行 Claude Agent SDK ドキュメントではサードパーティ製品で Claude のサブスクリプションログインを許可していないため、新規インストールでの使用は非推奨です。
> `>=1.25.0` を使用し、OAuth の代わりに `ANTHROPIC_API_KEY` を設定してください。
>
> 2026年4月15日時点では、Anthropic の一部 Help ページに「Extra Usage / usage bundles が Claude アカウントを使う third-party products にも適用されうる」と読める記述があります。CC Pocket としては、Agent SDK でもそれが正式に許可されるなら OAuth ブロックを外したいと考えていますが、公開中の Claude Agent SDK ドキュメントでは依然としてサードパーティ製品による Claude のサブスクリプションログイン提供が禁止されています。ドキュメント同士の整合が取れるまでは、より厳しいガイダンスを優先して OAuth ブロックを維持します。
>
> **重要:** API キーは `ANTHROPIC_API_KEY` 環境変数で設定してください。Claude CLI 内の `/login` で設定したキーはサブスクリプションプランの認証と区別がつかず、現行のサードパーティ認証ガイダンスと衝突します。

### 2. アプリをインストール

上のバナーの QR コードをスキャンするか、直接ダウンロード:

<div align="center">
<a href="https://apps.apple.com/jp/app/cc-pocket-%E3%81%A9%E3%81%93%E3%81%A7%E3%82%82%E3%82%B3%E3%83%BC%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0/id6759188790"><img height="40" alt="App Storeからダウンロード" src="docs/images/app-store-badge.svg" /></a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://play.google.com/store/apps/details?id=com.k9i.ccpocket"><img height="40" alt="Google Play で手に入れよう" src="docs/images/google-play-badge-ja.svg" /></a>
</div>

### macOS デスクトップ版（ベータ）

macOS ネイティブアプリもあります。モバイル版の UI/UX を気に入ったユーザーから「同じ体験を Mac でも使いたい」という声があり、実験的に作ったのが始まりです。

まだベータ版ですが、十分に実用可能です。最新の `.dmg` は [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=macos) からダウンロードできます（`macos/v*` タグのリリースが対象です）。

### 3. 接続してコーディング開始

| 接続方法 | 向いているケース |
|----------|------------------|
| **QRコード** | 初回セットアップを最短で — ターミナルの QR をスキャン |
| **保存済みマシン** | 普段使い、再接続、状態確認 |
| **mDNS自動発見** | 同一ネットワーク上で IP 入力を避けたいとき |
| **手動入力** | Tailscale、リモート環境、カスタムポート |

アプリでプロジェクトと AI ツールを選び、セッションモードを設定して開始します。

Bridge 側では、**Claude セッションは Claude Agent SDK で動作**します。セッション履歴は Claude Code と互換なので、CC Pocket から過去の Claude Code セッションを開いたり、必要に応じて Claude Code 側で続きを再開したりできます。

**Claude** は単一の **Permission Mode** で承認範囲とプランニングを制御します:

| Permission Mode | 挙動 |
|----------------|------|
| `Default` | 標準の対話モード |
| `Accept Edits` | ファイル編集は自動承認し、それ以外は確認 |
| `Plan` | まずプランを立て、承認後に実行する |
| `Bypass All` | すべて自動承認 |

**Codex** は関心ごとを独立した設定に分離しています:

| 設定 | 選択肢 | 説明 |
|------|--------|------|
| **Approval Policy** | `Untrusted` / `On Request` / `On Failure` / `Never Ask` | どのタイミングで Codex が承認を求めるかを制御します。`On Failure` は互換性のため残していますが非推奨です。 |
| **Plan** | On / Off | Approval Policy とは独立してプランモードを切り替え |
| **Sandbox** | On（デフォルト）/ Off | 安全のため制限された環境で実行 |

> Codex はデフォルトで Sandbox On（安全側）。Claude はデフォルトで Sandbox Off です。

必要なら **Worktree** を有効にして、セッションごとに独立した git worktree を使えます。

### サポートしているモデルについて

CC Pocket は、Codex CLI や Claude で利用できるすべてのモデルをそのまま表示するわけではありません。
代わりに、Bridge Server 側で定義した「最近よく使われる主要モデル」のリストを提供し、必要に応じてモバイルアプリも同じ curated list をフォールバックとして使います。

これはモバイルでの設定やモデル選択をシンプルに保ちつつ、多くのユーザーが必要とするモデルを十分にカバーするための方針です。
追加のモデル対応は、利用可能モデルの一覧を Bridge 側で管理しているため、比較的簡単に行えます。

Codex CLI や Claude では使えるのに CC Pocket に表示されないモデルが必要な場合は、使いたい正確なモデル名を添えて Issue を作成してください。

## Worktree 設定 (`.gtrconfig`)

セッション開始時に **Worktree** を有効にすると、[git worktree](https://git-scm.com/docs/git-worktree) で独立したブランチ・ディレクトリが自動的に作成されます。同じプロジェクトで複数のセッションを競合なく並行して実行できます。

プロジェクトルートに [`.gtrconfig`](https://github.com/coderabbitai/git-worktree-runner?tab=readme-ov-file#team-configuration-gtrconfig) を配置して、ファイルコピーとライフサイクルフックを設定します:

| セクション | キー | 説明 |
|-----------|------|------|
| `[copy]` | `include` | コピーするファイルの glob パターン（`.env` や設定ファイル等） |
| `[copy]` | `exclude` | コピーから除外する glob パターン |
| `[copy]` | `includeDirs` | 再帰的にコピーするディレクトリ名 |
| `[copy]` | `excludeDirs` | 除外するディレクトリ名 |
| `[hook]` | `postCreate` | worktree 作成後に実行するシェルコマンド |
| `[hook]` | `preRemove` | worktree 削除前に実行するシェルコマンド |

**Tips:** `.claude/settings.local.json` を `include` に含めるのが特におすすめです。MCP サーバー設定やパーミッション設定が各 worktree セッションに自動的に引き継がれます。

<details>
<summary><code>.gtrconfig</code> の設定例</summary>

```ini
[copy]
# Claude Code の設定（MCP サーバー、パーミッション、追加ディレクトリ）
include = .claude/settings.local.json

# node_modules をコピーして worktree 構築を高速化
includeDirs = node_modules

[hook]
# worktree 作成後に Flutter の依存関係を復元
postCreate = cd apps/mobile && flutter pub get
```

</details>

## Sandbox 設定 (Claude Code)

アプリからサンドボックスモードを有効にすると、Claude Code はネイティブの `.claude/settings.json`（または `.claude/settings.local.json`）のサンドボックス設定を使用します。Bridge 側の設定は不要です。

`sandbox` スキーマの詳細は [Claude Code ドキュメント](https://docs.anthropic.com/en/docs/claude-code) を参照してください。

## 典型的な使い方

- **常時稼働のホスト**（Mac mini、Raspberry Pi、Linux サーバー）上でエージェントを動かし、スマホから様子を見る
- **移動中の軽いレビュー運用** として、必要なときだけ返答や承認をする
- **複数プロジェクトの並列セッション** をスマホ側でまとめて追う
- **Tailscale 経由の個人インフラ** で外出先から安全に接続する

## リモートアクセスとマシン管理

### Tailscale

外出先から Bridge Server に繋ぐなら、Tailscale が最も手軽です。

1. ホストマシンとスマホの両方に [Tailscale](https://tailscale.com/) を入れる
2. 同じ tailnet に参加する
3. アプリから `ws://<host-tailscale-ip>:8765` に接続する

### 保存済みマシンと SSH

アプリには、host / port / API key / 任意の SSH 認証情報を持つマシンを登録できます。

SSH を有効にすると、マシンカードから以下の操作ができます。

- `Start`
- `Stop Server`
- `Update Bridge`

この運用は **macOS (launchd)** および **Linux (systemd)** ホストに対応しています。

### サービスセットアップ

`setup` コマンドは OS を自動判定し、Bridge Server をバックグラウンドサービスとして登録します。

```bash
npx @ccpocket/bridge@latest setup
npx @ccpocket/bridge@latest setup --port 9000 --api-key YOUR_KEY
npx @ccpocket/bridge@latest setup --uninstall

# グローバルインストール時
ccpocket-bridge setup
```

#### macOS (launchd)

macOS では launchd plist を生成し `launchctl` で登録します。`zsh -li -c` 経由で起動するため、nvm・pyenv・Homebrew 等のシェル環境がそのまま引き継がれます。

#### Linux (systemd)

Linux では systemd ユーザーサービスを生成します。セットアップ時に `npx` のフルパスを解決するため、nvm/mise/volta 経由の Node.js でも正しく動作します。

> **Tip:** `loginctl enable-linger $USER` を実行すると、ログアウト後もサービスが継続します。

## プラットフォーム補足

- **Bridge Server**: Node.js と CLI provider が動く環境なら利用可能
- **サービスセットアップ**: macOS (launchd) および Linux (systemd)
- **アプリからの SSH start/stop/update**: macOS (launchd) または Linux (systemd) ホスト
- **ウィンドウ一覧とスクリーンショット取得**: macOS ホスト専用
- **Tailscale**: 必須ではないが、リモート接続には強く推奨

常時稼働マシンとしては、Mac mini やヘッドレスの Linux ボックスが相性の良い構成です。

## スクリーンショット機能のためのホスト設定

macOS でスクリーンショット機能を使う場合は、Bridge Server を起動するターミナルアプリに **画面収録** 権限を付与してください。

権限がないと、`screencapture` が黒い画像を返すことがあります。

場所:

`システム設定 -> プライバシーとセキュリティ -> 画面収録`

常時稼働ホストで安定してウィンドウキャプチャを使うなら、ディスプレイのスリープと自動ロックも無効化しておくのがおすすめです。

```bash
sudo pmset -a displaysleep 0 sleep 0
```

## 開発

### リポジトリ構成

```text
ccpocket/
├── packages/bridge/    # Bridge Server (TypeScript, WebSocket)
├── apps/mobile/        # Flutter mobile app
└── package.json        # npm workspaces root
```

### ソースからビルド

```bash
git clone https://github.com/K9i-0/ccpocket.git
cd ccpocket
npm install
cd apps/mobile && flutter pub get && cd ../..
```

### よく使うコマンド

| コマンド | 説明 |
|---------|------|
| `npm run bridge` | Bridge Server を開発モードで起動 |
| `npm run bridge:build` | Bridge Server をビルド |
| `npm run dev` | Bridge を再起動し、Flutter アプリも起動 |
| `npm run dev -- <device-id>` | デバイス指定付きで同上 |
| `npm run setup` | Bridge Server をバックグラウンドサービスとして登録 (launchd/systemd) |
| `npm run test:bridge` | Bridge Server のテスト実行 |
| `cd apps/mobile && flutter test` | Flutter テスト実行 |
| `cd apps/mobile && dart analyze` | Dart 静的解析 |

### 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `BRIDGE_PORT` | `8765` | WebSocket ポート |
| `BRIDGE_HOST` | `0.0.0.0` | バインドアドレス |
| `BRIDGE_API_KEY` | 未設定 | API key 認証を有効化 |
| `BRIDGE_ALLOWED_DIRS` | `$HOME` | 許可するプロジェクトディレクトリ。カンマ区切り |
| `DIFF_IMAGE_AUTO_DISPLAY_KB` | `1024` | 画像 diff の自動表示しきい値 |
| `DIFF_IMAGE_MAX_SIZE_MB` | `5` | 画像 diff プレビューの最大サイズ |
| `BRIDGE_DISABLE_MDNS` | 未設定 | mDNS 自動発見のアドバタイズメントを無効化 |

## ライセンス

[FSL-1.1-MIT](LICENSE) — ソースコード公開。2028-03-17 に自動的に MIT へ移行します。

`@ccpocket/bridge` には Bridge Redistribution Exception を設けています。
Windows、WSL、proxy 必須環境、enterprise network など、メンテナが継続的に
検証しづらい環境向けの非公式再配布や環境特化 fork は許可されます。

ただし、それらの配布物は非公式かつ無保証であることを明確にしてください。
Anthropic、OpenAI、社内ネットワーク規約その他の第三者条件への適合責任は、
配布者および利用者にあります。
