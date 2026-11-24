#!/usr/bin/env bash
# モデルのトレースを本物の SdkProcess (SDK の query だけ差し替え) で再生して突き合わせる。
# run.sh の最後に呼ばれる。単独でも: bash formal/permission-flow/quint/replay.sh
# packages/ には何も書かない (vitest は packages/bridge に入っているものを借りる)。
set -u

cd "$(dirname "$0")" || exit 1
ROOT=../../..
OUT=out/replay
SUMMARY=out/summary.tsv
VITEST=$ROOT/packages/bridge/node_modules/.bin/vitest
q() { npx -y @informalsystems/quint@0.34.0 "$@"; }

rm -rf "$OUT"
mkdir -p "$OUT"
[ -f "$SUMMARY" ] || printf 'stage\tinstance\tproperty\tresult\tdetail\n' > "$SUMMARY"
grep -v "^replay	" "$SUMMARY" > "$SUMMARY.tmp" && mv "$SUMMARY.tmp" "$SUMMARY"
TMP=$(mktemp -d)

replay_dir() { # 名前 ITF のディレクトリ 説明
  local log=$OUT/$1.txt
  ITF_DIR="$2" "$VITEST" run --config repro/vitest.config.mjs > "$log" 2>&1
  local tests; tests=$(grep -E '^ +Tests ' "$log" | sed -E 's/^ +Tests +//; s/\x1b\[[0-9;]*m//g')
  printf 'replay\t%s\t-\t%s\t%s\n' "$1" "${tests:-error}" "$3" >> "$SUMMARY"
  echo "replay $1: ${tests:-error} ($3)"
}

# 1. ランダムなトレース。現行コードのモデルは全部一致するはず、退行のモデルは食い違うはず。
random_traces() { # インスタンス 本数
  mkdir -p "$TMP/$1"
  q run --main "$1" --invariant true --mbt --n-traces "$2" --max-samples "$2" --max-steps 30 --seed 11 \
    --out-itf "$TMP/$1/t_{seq}.itf.json" instances.qnt > /dev/null 2>&1
  replay_dir "random.$1" "$TMP/$1" "$2 traces x 30 steps, seed 11"
}
random_traces cur_U 500
random_traces m1_U 100
random_traces m2_U 100
random_traces m3_U 100

# 2. out/itf に保存した反例。現行コードの反例は実装でも同じ状態になる (= 通る) はず。
if ls out/itf/cur_*.itf.json > /dev/null 2>&1; then
  mkdir -p "$TMP/ce_cur" "$TMP/ce_mut"
  cp out/itf/cur_*.itf.json "$TMP/ce_cur/"
  cp out/itf/m[123]_*.itf.json "$TMP/ce_mut/" 2> /dev/null
  replay_dir counterexamples.current "$TMP/ce_cur" "out/itf/cur_*: 通れば実装でも再現"
  replay_dir counterexamples.mutants "$TMP/ce_mut" "out/itf/m*: 食い違えば実装は退行していない"
fi

rm -rf "$TMP" repro/.cache
