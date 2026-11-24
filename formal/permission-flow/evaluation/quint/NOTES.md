# 権限承認フロー: Quint での検証メモ

出題は [SCOPE.md](../SCOPE.md)。対象は `packages/bridge/src/sdk-process.ts` の `SdkProcess`。
道具は Quint 0.34.0（`npx -y @informalsystems/quint@0.34.0`）、Java 21、
バックエンドは Rust シミュレーター 0.8.0・Apalache 0.62.4・TLC（Quint が同梱の Apalache 配布物から起動）。
`@anthropic-ai/claude-agent-sdk` は 0.3.325 を読んだ。

## 1. 結論

- 現行コードのモデルは、SCOPE の 9 個の性質（P1a〜P8）のうち **P2・P6 だけがどの環境の仮定でも成立**した
  （P2 には 4 章の但し書きがある）。P1b と P4 は、いちばん行儀のよい SDK を仮定しても反例が出る。
  残りは SDK の振る舞いの仮定しだいで反例が出る。
- 反例は 9 種類に整理できた（5 章）。うち 7 種類（CE1〜CE6・CE8）を「実装の不具合の疑い」、
  2 種類（CE7・CE9）を「コードで対処済み」とした。モデルの誤りによる反例は無かった。
- 検査の範囲: ツール呼び出し ID 2 個で全状態探索（全性質）、ID 3 個では成立する 5 性質の全状態探索とシミュレーション。
  再開始は 1 回まで。
- 仕込んだ退行 M1〜M3 はすべて検出できた。ただし **M2 は SCOPE の P4 そのままでは現行コードと区別できない**
  （P4 は現行コードでも破れるため）。区別には P4 を絞った性質を足す必要があった（6 章）。
- 安全性の反例は、退行も含めてすべてランダムシミュレーター（`quint run`）だけで見つかった。
  TLC の全状態探索は「成立」の裏付けと活性（P7・P8）に必要だった。
- `quint verify` の既定バックエンド（Apalache）は、この仕様では遅すぎて実用にならなかった（8 章）。
  モデル検査の結果はすべて `--backend tlc` のもの。
- モデルのトレース（ITF）を本物の `SdkProcess` に流して突き合わせる vitest を試作した。
  ランダムな 500 本（各 30 ステップ）で食い違い 0、退行のモデルのトレースは食い違いを検出した（10 章）。

## 2. 成果物

| ファイル | 中身 |
|---|---|
| [permflow.qnt](permflow.qnt) | 仕様本体（状態・遷移・性質・公平性） |
| [gen-instances.sh](gen-instances.sh) → [instances.qnt](instances.qnt) | 退行と環境の仮定の組み合わせ（定数の束縛）を生成 |
| [run.sh](run.sh) | 再現用。`bash formal/permission-flow/quint/run.sh` |
| [replay.sh](replay.sh)・[repro/replay.test.ts](repro/replay.test.ts) | ITF トレースを本物の `SdkProcess` で再生 |
| [trace-summary.mjs](trace-summary.mjs)・[tlc-trace.mjs](tlc-trace.mjs)・[results.mjs](results.mjs) | トレースと結果の要約 |
| [out/summary.tsv](out/summary.tsv)・[out/results.md](out/results.md) | 全検査の結果 1 行ずつ／表 |
| `out/sim/`・`out/tlc/`・`out/live/`・`out/traces/`・`out/itf/`・`out/replay/`・`out/deep/`・`out/apalache/` | 生の出力 |

## 3. モデル

### 状態と遷移

状態は 1 つのレコード `s`。Bridge 側（`status`・`pending`・`queueLen`・`waiter`・`mode`・`gen`・`ops`・`stopped`・
`queryAlive`・`queryId`・`allowRule`）、SDK 側（`sdkPromise`・`sdkTurn`・`sdkBacklog`・`pullPending`）、
性質のためのゴースト（`settleCount`・`clientStrict`・`clientApp`・`requestSeen`・`resolvedSeen`・
`announcedUnregistered`・`staleModeWrite`・`lostInput`・`postStopEffect`・`userDecided`）からなる。

JS の同期ハンドラ 1 個（とそれに続くマイクロタスク）を 1 アクションにした。割り込みを許したのは次の 3 か所だけ。

- `setPermissionMode` の `await queryInstance.setPermissionMode(mode)`（`sdk-process.ts:1625`）。
  `ModeReturn(i, ok)` が戻り（成功／失敗）を表す。Promise の連鎖（`:1620`・`:1641`）と、
  `start()` による連鎖の作り直し（`:1200`）も表した。
- SDK が入力ストリームの `next()` を呼ぶ時点（`SdkPull`、`:1803`）。SDK は initialize を書き終えてから
  ストリームを読み始める（SDK の `streamInput`: `if(!this.initializeHasBeenWritten) await this.initializeWritten`）
  ので、`start()` の直後には読みに来ていない。
- `interrupt()` から SDK の `result` まで。

`handleInput` は旧来の経路（`delivery` 指定なし。`dispatchInput` の直後に `shouldInterrupt` なら `interrupt()`、
`websocket/handlers/session-input.ts:426`・`:446-450`）を 1 アクションにした。

### SDK についての仮定（環境）

SDK がいつ何を送るかはコードから決まらないので、仮定を定数にして切り替えた。
反例がどの仮定に依存するかを切り分けるためで、性質を通すために絞ったのではない。**生の結果は全部許す `cur_U`**。

| 定数 | 許すこと |
|---|---|
| `ENV_ANYTIME` | メインスレッドのメッセージ・`canUseTool` がターン外でも届く |
| `ENV_MSGS_WHILE_PENDING` | `canUseTool` の返事待ちの間にもメインスレッドのメッセージが届く |
| `ENV_BG` | ターン外でも `canUseTool` が来る（バックグラウンドのサブエージェント） |
| `ENV_ABORT` | `canUseTool` の `AbortSignal` が発火する（呼び出し時点で発火済みも含む） |
| `ENV_NATURAL_END` | SDK のストリームが例外なしで終わる（`processMessages` の正常終了 `:2121-2145`） |
| `ENV_REENTRANT` | `permission_request` の同期リスナーがその場で承認する（`:2261` のコメントの状況） |
| `ENV_INPUT_AFTER_DEAD` | 停止・終了したプロセスにも入力が届く |

インスタンス: `cur_min`（全部 false）、1 つずつ true にしたもの（`cur_abort`・`cur_bg`・`cur_msgs`・`cur_end`・
`cur_reent`・`cur_dead`）、組み合わせ（`cur_bgmsgs`・`cur_reab`・`cur_bgend`）、
`cur_plaus`（`ANYTIME` と `NATURAL_END` 以外すべて）、`cur_U`（全部 true）。退行は `m1_*`・`m2_*`・`m3_*` の `_min` と `_U`。

`ENV_ABORT` は SDK のコードで裏が取れた: CLI が `control_cancel_request` を送ると SDK は
その要求の `AbortController` を `abort()` する（`core.mjs` の `handleControlCancelRequest`）。
他の仮定（とくに `ENV_BG`・`ENV_MSGS_WHILE_PENDING`・`ENV_NATURAL_END`）が実際の CLI で起きるかは確かめていない。

### 大きさ

| 用途 | ツール呼び出し ID | 再開始 | 入力キュー | 処理中のモード変更 | モード |
|---|---|---|---|---|---|
| シミュレーター・ITF（接尾辞なし） | 3 個（`a` `b` `q`、`q` が AskUserQuestion） | 1 回 | 2 | 2 | 2 種 |
| TLC の全探索・活性（`_s`） | 2 個（`a` `q`） | 1 回 | 2 | 2 | 2 種 |
| TLC の深い全探索（`_3`、`cur_U` の 5 性質だけ） | 3 個 | 1 回 | 2 | 2 | 2 種 |

接尾辞なしのインスタンスは反例を読むための「直前のイベント名」を状態に持つ（`TRACE_LABELS`）。`_s` と `_3` は持たない。

ID は 1 回ずつしか使わない（実物の ID は一意。使い回すと `:2221` の `has(id)` で偽の反例が出る）。

## 4. 性質ごとの結果（現行コード）

検査の深さ:

- **sim** = `quint run`、ID 3 個、20000 サンプル × 25 ステップ、`--seed 1`。
- **TLC** = `quint verify --backend tlc`、ID 2 個、到達可能な全状態（深さの上限なし）。
  状態数は環境によって 41,672（`cur_min`）〜347,160（`cur_U`）、状態グラフの深さ 17〜19。
- 活性は TLC の時相検査（同じ全状態グラフ上）。

| ID | 結果 | 成立した環境（TLC 全探索） | 反例が出た環境 | 反例を出した道具 | sim だけで見つかったか | 反例 |
|---|---|---|---|---|---|---|
| P1a | 反例あり（環境しだい） | `min` `abort` `bg` `end` `reent` `reab` `dead` | `msgs` `bgmsgs` `bgend` `plaus` `U` | sim | はい（6〜21 状態のトレース） | CE3・CE4 |
| P1b | **反例あり（どの環境でも）** | なし | 全部 | sim | はい | CE1・CE2 |
| P2 | **成立** | 全部（`U` で 347,160 状態） | なし | – | – | – |
| P3 | 反例あり（環境しだい） | `reab` `plaus` `U` 以外 | `reab` `plaus` `U` | sim | はい | CE7 |
| P4 | **反例あり（どの環境でも）** | なし | 全部 | sim | はい | CE1・CE2・CE9 |
| P5 | 反例あり（環境しだい） | `dead` `plaus` `U` 以外 | `dead` `plaus` `U` | sim | はい | CE6 |
| P6 | **成立** | 全部（`U` で 347,160 状態） | なし | – | – | – |
| P7 | 反例あり（環境しだい） | `min` `bg` `abort` `msgs` `end` `plaus` | `bgend` `U` | TLC（時相） | いいえ（sim は時相性質を検査できない） | CE4 |
| P8 | 反例あり（環境しだい） | `min` `abort` `msgs` `U` | `bg` `end` `bgend` `plaus` | TLC（時相） | いいえ（同上） | CE5・CE8（経路によっては CE1・CE2 の残り） |

P4 は 2 つの不変条件に分けて検査した（`P4_resolved`: 届いた要求が決着したら `permission_resolved` も届く、
`P4_view`: クライアントの保留集合 = 保留表）。どちらも全環境で反例が出る。
P5 も 2 つ（`P5_state`: 停止中は表・キューが空で idle、`P5_noEffect`: 停止後の承認が状態を変えない）で、
`P5_noEffect` は全環境で成立、`P5_state` が上の表の結果。

SCOPE に無い補助の性質（性質を弱めて通したのではなく、切り分けのために足したもの）:

| 性質 | 意味 | 結果 |
|---|---|---|
| `P4_userDecision` | 承認・拒否・回答で決着した要求には `permission_resolved` が届く | 全環境で成立 |
| `P4_app` | Flutter の見え方（status が idle/starting になったら保留を捨てる）で保留表と一致 | 全環境で反例（CE1・CE2） |
| `P4_aux_registered` | `permission_request` が出た時点で要求が保留表に載っている | 全環境で成立 |
| `P8_noLostInput` | 入力が、使われていない入力ストリームに渡って消えない | `end` `bgend` `U` で反例（CE5） |
| `D_runningImpliesTurn` | status が running なら SDK のメインターンが動いている（診断用。一覧の検査には入れず、`cur_bg` のトレース取りにだけ使った） | `bg` で反例（CE8、`out/traces/`）。単発の TLC 実行では `end` でも反例（CE5）、`min` `abort` `msgs` で成立（`out/` には残していない） |

成立した結果についての但し書き:

- **P2** は「待っている約束は保留表に載っている」という基準では全環境で成立する。ただし CE4 では、
  終わったセッションの保留表に決着していない約束が載ったまま残る。「忘れられていない」とは言えるが、
  「いずれ決着する」（P7）は破れている。
- **`P5_noEffect`** が成立するのは、モデルの環境が停止後に承認要求を作らないから（閉じた query が遅れて
  `canUseTool` を呼ぶ場合を入れていない、11 章）。停止後は保留表が空なので承認は必ず空振りする。

全マスの結果は [out/results.md](out/results.md)。TLC が見つけて sim が見逃した安全性の反例は 0 件だった
（sim が何も見つけなかった組だけを TLC にかけ、すべて成立）。

追加で、ID 3 個・ラベルなしの全探索（`cur_U_3`）を `run.sh deep` で回した。
P2・`P4_userDecision`・`P4_aux_registered`・`P5_noEffect`・P6 をまとめて検査し、2,462,496 状態（深さ 20）で成立。

## 5. 反例の一覧

イベント名は仕様のアクション名。「並び」は反例に必要な最小限のイベントで、`out/traces/*.trace.txt`（TLC）と
`out/itf/*.summary.txt`（sim）のトレースから拾った。TLC のトレースは複数ワーカーで探索するので実行ごとに変わり、
`InitDone` や余分な `SdkPull` が混じることがある（反例であることは変わらない）。活性の反例（`out/live/`）は
実行ごとに別の経路になることがあった。「再生」は 10 章の vitest で本物の `SdkProcess` が同じ状態になったことを指す。

### CE1: interrupt が保留表だけ空にして status を残す — P1b・P4（実装の不具合の疑い・一時的）

- 並び（`cur_min`、4 ステップ）: `SdkPull` → `ClientInput` → `SdkCanUseTool(a)` → `ClientInterrupt`
- 結果: `pending = {}`、`status = waiting_approval`、`permission_resolved` なし。クライアントの承認カードも残る。
- コード: `interrupt()` は `denyAllPendingPermissions` を呼ぶだけで `setStatus` しない（`sdk-process.ts:1414-1421`）。
  `denyAllPendingPermissions` はメッセージも状態変更も出さない（`:2235-2242`、コメントで意図と明記）。
- 解消: SDK の `result` が来れば idle になる（`:2692-2694`）。それまでの間に承認を押すと
  「No matching pending tool action.」が返る（`websocket/handlers/approvals.ts:104-111`）。
- 入力中の割り込み（`ClientInput` が running 中に来る経路、`session-input.ts:446-450`）でも同じ。
- 再生: `out/itf/cur_min.P1b.interrupt.itf.json` が実装で再現。
- テストにするなら: `waitForPermission` で 1 件保留 → `queryInstance` を差し替え → `proc.interrupt()` →
  `expect(proc.status).not.toBe("waiting_approval")` が落ちる。

### CE2: AbortSignal で決着しても status とクライアントが置き去り — P1b・P4・P4_app・P8（実装の不具合の疑い）

- 並び（`cur_abort`、3 ステップ）: `SdkPull` → `ClientInput` → `SdkCanUseTool(q, 発火済み)`、
  または `SdkCanUseTool(q)` → `SdkAbort(q)`
- 結果: `pending = {}`、`status = waiting_approval`、クライアントには `permission_request` だけが届いている。
- コード: abort リスナーは `delete` と `resolve` だけ（`:2220-2225`）。発火済みの場合は
  `permission_request` を送った後で（`:2202`）表から消す（`:2214-2217`）。どちらも `setStatus` も
  `permission_resolved` も無い。
- 解消: ターン中なら次の `assistant` / `user` で running に戻る（`:2681-2691`）が、クライアントのカードは
  idle まで残る（`apps/mobile/lib/services/chat_message_handler.dart:473-486` は running では保留を捨てない）。
  ターン外で起きると誰も status を戻さず、`waiting_approval` のままキューの入力が渡らない。
  これは途中の実行で `cur_plaus` の P8 の反例として出た経路で、最終の実行の
  `out/live/cur_plaus_s.P8_fair.trace.txt` は別の経路（CE8）になっている。`out/` に残っている証拠は安全性の側だけ。
- SDK がシグナルを発火させるのは CLI の `control_cancel_request` と `close()` のとき（SDK のコードで確認）。
  CLI がいつ cancel を送るかは確かめていない。
- 再生: `out/itf/cur_abort.P4_app.abort.itf.json` が実装で再現。

### CE3: 保留中に system の status が届くと status が上書きされる — P1a（実装の不具合の疑い・SDK しだい）

- 並び（`cur_msgs`、4 ステップ）: `SdkPull` → `ClientInput` → `SdkCanUseTool(q)` → `SdkSystem(compacting)`
  （`requesting` でも同じ）
- 結果: `pending = {q}` のまま `status = compacting`（または running）。
- コード: `updateStatusFromMessage` の `system` は保留表を見ない（`:2670-2677`）。
  `assistant` と `user` は `pendingPermissions.size === 0` を見ている（`:2682`・`:2688`）ので、ここだけ抜けている。
- 起きる条件: `canUseTool` の返事待ちの間にメインスレッドの `system/status` が届くこと。
  サブエージェントのフレームは `processMessages` が先に捨てる（`:1953-1965`）ので、
  バックグラウンドのサブエージェントが承認待ちの間にメインが次のリクエストを始める場合などに限られる。実機では未確認。
- 再生: `out/itf/cur_msgs.P1a.system-status.itf.json` が実装で再現。

### CE4: ストリームが正常終了すると保留が残る — P1a・P7（実装の不具合の疑い・SDK しだい）

- 並び（`cur_bgend`、2 ステップ）: `SdkCanUseTool(q)`（ターン外）→ `SdkNaturalEnd`
- 結果: `status = idle`、`pending = {q}`、`queryInstance = null`。クライアントは idle を受けてカードを捨てるので、
  誰も答えない（P7 の反例: `out/live/cur_bgend_s.P7_fair.trace.txt`）。SDK 側の約束も決着しない。
- コード: 正常終了の後始末（`:2121-2145`）は `queryInstance = null` と `setStatus("idle")` だけで、
  `denyAllPendingPermissions` を呼ばない。例外で終わる経路は `stop()` を通るので問題ない（`:1351-1362`）。
- この後に `approve` が届くと `resolvePendingPermission` が `setStatus("running")` する（`:2254-2256`）ので、
  終わったセッションが running になる（モデルで確認、実装では未再生）。
- 起きる条件: `canUseTool` が保留のままストリームが例外なしで終わること。実機では未確認。
- 再生: `out/itf/cur_bgend.P1a.stream-end-with-pending.itf.json` が実装で再現。

### CE5: 正常終了後の再開始で、古い入力待ちに入力が吸われる — P8_noLostInput・P8（実装の不具合の疑い・条件が狭い）

- 並び（`cur_end`、4 ステップ）: `SdkPull` → `SdkNaturalEnd` → `Restart` → `ClientInput`
- 結果: 入力は前の query のジェネレーターに渡って消える。`status = running` のまま、新しい query は何も受け取っていない。
  以後の入力はキューに積まれたまま渡らない（`out/live/cur_end_s.P8_fair.trace.txt`）。
- コード: `userMessageResolve` を null にするのは `stop()` だけ（`:1386`）。正常終了（`:2134`）は消さない。
  `start()` は `queryInstance` が無いと `stop()` を通らない（`:1177-1179`）。
  そのため再開始後も古い resolver が残り、`dispatchInput` はそれを使う（`:1449-1459`）。
  古いジェネレーターは `stopped` が false に戻っているので `yield` まで進む（`:1834-1835`）。
- 起きる条件: (1) ストリームの正常終了 (2) 同じ `SdkProcess` の `start()` 再呼び出し（巻き戻しで実在:
  `session.ts:2387`）(3) 新しい query が最初の `next()` を呼ぶ前に入力が届く。(3) の窓は実在する
  （SDK は initialize を書き終えてから読み始める）が、長さは測っていない。
- 再生: `out/itf/cur_end.P8_noLostInput.restart-after-end.itf.json` が実装で再現（入力が古いストリームから出てくる）。

### CE6: 異常終了で止まったプロセスに入力が積まれる — P5（実装の不具合の疑い）

- 並び（`cur_dead`、2 ステップ）: `SdkError` → `ClientInput`
- 結果: `stopped = true`、`queryInstance = null` なのに `pendingInputQueue.length = 1`。渡す相手はいない。
- コード: 例外で終わると `stop()` と `emit("exit", 1)`（`:1360-1361`）。`exit` を受けた側はセッションを
  残す（`session.ts:1080-1092`）。`handleInput` は Claude のプロセスが生きているかを見ない
  （`session-input.ts:343-450`。Antigravity には `isRunning` の確認がある `:184`）。
  `dispatchInput` には `stopped` のガードが無く、`userMessageResolve` が null なのでキューに積む（`:1449-1455`）。
  クライアントには `input_ack`（`queued: true`）が返る。
- `exit` の後もセッションが残ることは `session.ts` で確かめた: 掃除（`evictStaleIdleSessions`、`:2694-2724`）が
  消すのは idle のセッションが 30 個（`:261`）を超えた分か、最後の活動から TTL を過ぎたものだけ。
- `stop_session` 経由の停止はセッションごと消える（`session.ts:2675-2690`）ので該当しない。
  該当するのは Bridge が自分で `stop()` した場合（SDK の異常終了、OAuth の拒否 `:1912`）。
- 再生: `out/itf/cur_dead.P5_state.input-after-error.itf.json` が実装で再現。

### CE7: 発火済みのシグナル + その場の承認で resolve が 2 回 — P3（コードで対処済み・実害なし）

- 並び（`cur_reab`、3 ステップ）: `SdkPull` → `ClientInput` → `SdkCanUseTool(q, リスナーが承認, 発火済み)`
- コード: `permission_request` の送信中にリスナーが承認すると `resolvePendingPermission` が 1 回目の
  `resolve`（`:2253`）。戻ってきて `signal.aborted` なら表を見ずに 2 回目の `resolve`（`:2214-2217`）。
- 実害なしとした理由: Promise は 2 回目の `resolve` を無視する。また、その場で承認するリスナーは
  現行コードに無い（`approve` を呼ぶのは `websocket/handlers/approvals.ts` だけ）。
  `:2221` と同じ `has` の確認を `:2214` にも入れれば消える。

### CE8: ターン外の承認要求を承認すると running のまま戻らない — P8（実装の不具合の疑い・SDK しだい）

- 並び（`cur_bg`、3 ステップ + 入力）: `InitDone` →（ターン外）`SdkCanUseTool(q)` → `ClientApprove(q)`。
  ここで `status = running` だが SDK のメインターンは動いていない（診断用の `D_runningImpliesTurn` の反例、
  `out/traces/cur_bg_s.D_runningImpliesTurn.trace.txt`）。続けて `ClientInput` が来ると、
  入力はキューに積まれ（`:1447-1455`）、`result` が来ないので `deliverQueuedInputIfWaiting`（`:2729`）も
  入力ストリーム（`:1807-1830`）も動かない（P8 の反例、最終の実行では `out/live/cur_bg_s.P8_fair.trace.txt`）。
- コード: `resolvePendingPermission` は表が空になると無条件に `setStatus("running")`（`:2254-2256`）。
  承認要求が来る前の status を覚えていない。
- 同じ環境では、承認の代わりに `ClientInterrupt` でも止まる（CE1 の `waiting_approval` が、ターン外なので
  `result` で解消されない）。途中の実行では P8 の反例としてこちらの経路が出た。
- 起きる条件: メインターンが動いていない時に `canUseTool` が来ること（`session.ts:1303` のコメント
  「Non-blocking questions remain answerable after the turn is idle」は、その状況を想定しているように読める）。
  実機では、バックグラウンドのエージェントが終わるとメインターンが再開して `result` が出るはずなので、
  永久に止まるとは限らない。未確認。
- 再生: `out/itf/cur_bg.D_runningImpliesTurn.approve-outside-turn.itf.json` が実装で再現
  （承認の後、実装の status も running になる）。

### CE9: result・stop・再開始での一括拒否は permission_resolved を出さない — P4（コードで対処済み）

- 並び（`cur_min`、4 ステップ）: `SdkPull` → `ClientInput` → `SdkCanUseTool(q)` → `SdkError`（`SdkResult`・`ClientStop`・`Restart` でも同じ）
- 結果: `permission_request` は届いたが `permission_resolved` は届かない。SCOPE の P4 の文面どおりなら違反。
- コード: `denyAllPendingPermissions` の仕様（`:2229-2242`）。既存のテストが「出さないこと」を確かめている
  （`sdk-process.test.ts:3346-3372`）。
- 対処済みとした理由: この 3 つは同じハンドラの中で status が idle か starting に変わり、Flutter は
  それで保留を捨てる（`chat_message_handler.dart:476-486`）。その見え方の `P4_app` で残る反例は CE1・CE2 だけ。
  ただし status が既に idle のときは `setStatus` がメッセージを出さない（`:2767`）ので、
  ターン外の承認要求（CE8 の状況）で `stop` 以外の一括拒否が起きるとカードが残る。

## 6. 仕込んだ退行

| ID | 検出 | 検出した性質 | sim だけで見つかったか | 現行コードでは成立する性質か |
|---|---|---|---|---|
| M1 | できた | `P2`（6 状態のトレース）。活性の `P7`（SDK 側の約束で述べた版）と `P8` も破れる | はい | はい（P2 は全環境で成立） |
| M2 | できた（P4 そのままでは区別できない） | `P4_userDecision`・`P4_aux_registered` | はい | はい（両方とも全環境で成立） |
| M3 | できた | `P6`（sim は 20 状態、TLC は 7 状態のトレース） | はい | はい（P6 は全環境で成立） |

- **M1**: `m1_min` で `SdkCanUseTool` → `ClientInterrupt`（または `SdkError`・`Restart`）の後、
  SDK の約束が `waiting` のまま表から消える。保留表で述べた `P7_table` は M1 を**見逃す**（表は空になるので成立）。
  SDK 側の約束で述べた `P7` は検出する。
- **M2**: SCOPE の P4（`P4_resolved`・`P4_view`）は M2 で破れるが、現行コードでも CE1・CE9 で破れるので、
  P4 が赤いだけでは退行に気づけない。検査器が返す反例も現行コードと同じ一括拒否の経路になりうる
  （最終の実行の `out/traces/m2_min_s.P4_resolved.trace.txt` は `SdkError` で終わる、現行コードと同じ形の反例）。
  そこで、d6c7e677 が直した範囲に絞った `P4_userDecision` と、送信順を見る `P4_aux_registered` を足した。
  M2 の前半（登録より前に送る）だけを検出できるのは `P4_aux_registered`、後半（`permission_resolved` を送らない）は
  `P4_userDecision`。
- **M3**: `:1628` の `queryInstance` の比較は残るので、検出には「同じ連鎖に 2 件のモード変更が並んだ状態で再開始」が要る。
  最短は `ClientSetMode` ×2 → `Restart` → `SdkError` → `ModeReturn(失敗)`（1 件目が片付き、世代チェックの無い 2 件目が
  query なしの分岐 `:1633` で書き込む）。
- 実装との突き合わせ（10 章）でも、退行のモデルのランダムなトレースは実装と食い違った
  （M1: 100 本中 9 本、M2: 24 本、M3: 3 本）。現行のモデルは 500 本中 0 本。

## 7. 活性の扱いと公平性

Quint の `temporal`（`always`・`eventually`・`weakFair`）で書き、`quint verify --backend tlc --temporal` で検査した。
**TLC バックエンドでは、パラメーター付きアクションへの弱公平も含めてそのまま検査できた。**
`quint run` には時相性質のオプションが無い。Apalache の時相検査は「実験的」と警告して y/N を聞いてくるので使っていない。
安全性での近似は不要だった（足したのは `P8_noLostInput` だけで、これは P8 の「渡る」を「正しい相手に渡る」と読むため）。

性質:

- `P7`: 各 ID について `always(sdkPromise = waiting ⇒ eventually(sdkPromise ≠ waiting))`。
- `P8`: `always(キューが空でない ∧ 止まっていない ⇒ eventually(先頭が入れ替わる ∨ 空 ∨ 止まった))`。
  「止まった」は `stopped ∨ queryInstance が無い`。`stopped` だけで読む版（`P8_stoppedOnly`）は
  正常終了を許す環境で自明に破れる。

公平性の仮定（すべて弱公平）:

- `F_sdk`: SDK は入力ストリームをいずれ読みに来る（`SdkPull`）、進行中のターンをいずれ `result` で終える（`SdkResult`）、
  起動をいずれ終える（`InitDone`）。
- `F_client`: クライアントは**自分に見えている**保留中の要求（`clientApp`）にいずれ答える。
  見えていない要求には答えられない、という形にしたので、P7 は自明にはならない（CE4 で破れる）。

| 性質 | `cur_min` | `cur_bg` | `cur_bgend` | `cur_plaus` | `cur_U` | `m1_min` |
|---|---|---|---|---|---|---|
| P7（`F_sdk` のみ） | 反例 | 反例 | 反例 | 反例 | 反例 | 反例 |
| P7（`F_sdk ∧ F_client`） | 成立 | 成立 | 反例（CE4） | 成立 | 反例（CE4） | 反例（M1） |
| P8（`F_sdk` のみ） | 反例 | 反例 | 反例 | 反例 | 成立 | 反例 |
| P8（`F_sdk ∧ F_client`） | 成立 | 反例（CE8） | 反例 | 反例（CE2） | 成立 | 反例（M1） |

「`F_sdk` のみ」で破れるのは、人が答えなければ進まないので当然。仕様が空振りしていないことの確認として載せた。
`cur_U` で P8 が成立するのは、`result` がターン外でも届く仮定のせいで、CE8 が隠れる。
活性は `ENV_ANYTIME = false` の環境で見るべき、という注意点。
`cur_abort`・`cur_msgs` では P7・P8 とも成立、`cur_end` では P7 成立・P8 反例（CE5）。

## 8. 道具ごとの記録

| 道具 | 使ったこと | 規模 | 所要 |
|---|---|---|---|
| `quint run`（Rust シミュレーター） | 安全性 13 性質 × 18 インスタンス | 20000 本 × 25 ステップ | 1 件 4 秒前後（空いた機械） |
| `quint verify --backend tlc` | sim が反例を出さなかった 130 組の全探索（残り 104 組は sim が反例を出したので省いた）、活性 46 件、反例の短いトレース 18 件 | ID 2 個の全状態（41,672〜347,160） | 1 件 1〜10 秒（空いた機械）、混むと 2 分 |
| `quint verify`（Apalache） | 代表 2 件だけ | 4 ステップまで、1 件 15 分で打ち切り | 下記 |

- **Apalache（既定のバックエンド）は実用にならなかった。** 試した順に:
  `cur_U` の P2 を 8 ステップで 13 分待って打ち切り、`cur_min` の P1b（深さ 4 の反例）を 6 ステップで 17 分待って
  3 ステップ目の途中で打ち切り、`cur_min` の P2 を 5 ステップで 20 分以上待って打ち切り（ここまでは他の検証と
  機械を取り合っている状態）。機械が空いてからも、`m1_min` の P2（深さ 3 の反例）を 4 ステップで 13 分待って
  3 ステップ目に入ったところで打ち切り。詳細ログでは 3 ステップ目の遷移 1 本の充足判定に 30 秒〜3 分かかっていた。
  状態を 1 つの大きなレコードにして純粋関数で更新する書き方が、記号的な検査には重いらしい
  （仕様を変数ごとに分けて書き直せば変わる可能性はある。試していない）。
  別の `quint verify` が終わるときにサーバーが落ちて「Connection dropped」になったことも 1 回あった。
  `run.sh apalache` は 1 件 15 分で打ち切る。結果は末尾の「実行の記録」。
- **TLC の全探索は、反例を読むためのラベルを状態に持たせると ID 3 個で終わらない。**
  ラベルあり（`cur_U`）は 10 分で 2000 万状態・深さ 14 まで進んでも終わらず打ち切った。
  ラベルなし（`cur_U_3`）は 246 万状態で、空いた機械なら 1 分で終わる（`run.sh deep`）。
- **TLC バックエンドは `--out-itf` を書かない**（オプションは受け付けるがファイルが出ない）。
  反例は TLA+ の文字列で出るので `tlc-trace.mjs` で要約した。ITF は sim からだけ取った。
- **TLC は `--invariants` でまとめて検査すると、どれが破れたかを言わない**（`q_inv is violated`）。1 つずつ回し直した。
- sim の反例は最短ではなく、足踏み（`Stutter`）も混じる。`--max-steps` を 3〜7 に絞ると最短に近いものが取れた。

## 9. 往復の回数とつまずいた点

仕様（`permflow.qnt`）の「書く → 検証 → 直す」は **3 往復**（うち、モデルの誤りを直した回は 0）。

1. 初版。型検査は 1 回で通った。sim と TLC の最初の結果で反例が 9 種類出たので、1 つずつ該当行と照合した。
   モデルの誤りは見つからず、モデルは直していない。
2. 追加。M2 が P4 では現行コードと区別できないと分かったので、ゴースト `userDecided` と `P4_userDecision` を足した。
   あわせて `ClientInterrupt` に名前とガードを付け（TLC のトレースで名前が出なかった）、
   「ターン外の承認要求 + 正常終了」を見るインスタンス `cur_bgend` を足した。
3. 追加。活性の反例として出た CE8 を安全性の形で取り出して実装で再生するため、診断用の
   `D_runningImpliesTurn` を足した（遷移は変えていない）。

**性質もモデルも、通すために弱めてはいない。** 環境の定数は反例の切り分け用で、生の結果は `cur_U`。

道具と段取りでつまずいた点（こちらは 6 回ほど `run.sh` を直した）:

- Apalache が遅く、TLC に切り替えた（上記）。
- Apalache は作業ディレクトリに `_apalache-out/` を作る。リポジトリのルートに出来てしまったので消し、
  `run.sh` が自分のディレクトリに `cd` して最後に消すようにした。
- `quint verify` を 2 つ同時に起動すると、Apalache サーバーの起動が重なって
  「Failed to bind to address 0.0.0.0:8822」で片方が `error: error` になることがある。`run.sh` に 1 回のやり直しを入れた。
- `--invariants` は配列を取るので、入力ファイルを後ろに置くとファイル名まで飲み込む（「Not enough non-option arguments」）。
- `--out-itf` を付けるとコンソール出力が消えるので、ログ用と ITF 用を別に回す必要がある。
- 状態を 1 つのレコードにしたので、反例の表示が 1 状態 30 行になる。要約スクリプトを 2 本書いた。
- 機械が他の検証と取り合いで 5〜10 倍遅くなり、全組み合わせを 1 つずつ TLC にかけるのを諦めて、
  「sim が反例を出した組は TLC を省く」「残りはインスタンスごとにまとめて全探索」に組み替えた。

## 10. 実装との接続（ITF トレース → vitest）

**試作して動いた。** [repro/replay.test.ts](repro/replay.test.ts) は、`quint run --mbt --out-itf` のトレースを読み、
`mbt::actionTaken` と `mbt::nondetPicks` から 1 ステップずつ本物の `SdkProcess` を動かして、
モデルの状態と突き合わせる。SDK の `query` は `sdk-process.test.ts` と同じく `vi.mock` で差し替え、
メッセージを好きな時に流せる非同期イテレーター・`canUseTool`・入力ストリーム・`setPermissionMode` の遅延を握る。
vitest は `packages/bridge/node_modules` のものを借り、`packages/` には何も置いていない。

突き合わせる項目: `status`、保留表の ID、入力キューの長さ、`userMessageResolve` の有無、`stopped`、`queryInstance` の有無、
`permissionMode`、`permissionModeGeneration`、各 `canUseTool` の約束が決着したか、届いたメッセージから組み立てた
クライアントの保留集合（2 通り）、返っていない `setPermissionMode` の数、入力が古いストリームに落ちたか。

| 流したトレース | 結果 |
|---|---|
| 現行のモデル `cur_U` のランダムな 500 本 × 30 ステップ | 500 本とも一致 |
| 退行のモデルのランダムな 100 本ずつ | M1: 9 本、M2: 24 本、M3: 3 本が食い違い（= 実装は退行していない） |
| 現行コードの反例 9 本（`out/itf/cur_*`。CE1〜CE8 の各 1 本と `cur_bg` の P1b） | 9 本とも一致（= 反例の状態が実装でも起きる） |
| 退行の反例 3 本（`out/itf/m*`） | M1・M2 は食い違い、M3 は一致 |

正直な評価:

- 「モデルがコードと合っているか」の確認としては効く。反例を不具合の疑いとする前の照合が、
  行を読むだけでなく実行でも裏付けられた。退行のトレースが実際に落ちるので、空振りでもない。
- そのまま回帰テストにできる。ただし今の形は `packages/` の外にあり、`SdkProcess` の private なフィールド
  （`pendingInputQueue`・`userMessageResolve`・`stopped`・`permissionModeGeneration`）を `as any` で覗いている。
  既存のテストも同じことをしているが、名前が変わると壊れる。
- 見えないものは比べられない。M3 の反例が「一致」になったのは、書き込まれた値がたまたま再開始後のモードと
  同じだったから（ゴーストの `staleModeWrite` は実装に無い）。P3 の resolve の回数も実装からは見えない。
- モデルが 1 ステップにまとめたものは、ハーネス側で `setImmediate` を数回待って吸収している。
  実装が非同期の段を増やすと、待ち方の調整が要る。
- 起動時のタイマー（3 秒）は偽のタイマーで進めた。認証の解決（`initializationResult`）は差し替えの query に
  持たせていないので、`authResolution` を待つ経路（`:2026`）は素通りしている。
- 環境の仮定（SDK がいつ何を送るか）が正しいかは、この方法では分からない。本物の CLI が要る。

## 11. モデルが単純化したこと・コードと対応が取れていない部分

- 入力は中身を捨てて本数だけ。画像つき（`dispatchInputWithImages`）は同じ形なので省いた。
- steer（`steerInput`・`pendingSteerQueue`、`:1142`・`:1811`）と、セッション側のキュー
  （`delivery` 指定あり、`session.queuedInput`・`input_ready`）は入れていない。新しいクライアントの入力経路は未検証。
- バックグラウンドタスクがあるときの `interrupt()` の分岐（`:1404-1413`）は入れていない。
- `approve`・`reject` は結果（allow / deny）を区別していない。`approve(undefined)`（先頭を選ぶ `firstPendingId`）は、
  ID を非決定的に選ぶことで覆っている。`approve` の `clearContext`（セッションを作り直す）は対象外。
- `approveAlways` はツール名の規則を「AskUserQuestion 以外は以後すべて即許可」に丸めた。
  ファイル編集ツールのとき `_permissionMode` を `acceptEdits` に書き換える副作用（`:1544-1553`）は入れていない。
- SDK からのモード変更（`system/status` の `permissionMode`、`:2100-2115`）は入れていない。P6 には関係しないと判断した。
- 認証まわり（`authGeneration`・`authResolution`、`result` での `await`、OAuth の拒否で `stop()`）は、
  「古い query のメッセージは処理されない」というガードとしてだけ表した。`result` の `await authResolution`（`:2026`）の
  途中に割り込みが入る場合は見ていない。
- 閉じた query が遅れて `canUseTool` を呼ぶ場合は入れていない（`handleCanUseTool` に世代の確認は無いので、
  起きれば新しいセッションの保留表に載る。SDK が `close()` の後に呼ぶかは確かめていない）。
- `permissionModeGeneration`・「どの連鎖か」・再開始の回数は実装では別々の値だが、常に同時に進むので 1 つの `gen` にした。
- クライアントは 1 つ、メッセージは送った順に即座に届くとした。再接続や履歴の再取得は見ていない。
- `status` の初期値は最初の `start()` の直後（`starting`）。`start()` が例外で失敗する経路（`:1241-1245`）は入れていない。
- 上限: ID 2〜3 個、再開始 1 回、キュー 2、処理中のモード変更 2。再開始 2 回以上は見ていない。

## 12. できなかったこと・確かめていないこと

- Apalache でのモデル検査は、代表 2 件を 4 ステップで試しただけ（8 章）。有界検査としての結果は無い。
- ID 3 個での全探索は、`cur_U` で成立する 5 性質をまとめた 1 回だけ。他の環境と活性は ID 2 個だけ。
  再開始 2 回以上はどの検査でも見ていない。
- `ENV_BG`・`ENV_MSGS_WHILE_PENDING`・`ENV_NATURAL_END` が実際の Claude Code CLI で起きるかは確かめていない。
  CE3・CE4・CE8 の「疑い」はこの仮定に依存する。
- CE1〜CE6 の影響の大きさ（実機でどう見えるか、どれくらい続くか）は確かめていない。
  モデルと `SdkProcess` 単体の再生で状態を確認しただけで、WebSocket 層と Flutter を通した確認はしていない。
- Flutter 側は `chat_message_handler.dart` の保留の捨て方を読んだだけ。
- Apalache は 2 件とも 15 分の打ち切りにかかり、結果が出ていない。
- リポジトリのルートの `node_modules/.vitest-cache/` に、試作の初回実行でキャッシュが書かれた
  （既存の gitignore 済みキャッシュ。自分が作った分は消し、以後は `repro/.cache` に向けた）。
  同じく初回に出来た `node_modules/.vite/` は消した。

## 実行の記録

`out/` は、最終版の仕様とスクリプトで `bash formal/permission-flow/quint/run.sh` を引数なしで 1 回通した結果
（2026-11-24、所要 1 時間 23 分。うち Apalache の打ち切り待ちが 30 分）。途中の版での段ごとの実行と比べて、
安全性の判定（234 組）と活性の判定（46 件）は 1 つも変わらなかった。反例のトレースの中身は TLC では実行ごとに変わった。

| 段 | 件数 | 結果 |
|---|---|---|
| sim | 234 | 反例 104、反例なし 130 |
| tlc | 234 | 全探索で成立 130、sim が反例を出したので省略 104、TLC だけが見つけた反例 0 |
| traces | 18 | すべて反例（NOTES に載せた反例の短いトレース） |
| live | 46 | 7 章と `out/results.md` |
| itf | 12 | すべて sim がトレースを出力 |
| deep | 1 | ID 3 個、2,462,496 状態、5 性質とも成立 |
| replay | 6 | 10 章 |
| apalache | 2 | 2 件とも 900 秒で打ち切り（`cur_min` の P1b は 4 ステップの反例の 3 ステップ目まで） |
