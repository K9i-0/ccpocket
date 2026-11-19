# Antigravity（`agy acp`）連携の対応計画

> 調査日: 2026-11-18 / 対象: Antigravity CLI `agy` 1.5.10（ACP protocol version 1）
> 状態: Bridge とアプリに実装済み（2026-11-19、agy 1.5.12 で確認）。
> 公開上の位置づけ: 当面はプレビュー機能として出す（2026-11-19 決定）。`agy` があれば自動で表示し、新規セッション画面に「プレビュー」表記と注記を出す。README と Bridge の README にも preview として記載している。ストアの説明文には載せない。

Google Antigravity を ccpocket の3つ目のプロバイダーとして扱うための、判断・検証ルール・実装の要点をまとめる。

## 最重要: 検証時の認証ルール

**エージェントが `agy` にプロンプトを送るときは、必ず APIキー認証を使う。**

Google は、個人向け Google アカウントのログイン（`oauth-personal`。Free / Plus / Pro / Ultra のサブスク枠）で、別のエージェントや自律ループが `agy acp` / `agy -p` を駆動することを禁止している。違反はアカウント停止の対象になる。Claude Code、Codex、サブエージェント、`e2e-verifier` がプロンプトを書いて送る検証は、すべてこの「別エージェントによる駆動」にあたる。

| 誰がプロンプトを書くか | 使ってよい認証 |
|---|---|
| エージェント（サブエージェント、E2E、スクリプトの自動生成を含む） | APIキー（`gemini-api-key`）または Google Cloud（`agent-platform`）のみ |
| 人間が手入力する | どちらでも可 |

手順は次のとおり。

0. **Bridge 経由の検証は `bash scripts/e2e-env.sh bridge` のテスト用 Bridge で行う。** このスクリプトは `CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY=1` を立て、`.env.antigravity.local` のキーを `CCPOCKET_ANTIGRAVITY_API_KEY` として渡す。この状態の Bridge は、キーがなければ `agy` を起動せず、モデル一覧が Gemini のみでなければプロンプトを送らない。本番 Bridge（8765）や、このフラグのない Bridge に対して、エージェントが Antigravity セッションへ入力を送ってはいけない。`agy` を直接動かす検証は `scripts/antigravity-acp-probe.mjs` を使う。以下の 1〜4 は、どちらの経路でもコードが強制している内容。
1. **APIキー用プロファイルで起動する。** `agy acp --app-data-dir <APIキー用の名前>` を使う。既定プロファイル（`~/.gemini/antigravity-cli`）ではエージェントからプロンプトを送らない。
2. **毎回、最初に `authenticate`（`methodId: "gemini-api-key"`）を送る。** まっさらなプロファイルは、何もしないと Google ログインで動く（ログイン情報はプロファイル間で共有される）。
3. **`session/new` の応答でモデル一覧を確認してから、プロンプトを送る。** APIキーモードでは Gemini のみが返る。`claude-*` や `gpt-oss-*` が含まれていたら Google ログイン側で動いているので、送らずに中止する。
4. **既定プロファイルには `authenticate` を送らない。** 普段の `agy` が APIキーモードに切り替わる恐れがあり、戻す経路を確認できていない。
5. **APIキーはリポジトリ直下の `.env.antigravity.local` に `GEMINI_API_KEY=...` として置く。** gitignore 済みで、worktree にも複製される。`node scripts/antigravity-check-key.mjs` で、プロンプトを送らずに有効性を確認できる（キーの値は表示しない）。`~/.zshrc` でのグローバル export とコミットは不可（グローバルに置くと普段の `agy` / `gemini` まで従量課金側に切り替わる恐れがある）。
6. **本物のキーでの最初の1ターンのあと、AI Studio の使用量に計上されたことを確認する。** 無効なキーのときにログイン側へ落ちないかは未検証のため。

プロンプトを送らない操作（`initialize`、`session/new`、`session/list`、`session/load`、モードや設定の切替）は、既定プロファイルでも行ってよい。

このルールは初回実装だけでなく、以降の改修・不具合調査・E2E でも同じ。

## 決定事項

- **連携経路は `agy acp` を使う。** stdio 上の JSON-RPC（Agent Client Protocol）で、Codex の app-server と同じ構図になる。
- **認証の切替はプロファイル分離で行う。** Bridge が `agy acp` を起動するときに `--app-data-dir` を選ぶ。
- **エージェントによる開発・検証は APIキーで行う。**

採用しなかった経路:

| 経路 | 見送る理由 |
|---|---|
| Antigravity SDK（`google-antigravity`、Python） | Python 限定で、TypeScript 版は未提供。文書化された認証は APIキー / Vertex / ローカルモデルのみ |
| `agy -p` ヘッドレス（`stream-json`） | 承認の往復ができない（承認が必要な操作は soft-deny）。制御メッセージも不可 |
| `language_server agentapi` | 文書化されていない内部ツール |

## 認証方式（2026-11-19 決定）

- **既定は Google ログイン。** Bridge は既定プロファイルで `agy acp` を起動し、`authenticate` を送らない。ユーザーが `agy` でサインイン済みの状態をそのまま使う。人間が直接操作する対話クライアントとしての利用であり、下の Issue 回答で許容側とされた形にとどめる。
- **APIキーは任意。** Bridge の環境変数 `CCPOCKET_ANTIGRAVITY_API_KEY` を設定すると、専用プロファイル `antigravity-cli-ccpocket-apikey` で起動し、`authenticate`（`gemini-api-key`、キーは `_meta.apiKey`）を送る。キーは子プロセスの環境変数には入れない（エージェントが実行するコマンドへ渡さないため）。`GEMINI_API_KEY` は読まない（グローバルに export されたキーで黙って従量課金に切り替わらないようにするため）。
- **Bridge が自分でプロンプトを作る機能は、Antigravity に送らない。** ログイン認証で禁止されている「人間以外による駆動」にあたるため。
  - 自動リネームは Antigravity セッションでは無効。セッション名は `agy` が付けるタイトル（`session_info_update`）を使う。
  - コミットメッセージの自動生成は `agy` を使わない（既存どおり `claude` CLI を呼ぶ）。
  - `_meta.antigravity.systemPrompt.append` は使わない。
- セッション履歴はプロファイルごとに別なので、認証方式を切り替えると、もう一方で作った会話は一覧に出ない。

## 規約上の位置づけ

- **規約 §6**: 「Using third party software, tools, or services to access the Service (e.g. using OpenClaw with Antigravity OAuth) is a breach of this Agreement.」（[Additional Terms](https://antigravity.google/terms/)）
- **FAQ**: サードパーティのコーディングエージェントには Gemini Enterprise か Google AI Studio の APIキーを使うよう案内している。`agy` をサードパーティのエージェントやアプリでラップすることは「not supported under consumer plans」。（[FAQ](https://antigravity.google/docs/faq/)）
- **CLI リポジトリ [Issue #1493](https://github.com/google-antigravity/antigravity-cli/issues/1493)**（コラボレーター manirajc の回答、2026-11-12）:
  - 「Any interactive ACP v1 client, including editors like Zed, JetBrains IDEs, and Xcode as well as custom or non-editor interactive ACP UIs, may launch the unmodified agy acp binary when a human user is directly driving the session.」
  - 「Having another agent, autonomous loop, or background task queue generate prompts and drive agy acp or agy -p programmatically is not permitted on consumer OAuth, nor is overriding Antigravity's system identity instructions or automating account rotation.」
  - 個人・単一アカウント・非商用でも例外はない（「there is no carve-out for single-account or personal use」）。
  - APIキーと Google Cloud 認証は、それぞれの API / Cloud の規約が適用される。

Issue の回答は規約本文ではない。フレームワークがシステムプロンプトや履歴を自動で付ける場合の追加質問には回答がない。**配布アプリとしての ccpocket がサブスク認証で許容されるとは確定していない。**


## 検証で分かった仕様

サニタイズ済みのトレースを [antigravity-acp/](antigravity-acp/) に置いた。パーサーやイベント変換のユニットテストのフィクスチャに使える。

- [trace-turns.ndjson](antigravity-acp/trace-turns.ndjson): 5ターン（応答、ファイル編集の承認と拒否、コマンド実行、長めの出力）
- [trace-load.ndjson](antigravity-acp/trace-load.ndjson): 上のセッションの `session/load`（履歴リプレイ）

### 接続とセッション

- `initialize` の応答: `agentInfo.name` は `Antigravity ACP Server`。`loadSession`、`sessionCapabilities`（`resume` / `close` / `load` / `list` / `additionalDirectories`）、`promptCapabilities`（`image: true`、`audio: false`、`embeddedContext: true`）。
- `authMethods`: `oauth-personal` / `oauth-business` / `gemini-api-key` / `agent-platform`。
- `session/new` の応答にモデル一覧、モード一覧、設定オプション（`model`、`thought_level`）が入る。
- モードは `default` / `accept-edits` / `auto` / `plan`。`session/set_mode` で切り替わり、`current_mode_update` が届く。
- `session/set_config_option` で設定を変えると `config_option_update` が届く。
- `session/list` は `cwd` を指定しても他プロジェクトのセッションを返した。Bridge 側で絞り込む必要がある。
- `session/load` はユーザー発言（`user_message_chunk`）、応答、思考、ツール呼び出しをリプレイする。
- スラッシュコマンドは `available_commands_update` で届く（`/goal`、`/compact`、`/schedule`、`/browser`、`/plan` など）。

### ターンの流れ

- 思考は `agent_thought_chunk`、本文は `agent_message_chunk` で届く。
- 最初のターンで `session_info_update` によりタイトルが自動で付く。
- `usage_update` でコンテキスト使用量（`used` / `size`）が随時届く。`session/prompt` の応答に `stopReason` とトークン内訳（`inputTokens`、`outputTokens`、`cachedReadTokens`、`thoughtTokens`）が入る。
- ツール呼び出しは `tool_call`（`in_progress`）→ `tool_call_update`（`pending`）→ `session/request_permission` → `tool_call_update`（`in_progress` → `completed` / `failed`）の順。
- ツール呼び出しには ACP 標準の `rawInput` に加えて、同じ内容の `name` / `args` が付く。標準側だけ読めば足りる。
- ファイル編集の承認リクエストには `content` に diff（`path`、`newText`）が付く。
- コマンド実行は `run_command`（`kind: execute`）。`rawOutput` に出力と `exit_code` が入る。出力には `Created At` などのヘッダーと `\r\n` が混ざる。
- 承認リクエストの JSON-RPC ID は文字列（`"1"`、`"2"`…）で、クライアント側のリクエスト ID とは別系列。

### default モードで数回だけ観測した挙動

回数が少ないので、実装前に再確認する。

- 承認の選択肢は `allow_once` と `reject_once` の2つだけだった。「常に許可」に相当する選択肢は出なかった。
- 拒否するとツールが `failed` になり、エージェントの追加発言なしでターンが `end_turn` で終わった。

### 認証とプロファイル

ダミーキーを使い、プロンプトを送らずに確認した。

| 条件 | 結果 |
|---|---|
| 既定プロファイル、キーなし | Google ログインで動作 |
| 新規の分離プロファイル（`--app-data-dir`）、キーなし | Google ログインで動作（ログイン情報は共有） |
| 分離プロファイルで `authenticate`（`gemini-api-key`）+ `GEMINI_API_KEY` | APIキーモードに切替。モデル一覧が Gemini のみになる |
| その後、同プロファイルでキーあり・`authenticate` なし | APIキーモードのまま（選択はプロファイルに保存される） |
| その後、同プロファイルでキーなし | `Authentication required`（code `-32000`）。Google ログインには戻らない |
| キーなしで `authenticate`（`gemini-api-key`） | エラー。`_meta.apiKey` でもキーを渡せるとメッセージに出る |
| 上記の間の既定プロファイル | 影響なし |

- セッション履歴はプロファイルごとに別になる。APIキー側で作ったセッションは Google ログイン側の一覧に出ない。
- APIキーモードでは Claude / GPT-OSS のモデルが出ず、Gemini 4 系などが出る。モデル一覧は認証方式ごとに取得する。
- ダミーキーでも `authenticate` と `session/new` は成功した。キーの妥当性はこの時点では検証されない。

### 本物の APIキーでの確認（2026-11-19、agy 1.5.12）

- `GEMINI_API_KEY` を子プロセスの環境変数で渡し、`authenticate`（`gemini-api-key`）→ `session/new` → `session/prompt` が通った。
- モデル一覧は 25 件で、すべて Gemini。既定モデルは `gemini-3.1-pro-low` だった（Google ログイン側の既定は `gemini-3.8-flash-high`）。3.1 Pro は 3.8 Flash より高いので、ランチャーは指定がなければ `gemini-3.8-flash-high` に切り替える。
- 1ターン（入力 10,958、出力 142 トークン）のあと、AI Studio の使用状況に、このキー名でリクエスト 1 件が計上された。Google ログイン側ではなく APIキーで課金されている。
- クレジット残高への反映は未確認。費用の表示には数時間から 24 時間以上かかると課金ページに書かれている。送信前の残高は、クレジット合計 ¥14,244（¥6,329 が 1 件、¥1,583 が 5 件）、前払い残高 ¥391。

## 追加検証の結果（2026-11-19、APIキー）

トレース: [trace-cancel.ndjson](antigravity-acp/trace-cancel.ndjson)、[trace-steer.ndjson](antigravity-acp/trace-steer.ndjson)、[trace-accept-edits.ndjson](antigravity-acp/trace-accept-edits.ndjson)、[trace-resume.ndjson](antigravity-acp/trace-resume.ndjson)

- **`_meta.apiKey`**: `authenticate` の `_meta.apiKey` でキーを渡せる。環境変数は不要。
- **キャンセル**: `session/cancel` を送ると、実行中の `session/prompt` が `stopReason: "cancelled"` で返る。
- **ステア**: ターン実行中に 2 本目の `session/prompt` を送ると、1 本目が `usage` なしの `{"stopReason":"end_turn"}` で即座に返り、2 本目がターンの残りを引き継ぐ。モデルは進行中の出力を終えてから追加の指示に応じた。ターンの終了は「未完了の `session/prompt` が 0 になったとき」で判定する。
- **`session/resume`**: 履歴をリプレイせずに会話を継続できる。Bridge は履歴を表示するため `session/load` を使う。
- **`accept-edits`**: ファイル編集は承認なしで実行され、コマンド実行は承認を求める。
- **`auto`**: APIキー認証ではモード一覧に出ず、`session/set_mode` は `-32602`（OS のターミナルサンドボックスが必要）で失敗した。モードはセッション応答の一覧から出す。
- **モデル**: `availableModels` の ID はモデルと思考レベルの組（`gemini-3.8-flash-high` など）。`session/set_model` で切り替わる。`session/load` で再開するとモデルは `agy` の既定に戻る（APIキー認証では `gemini-3.1-pro-low`）。
- **画像入力**: `{type:"image", data, mimeType}` のブロックを Bridge 経由で送り、内容を答えられた。
- **拒否後の挙動**: 拒否するとツールが `failed` になり、追加の発言なしで `end_turn` になる（再確認）。承認の選択肢は `allow_once` / `reject_once` の 2 つ（再確認）。

## 未検証

- elicitation（質問フォーム）、`plan` モードでの承認の出方
- 無料枠の APIキーで `agy` が動くか
- 無効なキーでプロンプトを送ったときの挙動（Google ログイン側に落ちないか）。確かめるには禁止側の送信になりうるので、検証しない
- 既定プロファイルで `authenticate` を送ったときの影響と、`oauth-personal` へ戻す経路
- Google AI プラン付属の Cloud クレジットが、`agy` の APIキー経由の利用に適用されるか（AI Studio の課金ページでクレジット残高が減ったことを確認する。費用の反映に数時間以上かかる）

## 実装の要点

### Bridge

- [antigravity-process.ts](../packages/bridge/src/antigravity-process.ts): `agy acp` の起動、ACP の往復、Bridge メッセージへの変換。`CodexProcess` / `SdkProcess` と同じイベント（`message` / `status` / `exit` / `input_ready`）を出す。
  - ツール呼び出しは既存の表示に合わせる。コマンド実行は `Bash`、ファイル編集は `FileChange`（`oldText` / `newText` から unified diff を作る）。
  - 承認リクエストは `availableDecisions: ["accept", "decline"]` を付ける。アプリは「常に許可」を出さない。
  - 拒否・キャンセル時は `tool_result`（`permissionOutcome: "rejected"`）を出す。`agy` は拒否後に何も言わずターンを終えるため。
  - モードは Claude と同じ `PermissionMode`（`default` / `acceptEdits` / `auto` / `plan`）に対応づける。`bypassPermissions` は非対応。
- [antigravity-sessions.ts](../packages/bridge/src/antigravity-sessions.ts): 短命の `agy acp` で `session/list` を呼び、最近のセッション一覧に載せる（15 秒キャッシュ）。
- 環境変数:

| 変数 | 意味 |
|------|------|
| `CCPOCKET_ANTIGRAVITY_API_KEY` | Gemini APIキー。設定すると APIキー用プロファイルで動く |
| `CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY` | `1` で、APIキー認証を確認できない限りプロンプトを送らない（エージェント検証用） |
| `CCPOCKET_ANTIGRAVITY_BIN` | `agy` の実行ファイル（既定 `agy`） |

- プロトコルの追加:
  - `provider: "antigravity"`（`start` / `resume_session` / `list_recent_sessions`）
  - クライアント → Bridge: `set_antigravity_model {sessionId, model}`、`list_recent_sessions.includeAntigravity`
  - Bridge → クライアント: `system` の `init` / `antigravity_settings` に `antigravity`（現在のモデル、選べるモデルとモード、認証方式）。セッション概要に `antigravitySettings`
  - 機能宣言 `antigravity_v1`（`agy acp` が使えるマシンでだけ出す）
- 明示エラーを返す操作: フォーク、巻き戻し、メッセージ編集、サンドボックス切替、ゴール、Codex / Claude 用の設定変更。

### 制約

- 再開（`session/load`）するとモデルが `agy` の既定に戻る。Bridge はセッションごとのモデルを保存していない。
- 最近のセッション一覧で Antigravity の行が混ざるのは、絞り込みのない一覧の先頭ページだけ。プロジェクト絞り込み、ピン留めのみ、全文検索の一覧には出ない。プロバイダーを Antigravity に絞った一覧はページ送りできる。
- Antigravity の会話にはプロジェクト割り当てとピン留めがない。
- 送信済みプロンプトの取り消し（停止時の入力の巻き戻し）はできない。ターンのキャンセルだけ行う。
- 使用量（`get_usage`）は対象外。
- 再開時に復元した履歴には元の時刻がない（`agy` が返さない）。拒否した編集は「File change failed」と表示される。
- 認証方式（`authMode`）はアプリに届いているが、画面には出していない。

### アプリ

- 3 つ目のチャット画面は作らず、Claude 用の画面を使う（モードが Claude の権限モードにそのまま対応するため）。
- 新規セッションの Antigravity タブ、プロバイダーフィルター、モデル切替は、Bridge が `antigravity_v1` を宣言しているときだけ出す。
- モデルの選択はセッション開始後に行う（一覧はセッション応答でしか取れないため）。

### 確認したこと（2026-11-19、APIキー認証、テスト用 Bridge）

- Bridge に WebSocket で直接つなぎ、開始、応答、タイトルの自動設定、ファイル編集とコマンドの承認・拒否、モード切替、モデル切替、`auto` 不可時のエラー、画像つき入力、割り込み、停止、再開と履歴の復元、最近のセッション一覧を確認した。
- iOS シミュレーターのアプリから、Antigravity タブでのセッション開始、モデル切替、承認バー（「拒否」「今回だけ許可」の 2 つ）での承認と拒否、最近のセッション一覧からの再開を確認した。
- Google ログイン認証での動作は、エージェントからは確認していない（規約上できない）。同じコード経路で `authenticate` を送らないだけの違いだが、人間の手で一度確認すること。

## 互換性方針

- Antigravity は新しい `provider` の値として追加した。既存の Claude / Codex セッションの挙動とメッセージは変えていない。
- **新しいアプリ + 古い Bridge**: 古い Bridge は `antigravity_v1` を宣言しないので、アプリは Antigravity の UI を出さない。`set_antigravity_model` は `_unsupportedActions` に登録してあり、届かない場合は Bridge の更新を案内する。
- **古いアプリ + 新しい Bridge**: 古いアプリは Antigravity セッションを作れない。別の端末が作ったセッションは実行中の一覧に出て、古いアプリでは Claude 用の画面で開く。メッセージの形は Claude / Codex と同じなので会話と承認は動き、Claude 専用の操作（巻き戻し、フォーク、設定変更）は Bridge が明示エラーを返す。最近のセッション一覧には、`includeAntigravity` を送るアプリにだけ Antigravity の行を返す（古いアプリが Claude として再開しようとするのを防ぐ）。
- `agy` が未導入、または ACP 非対応のバージョンのときは、`antigravity_v1` を宣言しない（`agy acp --help` で判定）。`npx @ccpocket/bridge doctor` は、導入されている場合だけ Antigravity CLI を表示する。

## 検証費用の目安

Gemini 3.8 Flash（`agy` の既定モデル）の標準料金は、100万トークンあたり入力 $0.75、キャッシュ済み入力 $0.075、出力 $3.75（[料金ページ](https://aistudio.google.com/docs/pricing)、2026-11-18 時点。2027-01-01 から倍になる予定）。

- `agy` のシステムプロンプトが約1万トークンあり、短いターンで約1セント、ツールを多用するターンで 5〜15 セント程度（推定）。
- 開発と E2E を合わせて 5〜20 ドル程度の見込み。ターン数は仮定に基づく。
- Gemini 4 Carbon / Argon は入力 $2・出力 $10（2026-12-01 から倍）。モデル切替の確認は数ターンにとどめる。
- 3.8 Flash には無料枠がある。レート制限と、`agy` の APIキー認証で使えるかは未確認。
- Google AI Pro / Ultra には Gemini API に充てられる月ごとの Cloud クレジットが付く（Pro $10、Ultra 5x $40、Ultra 20x $100。Plus はなし。各月分の有効期限は 12 か月）。AI Studio の左メニューのカードから請求先アカウントを選んで受け取る。利用には $5 の前払いが必要。（[公式ページ](https://aistudio.google.com/learn/claim-google-ai-plan-credits-in-ai-studio)、2026-11-19 確認）
- 検証用の APIキーは AI Studio の `Default Gemini Project` に `ccpocket-antigravity-verify` という名前で発行した（2026-11-19）。請求先アカウントは `ccpocket`（前払い）で、プラン付属のクレジットをここに受け取り済み。今後の月次分も自動で適用される設定にしてある。

## 参考

- [Agent Client Protocol (ACP) - Antigravity CLI](https://antigravity.google/docs/cli/acp/)
- [Other editors (ACP) - IDE Extensions](https://antigravity.google/docs/ide/extensions/acp)
- [Headless mode - Antigravity CLI](https://antigravity.google/docs/cli/headless/)
- [Authenticate](https://antigravity.google/docs/install/)
- [Antigravity SDK overview](https://antigravity.google/docs/sdk/overview/)
- [Google Antigravity Additional Terms of Service](https://antigravity.google/terms/)
- [Antigravity FAQ](https://antigravity.google/docs/faq/)
- [Issue #1493: agy acp from a non-editor ACP client](https://github.com/google-antigravity/antigravity-cli/issues/1493)
