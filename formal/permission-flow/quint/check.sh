#!/usr/bin/env bash
# Fast check of the permission-flow model. Run from anywhere:
#   bash formal/permission-flow/quint/check.sh
#
# 1. typecheck
# 2. random simulation of every safety property in every instance, compared
#    against expected-violations.tsv (a property listed there must still be
#    violated; every other property must hold)
# 3. traces generated from the model, replayed on the real SdkProcess
#
# After a deliberate change of behaviour: UPDATE=1 bash .../check.sh, then
# review the diff of expected-violations.tsv.
#
# Simulation is sampling, not proof: "holds" here means "no violation in
# $SAMPLES runs". The exhaustive check is run.sh (needs Java).
set -u
cd "$(dirname "$0")" || exit 1

q() { bash ../../quint.sh "$@"; }
F=instances.qnt
EXPECTED=expected-violations.tsv
SAMPLES=${SAMPLES:-20000}
STEPS=25
SEED=1
VITEST=../../../packages/bridge/node_modules/.bin/vitest
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }

# P4_resolved and P4_view are left out on purpose: result, stop and restart end
# requests without permission_resolved, and clients clear them on the status
# change. P4_app states the client view with that rule.
SAFETY="P1a P1b P2 P3 P4_userDecision P4_app P4_aux_registered P5_state P5_noEffect P6 P8_noLostInput"
INSTANCES="cur_U cur_min cur_abort cur_bg cur_msgs cur_bgmsgs cur_end cur_reent cur_reab cur_dead cur_bgend cur_plaus m1_U m1_min m2_U m2_min m3_U m3_min"

# ---- 1. typecheck ----
bash gen-instances.sh > "$TMP/instances.qnt"
cmp -s "$TMP/instances.qnt" $F || fail "$F is stale: bash gen-instances.sh > $F"
q typecheck $F > "$TMP/typecheck.txt" 2>&1 || { cat "$TMP/typecheck.txt"; fail "typecheck"; exit 1; }
echo "typecheck: ok"

# ---- 2. simulation against the expected results ----
sim() { # instance, log, invariant names...
  local inst=$1 log=$2; shift 2
  q run --main "$inst" --invariants "$@" --max-samples "$SAMPLES" --max-steps $STEPS --seed $SEED $F > "$log" 2>&1
}
# UPDATE=1 rewrites the expected results from a fresh simulation of every cell.
# Review the diff: a line that disappears is a fix, a new line is a regression.
if [ -n "${UPDATE:-}" ]; then
  : > "$TMP/expected.tsv"
  for inst in $INSTANCES; do
    rest=$SAFETY
    while [ -n "${rest// /}" ]; do
      # shellcheck disable=SC2086
      sim "$inst" "$TMP/u.txt" $rest
      grep -q '^\[ok\]' "$TMP/u.txt" && break
      # One violating trace names the properties it breaks; drop them and look again.
      broken=$(sed -nE 's/^ *❌ +([A-Za-z0-9_]+).*/\1/p' "$TMP/u.txt" | tr '\n' ' ')
      [ -n "${broken// /}" ] || { echo "simulator error: $inst"; tail -3 "$TMP/u.txt"; exit 1; }
      next=""
      for p in $rest; do
        case " $broken " in *" $p "*) printf '%s\t%s\n' "$inst" "$p" >> "$TMP/expected.tsv" ;; *) next="$next $p" ;; esac
      done
      rest=$next
    done
  done
  sort "$TMP/expected.tsv" > $EXPECTED
  echo "rewrote $EXPECTED ($(wc -l < $EXPECTED | tr -d ' ') expected violations)"
  exit 0
fi

runs=0
for inst in $INSTANCES; do
  known=$(awk -F'\t' -v i="$inst" '$1==i{print $2}' $EXPECTED | tr '\n' ' ')
  holds=""
  for p in $SAFETY; do
    case " $known " in *" $p "*) ;; *) holds="$holds $p" ;; esac
  done
  if [ -n "$holds" ]; then
    # shellcheck disable=SC2086
    sim "$inst" "$TMP/$inst.holds.txt" $holds; runs=$((runs + 1))
    if ! grep -q '^\[ok\]' "$TMP/$inst.holds.txt"; then
      fail "$inst: a property that should hold is violated (or the run failed)"
      grep -E '❌|error' "$TMP/$inst.holds.txt" | head -5
      echo "  reproduce: bash formal/quint.sh run --main $inst --invariants$holds --max-samples $SAMPLES --max-steps $STEPS --seed $SEED formal/permission-flow/quint/$F --verbosity 3"
    fi
  fi
  for p in $known; do
    sim "$inst" "$TMP/$inst.$p.txt" "$p"; runs=$((runs + 1))
    if grep -q '^\[ok\]' "$TMP/$inst.$p.txt"; then
      fail "$inst $p: listed in $EXPECTED but no violation found. If the code was fixed, remove the line."
    elif ! grep -q '^\[violation\]' "$TMP/$inst.$p.txt"; then
      fail "$inst $p: simulator error"; tail -3 "$TMP/$inst.$p.txt"
    fi
  done
done
echo "simulation: $runs runs, $(wc -l < $EXPECTED | tr -d ' ') expected violations"

# ---- 3. replay model traces on the real SdkProcess ----
if [ ! -x "$VITEST" ]; then
  fail "vitest not found: run npm ci in the repository root"
else
  replay() { # instance, trace count -> prints the vitest "Tests" line
    mkdir -p "$TMP/itf-$1"
    q run --main "$1" --invariant true --mbt --n-traces "$2" --max-samples "$2" --max-steps 30 --seed 11 \
      --out-itf "$TMP/itf-$1/t_{seq}.itf.json" $F > "$TMP/gen-$1.txt" 2>&1
    ls "$TMP/itf-$1" | grep -q . || { echo "no traces generated for $1:" >&2; tail -15 "$TMP/gen-$1.txt" >&2; }
    ITF_DIR="$TMP/itf-$1" "$VITEST" run --config repro/vitest.config.mjs > "$TMP/replay-$1.txt" 2>&1
    if ! grep -qE '^ +Tests ' "$TMP/replay-$1.txt"; then
      # vitest did not get as far as running tests: show why.
      tail -25 "$TMP/replay-$1.txt" >&2
    fi
    grep -E '^ +Tests ' "$TMP/replay-$1.txt" | sed -E 's/\x1b\[[0-9;]*m//g; s/^ +Tests +//'
  }
  r=$(replay cur_U 300)
  echo "replay cur_U: ${r:-error}"
  case "$r" in
    "300 passed (300)") ;;
    *) fail "model and SdkProcess disagree: update permflow.qnt or fix the code"
       grep -E '実装=' "$TMP/replay-cur_U.txt" | head -5 ;;
  esac
  # The replay must be able to tell a wrong model from the code.
  for m in m1_U m2_U; do
    r=$(replay $m 100)
    echo "replay $m: ${r:-error}"
    case "$r" in *failed*) ;; *) fail "$m traces all matched the code: the replay lost its sensitivity" ;; esac
  done
fi

[ $FAILED -eq 0 ] && echo "OK" || echo "FAILED"
exit $FAILED
