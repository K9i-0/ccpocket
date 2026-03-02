# Whisper 音声入力エンジン統合 調査

## 背景

競合アプリが Whisper をオンデバイス音声入力エンジンとして採用している。
現在 ccpocket は `speech_to_text` パッケージ（OS標準エンジン）のみ対応。
Whisper エンジンを選択肢として追加したい。

## 現状の音声入力実装

- **パッケージ**: `speech_to_text: ^7.3.0`
- **エンジン**: iOS = Apple Speech / Android = Google Speech-to-Text
- **設定**: 言語選択のみ (`speechLocaleId`, デフォルト `ja-JP`)
- **主要ファイル**:
  - `lib/services/voice_input_service.dart` — STTラッパー
  - `lib/hooks/use_voice_input.dart` — Hook (lifecycle管理)
  - `lib/features/settings/state/settings_state.dart` — 設定state
  - `lib/features/settings/widgets/speech_locale_bottom_sheet.dart` — 言語選択UI

## Whisper モデルサイズ

モバイルでは tiny〜small が現実的。medium 以上はストレージ・メモリ的に厳しい。

| モデル | サイズ | 速度 | 精度 | モバイル適性 |
|--------|--------|------|------|-------------|
| **tiny** | ~75 MB | 最速 | 低 | ◎ |
| **base** | ~142 MB | 高速 | 良 | ◎ |
| **small** | ~466 MB | 普通 | 高 | ○ |
| medium | ~1.5 GB | 遅い | 高 | △ 非推奨 |
| large | ~3 GB | 非常に遅い | 最高 | × 非現実的 |

各モデルに **English Only** と **Multilingual** の2バリアントがある。
English Only の方が英語に特化しており、同サイズでも英語精度が高い。

## Flutter パッケージ候補

### 第1候補: whisper_ggml (MIT)

- **Likes**: 28 (最多)
- **ライセンス**: MIT
- **iOS/Android**: 両対応 (CoreML最適化あり)
- **モデルDL**: 自動ダウンロード対応、アセットバンドルも可
- **特徴**: release モードで5倍高速

### 第2候補: whisper_ggml_plus (MIT)

- **DL数**: 1,202 (最多)
- **ライセンス**: MIT
- **iOS/Android**: 両対応 + Linux/Windows
- **モデルDL**: 手動 (HTTPで自前DL)
- **特徴**: 最新 whisper.cpp (v1.8.3)、量子化モデル対応 (q2_k, q3_k, q5_0)、Large-v3-Turbo 対応

### 候補外

| パッケージ | 除外理由 |
|-----------|---------|
| whisper_flutter_new | GPL-3.0 (プロプライエタリ不可) |
| whisper_flutter_coreml | GPL-3.0 |
| flutter_whisper_kit | iOS のみ |
| whisper_kit | Android のみ |
| sherpa_onnx | 汎用すぎる、Whisper特化ではない |

## 実装方針 (案)

### 設定UI

競合アプリと同様の構成:

```
SPEECH ENGINE
├── Native (現行の speech_to_text)  ← デフォルト
└── Whisper (オンデバイス、モデルDL必要)

── Whisper 選択時 ──
ENGLISH ONLY
├── Tiny   (75 MB)
├── Base   (142 MB)
└── Small  (466 MB)

MULTILINGUAL
├── Tiny   (75 MB)
├── Base   (142 MB)
└── Small  (466 MB)
```

### モデル管理

- ユーザーがモデルを選択した時点でダウンロード開始 (オンデマンド)
- ダウンロード進捗をUIに表示
- ダウンロード済みモデルにはチェックマーク表示
- モデル削除機能も提供 (ストレージ節約)
- アプリの Documents ディレクトリに保存

### 設定State の変更

```dart
// 追加するフィールド
enum SpeechEngine { native, whisper }
enum WhisperModelType { tiny, base, small }
enum WhisperModelVariant { englishOnly, multilingual }

// settings_state.dart に追加
speechEngine: SpeechEngine          // デフォルト: native
whisperModelType: WhisperModelType  // デフォルト: base
whisperModelVariant: WhisperModelVariant // デフォルト: multilingual
```

### VoiceInputService の変更

- `SpeechEngine` に応じてバックエンドを切り替え
- Whisper 選択時は whisper_ggml (or whisper_ggml_plus) を使用
- Native 選択時は既存の speech_to_text をそのまま使用

## 未決事項

- [ ] whisper_ggml vs whisper_ggml_plus の最終選定 (実際に動かして比較)
- [ ] ストリーミング認識の対応状況確認 (部分結果のリアルタイム表示)
- [ ] iOS / Android 両プラットフォームでの実機検証
- [ ] モデルダウンロードの通信量・時間の実測
- [ ] Whisper 選択時の言語設定との連携 (Multilingual モデルの言語指定方法)
