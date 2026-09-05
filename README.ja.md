# CC Pocket

**エージェントを、ポケットに。**

CodexとClaudeを、スマホのチャット感覚で。指示を出し、次の操作を承認し、結果を確認。
タブレットやMacでも、同じ作業の続きを開けます。

[CC Pocketを見る](https://k9i-0.github.io/ccpocket/install/?lang=ja) · 無料で利用 · オープンソース

[English README](README.md) | [简体中文版 README](README.zh-CN.md) | [한국어 README](README.ko.md)

<p align="center">
  <img src="docs/images/screenshots-ja.png" alt="CC Pocket screenshots" width="800">
</p>

## インストール

1. セッションを実行するマシンに、少なくとも1つのエージェント CLI を入れます:
   [Codex](https://github.com/openai/codex) または [Claude](https://docs.anthropic.com/en/docs/claude-code)。
2. 同じマシンに [Node.js](https://nodejs.org/) 20.18.1 以上を入れます。
3. CC Pocket Bridge Server を起動します。

```bash
npx @ccpocket/bridge@latest
```

4. CC Pocket をインストールし、Bridge Server が表示する QR コードをスキャンします。
5. プロジェクトを選び、Codex / Claude を選択して、アプリからセッションを開始します。

| プラットフォーム | インストール |
|------------------|--------------|
| **iOS / iPadOS** | <a href="https://apps.apple.com/jp/app/cc-pocket-%E3%81%A9%E3%81%93%E3%81%A7%E3%82%82%E3%82%B3%E3%83%BC%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0/id6759188790"><img height="40" alt="App Storeからダウンロード" src="docs/images/app-store-badge.svg" /></a> |
| **Android** | <a href="https://play.google.com/store/apps/details?id=com.k9i.ccpocket"><img height="40" alt="Google Play で手に入れよう" src="docs/images/google-play-badge-ja.svg" /></a> |
| **macOS** | 最新の `.dmg` は [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=macos) からダウンロードできます。`macos/v*` タグのリリースを探してください。Homebrew Cask を用いて `brew install --cask cc-pocket` でインストールすることもできます。 |
| **Linux（実験的）** | 最新の `.tar.gz` は [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=linux) からダウンロードできます。`linux/v*` タグのリリースを探してください。コミュニティ管理の [AUR パッケージ](https://aur.archlinux.org/packages/cc-pocket-bin)を `yay -S cc-pocket-bin` でインストールすることもできます。 |
| **Windows（実験的）** | 最新の `.zip` は [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=windows) からダウンロードできます。`windows/v*` タグのリリースを探してください。 |

## 無料で利用できます

CC Pocket は無料で利用できます。もし開発ワークフローに役立ったら、アプリ内の Supporter から応援してもらえると助かります。いただいた支援は、AI ツール利用料や継続開発の維持に使われます。

## できること

- **チャット感覚で操作。** セッションごとに、指示・返答・承認・質問がひとつの部屋にまとまります。Markdown、音声入力、画像添付にも対応。
- **端末をまたいで続きから。** CLIやアプリのセッションを、スマホ・タブレット・Macで再開。大きな画面ではチャット、ファイル、Gitの差分を並べて確認できます。
- **通信が途切れても、入力を保持。** オフライン中のメッセージは再接続後に自動送信。取りこぼした応答も復元します。新しい依頼の実行には接続が必要です。
- **つくる、見る、再生する。** CodexのImagegenで画像を生成し、チャットで確認。動画や音声ファイルもアプリ内で再生できます。
- **確認から反映まで。** ファイル閲覧、コード・画像の差分、stage、commit、push、revertに対応。並列の作業はgit worktreeで分けられます。
- **自分のマシンで動かす。** Mac・Linux・Windows上のBridge Serverでエージェントを実行。QRコード、保存済みホスト、Tailscaleで接続し、SSHからBridgeを管理できます。

## Why fork CC Pocket?

CC Pocket は MIT ライセンスです。完成済みアプリとして使うだけでなく、自分の
エージェントワークフローを作るための土台として fork できます。

- Codex / Claude と、チームの Jira、Linear、GitHub、社内 REST API を組み合わせた内部向けクライアントを作れます。
- 使わない画面や機能を削ぎ落とし、日々のワークフローに特化したアプリにできます。
- Bridge 同期、承認フロー、プロンプト履歴、git 操作、ファイル閲覧、画像 / diff ビューアを再利用できます。
- ローカルのエージェントツールや既存のセッション履歴との互換性を保ちながら、プロンプトや MCP より GUI が向いている業務機能を追加できます。
- デスクトップ対応を拡張できます。macOS / Linux / Windows ビルドは現在利用できますが、Linux / Windows は継続検証環境が限定的なため experimental 扱いです。

実装の詳細は [technical stack page](https://k9i-0.github.io/ccpocket/architecture/) または
[agent-readable Markdown](https://k9i-0.github.io/ccpocket/architecture/stack.md) を参照してください。

## 仕組み

CC Pocket は2つの部分で動きます。

```text
CC Pocket app  <->  自分のマシン上の Bridge Server  <->  Codex / Claude
```

アプリは操作画面です。Bridge Server は、プロジェクト、シェル、git リポジトリ、
エージェント CLI にアクセスできる自分のマシン上で動きます。コードはホスト型 IDE
へ移さず、自分のマシンに置いたまま使えます。

## リモートアクセス

同じネットワーク内では、QR コード、mDNS 自動発見、または手入力の
`ws://` / `wss://` URL で接続できます。

自宅やオフィスの外から使う場合は、Tailscale がおすすめです。

1. ホストマシンとスマホに [Tailscale](https://tailscale.com/) を入れる
2. 同じ tailnet に参加する
3. CC Pocket から `ws://<host-tailscale-ip>:8765` に接続する

常時起動するホストでは、Bridge Server をバックグラウンドサービスとして登録できます。

```bash
npx @ccpocket/bridge@1 setup
```

サービス化は macOS launchd と Linux systemd に対応しています。
`BRIDGE_ALLOWED_DIRS` などの Bridge 設定・service setup で保存される項目は
[Bridge package README](packages/bridge/README.md#configuration) を参照してください。

## 補足

- Claude セッションはデフォルトで `ANTHROPIC_API_KEY` を使います。公式文書の適用範囲が
  明確でないため、サブスクリプション認証には `BRIDGE_ALLOW_CLAUDE_OAUTH=1` による
  Bridge 側の明示的な有効化が必要です。
  詳細は [Claude 認証トラブルシューティング](docs/auth-troubleshooting.ja.md) を参照してください。
- CC Pocket はセルフホストと最小限のデータ収集を前提にしています。Supporter 購入は
  同じ Apple ID / Google アカウント内で復元できますが、ストア間では共有されません。
  詳細は [Supporter / Purchases](docs/supporter_ja.md) を参照してください。
- macOS のスクリーンショット取得には、Bridge Server を実行するターミナルアプリへの
  画面収録権限が必要です。
- CC Pocket は Anthropic / OpenAI と提携、後援、または公式連携しているものではありません。

## 開発

```bash
git clone https://github.com/K9i-0/ccpocket.git
cd ccpocket
npm install
cd apps/mobile && flutter pub get && cd ../..
```

よく使うコマンド:

| コマンド | 説明 |
|----------|------|
| `npm run bridge` | Bridge Server を開発モードで起動 |
| `npm run bridge:build` | Bridge Server をビルド |
| `npm run dev` | Bridge を再起動して Flutter アプリを起動 |
| `npm run test:bridge` | Bridge Server のテストを実行 |
| `cd apps/mobile && flutter test` | Flutter テストを実行 |
| `cd apps/mobile && dart analyze` | Dart 静的解析を実行 |

貢献方法は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

[MIT](LICENSE)
