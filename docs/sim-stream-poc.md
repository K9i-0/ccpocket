# sim-stream: iOS Simulator Remote Viewer PoC

## 概要

Bridge Server を動かしている Mac の iOS Simulator を、iPhone のブラウザからリモート操作するプロトタイプ。

## 検証結果サマリー

| 項目 | 結果 |
|------|------|
| 映像配信 | screencapture → MJPEG multipart HTTP: **12fps, 81KB/frame** |
| タッチ入力 | AXe CLI: タップ ~50ms, スワイプ, テキスト入力対応 |
| 座標変換 | screencapture pixels → AXe points 自動マッピング |
| データ帯域 | ~1MB/s (LAN/Tailscale で十分) |
| CPU負荷 | screencapture のみで低負荷 (FFmpeg 不要) |

## アーキテクチャ

```
iPhone Safari
  ├─ GET /stream          ← MJPEG multipart (12fps JPEG)
  └─ WS  /ws              → tap/swipe/type イベント送信
       │
  Node.js (port 8100)
  ├─ screencapture -l <WindowID>  → JPEG → broadcast to clients
  └─ AXe tap/swipe/type CLI      ← WebSocket events (座標変換付き)
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

### 5. screencapture -l (Window ID 指定) + Node.js ✅ 採用

```bash
screencapture -l <WindowID> -t jpg -x /tmp/frame.jpg
# → 1枚 ~60ms, JPEG 81KB, シミュレータウィンドウのみキャプチャ
```

**結果**: macOS 標準コマンドで安定・低CPU・高品質。12fps で十分操作可能。

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
| screencapture | macOS 標準 | ウィンドウキャプチャ |
| xcrun simctl | Xcode 標準 | シミュレータ検出 |

## 起動方法

```bash
cd packages/sim-stream
node server.mjs

# 環境変数
SIM_STREAM_PORT=8100   # ポート番号
SIM_STREAM_FPS=12      # 目標FPS
SIM_STREAM_QUALITY=8   # JPEG品質 (screencapture デフォルト)
```

## 制限事項・今後の改善点

### 現時点の制限

- **FPS**: screencapture ベースのため最大 ~15fps (Rork のような 60fps には届かない)
- **ウィンドウ移動**: シミュレータウィンドウを移動すると座標がずれる (再起動で対応)
- **マルチタッチ**: シングルタッチのみ (ピンチ等は未対応)
- **遅延**: screencapture + HTTP + WebSocket で合計 100-200ms

### 改善案

1. **ScreenCaptureKit API (Swift)**: macOS 12.3+ の ScreenCaptureKit を使えばウィンドウ単位の低遅延キャプチャが可能。60fps も視野に入る
2. **WebRTC 化**: MJPEG → WebRTC に変更すれば遅延が大幅に低減
3. **ccpocket 統合**: Bridge Server に `/simulator` エンドポイントを追加し、チャットとシミュレータを並行操作
4. **Flutter WebView 統合**: ccpocket アプリ内にシミュレータビューを埋め込み

### 最も有望な次のステップ: ScreenCaptureKit

```swift
// ScreenCaptureKit は 60fps ウィンドウキャプチャをネイティブにサポート
let filter = SCContentFilter(desktopIndependentWindow: simulatorWindow)
let config = SCStreamConfiguration()
config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
let stream = SCStream(filter: filter, configuration: config, delegate: self)
```

Swift で小さなキャプチャデーモンを書き、Node.js サーバーに WebSocket/TCP でフレームを送る構成にすれば、Rork に近い品質が実現可能。
