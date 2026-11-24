#!/usr/bin/env python3
"""Run `fslc verify --property P` for every property of a spec, save the raw
JSON per property and print a one-line verdict (plus the trace) for each.
usage: run_props.py SPEC.fsl OUTDIR [--depth N] [--engine E] [--only P,P] [--live-depth N] [--quiet]"""
import json, os, re, subprocess, sys, time

FSLC = os.environ.get("FSLC") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".tools", "fsl", "fslc-macos-arm64")

def args():
    a = sys.argv[1:]
    opt = {"depth": "10", "engine": "bmc", "only": None, "live-depth": "8", "quiet": False}
    pos = []
    i = 0
    while i < len(a):
        if a[i] == "--quiet":
            opt["quiet"] = True
        elif a[i].startswith("--"):
            opt[a[i][2:]] = a[i + 1]; i += 1
        else:
            pos.append(a[i])
        i += 1
    return pos[0], pos[1], opt

def props(spec):
    src = open(spec).read()
    return re.findall(r"^\s*(invariant|leadsTo|trans|reachable)\s+(\w+)", src, re.M)

def fmt_trace(d):
    lines = []
    for st in d.get("trace", []):
        a = st.get("action")
        if not a:
            continue
        ps = ",".join("%s=%s" % kv for kv in sorted(a["params"].items()))
        lines.append("      %2d %s(%s)" % (st["step"], a["name"], ps))
    for k in ("loop_start", "stall", "pending_since"):
        if k in d:
            lines.append("      %s=%s" % (k, d[k]))
    return "\n".join(lines)

def main():
    spec, outdir, opt = args()
    os.makedirs(outdir, exist_ok=True)
    only = opt["only"].split(",") if opt["only"] else None
    rows = []
    for kind, name in props(spec):
        if only and name not in only:
            continue
        depth = opt["live-depth"] if kind == "leadsTo" else opt["depth"]
        engine = "bmc" if kind == "leadsTo" else opt["engine"]
        cmd = [FSLC, "verify", spec, "--engine", engine, "--depth", depth, "--property", name, "--no-cache"]
        t0 = time.time()
        r = subprocess.run(cmd, capture_output=True, text=True)
        dt = time.time() - t0
        path = os.path.join(outdir, "%s.%s.json" % (name, engine))
        open(path, "w").write(r.stdout)
        try:
            d = json.loads(r.stdout)
        except Exception:
            d = {"result": "unparseable"}
        res = d.get("result")
        extra = ""
        if res == "violated":
            # with --property the verifier still reports a violated `ensures`
            # (named after its action) or type bound instead of the selected property
            what = d.get("invariant")
            extra = " %s%s at step %s" % (d.get("violation_kind"), "" if what == name else " of " + str(what), d.get("violated_at_step"))
        elif res == "error":
            extra = " " + str(d.get("message"))[:160]
        elif res == "unknown_cti":
            extra = " invariant=%s" % d.get("invariant")
        print("%-34s %-11s exit=%d engine=%s depth=%s %s%s (%.1fs)" % (name, res, r.returncode, engine, d.get("checked_to_depth", depth), d.get("completeness", ""), extra, dt))
        if res == "violated" and not opt["quiet"]:
            print(fmt_trace(d))
        rows.append((name, res))
    return 0

if __name__ == "__main__":
    sys.exit(main())
