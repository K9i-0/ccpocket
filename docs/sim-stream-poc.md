# sim-stream: iOS Simulator Remote Viewer

## 概要

Bridge Server を動かしている Mac の iOS Simulator を、iPhone のブラウザからリモート操作するプロトタイプ。

## 検証結果サマリー

| 項目 | ScreenCaptureKit (推奨) | screencapture (fallback) |
|------|------------------------|--------------------------|
| 映像配信 | MJPEG multipart HTTP: **29fps, 65KB/frame** | **12fps, 81KB/frame** |
| タッチ入力 | AXe CLI: タップ ~50ms, スワイプ, テキスト入力対応 | 同左 |
| 座標変換 | window pixels → AXe points 自動マッピング | 同左 |
| データ帯域 | ~2MB/s | ~1MB/s |
| CPU負荷 | Swift デーモン (H/W accelerated) | screencapture CLI |

## アーキテクチャ

```
iPhone Safari
  ├─ GET /stream          ← MJPEG multipart (29fps JPEG)
  └─ WS  /ws              → tap/swipe/type イベント送信
       │
  Node.js (port 8100)
  ├─ Swift daemon (ScreenCaptureKit)  → stdout: length-prefixed JPEG
  │   └─ fallback: screencapture -l <WindowID> (デーモン未ビルド時)
  └─ AXe tap/swipe/type CLI          ← WebSocket events (座標変換付き)
       │
  iOS Simulator (macOS)
```

## 検証で試した方式と結果

### 1. simctl io recordVideo → TCP ストリーム ❌

```bash
xcrun simctl io booted recordVideo --codec=h264 tcp://127.0.0.1:9010
# → "Couldn't create an asset writer" エラー
# TCP/UDP URL 出力は現行 Xcode ではサポートされていない
```

### 2. simctl io recordVideo → FIFO パイプ → FFmpeg ❌

```bash
mkfifo /tmp/sim.mov && xcrun simctl io booted recordVideo /tmp/sim.mov
# → MOV コンテナはファイナライズ時に moov atom を書くため、パイプ非互換
```

### 3. FFmpeg AVFoundation screen capture + crop ⚠️

```bash
ffmpeg -f avfoundation -framerate 30 -i "Capture screen 0" \
  -vf "crop=440:939:1084:107" -f mjpeg pipe:1
# → 30fps キャプチャ成功だが、pipe 出力でバッファリング問題
# → CPU 使用率が非常に高い (800%+)
```

**結果**: ファイル出力は 30fps で動作するが、リアルタイムパイプ配信にはバッファリングの問題がある。

### 4. AXe stream-video (screenshot ベース) ⚠️

```bash
axe stream-video --udid <UDID> --format mjpeg --fps 15
# → 実測 3-5fps (simctl screenshot と同じ制約)
```

**結果**: MJPEG HTTP multipart 出力は正しく動作するが、FPS が品質不足。

### 5. screencapture -l (Window ID 指定) + Node.js ✅ fallback

```bash
screencapture -l <WindowID> -t jpg -x /tmp/frame.jpg
# → 1枚 ~60ms, JPEG 81KB, シミュレータウィンドウのみキャプチャ
```

**結果**: macOS 標準コマンドで安定・低CPU・高品質。12fps で十分操作可能。デーモン未ビルド時の fallback として採用。

### 6. ScreenCaptureKit Swift デーモン ✅ 推奨

```swift
// macOS 13+ の ScreenCaptureKit でウィンドウ単位の低遅延キャプチャ
let filter = SCContentFilter(desktopIndependentWindow: window)
let config = SCStreamConfiguration()
config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
let stream = SCStream(filter: filter, configuration: config, delegate: delegate)
```

**結果**: 29.4fps, 43KB/frame を安定達成。H/W accelerated で CPU 負荷も低い。

**実装詳細**:
- `packages/sim-stream/daemon/` に Swift Package として実装
- stdout に `[4byte BE uint32 = length][JPEG data]` で出力
- ImageIO による直接 JPEG エンコード (CIContext より高速)
- `desktopIndependentWindow` フィルタでタイトルバー・影なしキャプチャ
- idle フレーム (画面変化なし) は最後のフレームを再送して fps 維持

## 座標変換

screencapture の出力にはウィンドウ枠（タイトルバー・影）が含まれるため、AXe のポイント座標系との変換が必要。

```
screencapture: 508x1007 pixels (ウィンドウ全体 + 影)
CGWindow:      440x939  points (ウィンドウ論理サイズ)
AXe content:   402x874  points (シミュレータ画面コンテンツ)

コンテンツ開始位置: pixel(22, 70)
スケール: 1.15x, 1.07y
```

サーバー側で pixel → AXe point 変換を行い、クライアントは画像の naturalWidth/Height ベースの座標を送るだけ。

## 依存ツール

| ツール | インストール | 用途 |
|--------|-------------|------|
| AXe | `brew install cameroncooke/axe/axe` | タッチ入力・テキスト入力 |
| ws (npm) | `npm install ws` | WebSocket サーバー |
| Swift 5.9+ | Xcode 標準 | ScreenCaptureKit デーモンのビルド |
| screencapture | macOS 標準 | ウィンドウキャプチャ (fallback) |
| xcrun simctl | Xcode 標準 | シミュレータ検出 |

## 起動方法

```bash
cd packages/sim-stream

# 1. デーモンビルド (初回のみ)
npm run build:daemon

# 2. サーバー起動
node server.mjs

# 環境変数
SIM_STREAM_PORT=8100    # ポート番号
SIM_STREAM_FPS=30       # 目標FPS (デーモンモード)
SIM_STREAM_QUALITY=0.7  # JPEG品質 (0-1, デーモンモード)
```

**macOS Screen Recording 権限**: 初回起動時にシステム設定 > プライバシーとセキュリティ > 画面収録 でターミナルアプリに許可が必要。

デーモンが未ビルドの場合は自動的に screencapture fallback モードで起動する (12fps)。

## 制限事項・今後の改善点

### 現時点の制限

- **FPS**: ScreenCaptureKit デーモンで ~30fps (Rork のような 60fps にはまだ届かない)
- **ウィンドウ移動**: シミュレータウィンドウを移動すると座標がずれる (再起動で対応)
- **マルチタッチ**: シングルタッチのみ (ピンチ等は未対応)
- **遅延**: MJPEG + HTTP + WebSocket で合計 50-150ms

### 改善案

1. **WebRTC 化**: MJPEG → WebRTC に変更すれば遅延が大幅に低減
2. **ccpocket 統合**: Bridge Server に `/simulator` エンドポイントを追加し、チャットとシミュレータを並行操作
3. **Flutter WebView 統合**: ccpocket アプリ内にシミュレータビューを埋め込み
4. **60fps 化**: JPEG エンコードの最適化、または H.264 ストリーム化で 60fps を目指す
