---
name: web-preview
description: Flutter Web版をビルドしてユーザーにプレビューURLを案内する。playwright-cliでアクセス確認も行う。
disable-model-invocation: true
allowed-tools: Bash(bash:*), Bash(playwright-cli:*)
---

# Web Preview

Flutter Web版をビルド → サーバー起動 → Playwright でアクセス確認 → URLをユーザーに案内する。

## 手順

### 1. ビルド & サーバー起動（スクリプト）

```bash
bash .claude/skills/web-preview/scripts/web-preview.sh .
```

スクリプトが以下を一括で行う:
- `flutter build web --release`
- ポート8888の既存プロセスを停止
- `python3 -m http.server 8888` をバックグラウンド起動
- Tailscale IPを取得してURLを出力

最終行に `URL: http://<ip>:8888` が出力される。

### 2. Playwright でアクセス確認

スクリプト出力のURLを使って確認する:

```bash
playwright-cli open <URL>
playwright-cli screenshot --filename=web-preview.png
playwright-cli close
```

- スクリーンショットを取得してページが正常に表示されることを確認する
- エラーがあればユーザーに報告する

### 3. ユーザーへの案内

以下の情報をユーザーに伝える:

- アクセスURL
- スクリーンショット（確認用）
- ⚠️ ブラウザキャッシュクリア（Cmd+Shift+R）してからリロードすること
