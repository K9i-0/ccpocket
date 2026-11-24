# TLA+ / TLC による権限承認フローの検証メモ

対象は `packages/bridge/src/sdk-process.ts` の `SdkProcess`。出題は [SCOPE.md](../SCOPE.md)。
道具は tla2tools 1.7.4（TLC 2.19）、Java 21。再現は `bash formal/permission-flow/tlaplus/run.sh`（10コアで20〜30分）。

- 仕様: [PermissionFlow.tla](PermissionFlow.tla)（素の TLA+。PlusCal は使っていない）
- 実行: [run.sh](run.sh)。設定は `cfg/<実行名>.cfg` に生成し、生の出力は `out/<実行名>.txt`
- 実行ごとの記録: [out/SUMMARY.txt](out/SUMMARY.txt)。1行に、結果、生成した状態数、異なる状態数、探索が完了したか（`0 states left on queue`）、深さ、所要時間、定数（ID、モード、キュー上限、連鎖上限、M1〜M3、止めた環境動作）を載せている。違反した不変条件の行は、1ワーカーで回し直したときの数字
- 反例の JSON: `out/trace-*.json`（実コードで再生するもの）、`out/other-*.json`（再生しないもの）
- 実コードでの再生: [replay/replay.test.ts](replay/replay.test.ts)、結果は `out/replay.txt`

## 1. 結論

| ID | 現行コードの結果 | 状態数（異なる状態）/ 深さ | 備考 |
|---|---|---|---|
| P1a | **反例あり**（2系統） | 反例は深さ6。原因2つを外すと成立（792,960） | `system` の status フレーム、イテレータの正常終了 |
| P1b | **反例あり**（3系統） | 反例は深さ5〜6。原因3つを外すと成立（1,853,292） | 中止済みシグナル、`interrupt`、中止シグナル |
| P2 | 成立 | 3,700,032 / 29（ID 3個: 671,148 / 30） | 探索完了 |
| P3 | **反例あり**（1系統、無害） | 反例は深さ6。原因のどちらかを外すと成立（2,020,452） | `resolve()` の二重呼び出し。Promise の仕様で無害 |
| P4 | **反例あり**（文字どおりの P4） | 反例は深さ6〜7 | `permission_resolved` を出さない経路がある（テストで固定された設計） |
| P4n（追加した狭い版） | 成立 | 3,700,032 / 29（ID 3個: 671,148 / 30） | P4 の食い違いは「黙って消した要求」だけ、という主張 |
| P5 | **反例あり**（1系統） | 反例は深さ3。原因を外すと成立（3,473,344） | 異常終了後の入力がキューに積まれる |
| P6 | 成立 | 3,700,032 / 29（連鎖3・モード3: 15,066,720 / 26） | 探索完了 |
| P7 | 成立（公平性つき） | 33,792 / 25（ID 3個: 454,936 / 29） | 公平性は §5 |
| P8 | **反例あり**（1系統） | 33,792。原因を外すと成立（8,952 / 18〜20） | 正常終了 → 再開始 → 入力、で入力が失われ以後のキューが流れない |

「深さ」は TLC が報告する探索の深さ（複数ワーカーでは実行ごとに1〜2ずれる）。
成立と書いた実行はすべて「0 states left on queue」で探索が完了している。上限つきの有限モデルの中での結果であり、上限の外は何も言っていない。

共通の定数（特記のない実行）: ツール呼び出しID 2個、モード2種（`default` / `plan`）、入力キュー上限2、モード変更の連鎖の上限2。
デッドロック検査は有効のまま（`-deadlock` は付けていない）。`stop_session` で破棄した後だけ、明示的な自己ループ `Terminated` を置いている。デッドロックの報告はなかった。

退行 M1〜M3 はすべて検出できた（§4）。

## 2. 反例の一覧（現行コード）

各反例は 1ワーカーの幅優先探索で出した最短のもの。イベント列はモデルの動作名で書き、括弧内に `SdkProcess` への操作を書いた。
「再生」は、その列を実際の `SdkProcess`（SDK の `query` はモック）に流して、各ステップ後の状態がモデルと一致したことを指す（§6）。
再生が示すのは「コードがその状態に到達する」ことまでで、SDK が実際にそのイベント列を出すかどうかは別の話。SDK のふるまいに依存する反例にはその旨を書いた。

### C1. P1a: 承認待ちの最中に status フレームが来ると `waiting_approval` が外れる

- 列: `Input`（`dispatchInput`）→ `SdkPull`（SDK が入力ストリームを読む）→ `CanUseBegin`/`CanUseEnd`（`canUseTool` 呼び出し、`t1`）→ `SysStatus`（`{type:"system", subtype:"status", status:"compacting"}` または `"requesting"`）
- 結果: `pendingPermissions = {t1}` のまま `status` が `compacting` / `running`
- コード: `sdk-process.ts:2671-2676`。`assistant`（`:2682`）と `user`（`:2688`）にはある `pendingPermissions.size === 0` の確認が `system` にはない
- 影響（Bridge 側）: この状態で `delivery` なしの入力が届くと、`dispatchInput` が「実行中」と見て（`:1446-1448`）websocket 層が `interrupt()` を呼び（`websocket/handlers/session-input.ts:446-451`）、保留中の要求が拒否される。現行のモバイルは実行中と見ている間 `delivery` を付けて送り（`apps/mobile/lib/widgets/chat_input_bar.dart:1370-1373`）、その場合は `session.queuedInput` に入って `dispatchInput` に来ない（`session-input.ts:111-118`）。なので、この経路に入るのは古いクライアントか、クライアントが `idle` と見ている場合
- 影響（モバイル側）: 履歴上の要求は `waiting_approval` でない間は解決済みとして描かれる（`apps/mobile/lib/features/chat_session/permission_transcript.dart:61-73`）が、表示中の要求（`activeToolUseId`）は除外される。承認の操作部がどうなるかまでは追っていない
- 分類: **実装の不具合の疑い**。ただし SDK が `canUseTool` の保留中にメインの status フレームを出す場合に限る（並列サブエージェントの片方が承認待ち、という状況を想定）。SDK がそう動くかは未確認
- 再生: `out/trace-P1a.json` で一致
- 出力: `out/P1a.txt`

### C2. P1a / E1: イテレータが正常終了すると保留要求が残る

- 列: `Input` → `SdkPull` → `CanUseBegin`/`CanUseEnd`（`t1`）→ `NaturalEnd`（SDK のメッセージイテレータが例外なしで終わる）
- 結果: `queryInstance = null`、`status = idle`、`pendingPermissions = {t1}`。SDK 側の約束は未決着のまま
- 続き（E1-x1）: そのあと `approve(t1)` すると `status` が `running` になり、クエリがないので戻らない（`:2254-2255`）
- コード: `sdk-process.ts:2121-2145`。`stop()` と違い `denyAllPendingPermissions` を呼ばない。`userMessageResolve` も消さない
- 分類: **実装の不具合の疑い**。イテレータが保留要求を残したまま正常終了するかは SDK 次第（未確認）
- 再生: `out/trace-P1a-x1.json`、`out/trace-E1-x1.json` で一致
- 出力: `out/P1a-x1.txt`、`out/E1-x1.txt`
- この2つ（C1・C2）の経路を止めると P1a は成立する（`out/P1a-x2.txt`）

### C3. P1b / P4: 中止済みのシグナルで呼ばれた `canUseTool`

- 列: `Input` → `SdkPull` → `CanUseBegin`/`CanUseEnd`（`signal.aborted === true` で呼ぶ）
- 結果: 保留表は空、約束は拒否で決着、`status = waiting_approval` のまま。`permission_request` は送信済みで `permission_resolved` は出ない
- コード: `sdk-process.ts:2199`（先に `waiting_approval`）→ `:2214-2218`（表から消して拒否するだけ）
- 分類: **実装の不具合の疑い**（軽い）。SDK が中止済みのシグナルを渡す場合に限る
- 再生: `out/trace-P1b.json` で一致

### C4. P1b / P4: `interrupt` のあと `waiting_approval` が残る

- 列: `Input` → `SdkPull` → `CanUseBegin`/`CanUseEnd`（`t1`）→ `Interrupt`（`interrupt()`）
- 結果: 保留表は空、`status = waiting_approval`、クライアントは `t1` を保留中と見たまま。次の `assistant` / `user` フレームか `result` が届くまで続く
- コード: `sdk-process.ts:1414-1422`。`denyAllPendingPermissions`（`:2235-2242`）は意図して状態もメッセージも出さない（コメント `:2229-2234`「呼び出し側が次の状態へ進める」）が、`interrupt()` は状態を進めない
- 影響: この間にクライアントが承認すると「No matching pending tool action.」になる（`websocket/handlers/approvals.ts:104-112`）
- 分類: **実装の不具合の疑い**（一時的。次のフレームか `result` が来れば解消する。必ず来るかは SDK 次第）。`permission_resolved` を出さないこと自体は `sdk-process.test.ts:3346-3368` で固定された設計
- 再生: `out/trace-P1b-x1.json` で一致

### C5. P1b / P4: 保留中に中止シグナルが発火

- 列: `Input` → `SdkPull` → `CanUseBegin`/`CanUseEnd`（`t1`）→ `Abort`（`AbortController.abort()`）
- 結果: C4 と同じ形。次の `assistant` / `user` フレームか `result` まで `waiting_approval` のまま、`permission_resolved` なし
- コード: `sdk-process.ts:2220-2225`
- 分類: **実装の不具合の疑い**。`resolvePendingPermission` を通らないので、状態更新も通知もない
- 再生: `out/trace-P1b-x2.json` で一致
- C3・C4・C5 の経路を止めると P1b は成立する（`out/P1b-x3.txt`）

### C6. P3: `resolve()` が2回呼ばれる

- 列: `Input` → `SdkPull` → `CanUseBegin`（中止済みシグナル）→ `ReentrantDecide`（`permission_request` の同期リスナーがその場で `approve`）→ `CanUseEnd`
- 結果: `:2253` で許可、続けて `:2216` で拒否。同じ約束への `resolve` が2回
- 分類: **コードで対処済み**（言語仕様による）。Promise は最初の決着だけを採るので SDK には許可が届く。クライアントへの通知も `request → resolved` の順で1回ずつ。害は見つからなかった
- 「同期リスナーの即答」と「中止済みシグナル」のどちらかを外すと P3 は成立する（`out/P3-x1.txt`、`out/P3-x2.txt`）
- 再生: `out/trace-P3.json` は一致。ただし呼び出し回数は実コードから観測していない

### C7. P4（文字どおり）: 黙って消す経路では `permission_resolved` が届かない

- 該当経路: 中止（C3・C5）、`interrupt`（C4）、`stop`、`result`、再開始、異常終了、実行中の入力に伴う `interrupt`
- 例: `out/P4-x1.txt`（`interrupt`）、`out/P4-x2.txt`（`stop_session`）
- 分類: `denyAllPendingPermissions` の経路は **設計どおり**（テスト `sdk-process.test.ts:3346-3368` が「出さない」ことを確認している）。性質としては破れているので「反例あり」と記録する。モバイル側には `status` が `waiting_approval` でないときに保留表示を解決済みへ倒す処理がある（`permission_transcript.dart:61-73`）。`stop`・`result`・再開始では `status` が離れるのでこれが働きうるが、表示中の要求は除外される作りで、どこまで補えているかは追っていない。`interrupt` と中止では `status` が残るので、この処理はそもそも働かない（C4・C5）
- 追加した P4n は「配り終えた時点で、Bridge の保留表はクライアントの集合に含まれ、余分は黙って消した要求だけ」。これは成立し、P4 の食い違いが上の経路に限られることを示す。P4 を弱めて通したのではなく、P4 は反例ありのまま、M2 の検出用に P4n を足した
- モデルに入れていないもの: セッション一覧に載る `pendingPermission` のスナップショット（`session.ts:1289-1298`）。保留表を直接読むので、再接続時にはこの食い違いを隠す

### C8. P5: 異常終了後の入力がキューに積まれる

- 列: `Crash`（イテレータが例外 → `:1351-1361` で `stop()` と `exit`）→ `Input`（`dispatchInput`）
- 結果: `stopped = true` のまま `pendingInputQueue.length = 1`。`input_ack` は `queued: true` で返る
- コード: `sdk-process.ts:1449-1455` に停止の確認がない。Claude の入力経路には実行中かの確認がない（`session-input.ts:422-426`。Antigravity には `:184` にある）
- 到達できるか: `exit` を聞いているのは `session.ts:1080-1093` だけ（ほかは `websocket/rewind-fork.ts:163-175` の一時的なもの）で、セッションを `idle` にして残す。消えるのは `evictStaleIdleSessions`（`session.ts:2694-2723`）が件数か経過時間で破棄したときだけ。それまではクライアントの入力・承認・モード変更が届く。C9・C10・C2 の続きも同じ前提
- 続き（モデル上）: `start()` はキューを消さない（`:1216-1218` は足すだけ）ので、同じオブジェクトを再開始すると古い入力が最初に送られる
- 分類: **実装の不具合の疑い**
- 入力を「クエリがある間だけ」に絞ると P5 は成立する（`out/P5-x1.txt`）。「停止後に届いた承認は何も起こさない」は P5 の不変条件（停止中は保留表が空）と `approve` の実装（表にない ID は `false`）から従う
- 再生: `out/trace-P5.json` で一致

### C9. E1 / E2: 正常終了後の入力で `running` に張り付く

- 列: `SdkPull`（入力待ちで停止、`userMessageResolve` が入る）→ `NaturalEnd` → `Input`
- 結果: `queryInstance = null` なのに `status = running`。入力は誰も読まないジェネレータに渡って消える。以後の入力は「実行中」としてキューに入り、`interrupt()` はクエリがないので何もしない
- コード: `:2121-2145` が `userMessageResolve` を残す → `:1449` の判定を通り `:1457-1459` で `running`
- 分類: **実装の不具合の疑い**。イテレータの正常終了が起きる場合に限る（コード自身は `:2127` のコメントで起きる前提）
- 再生: `out/trace-E1.json` で一致
- E1・E2 は SCOPE.md にない追加の性質（E1: クエリがなければ `idle`、E2: 入力が死んだジェネレータに渡らない）。モデルを書いている途中で気づき、TLC で列を確定した。正常終了を止めると両方成立する（`out/E1-x2.txt`、`out/E2-x2.txt`）

### C10. P8 / E2: 正常終了 → 再開始 → 入力 で入力が失われ、キューが流れなくなる

- 列（核）: `SdkPull`（入力待ち）→ `NaturalEnd` → `Start`（同じオブジェクトで `start()`）→ `Input` → `SdkPull` →（キューに1件以上ある状態で）以後進まない。TLC が出すラッソはこの前に無関係な手順を含む（活性の反例は最短にならない）
- 結果: `start()` はクエリがないと `stop()` を呼ばないので（`:1177-1179`）古い `userMessageResolve` が残る。新しいジェネレータが待ちに入る前に入力が来ると、古い約束に渡って消え、`status = running` になる。新しいジェネレータは「ターン中」と見て待ちに入り、SDK はターンを持っていないので `result` が来ず、キューが流れない
- コード: `sdk-process.ts:1176-1220`（`userMessageResolve` を消さない）、`:1457-1459`、`:1807-1833`
- 分類: **実装の不具合の疑い**（競合の窓は狭い。再開始の直後、SDK が入力ストリームを読み始める前に入力が届く必要がある）。同じオブジェクトでの再開始は `session.ts:2387` にある
- ラッソ: `out/P8-min.txt`（ID 1個で脇道を止めた版。それでも14状態）、`out/P8.txt`（基本設定）。再生は `out/trace-E2-x1.json`（安全性の側）で一致
- 正常終了か再開始のどちらかを止めると P8 は成立する（`out/P8-x1.txt`、`out/P8-x2.txt`）

### SDK のふるまいを追加で許した場合（既定では止めてある）

| 実行 | 許したこと | 結果 | 分類 |
|---|---|---|---|
| `late-P5` | クエリを閉じたあとの `canUseTool` | P5 違反。停止後に保留表へ登録され `waiting_approval` になる（`handleCanUseTool` `:2160-2183` に停止の確認がない） | SDK 次第。`close()` 後に呼ばれないなら起きない |
| `late-P2` | 同上 | P2 は成立 | — |
| `bgTool-P8` | ターンの外での `canUseTool`（バックグラウンドのサブエージェント） | P8 違反。承認すると `:2254-2255` で `running` になり、ターンがないので `result` が来ず、キューが流れない | **実装の不具合の疑い**（SDK 次第）。`:1955-1958` のコメントが書く不具合と同じ形が承認経路に残っている可能性 |
| `bgTool-P7` | 同上 | P7 は成立 | — |
| `bgFrame-P8` | ターンの外でのメインエージェントの `assistant` / `user` フレーム | P8 違反 | おそらく **モデル側の仮定の問題**。メインのフレームが来るなら SDK はターン中で、あとで `result` が来るはず。モデルはそこを結びつけていない |
| `gated-P7` | クライアントが `waiting_approval` を見ているときだけ答える、という仮のクライアント | P7 違反。C1・C2 のあと、要求が答えられないまま残る | C1・C2 の帰結を示すための仮定。実際のモバイルがこう動くとは確かめていない（表示中の要求は `status` に関係なく残る作りに見える）。C1・C2 の経路を止めると成立（`gated-P7-x1`） |

### モデルの誤りだったもの

- P8 の最初の書き方（「キューが空でなければいずれ1件渡る」）は、動いているクエリへの再開始で反例が出た。`start()` は内部で `stop()` を呼んでキューを消す（`:1177-1179`、`:1378`）ので、これは「セッションが止まった」場合にあたる。性質の側を直し、「渡るか、`stop()` が走るか」にした。弱めたのはこの1点で、理由は SCOPE.md の「セッションが止まらない限り」

## 3. モデルの作り

- 1つの動作 = 1つの同期ハンドラ（JS のマクロタスク1つと、それが起こすマイクロタスク）。`await` をまたぐ `setPermissionMode` は `SetMode` と `ModeReturn` の2段
- `waitForPermission` だけは `CanUseBegin` / `CanUseEnd` に割り、間に `ReentrantDecide`（`permission_request` の同期リスナーが即答、`sdk-process.test.ts:2844`）を挟めるようにした。P1a・P1b・P4 は割り込みの途中では問わない
- SDK の約束（`prom`、`resolve` の呼び出し回数 `calls`）と Bridge の保留表（`pending`）は別の変数
- クライアントは、イベントの列（`chan`）と、そこから組み立てた集合（`cview`）
- モード変更は「現世代の連鎖」（`chain`）と「再開始前の連鎖」（`old`）。世代番号は持たず、「再開始より前に出したか」と「クエリが変わったか（`qchg`）」の2つの印で表した。連鎖が空のときの最初の段はマイクロタスクなので、呼び出しと同じ動作の中で実行する（`Drain`）
- 履歴用の変数（コードのモデルは読まない）: `silent`（黙って消した ID）、`staleWrote`（P6）、`lost`（E2）、`tick`（P8）
- `Disabled` 定数で環境のふるまいを止められる。反例の系統を数えるのに使った（見つけた原因を止めて次を探す）。性質を通すためには使っていない。結論の表の「反例あり」は何も止めていない基本設定の結果

### 単純化したこと、コードと対応が取れていないところ

- ID は1回しか使わない。同じ ID が保留中に再度来ると `:2198` が上書きして前の約束が漏れるはずだが、調べていない
- `approve` / `approveAlways` / `reject` / `answer` は1つの動作 `Decide`。`approveAlways` によるモード書き換え（`:1544-1553`）、`answer` のツール名の確認、ID 省略時に先頭の要求へ当たること（`firstPendingId` `:1769`）は入れていない。古い承認が ID なしで届いて別の要求に当たる、という筋は調べていない
- セッション許可ルールによる自動承認（`:2175-2177`）は状態を変えないので省いた
- ステアリング（`pendingSteerQueue`）、バックグラウンドタスク向けの `interrupt` の分岐（`:1404-1413`）、認証（`authGeneration`、`result` 処理中の `await authResolution` `:2026`）、`start` の `initialInput`、websocket 層の `session.queuedInput` は入れていない
- SDK のメッセージと `canUseTool` は「SDK が出す」と「Bridge が処理する」を1動作にした。両者の間の遅れは表していない
- SDK のターンは `active` / `idle` の2値。ターン中に届いた入力は同じターンに吸収される扱い
- 再開始は「再開始前の連鎖が片づいてから」に限った（`Start` の `old = << >>`）。再開始を2回重ねたときの古い連鎖は調べていない。世代番号は増えるだけ、クエリは毎回新しいオブジェクトなので問題にならないと考えるが、検査はしていない
- `stop_session` のあとはクライアントからの操作が届かない（`SessionManager.destroy`、`session.ts:2675-2692`）。異常終了・正常終了のあとは届く、とした（C8 の「到達できるか」）
- 入力は `delivery` なしの経路（`dispatchInput` → 実行中なら `interrupt()`）だけをモデルにした。`delivery` つきでターン中の入力は `session.queuedInput` に入り `SdkProcess` に来ないので、対象外。P8 の「ターン中に積まれた入力」はこの経路の話
- クライアントの `ClientGated` は `status` イベントの遅れを無視して Bridge の `status` を直接見ている

## 4. 仕込んだ退行

検出に使ったのは、基本設定で成立する性質だけ（P2、P4n、P6、P7、P8。P8 は C10 の経路＝正常終了を止めた設定）。

| 退行 | P2 | P4n | P6 | P7 | P8 | 検出 |
|---|---|---|---|---|---|---|
| M1 保留表を消すだけ | **違反** | 成立 | 成立 | **違反** | 成立 | P2（`out/M1-P2.txt`: 承認待ち → `interrupt` で約束が宙に浮く）、P7（`out/M1-P7.txt`） |
| M2 登録前に送信、`permission_resolved` なし | 成立 | **違反** | 成立 | 成立 | 成立 | P4n（`out/M2-P4n.txt`: 承認してもクライアントに保留が残る） |
| M3 世代チェックを外す | 成立 | 成立 | **違反** | 成立 | 成立 | P6（`out/M3-P6.txt`） |

- M2 は「`permission_resolved` を送らない」側で検出している。「登録より前に送る」側は、同期リスナーの即答が空振りする形でモデルに入れたが、クライアントは答え直せる（公平性の仮定）ので P7 では見えない。この半分だけを仕込んだ場合に検出できるかは確かめていない
- M3 は連鎖の上限が1だと検出できない（`out/M3-P6-chain1.txt` は成立）。連鎖が空のときの世代チェック（`:1621`）は呼び出しと同じマイクロタスクで走るので割り込めず、`await` のあとは `:1628` のクエリ同一性の確認が代わりに止めるため。検出には「SDK 待ちの変更の後ろにもう1件並んでいる」状態が要る: `SetMode` → `SetMode` → `Start` → `ClientStop` → `ModeReturn`（2件目が `:1621` を素通りし、クエリがないので `:1633` で書く）
- 3つの退行は実コードには入れていないので、実コードでの再生はしていない

## 5. 活性と公平性

時相性質として書き、TLC で検査した。対称性と状態制約は使っていない（上限は動作のガードに入れた）。
活性の実行はモード変更と無関係なので、モード1種・連鎖0で状態を減らしている。

- P7: `\A id : (prom[id] = "waiting") ~> (prom[id] = "settled")`
- P8: `\A b : (qlen > 0 /\ tick = b /\ ~Ended) ~> (tick # b \/ Ended)`。`tick` はキューの入力が SDK に渡るたび、および `stop()` が走るたびに反転する。`Ended` は `stopped \/ queryInstance が null`

| 仮定（すべて弱公平性） | 意味 | P7 | P8 |
|---|---|---|---|
| `WF(CanUseEnd)` | 同期関数 `waitForPermission` は最後まで走る（モデルを2段に割ったための仮定） | 必要 | 必要 |
| `WF(ClientRecv)` | 送ったイベントはいずれクライアントに届く | 必要 | — |
| `\A id : WF(DecideSeen(id))` | クライアントは、見えている要求にいずれ答える | 必要 | — |
| `WF(SdkPull)` | SDK は入力ストリームを読み続ける | — | 必要 |
| `WF(Result)` | SDK のターンはいずれ `result` で終わる | — | 必要 |

- 「必要」は、その1つを外すと反例（ラッソ）が出ることで確かめた: `out/P7-noHandler.txt`、`out/P7-noRecv.txt`、`out/P7-noDecide.txt`、`out/P8-noHandler.txt`、`out/P8-noPull.txt`、`out/P8-noResult.txt`（P8 の3つは正常終了を止めた設定で実行。基本設定では P8 自体が破れるため）
- 強公平性は要らなかった。P7 は ID ごとの公平性を `WF(\E id : DecideSeen(id))` に弱めても成立した（`out/P7-weakExists.txt`）
- P7 に SDK 側の公平性は要らない。クライアントの応答だけで決着する。逆に言うと、P7 は「クライアントが答える」という仮定にほぼ乗っている
- P8 は上の仮定のもとでも基本設定で破れる（C10）。ラッソは `out/P8-min.txt`: 末尾は `status = running`、SDK のターンなし、`qlen > 0` で足踏み
- `WF(Result)` は「`interrupt()` すれば必ず `result` が返る」を含む。SDK がそう動くかは確かめていない

## 6. 仕様と実装をつなげられるか

- `-dumpTrace json` は tla2tools 1.7.4 にない（`unrecognized option`）。代わりにテキストの反例を [trace2json.mjs](trace2json.mjs) で JSON にした
- [replay/replay.test.ts](replay/replay.test.ts) は、その JSON を1ステップずつ実際の `SdkProcess` に流す vitest。`sdk-process.test.ts` と同じく `@anthropic-ai/claude-agent-sdk` の `query` をモックし、モックが受け取った `prompt`（入力ストリーム）と `canUseTool` を SDK 役として使う。各ステップ後に `status`、保留中の ID、キュー長、`stopped`、クエリの有無、入力待ちか、モード、約束が決着したか、送信済みイベントから組んだクライアントの集合、をモデルと比べる
- 結果（`out/replay.txt`）: 反例と到達確認の17本、TLC の `-simulate` で採ったランダムな198本（合計約5,400状態）がすべて一致。JSON の値を1つ書き換えると失敗することも確かめた
- つまり、**安全性の反例はそのまま実クラスへの失敗するテストの材料になる**。C1〜C5・C8〜C10 は再生で実クラスが同じ状態に入ることを確認済み。テストとして `packages/` に置く場合は、末尾に性質の `expect` を足せばよい
- 限界:
  - TLC の反例には動作の引数が載らない（どの ID を承認したか、どのモードか）。前後の状態の差から推定している。推定できない組み合わせを増やすと破綻する
  - 再生は「1動作ごとにマイクロタスクを流し切る」前提。モデルの原子性の置き方がずれていれば、ここで不一致として出るはずで、今回は出なかった
  - `resolve` の呼び出し回数、SDK のターン、ジェネレータの状態は実クラスから見えないので比べていない
  - 活性の反例（ラッソ）はテストにならない。足踏み直前の状態までを安全性として再生することはできる
  - 退行は実コードを書き換えないと再生できない
  - `packages/` の外から vitest を動かすために、グローバル API と相対 import を使っている。常用するなら `packages/bridge` 側に置くほうが素直
- 一致したのはモックした SDK に対してであり、本物の SDK がその列を出すかは別途の確認が要る

## 7. 往復回数とつまずいた点

仕様を書いて検査し直した回数は4回。

1. 初版。構文・型は1回で通った（`TypeOK` 成立、3,700,032 状態）
2. P8 が再開始で反例 → 性質の書き方の誤り（§2 末尾）。`stop()` の印を足した
3. 足した変数の `UNCHANGED` 漏れを TLC が指摘（`Successor state is not completely specified`）
4. 印を別変数にしたら状態数が倍になったので `tick` に統合

現行コードに対する反例でモデルを直したのは 2. だけ。ほかの反例は該当行を読み直し、さらに実クラスで再生して、モデルどおりであることを確かめた。

つまずいた点:

- TLC は性質ごとに最初の1件で止まる。同じ性質の別系統を出すには、見つけた原因を止めて回し直す必要があった（`Disabled`）
- 複数ワーカーだと反例が実行ごとに変わり、最短でもない。違反が出た不変条件は1ワーカーで回し直している
- 活性の反例は長く、脇道を含む。短くするには ID を減らし脇道を止めた設定を別に作った（`P8-min`）
- `UNCHANGED` を全動作に手で書く。変数を1つ足すと全動作を直すことになる
- 反例に動作の引数が出ない
- `-dumpTrace` がこの版にない
- 履歴用の変数を1つ足すだけで状態数が倍になる
- `run.sh` を実行中に書き換えて1行壊した（bash はスクリプトを読みながら実行する）。最後に全体を通しで回し直した

## 8. できなかったこと、確かめていないこと

- SDK の実際のふるまい（保留中の status フレーム、保留を残した正常終了、`close()` 後の `canUseTool`、ターン外の `canUseTool`、`interrupt()` 後の `result`）は確かめていない。該当する反例は「SDK 次第」と書いた
- 上限（ID 2〜3、キュー2、連鎖2〜3、モード2〜3）の外
- 再開始を重ねたときの古いモード変更、ID の再利用、ID なしの承認、ステアリング、認証まわり（§3）
- websocket 層とモバイルは、入口の形と通知の読み方だけをモデルに入れた。`session.queuedInput` や再接続時の復元は対象外。モバイルが `status` と保留要求をどう突き合わせるかは読み切っていない
- 見つけた不具合の疑いを本物の SDK で起こすことはしていない
