#!/usr/bin/env bash
# 権限承認フローの Quint 検証を最初から再現する。
#   リポジトリのルートから: bash formal/permission-flow/quint/run.sh [sim|tlc|traces|live|deep|itf|replay|apalache|all]
# 引数なし = all (順に全部。空いた機械で 40 分ほど、うち Apalache の打ち切り待ちが最大 30 分)。急ぐときは段ごとに別の端末で
#   RESUME=1 bash formal/permission-flow/quint/run.sh sim   (tlc, live, ... も同様)
# と並行に回せる。反例が出るとコマンドは非ゼロで終わるので set -e は使わない。
# 生の出力は out/ 以下、1 行ずつの結果は out/summary.tsv に溜まる。
set -u

# Apalache は作業ディレクトリに _apalache-out/ を作るので、このディレクトリの中で動かす
cd "$(dirname "$0")" || exit 1
DIR=.
OUT=out
F=instances.qnt
STAGE=${1:-all}

q() { npx -y @informalsystems/quint@0.34.0 "$@"; }

# RESUME=1 を付けると、ログが残っている検査は飛ばして続きから回す (既定は最初からやり直す)
# (itf / deep / replay は短いので RESUME でも毎回やり直す)
if [ -z "${RESUME:-}" ] || [ "$STAGE" = itf ] || [ "$STAGE" = deep ] || [ "$STAGE" = replay ] || [ "$STAGE" = traces ]; then
  case "$STAGE" in
    all) rm -rf "$OUT" ;;
    *) rm -rf "${OUT:?}/$STAGE"; [ -f "$OUT/summary.tsv" ] && grep -v "^$STAGE	" "$OUT/summary.tsv" > "$OUT/summary.tmp" && mv "$OUT/summary.tmp" "$OUT/summary.tsv" ;;
  esac
fi
mkdir -p "$OUT/sim" "$OUT/tlc" "$OUT/live" "$OUT/apalache" "$OUT/itf" "$OUT/deep" "$OUT/traces"
# 段を並行に回しても読み手が書きかけを見ないよう、中身が変わったときだけ置き換える
bash $DIR/gen-instances.sh > $F.new
if cmp -s $F.new $F; then rm $F.new; else mv $F.new $F; fi
q typecheck $F > "$OUT/typecheck.txt" 2>&1 || { echo "typecheck failed"; cat "$OUT/typecheck.txt"; exit 1; }

SUMMARY=$OUT/summary.tsv
[ -f "$SUMMARY" ] || printf 'stage\tinstance\tproperty\tresult\tdetail\n' > "$SUMMARY"

SAFETY="P1a P1b P2 P3 P4_resolved P4_view P4_userDecision P4_app P4_aux_registered P5_state P5_noEffect P6 P8_noLostInput"
LIVENESS="P7_sdkFairOnly P7_fair P7_table_fair P8_sdkFairOnly P8_fair P8_stoppedOnly_fair"
CUR="cur_U cur_min cur_abort cur_bg cur_msgs cur_bgmsgs cur_end cur_reent cur_reab cur_dead cur_bgend cur_plaus"
MUT="m1_U m1_min m2_U m2_min m3_U m3_min"

# quint verify --backend tlc を回してログに取る。TLA+ への変換 (Apalache サーバー経由) が
# 混雑時にまれに "error: error" で落ちるので、判定が取れなければ 1 回だけやり直す。
tlc_run() { # ログ 残りは quint verify の引数
  local log=$1; shift
  q verify "$@" 2>&1 | grep -v 'protobuf' > "$log"
  if ! grep -qE '^\[(ok|violation)\]' "$log"; then
    q verify "$@" 2>&1 | grep -v 'protobuf' > "$log"
  fi
}

verdict() { # ログから ok / violation / error を取り出す
  if grep -q '^\[ok\]' "$1"; then echo ok
  elif grep -q '^\[violation\]' "$1"; then echo violation
  else echo error; fi
}

record() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$SUMMARY"; echo "$1 $2 $3: $4 ($5)"; }

# ---- 1. ランダムシミュレーション (quint run): ID 3 個、20000 サンプル x 25 ステップ、種は固定 ----
SIM_SAMPLES=20000
SIM_STEPS=25
sim() {
  local log=$OUT/sim/$1.$2.txt
  [ -n "${RESUME:-}" ] && [ -s "$log" ] && return
  q run --main "$1" --invariant "$2" --max-samples $SIM_SAMPLES --max-steps $SIM_STEPS --seed 1 $F > "$log" 2>&1
  local v; v=$(verdict "$log")
  local detail="samples<=$SIM_SAMPLES steps<=$SIM_STEPS"
  [ "$v" = violation ] && detail="$detail; trace states=$(grep -c '^\[State' "$log")"
  record sim "$1" "$2" "$v" "$detail"
}

# ---- 2. TLC による全状態探索 (quint verify --backend tlc): ID 2 個の _s インスタンス ----
tlc() {
  local log=$OUT/tlc/$1.$2.txt
  [ -n "${RESUME:-}" ] && [ -s "$log" ] && return
  tlc_run "$log" --backend tlc --main "$1" --invariant "$2" $F
  local v; v=$(verdict "$log")
  local detail
  if [ "$v" = ok ]; then
    detail="exhaustive; $(grep -E 'distinct states found, 0 states left' "$log" | tail -1 | sed -E 's/^([0-9]+) states generated, ([0-9]+) distinct.*/\2 distinct states/'); $(grep -E 'depth of the complete' "$log" | sed -E 's/.*is ([0-9]+)\./depth \1/')"
  else
    detail="trace states=$(grep -cE '^State [0-9]+:' "$log")"
    node tlc-trace.mjs "$log" > "${log%.txt}.trace.txt" 2>&1
  fi
  record tlc "$1" "$2" "$v" "$detail"
}

# ---- 3. 活性 (TLC の時相検査) ----
live() {
  local log=$OUT/live/$1.$2.txt
  [ -n "${RESUME:-}" ] && [ -s "$log" ] && return
  tlc_run "$log" --backend tlc --main "$1" --temporal "$2" $F
  local v; v=$(verdict "$log")
  local detail
  if [ "$v" = ok ]; then
    detail="exhaustive; $(grep -E 'distinct states found, 0 states left' "$log" | tail -1 | sed -E 's/^([0-9]+) states generated, ([0-9]+) distinct.*/\2 distinct states/')"
  else
    detail="lasso; trace states=$(grep -cE '^State [0-9]+:' "$log"); $(grep -E '^Back to state|Stuttering' "$log" | tail -1 | sed -E 's/^State [0-9]+: //')"
    node tlc-trace.mjs "$log" > "${log%.txt}.trace.txt" 2>&1
  fi
  record live "$1" "$2" "$v" "$detail"
}

# ---- 4. Apalache による有界モデル検査 (quint verify の既定バックエンド): ID 3 個、APA_STEPS ステップまで ----
# この仕様では 1 ステップに数分かかる (NOTES.md 8 章)。代表の 2 件だけ、1 件 APA_TIMEOUT 秒で打ち切る。
APA_STEPS=${APA_STEPS:-4}
APA_TIMEOUT=${APA_TIMEOUT:-900}
apa() {
  local log=$OUT/apalache/$1.$2.txt
  [ -n "${RESUME:-}" ] && [ -s "$log" ] && return
  local t0=$SECONDS
  q verify --main "$1" --invariant "$2" --max-steps "$APA_STEPS" $F > "$log.raw" 2>&1 &
  local pid=$!
  while kill -0 $pid 2> /dev/null && [ $((SECONDS - t0)) -lt "$APA_TIMEOUT" ]; do sleep 5; done
  local v
  if kill -0 $pid 2> /dev/null; then
    pkill -f "quint verify --main $1 --invariant $2 --max-steps" # 止めると Quint が起動した Apalache サーバーも終わる
    pkill -f '\.quint/apalache-dist.*apalache\.jar'             # 念のため (Apalache を使うのは Quint だけ)
    wait $pid 2> /dev/null
    v=timeout
  else
    wait $pid 2> /dev/null
  fi
  grep -v 'protobuf' "$log.raw" > "$log"; rm -f "$log.raw"
  [ -z "${v:-}" ] && v=$(verdict "$log")
  local detail="steps<=$APA_STEPS; $((SECONDS - t0))s"
  [ "$v" = violation ] && detail="$detail; trace states=$(grep -c '^\[State' "$log")"
  [ "$v" = timeout ] && detail="$detail; stopped after APA_TIMEOUT=${APA_TIMEOUT}s"
  record apalache "$1" "$2" "$v" "$detail"
}

# ---- 5. ITF トレース (シミュレーター。--out-itf はコンソール出力を消すので別に回す) ----
# TLC バックエンドは ITF を書かない。短い反例にするためステップ数を絞る。
itf_sim() { # インスタンス 性質 最大ステップ 名前
  q run --main "$1" --invariant "$2" --max-samples 200000 --max-steps "$3" --seed 1 \
    --mbt --out-itf "$OUT/itf/$4.itf.json" $F > "$OUT/itf/$4.log" 2>&1
  if [ -s "$OUT/itf/$4.itf.json" ]; then
    node trace-summary.mjs "$OUT/itf/$4.itf.json" > "$OUT/itf/$4.summary.txt" 2>&1
    record itf "$1" "$2" violation "steps<=$3; $OUT/itf/$4.itf.json"
  else
    record itf "$1" "$2" none "steps<=$3; no trace"
  fi
}

if [ "$STAGE" = sim ] || [ "$STAGE" = all ]; then
  for m in $CUR $MUT; do for p in $SAFETY; do sim "$m" "$p"; done; done
fi

# TLC の全探索は 1 回 10 秒〜数分かかるので、全部の組を 1 つずつは回さない:
#   - シミュレーターが反例を出した組は TLC では調べ直さない (skipped と記録)
#   - 残り (シミュレーターが何も見つけなかった性質) をインスタンスごとにまとめて 1 回の全探索にかける。
#     まとめた検査が反例を出したら (TLC はどの不変条件かを言わないので) 1 つずつ回し直す。
#     ここで violation になった組が「シミュレーターだけでは見つからなかった反例」。
tlc_group() { # インスタンス名 (接尾辞なし)
  local base=$1 m=${1}_s props="" p
  for p in $SAFETY; do
    if grep -q "^sim	$base	$p	violation" "$SUMMARY"; then
      record tlc "$m" "$p" skipped "simulator already found a counterexample"
    else
      props="$props $p"
    fi
  done
  [ -z "$props" ] && return
  local log=$OUT/tlc/$m.group.txt
  # shellcheck disable=SC2086
  tlc_run "$log" $F --backend tlc --main "$m" --invariants $props
  if [ "$(verdict "$log")" = ok ]; then
    local detail
    detail="exhaustive (checked together:$props); $(grep -E 'distinct states found, 0 states left' "$log" | tail -1 | sed -E 's/^([0-9]+) states generated, ([0-9]+) distinct.*/\2 distinct states/'); $(grep -E 'depth of the complete' "$log" | sed -E 's/.*is ([0-9]+)\./depth \1/')"
    for p in $props; do record tlc "$m" "$p" ok "$detail"; done
  else
    for p in $props; do tlc "$m" "$p"; done
  fi
}

if [ "$STAGE" = tlc ] || [ "$STAGE" = all ]; then
  for m in $CUR $MUT; do tlc_group "$m"; done
fi

# ---- 2b. NOTES.md に載せる反例の、TLC による短いトレース (out/traces/*.trace.txt) ----
trace() {
  local log=$OUT/traces/$1.$2.txt
  tlc_run "$log" --backend tlc --main "$1" --invariant "$2" $F
  node tlc-trace.mjs "$log" > "${log%.txt}.trace.txt" 2>&1
  record traces "$1" "$2" "$(verdict "$log")" "trace states=$(grep -cE '^State [0-9]+:' "$log")"
}
if [ "$STAGE" = traces ] || [ "$STAGE" = all ]; then
  trace cur_min_s   P1b
  trace cur_min_s   P4_view
  trace cur_min_s   P4_app
  trace cur_abort_s P1b
  trace cur_abort_s P4_app
  trace cur_msgs_s  P1a
  trace cur_bg_s    P1b
  trace cur_bgend_s P1a
  trace cur_end_s   P8_noLostInput
  trace cur_dead_s  P5_state
  trace cur_reab_s  P3
  trace cur_plaus_s P1a
  trace cur_bg_s    D_runningImpliesTurn
  trace m1_min_s    P2
  trace m2_min_s    P4_userDecision
  trace m2_min_s    P4_aux_registered
  trace m2_min_s    P4_resolved
  trace m3_min_s    P6
fi

if [ "$STAGE" = live ] || [ "$STAGE" = all ]; then
  for m in cur_min cur_bg cur_bgend cur_plaus cur_U m1_min; do
    for p in $LIVENESS; do live "${m}_s" "$p"; done
  done
  for m in cur_abort cur_msgs cur_end m2_min m3_min; do
    for p in P7_fair P8_fair; do live "${m}_s" "$p"; done
  done
fi

if [ "$STAGE" = itf ] || [ "$STAGE" = all ]; then
  itf_sim cur_min   P1b            5 cur_min.P1b.interrupt
  itf_sim cur_abort P4_app         5 cur_abort.P4_app.abort
  itf_sim cur_msgs  P1a            5 cur_msgs.P1a.system-status
  itf_sim cur_end   P8_noLostInput 6 cur_end.P8_noLostInput.restart-after-end
  itf_sim cur_dead  P5_state       4 cur_dead.P5_state.input-after-error
  itf_sim cur_bgend P1a            3 cur_bgend.P1a.stream-end-with-pending
  itf_sim cur_reab  P3             4 cur_reab.P3.double-resolve
  itf_sim cur_bg    P1b            4 cur_bg.P1b
  itf_sim cur_bg    D_runningImpliesTurn 5 cur_bg.D_runningImpliesTurn.approve-outside-turn
  itf_sim m1_min    P2             5 m1_min.P2
  itf_sim m2_min    P4_userDecision 6 m2_min.P4_userDecision
  itf_sim m3_min    P6             7 m3_min.P6
fi

# ---- 6. ID 3 個での全状態探索 (ラベルなし)。成り立つはずの不変条件をまとめて 1 回 ----
if [ "$STAGE" = deep ] || [ "$STAGE" = all ]; then
  mkdir -p "$OUT/deep"
  log=$OUT/deep/cur_U_3.holding.txt
  DEEP="P2 P4_userDecision P4_aux_registered P5_noEffect P6"
  # shellcheck disable=SC2086
  tlc_run "$log" $F --backend tlc --main cur_U_3 --invariants $DEEP
  v=$(verdict "$log")
  record deep cur_U_3 "$DEEP" "$v" "exhaustive; $(grep -E 'distinct states found, 0 states left' "$log" | tail -1 | sed -E 's/^([0-9]+) states generated, ([0-9]+) distinct.*/\2 distinct states/'); $(grep -E 'depth of the complete' "$log" | sed -E 's/.*is ([0-9]+)\./depth \1/')"
fi

# ---- 7. モデルのトレースを本物の SdkProcess で再生 ----
if [ "$STAGE" = replay ] || [ "$STAGE" = all ]; then
  bash replay.sh
fi

if [ "$STAGE" = apalache ] || [ "$STAGE" = all ]; then
  apa cur_min P1b
  apa m1_min  P2
fi

rm -rf _apalache-out
node results.mjs > "$OUT/results.md"
echo "done: $OUT/summary.tsv $OUT/results.md"
