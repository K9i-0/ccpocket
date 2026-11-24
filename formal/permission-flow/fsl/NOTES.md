# FSL による権限承認フローの検証メモ

対象は `packages/bridge/src/sdk-process.ts` の `SdkProcess`、出題は [SCOPE.md](../SCOPE.md)。
検証器は `fslc` 5.2.0（Z3 4.16.0 同梱、`formal/.tools/fsl/fslc-macos-arm64`）。

- 仕様: [permission_flow.fsl](permission_flow.fsl)（現在のコードのモデル。性質は SCOPE の意図のまま）
- 再現: リポジトリのルートで `bash formal/permission-flow/fsl/run.sh`（変異解析だけは別で、`bash formal/permission-flow/fsl/run.sh mutate summary`。1〜2 時間かかる）
- 生の出力: `out/`、集計: [out/SUMMARY.txt](out/SUMMARY.txt)（`tools/summarize.py` が JSON から作る）
- 派生仕様: `variants/`（`run.sh` の `gen` が毎回作り直す。差分は `out/diffs/`）
- 道具: `tools/`（`run_props.py` 性質ごとの実行、`mkvariant.py` 切り替え定数、`strip_props.py` 成立する性質だけの写し、`make_mutants.py` 退行 M1〜M3、`make_midsession.py` 変異解析用の初期状態、`make_ranked.py` 順位づけ版の P7、`summarize.py` 集計）
- 今回の `out/` は `run.sh` の各節を分けて走らせたもの（`current proof attribution fixall seeded liveness env sketch summary`、`testgen`）。変異解析だけは `run.sh` の `mutate` 節と同じコマンドを直接走らせた。全節を通しで 1 回、という実行はしていない。

結論を先に書く。

- 現在のコードのモデルで、SCOPE の性質 9 件（P1a〜P8）のうち 6 件に反例が出た。P1a・P1b・P3 は全体が、P4・P5 は一部が、P8 は全体が破れる。仕様の不変条件の数でいうと 10 本中 6 本（P1a・P1b・P3・P4a・P4b・P5b）と `leadsTo` 2 本中 1 本（P8）。
- 反例は 9 系統。すべて実物の `SdkProcess` に対する vitest で再現した（[sketch/counterexamples.test.ts](sketch/counterexamples.test.ts)。反例 10 件と仮定の外の 1 件が失敗＝再現、対照 3 件は成功）。
- P2・P4c・P5a・P6 は k 帰納法で深さ無制限に証明できた（ツール呼び出しID 2 個、入力 2 個、同時のモード変更 2 件の範囲で）。
- 仕込んだ退行は M1（P2・P7）と M3（P6）をはっきり検出できた。M2 は条件つき。SCOPE の P4 は現在のモデルでもともと破れているので、M2 を現在のモデルで見分けたのは、M2 を意識して足した P4c と、ハンドラ途中の状態を見る P2 だけである。仮の修正を全部入れたモデルに M2 を入れた場合は P4a・P4b が検出した。
- 見つかった反例のうち、実害がありそうなものは少ない。多くは「SCOPE の性質の書き方では違反だが、設計上の意図か、クライアント側で吸収している」もの。分類は「反例の一覧」に書いた。

## 1. 性質ごとの結果

現在のコードのモデル（`permission_flow.fsl`、切り替え定数はすべて 0）。
`fslc verify` は最初に破れた性質 1 件で止まるので、性質ごとに `--property` で分けて走らせた（`out/current/`）。
有界検査の深さは安全性 10、活性 8。「証明」は `--engine induction` の `proved`（深さ無制限）。

| ID | 仕様での名前 | 結果 | 検査 |
|---|---|---|---|
| P1a | `P1a_PendingImpliesWaiting` | **反例あり**（5 手） | 有界 BMC |
| P1b | `P1b_WaitingImpliesPending` | **反例あり**（4 手） | 有界 BMC |
| P2 | `P2_AwaitedIsTracked` | 成立 | **証明**（k=1）＋ 有界 深さ 10 |
| P3 | `P3_SettledAtMostOnce` | **反例あり**（5 手） | 有界 BMC |
| P4 | `P4a_ResolvedReachesClient`（決着したら resolved も届く） | **反例あり**（4 手） | 有界 BMC |
| P4 | `P4b_ClientViewMatchesTable`（配り終えた時点で一致） | **反例あり**（4 手） | 有界 BMC |
| P4 | `P4c_AnnouncedIsRegistered`（通知中の要求は登録済み。M2 の前半用に足した） | 成立 | **証明**（k=1）＋ 有界 深さ 10 |
| P5 | `P5a_StoppedTableEmptyIdle`（停止後は保留表が空で idle） | 成立 | **証明**（k=1）＋ 有界 深さ 10 |
| P5 | `P5b_StoppedQueueEmpty`（停止後は入力キューが空） | **反例あり**（2 手） | 有界 BMC |
| P5 | 承認系 5 アクションの `ensures`（停止後の承認は何も起こさない） | 成立 | **証明**（帰納法は `ensures` も検査する） |
| P6 | `P6_NoStaleModeWrite` | 成立 | **証明**（k=1）＋ 有界 深さ 10 |
| P7 | `P7_PendingEventuallySettled`（`leadsTo`） | 成立（公平性の仮定つき） | 有界 深さ 8 と 12。順位づけによる無制限証明は不成立 |
| P8 | `P8_QueuedInputDelivered`（`leadsTo`） | **反例あり**（ラッソ） | 有界 深さ 8 |

補足。

- P4 と P5 は 1 件の性質を複数に割った。どの部分が破れているかを分けて見るためで、弱めてはいない（全部を合わせると SCOPE の文になる）。
- 「証明」の範囲は `Tool = 0..1`、`Inp = 0..1`、`Slot = 0..1`（同時のモード変更 2 件）、キュー長 2。これより大きい世界は検査していない。
- 証明は破れた 7 件を外した写し `variants/current_holding.fsl` で行った（帰納法は破れた不変条件があると全体が通らないため）。生の出力は `out/proof/current_holding.induction.json`。
- 明示状態エンジン（`--engine explicit`）は既定の予算 100 万状態を深さ 9 で使い切り、`unknown_budget`（`closure: false`）で終わった（`out/proof/current_holding.explicit.json`）。`leadsTo` には使えない（エラーになる）。予算 500 万でも試したが 10 分で終わらず打ち切った。到達可能な状態数は 100 万を超える、としか言えない。
- 帰納法には補助不変条件が 7 本要った（`Aux_*`）。1 つの性質だけを `--property` で選んだ帰納法は `unknown_cti` になる（`out/proof/current.P2_alone.induction.json`）。兄弟の不変条件を仮定に使わないため。
- 状態数は BMC・帰納法とも記号的なので出ない。
- `proved` の出力には `not_covered: ["int_overflow"]` がつく（帰納ステップは整数のあふれを見ない、という断り書き）。この仕様の整数はすべて範囲つきの型（`Cnt = 0..3`、`Flight = 0..2`）で、その境界 `_bounds_*` も証明に含まれるので、ここでは影響しない。
- 成立した実行についていた警告は 2 種類だけ。`always_true_requires`（`client_input` の `H_STOPPED_INPUT == 0 or …` と、`E_*` を 1 にした派生の `sdk_can_use_tool`。切り替え定数のせいで自明に真になる節）と、`vacuity_probe_truncated`（`Fix_*` 補題。定数が 0 の間は前件が偽）。デッドロックの警告と `vacuous_leadsto` は 1 件も出ていない。M2 の派生では `never_enabled_action`（`listener_answers_during_announce`）が出るが、これは M2 が「通知中は未登録」にするので当然。
- `check --strict-tags` は `untagged` の警告を 29 件出す（アクションに要件タグをつけていない。`out/check.strict-tags.json`）。性質には全部 `@requirement` をつけた。アクションには `// SRC:` のコメントで行を対応づけただけで、タグは振っていない。

### 仮の修正を全部入れたモデル

反例の原因を 1 つずつ切り分けるため、仕様に「仮の修正」の切り替え定数 `H_*` を 7 本置いた（既定は 0 でコードどおり）。
7 本すべてを 1 にした `variants/fix_all.fsl` では、P1a〜P6 の安全性すべてが帰納法で証明でき（`out/proof/fix_all.induction.json`）、P7・P8 も深さ 8 で成立した（`out/fix_all/`）。性質を絞らない素の `fslc verify --depth 8` も `verified`、デッドロックなし、警告なし、全アクションが到達済みだった（`out/fix_all/unfiltered.bmc.json`。絞らずに通った実行はこれだけ）。
つまりこのモデルの範囲では、安全性の反例の原因は下の 7 か所で尽きている（証明済み）。活性は有界の検査なので、P8 の原因がほかにないとまでは言えない（深さ 8 と 10 で成立）。

| 定数 | 仮の修正の内容 | 外すと再発する性質（`out/attribution/`） |
|---|---|---|
| `H_STATUS_GUARD` | `system/status` の `requesting`・`compacting` は保留中なら状態を変えない | P1a |
| `H_ABORT_NOTIFY` | 中止の 2 経路でも `permission_resolved` を出し `waiting_approval` を抜ける | P1b, P4a, P4b |
| `H_ABORT_ONCE` | 「呼ばれた時点で中止済み」の分岐は、まだ登録されているときだけ resolve する | P3 |
| `H_INTERRUPT_NOTIFY` | `interrupt()` でも `permission_resolved` を出し `waiting_approval` を抜ける | P1b, P4a, P4b |
| `H_DENYALL_NOTIFY` | `result`・`stop`・再開始の一括拒否でも `permission_resolved` を出す | P4a, P4b |
| `H_STOPPED_INPUT` | 停止中の `dispatchInput` は入力を捨てる | P5b |
| `H_STREAM_END_CLEANUP` | SDK のストリームが自然に終わったとき `stop()` と同じ後始末をする | P1a（単独で入れると P8 も成立） |

これは「こう直せ」という提案ではない。原因の切り分けのための道具で、直し方の良し悪しは検討していない。

## 2. 反例の一覧

イベントの並びはモデルのアクション名。`sdk-process.ts` は `packages/bridge/src/sdk-process.ts`。
「再現」は `sketch/counterexamples.test.ts` のテスト名（意図した性質を assert しているので、**失敗＝反例が実物で再現**）。
出力は `out/sketch/vitest-run.txt`（14 件中、反例 10 件と仮定の外の 1 件が失敗、対照 3 件が成功）。

どの反例も、モデルの該当箇所をコードの行と突き合わせたうえで、実物のクラスで再現を確かめた。
ただし「SDK が実際にその順でイベントを出すか」は SDK の内部なので確かめていない。そこは各項に書いた。

### CE-1（P1a）保留中に `system/status` が来ると `waiting_approval` を抜ける

- 並び: `start_with_initial_input` → `sdk_pull` → `sdk_can_use_tool(t)` → `announce_finish` → `sdk_status_requesting`（または `sdk_status_compacting`）
- コード: `sdk-process.ts:2671-2674` は保留件数を見ずに `setStatus`。同じ関数の `assistant`・`user` は `pendingPermissions.size === 0` を見ている（`:2681-2690`）。
- 影響: 保留があるのに `running`。この状態で旧クライアントから入力が来ると `shouldInterrupt` が真になり（`:1446-1448`）、`session-input.ts:446-451` が `interrupt()` を呼んで保留中の承認を黙って拒否する。
- 分類: **実装の不具合の疑い**。条件つき。承認待ちの間に `status` フレームが届くのは、並行するサブエージェントが API を呼ぶ場合などに限られるはず。`system` フレームは `parent_tool_use_id` を持たない扱い（`:597-607`）なので、サブエージェント由来でも `:1953-1965` のふるいを通らずに `updateStatusFromMessage` に届く。SDK がその場面で `requesting` を出すかは未確認。
- 再現: `CE-1`、`CE-1b`

### CE-2（P1b・P4）中止シグナルで保留が消えても、状態もクライアントもそのまま

- 並び: … → `sdk_can_use_tool(t)` → `announce_finish` → `sdk_abort(t)`（検証器が出す最短の反例は CE-3 のほうで、こちらは同じ切り替え定数の下の別経路。コードを読んで並びを作り、実物で再現した）
- コード: `sdk-process.ts:2220-2224`。表から消して deny で resolve するだけ。`permission_resolved` を出さず、状態も変えない。
- 影響: `waiting_approval` のまま保留 0 件。クライアントには承認カードが残る。次の `assistant`・`user` フレーム（`:2681-2690`）か `result` で状態は戻る。残ったカードを承認すると「No matching pending tool action.」（`approvals.ts:102-112`）。
- 分類: **実装の不具合の疑い**（軽い）。クライアントは `tool_result`・`result`・`status: idle` で保留表示を消す（`apps/mobile/lib/services/session_pending_input_state.dart:66-76`）ので、ずれは一時的。
- 再現: `CE-2`

### CE-3（P1b・P4）呼ばれた時点で中止済みの要求を、いったん通知してから捨てる

- 並び: … → `sdk_can_use_tool(t, preAborted=true)` → `announce_finish`
- コード: `sdk-process.ts:2198-2217`。登録し、`waiting_approval` にし、`permission_request` を出したあとで `signal.aborted` を見て消す。
- 影響・分類: CE-2 と同じ。**実装の不具合の疑い**（軽い）。中止の確認を登録より前に置けば起きない形。
- 再現: `CE-3`

### CE-4（P3）同じ約束を 2 回 resolve する

- 並び: … → `sdk_can_use_tool(t, preAborted=true)` → `listener_answers_during_announce` → `announce_finish`
- コード: `permission_request` の emit 中に同期リスナーが承認すると `:2250-2253` で 1 回目。戻ったあと `:2214-2216` が登録の有無を見ずに 2 回目の `resolve` を呼ぶ。
- 分類: **コードで対処済み**。JavaScript の Promise は 2 回目の resolve を無視するので、SDK に届くのは 1 回目の結果だけ。ただし「中止済みの要求が allow で決着する」ことにはなる。`packages/bridge/src` のテスト以外のコードを `approve(`・`reject(`・`answer(`・`approveAlways(` で検索した範囲では、`SdkProcess` のこれらを呼ぶのは `websocket/handlers/approvals.ts` だけで、emit の最中に同期で答える呼び出し元は見つからなかった。つまり本番経路では今のところ起きない並びで、コードが備えている再入（`:2261-2267`）を突いたときにだけ出る。
- 再現: `CE-4`（resolve の呼び出しが 2 回）

### CE-5（P1b・P4）`interrupt()` は保留を拒否するが、状態もクライアントもそのまま

- 並び: … → `sdk_can_use_tool(t)` → `announce_finish` → `client_interrupt`
- コード: `sdk-process.ts:1414-1422` と `:2235-2242`。`denyAllPendingPermissions` のコメントが「メッセージも状態変更も出さない。呼び出し側が次の状態へ動かす」と明言している。ところが `interrupt()` は状態を動かさない。SDK の `result` が届いて初めて `idle` になる。
- 分類: **コードで対処済み**（意図された設計で、クライアント側が `result`・`idle` で保留表示を消す）。ただし SCOPE の P1b・P4 の書き方では違反。既存のテスト `sdk-process.test.ts:3346-3372` は `permission_resolved` が出ないことを期待値にしている。`interrupt()` から `result` までの間は「`waiting_approval` で保留 0 件、クライアントにはカードが残る」状態になる。
- 再現: `CE-5`

### CE-6（P4）`result`・`stop`・再開始・異常終了は `permission_resolved` を出さない

- 並び: … → `sdk_can_use_tool(t)` → `announce_finish` → `sdk_result_while_awaiting` / `stop` / `start` / `sdk_error_exit`
- コード: `sdk-process.ts:2693`、`:1385`、`:1198`、`:1360` と `:2235-2242`。
- 分類: **コードで対処済み**（CE-5 と同じ設計。クライアントは `result` と `status: idle / starting` で消す）。1 点だけ未確認の懸念がある。クライアントは「任意回答の質問」（`usesAskUserUi` かつ `isBlocking == false`）を `result` のあとも残す（`session_pending_input_state.dart:40-45`）。この種の要求が `result` の一括拒否に巻き込まれると、Bridge は忘れているのにクライアントには残り続ける。その流れが実際に `canUseTool` を通るかは調べていない。
- 再現: `CE-6`（`result` の場合）

### CE-7（P5）停止後の入力がキューに積まれ、次の `start()` で送られる

- 並び: `stop` → `client_input`
- コード: `dispatchInput`（`sdk-process.ts:1445-1455`）は `stopped` を見ない。停止後は `userMessageResolve` が null なので必ずキューに入る。`start()` は `queryInstance` があるときだけ `stop()` 経由でキューを空にする（`:1177-1179`、`:1378`）ので、停止済みのところへ積まれた入力は次の `start()` の最初の入力として SDK に渡る。
- 届くか: `stop_session` はセッションごと破棄する（`session-catalog.ts:21-34`、`session.ts:2687`）ので届かない。一方、異常終了の `exit` ではセッションは一覧に残る（`session.ts:1080-1093`）ので、`input` は `session-input.ts:424` から停止済みのプロセスに届き、`queued: true` の ack が返る。同じオブジェクトへの `start()` は巻き戻しで呼ばれる（`session.ts:2387`）。
- 分類: **実装の不具合の疑い**。websocket 層まで含めた通しの再現はしていない（クラス単体で確認）。
- 再現: `CE-7`

### CE-8（P1a）SDK のストリームが自然に終わると、保留表が残ったまま `idle` になる

- 並び: … → `sdk_can_use_tool(t)` → `announce_finish` → `sdk_stream_end`
- コード: `sdk-process.ts:2121-2145`。`queryInstance = null` と `setStatus("idle")` はするが、`denyAllPendingPermissions` も入力キューの掃除も `userMessageResolve` の破棄もしない。例外で終わる経路（`:1351-1361`）は `stop()` を呼ぶので起きない。
- 影響: 保留表が空でない `idle` のセッションは、古いセッションの掃除の対象から外れ続ける（`session.ts:2694-2702`）。セッション一覧にも保留中として出る（`session.ts:1298-1304`、`:1380`）。
- 分類: **実装の不具合の疑い**。条件つき。承認待ちの最中に SDK の反復が例外なしで終わることが実際にあるかは未確認。
- 再現: `CE-8`

### CE-9（P8）自然終了のあと再開始すると、入力が古い入力ストリームに吸われて消える

- 並び: `start` → `sdk_pull`（待機に入る）→ `sdk_stream_end` → `start_with_initial_input(i)` → `client_input`（古い resolver に渡る）→ `sdk_pull` → …（`i` はキューに残り続ける）
- コード: 自然終了は `userMessageResolve` を残す（`:2121-2145`）。`start()` は `queryInstance` が null なので `stop()` を通らず（`:1177-1179`）resolver が生き残る。`dispatchInput` はそれを見て直接渡し、状態を `running` にする（`:1449`、`:1457-1459`、`:2747-2748`）。渡した先は終わったクエリのジェネレーターなので SDK には届かない。新しいクエリには実行中のターンがないので `result` も来ず、`running` のまま。以後の入力はキューに積まれるだけになる。
- 分類: **実装の不具合の疑い**。条件つき。自然終了 → 同じオブジェクトで再開始 → 新しい SDK が入力を取りに来る前に入力、という順が要る。再開始なしでも、自然終了後の入力は同じ理由で消えて `running` のまま止まる（こちらは「セッションが止まっている」ので P8 の対象外）。
- 再現: `CE-9`

### 仮定の外（参考）

SDK がコールバックを呼ぶ時期の仮定（ASSUME-2）を緩めた派生も走らせた（`out/env/`）。
反例ではなく「SDK がそう振る舞うなら起きる」という条件つきの観察。

- `E_PROMPT_AFTER_STOP`（`stop()` のあとに `canUseTool` が呼ばれる）: `handleCanUseTool`〜`waitForPermission`（`:2160-2199`）は `stopped` を見ないので登録して `waiting_approval` にする。P5a と「停止後の承認は何も起こさない」（`ensures`）が破れる。`close()` 後に SDK が呼ぶことがあるかは未確認。この切り替えは最初の `start()` より前の呼び出しも許してしまうので、`out/env/env_prompt_after_stop*/` のうち「停止後」の観察として読めるのは P5a と `ensures` の並びだけ。
- `E_PROMPT_OUT_OF_TURN`（メインのターンが終わったあとにバックグラウンドのエージェントが承認を求める）: P8 が破れる。詳しくは「4. 活性」。SCOPE はバックグラウンドタスクを対象外としている。

### モデルの誤りだったもの

- **モード変更のコールバックの割り込み位置**。最初は `setPermissionMode` の `.then` コールバックの開始を独立したステップにしていた。そのせいで M3 が「1 件のモード変更 → 再開始 → コールバック開始」という、実際には起きない並び（マイクロタスクの前にマクロタスクは割り込めない）で検出されていた。開始を前のイベントと同じステップにまとめ直した。直したあとの M3 の反例は 2 件のモード変更を要する 6 手になった。
- **緊急ステップによる公平性の抜け**。上の直しを最初は「コールバックが実行可能な間は他のアクションを止める」ガードで書いた。すると公平なアクションが一瞬無効になるので弱公平性が効かなくなり、P7・P8 に偽の反例（モード変更を延々と繰り返すラッソ）が出た。ガードをやめてステップの合成に書き換えた。

どちらも性質は変えていない。

## 3. 仕込んだ退行

`tools/make_mutants.py` が元の仕様から置換で作る（置換が外れたら失敗する）。差分は `out/diffs/m1.diff` など。
現在のコードのモデルでは 7 件がもともと破れているので、「新しく破れた性質」で判定した。
あわせて、全性質が成立する `fix_all` に同じ退行を入れた派生（`*_on_fix_all`）でも確かめた。結果は `out/seeded/`。

| ID | 検出 | 新しく破れた性質（現在のモデル） | `fix_all` に入れた場合 |
|---|---|---|---|
| M1 | できた | P2（5 手）、P7（ラッソ） | P2（5 手）、P7、P8（どちらもラッソ） |
| M2 | **条件つき** | P2（3 手）、P4c（3 手）。補助の `Aux_DeferredFlag` も | 左に加えて P4a・P4b（5 手。承認・拒否のあとクライアントに要求が残る）、P1b（4 手） |
| M3 | できた | P6（6 手） | P6（6 手）のみ |

- M1 の P3 は「高々 1 回」なので、決着が 0 回になる退行は拾わない。拾ったのは P2 と P7。P7 を Bridge の保留表ではなく SDK 側の約束について書いたのが効いている（表について書くと M1 は表を空にするので通ってしまう）。
- **M2 の検出は割り引いて読む必要がある**。
  - SCOPE の P4（P4a・P4b）は現在のモデルでもともと破れているので、現在のモデルでは M2 を見分けられない（反例は出るが、M2 を入れる前と同じ「中止済みの要求」の並びのまま）。
  - 現在のモデルで新しく破れたのは 2 つ。P4c は M2 の前半（登録より前に通知）を拾うために私が足した性質で、SCOPE の P4 の文を「通知の途中」に延長したもの。P2 の 3 手の反例は、`permission_request` の emit と登録の間というハンドラ途中の状態を見ている（P1a・P1b と違い、P2 には「処理の途中は問わない」の但し書きがないのでそのまま数えた）。
  - M2 の後半（`permission_resolved` を出さない）を SCOPE の P4 そのもので検出できたのは `m2_on_fix_all` だけ。反例は `… → announce_finish → client_reject(t)`（または `client_approve_always`）で終わり、決着したのにクライアントの保留集合に残る。原因が M2 の後半であることは並びで確かめた。
  - `m2_on_fix_all` の P1b は、M2 の書き換えが「中止済み」分岐の仮の修正ごと古い順序に戻すために再発したもので、M2 固有の検出ではない。
- `m1_on_fix_all` の P8 は M1 の帰結として筋が通っている。`interrupt()` が表だけ消すと SDK は約束を待ち続け、ターンが終わらないので、キューの入力が永久に渡らない。
- M3 の反例: `start` → `client_set_mode`（SDK 待ち）→ `client_set_mode`（1 件目の後ろに連結）→ 再開始 → `stop` → `mode_op_sdk_done`（1 件目は `:1628` の検査で書かない。連結されていた 2 件目が世代検査なしで走り、クエリがないので `_permissionMode` を直接書く）。同時のモード変更を 1 件しか置けないモデルでは `:1628` のインスタンス検査が M3 を隠すので、2 件にしてある。

## 4. 活性の扱いと公平性の仮定

FSL の `leadsTo` と `fair action`（弱公平性、アクションの引数ごと）を使った。`leadsTo` は BMC のラッソ探索で、深さは有界。

置いた仮定は 3 つ。仕様では `fair action` と書いてある。

| 公平なアクション | 意味 |
|---|---|
| `client_approve(t)` | クライアントは、自分に見えている要求にはいずれ答える（見えていない要求には答えられない） |
| `sdk_pull` | SDK は入力ストリームが待機中でなければ、いずれ次の入力を取りに来る |
| `sdk_result` | SDK は、`canUseTool` の約束を待っていないターンをいずれ `result` で終える |

`sdk_result` を有効にする条件は Bridge の `status` ではなく SDK 側の実際のターン（`sdkInflight`）で書いた。Bridge の思い込みで書くと、状態が固まる不具合を公平性が隠してしまう。
約束を待っている最中に `result` が来る場合は別アクション（`sdk_result_while_awaiting`、公平性なし）にした。

結果（`out/current/`、`out/liveness/`）。

- **P7**: 成立（深さ 8、12）。`client_approve` の公平性を外すと破れる（`out/liveness/current_nofair_client_approve/`）。つまり「クライアントが答える限り」という仮定に全面的に寄りかかった性質で、Bridge 側の誤りを見つける力は M1 のような「表から消えて答えようがなくなる」場合に限られる。
- **P8**: 現在のモデルでは破れる（CE-9）。`H_STREAM_END_CLEANUP` だけを入れると深さ 8 で成立（`out/liveness/fix_only_stream_end/`）。`fix_all` では深さ 8 と 10 で成立。
- 公平性を 1 つずつ外した結果（`fix_all` で。P8 が成立するモデルでないと比べられないため）。3 つとも P8 に必要で、P7 に必要なのは `client_approve` だけ。

  | 外した公平性 | P7 | P8 |
  |---|---|---|
  | `client_approve` | 破れる | 破れる |
  | `sdk_pull` | 成立 | 破れる |
  | `sdk_result` | 成立 | 破れる |
- **順位づけによる無制限の証明**（`helpful` ＋ `decreases`、`variants/current_ranked_p7.fsl`）は `unknown_cti / helpful_action_not_enabled` で不成立。`permission_request` の emit 中（`announcing`）は約束が保留なのに `client_approve` が無効になるため。FSL の順位づけは「保留中は helpful なアクションが常に有効」を要求するので、このモデルの形では使えなかった。P7・P8 は有界のままである。
- 活性の検査は高くつく。P8 は深さ 8 で 1 回 50〜150 秒、安全性は深さ 10 で 1 件 5〜40 秒（どちらもマシンの負荷で大きく振れた）。深さ 10 は `fix_all` の P8 で 1 回だけ走らせた。
- `E_PROMPT_OUT_OF_TURN`（メインのターンが動いていないときに `canUseTool` が来る。SCOPE の対象外）: `fix_all` に入れても P8 だけが破れる（`out/env/env_prompt_out_of_turn_on_fix_all/`）。承認要求が `status` を `waiting_approval` にし、承認すると `running` になる（`sdk-process.ts:2254-2256`）。SDK 側には終わらせるターンがないので `result` が来ず、以後の入力はキューに積まれたままになる。実物でも再現した（`sketch` の `OUT-1`）。バックグラウンドのエージェントがターンの外で承認を求めることが実際にあるかは未確認。`:1955-1958` のコメントは、バックグラウンドのエージェントのフレームが `result` のあとも流れ続けることには触れている。

表現できなかったもの。

- 「直接渡した入力（キューを通らないもの）が SDK に届く」は P8 に入れていない。CE-9 の「消える入力」そのものはキューに積まれた別の入力の飢餓として検出している。
- 強公平性は FSL にない。条件つきの公平性はアクションを分けて書く（`sdk_result` を 2 つに分けたのはそのため）。

## 5. 変異解析（`fslc mutate`）

`fslc mutate` は破れた性質がある仕様を基準にできない。そこで成立する性質だけを残した写しを使った。

- 対象: `variants/current_holding_midsession.fsl`。`current_holding.fsl`（P2・P4c・P5a・P6・P7 と補助 7 本）の `init` を、セッション開始済み・入力待ち・ターン実行中の状態に替えたもの（`tools/make_midsession.py`）。この初期状態からも不変条件が帰納法で証明できることを確かめてある。
- なぜ初期状態を替えたか: 元の `init` からは承認アクションに届くのが 5 手目で、深さ 5〜6 の変異解析は 892 件で 4 時間を超える見込みだった（深さ 6 は 1 件 7〜18 秒）。途中状態から始めれば深さ 4 で「要求 → 通知 → 回答 → その後」まで届く。**下の点数はこの初期状態・深さ 4 のもの**で、元の仕様の点数ではない。
- 結果（`out/mutate/current_holding_midsession.depth4.json`、進行ログは同名の `.progress.txt`）:

  | 変異体 | 検出（killed） | 生存（survived） | 無効 | 検出率 |
  |---|---|---|---|---|
  | 892 | 292 | 596 | 4 | **0.3288** |

- 検出した側の内訳（上位）: `Aux_IdleMeansNoPrompt` 52、`build_spec`（仕様として成り立たなくなる変異）40、P7 32、P2 31、P4c 26、P5a 19、`Aux_UnsettledHasNoResolve` 18、`Aux_TableEntryIsAwaited` 15、型の境界 `_bounds_*` 計 30、P6 2。

### 生き残った 596 件の意味

変異が触った行で分けると、理由がはっきり分かれる（重なりのない分類。JSON の `mutants[].loc` の行から集計）。

| 変異が触った行 | 検出 | 生存 | 生き残る理由 |
|---|---|---|---|
| `H_*`・`E_*` の定数と、それを読む行 | 8 | 129 | 切り分け用の足場。定数が 0 の間は死んだコードなので、中身を変えても何も変わらない。0 を 1 にする変異は「仮の修正を入れる」ことで、生き残って当然 |
| `requires`（ガード）の除去・反転・書き換え | 78 | 143 | ガードを反転・強化する変異は振る舞いを減らすだけなので安全性では気づけない。モデルの上限用のガード（キュー長など）は等価 |
| `status` への代入 | 37 | 97 | P1a・P1b を外してあるので、`waiting_approval` と保留表の関係を見る性質がない。`status` を見るのは P5a と補助 `Aux_IdleMeansNoPrompt` だけ |
| `settles`（resolve の回数） | 2 | 52 | P3 を外してある。「決着したら 1 回は呼ばれている」という性質も書いていない |
| `queue`・`parked`・`waiterStale` | 3 | 28 | P8 と P5b を外してある |
| モード変更まわり（`mode`・`op*`・`lastModeWriteStale`） | 18 | 32 | モードについての性質は P6（古い変更が書かない）だけ。「新しい変更は反映される」は SCOPE にない |
| `clientSees`（足場の外） | 1 | 6 | P4a・P4b を外してある |
| 型の境界 | 6 | 14 | 境界を広げる変異は等価（届かない値） |
| `prom`・`pend`・`sdkInflight` | 89 | 23 | P2・P4c・P7 と補助が見張っている。ここは検出率 79% |
| その他（条件式、`forall`、`hasQuery`、`hasRule` など） | 50 | 72 | まちまち |

読み方。

- 生存の 22%（129 件）は切り替え定数という足場が生んだ水増しで、仕様の弱さではない。足場の行を除くと検出率は 284 / 751 = 0.378。原因の切り分けを定数でやる方法は、変異解析の点数を汚す。
- `status`・`settles`・`queue` 系・`clientSees` の生存 183 件は、「現在のコードが満たしていない性質（P1a・P1b・P3・P4a・P4b・P5b・P8）を基準から外したので、その変数を見張る性質がない」ことを表している。仕様が空振りしているというより、現在のコードに対して成り立つと言えることが P2・P4c・P5a・P6・P7 に限られる、というのが実情。
- SDK の約束と保留表（`prom`・`pend`）を触る変異は 8 割近く検出している。P2 と P7 が効いている部分で、M1 を拾えたのと同じ理由。

上の表は `tools/summarize.py` が同じ分類で作り直す（`out/SUMMARY.txt` の「by kind of mutated line」）。全性質が成立する `fix_all` の変異解析は時間の都合で走らせていない。したがって「P1・P3・P4 を戻せば `status`・`settles`・`clientSees` の生存が減る」というのは見込みであって、確かめた結果ではない。

`out/mutate/spec.sha256` は変異解析に使った仕様のハッシュ。ただし `current_holding_midsession.fsl` だけは、実行後に先頭の生成コメント 1 行を書き換えたので、実行時のものと 1 行違う（本体は同じ）。

`--by-requirement` の結果: P2 31、P4（P4c）26、P5（P5a）19、P6 2、P7 32、補助は AUX2 52・AUX4 18・AUX3 15・AUX6 6・AUX7 5・AUX1 4・AUX5 3。
P6 の 2 件は少ない。モード変更の変異の多くは、世代検査を壊すのではなく「書く値や順番を変える」もので、P6 では見分けられない。`fslc` の変異演算子は代入の削除、定数の入れ替え、`requires` の除去・反転、等号の反転、整数 ±1、`fair` の除去といった小さな書き換えで、M1〜M3 のような「意味のある退行」は手で書く必要があった。

## 6. 仕様と実装のつなぎ（`fslc scenarios`・`fslc testgen`）

対象は成立する性質だけを残した `variants/current_holding.fsl`（`testgen` は破れた仕様からは生成しない）。出力は `out/testgen/`。

- `scenarios --depth 6`: 31 本。内訳はアクションを 1 回通すだけの `action_coverage` が 29 本、P7 の応答を示す `leadsTo` が 2 本。反例に相当する並びや、割り込みを突く並びは出ない。
- `testgen --target vitest --depth 6`: `PermissionFlow.conformance.test.ts`（518 行）。上のシナリオ 31 本と、固定シードの 100 手のランダムウォーク 1 本。生成に 10 分以上かかった（先に検証が走る）。

そのまま `SdkProcess` のテストにできるか。結論は「アダプターを書けば動かせるが、得るものは少ない。反例から手で書いたテストのほうがずっと効く」。

1. **ランダムウォークが承認フローに届かない**。100 手の内訳は `start*` 28、`sdk_status_mode` 16、`client_set_mode` 15、`client_late_approve` 9、`stop` 8 など。`sdk_can_use_tool` は 0 回で、保留がある状態は 1 手もない。検証したい部分を一度も通らない。
2. **期待値がモデルの全変数**。`observe()` は 23 変数すべてを返す必要がある。`_status`・`pendingPermissions`・`pendingInputQueue`・`userMessageResolve`・`stopped`・`queryInstance`・`_permissionMode` は `as any` で読める（既存のテストと同じ流儀）。しかし `opStale`・`opQiChanged`・`opAfter`・`waiterStale`・`lastModeWriteStale`・`sdkInflight`・`prom`・`settles` は実装に対応する変数がない。アダプターの中でモデルを写し直すことになり、その部分は「モデルをモデルと比べる」だけになる。
3. **アダプターの `step` と `observe` が同期**。`setPermissionMode` はマイクロタスクを挟むので、`step` の直後の `observe` では結果が見えない。生成物を `async` に手で書き換える必要がある。
4. **環境側のアクションを起こす仕掛けは既存テストの流儀で足りる**。`query` をモックし、渡された `prompt` ジェネレーターの `next()` を呼べば `sdk_pull`、モックの非同期イテレーターにフレームを流せば `sdk_*` フレーム、`options.canUseTool` を呼べば `sdk_can_use_tool`、`setPermissionMode` の Promise を握れば `mode_op_sdk_done / failed` になる。`sketch/counterexamples.test.ts` の `fakeQuery()` がその最小形。
5. **モデルが 1 手にまとめた範囲は試されない**。生成されるテストはアクション 1 つを 1 手として進める。emit 中の再入のような、アクションの内側の順序は自分で書くしかない。

実際にやったこと。生成物のアダプターは配線していない（上の 1〜3 の理由で、手間に見合わないと判断した）。したがって `testgen` の生成物が実物に対して通るかどうかは確かめていない。代わりに、反例 9 系統を既存テストの流儀で手書きし、実物で走らせた（`sketch/`、`out/sketch/vitest-run.txt`）。`packages/` のソースには何も足していない。`sketch/node_modules` は `packages/bridge/node_modules` へのシンボリックリンクで、Bridge の vitest を借りている。

FSL の「仕様と実装をつなぐ」機能のうち、今回役に立ったのは `testgen` ではなく、**反例の並びがそのまま失敗する単体テストの台本になった**ことのほう。

## 7. 「書く → 検証 → 直す」の往復

仕様本体の書き直しは 12 回。うち `fslc check` に弾かれたのは 1 回（事前の小さな試し書きで 1 回）。

| # | きっかけ | 直したこと |
|---|---|---|
| 1 | 初版 | `check` は 1 回で通った。スキルの参照文書が長大（構文だけで 2,800 行）で、必要な箇所を探すのに時間がかかった |
| 2 | 性質ごとの反例が出そろった | 原因の切り分け用に `H_*` を導入。クライアントの見え方を `Set` から `Map<Tool, Bool>` に変更（`forall` の中で `Set` を少しずつ書き換えられないため） |
| 3 | 帰納法が `unknown_cti`（`_bounds_settles`） | 補助不変条件 `Aux_*` を 4 本追加 |
| 4 | 帰納法が `ensures` の CTI | P5 を P5a・P5b に分割（成立する部分を帰納法の仮定に使うため） |
| 5 | 帰納法が P5a の CTI | `Aux_StoppedHasNoQuery` を追加 → `proved` |
| 6 | `fix_all` の帰納法が P4b の CTI | `--lemma` で候補を渡したが、候補は 1 本ずつ独立に判定されるので互いに支え合う補題は全滅。仕様に条件つきの補題 `Fix_*` として書いた |
| 7 | `Fix_*` の CTI | `Aux_DeferredFlag` を追加 → `proved` |
| 8 | 見直し | 再開始後も古いモード変更の連結順は保たれる、という点をコードどおりに修正 |
| 9 | M3 の反例が不自然 | モード変更コールバックを緊急ステップに（モデルの誤り 1） |
| 10 | 助言を受けて | 仮定の外を見る `E_*` を追加 |
| 11 | P7・P8 に偽のラッソ | 緊急ガードをやめ、ステップの合成に書き換え（モデルの誤り 2）。`check` が「同じ状態位置への二重代入」で拒否 |
| 12 | 上の拒否 | `opPhase[s]` と `opPhase[1 - s]` が別の位置だと `fslc` が証明できないため、`forall` と条件式で 1 回の代入に書き換え |

性質は、分割（P4・P5）以外は初版から変えていない。反例を通すために弱めた箇所はない。

### つまずいた点

- **`verify` は最初の違反 1 件で止まる**。性質ごとの表を作るには `--property` で 1 件ずつ走らせる必要がある。スキルは「`--property` の実行を完了報告に使うな」と言うが、破れた性質が複数ある仕様では他に方法がない。`out/current/unfiltered.bmc.json` に絞らない実行も残した。
- **`--property` で選んでも `ensures` と型の境界は検査され、選んだ性質の名前ではなくそちらが報告される**。`out/env/` で全性質が同じ `ensures` 違反になったのはこのため。集計はそれを区別して表示するようにした。
- **反例は性質ごとに最短の 1 本だけ**。同じ性質に原因が複数あるとき、次の原因を見るには先の原因を潰した派生が要る。`H_*` と「1 本だけ外す」派生（`out/attribution/`）はその代用。同じ定数の下にある複数の経路（`requesting` と `compacting`、`result`・`stop`・再開始）は 1 本しか出ないので、残りはコードを読んで補った。
- **同じアクションの中で同じ変数に 2 回代入できない**。`denyAllPendingPermissions` に当たる 7 行の塊を 8 か所に複製した（手続きの再利用がない。`def` は式だけ）。M1 はその 8 か所を全部書き換える必要があった。
- **マップの添字が別だと証明できない代入は拒否される**（`m[s]` と `m[1 - s]`）。
- **割り込めない続きの処理を素直に書く手段がない**。緊急ステップをガードで書くと弱公平性が壊れる（上の誤り 2）。
- **`mutate` は既定で先頭 200 件で打ち切る**（`mutant cap 200 reached: 692 dropped` と notes に出るだけで、終了コードは 0）。先頭は定数・型・`init`・`start` なので、肝心の承認アクションには届かない。`--max-mutants` を明示しないと点数が的外れになる。
- **`lint` は要件IDの形式で 21 件指摘する**（`non_canonical_id`。`P1a` ではなく `REQ-…-001` の形を求める）。SCOPE のIDをそのまま使うほうを優先し、直していない（`out/lint.json`）。
- 計測中はマシンの負荷が高く（他の検証や動画処理が並行、ロードアベレージ 50 超）、所要時間は目安にしかならない。

## 8. モデルが単純化したこと、コードと対応が取れていない部分

仕様の先頭の `ASSUME-1`〜`9` と同じ内容。

- **ツール呼び出しIDは使い切り**（2 個）。1 回の実行で `canUseTool` は 2 回まで。IDを使い回すと中止リスナー（`:2221` は ID の有無だけを見る）が別の要求を消す、という類の誤りは見ていない。3 個では走らせていない。
- **SDK は生きているクエリのターン中にだけ `canUseTool` とメインのフレームを送る**。バックグラウンドのエージェントは対象外（`E_*` で一部だけ覗いた）。
- **`close()` や再開始のあと、古いクエリは入力ストリームを取りに来ず、そのフレームも処理されない**（`:1926` の世代検査を根拠にした）。古いジェネレーターが再開始後に動く場合は見ていない。
- **1 つのハンドラ＝1 つのアクション**。途中の割り込みとして扱ったのは `permission_request` の emit 中の再入と、`queryInstance.setPermissionMode()` の `await` だけ。`result` の前の `await authResolution`（`:2026`）と自然終了の `await authResolution`（`:2122`）は割り込み点にしていない。
- **クライアントの見え方は emit の順に即時更新**。配送の遅れは「見えていない要求への承認」（`client_late_approve`）で代用した。メッセージの追い越しや切断・再接続（履歴からの復元）は見ていない。
- **クライアントは SCOPE の定義どおり `permission_request`・`permission_resolved` だけで保留集合を作る**。実物のアプリは `result`・`status`・`tool_result` でも消す。それはモデルに入れず、反例の分類に使った。
- **入力はID 2 個、キュー長 2**。あふれる場合はガードで止めている。`sdkInflight` の上限 2 は補助不変条件 `Aux_OnePromptInFlight` で効いていないことを示した。
- **モード**は 3 種、同時のモード変更は 2 件まで。`approveAlways` のセッション許可ルールは「1 本あるかないか」に潰した。
- **`interrupt()` のバックグラウンドタスク分岐**（`:1404-1413`）、ステア用キュー、認証、費用、画像、`clearContext` つきの承認（セッションを作り直す）はモデルにない。`start()` の失敗経路（`:1222-1245`。認証の事前確認の失敗、`startSdkQuery` の例外）もない。
- **websocket 層**は「どの呼び出しがいつ届くか」だけを写した（入力のあとの `interrupt()`、`stop_session` は破棄）。セッション単位の送信待ちキュー（`delivery` 指定時）は対象外。
- SDK の `result` が「約束を待っていないときだけ公平」という仮定は、SDK の実装を確かめたものではない。

## 9. できなかったこと、確かめていないこと

- P7・P8 の深さ無制限の証明。有界（深さ 8〜12）のみ。
- 明示状態エンジンでの状態空間の閉包（予算内に終わらない）。到達可能な状態数は不明。
- ID 3 個・入力 3 個など、より大きい世界での検査。
- `testgen` が生成したアダプターの配線と実行（理由は 6 章）。
- 反例が本番で起きる頻度。SDK がそのイベント順を実際に出すかは、CE-1・CE-4・CE-8・CE-9 と `E_*` について未確認。
- CE-7 の websocket 層を通した再現。
- `fix_all` の変異解析（時間の都合で現在のモデルだけ）。
- スキルが求める「形式化メモを人に確認してもらう」手順は、人がいないので SCOPE.md を確認済みの意図として代用した。
- スキルの設計層の手順のうち `refine`（上位の要件仕様との対応づけ）は、上位の仕様がないので行っていない。`diff` も使っていない。
- CE-2（中止リスナー）の並びは検証器の出力ではなく、コードを読んで作った（検証器が出す最短の反例は同じ原因の CE-3）。実物では再現している。

### 自分のディレクトリの外に書いてしまったもの

- `packages/bridge/node_modules/.vite/vitest/da39a3ee…/results.json`。`sketch` のテストを最初に走らせたとき、vitest の既定のキャッシュ先がシンボリックリンク越しに Bridge 側になっていて、テストの所要時間の記録が上書きされた（git の管理外、ソースではない）。気づいたあと `sketch/vitest.config.ts` に `cacheDir` を置き、以後は `sketch/.vite-cache` に書くようにした。上書きされたファイルは元に戻していない。
- `~/.cache/fslc/`。`fslc verify` の判定キャッシュ。最初のうち `--no-cache` をつけずに走らせた分が入っている。`run.sh` は `FSLC_CACHE=off` で走るので読み書きしない。
