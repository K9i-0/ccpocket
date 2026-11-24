#!/usr/bin/env python3
"""Seeded regressions M1-M3 of SCOPE.md as spec variants.
usage: make_mutants.py BASE.fsl OUTDIR [SUFFIX]
Writes OUTDIR/m1SUFFIX.fsl, m2SUFFIX.fsl, m3SUFFIX.fsl. Every replacement is
asserted, so a drifted base spec fails loudly instead of yielding a no-op variant."""
import sys

base, outdir = sys.argv[1], sys.argv[2]
suffix = sys.argv[3] if len(sys.argv) > 3 else ""
src = open(base).read()

def rep(s, old, new, n=1):
    assert s.count(old) == n, (s.count(old), old)
    return s.replace(old, new)

def header(s, text):
    return rep(s, "spec PermissionFlow {", "// SEEDED REGRESSION %s\nspec PermissionFlow {" % text)

# ---- M1: interrupt / stop / result / restart only clear the table (pre-ce064bf0) ----
m1 = src
deny8 = """    forall t: Tool {
      if pend.contains(t) {
        prom[t] = Settled
        settles[t] = settles[t] + 1
        if H_DENYALL_NOTIFY == 1 { clientSees[t] = false }
      }
    }
    pend = Set {}"""
m1 = rep(m1, deny8, """    // M1: table cleared, SDK promises left unsettled
    forall t: Tool {
      if pend.contains(t) {
        if H_DENYALL_NOTIFY == 1 { clientSees[t] = false }
      }
    }
    pend = Set {}""", 6)   # start, start_with_initial_input, stop, sdk_error_exit, sdk_result, sdk_result_while_awaiting
m1 = rep(m1, """    forall t: Tool {
      if pend.contains(t) {
        prom[t] = Settled
        settles[t] = settles[t] + 1
        if H_INTERRUPT_NOTIFY == 1 { clientSees[t] = false }
      }
    }
    pend = Set {}                                       // SRC: 1421; status untouched""",
"""    // M1: table cleared, SDK promises left unsettled
    forall t: Tool {
      if pend.contains(t) {
        if H_INTERRUPT_NOTIFY == 1 { clientSees[t] = false }
      }
    }
    pend = Set {}                                       // SRC: 1421; status untouched""")
m1 = rep(m1, """        forall t: Tool {
          if pend.contains(t) {
            prom[t] = Settled
            settles[t] = settles[t] + 1
            if H_INTERRUPT_NOTIFY == 1 { clientSees[t] = false }
          }
        }
        pend = Set {}""", """        // M1: table cleared, SDK promises left unsettled
        forall t: Tool {
          if pend.contains(t) {
            if H_INTERRUPT_NOTIFY == 1 { clientSees[t] = false }
          }
        }
        pend = Set {}""")
m1 = header(m1, "M1: interrupt/stop/result/restart clear the pending table without settling the SDK promises (undoes ce064bf0)")

# ---- M2: permission_request emitted before registration, no permission_resolved (pre-d6c7e677) ----
m2 = src
m2 = rep(m2, """    prom[t] = Awaiting
    askTool[t] = ask
    pend = pend.add(t)                                  // SRC: 2198
    status = WaitingApproval                            // SRC: 2199
    announcing = some(t)                                // SRC: 2196, emit starts at 2202
    deferredResolved = false
    annAborted = preAborted
  }""", """    prom[t] = Awaiting
    askTool[t] = ask
    // M2: permission_request is emitted first; registration and the status change
    // happen only after the listeners returned (see announce_finish)
    clientSees[t] = true
    announcing = some(t)
    deferredResolved = false
    annAborted = preAborted
  }""")
m2 = rep(m2, """    if deferredResolved or (annAborted and H_ABORT_NOTIFY == 1) {
      clientSees[t] = false
    } else {
      clientSees[t] = true
    }
    // SRC: 2214-2217 signal already aborted: delete + resolve(deny) unconditionally,
    // nothing emitted, status untouched
    if annAborted and (H_ABORT_ONCE == 0 or pend.contains(t)) {
      pend = pend.remove(t)
      prom[t] = Settled
      settles[t] = settles[t] + 1
      if H_ABORT_NOTIFY == 1 and pend.contains(t) and pend.remove(t).size() == 0 { status = Running }
    }""", """    // M2: registration after the emit (old order: emit, setStatus, pendingPermissions.set)
    status = WaitingApproval
    if annAborted {
      prom[t] = Settled
      settles[t] = settles[t] + 1
      if H_ABORT_NOTIFY == 1 { clientSees[t] = false }
    } else {
      pend = pend.add(t)
    }""")
# no permission_resolved when a request is answered
m2 = rep(m2, """      clientSees[t] = false                 // SRC: 2258, 2266 permission_resolved
""", """      // M2: no permission_resolved
""")
m2 = rep(m2, """      if pend.remove(t).size() == 0 { status = Running }
      clientSees[t] = false
    }""", """      if pend.remove(t).size() == 0 { status = Running }
      // M2: no permission_resolved
    }""", 3)   # client_reject, client_approve_always, client_answer
m2 = header(m2, "M2: permission_request is sent before the request is registered and no permission_resolved is sent when it is answered (undoes d6c7e677)")

# ---- M3: setPermissionMode without the generation checks (lines 1621 and 1627) ----
m3 = src
# line 1627: the write no longer checks the generation (the instance check of 1628 stays)
m3 = rep(m3, """    let writes = not (opStale[s] or opQiChanged[s])              // SRC: 1626-1631 generation + instance check""",
              """    let writes = not opQiChanged[s]                              // M3: generation check of line 1627 removed, 1628 kept""")
# line 1621: a chained update starts even when it was issued before a restart
m3 = rep(m3, """    let nextRuns = chainedNext and not opStale[1 - s]            // SRC: 1621 generation check""",
              """    let nextRuns = chainedNext                                   // M3: generation check of line 1621 removed""", 2)
m3 = header(m3, "M3: setPermissionMode() without the generation checks at sdk-process.ts:1621 and :1627")

for name, text in (("m1", m1), ("m2", m2), ("m3", m3)):
    open("%s/%s%s.fsl" % (outdir, name, suffix), "w").write(text)
