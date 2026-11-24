#!/usr/bin/env bash
# Reproduces the whole FSL evaluation of the permission approval flow.
#
#   bash formal/permission-flow/fsl/run.sh            # everything except the long mutation run
#   bash formal/permission-flow/fsl/run.sh mutate summary   # full mutation run (1-2 h, longer on a busy machine)
#   bash formal/permission-flow/fsl/run.sh current seeded   # only the named sections
#
# Sections: gen current proof attribution fixall seeded liveness env testgen sketch mutate summary
# No `set -e`: exit code 1 (property violated) is an expected result; every run
# records its own exit code. Raw verifier output goes to out/.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
export FSLC="${FSLC:-$HERE/../../.tools/fsl/fslc-macos-arm64}"
export FSLC_CACHE=off   # no reads/writes of the persistent verdict cache (~/.cache/fslc)
BASE=permission_flow.fsl
DEPTH="${DEPTH:-10}"          # bounded depth for safety properties
LIVE_DEPTH="${LIVE_DEPTH:-8}" # bounded depth for leadsTo (lasso search)
MUTATE_DEPTH="${MUTATE_DEPTH:-4}" # bounded depth for mutation analysis
ALL_FIXES="H_STATUS_GUARD H_ABORT_NOTIFY H_ABORT_ONCE H_INTERRUPT_NOTIFY H_DENYALL_NOTIFY H_STOPPED_INPUT H_STREAM_END_CLEANUP"
# Properties violated by the current-code model (removed only in the copy used
# where the tool needs a passing spec: induction, mutate, scenarios, testgen).
VIOLATED="P1a_PendingImpliesWaiting P1b_WaitingImpliesPending P3_SettledAtMostOnce P4a_ResolvedReachesClient P4b_ClientViewMatchesTable P5b_StoppedQueueEmpty P8_QueuedInputDelivered"
FIX_ONLY_LEMMAS="Fix_ViewMatchesOutsideAnnouncement Fix_StatusTracksTable"
SAFETY_VIOLATED="P1a_PendingImpliesWaiting,P1b_WaitingImpliesPending,P3_SettledAtMostOnce,P4a_ResolvedReachesClient,P4b_ClientViewMatchesTable,P5b_StoppedQueueEmpty"

if [ "$#" -eq 0 ]; then
  SECTIONS="gen current proof attribution fixall seeded liveness env testgen sketch summary"
else
  SECTIONS="gen $*"
fi
want() { case " $SECTIONS " in *" $1 "*) return 0;; *) return 1;; esac; }

props() { # props SPEC OUTDIR [extra run_props args]
  local spec=$1 out=$2; shift 2
  mkdir -p "$out"
  python3 tools/run_props.py "$spec" "$out" --depth "$DEPTH" --live-depth "$LIVE_DEPTH" "$@" > "$out/summary.txt" 2>&1
}

verify_raw() { # verify_raw OUTFILE fslc-args...
  local out=$1; shift
  "$FSLC" "$@" > "$out" 2> "$out.stderr"
  echo "exit=$?" > "$out.exit"
}

# ---------------------------------------------------------------- gen
if want gen; then
  mkdir -p variants out
  "$FSLC" version > out/fslc-version.json 2>&1
  python3 tools/strip_props.py $BASE variants/current_holding.fsl $VIOLATED $FIX_ONLY_LEMMAS
  python3 tools/mkvariant.py $BASE variants/fix_all.fsl $ALL_FIXES
  for skip in $ALL_FIXES; do
    rest=""; for h in $ALL_FIXES; do [ "$h" != "$skip" ] && rest="$rest $h"; done
    python3 tools/mkvariant.py $BASE "variants/fix_all_but_$skip.fsl" $rest
  done
  python3 tools/mkvariant.py $BASE variants/fix_only_H_STREAM_END_CLEANUP.fsl H_STREAM_END_CLEANUP
  python3 tools/make_mutants.py $BASE variants
  python3 tools/make_mutants.py variants/fix_all.fsl variants _on_fix_all
  python3 tools/mkvariant.py $BASE variants/env_prompt_out_of_turn.fsl E_PROMPT_OUT_OF_TURN
  python3 tools/mkvariant.py $BASE variants/env_prompt_after_stop.fsl E_PROMPT_AFTER_STOP
  python3 tools/mkvariant.py $BASE variants/env_prompt_out_of_turn_on_fix_all.fsl E_PROMPT_OUT_OF_TURN $ALL_FIXES
  python3 tools/mkvariant.py $BASE variants/env_prompt_after_stop_on_fix_all.fsl E_PROMPT_AFTER_STOP $ALL_FIXES
  # fairness ablations: drop `fair` from one action at a time
  for a in sdk_pull sdk_result client_approve; do
    sed "s/^  fair action $a(/  action $a(/" variants/fix_all.fsl > "variants/fix_all_nofair_$a.fsl"
    sed "s/^  fair action $a(/  action $a(/" $BASE > "variants/current_nofair_$a.fsl"
  done
  # ranked (unbounded) liveness attempt for P7
  python3 tools/make_ranked.py variants/current_holding.fsl variants/current_ranked_p7.fsl
  python3 tools/make_midsession.py variants/current_holding.fsl variants/current_holding_midsession.fsl
  mkdir -p out/diffs
  for v in m1 m2 m3; do diff -u $BASE variants/$v.fsl > out/diffs/$v.diff; done
  diff -u $BASE variants/fix_all.fsl > out/diffs/fix_all.diff
  diff -u $BASE variants/current_holding.fsl > out/diffs/current_holding.diff
  for f in $BASE variants/*.fsl; do
    "$FSLC" check "$f" > "out/check.$(basename "$f" .fsl).json" 2>&1 || echo "check failed: $f"
  done
  "$FSLC" lint $BASE > out/lint.json 2>&1
  "$FSLC" check $BASE --strict-tags > out/check.strict-tags.json 2>&1
fi

# ---------------------------------------------------------------- current code model
if want current; then
  # every property on its own (verify stops at the first violated property)
  props $BASE out/current
  # the unfiltered run, as the tool is meant to be used (reports the first violation only)
  verify_raw out/current/unfiltered.bmc.json verify $BASE --depth "$DEPTH" --no-cache
fi

# ---------------------------------------------------------------- unbounded proofs
if want proof; then
  mkdir -p out/proof
  # properties that hold in the current-code model: k-induction (leadsTo cannot be selected for induction)
  verify_raw out/proof/current_holding.induction.json verify variants/current_holding.fsl --engine induction --depth 8 --exclude-property P7_PendingEventuallySettled --no-cache
  # same spec, explicit-state engine with the default budget (does it close the state space?)
  verify_raw out/proof/current_holding.explicit.json verify variants/current_holding.fsl --engine explicit --depth 60 --exclude-property P7_PendingEventuallySettled --no-cache
  # induction on one selected property without the auxiliary invariants as hypotheses (expected: unknown_cti)
  verify_raw out/proof/current.P2_alone.induction.json verify $BASE --engine induction --depth 6 --property P2_AwaitedIsTracked --no-cache
  # model with all hypothetical fixes: every safety property
  verify_raw out/proof/fix_all.induction.json verify variants/fix_all.fsl --engine induction --depth 8 --exclude-property P7_PendingEventuallySettled --exclude-property P8_QueuedInputDelivered --no-cache
fi

# ---------------------------------------------------------------- which code path causes which violation
if want attribution; then
  for skip in $ALL_FIXES; do
    props "variants/fix_all_but_$skip.fsl" "out/attribution/all_but_$skip" --only "$SAFETY_VIOLATED" &
  done
  wait
fi

# ---------------------------------------------------------------- all hypothetical fixes on
if want fixall; then
  props variants/fix_all.fsl out/fix_all
  verify_raw out/fix_all/unfiltered.bmc.json verify variants/fix_all.fsl --depth 8 --no-cache
fi

# ---------------------------------------------------------------- seeded regressions M1-M3
if want seeded; then
  for v in m1 m2 m3 m1_on_fix_all m2_on_fix_all m3_on_fix_all; do
    props variants/$v.fsl out/seeded/$v &
  done
  wait
fi

# ---------------------------------------------------------------- liveness
if want liveness; then
  LIVE="P7_PendingEventuallySettled,P8_QueuedInputDelivered"
  props variants/fix_only_H_STREAM_END_CLEANUP.fsl out/liveness/fix_only_stream_end --only "$LIVE" &
  for a in sdk_pull sdk_result client_approve; do
    props "variants/fix_all_nofair_$a.fsl" "out/liveness/fix_all_nofair_$a" --only "$LIVE" &
    props "variants/current_nofair_$a.fsl" "out/liveness/current_nofair_$a" --only P7_PendingEventuallySettled &
  done
  wait
  # deeper lasso search for P7 (cheap) on the current-code model
  mkdir -p out/liveness/deeper
  verify_raw out/liveness/deeper/current.P7.depth12.json verify $BASE --depth 12 --property P7_PendingEventuallySettled --no-cache
  verify_raw out/liveness/deeper/fix_all.P8.depth10.json verify variants/fix_all.fsl --depth 10 --property P8_QueuedInputDelivered --no-cache
  # ranked response: unbounded proof attempt of P7 by induction (helpful + decreases)
  verify_raw out/liveness/current_ranked_p7.induction.json verify variants/current_ranked_p7.fsl --engine induction --depth 8 --no-cache
fi

# ---------------------------------------------------------------- environment relaxations (outside ASSUME-2)
if want env; then
  for v in env_prompt_out_of_turn env_prompt_after_stop env_prompt_out_of_turn_on_fix_all env_prompt_after_stop_on_fix_all; do
    props variants/$v.fsl out/env/$v &
  done
  wait
fi

# ---------------------------------------------------------------- spec -> implementation link
if want testgen; then
  mkdir -p out/testgen
  verify_raw out/testgen/scenarios.current_holding.json scenarios variants/current_holding.fsl --depth 6
  # testgen first verifies the spec, then bakes a 100-step random walk; slow (10+ min)
  "$FSLC" testgen variants/current_holding.fsl --depth 6 --target vitest -o out/testgen/PermissionFlow.conformance.test.ts > out/testgen/testgen.vitest.json 2> out/testgen/testgen.vitest.stderr
  echo "exit=$?" > out/testgen/testgen.vitest.exit
fi

# ---------------------------------------------------------------- counterexamples replayed on the real class
if want sketch; then
  # Uses the Bridge's own vitest; sketch/node_modules is a symlink to packages/bridge/node_modules.
  # Expected: the CE-* tests FAIL (counterexample reproduced), the control tests pass.
  mkdir -p out/sketch
  ln -sfn ../../../../packages/bridge/node_modules sketch/node_modules
  ( cd "$HERE/../../.." && packages/bridge/node_modules/.bin/vitest run --root formal/permission-flow/fsl/sketch ) > out/sketch/vitest-run.txt 2>&1
  echo "exit=$?" > out/sketch/vitest-run.exit
fi

# ---------------------------------------------------------------- mutation analysis (long)
if want mutate; then
  # 892 mutants. On the spec as written a mutant of the permission actions is
  # only reachable from step 5 on, and depth 5-6 costs 4+ hours, so the run uses
  # the copy whose init is the reachable mid-session state (tools/make_midsession.py).
  mkdir -p out/mutate
  "$FSLC" mutate variants/current_holding_midsession.fsl --depth "$MUTATE_DEPTH" --max-mutants 2000 --by-requirement > "out/mutate/current_holding_midsession.depth$MUTATE_DEPTH.json" 2> "out/mutate/current_holding_midsession.depth$MUTATE_DEPTH.progress.txt"
  echo "exit=$?" >> "out/mutate/current_holding_midsession.depth$MUTATE_DEPTH.progress.txt"
  shasum -a 256 $BASE variants/current_holding.fsl variants/current_holding_midsession.fsl > out/mutate/spec.sha256
fi

# ---------------------------------------------------------------- summary
if want summary; then
  python3 tools/summarize.py out > out/SUMMARY.txt 2>&1
  cat out/SUMMARY.txt
fi
