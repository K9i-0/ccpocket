---
name: sim-preview
description: iOSシミュレーターで動くFlutterアプリをExpo Device HubとTailscale HTTPSでスマホのブラウザへ配信・操作するときに使う。
---

# Simulator Preview (Expo Device Hub)

MacのiOSシミュレーターを **Expo Device Hub → Tailscale Serve (HTTPS) → スマホのブラウザ** で配信する。Expoプロジェクトは不要。Flutterアプリをそのまま確認・操作できる。

既定はH.264・30fps・最大1000px・2.5Mbps。Device Hub 0.10.1でccpocketの配信を確認し、ユーザーから旧VNC方式より快適との評価を得た設定。TrollVNC / noVNCを既定に戻さない。

## 1. シミュレーターとアプリ

```bash
xcrun simctl list devices booted
```

対象アプリが既に動いていれば再利用する。起動が必要な場合やhot reloadには [mobile-automation](../mobile-automation/SKILL.md) を使う。テスト用Bridgeが必要なら8766を使い、本番8765を停止・再起動しない。

前提はMac + Xcode、Node.js/npm、MacとスマホのTailscale接続。CoreSimulatorへのアクセスがサンドボックスで拒否された場合は、シミュレーターの故障と判断せず適切な実行権限で再確認する。

## 2. Device Hubを起動

既存のDevice HubとTailscale Serveの状態を確認し、目的の配信が動いていれば再利用する。

```bash
lsof -nP -iTCP:3400 -sTCP:LISTEN
tailscale serve status
```

新規起動には以下を使う。スクリプトはDevice Hubのみを起動し、アプリ起動やTailscale設定は別に行う。

```bash
bash .claude/skills/sim-preview/scripts/sim-preview.sh
```

- ローカル待受は `127.0.0.1:3400`。npm経由で検証済みバージョンを取得し、リポジトリの依存関係は変更しない。
- 長時間実行できるツールセッションで起動し、停止用のセッションID / PIDとログを控える。
- 3400が使用中ならプロセスを勝手に停止せず、既存配信を確認するか `SIM_PREVIEW_PORT=3401` などの空きポートを選ぶ。起動ログの実際のポートを確認する。
- 更新時は対象バージョンの `--help` を確認する。配信設定の変更はブラウザの「Stream options」からも試せる。

## 3. Tailscale内限定のHTTPSを設定

**リモートのH.264 / WebRTCにはHTTPSが必要。** `http://<Tailscale IP>:3400` ではMJPEGへフォールバックする。localhostでH.264が動くだけではスマホ向け検証の完了にならない。

`tailscale serve status` に今回のHubを指す設定があれば再利用する。未設定なら、起動ログのポートに合わせて設定する。

```bash
tailscale serve --bg --https=443 http://127.0.0.1:3400
```

- 443に別サービスの設定がある場合は上書きせず、未使用のHTTPSポート（例: `--https=8443`）を選ぶ。
- Serveが未有効なら、CLIが出力した有効化URLを案内する。ログインが必要ならユーザーに操作を依頼し、完了後に上記コマンドを再実行する。有効化だけでは転送設定が作成されないことがある。
- 出力された `https://<MacのDNS名>.ts.net[:port]/` を使う。ホスト名を固定値で書かない。
- `tailscale` がPATHにない環境では `/Applications/Tailscale.app/Contents/MacOS/Tailscale` を確認する。
- インターネット公開の `tailscale funnel` は使用しない。

## 4. 配信確認とユーザーへの案内

実際のHTTPS URLをブラウザで開き、以下を確認する。

- 対象シミュレーターが `Live` になり、ccpocketの映像が表示される。
- 「Stream options」でHTTP codecが **H.264**、Video FPSが **30 FPS**、Max sizeが **1000 px**、Video bitrateが **2.5 Mbps** になっている（意図して調整した場合はその値）。

スマホのTailscaleをONにして開くHTTPSリンクを案内する。ユーザーにタップ・スクロール・文字入力の体感を試してもらい、Mac側の表示確認とスマホ側の確認結果を区別して報告する。遅延が残る場合は同画面で解像度やビットレートを調整して比較する。

初回のページ遷移がタイムアウトしても、再度画面状態を確認すると `Live` になっている場合がある。MJPEGになる場合はHTTPS URLとコーデック設定を確認する。

## 5. 継続・終了

プレビュー依頼中はDevice HubとHTTPS転送を残す。コード変更後のhot reloadはFlutter側で行い、配信画面で結果を確認する。

停止を依頼されたら、自分が起動したHubのセッションまたはPIDだけを停止する。今回追加したServe設定も不要になった場合のみ、対象HTTPSポートの転送を解除する。

```bash
# 今回443に追加した転送を終了する場合。別ポートなら置き換える。
tailscale serve --https=443 off
```

既存の共有設定を巻き込む `tailscale serve reset` やプロセス名による一括killは使わない。

## 参照

- [Expo Device Hub](https://github.com/expo/expo-device-hub): standalone起動と配信方式。
- 起動オプション: `npm exec --yes --package=expo-device-hub@0.10.1 -- expo-device-hub --help`
