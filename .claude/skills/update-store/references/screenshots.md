# ストアスクリーンショット

コマンドはリポジトリルート基準。撮影は指定されたデバイスだけを対象とする。構成・見出し文言・出力先の正本は [apps/mobile/fastlane/screenshots/README.md](../../../../apps/mobile/fastlane/screenshots/README.md) と `compose.sh`。この手順と食い違う場合はそちらに合わせて更新する。

## 既定: macOS のプレビューで一括撮影

[apps/mobile_preview](../../../../apps/mobile_preview/README.md) は [multi_device_preview](https://pub.dev/packages/multi_device_preview) で ccpocket を iPhone 17 Pro・iPhone Duo（閉）・iPad Pro 13-inch (M5)（横）の3台に並べて動かす macOS アプリ。1回の遷移で3台が同じシナリオを表示し、各端末の画面をストアの解像度（1206x2622 / 1398x2034 / 2752x2064、アルファなし、ステータスバー 9:41）で保存する。シミュレーター・言語設定・権限ダイアログ・iPad の回転は不要。2026-11-03 に全29枚と compose.sh を通して確認済み。

```bash
bash scripts/landing-preview/prepare.sh
node scripts/landing-preview/serve.mjs &                # LP Video / Audio のメディア。PIDを控える
cd apps/mobile_preview
flutter run -d macos --debug --pid-file /tmp/mdp-run.pid > /tmp/mdp-run.log 2>&1 &
grep "Dart VM Service" /tmp/mdp-run.log                 # 起動を待ち、さらに数秒（初期化）待つ
cd ../..
node scripts/store-preview/capture.mjs ws://127.0.0.1:<port>/<token>=/ws   # --only iphone|ipad で絞れる
```

- `capture.mjs` が下の表の全シナリオを開き、iPhone・Duo はダーク、iPad はライトで `en-US/` に保存し、最後にテーマと言語を system に戻す。
- プレビューのウィンドウは前面に出しておく（macOS は隠れたウィンドウを描画しないため、保存が失敗する）。
- hot restart はしない。media_kit（mpv）が破棄中に落ちてアプリごと終了することがある。コードを変えたら `flutter run` からやり直す。
- 端末内の判定は iOS として振る舞う（`debugDefaultTargetPlatformOverride`）。ネイティブ機能（通知・Keychain など）は macOS のものになるが、ストア用シナリオは使わない。
- 撮影後は「5. 解像度の確認」以降（compose.sh・目視）に進む。ステータスバーは電池 76%・セルラー表示ありで固定（シミュレーター撮影の 100%・Wi-Fi のみとは異なる）、画面下にホームインジケーターが写る。

以下のシミュレーター手順は、プレビューで再現できない表示（ネイティブUI・キーボードなど）を撮るときの代替。2026-11-02 に Xcode 27.2 / iOS 27.2 で全手順を確認済み。

## 前提（シミュレーター）

- debug ビルド（iOSシミュレーターは profile 不可）。ストア用 `ccpocket.navigateToStoreScenario` と LP 用 `ccpocket.mock.openScenario` は debug でのみ登録される。
- Marionette MCP の `call_custom_extension` と `tap`。
- ImageMagick（`magick`）と ffmpeg（LPメディアの準備）。
- agent-device: ネイティブダイアログと iPad の回転に使う。`mise exec -- agent-device ...` で実行する。
- Xcode 27.2 以降は Simulator.app ではなく `DeviceHub.app`。GUI が必要なら [mobile-automation の startup.md](../../mobile-automation/references/startup.md) を参照。撮影自体は `simctl` だけで完結する。

## 撮影対象

### iPhone（8枚・ダークテーマ・英語UI）

raw は `apps/mobile/fastlane/screenshots/en-US/<key>.png`。各言語の枠付き画像は `compose.sh` が en-US の raw から作る。

| Key | 呼び出し | 引数 `scenario` | 補足 |
|-----|---------|----------------|------|
| `01_conversation` | `ccpocket.mock.openScenario` | `LP Conversation` | |
| `02_recent_sessions` | `ccpocket.navigateToStoreScenario` | `Recent Sessions` | |
| `03_approval_list` | `ccpocket.navigateToStoreScenario` | `Approval List` | |
| `04_git_review` | `ccpocket.navigateToStoreScenario` | `Git Actions` | 既存画像には差分コメント（"Keep retries safe…"）が表示されているが、遷移だけでは出ない。再現手順は未確立 |
| `05_network_resilience` | `ccpocket.mock.openScenario` | `LP Network` | |
| `06_imagegen` | `ccpocket.mock.openScenario` | `LP Imagegen` | |
| `07_video` | `ccpocket.mock.openScenario` | `LP Video` | 読み込み後に Marionette `tap` key `file_peek_video_viewport` で操作UIを出してから撮る。12s 表示を確認 |
| `08_audio` | `ccpocket.mock.openScenario` | `LP Audio` | 12s 表示を確認 |

会話内の時刻はモックが現在時刻から生成するため、撮影時刻に応じて変わる。

### iPhone Duo（8枚・外側画面・ダークテーマ・英語UI）

iPhone と同じ8シナリオ・同じ見出しを、iPhone Duo の外側画面（縦 1398x2034）で撮る。raw は `en-US/duo_<key>.png`（`<key>` は iPhone の表と同じ）。Duo の操作列（右の縦列）が写る。手順は「3b. iPhone Duo 撮影」。

### iPad（5枚・landscape・英語UI）

raw は `en-US/ipad_<key>.png`。テーマは `light` に設定し、`Dark Workspace` はシナリオ側でダークに切り替わる。

| Key | `ccpocket.navigateToStoreScenario` の `scenario` |
|-----|------------------------------------------------|
| `01_workspace_overview` | `Workspace Overview` |
| `02_workspace_explorer` | `Workspace Explorer` |
| `03_approval_context` | `Approval In Context` |
| `04_approval_queue` | `Approval Queue` |
| `05_dark_workspace` | `Dark Workspace` |

## 1. デバイス準備

| 用途 | デバイス | raw 解像度 |
|------|---------|-----------|
| iPhone | iPhone 17 Pro | 1206x2622 |
| iPad | iPad Pro 13-inch (M5) | 2752x2064（landscape） |
| iPhone Duo | iPhone Duo（iOS 27.2 専用ランタイム） | 1398x2034（外側画面・縦） |

iOS 27.2 の標準デバイスに iPhone 17 Pro は含まれない。既存がなければ作成する（デバイスタイプは残っている）。

```bash
xcrun simctl list devices available | grep -E "iPhone 17 Pro|iPad Pro 13"
xcrun simctl create "iPhone 17 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2
```

iPhone と iPad を同時に起動したまま進めるため、`booted` は使わず UDID を変数に入れて指定する（`booted` は複数起動時に対象が曖昧になる）。既存シミュレーターを再利用し、`erase` しない。`erase` すると通知などのダイアログが毎回復活する。

```bash
ID=<撮影するデバイスのUDID>
xcrun simctl boot $ID 2>/dev/null || true

# システムを英語化（DatePicker・システムダイアログ・iPadステータスバーの日付も英語になる）。反映に再起動が必要
xcrun simctl spawn $ID defaults write -g AppleLanguages "(en-US)"
xcrun simctl spawn $ID defaults write -g AppleLocale "en_US"
xcrun simctl shutdown $ID && xcrun simctl boot $ID

# ステータスバーを 9:41 / Wi-Fi / 100% に固定
xcrun simctl status_bar $ID override --time "9:41" --dataNetwork wifi --wifiMode active \
  --wifiBars 3 --cellularMode notSupported --batteryState charged --batteryLevel 100
```

iPad のステータスバーには日付も出るが、`status_bar --time` では変えられない。システム日付のまま許容する。

### 権限ダイアログ

iOS 27.2 では `xcrun simctl privacy $ID grant notifications|speech-recognition` が `Failed to create TCC authorization record` で失敗する。事前付与できるのは `microphone` など `simctl privacy` の一覧にあるサービスだけ。通知ダイアログは初回起動時に出るので、アプリ起動後にセッションなしで処理する。

```bash
mise exec -- agent-device alert get --platform ios --udid $ID
mise exec -- agent-device alert accept --platform ios --udid $ID
```

一度許可すれば、`erase` しない限り再発しない。

### ソフトウェアキーボード

Xcode 27.2（DeviceHub）では `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool true` が効かず、入力欄にフォーカスするとソフトウェアキーボードが出る。現行の13シナリオは入力欄にフォーカスしないので対策は不要。映り込んだら `ccpocket.popToRoot` してシナリオを開き直す。

## 2. アプリ起動 & Marionette 接続

`flutter run` は1台ずつ実行する。同じプロジェクトを並行ビルドすると `build/ios` が衝突して失敗する。

```bash
cd apps/mobile
flutter run -d $ID --debug --pid-file /tmp/ss-run.pid > /tmp/ss-run.log 2>&1 &
grep "Dart VM Service" /tmp/ss-run.log   # 起動完了まで待つ
```

出力の `http://127.0.0.1:<port>/<token>=/` を `ws://127.0.0.1:<port>/<token>=/ws` にして Marionette `connect` に渡す。dart-mcp `launch_app` が使える環境ならそれでもよい。

LP シナリオ（Video / Audio）用のメディアを用意する。サーバーは撮影が終わるまで動かしておく。

```bash
bash scripts/landing-preview/prepare.sh
node scripts/landing-preview/serve.mjs &   # 127.0.0.1:8898。PIDを控える
```

起動直後のアプリに `agent-device open <app>` すると、アプリが再起動されて `flutter run` の接続が切れることがある（`/tmp/ss-run.log` に `Lost connection to device.`）。ダイアログ処理は上記のセッションなしコマンドで行い、切れた場合は `flutter run` からやり直す。

## 3. iPhone 撮影

接続後に一度だけ設定する。

- `ccpocket.setLocale` / `{ "locale": "en" }`
- `ccpocket.setTheme` / `{ "theme": "dark" }`

各 Key について次を繰り返す。

1. 表の呼び出しと `scenario` で遷移する。
2. 3秒待つ（Video / Audio はメディアの読み込みを待つ）。
3. 撮影する。

   ```bash
   xcrun simctl io $ID screenshot apps/mobile/fastlane/screenshots/en-US/<key>.png
   ```

4. `ccpocket.popToRoot` で戻る。

## 3b. iPhone Duo 撮影

Duo は他の作業でも使われていることが多い。`mise exec -- agent-device session list` で既存セッションを確認し、あればそのセッション名で `fold` する（新しく `open` するとアプリが再起動されることがある）。

- システム言語は変えない（変更には再起動が必要で、実行中の `flutter run` が切れる）。アプリ内の `setLocale en` と `setTheme dark` で足りる。撮影後は `setLocale ""`・`setTheme system` で元に戻す。
- 閉じた状態（外側画面）で撮る: `mise exec -- agent-device fold closed --session <name>`。
- ステータスバーは iPhone と同じ `status_bar override`（9:41）。時刻は右の操作列の上に出る。
- 外側画面は `--display=1`（内側は `--display=3`）。`simctl` のエラー出力で番号を確認できる。

```bash
xcrun simctl io $ID screenshot --display=1 apps/mobile/fastlane/screenshots/en-US/duo_<key>.png
```

各 Key は iPhone と同じく、遷移 → 3秒待機（Video / Audio は読み込み待ちと操作UI表示）→ 撮影 → `ccpocket.popToRoot`。`Recent Sessions` / `Approval List` のストア用モック一覧は、操作列があると本物と同じく検索と New を列に、ギャラリー等をタイトル横の接続先メニューに移す。撮影後に `fold open` と `status_bar clear` で戻す。

## 4. iPad 撮影

iPhone の `flutter run` を止めてから、iPad で起動・接続する。設定は `setLocale en` と `setTheme light`。

landscape に固定するには agent-device のセッションが必要（`orientation` はセッションなしでは動かない）。アプリが起動して落ち着いてから開く。

```bash
mise exec -- agent-device open com.k9i.ccpocket --platform ios --udid $ID --session ss-ipad
mise exec -- agent-device orientation landscape-left --session ss-ipad
```

各 Key について遷移 → 3秒待機 → 撮影 → `ccpocket.popToRoot`。iOS 27.2 の `simctl io` は landscape のまま保存するが、縦で保存された場合に備えて向きを確認する。

```bash
OUT=apps/mobile/fastlane/screenshots/en-US/ipad_<key>.png
xcrun simctl io $ID screenshot "$OUT"
W=$(sips -g pixelWidth "$OUT" | tail -1 | awk '{print $2}')
H=$(sips -g pixelHeight "$OUT" | tail -1 | awk '{print $2}')
[ "$W" -lt "$H" ] && sips -r 270 "$OUT" --out "$OUT" >/dev/null
```

撮影後に `mise exec -- agent-device close --session ss-ipad`。

## 5. 解像度の確認

raw がすべて期待値（iPhone 1206x2622、iPad 2752x2064、iPhone Duo 1398x2034）になっていることを確認する。Duo のサイズは `compose.sh` も検査する。iPad が大幅に小さい場合は互換モード（iPhone用ウィンドウ + 黒帯）を疑い、まずアプリを再起動する。解消しない場合に限り `erase` する。

```bash
cd apps/mobile/fastlane/screenshots/en-US
for f in 0[1-8]_*.png ipad_0[1-5]_*.png; do
  case $f in *_framed.png) continue;; esac
  echo "$f $(sips -g pixelWidth -g pixelHeight $f | tail -2 | awk '{print $2}' | tr '\n' ' ')"
done
```

## 6. 合成 & 配置

```bash
bash apps/mobile/fastlane/screenshots/compose.sh
```

所要時間は約2分。en-US の raw を ja / zh-CN / ko にコピーし、各言語の見出しで枠付き画像を作る。出力先は次のとおり。

- `fastlane/screenshots/store/{en-US,ja,zh-Hans,ko}/`: iPhone 8枚 + iPad 5枚（1320x2868 / 2752x2064、alpha なし）
- `fastlane/metadata/android/{en-US,ja-JP,zh-CN,ko-KR}/images/phoneScreenshots/`: iPhone 8枚
- `fastlane/screenshots/store_duo/{en-US,ja,zh-Hans,ko}/`: iPhone Duo 8枚（1398x2034、alpha なし）。fastlane deliver は Duo のサイズを扱えないため `store/` とは分け、`upload-metadata.yml` の `upload_duo_screenshots` で asc（`APP_IPHONE_DUO`）から上げる。
- `docs/images/screenshots*.png`: README バナー

合成の挙動だけを試すときは、`apps/mobile/fastlane/{screenshots,metadata/android}` を `/tmp/<dir>/apps/mobile/fastlane/` に複製し、`/tmp/<dir>/docs/images` を作ってから複製側の `compose.sh` を実行すれば、リポジトリの素材を変更しない。

## 7. 確認

- 生成画像を数枚開き、見出し・枠・UIの欠けを目視する。
- Duo は asc 6.3.0 で検証する: `asc screenshots validate --path apps/mobile/fastlane/screenshots/store_duo/<locale> --device-type APP_IPHONE_DUO`（認証不要）。
- `git diff --stat` で変更範囲を確認する。

## 8. 後片付け

自分が起動したものだけを止める。プレビューで撮った場合は `kill $(cat /tmp/mdp-run.pid)` とメディアサーバーの停止だけでよい。

```bash
kill $(cat /tmp/ss-run.pid)          # flutter run
kill <serve.mjs の PID>               # LPメディアサーバー
mise exec -- agent-device session list
xcrun simctl status_bar $ID clear     # override は再起動後も残る
xcrun simctl spawn $ID defaults write -g AppleLanguages "(ja-JP)"
xcrun simctl spawn $ID defaults write -g AppleLocale "ja_JP"
xcrun simctl shutdown $ID
```
