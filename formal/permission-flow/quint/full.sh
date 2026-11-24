#!/usr/bin/env bash
# Exhaustive check of the permission-flow model with TLC. Run by hand before
# and after a change to the flow; it takes several minutes and needs Java.
#   bash formal/permission-flow/quint/full.sh
#
# Unlike check.sh this explores every reachable state of the small instances
# (2 tool-call ids, 1 restart) and checks the liveness properties.
# Do not run two copies at once: Quint's TLA+ export uses a fixed local port.
set -u
cd "$(dirname "$0")" || exit 1
command -v java > /dev/null || { echo "Java is required for the TLC backend."; exit 1; }

q() { bash ../../quint.sh "$@"; }
F=instances.qnt
OUT=out/full
rm -rf "$OUT"; mkdir -p "$OUT"
FAILED=0

SAFETY="P1a P1b P2 P3 P4_userDecision P4_app P4_aux_registered P5_state P5_noEffect P6 P8_noLostInput"
CUR="cur_U cur_min cur_abort cur_bg cur_msgs cur_bgmsgs cur_end cur_reent cur_reab cur_dead cur_bgend cur_plaus"

verify() { # log, quint verify arguments...
  local log=$1; shift
  q verify $F --backend tlc "$@" 2>&1 | grep -v protobuf > "$log"
  # The export to TLA+ occasionally fails under load; one retry.
  grep -qE '^\[(ok|violation)\]' "$log" || q verify $F --backend tlc "$@" 2>&1 | grep -v protobuf > "$log"
  if grep -q '^\[ok\]' "$log"; then echo ok
  elif grep -q '^\[violation\]' "$log"; then echo violation
  else echo error; fi
}
expect() { # label, expected, actual, log
  local states; states=$(grep -E 'distinct states found, 0 states left' "$4" | tail -1 | sed -E 's/.* ([0-9]+) distinct.*/\1 states/')
  if [ "$2" = "$3" ]; then echo "ok   $1: $3 ${states}"
  else echo "FAIL $1: expected $2, got $3 (see formal/permission-flow/quint/$4)"; FAILED=1; fi
}

echo "== safety, every reachable state"
for inst in $CUR; do
  # shellcheck disable=SC2086
  r=$(verify "$OUT/$inst.safety.txt" --main "${inst}_s" --invariants $SAFETY)
  expect "$inst safety" ok "$r" "$OUT/$inst.safety.txt"
done

echo "== seeded regressions are still caught"
while read -r inst prop; do
  r=$(verify "$OUT/$inst.$prop.txt" --main "${inst}_s" --invariant "$prop")
  expect "$inst $prop" violation "$r" "$OUT/$inst.$prop.txt"
done <<'LIST'
m1_min P2
m2_min P4_userDecision
m3_min P6
LIST

echo "== liveness (expected results in expected-liveness.tsv)"
while IFS=$'\t' read -r inst prop want _note; do
  case "$inst" in ''|'#'*) continue ;; esac
  r=$(verify "$OUT/$inst.$prop.txt" --main "${inst}_s" --temporal "$prop")
  expect "$inst $prop" "$want" "$r" "$OUT/$inst.$prop.txt"
done < expected-liveness.tsv

[ $FAILED -eq 0 ] && echo "OK" || echo "FAILED"
exit $FAILED
