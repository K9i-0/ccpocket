# Claude モデル一覧

アプリの新規セッションシートに出す Claude モデルは、Claude Code CLI の `/model` ピッカーと同じ内容にする。Bridge・アプリにバージョン付きのモデルIDをハードコードしない。

## 取得元

- Bridge は Agent SDK の `initializationResult().models`（セッション中は `supportedModels()`）から一覧を取る。SDK は同梱の Claude Code バイナリを起動し、そのバイナリがサーバー配信のモデルカタログから一覧を作る。
- そのため一覧の鮮度は `@anthropic-ai/claude-agent-sdk` のバージョンで決まる。Dependabot（`.github/dependabot.yml`）が Agent SDK を単独PRで毎週提案する。npm workspaces の lockfile はルートにあるので、npm の `directory` は `/` にする。
- `value` はカタログ次第で `fable` のような別名にも `claude-fable-5-1[1m]` のようなIDにもなる。アプリは `value` をそのまま Bridge へ返し、表示には `displayName` と `description` を使う。

## `session_list` のフィールド

| フィールド | 内容 |
|---|---|
| `claudeModels: string[]` | 既存。モデルの `value` 一覧。古いアプリ向けに維持する |
| `claudeModelOptions: {value, displayName?, description?}[]` | 追加。CLI と同じ表示名・説明 |
| `claudeModelEfforts: Record<string, string[]>` | 既存。モデルごとの effort |

- `description` から `$4/$20 per Mtok` のような料金セグメントを Bridge 側で除く（`stripClaudeModelPricing`）。CLI はサブスクリプション利用時に料金を出さず、Bridge も推定コストを出さない方針のため。
- 互換性: 新しいアプリが古い Bridge に接続した場合、`claudeModelOptions` がないので `claudeModels` から `value` だけの選択肢を作り、従来どおり `value` を表示する。古いアプリは追加フィールドを無視する。

## フォールバック

SDK が一覧を返せないときは、Bridge・アプリとも Claude Code のエイリアス `default` / `opus` / `sonnet` / `haiku` を使う。エイリアスは各系列の最新モデルに解決されるので、モデル更新時の修正は不要。effort は `default` / `opus` / `sonnet` に `low` / `medium` / `high`、`haiku` は空にする。
