#!/usr/bin/env python3
"""Variant with a ranked (helpful + decreases) form of P7, to try an unbounded
liveness proof with `fslc verify --engine induction`.
usage: make_ranked.py HOLDING.fsl OUT.fsl"""
import sys
src = open(sys.argv[1]).read()
old = """  leadsTo P7_PendingEventuallySettled {
    forall t: Tool { prom[t] == Awaiting ~> prom[t] == Settled }
  }"""
new = """  leadsTo P7_PendingEventuallySettled {
    forall t: Tool { prom[t] == Awaiting ~> prom[t] == Settled }
    helpful client_approve(t)
    decreases (if prom[t] == Awaiting then 1 else 0)
  }"""
assert src.count(old) == 1
open(sys.argv[2], "w").write(src.replace(old, new))
