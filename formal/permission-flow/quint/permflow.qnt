// -*- mode: Bluespec; -*-
// 権限承認フロー (packages/bridge/src/sdk-process.ts の SdkProcess) のモデル。
// 出題: formal/permission-flow/SCOPE.md
//
// 1 つの同期ハンドラ (JS のマクロタスク 1 個 + それに続くマイクロタスク) を 1 アクションにする。
// 分割するのは本当に他のイベントが割り込める所だけ:
//   - setPermissionMode の `await queryInstance.setPermissionMode(mode)` (sdk-process.ts:1625)
//   - SDK が次の入力を取りに来る (createUserMessageStream の next(), :1803)
//   - interrupt() から SDK の result まで
module permflow {
  // ---- 仕込む退行 (SCOPE.md) ----
  const M1: bool // denyAll が保留表を消すだけで SDK の約束を決着させない (ce064bf0 より前)
  const M2: bool // permission_request を登録より前に送り、決着時に permission_resolved を送らない (d6c7e677 より前)
  const M3: bool // setPermissionMode の世代チェック (:1621, :1627) を外す

  // ---- SDK / 環境の仮定 (true = 許す) ----
  const ENV_ANYTIME: bool             // SDK のメインスレッドのメッセージ・canUseTool がターン外でも届く
  const ENV_MSGS_WHILE_PENDING: bool  // SDK が canUseTool の返事待ちの間にもメインスレッドのメッセージが届く
  const ENV_BG: bool                  // ターン外でも canUseTool が来る (バックグラウンドのサブエージェント)
  const ENV_ABORT: bool               // canUseTool の AbortSignal が発火する (呼び出し時点で発火済みも含む)
  const ENV_NATURAL_END: bool         // SDK のストリームが例外なしで終わる (processMessages の正常終了)
  const ENV_REENTRANT: bool           // permission_request の同期リスナーがその場で承認する
  const ENV_INPUT_AFTER_DEAD: bool    // 停止・終了後のプロセスにも入力が届く (exit 後もセッションは残る: session.ts:1080)

  // ---- 大きさ ----
  const IDS: Set[str]      // ツール呼び出し ID (1 回ずつしか使わない)
  const ASK_IDS: Set[str]  // そのうち AskUserQuestion のもの
  const MAX_RESTARTS: int  // start() の再呼び出し回数の上限
  const TRACE_LABELS: bool // 反例を読むための直前イベント名を状態に持つ (活性・全探索では false)

  pure val MAX_QUEUE = 2
  pure val MAX_OPS = 2
  pure val MODES = Set("default", "plan")

  // 処理中のモード変更 1 件。gen は発行時の permissionModeGeneration。
  // start() が permissionModeUpdates を作り直す (:1200) のと世代を進める (:1199) のは同時なので、
  // gen は「どの Promise 連鎖に繋がっているか」も表す。
  // q = -1: 連鎖の中で順番待ち / q >= 0: その ID の query に SDK 呼び出しを送って await 中
  type Op = { mode: str, gen: int, q: int }

  type State = {
    // ---- Bridge (SdkProcess のフィールド) ----
    status: str,          // _status
    pending: Set[str],    // pendingPermissions のキー
    queueLen: int,        // pendingInputQueue.length
    headSeq: int,         // (ゴースト) キュー先頭が入れ替わるたびに 0/1 反転。P8 用
    waiter: int,          // userMessageResolve を握っているジェネレーターの query ID。-1 = null
    mode: str,            // _permissionMode
    gen: int,             // permissionModeGeneration
    ops: List[Op],        // 処理中の setPermissionMode
    stopped: bool,
    queryAlive: bool,     // queryInstance !== null
    queryId: int,         // queryInstance の同一性 (start のたびに +1)
    allowRule: bool,      // sessionAllowRules に AskUserQuestion 以外へ効く規則がある
    // ---- SDK 側 ----
    sdkPromise: str -> str, // canUseTool の約束: "unused" / "waiting" / "settled"
    sdkTurn: bool,          // SDK のメインターンが進行中
    sdkBacklog: int,        // ターン中に渡され、次のターンとして待っている入力 (0..2 で飽和)
    pullPending: bool,      // SDK が入力ストリームの next() を呼ぼうとしている
    // ---- ゴースト (性質のための記録。コードのガードとは独立) ----
    settleCount: str -> int,     // その要求の resolve() が呼ばれた回数 (2 で飽和)
    clientStrict: Set[str],      // クライアントの保留集合 (permission_request / permission_resolved だけから)
    clientApp: Set[str],         // 同上 + status が idle/starting に変わったら空にする (Flutter の実装)
    requestSeen: Set[str],       // permission_request が届いた ID
    resolvedSeen: Set[str],      // permission_resolved が届いた ID
    announcedUnregistered: Set[str], // permission_request が出た瞬間に保留表に無かった ID
    staleModeWrite: bool,        // 再開始より前に出したモード変更が _permissionMode を書いた
    lostInput: bool,             // 入力が、もう使われていないジェネレーターに渡って消えた
    postStopEffect: bool,        // 停止後の approve/reject/answer が状態を変えた
    userDecided: Set[str],       // resolvePendingPermission を通って決着した ID (承認・拒否・回答)
    last: { ev: str, arg: str },
  }

  var s: State

  // ================= 純粋な補助関数 (コードのメソッドに対応) =================

  pure def min2(a: int, b: int): int = if (a < b) a else b

  // setStatus (:2766): 変化したときだけ status メッセージを出す。
  // Flutter は idle / starting を受けると保留中の承認を捨てる
  // (apps/mobile/lib/services/chat_message_handler.dart:476)。
  pure def setStatus(st: State, v: str): State =
    if (st.status == v) st
    else {
      ...st,
      status: v,
      clientApp: if (v == "idle" or v == "starting") Set() else st.clientApp,
    }

  // PendingPermission.resolve(...) を ids について呼ぶ
  pure def settle(st: State, ids: Set[str]): State = {
    ...st,
    sdkPromise: st.sdkPromise.keys().mapBy(i =>
      if (i.in(ids)) "settled" else st.sdkPromise.get(i)),
    settleCount: st.settleCount.keys().mapBy(i =>
      if (i.in(ids)) min2(st.settleCount.get(i) + 1, 2) else st.settleCount.get(i)),
  }

  // denyAllPendingPermissions (:2235)。メッセージも状態変更も出さない。
  pure def denyAll(st: State): State =
    if (M1) { ...st, pending: Set() }
    else { ...settle(st, st.pending), pending: Set() }

  pure def emitRequest(st: State, id: str): State = {
    ...st,
    clientStrict: st.clientStrict.union(Set(id)),
    clientApp: st.clientApp.union(Set(id)),
    requestSeen: st.requestSeen.union(Set(id)),
    announcedUnregistered:
      if (id.in(st.pending)) st.announcedUnregistered
      else st.announcedUnregistered.union(Set(id)),
  }

  pure def emitResolved(st: State, id: str): State = {
    ...st,
    clientStrict: st.clientStrict.exclude(Set(id)),
    clientApp: st.clientApp.exclude(Set(id)),
    resolvedSeen: st.resolvedSeen.union(Set(id)),
  }

  // resolvePendingPermission (:2244)。呼ぶ側が id in pending を確かめてある。
  pure def resolvePending(st: State, id: str): State = {
    pure val s1 = settle(
      { ...st, pending: st.pending.exclude(Set(id)), userDecided: st.userDecided.union(Set(id)) },
      Set(id)
    )
    pure val s2 = if (s1.pending == Set()) setStatus(s1, "running") else s1
    if (M2) s2 else emitResolved(s2, id)
  }

  // stop (:1368)
  pure def stopP(st: State): State = {
    pure val s1 = {
      ...st,
      stopped: true,
      queueLen: 0,
      queryAlive: false,
      sdkTurn: false,
      sdkBacklog: 0,
      pullPending: false,
    }
    pure val s2 = denyAll(s1)
    setStatus({ ...s2, waiter: -1 }, "idle")
  }

  // start (:1176)。queryInstance が無いときは stop() を通らない点に注意 (:1177)。
  pure def startP(st: State, newMode: str, withInit: bool): State = {
    pure val s1 = if (st.queryAlive) stopP(st) else st
    pure val s2 = denyAll({ ...s1, stopped: false })
    pure val s3 = {
      ...s2,
      gen: s2.gen + 1,
      mode: newMode,
      allowRule: false,
      queueLen: if (withInit) s2.queueLen + 1 else s2.queueLen,
    }
    pure val s4 = setStatus(s3, "starting")
    {
      ...s4,
      queryAlive: true,
      queryId: s4.queryId + 1,
      pullPending: true,
      sdkTurn: false,
      sdkBacklog: 0,
    }
  }

  // interrupt (:1403)。バックグラウンドタスクの分岐 (:1404-1413) は対象外。
  pure def interruptP(st: State): State =
    if (st.queryAlive) denyAll(st) else st

  // ジェネレーター w が yield した入力が SDK に届く。
  // w が今の query のものでなければ、誰も読まないストリームに落ちる。
  pure def deliverToSdk(st: State, w: int): State =
    if (st.queryAlive and w == st.queryId) {
      ...st,
      pullPending: true,
      sdkTurn: true,
      sdkBacklog: if (st.sdkTurn) min2(st.sdkBacklog + 1, 2) else st.sdkBacklog,
    } else { ...st, lostInput: true }

  pure def turnInProgress(st: State): bool =
    st.status == "running" or st.status == "compacting" or st.status == "waiting_approval"

  // createUserMessageStream のループ 1 周 (:1804-1836)。steer キューは対象外。
  pure def pullP(st: State): State =
    if (st.queueLen > 0 and not(turnInProgress(st)))
      deliverToSdk(
        setStatus({ ...st, queueLen: st.queueLen - 1, headSeq: 1 - st.headSeq }, "running"),
        st.queryId
      )
    else { ...st, waiter: st.queryId, pullPending: false }

  // dispatchInput (:1445) と、handleInput がその直後に呼ぶ interrupt
  // (websocket/handlers/session-input.ts:446-450)。delivery 指定なしの旧来の経路。
  // 動いていないプロセスは入力を受け取らない (dispatchInput 冒頭の isRunning の確認)。
  pure def inputP(st: State): State = {
    pure val shouldInterrupt = st.status == "running" or st.status == "compacting"
    pure val mustQueue = shouldInterrupt or st.status == "waiting_approval"
    if (not(st.queryAlive)) st
    else if (mustQueue or st.waiter == -1) {
      pure val s1 = { ...st, queueLen: st.queueLen + 1 }
      if (shouldInterrupt) interruptP(s1) else s1
    } else deliverToSdk(setStatus({ ...st, waiter: -1 }, "running"), st.waiter)
  }

  // updateStatusFromMessage の result (:2692) + deliverQueuedInputIfWaiting (:2729)
  pure def resultP(st: State): State = {
    pure val sA =
      if (st.sdkBacklog > 0) { ...st, sdkBacklog: st.sdkBacklog - 1 }
      else { ...st, sdkTurn: false }
    pure val s1 = setStatus(denyAll(sA), "idle")
    if (s1.waiter != -1 and s1.queueLen > 0)
      deliverToSdk(
        setStatus(
          { ...s1, waiter: -1, queueLen: s1.queueLen - 1, headSeq: 1 - s1.headSeq },
          "running"
        ),
        s1.waiter
      )
    else s1
  }

  // handleCanUseTool (:2160) + waitForPermission (:2185)
  pure def canUseToolP(st: State, id: str, reentrant: bool, preAborted: bool): State =
    if (not(id.in(ASK_IDS)) and st.allowRule) {
      // セッション規則で即許可 (:2175)。保留表には載らない。
      ...st,
      sdkPromise: st.sdkPromise.set(id, "settled"),
      settleCount: st.settleCount.set(id, 1),
    } else if (M2) {
      // d6c7e677 より前: 送信 → 状態 → 登録。リスナーがその場で承認しても表に無いので空振り。
      pure val s1 = setStatus(emitRequest(st, id), "waiting_approval")
      pure val s2 = {
        ...s1,
        pending: s1.pending.union(Set(id)),
        sdkPromise: s1.sdkPromise.set(id, "waiting"),
      }
      if (preAborted) settle({ ...s2, pending: s2.pending.exclude(Set(id)) }, Set(id)) else s2
    } else {
      // 現行: 登録 (:2198) → 状態 (:2199) → 送信 (:2202) → 溜めた決着イベント (:2209)
      pure val s1 = setStatus(
        {
          ...st,
          pending: st.pending.union(Set(id)),
          sdkPromise: st.sdkPromise.set(id, "waiting"),
        },
        "waiting_approval"
      )
      pure val s2 = emitRequest(s1, id)
      pure val s3 = if (reentrant) resolvePending(s2, id) else s2
      // :2214-2217 は表に残っているかを見ずに delete と resolve をする
      if (preAborted) settle({ ...s3, pending: s3.pending.exclude(Set(id)) }, Set(id)) else s3
    }

  // AbortSignal のリスナー (:2220-2225)。pending に在るときだけ呼ばれる前提。
  pure def abortP(st: State, id: str): State =
    settle({ ...st, pending: st.pending.exclude(Set(id)) }, Set(id))

  pure def assistantOrUserP(st: State): State =
    if (st.pending == Set()) setStatus(st, "running") else st

  pure def systemP(st: State, kind: str): State =
    if (kind == "compacting") setStatus(st, "compacting")
    else if (kind == "requesting") setStatus(st, "running")
    else if (st.status == "compacting") setStatus(st, "running")
    else st

  // processMessages が例外なしでループを抜けた後 (:2121-2145)。
  // 保留表・入力キュー・userMessageResolve・stopped には触らない。
  pure def naturalEndP(st: State): State =
    setStatus(
      { ...st, queryAlive: false, sdkTurn: false, sdkBacklog: 0, pullPending: false },
      "idle"
    )

  // ---- setPermissionMode (:1618) ----

  pure def removeAt(l: List[Op], i: int): List[Op] =
    l.slice(0, i).concat(l.slice(i + 1, l.length()))

  pure def firstOfChain(st: State, g: int): int =
    if (st.ops.length() > 0 and st.ops[0].gen == g) 0
    else if (st.ops.length() > 1 and st.ops[1].gen == g) 1
    else -1

  pure def writeMode(st: State, op: Op): State = {
    ...st,
    mode: op.mode,
    staleModeWrite: st.staleModeWrite or op.gen < st.gen,
  }

  // 連鎖 g の先頭が順番待ちなら、then コールバックの前半 (:1621-1625 または :1633) を実行する
  pure def drainOnce(st: State, g: int): State = {
    pure val i = firstOfChain(st, g)
    if (i < 0) st
    else {
      pure val op = st.ops[i]
      if (op.q >= 0) st
      else if (not(M3) and op.gen != st.gen) { ...st, ops: removeAt(st.ops, i) }
      else if (st.queryAlive) { ...st, ops: st.ops.replaceAt(i, { ...op, q: st.queryId }) }
      else writeMode({ ...st, ops: removeAt(st.ops, i) }, op)
    }
  }

  // MAX_OPS = 2 なので 2 回で連鎖を進め切る
  pure def drain(st: State, g: int): State = drainOnce(drainOnce(st, g), g)

  pure def setModeP(st: State, m: str): State =
    drain({ ...st, ops: st.ops.append({ mode: m, gen: st.gen, q: -1 }) }, st.gen)

  // await していた SDK 呼び出しが返る (ok) か失敗する (:1626-1633)
  pure def modeReturnP(st: State, i: int, ok: bool): State = {
    pure val op = st.ops[i]
    pure val s1 = { ...st, ops: removeAt(st.ops, i) }
    pure val s2 =
      if (ok and (M3 or op.gen == st.gen) and st.queryAlive and op.q == st.queryId)
        writeMode(s1, op)
      else s1
    drain(s2, op.gen)
  }

  // ---- クライアントの承認系 (:1505-1612) ----

  pure def approveP(st: State, id: str): State =
    if (id.in(st.pending)) resolvePending(st, id) else st

  pure def approveAlwaysP(st: State, id: str): State =
    if (id.in(st.pending))
      resolvePending({ ...st, allowRule: st.allowRule or not(id.in(ASK_IDS)) }, id)
    else st

  pure def answerP(st: State, id: str): State =
    if (id.in(st.pending) and id.in(ASK_IDS)) resolvePending(st, id) else st

  pure def afterStopCheck(before: State, after: State): State =
    if (before.stopped and after != before) { ...after, postStopEffect: true } else after

  pure def lab(st: State, ev: str, arg: str): State =
    if (TRACE_LABELS) { ...st, last: { ev: ev, arg: arg } } else st

  // ================= 初期状態と遷移 =================

  // new SdkProcess() の直後に最初の start() が呼ばれた状態
  action init = s' = {
    status: "starting",
    pending: Set(),
    queueLen: 0,
    headSeq: 0,
    waiter: -1,
    mode: "default",
    gen: 0,
    ops: [],
    stopped: false,
    queryAlive: true,
    queryId: 0,
    allowRule: false,
    sdkPromise: IDS.mapBy(i => "unused"),
    sdkTurn: false,
    sdkBacklog: 0,
    pullPending: true,
    settleCount: IDS.mapBy(i => 0),
    clientStrict: Set(),
    clientApp: Set(),
    requestSeen: Set(),
    resolvedSeen: Set(),
    announcedUnregistered: Set(),
    staleModeWrite: false,
    lostInput: false,
    postStopEffect: false,
    userDecided: Set(),
    last: { ev: "init", arg: "" },
  }

  // SDK がメインスレッドのメッセージを出せるか (processMessages の入口のガード :1926 を含む)
  def anyWaiting = IDS.exists(i => s.sdkPromise.get(i) == "waiting")
  def mainOk = and {
    s.queryAlive,
    not(s.stopped),
    ENV_ANYTIME or s.sdkTurn,
    ENV_MSGS_WHILE_PENDING or not(anyWaiting),
  }

  // ---- SDK からのイベント ----

  // init メッセージ (:2093) または 3 秒のタイマー (:1256)
  action InitDone = all {
    s.queryAlive,
    s.status == "starting",
    s' = lab(setStatus(s, "idle"), "sdk_init_or_timeout", ""),
  }

  action SdkPull = all {
    s.queryAlive,
    not(s.stopped),
    s.pullPending,
    s' = lab(pullP(s), "sdk_pull_input", ""),
  }

  action SdkCanUseTool(id: str, reentrant: bool, preAborted: bool): bool = all {
    s.queryAlive,
    not(s.stopped),
    s.sdkPromise.get(id) == "unused",
    ENV_ANYTIME or ENV_BG or s.sdkTurn,
    reentrant implies ENV_REENTRANT,
    preAborted implies ENV_ABORT,
    s' = lab(
      canUseToolP(s, id, reentrant, preAborted),
      if (reentrant and preAborted) "sdk_canUseTool+listener_approves+signal_already_aborted"
      else if (reentrant) "sdk_canUseTool+listener_approves"
      else if (preAborted) "sdk_canUseTool+signal_already_aborted"
      else "sdk_canUseTool",
      id
    ),
  }

  action SdkAbort(id: str): bool = all {
    ENV_ABORT,
    id.in(s.pending),
    s' = lab(abortP(s, id), "sdk_abort_signal", id),
  }

  action SdkAssistant = all { mainOk, s' = lab(assistantOrUserP(s), "sdk_assistant", "") }
  action SdkUser = all { mainOk, s' = lab(assistantOrUserP(s), "sdk_user", "") }
  action SdkSystem(kind: str): bool = all {
    mainOk,
    s' = lab(systemP(s, kind), "sdk_system_status", kind),
  }
  action SdkResult = all { mainOk, s' = lab(resultP(s), "sdk_result", "") }

  // 異常終了: for await が例外を投げ、catch が stop() を呼ぶ (:1351-1362)
  action SdkError = all {
    s.queryAlive,
    not(s.stopped),
    s' = lab(stopP(s), "sdk_stream_error", ""),
  }

  action SdkNaturalEnd = all {
    ENV_NATURAL_END,
    s.queryAlive,
    not(s.stopped),
    ENV_ANYTIME or not(s.sdkTurn),
    s' = lab(naturalEndP(s), "sdk_stream_end", ""),
  }

  action ModeReturn(i: int, ok: bool): bool = all {
    i < s.ops.length(),
    s.ops[i].q >= 0,
    s' = lab(
      modeReturnP(s, i, ok),
      if (ok) "sdk_setPermissionMode_returns" else "sdk_setPermissionMode_rejects",
      s.ops[i].mode
    ),
  }

  // ---- クライアントからのイベント ----

  action ClientInput = all {
    s.queueLen < MAX_QUEUE,
    ENV_INPUT_AFTER_DEAD or (s.queryAlive and not(s.stopped)),
    s' = lab(inputP(s), "client_input", ""),
  }

  action ClientApprove(id: str): bool = all {
    s.sdkPromise.get(id) != "unused",
    s' = lab(afterStopCheck(s, approveP(s, id)), "client_approve", id),
  }
  action ClientReject(id: str): bool = all {
    s.sdkPromise.get(id) != "unused",
    s' = lab(afterStopCheck(s, approveP(s, id)), "client_reject", id),
  }
  action ClientApproveAlways(id: str): bool = all {
    s.sdkPromise.get(id) != "unused",
    s' = lab(afterStopCheck(s, approveAlwaysP(s, id)), "client_approve_always", id),
  }
  action ClientAnswer(id: str): bool = all {
    s.sdkPromise.get(id) != "unused",
    s' = lab(afterStopCheck(s, answerP(s, id)), "client_answer", id),
  }

  action ClientSetMode(m: str): bool = all {
    s.ops.length() < MAX_OPS,
    s' = lab(setModeP(s, m), "client_set_permission_mode", m),
  }

  // queryInstance が無いときの interrupt() は何もしない (:1414) ので、在るときだけ遷移にする
  action ClientInterrupt = all {
    s.queryAlive,
    s' = lab(interruptP(s), "client_interrupt", ""),
  }

  action ClientStop = all {
    not(s.stopped),
    s' = lab(stopP(s), "client_stop_session", ""),
  }

  action Restart(m: str, withInit: bool): bool = all {
    s.gen < MAX_RESTARTS,
    withInit implies (if (s.queryAlive) true else s.queueLen < MAX_QUEUE),
    s' = lab(
      startP(s, m, withInit),
      if (withInit) "restart_with_initial_input" else "restart",
      m
    ),
  }

  // 上限を使い切った後にデッドロック扱いにならないための足踏み
  action Stutter = s' = s

  action step = any {
    InitDone,
    SdkPull,
    nondet id = IDS.oneOf()
    nondet reentrant = Set(false, true).oneOf()
    nondet preAborted = Set(false, true).oneOf()
    SdkCanUseTool(id, reentrant, preAborted),
    nondet id = IDS.oneOf()
    SdkAbort(id),
    SdkAssistant,
    SdkUser,
    nondet kind = Set("compacting", "requesting", "null").oneOf()
    SdkSystem(kind),
    SdkResult,
    SdkError,
    SdkNaturalEnd,
    nondet i = Set(0, 1).oneOf()
    nondet ok = Set(false, true).oneOf()
    ModeReturn(i, ok),
    ClientInput,
    nondet id = IDS.oneOf()
    any {
      ClientApprove(id),
      ClientReject(id),
      ClientApproveAlways(id),
      ClientAnswer(id),
    },
    nondet m = MODES.oneOf()
    ClientSetMode(m),
    ClientInterrupt,
    ClientStop,
    nondet m = MODES.oneOf()
    nondet withInit = Set(false, true).oneOf()
    Restart(m, withInit),
    Stutter,
  }

  // ================= 性質 (SCOPE.md の意図から) =================

  // P1a: 保留が 1 件でもあれば status は waiting_approval
  val P1a = s.pending != Set() implies s.status == "waiting_approval"
  // P1b: waiting_approval なら保留が 1 件以上
  val P1b = s.status == "waiting_approval" implies s.pending != Set()
  // P2: SDK が待っている約束は保留表に載っている (載っていなければ決着済み)
  val P2 = IDS.forall(i => s.sdkPromise.get(i) == "waiting" implies i.in(s.pending))
  // P3: 1 つの要求の決着 (resolve の呼び出し) は高々 1 回
  val P3 = IDS.forall(i => s.settleCount.get(i) <= 1)
  // P4: permission_request が届いた要求は、決着したら permission_resolved も届く。
  //     配り終えた時点でクライアントの保留集合 (request/resolved から組み立てたもの) は保留表と一致。
  val P4_resolved = IDS.forall(i =>
    (i.in(s.requestSeen) and s.sdkPromise.get(i) == "settled") implies i.in(s.resolvedSeen))
  val P4_view = s.clientStrict == s.pending
  val P4 = P4_resolved and P4_view
  // P4 を「クライアントの承認・拒否・回答で決着した要求」に絞った版 (d6c7e677 が直した範囲)。
  // P4 の代わりではなく、M2 を現行コードと区別して検出できるかを見るために置く。
  val P4_userDecision = IDS.forall(i =>
    (i.in(s.userDecided) and i.in(s.requestSeen)) implies i.in(s.resolvedSeen))
  // P4 の別の読み: Flutter クライアントは status idle/starting でも保留を捨てる。その見え方で一致するか。
  val P4_app = s.clientApp == s.pending
  // 補助 (SCOPE には無い): permission_request が出た時点で要求が保留表に載っている (:2201 のコメントの意図)
  val P4_aux_registered = s.announcedUnregistered == Set()
  // P5: stop の後は保留表と入力キューが空で status は idle。停止後の承認は何も起こさない。
  val P5_state = s.stopped implies (s.pending == Set() and s.queueLen == 0 and s.status == "idle")
  val P5_noEffect = not(s.postStopEffect)
  val P5 = P5_state and P5_noEffect
  // P6: 再開始より前に出したモード変更は、再開始後の permissionMode を書き換えない
  val P6 = not(s.staleModeWrite)
  // P8 の安全性の側面: 入力が使われていない入力ストリームに渡って消えることはない
  val P8_noLostInput = not(s.lostInput)

  // 診断用 (SCOPE には無い): status が running なのに SDK のメインターンが動いていない状態に入らない。
  // ENV_ANYTIME = false の環境でだけ意味がある。P8 の反例 (CE8) を安全性の形で取り出すために置く。
  val D_runningImpliesTurn = (s.queryAlive and s.status == "running") implies s.sdkTurn

  // ---- 活性 ----

  // 「セッションが止まった」: stopped フラグ、または queryInstance が無い (正常終了 :2134 は stopped を立てない)
  def dead = s.stopped or not(s.queryAlive)

  // P7: 保留中の承認要求はいずれ必ず決着する。SDK 側の約束で述べる (M1 を取り逃さないため)。
  temporal P7 = IDS.forall(i =>
    always(s.sdkPromise.get(i) == "waiting" implies eventually(s.sdkPromise.get(i) != "waiting")))
  // 保留表で述べた版
  temporal P7_table = IDS.forall(i =>
    always(i.in(s.pending) implies eventually(not(i.in(s.pending)))))

  // P8: セッションが止まらない限り、キューの先頭の入力はいずれ SDK に渡る
  // (先頭が入れ替わる = headSeq が反転する。FIFO なので各入力について成り立つ)。
  temporal P8 = Set(0, 1).forall(k =>
    always((s.queueLen > 0 and s.headSeq == k and not(dead))
      implies eventually(s.queueLen == 0 or s.headSeq != k or dead)))
  // 「止まった」を stopped フラグだけで読んだ版
  temporal P8_stoppedOnly = Set(0, 1).forall(k =>
    always((s.queueLen > 0 and s.headSeq == k and not(s.stopped))
      implies eventually(s.queueLen == 0 or s.headSeq != k or s.stopped)))

  // ---- 公平性の仮定 ----
  // F_sdk: SDK は (1) 入力ストリームをいずれ読みに来る (2) 進行中のターンをいずれ result で終える
  //        (3) 起動をいずれ終える。いずれも弱公平。
  temporal F_sdk = weakFair(SdkPull, s) and weakFair(SdkResult, s) and weakFair(InitDone, s)
  // F_client: クライアントは「自分に見えている」保留中の要求にいずれ答える (承認か拒否)。
  //           見えている = Flutter の見え方 (clientApp)。答えが空振りする場合は進行と数えない。
  action ClientAnswersVisible(id: str): bool = all {
    id.in(s.clientApp),
    s' = approveP(s, id),
  }
  temporal F_client = IDS.forall(i => weakFair(ClientAnswersVisible(i), s))

  // SDK の公平性だけ (人が答えなければ当然成り立たない。空振りしていないことの確認用)
  temporal P7_sdkFairOnly = F_sdk implies P7
  temporal P7_fair = (F_sdk and F_client) implies P7
  temporal P7_table_fair = (F_sdk and F_client) implies P7_table
  temporal P8_sdkFairOnly = F_sdk implies P8
  temporal P8_fair = (F_sdk and F_client) implies P8
  temporal P8_stoppedOnly_fair = (F_sdk and F_client) implies P8_stoppedOnly

  // ---- 到達できることの確認 (モデルが空回りしていないか) ----
  val W_twoPending = size(s.pending) < 2
  val W_queueFull = s.queueLen < MAX_QUEUE
  val W_modeWritten = s.mode == "default"
  val W_resolvedSeen = s.resolvedSeen == Set()
}
