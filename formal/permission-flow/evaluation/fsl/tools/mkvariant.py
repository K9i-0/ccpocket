#!/usr/bin/env python3
"""Generate a spec variant by flipping H_* (hypothetical fix) or E_* (environment) switches to 1.
usage: mkvariant.py BASE.fsl OUT.fsl H_NAME [H_NAME ...]"""
import re, sys
base, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
s = open(base).read()
for n in names:
    s, k = re.subn(r"(const %s = )0\b" % re.escape(n), r"\g<1>1", s)
    if k != 1:
        sys.exit("switch %s not found exactly once" % n)
open(out, "w").write(s)
