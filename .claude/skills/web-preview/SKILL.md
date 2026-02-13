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
- ポート8888の既存プロセスを停止（PIDファイル優先）
- `nohup python3 -m http.server` で安定してバックグラウンド起動
- `curl` で起動完了を待機・検証
- `LOCAL_URL`（`127.0.0.1`）と共有用 `URL`（Tailscale優先）を出力

出力例:

```text
PID: 12345
LOCAL_URL: http://127.0.0.1:8888
URL: http://<tailscale-ip>:8888
```

### 2. Playwright でアクセス確認

Playwright検証は `LOCAL_URL` を優先して実施する:

```bash
playwright-cli open <LOCAL_URL>
playwright-cli eval "document.title"
playwright-cli screenshot --filename=web-preview.png
playwright-cli close
```

- `document.title` が `ccpocket` であることを確認する
- スクリーンショットを取得してページが正常に表示されることを確認する
- エラーがあればユーザーに報告する

### 3. ユーザーへの案内

以下の情報をユーザーに伝える:

- ローカル確認URL（`LOCAL_URL`）
- 共有用URL（`URL`。通常はTailscale）
- スクリーンショット（確認用）
- ⚠️ ブラウザキャッシュクリア（Cmd+Shift+R）してからリロードすること

## トラブルシュート

- `ERR_CONNECTION_REFUSED` が出る場合:
  - `curl -I <LOCAL_URL>` でサーバー生存確認
  - `lsof -nP -iTCP:8888 -sTCP:LISTEN` で待受確認
  - `/tmp/ccpocket-web-preview-8888.log` を確認
- 一部の実行環境では、コマンド終了時にバックグラウンドプロセスが回収されることがある。
  その場合は別ターミナルで以下を起動してから Playwright を実行する:

```bash
cd apps/mobile/build/web
python3 -m http.server 8888
```
