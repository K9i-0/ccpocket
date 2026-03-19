# Claude 認証トラブルシューティング

[English](auth-troubleshooting.md) | [简体中文版](auth-troubleshooting.zh-CN.md)

CC Pocket は Bridge マシン上に保存された Claude Code のログイン状態を使います。
認証エラーが出たら、そのマシンで Claude Code に再ログインしてください。

## 手元に Bridge マシンがない場合

CC Pocket では、自宅の Mac mini や別の Mac を Bridge マシンとして動かしていることがあります。
その場合でも、iPhone などから遠隔で Claude Code に再ログインできます。

1. ターミナルアプリから Bridge マシンに接続
   - Moshi, Termius, Blink などで SSH 接続します
2. `claude` を実行
3. Claude Code の中で `/login` を実行
4. 表示された URL を iPhone や PC のブラウザで開く
5. サインインを完了する
6. 必要なら結果をターミナルに貼り付ける

次のリクエストから、CC Pocket が新しいログイン状態を使います。

## 手元に Bridge マシンがある場合

1. Bridge マシンで `claude` を実行
2. `/login` を実行
3. ブラウザでサインインを完了する

## シェルから実行する方法

対話画面を開かずに、次のコマンドでも再認証できます。

```bash
claude auth login
```

## よくある原因

- Claude Code のログイン期限が切れた
- Claude Code の更新で以前のログイン情報が無効になった
- Anthropic 側で保存済みトークンが失効した
