# Antigravity（`agy acp`）連携の対応計画

> 調査日: 2026-11-18 / 対象: Antigravity CLI `agy` 1.5.10（ACP protocol version 1）
> 状態: 調査と手動検証まで完了。実装は未着手。

Google Antigravity を ccpocket の3つ目のプロバイダーとして追加するための、判断・検証ルール・作業計画をまとめる。

## 最重要: 検証時の認証ルール

**エージェントが `agy` にプロンプトを送るときは、必ず APIキー認証を使う。**

Google は、個人向け Google アカウントのログイン（`oauth-personal`。Free / Plus / Pro / Ultra のサブスク枠）で、別のエージェントや自律ループが `agy acp` / `agy -p` を駆動することを禁止している。違反はアカウント停止の対象になる。Claude Code、Codex、サブエージェント、`e2e-verifier` がプロンプトを書いて送る検証は、すべてこの「別エージェントによる駆動」にあたる。

| 誰がプロンプトを書くか | 使ってよい認証 |
|---|---|
| エージェント（サブエージェント、E2E、スクリプトの自動生成を含む） | APIキー（`gemini-api-key`）または Google Cloud（`agent-platform`）のみ |
| 人間が手入力する | どちらでも可 |

手順は次のとおり。

1. **APIキー用プロファイルで起動する。** `agy acp --app-data-dir <APIキー用の名前>` を使う。既定プロファイル（`~/.gemini/antigravity-cli`）ではエージェントからプロンプトを送らない。
2. **毎回、最初に `authenticate`（`methodId: "gemini-api-key"`）を送る。** まっさらなプロファイルは、何もしないと Google ログインで動く（ログイン情報はプロファイル間で共有される）。
3. **`session/new` の応答でモデル一覧を確認してから、プロンプトを送る。** APIキーモードでは Gemini のみが返る。`claude-*` や `gpt-oss-*` が含まれていたら Google ログイン側で動いているので、送らずに中止する。
4. **既定プロファイルには `authenticate` を送らない。** 普段の `agy` が APIキーモードに切り替わる恐れがあり、戻す経路を確認できていない。
5. **APIキーは gitignore 済みの場所に置く。** `.env.local` など。`~/.zshrc` でのグローバル export とコミットは不可（グローバルに置くと普段の `agy` / `gemini` まで従量課金側に切り替わる恐れがある）。
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

## 未決定事項

- **エンドユーザーにサブスク認証（Google ログイン）を出すか。** 規約上の位置づけが確定していない（次節）。APIキーを既定にしてサブスク認証を自己責任のオプトインにする案と、事前に Google へ確認する案がある。
- **検証費用の出どころ。** 無料枠、従量課金、Google AI プラン付属の Cloud クレジットのどれを使うか。

## 規約上の位置づけ

- **規約 §6**: 「Using third party software, tools, or services to access the Service (e.g. using OpenClaw with Antigravity OAuth) is a breach of this Agreement.」（[Additional Terms](https://antigravity.google/terms/)）
- **FAQ**: サードパーティのコーディングエージェントには Gemini Enterprise か Google AI Studio の APIキーを使うよう案内している。`agy` をサードパーティのエージェントやアプリでラップすることは「not supported under consumer plans」。（[FAQ](https://antigravity.google/docs/faq/)）
- **CLI リポジトリ [Issue #1493](https://github.com/google-antigravity/antigravity-cli/issues/1493)**（コラボレーター manirajc の回答、2026-11-12）:
  - 「Any interactive ACP v1 client, including editors like Zed, JetBrains IDEs, and Xcode as well as custom or non-editor interactive ACP UIs, may launch the unmodified agy acp binary when a human user is directly driving the session.」
  - 「Having another agent, autonomous loop, or background task queue generate prompts and drive agy acp or agy -p programmatically is not permitted on consumer OAuth, nor is overriding Antigravity's system identity instructions or automating account rotation.」
  - 個人・単一アカウント・非商用でも例外はない（「there is no carve-out for single-account or personal use」）。
  - APIキーと Google Cloud 認証は、それぞれの API / Cloud の規約が適用される。

Issue の回答は規約本文ではない。フレームワークがシステムプロンプトや履歴を自動で付ける場合の追加質問には回答がない。**配布アプリとしての ccpocket がサブスク認証で許容されるとは確定していない。**

### 製品側の前提

サブスク認証を出す場合、人間が打っていないプロンプトを送る機能は Antigravity プロバイダーで無効にする。

- 自動リネームなど、Bridge が裏でプロンプトを生成する機能
- ゴール通知後の自動継続、バックグラウンドの自動再開
- `_meta.antigravity.systemPrompt.append` によるシステムプロンプトへの追記

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

## 未検証

- キャンセル（`session/cancel`）と、実行中ターンへの追加入力（ステア）
- `session/resume`、モデル切替後の応答、画像入力、elicitation（質問フォーム）
- `accept-edits` / `auto` / `plan` モードでの承認の出方
- `_meta.apiKey` での認証が実際に通るか
- 無料枠の APIキーで `agy` が動くか
- 無効なキーでプロンプトを送ったときの挙動（Google ログイン側に落ちないか）
- 既定プロファイルで `authenticate` を送ったときの影響と、`oauth-personal` へ戻す経路
- Google AI プラン付属の Cloud クレジットが、`agy` の APIキー経由の利用に適用されるか

## 作業計画

1. **ガード付きの検証ランチャーを作る。** APIキー用プロファイルで起動し、`authenticate` を送り、モデル一覧が Gemini のみであることを確認できなければプロンプトを送らずに終了する。エージェントによる検証は必ずこれを通す。調査時の使い捨てスクリプトは既定プロファイルでもプロンプトを送れるため、リポジトリには入れていない。
2. **未検証の項目を APIキーで埋める。** 上の一覧のうち、キャンセル、ステア、`session/resume`、モデル切替、各モードの承認を優先する。
3. **Bridge に ACP クライアントを実装する。** `CodexProcess` / `SdkProcess` と並ぶプロセスクラスとして、`agy acp` の起動、JSON-RPC の往復、`session/update` から Bridge の `ServerMessage` への変換、承認リクエストの対応づけを行う。ユニットテストはトレースをフィクスチャにする。
4. **セッション管理をつなぐ。** `Provider` に Antigravity を追加し、作成、再開（`session/load`）、一覧（`cwd` での絞り込み）、モード・モデル・思考レベルの切替を対応させる。
5. **認証設定を追加する。** APIキーの保管と、起動時のプロファイル選択。サブスク認証の扱いは未決定事項の結論に従う。
6. **アプリ側を対応させる。** プロバイダー選択、モデル・モードの表示、承認 UI（選択肢が2つの場合と、拒否後に無言で終わる場合の表示）。
7. **E2E を APIキーで行う。**

## 互換性方針

- Antigravity は新しい `provider` の値として追加する。既存の Claude / Codex セッションの挙動とメッセージは変えない。
- 新しいアプリが古い Bridge に Antigravity セッションの作成を送った場合は、`unsupported_message` として扱い、Bridge の更新を案内する。
- 古いアプリが新しい Bridge に接続した場合に、Antigravity セッションを一覧にどう出すか（隠すか、読み取り専用で出すか）は、実装時にプロトコルバージョンと合わせて決めてここに追記する。
- `agy` が未導入、または ACP 非対応のバージョンのときは、プロバイダーを利用不可として示す（`agy acp --help` で判定できる）。

## 検証費用の目安

Gemini 3.8 Flash（`agy` の既定モデル）の標準料金は、100万トークンあたり入力 $0.75、キャッシュ済み入力 $0.075、出力 $3.75（[料金ページ](https://aistudio.google.com/docs/pricing)、2026-11-18 時点。2027-01-01 から倍になる予定）。

- `agy` のシステムプロンプトが約1万トークンあり、短いターンで約1セント、ツールを多用するターンで 5〜15 セント程度（推定）。
- 開発と E2E を合わせて 5〜20 ドル程度の見込み。ターン数は仮定に基づく。
- Gemini 4 Carbon / Argon は入力 $2・出力 $10（2026-12-01 から倍）。モデル切替の確認は数ターンにとどめる。
- 3.8 Flash には無料枠がある。レート制限と、`agy` の APIキー認証で使えるかは未確認。
- Google AI Pro / Ultra には Gemini API に充てられる月ごとの Cloud クレジットが付くとされる（Pro $10、Ultra 5x $40、Ultra 20x $100。Plus はなし）。金額と条件（AI Studio での受け取り手続き、プリペイド時の最低入金）は検索結果の要約に基づくもので、公式ページを直接は確認できていない。

## 参考

- [Agent Client Protocol (ACP) - Antigravity CLI](https://antigravity.google/docs/cli/acp/)
- [Other editors (ACP) - IDE Extensions](https://antigravity.google/docs/ide/extensions/acp)
- [Headless mode - Antigravity CLI](https://antigravity.google/docs/cli/headless/)
- [Authenticate](https://antigravity.google/docs/install/)
- [Antigravity SDK overview](https://antigravity.google/docs/sdk/overview/)
- [Google Antigravity Additional Terms of Service](https://antigravity.google/terms/)
- [Antigravity FAQ](https://antigravity.google/docs/faq/)
- [Issue #1493: agy acp from a non-editor ACP client](https://github.com/google-antigravity/antigravity-cli/issues/1493)
