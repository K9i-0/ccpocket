# ccpocket

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Diff Image Preview

Diff画面では画像ファイルの変更をSide-by-side比較で表示します。
表示モードはBridge Server側の閾値で制御され、環境変数でカスタマイズ可能です。

| 環境変数 | デフォルト | 説明 |
|---------|-----------|------|
| `DIFF_IMAGE_AUTO_DISPLAY_KB` | `1024` (1MB) | この閾値以下の画像は自動でインライン表示 |
| `DIFF_IMAGE_MAX_SIZE_MB` | `5` (5MB) | この閾値以下はタップで読み込み可能。超過はサイズ情報のみ表示 |

```bash
# 例: 自動表示を512KBに、最大サイズを10MBに変更
DIFF_IMAGE_AUTO_DISPLAY_KB=512 DIFF_IMAGE_MAX_SIZE_MB=10 npm run bridge
```
