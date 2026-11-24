---
name: formal-check
description: Claude 用プロセス（sdk-process.ts）の権限承認・状態・入力キュー・権限モードの動作を変えるとき、または Quint モデルの検査が失敗したときに使う。
allowed-tools: Bash(bash formal/:*), Read, Glob, Grep, Edit
---

# 権限承認フローの Quint モデル

`packages/bridge/src/sdk-process.ts` の `SdkProcess` のうち、権限承認、`status`、入力キュー、権限モード変更を [permflow.qnt](../../../formal/permission-flow/quint/permflow.qnt) にモデル化している。性質の一覧と前提は [README](../../../formal/permission-flow/README.md) にある。

モデルの関数は実装のメソッドに1対1で対応する（`inputP` ↔ `dispatchInput`、`resultP` ↔ `result` の処理など）。対応が崩れると検査の意味がなくなるので、上の範囲の動作を変えるときはモデルも同じコミットで変える。

## 検査

```bash
bash formal/permission-flow/quint/check.sh   # 約2分。CI でも走る
bash formal/permission-flow/quint/full.sh    # 全探索と活性。約12分、Java が要る。手元で実行
```

- `check.sh` はランダム実行なので、「成立」は「2万本の試行で反例が出なかった」の意味。全状態を調べるのは `full.sh` だけ。
- `full.sh` は2つ同時に走らせない（Quint の TLA+ 変換が固定ポートを使う）。
- 承認・状態・キューの遷移を変えたら `full.sh` まで流す。文言やログだけの変更なら `check.sh` で足りる。

## 動作を変える手順

1. `permflow.qnt` を意図する動作に直す。性質（`P1a` など）は、意図が変わらない限り触らない。
2. `bash formal/quint.sh run --main cur_U --invariants <性質> ... instances.qnt` か `check.sh` で、性質が成り立つことを確かめる。反例が出たら設計を見直す。
3. `check.sh` の再生が失敗することを確かめる（モデルと実装が食い違っている状態）。
4. 実装を直し、`sdk-process.test.ts` に通常のテストを足す。
5. `check.sh` が通ることを確かめる。期待結果が変わる場合は `UPDATE=1 bash formal/permission-flow/quint/check.sh` で作り直し、`expected-violations.tsv` の差分を読む。行が消えるのは修正、増えるのは退行。

## 失敗の読み方

| 出力 | 意味 | 対処 |
|---|---|---|
| `a property that should hold is violated` | モデルの変更で性質が破れた | 表示された再現コマンドに `--verbosity 3` を付けて反例を読む。各状態の `last` が直前のイベント |
| `listed in expected-violations.tsv but no violation found` | 既知の違反が消えた | 意図した修正なら `UPDATE=1` で一覧を更新する |
| `model and SdkProcess disagree` | モデルと実装の動作が違う | 表示された「実装=… モデル=…」の行で、どのイベントのあと何がずれたかを見る。意図した側に合わせる |
| `the replay lost its sensitivity` | 退行モデルのトレースが全部実装と一致した | 再生テスト（`repro/replay.test.ts`）が状態を比べなくなっている |

## 範囲外

Codex・Antigravity のプロセス、WebSocket 層、アプリはモデルにない。SDK のふるまいは `ENV_*` の仮定として切り替えていて、実際の SDK がどう動くかは検査では決まらない。
