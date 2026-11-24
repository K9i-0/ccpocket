#!/usr/bin/env bash
# instances.qnt を生成する。定数の組み合わせが多いので手書きしない。
# 使い方: bash formal/permission-flow/quint/gen-instances.sh > formal/permission-flow/quint/instances.qnt
set -u

# 名前 M1 M2 M3 ANYTIME MSGS_WHILE_PENDING BG ABORT NATURAL_END REENTRANT INPUT_AFTER_DEAD
ROWS=(
  # 現行コード
  "cur_U     false false false true  true  true  true  true  true  true"   # 制約なしの SDK
  "cur_min   false false false false false false false false false false"  # いちばん行儀のよい SDK
  "cur_abort false false false false false false true  false false false"
  "cur_bg    false false false false false true  false false false false"
  "cur_msgs  false false false false true  false false false false false"
  "cur_bgmsgs false false false false true true  false false false false"
  "cur_end   false false false false false false false true  false false"
  "cur_reent false false false false false false false false true  false"
  "cur_reab  false false false false false false true  false true  false"
  "cur_dead  false false false false false false false false false true"
  "cur_bgend false false false false false true  false true  false false"
  "cur_plaus false false false false true  true  true  false true  true"   # ありそうな SDK (下の NOTES 参照)
  # 退行
  "m1_U      true  false false true  true  true  true  true  true  true"
  "m1_min    true  false false false false false false false false false"
  "m2_U      false true  false true  true  true  true  true  true  true"
  "m2_min    false true  false false false false false false false false"
  "m3_U      false false true  true  true  true  true  true  true  true"
  "m3_min    false false true  false false false false false false false"
)

# 大きさの違い: 接尾辞なし = ID 3 個・再開始 1 回・ラベルあり (反例探し用)
#               _s        = ID 2 個・再開始 1 回・ラベルなし (TLC の全探索・活性用)
#               _3        = ID 3 個・再開始 1 回・ラベルなし (TLC の深い全探索用)
emit() {
  local name=$1 m1=$2 m2=$3 m3=$4 any=$5 msgs=$6 bg=$7 abort=$8 nat=$9 re=${10} dead=${11}
  local suffix=${12} ids=${13} ask=${14} restarts=${15} labels=${16}
  cat <<EOF
module ${name}${suffix} {
  import permflow(
    M1 = ${m1}, M2 = ${m2}, M3 = ${m3},
    ENV_ANYTIME = ${any}, ENV_MSGS_WHILE_PENDING = ${msgs}, ENV_BG = ${bg},
    ENV_ABORT = ${abort}, ENV_NATURAL_END = ${nat}, ENV_REENTRANT = ${re},
    ENV_INPUT_AFTER_DEAD = ${dead},
    IDS = ${ids}, ASK_IDS = ${ask}, MAX_RESTARTS = ${restarts}, TRACE_LABELS = ${labels}
  ).* from "./permflow"
}

EOF
}

echo "// -*- mode: Bluespec; -*-"
echo "// gen-instances.sh が生成したファイル。直接編集しない。"
echo
for row in "${ROWS[@]}"; do
  # shellcheck disable=SC2086
  set -- $row
  emit "$@" ""   'Set("a", "b", "q")' 'Set("q")' 1 true
  emit "$@" "_s" 'Set("a", "q")'      'Set("q")' 1 false
  emit "$@" "_3" 'Set("a", "b", "q")' 'Set("q")' 1 false
done
