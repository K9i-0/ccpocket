# agent-device（ネイティブUI操作）

Flutter画面の操作は Marionette を使う。agent-device は Flutter の外側にあるネイティブUIだけに使う。

- 権限ダイアログ（通知・マイク・音声認識・カメラ・写真）、システムアラート、OSの共有シート・ファイルピッカー
- シミュレーター／エミュレーターの回転（`orientation`）、ホーム・戻るなどのハードウェア操作
- Marionette が接続できないrelease相当ビルドの外観確認

CLI は `.mise.toml` でバージョンを固定している。非対話シェルでは mise の PATH 切り替えが働かないため、常に `mise exec -- agent-device ...` で呼ぶ。未導入なら `mise install`。

## 基本ループ

```bash
mise exec -- agent-device open com.k9i.ccpocket --platform ios --udid <udid> --foreground
# 返るスナップショットの @ref を使って操作する
mise exec -- agent-device press @e3 --settle
mise exec -- agent-device close
```

- Android は `--platform android --serial emulator-5554`。
- `open` の前に `--help` や `devices` で探索しない。コマンド形が不明なときだけ `mise exec -- agent-device help <command>` を読む。
- 同じセッションへの変更系コマンドは直列に実行する。終わったら必ず `close` する。

## 権限ダイアログ

```bash
mise exec -- agent-device alert wait 8000   # 非同期に出るダイアログを待つ
mise exec -- agent-device alert get         # 文言を確認
mise exec -- agent-device alert accept      # 許可
mise exec -- agent-device alert dismiss     # 拒否
```

- 日本語ロケールのiOSシミュレーター、Androidの実行時権限ダイアログで動作確認済み。
- `alert` は押下の送信までしか保証しない。権限の結果はアプリの画面で確認する。
- iPhone Duo（折りたたみ・ウィンドウ表示）では `alert` がダイアログを検出できないことがある。その場合は `screenshot /tmp/ad.png` で位置を確認し、`press <x> <y>`（ポイント単位）でボタンを押す。
- フローの前提として権限を整えたいだけなら、ダイアログ操作より `xcrun simctl privacy booted grant <service> <bundleId>` / `adb shell pm grant <package> <permission>` を優先する。

## 回転

```bash
mise exec -- agent-device orientation landscape-left
mise exec -- agent-device orientation portrait
```

Android では自動回転が固定されたまま残るので、終了時に `orientation auto` で戻す。

## スクリーンショット

`agent-device screenshot` はポイント解像度で保存する。検証の証跡には使えるが、ストア素材は `xcrun simctl io booted screenshot` で原寸を撮る。
