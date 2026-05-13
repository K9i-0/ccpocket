# Shared App Server (Codex TUI Session Joining)

## Status: Shelved (revalidated 2026-05-06)

Codex側の基盤が未成熟のため、実用レベルに達しないと判断し一旦見送り。
ブランチ `feat/shared-app-server` に実装を残す。

2026-05-06 に `openai/codex` 最新 `origin/main` (`332b8b2c74 fix build (#21261)`) を確認したが、
再開条件はまだ満たしていない。

- WebSocket transport は引き続き `experimental / unsupported`
- `codex --remote` は CLI オプションとして残っており、`--remote-auth-token-env` も追加済み
- WebSocket 認証 (`--ws-auth ...`) と大きめの outbound buffer は追加されたが、本番利用可能という扱いではない
- `thread/resume` は running thread でも最終的に persisted rollout/history を読むため、`thread/start` 直後の合流にはまだ弱い
- app-server protocol に per-turn の client/owner/originator は見当たらず、CC Pocket と TUI の二重参加時に「誰の入力か」を区別する根拠がない

結論: いま再開するなら、ユーザー向け機能ではなく `dev-only` の検証ブランチで実験を継続するのが妥当。

## 2026-05-13 再検証メモ: PR #90

PR #90 (`feat(bridge): support Codex shared app-server co-presence`) で、Bridge 側だけの
managed shared app-server 実装を実機確認した。

ローカル検証では以下の形で動作した。

```bash
BRIDGE_PORT=8766 \
BRIDGE_CODEX_APP_SERVER_MODE=managed \
BRIDGE_CODEX_SHARED_APP_SERVER_URL=ws://127.0.0.1:8767 \
npm run bridge
```

CC Pocket から Codex セッションを開始/再開したあと、同じMac上の Codex CLI から以下で合流できる。

```bash
codex resume <thread-id> --remote ws://127.0.0.1:8767
```

`codex resume --all --remote ws://127.0.0.1:8767` も起動はできるが、これは Bridge の active
session 一覧ではなく、Codex の保存済み履歴 picker を表示する。active ではない過去履歴も混ざるため、
CC Pocket の合流導線としては不適切。

### 現時点の成立条件

- セッションは CC Pocket / Bridge 側から開始または再開されている必要がある
- Bridge が shared app-server mode (`managed` または将来的な `external`) で動いている必要がある
- 合流できる公式クライアントは、現実的には Codex CLI の `--remote` 対応 TUI のみ
- Codex App / Desktop / ChatGPT から任意の local app-server URL に接続する公式導線は未確認
- この機能は「Codex App 共有」ではなく、現時点では「Codex CLI co-presence」として扱う

### UX 方針

この機能は便利だが、仕組みを理解しているユーザー向けの性質が強い。
ユーザーに `resume --all --remote ...` を覚えさせるのではなく、現在のセッションに直行する
コマンドをアプリ内でコピーできる導線が必要。

推奨 UI:

- Codex session screen の AppBar に terminal / join アイコンを表示する
- 表示条件:
  - provider が `codex`
  - Codex thread id が確定している
  - Bridge が shared app-server mode で動いている
  - Bridge から CLI join command または remote URL を受け取れている
- タップ時:
  - bottom sheet または dialog で join command を表示
  - copy button を提供
  - `ws://127.0.0.1:8767` は iPhone 用URLではなく「Bridge が動いているMac上のTerminal用」
    であることを明記する

Bridge から Flutter へ渡す情報案:

```ts
codexCliJoin?: {
  url: string;
  command: string;
}
```

将来 Codex App / Desktop への別導線が確認できた場合に備え、アプリ内部では単一の
`codexCliJoin` 前提を恒久化しすぎず、以下のような join target 配列へ拡張できる形が望ましい。

```ts
codexJoinTargets?: Array<
  | { type: "cliRemote"; url: string; command: string }
  | { type: "desktopRemoteControl"; /* future */ }
  | { type: "desktopDeepLink"; /* future */ }
>;
```

例:

```bash
codex resume <current-thread-id> --remote ws://127.0.0.1:8767
```

### 環境変数の整理案

PR #90 の初期案では以下の3変数がある。

```text
BRIDGE_CODEX_APP_SERVER_MODE
BRIDGE_CODEX_APP_SERVER_PORT
BRIDGE_CODEX_APP_SERVER_URL
```

`PORT` と `URL` は情報が重複し、`URL` も managed / external のどちらのURLなのか曖昧。
設定面を単純にするため、ドキュメント上は以下に寄せるのがよい。

```text
BRIDGE_CODEX_APP_SERVER_MODE=private|managed|external
BRIDGE_CODEX_SHARED_APP_SERVER_URL=ws://127.0.0.1:8767
```

`BRIDGE_CODEX_SHARED_APP_SERVER_URL` は「Bridge と Codex CLI が共有する app-server URL」という意味。
managed では Bridge がこのURLで app-server を起動し、external では Bridge がこのURLへ接続する。

推奨挙動:

- `private`: 既存通り。shared URL は不要
- `managed`: shared URL 未指定なら `ws://127.0.0.1:8767`
- `managed`: shared URL 指定ありなら、そのURLで Bridge が `codex app-server` を起動する
- `external`: shared URL 必須。Bridge は app-server を起動せず、既存 app-server に接続する

`BRIDGE_CODEX_APP_SERVER_PORT` は初回取り込みでは削るか、互換用 alias に留める。
ユーザー向けドキュメントには `BRIDGE_CODEX_SHARED_APP_SERVER_URL` を案内する。

### external mode の位置づけ

external mode は「Bridge が `codex app-server` を起動せず、すでに起動済みの app-server に接続する」
ための上級者向けモード。

想定例:

```bash
codex app-server --listen ws://127.0.0.1:8767

BRIDGE_CODEX_APP_SERVER_MODE=external \
BRIDGE_CODEX_SHARED_APP_SERVER_URL=ws://127.0.0.1:8767 \
npm run bridge
```

CC Pocket の通常UXでは managed だけで十分だが、将来的に Codex App / Desktop が内部で起動している
app-server に外部接続できる場合、external mode が同期実験に使える可能性がある。

ただし、external は lifecycle、port衝突、認証、ログ、誰がプロセスを落とすかが複雑になるため、
初回のユーザー向け機能として前面に出さない。入れる場合も undocumented experimental または
developer option 扱いが妥当。

### Codex App との同期可能性

2026-05-13 時点の調査では、Codex App との自然な同期はまだ難しい。

公式 docs / open-source README 上の事実:

- `codex app-server` は rich client 用の JSON-RPC interface
- `stdio` がデフォルト transport
- WebSocket (`--listen ws://IP:PORT`) は experimental / unsupported
- open-source README と CLI help では Unix socket (`--listen unix://`) と
  `codex app-server proxy` も存在する

ローカルの Codex App (`/Applications/Codex.app`) で確認した事実:

- Codex App は child process として `/Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled`
  を起動していた
- App logs では `hostId=local transport=stdio`
- `lsof -iTCP -sTCP:LISTEN` では Codex App の local app-server は TCP port を listen していなかった
- Electron main process と app-server child は stdio pipe / unix fd で接続されており、
  Bridge が後から接続できる public WebSocket URL は見つからなかった
- `codex app` CLI help にも、既存 app-server URL を指定して Desktop App を起動するオプションは見当たらない

Codex App の remote SSH connection では、別の transport が使われる。
GitHub issue の報告では、Desktop App が remote host 上で以下のような app-server を起動し、
`codex app-server proxy` 経由で接続している。

```bash
codex app-server --listen unix://
codex app-server proxy
```

また別の報告では、managed SSH remote が固定 remote port `127.0.0.1:9234` の WebSocket app-server を
使っていた時期/経路もある。つまり Codex App 内部には複数の app-server transport 実装があるが、
local Desktop App に「任意の external app-server URL へ接続する」公式UI/CLIは未確認。

現時点の結論:

- `external` mode は将来の実験余地として残す価値がある
- ただし、現在の local Codex App が起動している stdio app-server に Bridge が後から合流することは現実的ではない
- Codex App と同期するには、Codex App 側が external app-server URL / Unix socket / proxy target を
  設定できる公式導線を持つ必要がある
- あるいは remote SSH 経路の app-server/proxy を流用する実験は可能かもしれないが、認証・ownership・port衝突の
  リスクが大きく、通常機能としては扱わない

### 関連 Issue / 既存要望

`openai/codex` には、今回の方向性に近い Issue が複数ある。

- [#21743](https://github.com/openai/codex/issues/21743)
  `Codex Desktop open thread view does not refresh after another app-server client appends a turn`
  - 別の app-server client が Desktop-visible thread に turn を追加できるが、開いている Codex Desktop 側が
    即時 refresh しないという報告
  - `shared app-server transport` や `invalidate/refresh API` の必要性に近い
- [#14722](https://github.com/openai/codex/issues/14722)
  `Sync CLI and app-server sessions`
  - CLI / app-server / third-party app-server system 間の session 同期要望
- [#21551](https://github.com/openai/codex/issues/21551)
  `App Server: peer-client co-presence with the live TUI thread (RFC)`
  - live TUI thread に外部 peer client が合流する RFC
  - closed だが、multi-subscriber live thread event fanout の論点が近い
- [#13410](https://github.com/openai/codex/issues/13410)
  `Configurable App Server WebSocket port/endpoint ...`
  - VS Code extension から任意の app-server endpoint に接続したい要望
- [#21779](https://github.com/openai/codex/issues/21779)
  `Codex Desktop: stable deep link or app-server API to open a local conversation by ID`
  - 外部 local tool から Codex Desktop の特定 conversation を開く public contract 要望

ピンポイントで「Codex App が自分で起動した app-server に外部から接続したい」という Issue は未確認。
ただし Desktop / app-server / external client の同期要求は既に複数出ている。

### Codex App Connections / Remote Control 調査

ユーザーが見つけた Codex App の `Settings > Connections` 画面について、手元の
`/Applications/Codex.app` (`CFBundleShortVersionString=26.506.31421`) の bundle を確認した。

確認できた UI 文言:

- `settings.remoteConnections.localHost.header.title` = `Device settings`
- `settings.remoteConnections.localHost.remoteControl.label` = `Allow other devices to connect`
- `settings.remoteConnections.localHost.keepLive.label` = `Keep connection alive`
- `settings.remoteConnections.deviceConnections.header.title` = `Devices you can access`
- `settings.remoteControlConnections.authorize` / `remote_control_connections` 関連

`Devices you can access` / `Connections` page の表示 gate:

```toml
[features]
remote_connections = true
```

または Statsig gate `4114442250` が有効な場合に表示される。
`remote_connections` は `codex features list` には出ないため、Codex CLI の canonical feature registry ではなく
Desktop App 側の独自 gate / config fallback とみなす。

`Device settings` section の表示 gate:

- App bundle の `remote-connection-visibility` ではなく、`remote-connections-settings` 側で
  Statsig gate `1042620455` により section 全体が gate されていた
- `remote_connections = true` のような config fallback は見つからなかった
- そのため、手元で `Connections` page が出ても `Device settings` が出ない場合、
  account rollout / Statsig 対象外の可能性が高い

`Allow other devices to connect` toggle の実体:

```toml
[features]
remote_control = true
```

UI 実装は `featureName: "remote_control"` を local app-server feature enablement として書き込んでいる。
ただし `remote_control = true` は toggle の状態には関係するが、`Device settings` section を強制表示する
条件ではなさそう。

`Keep connection alive` toggle の実体:

- `[features]` ではなく App setting `preventSleepWhileRunning`
- CLI feature registry には `[features].prevent_idle_sleep` もあるが、この UI が書く先は
  `preventSleepWhileRunning`

Remote Control の接続モデル:

- `codex-rs/app-server-transport/src/transport/remote_control` は ChatGPT backend の
  `.../wham/remote/control/server/enroll` と `wss://.../wham/remote/control/server` を使う
- local raw `ws://127.0.0.1:<port>` を Codex App に指定する機能ではない
- `native/remote-control-device-key.node` があり、device key / signed-in device 認可を使う設計に見える

結論:

- `Connections` は将来の Desktop / mobile / remote environment 連携として重要
- ただし、PR #90 の shared app-server URL を Codex App にそのまま接続する機能ではない
- 将来 Codex App と同期するなら、raw WebSocket よりも Remote Control backend / app-server daemon /
  deep link / supported API のいずれかに寄る可能性がある

### 負債化リスクと取り込み方針

PR #90 の最大のリスクは、`codex --remote ws://...` を「Codex App 共有の本命 API」として
Bridge / Flutter の公開仕様に焼き込むこと。

将来 Codex App が公式に app-server 共有をサポートする場合、接続モデルは以下へ寄る可能性がある。

- ChatGPT backend 経由の `remote_control`
- Desktop-managed app-server daemon / Unix socket / proxy
- signed bearer token または capability token 必須の WebSocket
- device registry / discovery 経由
- deep link / app-server API 経由で Desktop の conversation を開く方式

そのため、今回の取り込みは以下の位置づけに限定する。

- 機能名/説明は `Codex CLI join` または `Codex CLI co-presence`
- `managed` は supported experimental path
- `external` は unsupported integration hook / developer option
- known compatible client は Codex CLI only
- Codex App compatibility は not guaranteed

避けること:

- `BRIDGE_CODEX_SHARED_APP_SERVER_URL` を「Codex App と共有するURL」と説明する
- Flutter UI に `Codex App と同期` のような文言を出す
- `external` を通常ユーザー向け接続方式として案内する
- 単一の `remoteUrl` を恒久プロトコルにして、将来の `remote_control` / deep link を入れにくくする

許容すること:

- `experimental` と明記して破壊的変更可能にする
- Bridge 側の Codex process adapter 内に閉じ込める
- App には join target と copy command だけを渡す
- 将来の Codex App 連携は別 target / 別 adapter として追加する

## 概要

CC PocketのBridgeが `codex app-server --listen ws://127.0.0.1:<port>` でWebSocketトランスポートを使用し、Codex TUI (`codex --remote ws://...`) が同じセッションに合流できるようにする機能。

## アーキテクチャ

```
Flutter App <--WebSocket--> Bridge <--WebSocket--> codex app-server (ws://PORT)
                                                        ^
                                                        |
                                              Codex TUI (codex --remote ws://PORT)
```

- Bridge: stdio の代わりに WebSocket で app-server と通信
- app-server: 複数クライアントの接続を受け付け、イベントをブロードキャスト
- TUI: `codex --remote ws://host:port` で外部 app-server に接続

## 実装済みの内容

### Bridge (TypeScript)

- `codex-process.ts`: WebSocket トランスポート追加 (ポート 19800-19899 自動検出)
- `parser.ts`: `sharedAppServer` / `remoteUrl` プロトコル拡張
- `websocket.ts`: セッション作成時に `remoteUrl` を伝播

### Flutter App

- `NewSessionSheet`: "Shared App Server" トグル (Experimental 表記)
- `CodexSessionScreen`: "Copy Remote Command" メニュー (`codex --remote ws://...` をコピー)
- `ChatSessionState`: `remoteUrl` フィールド追加
- l10n: en/ja/zh 対応

### 検証スクリプト

- `scripts/verify-shared-app-server.mjs`: 基本的な thread discovery / resume / broadcast の検証
- `scripts/verify-bidirectional.mjs`: 双方向通信の検証 (問題発見用)

## 確認済みの問題点

### 1. thread/resume が thread/start 直後に失敗する

`thread/start` した直後は rollout ファイルがディスクにフラッシュされていないため、別クライアントから `thread/resume` すると `"no rollout found"` エラーになる。最初の `turn/start` が完了してrolloutが書き込まれるまで待つ必要がある。

- TUI からの合流タイミングが制限される
- CC Pocket側でワークアラウンドは可能だが、UXが悪い

2026-05-06 再確認:

- `thread/resume` は running thread の fast path を持つ
- ただしその fast path でも `read_stored_thread_for_resume(... include_history=true)` を呼び、persisted history を要求する
- そのため「app-server メモリ上には thread があるが rollout がまだない」状態は、依然として合流失敗リスクが残る

### 2. 双方向のメッセージ表示が正しく動作しない

実機テストで確認:

- **CLI (TUI) のメッセージが CC Pocket に表示されない** — TUI が `turn/start` したイベントが Bridge に届かない、または届いても正しく処理されていない可能性
- **CC Pocket で送ったメッセージが CLI にエージェントのメッセージとして表示される** — ユーザー入力とエージェント出力の区別が付かない

app-server のブロードキャスト自体は全 subscriber に送信される仕組みだが、各クライアントが「誰が開始した turn か」を区別する仕組みが不十分。

2026-05-06 再確認:

- `TurnStartParams` / `TurnStartedNotification` / `ThreadItem.UserMessage` に per-turn の client id / originator / owner はない
- `Thread.source` は thread 単位の由来 (`cli`, `vscode`, `exec`, `appServer` 等) で、同一 thread に参加する複数クライアントの区別には使えない
- `responsesapiClientMetadata` は `turn/start` に追加されているが experimental で、app-server 通知に戻ってくる ownership 情報ではない
- Bridge 側だけで解決する場合、入力を楽観的に local echo し、同じ `userMessage` item を dedupe する程度のワークアラウンドになる

### 3. `codex --remote` が未ドキュメント・Experimental

- developers.openai.com に `--remote` オプションの記載なし
- WebSocket トランスポート自体が "experimental and unsupported" 扱い
- 将来のリリースで削除される可能性がある

2026-05-06 再確認:

- CLI root/TUI 用オプションとして `--remote ws://...|wss://...` は存在する
- `--remote-auth-token-env` が追加され、Bearer token を WebSocket handshake に付与できる
- app-server README は `--listen ws://IP:PORT` を引き続き experimental / unsupported と明記している
- `codex --remote` は interactive TUI 専用で、非 interactive subcommand では拒否される

### 4. WebSocket transport の安定性

2026-04 以降、`#18203` の remote TUI 切断問題に対して `#19246` で WebSocket outbound buffer が `32 * 1024` に拡大された。
これは通常の出力バーストには効くが、transport router の基本動作は「disconnectable connection の writer queue が full なら切断」のまま。

- 短い turn / 通常の tool output では以前より安定している可能性が高い
- 長時間・大量出力・遅いモバイル回線では依然として切断リスクがある
- CC Pocket で使うなら、再接続・再 subscribe・missed event recovery を前提に設計する必要がある

## 2026-05-06 検証メモ

参照した upstream:

- `openai/codex` local clone: `origin/main` = `332b8b2c74 fix build (#21261)`
- 関連差分: `HEAD..origin/main` は `codex-rs/tui/src/resume_picker.rs` の fixture 修正のみで、app-server / protocol / CLI には影響なし
- app-server README: WebSocket transport は `experimental / unsupported`
- app-server protocol:
  - `ThreadStartParams`: `permissions`, `environments`, `dynamicTools`, `experimentalRawEvents` などが追加
  - `ThreadResumeParams`: `history`, `path`, `permissions`, `excludeTurns` などが追加
  - `TurnStartParams`: `responsesapiClientMetadata`, `environments`, `permissions`, `collaborationMode` などが追加
  - `ThreadItem.UserMessage`: `id` と `content` のみで client owner 情報なし
- TUI remote:
  - `codex --remote` は `ws://host:port` / `wss://host:port` を受け付ける
  - remote auth token は `wss://` または loopback `ws://` のみ許可

## 再開する場合の実験プラン

ユーザー向け UI 復活前に、まず Bridge 側だけで dev-only 検証を行う。

1. `feat/shared-app-server` を最新 `main` に rebase
2. app-server 起動時に loopback + token file を使う
   - `codex app-server --listen ws://127.0.0.1:<port> --ws-auth capability-token --ws-token-file <file>`
   - TUI 側は `CODEX_REMOTE_AUTH_TOKEN=<token> codex --remote ws://127.0.0.1:<port> --remote-auth-token-env CODEX_REMOTE_AUTH_TOKEN`
3. `thread/start` 直後、`turn/start` 前、`turn/completed` 後の各タイミングで `thread/resume` を検証
4. TUI 起点 `turn/start` が Bridge subscriber に届くか、Bridge 起点 `turn/start` が TUI に user message として描画されるかを再確認
5. Bridge 側で `userMessage.id` dedupe と local echo 抑制が可能か検証
6. 大量出力 prompt で WebSocket 切断が再現するか確認
7. 失敗時に `thread/read` / `thread/turns/list` / `thread/resume excludeTurns` で復旧できるか確認

## 再開の条件

以下が満たされた場合に再検討:

1. Codex app-server の WebSocket トランスポートが安定版になる
2. `thread/resume` が `thread/start` 直後でも rollout 依存なしで動作する
3. 複数クライアント間の turn ownership が明確に区別できる仕組みが導入される
4. `codex --remote` が公式ドキュメントに掲載される
5. WebSocket 切断後の missed event recovery が app-server protocol として実装される、または Bridge 側で安全に復旧できることを確認する
