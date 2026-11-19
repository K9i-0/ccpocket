# Antigravity（`agy acp`）連携の対応計画

> 調査日: 2026-11-18 / 対象: Antigravity CLI `agy` 1.5.10（ACP protocol version 1）
> 状態: Bridge とアプリに実装済み（2026-11-19、agy 1.5.12 で確認）。同日、他プロバイダーとの機能差を埋める改修（`antigravity_v2`）を追加した。
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
  - 例外は、ユーザーの1回の操作をそのまま1通の発言にするものだけ。plan の承認（固定文 `Approved. Proceed with the implementation plan.`）、plan への修正指示、拒否理由がこれにあたる。Bridge はその文をユーザー発言として会話に表示する。Codex の plan 承認と同じ扱い。
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

## 追加検証の結果（2026-11-19、`antigravity_v2` の実装時）

トレース: [trace-elicitation.ndjson](antigravity-acp/trace-elicitation.ndjson)（`elicitation` を宣言したクライアントに `ask_question` の `elicitation/create` が届くところまで。このプローブは応答せず `-32601` を返している）

- **ACP は公開仕様。** [agentclientprotocol.com](https://agentclientprotocol.com/) にある、エディタとエージェント間の共通プロトコル。Antigravity 独自の拡張は `_meta.antigravity` に入る。
- **質問（`ask_question`）**: クライアントが `clientCapabilities.elicitation.form` を宣言すると、`elicitation/create`（`mode: "form"`、`requestedSchema`）が届く。選択肢は `oneOf` の `const` / `title`、自由記述は `<id>_other`。応答は `{action: "accept", content}` / `decline` / `cancel`。宣言しないと、質問が本文に出てターンが終わるだけになる。
- **plan モード**: 承認リクエストは出ない。計画は `~/.gemini/<プロファイル>/brain/<セッションID>/` 配下の文書（`implementation_plan.md`、`plan_add_subtract.md` など。名前は一定しない）として `write_file` で書かれ、次の発言を待つ。計画の文書は `rawInput.ArtifactMetadata.RequestFeedback: true` で見分けられる。plan モード中もコマンド実行は承認を求める。
- **モデルと思考レベル**: `configOptions` の `model`（系統。`gemini-3.8-flash`）と `thought_level`（`low` / `medium` / `high` / `xhigh`）を `session/set_config_option` で切り替えられる。`availableModels` の ID は「系統-レベル」。選べるレベルは系統ごとに違う。`session/set_model` の `config_option_update` は応答のあとに届く。
- **カタログ**: `session/new` → `session/close` だけの空のセッションは `session/list` に残らない。プロンプトなしでモデル・モード・プラン名を取得できる。ただし `agy` のプロファイルに空の会話ファイル（`conversations/<id>.db` 約 400 KB と `brain/<id>/`）が残る。Bridge は読んだ結果を `~/.ccpocket/antigravity-sessions.json` に保存して 24 時間使い回し、セッションを開始するたびにその内容で更新する。`agy` のプロファイル内のファイルは消さない。
- **追加ディレクトリ**: `session/new` の `additionalDirectories`（絶対パスの配列）は受理された。
- **`auto`**: Google ログインの既定プロファイルでは一覧に出て、`session/set_mode` も成功した（プロンプトは送っていない）。APIキーでは `--sandbox` を付けても不可。
- **プラン名**: `session/new` 応答の `_meta.antigravity.tier.name`（例: `Google AI Ultra`）。APIキーでは付かない。
- **利用枠の残量は ACP では取れない**（`_antigravity/quota` などは `-32601`）。代わりに CLI の `agy -p /usage --output-format json` を使う（下記「利用量」）。ログや内部 API、Google の OAuth エンドポイントは読まない。
- **ツール種別**: `read_file`（`kind: read`、`rawInput.Path`）、`search_web`（`kind: search`、`rawInput.query`）、`run_command`（`execute`）、`write_file`（`edit`）。`session/set_title` と `session/delete` はない。
- **複数選択の質問**: `is_multi_select: true` は `{type: "array", items: {anyOf: [{const, title}]}}` と `<id>_other` で届く（APIキーで確認）。
- **フォーク・巻き戻し**: `session/fork`、`session/rewind`、`session/truncate`、`session/delete` はどれも `-32601`。
- **スラッシュコマンド**: `available_commands_update` に説明文が付く。スキルも同じ一覧に入る。

### 自発的なターンと MCP ツール（2026-11-20、APIキー、agy 1.5.12）

本番のセッションで「完了扱いなのにツールが動く」「`auto` なのに承認を求められる」が起きたため調べた。

- **`agy` はプロンプトなしでターンを始める。** `schedule`（タイマー）やバックグラウンドタスクが終わると、`agy` が会話にシステムメッセージを足してモデルを起こす。`session/prompt` はすでに応答済みなので、このターンは `session/update` と `session/request_permission` だけで届く。サブエージェントではなく、同じ会話の続き。
  - `schedule` の `tool_call` は `in_progress` のままターンが終わり、タイマーが切れた時点で `tool_call_update`（`completed`）が届く。
  - このターンの終わりを示すメッセージはない。`usage_update` はモデル呼び出しのたびに届き、ターンが続くなら数ミリ秒以内に `tool_call` が続く。最後の `usage_update` のあとは何も届かない。
- **MCP ツール**は `name: "call_mcp_tool"`、`kind: "execute"`、`title: "MCP Tool <ツール名>"`、`rawInput: {ServerName, ToolName, Arguments}` で届く（`Arguments` はオブジェクト。`agy` の記録では JSON 文字列のこともある）。
- **MCP ツールは `auto` でも承認を求める。** `auto` が自動で通すのはワークスペース内の編集とサンドボックス内のコマンドで、許可ルールのない MCP ツールは毎回 Ask になる。ACP の選択肢は `allow_once` / `reject_once` だけなので、承認しても `agy` 側には残らない。
- **許可ルールの保存先**は `~/.gemini/config/config.json` の `userSettings.globalPermissionGrants.allow`（Antigravity アプリと共有。`--app-data-dir` のプロファイルを問わず効く）。`mcp(<サーバー>/<ツール>)` と `mcp(<サーバー>/*)` が書ける。`mcp(dart-mcp/*)` を足すと承認リクエストなしで実行された。プロファイルの `settings.json` に `permissions.allow` を書いても効かなかった。
- セッション開始直後は MCP サーバーの起動が間に合わず、モデルに `call_mcp_tool` が見えないことがある。

### Google ログインでの確認（2026-11-19、所有者の指示による例外）

所有者の明示の指示で、ccpocket のアプリ画面から 2 セッション（計 3 発言）だけ確認した（上の認証ルールは変えていない。以後もエージェントは APIキーを使う）。

- 新規セッション画面にプラン名（`Google AI Ultra`）と `auto` が出て、選べる。
- `auto` で始めたセッションで、コマンド（`ls -1`）が承認なしで実行された。
- 質問フォームが表示され、回答が `agy` に渡って応答が返った。使用量バー（時間・トークン・コンテキスト）も出た。
- plan モードで計画書（`math_subtract_plan.md`）が書かれたあとプラン承認が出て、承認すると承認文がユーザー発言として表示され、`default` に戻って実装（ファイル編集の承認つき）まで進んだ。

## 未検証

- 無料枠の APIキーで `agy` が動くか
- 無効なキーでプロンプトを送ったときの挙動（Google ログイン側に落ちないか）。確かめるには禁止側の送信になりうるので、検証しない
- 既定プロファイルで `authenticate` を送ったときの影響と、`oauth-personal` へ戻す経路
- Google AI プラン付属の Cloud クレジットが、`agy` の APIキー経由の利用に適用されるか（AI Studio の課金ページでクレジット残高が減ったことを確認する。費用の反映に数時間以上かかる）

## 実装の要点

### Bridge

- [antigravity-process.ts](../packages/bridge/src/antigravity-process.ts): `agy acp` の起動、ACP の往復、Bridge メッセージへの変換。`CodexProcess` / `SdkProcess` と同じイベント（`message` / `status` / `exit` / `input_ready`）を出す。
  - ツール呼び出しは既存の表示に合わせる。コマンド実行は `Bash`、ファイル編集は `FileChange`（`oldText` / `newText` から unified diff を作る）。
  - 承認リクエストは、コマンド・ファイル編集・MCP ツールに `availableDecisions: ["accept", "acceptForSession", "decline"]` を付ける（それ以外のツールは `accept` / `decline`）。
  - 拒否・キャンセル時は `tool_result`（`permissionOutcome: "rejected"`）を出す。`agy` は拒否後に何も言わずターンを終えるため。
  - モードは Claude と同じ `PermissionMode`（`default` / `acceptEdits` / `auto` / `plan`）に対応づける。
  - 新規セッションでモードの指定がなければ、アカウントに `auto` があるとき `auto` で始める（`agy` CLI の既定に合わせる。ACP のセッション自体は `default` で始まる）。アプリの新規セッション画面も、保存済みの選択がなければ `auto` と、アカウントの既定モデルを初期値にする。
  - ターン実行中の入力は、クライアントが `delivery` を指定したときだけ Bridge が扱う。`queue` はターン終了まで保留し、`steer` はそのまま送る（`agy` が実行中のターンに合流させる）。指定がなければ従来どおりすぐ送る。
  - `bypassPermissions` は Bridge 側のモード。ACP のモードは `default` のまま、承認リクエストに Bridge が `allow_once` で答える。`auto` のないアカウントでも使える。
  - MCP ツール（`call_mcp_tool`）は Claude と同じ `mcp__<サーバー>__<ツール>` の名前で出し、入力は `Arguments` の中身にする。「常に許可」は Bridge がサーバーとツールの組で覚える（引数が違っても効く。セッションの間だけ）。
  - `agy` が自分で始めたターン（タイマーやバックグラウンドタスクでの再開）も実行中として扱う。プロンプトが出ていないときに発言・思考・新しいツール呼び出し・承認リクエストが届いたら `running` にし、`usage_update` のあと 2 秒何も届かなければ `result`（`success`、トークン数なし）と `idle` を出す。承認待ちの間は終わらせない。割り込みは `session/cancel` を送ってその場で `interrupted` にする。この間に送った入力はそのターンに合流し、その `session/prompt` の応答でターンが終わる。
  - 正常に終わったターンで開いたままのツール呼び出し（タイマー、バックグラウンドのコマンド）は覚えておき、あとから届く結果を元の呼び出しに付ける。キャンセルやエラーで終わったターンの呼び出しは捨て、遅れて届いた結果は無視する。
  - 質問は `AskUserQuestion` の承認リクエストにして、回答を elicitation の `content` に変換する。
  - plan モードのターンが計画の文書を書いて終わったら、`ExitPlanMode` の承認リクエストを出す。承認で plan に入る前のモードへ戻し、上記の固定文を送る。拒否に文が付いていればそれを送り、plan モードのまま続ける。
  - 読み取り・検索・取得のツールは `Read` / `Grep` / `WebSearch` / `WebFetch` として出す。`brain/` 配下の文書はファイル名だけで表示する。
  - コンテキスト使用量（`usage_update`）は設定オブジェクトの `contextUsage` に入れ、ターンの終わりに1回だけ送る（モデル呼び出しのたびに届くため）。
  - `result` に `thoughtTokens`、`duration`、`toolCalls`、`fileEdits` を付ける。
- [antigravity-store.ts](../packages/bridge/src/antigravity-store.ts): `agy` が持たない情報（ccpocket で付けた名前、最後に使ったモデル）を `~/.ccpocket/antigravity-sessions.json` に保存する。再開時にモデルを戻し、最近のセッション一覧に名前を反映する。
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
  - `antigravity_v2` で追加したもの:
    - クライアント → Bridge: `set_antigravity_settings {sessionId, model?, thoughtLevel?}`（`model` は系統）、`get_antigravity_catalog {requestId?}`
    - Bridge → クライアント: `antigravity_catalog {requestId?, catalog?, error?}`
    - `start` の `model` に系統も指定できる。`effort` を思考レベルとして使う。`additionalWritableRoots` を `additionalDirectories` として渡す
    - 設定オブジェクトに `baseModel`、`modelOptions`（系統ごとの `thoughtLevels`）、`thoughtLevel`、`thoughtLevels`、`tier`、`contextUsage`、`agentVersion`
    - `system` の `init` / `supported_commands` に `slashCommandDescriptions`
    - `permissionModes` に `bypassPermissions` が入る
- 明示エラーを返す操作: フォーク、巻き戻し、メッセージ編集、サンドボックス切替、ゴール、Codex / Claude 用の設定変更。

### 利用量（2026-11-19 追加）

- `agy -p /usage --output-format json` は CLI 自身が答えるコマンドで、モデルを呼ばず会話も作らない（`num_turns: 0`、トークン 0）。`command.data.groups[]` に枠のグループ（`Gemini Models`、`Claude and GPT models`）があり、各 `buckets[]` に `window`（`5h` / `weekly`）、`remaining_fraction`、`reset_time` が入る。
- Bridge は `get_usage` の結果に、グループごとの項目（`provider: "antigravity"`、`label` にグループ名）を足す。Claude / Codex の結果を先に返し、Antigravity の値が変わっていれば同じ `usage_result` をもう一度送る。
- 読むのは、クライアントが利用量を求めたときに前回から 15 分以上たっている場合と、利用者が更新を押したとき（`get_usage.refreshAntigravity`、1 分に 1 回まで）だけ。タイマーでは動かさない。APIキー認証と `CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY` の Bridge では実行しない。
- `agy -p` をプログラムから動かすことは、Issue #1493 の回答で消費者ログインでは不可とされた範囲に入り得る。モデルを呼ばない状態確認であること、アプリを開いている人の操作に応じてだけ動くことを理由に採用した（所有者の判断）。
- アプリは設定の利用量カードに全グループを、セッション一覧ヘッダーには Gemini のグループだけを出す。ヘッダーは 3 つ並ぶと名前の代わりにアイコンを使う。

### 制約

- 再開（`session/load`）するとモデルが `agy` の既定に戻るため、Bridge が保存しておいたモデルを設定し直す。Bridge を通さずに使った会話は既定のモデルで再開する。
- 最近のセッション一覧で Antigravity の行が混ざるのは先頭ページだけ。タイトル検索とプロジェクトパスの絞り込みには対応する。プロジェクト ID、ピン留めのみ、名前付きのみ、日付の絞り込みには出ない。プロバイダーを Antigravity に絞った一覧はページ送りできる。
- Antigravity の会話にはピン留めがない。
- 送信済みプロンプトの取り消し（停止時の入力の巻き戻し）、巻き戻し、フォーク、メッセージ編集はできない（ACP に手段がない）。
- プランの利用枠（5 時間 / 週）は Google ログインのときだけ表示する（下記「利用量」）。APIキーではプランの枠がないので、認証方式・`agy` のバージョン・セッションごとのコンテキスト使用量だけを出す。
- 費用（USD）は出ない。`agy` が金額を返さない。
- 再開時に復元した履歴には元の時刻がない（`agy` が返さない）。拒否した編集は「File change failed」と表示される。
- `agy` の承認は「今回だけ許可」「拒否」の 2 択。「常に許可」は Bridge が受け持つ: 選ぶと、そのセッションの間、同じコマンド（文字列が完全に一致するもの）またはすべてのファイル編集に Bridge が `allow_once` で答える。Bridge を再起動するかセッションを再開すると消える。

### アプリ

- 3 つ目のチャット画面は作らず、Claude 用の画面を使う（モードが Claude の権限モードにそのまま対応するため）。
- 新規セッションの Antigravity タブ、プロバイダーフィルター、モデル切替は、Bridge が `antigravity_v1` を宣言しているときだけ出す。
- `antigravity_v2` の Bridge では、新規セッション画面でモデルの系統・思考レベル・承認モード（アカウントで使えるもの）を選べる。一覧は画面を開くたびに `get_antigravity_catalog` で取る。古い Bridge では承認モード 3 種だけを出し、モデルは開始後に切り替える。
- チャット画面のモデルのチップは「系統 · 思考レベル」を表示し、シートで両方を切り替える。
- 上部の使用量バーにトークン、所要時間、コンテキスト使用率を出す。セッション一覧のカードにもコンテキスト使用率を出す。
- 設定の利用量の欄に、プラン名・認証方式・`agy` のバージョンを出す。
- 設定の「エージェント」に、新規セッション画面へ Antigravity のタブを出すかどうかの切替がある（既定はオン）。既存の会話の一覧表示には影響しない。タブの順序の設定で Antigravity の位置も並べ替えられる（保存済みのタブ一覧に `antigravity` が位置として入る。Codex / Claude と違い、有効・無効はこの一覧では決まらない）。

### 確認したこと（2026-11-19、APIキー認証、テスト用 Bridge）

- Bridge に WebSocket で直接つなぎ、開始、応答、タイトルの自動設定、ファイル編集とコマンドの承認・拒否、モード切替、モデル切替、`auto` 不可時のエラー、画像つき入力、割り込み、停止、再開と履歴の復元、最近のセッション一覧を確認した。
- iOS シミュレーターのアプリから、Antigravity タブでのセッション開始、モデル切替、承認バー（「拒否」「今回だけ許可」の 2 つ）での承認と拒否、最近のセッション一覧からの再開を確認した。
- Google ログイン認証での動作は、エージェントからは確認していない（規約上できない）。同じコード経路で `authenticate` を送らないだけの違いだが、人間の手で一度確認すること。

## `agy` 側の対応待ち（サポートされたら実装する）

`agy` に手段がなく、Claude / Codex との差として残っているもの。`agy` を更新したら下の「確認方法」で調べ、使えるようになっていたら実装して他のプロバイダーに揃える（2026-11-19、agy 1.5.12 時点）。

| 機能 | 足りないもの | 確認方法 | 実装するときの入口 |
|---|---|---|---|
| 巻き戻し（会話・コード） | 会話を途中まで戻す ACP メソッド。`session/rewind`、`session/truncate` は `-32601` | `initialize` 応答の `sessionCapabilities` に新しい項目が増えていないか。メソッドを直接呼んで `-32601` 以外が返るか | `session.ts` の `Rewind is not supported for Antigravity sessions`、アプリの `supportsRewind` |
| フォーク | `session/fork` が `-32601` | 同上（`sessionCapabilities.fork`） | `websocket.ts` の `Fork is not supported for Antigravity sessions`、アプリの `supportsFork` |
| メッセージ編集・再送 | 巻き戻しと同じ（編集は「その発言まで戻して送り直す」ため） | 同上 | アプリの `supportsMessageEdit`、Bridge の `edit_message` |
| 停止時の入力の取り消し | 送信済みプロンプトを会話から外す手段 | 同上 | `websocket.ts` の `retract` の分岐 |
| 費用（USD） | `session/prompt` 応答の `usage` に金額がない。`agy -p` の JSON にもない | `usage` に `cost` 相当の項目が増えていないか | `antigravity-process.ts` の `result` に `cost` を足す（アプリの使用量バーは `cost` があれば表示する） |
| `agy` 自身の「常に許可」 | 承認の選択肢に `allow_always` が出ない。いまは Bridge がセッション内で代行している | `session/request_permission` の `options` に `allow_always` が出るか | 出れば `approveAlways` がそのまま使う（実装済み） |
| セッションの改名・削除 | `session/set_title`、`session/delete` が `-32601`。名前はいま Bridge が `~/.ccpocket/antigravity-sessions.json` に持つ | メソッドを直接呼ぶ | `renameSession`、`antigravity-store.ts` |
| APIキーでの `auto` モード | APIキー認証では `auto` が一覧に出ない（OS のターミナルサンドボックスが必要） | APIキーのプロファイルで `session/new` の `modes` を見る | 対応不要（一覧に出れば自動で選べる） |

確認には `scripts/antigravity-acp-probe.mjs`（APIキー）を使う。プロンプトを送らない確認（`initialize`、`session/new`、メソッドの有無）は既定プロファイルでもよい。

## 互換性方針

- Antigravity は新しい `provider` の値として追加した。既存の Claude / Codex セッションの挙動とメッセージは変えていない。
- **新しいアプリ + 古い Bridge**: 古い Bridge は `antigravity_v1` を宣言しないので、アプリは Antigravity の UI を出さない。`set_antigravity_model` は `_unsupportedActions` に登録してあり、届かない場合は Bridge の更新を案内する。
- **`antigravity_v2` のない Bridge**（1.109.0）: アプリはカタログを要求せず、新規セッション画面は承認モード 3 種だけ、チャット画面は従来のモデル一覧（`set_antigravity_model`）を出す。`set_antigravity_settings` は更新を案内し、`get_antigravity_catalog` は黙って無視する。
- **古いアプリ（1.167.0）+ `antigravity_v2` の Bridge**: 質問フォームと plan 承認は Claude 用の画面でそのまま動く（同じ `AskUserQuestion` / `ExitPlanMode`）。`bypassPermissions` は古いアプリが一覧から読み捨てるので出ない。追加した設定の項目は無視される。
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
