--------------------------- MODULE PermissionFlow ---------------------------
(***************************************************************************)
(* Model of the permission approval flow of SdkProcess                     *)
(* (packages/bridge/src/sdk-process.ts).  Written from the code; the       *)
(* properties P1a..P8 come from formal/permission-flow/SCOPE.md.           *)
(*                                                                         *)
(* One action = one synchronous handler run (one JS macrotask plus the     *)
(* microtasks it triggers).  The only handler that is split is             *)
(* waitForPermission, because a synchronous "message" listener can call    *)
(* back into the class while permission_request is being emitted.          *)
(*                                                                         *)
(* Line numbers in comments refer to sdk-process.ts unless noted.          *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Ids,          \* tool-use ids; each id is used by the SDK at most once
    Modes,        \* permission modes
    InitMode,     \* mode at the first start
    MaxQueue,     \* bound on pendingInputQueue
    MaxChain,     \* bound on queued setPermissionMode calls per chain
    NONE,         \* model value: "no id"
    M1, M2, M3,   \* seeded regressions (SCOPE.md)
    Disabled,     \* environment behaviours switched off (set of strings)
    ClientGated   \* extra experiment: client answers only while it sees waiting_approval

VARIABLES
    \* ---- SdkProcess fields -------------------------------------------
    status,       \* _status                                   (:1025)
    pending,      \* keys of pendingPermissions                (:1027)
    query,        \* "live" iff queryInstance !== null         (:1024)
    stopped,      \* stopped                                   (:1048)
    qlen,         \* pendingInputQueue.length                  (:1050)
    resolver,     \* userMessageResolve: "none" | "cur" (belongs to the generator of
                  \* the live query) | "stale" (belongs to a generator nobody reads)
    mode,         \* _permissionMode                           (:1028)
    chain,        \* permissionModeUpdates of the current generation (:1030)
    old,          \* updates issued before the last start() (generation is stale)
    \* ---- waitForPermission in progress (:2191-2226) -------------------
    announcing,   \* id whose permission_request is being emitted, or NONE
    annAborted,   \* the signal was already aborted on entry   (:2214)
    annDeferred,  \* pending.resolutionEventsPending is set    (:2264)
    \* ---- SDK side ----------------------------------------------------
    prom,         \* canUseTool promise per id: "unused" | "waiting" | "settled"
    calls,        \* number of resolve() calls on that promise (capped at 2)
    gstate,       \* createUserMessageStream of the live query: "ready" (SDK may
                  \* pull) | "waiting" (parked on userMessageResolve) | "done"
    sdkTurn,      \* "active" while the CLI is inside a turn
    \* ---- client side -------------------------------------------------
    chan,         \* permission_request / permission_resolved events in flight
    cview,        \* pending set the client has built from those events
    destroyed,    \* SessionManager.destroy() ran: no client message reaches the process
    \* ---- ghosts (history only, never read by the model of the code) ---
    silent,       \* ids removed from the table without permission_resolved
    staleWrote,   \* a pre-restart mode change wrote _permissionMode after the restart
    lost,         \* an input was handed to a generator nobody reads
    tick          \* flips each time a queued input reaches the SDK, and each time
                  \* stop() runs (also inside a restart of a live query)

vars == << status, pending, query, stopped, qlen, resolver, mode, chain, old,
           announcing, annAborted, annDeferred, prom, calls, gstate, sdkTurn,
           chan, cview, destroyed, silent, staleWrote, lost, tick >>

On(key) == key \notin Disabled

InTurn(s) == s \in {"running", "compacting", "waiting_approval"}   \* isTurnActive (:1129)

Inc(n) == IF n < 2 THEN n + 1 ELSE 2

Update == [mode : Modes, phase : {"queued", "awaiting"}, qchg : BOOLEAN]

TypeOK ==
    /\ status \in {"starting", "idle", "running", "waiting_approval", "compacting"}
    /\ pending \subseteq Ids
    /\ query \in {"none", "live"}
    /\ stopped \in BOOLEAN
    /\ qlen \in 0..MaxQueue
    /\ resolver \in {"none", "cur", "stale"}
    /\ mode \in Modes
    /\ chain \in Seq(Update) /\ Len(chain) <= MaxChain
    /\ old \in Seq(Update) /\ Len(old) <= MaxChain
    /\ announcing \in Ids \cup {NONE}
    /\ annAborted \in BOOLEAN /\ annDeferred \in BOOLEAN
    /\ prom \in [Ids -> {"unused", "waiting", "settled"}]
    /\ calls \in [Ids -> 0..2]
    /\ gstate \in {"ready", "waiting", "done"}
    /\ sdkTurn \in {"idle", "active"}
    /\ chan \in Seq({"req", "res"} \X Ids)
    /\ cview \subseteq Ids
    /\ destroyed \in BOOLEAN
    /\ silent \subseteq Ids
    /\ staleWrote \in BOOLEAN /\ lost \in BOOLEAN
    /\ tick \in {0, 1}

Init ==
    \* State right after the first start(): status "starting" (:1220), query created (:1265).
    /\ status = "starting" /\ pending = {} /\ query = "live" /\ stopped = FALSE
    /\ qlen = 0 /\ resolver = "none" /\ mode = InitMode
    /\ chain = << >> /\ old = << >>
    /\ announcing = NONE /\ annAborted = FALSE /\ annDeferred = FALSE
    /\ prom = [i \in Ids |-> "unused"] /\ calls = [i \in Ids |-> 0]
    /\ gstate = "ready" /\ sdkTurn = "idle"
    /\ chan = << >> /\ cview = {} /\ destroyed = FALSE
    /\ silent = {} /\ staleWrote = FALSE /\ lost = FALSE /\ tick = 0

-----------------------------------------------------------------------------
(* Helpers *)

\* denyAllPendingPermissions (:2235-2242).  M1: clear the table only.
DenyProm  == IF M1 THEN prom
             ELSE [i \in Ids |-> IF i \in pending THEN "settled" ELSE prom[i]]
DenyCalls == IF M1 THEN calls
             ELSE [i \in Ids |-> IF i \in pending THEN Inc(calls[i]) ELSE calls[i]]

SettleProm(id)  == [prom EXCEPT ![id] = "settled"]
SettleCalls(id) == [calls EXCEPT ![id] = Inc(calls[id])]

\* queryInstance changed: every update that is awaiting the SDK sees
\* "queryInstance !== this.queryInstance" afterwards (:1628).
MarkQ(us) == [i \in DOMAIN us |-> [us[i] EXCEPT !.qchg = TRUE]]

\* Run the head of an update chain as far as microtasks take it (:1620-1640).
\* stale = the generation captured at :1619 differs from the current one.
\* Result: remaining chain, _permissionMode, staleWrote.
RECURSIVE Drain(_, _, _, _)
Drain(us, stale, md, bad) ==
    IF us = << >> THEN [u |-> us, m |-> md, bad |-> bad]
    ELSE LET h == Head(us) IN
         IF h.phase = "awaiting" THEN [u |-> us, m |-> md, bad |-> bad]
         ELSE IF stale /\ ~M3                       \* :1621 (M3 removes it)
              THEN Drain(Tail(us), stale, md, bad)
         ELSE IF query = "live"                     \* :1623-1625 await SDK
              THEN [u |-> << [h EXCEPT !.phase = "awaiting", !.qchg = FALSE] >> \o Tail(us),
                    m |-> md, bad |-> bad]
         ELSE Drain(Tail(us), stale, h.mode, bad \/ stale)   \* :1633 no query: write

Quiet == announcing = NONE          \* no handler is in the middle of waitForPermission
ClientCan == Quiet /\ ~destroyed

-----------------------------------------------------------------------------
(* Client -> Bridge *)

\* dispatchInput (:1445-1461) followed by the websocket layer's interrupt
\* (websocket/handlers/session-input.ts:423-451).
Input ==
    /\ ClientCan
    /\ On("inputWhenDead") \/ query = "live"
    /\ LET shouldInt == status \in {"running", "compacting"}
           mustQ     == shouldInt \/ status = "waiting_approval"
       IN IF mustQ \/ resolver = "none"
          THEN /\ qlen < MaxQueue
               /\ qlen' = qlen + 1
               /\ IF shouldInt /\ query = "live"        \* interrupt() (:1414-1422)
                  THEN /\ pending' = {} /\ prom' = DenyProm /\ calls' = DenyCalls
                       /\ silent' = silent \cup pending
                  ELSE UNCHANGED << pending, prom, calls, silent >>
               /\ UNCHANGED << status, resolver, gstate, sdkTurn, lost >>
          ELSE \* resolveUserMessage (:2739-2749)
               /\ resolver' = "none"
               /\ status' = "running"
               /\ IF resolver = "cur"
                  THEN gstate' = "ready" /\ sdkTurn' = "active" /\ lost' = lost
                  ELSE UNCHANGED << gstate, sdkTurn >> /\ lost' = TRUE  \* stale resolver: nobody reads it
               /\ UNCHANGED << qlen, pending, prom, calls, silent >>
    /\ UNCHANGED << query, stopped, mode, chain, old, announcing, annAborted,
                    annDeferred, chan, cview, destroyed, staleWrote, tick >>

\* interrupt (:1403-1423), background-task branch not modelled.
Interrupt ==
    /\ ClientCan /\ On("interrupt")
    /\ query = "live"
    /\ pending # {}                                   \* otherwise a no-op
    /\ pending' = {} /\ prom' = DenyProm /\ calls' = DenyCalls
    /\ silent' = silent \cup pending
    /\ UNCHANGED << status, query, stopped, qlen, resolver, mode, chain, old,
                    announcing, annAborted, annDeferred, gstate, sdkTurn, chan,
                    cview, destroyed, staleWrote, lost, tick >>

\* resolvePendingPermission (:2244-2268) as reached from approve / approveAlways /
\* reject / answer (:1505-1612).  The four differ only in the payload.
ResolveEffects(id) ==
    /\ pending' = pending \ {id}
    /\ prom' = SettleProm(id) /\ calls' = SettleCalls(id)
    /\ status' = IF pending \ {id} = {} THEN "running" ELSE status      \* :2254
    /\ IF M2 THEN UNCHANGED << chan, annDeferred >>                      \* no permission_resolved
       ELSE IF announcing = id
            THEN annDeferred' = TRUE /\ chan' = chan                     \* :2263
            ELSE chan' = Append(chan, << "res", id >>) /\ annDeferred' = annDeferred

Decide(id) ==
    /\ ClientCan
    /\ id \in pending                                 \* otherwise returns false, no effect
    /\ ResolveEffects(id)
    /\ UNCHANGED << query, stopped, qlen, resolver, mode, chain, old, announcing,
                    annAborted, gstate, sdkTurn, cview, destroyed, silent,
                    staleWrote, lost, tick >>

ClientSees(id) == id \in cview /\ (ClientGated => status = "waiting_approval")
DecideSeen(id)  == ClientSees(id) /\ Decide(id)       \* the client answers a request it shows
DecideBlind(id) == ~ClientSees(id) /\ Decide(id)      \* stale / racing answers

\* A synchronous "message" listener answers while permission_request is being
\* emitted (sdk-process.test.ts:2844).
ReentrantDecide ==
    /\ On("reentrant")
    /\ announcing # NONE /\ announcing \in pending
    /\ ResolveEffects(announcing)
    /\ UNCHANGED << query, stopped, qlen, resolver, mode, chain, old, announcing,
                    annAborted, gstate, sdkTurn, cview, destroyed, silent,
                    staleWrote, lost, tick >>

\* setPermissionMode (:1618-1643): the call itself.
SetMode(m) ==
    /\ ClientCan
    /\ Len(chain) < MaxChain
    /\ LET r == Drain(Append(chain, [mode |-> m, phase |-> "queued", qchg |-> FALSE]),
                      FALSE, mode, staleWrote)
       IN chain' = r.u /\ mode' = r.m /\ staleWrote' = r.bad
    /\ UNCHANGED << status, pending, query, stopped, qlen, resolver, old, announcing,
                    annAborted, annDeferred, prom, calls, gstate, sdkTurn, chan,
                    cview, destroyed, silent, lost, tick >>

\* queryInstance.setPermissionMode() settles (:1625) and the code after the await runs.
\* Not a client action: it also runs after the session was destroyed.
ModeReturn(isOld, ok) ==
    /\ Quiet
    /\ LET us == IF isOld THEN old ELSE chain IN
       /\ us # << >> /\ Head(us).phase = "awaiting"
       /\ LET h      == Head(us)
              \* :1626-1631.  M3 removes the generation half, the identity half stays.
              writes == ok /\ ~h.qchg /\ (~isOld \/ M3)
              r      == Drain(Tail(us), isOld,
                              IF writes THEN h.mode ELSE mode,
                              staleWrote \/ (writes /\ isOld))
          IN /\ mode' = r.m /\ staleWrote' = r.bad
             /\ IF isOld THEN old' = r.u /\ chain' = chain
                         ELSE chain' = r.u /\ old' = old
    /\ UNCHANGED << status, pending, query, stopped, qlen, resolver, announcing,
                    annAborted, annDeferred, prom, calls, gstate, sdkTurn, chan,
                    cview, destroyed, silent, lost, tick >>

\* stop() (:1368-1401).
StopEffects ==
    /\ stopped' = TRUE
    /\ qlen' = 0
    /\ query' = "none"
    /\ pending' = {} /\ prom' = DenyProm /\ calls' = DenyCalls
    /\ silent' = silent \cup pending
    /\ resolver' = "none"
    /\ status' = "idle"
    /\ gstate' = "done" /\ sdkTurn' = "idle"
    /\ chain' = MarkQ(chain) /\ old' = MarkQ(old)
    /\ tick' = 1 - tick

\* stop_session -> SessionManager.destroy (session.ts:2675-2692).
ClientStop ==
    /\ ClientCan /\ On("stop")
    /\ StopEffects
    /\ destroyed' = TRUE
    /\ UNCHANGED << mode, announcing, annAborted, annDeferred, chan, cview,
                    staleWrote, lost >>

\* start() called again on the same object (:1176-1246), e.g. session.ts:2387.
\* opt = "keep": no permissionMode option (:1201).
Start(opt) ==
    /\ ClientCan /\ On("restart")
    /\ old = << >>                                    \* bound: one stale generation at a time
    /\ stopped' = FALSE                                                   \* :1191
    /\ tick' = IF query = "live" THEN 1 - tick ELSE tick                 \* stop() at :1178
    /\ qlen' = IF query = "live" THEN 0 ELSE qlen                         \* only stop() clears it
    /\ resolver' = IF query = "live" THEN "none"                          \* stop() :1386
                   ELSE IF resolver = "none" THEN "none" ELSE "stale"     \* start() leaves it
    /\ pending' = {} /\ prom' = DenyProm /\ calls' = DenyCalls            \* :1198
    /\ silent' = silent \cup pending
    /\ old' = MarkQ(chain) /\ chain' = << >>                              \* :1199-1200
    /\ mode' = IF opt = "keep" THEN mode ELSE opt                         \* :1201
    /\ status' = "starting"                                               \* :1220
    /\ query' = "live" /\ gstate' = "ready" /\ sdkTurn' = "idle"          \* :1265
    /\ UNCHANGED << announcing, annAborted, annDeferred, chan, cview, destroyed,
                    staleWrote, lost >>

-----------------------------------------------------------------------------
(* SDK -> Bridge *)

\* The SDK pulls the next prompt from createUserMessageStream (:1803-1837).
SdkPull ==
    /\ Quiet /\ query = "live" /\ gstate = "ready"
    /\ IF qlen > 0 /\ ~InTurn(status)
       THEN /\ qlen' = qlen - 1 /\ status' = "running"                    \* :1824-1829
            /\ sdkTurn' = "active" /\ tick' = 1 - tick
            /\ UNCHANGED << resolver, gstate >>
       ELSE /\ resolver' = "cur" /\ gstate' = "waiting"                   \* :1831-1833
            /\ UNCHANGED << qlen, status, sdkTurn, tick >>
    /\ UNCHANGED << pending, query, stopped, mode, chain, old, announcing,
                    annAborted, annDeferred, prom, calls, chan, cview, destroyed,
                    silent, staleWrote, lost >>

\* system/init or the 3 s init timeout (:1256-1262, :2093).
InitDone ==
    /\ Quiet /\ query = "live" /\ status = "starting"
    /\ status' = "idle"
    /\ UNCHANGED << pending, query, stopped, qlen, resolver, mode, chain, old,
                    announcing, annAborted, annDeferred, prom, calls, gstate,
                    sdkTurn, chan, cview, destroyed, silent, staleWrote, lost, tick >>

\* assistant / user frame of the main agent (:2681-2691).
Frame ==
    /\ Quiet /\ query = "live"
    /\ sdkTurn = "active" \/ On("bgFrame")
    /\ pending = {} /\ status # "running"             \* otherwise no change
    /\ status' = "running"
    /\ UNCHANGED << pending, query, stopped, qlen, resolver, mode, chain, old,
                    announcing, annAborted, annDeferred, prom, calls, gstate,
                    sdkTurn, chan, cview, destroyed, silent, staleWrote, lost, tick >>

\* system status frame (:2668-2679): no pendingPermissions guard in the code.
SysStatus(s) ==
    /\ Quiet /\ query = "live" /\ sdkTurn = "active"
    /\ pending = {} \/ On("statusWhilePending")
    /\ \/ s = "compacting" /\ status' = "compacting"
       \/ s = "requesting" /\ status' = "running"
       \/ s = "null" /\ status = "compacting" /\ status' = "running"
    /\ UNCHANGED << pending, query, stopped, qlen, resolver, mode, chain, old,
                    announcing, annAborted, annDeferred, prom, calls, gstate,
                    sdkTurn, chan, cview, destroyed, silent, staleWrote, lost, tick >>

\* system status frame carrying permissionMode (:2100-2115).
SdkMode(m) ==
    /\ Quiet /\ query = "live" /\ On("sdkMode")
    /\ m # mode /\ mode' = m
    /\ UNCHANGED << status, pending, query, stopped, qlen, resolver, chain, old,
                    announcing, annAborted, annDeferred, prom, calls, gstate,
                    sdkTurn, chan, cview, destroyed, silent, staleWrote, lost, tick >>

\* result (:2692-2699) including deliverQueuedInputIfWaiting (:2729-2737).
Result ==
    /\ Quiet /\ query = "live" /\ sdkTurn = "active"
    /\ pending' = {} /\ prom' = DenyProm /\ calls' = DenyCalls
    /\ silent' = silent \cup pending
    /\ IF resolver # "none" /\ qlen > 0
       THEN /\ resolver' = "none" /\ qlen' = qlen - 1 /\ status' = "running"
            /\ IF resolver = "cur"
               THEN gstate' = "ready" /\ sdkTurn' = "active" /\ tick' = 1 - tick /\ lost' = lost
               ELSE gstate' = gstate /\ sdkTurn' = "idle" /\ tick' = tick /\ lost' = TRUE
       ELSE /\ status' = "idle" /\ sdkTurn' = "idle"
            /\ UNCHANGED << resolver, qlen, gstate, tick, lost >>
    /\ UNCHANGED << query, stopped, mode, chain, old, announcing, annAborted,
                    annDeferred, chan, cview, destroyed, staleWrote >>

\* canUseTool -> waitForPermission, first half (:2191-2207).
\* M2 (pre-d6c7e677): permission_request is emitted before anything is registered.
CanUseBegin(id, pre) ==
    /\ Quiet /\ prom[id] = "unused"
    /\ \/ query = "live" /\ (sdkTurn = "active" \/ On("bgTool"))
       \/ query = "none" /\ On("lateCanUse")
    /\ pre => On("preAbort")
    /\ announcing' = id /\ annAborted' = pre /\ annDeferred' = FALSE
    /\ chan' = Append(chan, << "req", id >>)
    /\ IF M2 THEN UNCHANGED << pending, prom, status >>
       ELSE /\ pending' = pending \cup {id}                               \* :2198
            /\ prom' = [prom EXCEPT ![id] = "waiting"]
            /\ status' = "waiting_approval"                               \* :2199
    /\ UNCHANGED << query, stopped, qlen, resolver, mode, chain, old, calls,
                    gstate, sdkTurn, cview, destroyed, silent, staleWrote, lost, tick >>

\* waitForPermission, second half (:2208-2226).
CanUseEnd ==
    /\ announcing # NONE
    /\ LET id == announcing IN
       /\ announcing' = NONE /\ annAborted' = FALSE /\ annDeferred' = FALSE
       /\ chan' = IF annDeferred THEN Append(chan, << "res", id >>) ELSE chan   \* :2209-2211
       /\ status' = IF M2 THEN "waiting_approval" ELSE status
       /\ IF annAborted                                                   \* :2214-2218
          THEN /\ pending' = pending \ {id}
               /\ prom' = SettleProm(id) /\ calls' = SettleCalls(id)
               /\ silent' = IF id \in pending \/ M2 THEN silent \cup {id} ELSE silent
          ELSE IF M2
               THEN /\ pending' = pending \cup {id}
                    /\ prom' = [prom EXCEPT ![id] = "waiting"]
                    /\ UNCHANGED << calls, silent >>
               ELSE UNCHANGED << pending, prom, calls, silent >>
    /\ UNCHANGED << query, stopped, qlen, resolver, mode, chain, old, gstate,
                    sdkTurn, cview, destroyed, staleWrote, lost, tick >>

\* The abort signal of a waiting canUseTool fires (:2220-2225).
Abort(id) ==
    /\ Quiet /\ On("abort")
    /\ prom[id] = "waiting" /\ id \in pending         \* has() false: nothing happens
    /\ pending' = pending \ {id}
    /\ prom' = SettleProm(id) /\ calls' = SettleCalls(id)
    /\ silent' = silent \cup {id}
    /\ UNCHANGED << status, query, stopped, qlen, resolver, mode, chain, old,
                    announcing, annAborted, annDeferred, gstate, sdkTurn, chan,
                    cview, destroyed, staleWrote, lost, tick >>

\* The message iterator ends without an error (:2121-2145).
NaturalEnd ==
    /\ Quiet /\ query = "live" /\ On("naturalEnd")
    /\ query' = "none" /\ status' = "idle"
    /\ gstate' = "done" /\ sdkTurn' = "idle"
    /\ resolver' = IF resolver = "none" THEN "none" ELSE "stale"   \* not cleared
    /\ chain' = MarkQ(chain) /\ old' = MarkQ(old)
    /\ UNCHANGED << pending, stopped, qlen, mode, announcing, annAborted,
                    annDeferred, prom, calls, chan, cview, destroyed, silent,
                    staleWrote, lost, tick >>

\* The message iterator throws (:1351-1361): stop() then "exit".  The session
\* stays in SessionManager (session.ts:1080-1093), so the client can still reach it.
Crash ==
    /\ Quiet /\ query = "live" /\ On("crash")
    /\ StopEffects
    /\ UNCHANGED << mode, announcing, annAborted, annDeferred, chan, cview,
                    destroyed, staleWrote, lost >>

-----------------------------------------------------------------------------
(* Bridge -> client *)

ClientRecv ==
    /\ chan # << >>
    /\ LET e == Head(chan) IN
       cview' = IF e[1] = "req" THEN cview \cup {e[2]} ELSE cview \ {e[2]}
    /\ chan' = Tail(chan)
    /\ UNCHANGED << status, pending, query, stopped, qlen, resolver, mode, chain,
                    old, announcing, annAborted, annDeferred, prom, calls, gstate,
                    sdkTurn, destroyed, silent, staleWrote, lost, tick >>

\* After destroy nothing is left to do once everything has drained; keep TLC's
\* deadlock check meaningful for every other state.
Terminated == destroyed /\ UNCHANGED vars

Next ==
    \/ Input \/ Interrupt \/ ClientStop
    \/ \E id \in Ids : DecideSeen(id) \/ DecideBlind(id)
    \/ ReentrantDecide
    \/ \E m \in Modes : SetMode(m)
    \/ \E b1 \in BOOLEAN, b2 \in BOOLEAN : ModeReturn(b1, b2)
    \/ \E o \in Modes \cup {"keep"} : Start(o)
    \/ SdkPull \/ InitDone \/ Frame \/ Result
    \/ \E s \in {"compacting", "requesting", "null"} : SysStatus(s)
    \/ \E m \in Modes : SdkMode(m)
    \/ \E id \in Ids, pre \in BOOLEAN : CanUseBegin(id, pre)
    \/ CanUseEnd
    \/ \E id \in Ids : Abort(id)
    \/ NaturalEnd \/ Crash
    \/ ClientRecv
    \/ Terminated

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Fairness.  Each conjunct is named so that configurations can drop one. *)

FairHandler == WF_vars(CanUseEnd)                 \* a synchronous function returns
FairRecv    == WF_vars(ClientRecv)                \* events reach the client
FairDecide  == \A id \in Ids : WF_vars(DecideSeen(id))  \* the client answers what it shows
FairPull    == WF_vars(SdkPull)                   \* the SDK keeps reading the prompt stream
FairResult  == WF_vars(Result)                    \* an active turn ends with a result

FairSpec        == Spec /\ FairHandler /\ FairRecv /\ FairDecide /\ FairPull /\ FairResult
P7Spec          == Spec /\ FairHandler /\ FairRecv /\ FairDecide
P7NoHandler     == Spec /\ FairRecv /\ FairDecide
P7NoRecv        == Spec /\ FairHandler /\ FairDecide
P7NoDecide      == Spec /\ FairHandler /\ FairRecv
P7WeakExists    == Spec /\ FairHandler /\ FairRecv /\ WF_vars(\E id \in Ids : DecideSeen(id))
P8Spec          == Spec /\ FairHandler /\ FairPull /\ FairResult
P8NoPull        == Spec /\ FairHandler /\ FairResult
P8NoResult      == Spec /\ FairHandler /\ FairPull
P8NoHandler     == Spec /\ FairPull /\ FairResult

-----------------------------------------------------------------------------
(* Properties from SCOPE.md *)

P1a == Quiet => (pending # {} => status = "waiting_approval")
P1b == Quiet => (status = "waiting_approval" => pending # {})

P2  == \A id \in Ids : prom[id] = "waiting" => id \in pending

P3  == \A id \in Ids : calls[id] <= 1

\* Literal P4: once every event is delivered the client's set equals the table.
P4  == (Quiet /\ chan = << >>) => cview = pending

\* Narrower variant (added by me, see NOTES.md): the client may still show
\* requests that the Bridge dropped silently (denyAll / abort paths), nothing else.
P4n == (Quiet /\ chan = << >>) => /\ pending \subseteq cview
                                  /\ (cview \ pending) \subseteq silent

P5  == stopped => (pending = {} /\ qlen = 0 /\ status = "idle")

P6  == ~staleWrote

P7  == \A id \in Ids : (prom[id] = "waiting") ~> (prom[id] = "settled")

Ended == stopped \/ query = "none"
\* "Whenever the queue is non-empty and the session is not stopped, eventually
\* a queued input reaches the SDK, or stop() runs."  With a FIFO queue of bounded
\* length this gives delivery of every queued input.  (tick flips on both events.)
P8  == \A b \in {0, 1} : (qlen > 0 /\ tick = b /\ ~Ended) ~> (tick # b \/ Ended)

(* Extra properties (not in SCOPE.md; added while modelling) *)
E1  == query = "none" => status = "idle"     \* a process without a query is idle
E2  == ~lost                                  \* no input goes to a generator nobody reads

(* Reachability probes: these are expected to FAIL (non-vacuity). *)
ProbeTwoPending == Cardinality(pending) < 2
ProbeChain2     == Len(chain) < 2
ProbeOldChain2  == Len(old) < 2
ProbeQueue2     == qlen < 2
ProbeStaleRes   == resolver # "stale"

\* Used only with TLC -simulate to harvest random behaviours for the replay
\* against the real class (see run.sh): "violated" once every id has been used
\* and settled and a restart generation is behind us.
ProbeSim == ~(/\ \A id \in Ids : prom[id] = "settled"
              /\ Quiet /\ chan = << >>)
=============================================================================
