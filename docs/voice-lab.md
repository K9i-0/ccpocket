# Mac ローカル音声入力ラボ

## 起動

リポジトリで `npm install` 済み、Node.js 20.18.1 以上、`codex` が PATH 上にあること。
通常の `codex login` で ChatGPT にログインした状態で実行する。

```sh
npm run voice:lab
```

Chrome で http://127.0.0.1:8790 を開く。停止はターミナルで Ctrl+C。
ポート変更は `VOICE_LAB_PORT=8791 npm run voice:lab`。
別バージョンの CLI は `CODEX_BIN=/absolute/path/to/codex npm run voice:lab`。

## 2026-09-18 の実機結果

- ローカル Codex CLI: 0.153.4。
- ChatGPT ログインの検出と一時スレッド作成まで成功。
- `gpt-live-1` / v3 と、モデル・プロトコルとも既定の設定で、
  `realtime conversation requires API key auth` が返りセッション開始不可。
- v3 は `outputModality: text` も拒否する（`text realtime output modality requires realtime v2`）。
  ラボは v2 のみ text、他は audio を指定し、返答音声を再生しない。
- この環境でサブスク枠の音声認識が利用できるとは確認できなかった。
  API キー認証への切り替えは実装していない。
- ブラウザ表示、実際のエラー表示、再接続、下書き編集・比較欄への保存を確認。
  マイクからサービスまでの文字起こしと認識精度は認証制限により未検証。

## 接続可能な環境での使い方

1. モデル・プロトコル・用語ヒントを選び「接続テスト」。
2. 接続済みになったら「録音開始」でマイクを許可する。
3. 日本語と技術用語を含む指示を話す。最大 60 秒。
4. 「録音停止・確定待ち」で 2 秒の無音を送り、認識結果を確認する。
   無音は確定要求ではないため、プロトコルによって確定通知が来ない可能性がある。
5. 下書きを編集・コピーし、比較欄へ保存する。チャットへの送信はしない。
6. 録音を WAV 保存し、設定を変えて再接続。同じ音声ファイルを実時間で再送できる。
7. 終了時は「切断」。結果とログは JSON 保存可能。タブを閉じると結果は消える。

モデル変更は再接続が必要。GPT-Live と GPT-Live-Transcribe は別の製品・API 契約であり、
モデル名の変更だけで文字起こし専用 API に切り替わるものではない。
本ツールは app-server の realtime 会話と user transcript 通知の検証に限定する。
`prompt` の用語ヒントは構造化 `keywords` と同じではなく、効果は未確認。
同じ録音で専門用語の正答、欠落、余計な語の追加、最初の文字までの時間を比較する。

## 構成と境界

- `scripts/voice-lab/server.mjs`: localhost HTTP とブラウザ WebSocket → 専用 app-server の stdio JSON-RPC。
- `app.js` / `capture.js`: AudioWorklet で 24 kHz mono PCM16 を 100 ms ごとに送信。
  ファイルは OfflineAudioContext で 24 kHz mono に変換。音声の自動ディスク保存なし。
- 一度に接続できるページは 1 つ。Host / Origin を固定し、任意 RPC の中継はしない。
- 認証情報をブラウザへ渡さず、API キーのみのログインは拒否する。
- スレッドは一時ディレクトリ・ephemeral・read-only。ツール承認要求は拒否し、
  万一開始した Codex ターンは割り込んで停止する。会話モデルへの指示だけに依存しない。
- 切断時に自分が起動した app-server を終了する。本番 Bridge 8765 は操作しない。
- app-server の生成スキーマで確認した experimental API を使用。
  古い CLI や非対応アカウントはエラーを表示する。CLI 更新後の再検証を想定する。
- 音声出力は捨てるが、サービス側で生成されることはあり、文字起こし専用とは同等でない。

## 検証

```sh
npm run test:voice-lab
node --check scripts/voice-lab/server.mjs
node --check scripts/voice-lab/app.js
node --check scripts/voice-lab/capture.js
```

テストは user transcript のみの追加、認証エラー後の復帰、マイク準備中の重複操作と切断を確認。
独立レビューで指摘された turnId 欠落、準備中の操作競合、比較設定の誤表示を修正した。

参照:
- https://developers.openai.com/codex/app-server
- https://developers.openai.com/api/docs/guides/live
- https://developers.openai.com/cookbook/examples/migrating_from_whisper_to_gpt_transcribe
