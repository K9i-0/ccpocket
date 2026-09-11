---
name: sim-preview
description: iOSシミュレーターのアプリをTrollVNC経由でリモートプレビューするときに使う。
---

# Simulator Preview (TrollVNC)

iOSシミュレーターでアプリを起動し、TrollVNC でリモートプレビュー環境を提供する。
ユーザーは iPhone の VNC Viewer アプリ（RealVNC Viewer 推奨）から Tailscale 経由で接続し、シミュレーター画面をリアルタイムで確認・操作できる。

## ワークフロー概要

```
iPhone (ユーザー)
  ├── ccpocket で Claude Code に指示
  ├── RealVNC Viewer でシミュレーター画面を確認
  └── 指示 → 変更 → hot reload → 目視確認 のループ
```

## 手順

### 1. アプリをビルド・起動

dart-mcp の `launch_app` でシミュレーターにアプリを起動する。
hot reload が使えるデバッグモードで起動される。

シミュレーターがまだ起動していない場合は、先にブートする:

```bash
# 利用可能なiPhoneシミュレーターを確認
xcrun simctl list devices available | grep iPhone

# 起動（UDIDを指定）
xcrun simctl boot <UDID>
```

起動済みのシミュレーターを確認:

```bash
xcrun simctl list devices booted
```

dart-mcp でアプリを起動:
- root: プロジェクトの `apps/mobile` ディレクトリ
- device に booted なシミュレーターの UDID を指定

### 2. TrollVNC 起動（スクリプト）

```bash
bash .claude/skills/sim-preview/scripts/sim-preview.sh
```

スクリプトが以下を行う:
- シミュレーターの起動確認（未起動なら自動ブート）
- trollvncserver バイナリをシミュレーターに配置
- VNC サーバー起動（ポート 5901、スケール 0.75、ナチュラルスクロール、サーバーサイドカーソル）
- Tailscale IP を検出して接続情報を出力

出力例:

```text
SIMULATOR: <UDID>
VNC_PORT: 5901
LOCAL_VNC: vnc://127.0.0.1:5901
TAILSCALE_VNC: vnc://<tailscale-ip>:5901
NOVNC_URL: http://<tailscale-ip>:5801/novnc/vnc_lite.html?...
```

### 3. ユーザーへの案内

スクリプト出力の `TAILSCALE_VNC` を使って、以下の情報をユーザーに伝える:

- **VNC 接続先**: `TAILSCALE_VNC` のアドレスとポート
- **推奨アプリ**: RealVNC Viewer（無料、スワイプ操作が自然）
- **操作方法**:
  - タップ: 1本指タップ
  - スワイプ: 1本指ドラッグ
  - ホームに戻る: マウスモードで2本指タップ（右クリック）
  - スクロール: 2本指スクロール
- **noVNC（ブラウザ）**: `NOVNC_URL` でも接続可能だが、アプリの方が操作性が良い

### 4. コード変更 → 確認ループ

コード変更後は dart-mcp の `hot_reload` でシミュレーターに即時反映される。
ユーザーは VNC Viewer で変化をリアルタイムに確認できる。

## 前提条件

- `~/bin/trollvncserver`: TrollVNC シミュレーター用バイナリ（ビルド済み）
- Tailscale: Mac と iPhone の両方で接続済み
- RealVNC Viewer: iPhone にインストール済み

## TrollVNC のビルド方法（初回のみ）

バイナリが存在しない場合のビルド手順:

```bash
# Theos（未インストールの場合）
git clone --recursive https://github.com/theos/theos.git ~/theos

# TrollVNC クローン
git clone --depth 1 https://github.com/OwnGoalStudio/TrollVNC.git /tmp/TrollVNC

# シミュレーター向けビルド（シミュレーターを起動しておくこと）
cd /tmp/TrollVNC && THEOS=~/theos make THEOS_DEVICE_SIMULATOR=1

# バイナリを配置
mkdir -p ~/bin
cp /tmp/TrollVNC/.theos/obj/iphone_simulator/debug/trollvncserver ~/bin/
chmod +x ~/bin/trollvncserver

# noVNC webclients（オプション）
mkdir -p ~/bin/trollvnc-webclients
cp -R /tmp/TrollVNC/layout/usr/share/trollvnc/webclients/* ~/bin/trollvnc-webclients/
```

## トラブルシュート

- **VNC 接続できない**: macOS ファイアウォールで trollvncserver の接続を許可する
- **画面が映らない**: `cat /tmp/trollvnc-sim-preview.log` でログ確認
- **既存の VNC が残っている**: `pkill -f trollvncserver` で停止してから再実行
- **シミュレーターが見つからない**: `xcrun simctl list devices available` で確認
