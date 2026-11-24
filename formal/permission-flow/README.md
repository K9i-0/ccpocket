# 権限承認フローの形式仕様

Claude 用プロセス `packages/bridge/src/sdk-process.ts`（`SdkProcess`）の権限承認、`status`、入力キュー、権限モード変更を [Quint](https://quint-lang.org/) でモデル化し、実装と突き合わせている。

導入の経緯と、FSL・TLA+ との比較は [docs/formal-methods-evaluation.md](../../docs/formal-methods-evaluation.md) にある。

## 使い方

```bash
bash formal/permission-flow/quint/check.sh   # 約2分。CI（Formal check）でも走る
bash formal/permission-flow/quint/full.sh    # 全探索と活性。約12分、Java が要る。手元で実行
```

動作を変えるときの手順と、失敗の読み方は [formal-check スキル](../../.claude/skills/formal-check/SKILL.md) にある。

| ファイル | 役割 |
|---|---|
| [quint/permflow.qnt](quint/permflow.qnt) | モデルと性質 |
| [quint/gen-instances.sh](quint/gen-instances.sh) | 仮定の組み合わせごとのインスタンス（`instances.qnt`）を生成する |
| [quint/check.sh](quint/check.sh) | 型検査、ランダム実行、実装への再生 |
| [quint/full.sh](quint/full.sh) | TLC による全状態の探索と活性の検査 |
| [quint/expected-violations.tsv](quint/expected-violations.tsv) | 破れることが期待される（インスタンス, 性質）。今は仕込んだ退行だけ |
| [quint/expected-liveness.tsv](quint/expected-liveness.tsv) | 活性の期待結果 |
| [quint/repro/replay.test.ts](quint/repro/replay.test.ts) | モデルのトレースを実際の `SdkProcess` に流して状態を比べる |
| [../quint.sh](../quint.sh) | Quint のバージョン固定（ここ1か所） |

## 何を保証しているか

- **`check.sh`**: 各性質について、2万本×25ステップのランダム実行で反例が出ないこと。モデルから作った300本のトレースを実装に流し、各ステップ後の状態がモデルと一致すること。証明ではない。
- **`full.sh`**: ツール呼び出しID 2個、再開始1回までの範囲で、到達できる全状態で安全性が成り立つこと。同じ範囲での活性。
- **どちらも保証しないこと**: SDK が実際にどのイベントをどの順で送るか。モデルは `ENV_*` の仮定として切り替えているだけで、12通りの組み合わせすべてで性質が成り立つことを見ている。WebSocket 層、アプリ、Codex・Antigravity のプロセスは範囲外。

再生テストは実装の private フィールド（`pendingInputQueue`、`userMessageResolve` など）を読む。フィールド名を変えたら [replay.test.ts](quint/repro/replay.test.ts) も直す。

## 性質

| ID | 内容 |
|---|---|
| `P1a` | 保留中の承認要求があれば、`status` は `waiting_approval` |
| `P1b` | `status` が `waiting_approval` なら、保留中の承認要求がある |
| `P2` | SDK が待っている `canUseTool` の約束は、保留表に載っているか決着済み |
| `P3` | 1つの要求の決着は高々1回 |
| `P4_userDecision` | 承認・拒否・回答で決着した要求には `permission_resolved` が届く |
| `P4_app` | クライアントが見ている保留集合は保留表と一致する（`idle` / `starting` への変化で消える分を含む） |
| `P4_aux_registered` | `permission_request` を送る時点で、要求は保留表に載っている |
| `P5_state` | 停止後は保留表と入力キューが空で、`status` は `idle` |
| `P5_noEffect` | 停止後に届いた承認は何も起こさない |
| `P6` | 再開始より前に出したモード変更は、再開始後の `permissionMode` を書き換えない |
| `P8_noLostInput` | 入力が、使われていない入力ストリームに渡って消えることはない |
| `P7_fair`（活性） | 保留中の承認要求は、いずれ決着する |
| `P8_fair`（活性） | 止まらない限り、キューに積んだ入力はいずれ SDK に渡る |

`P4_resolved` と `P4_view`（すべての要求に `permission_resolved` が届く）は、定義は残してあるが検査していない。`result`・`stop`・再開始は通知なしで要求を終わらせ、クライアントは状態の変化で表示を消す設計のため。

## SDK についての仮定

`true` にすると、そのふるまいを SDK に許す。`cur_min` は全部 `false`、`cur_U` は全部 `true`。

| 定数 | 許すふるまい |
|---|---|
| `ENV_MSGS_WHILE_PENDING` | 承認の返事待ちの間にも、メインスレッドのメッセージが届く |
| `ENV_BG` | ターンの外でも `canUseTool` が来る（バックグラウンドのエージェント） |
| `ENV_ABORT` | `canUseTool` の中止シグナルが発火する |
| `ENV_NATURAL_END` | ストリームが例外なしで終わる |
| `ENV_REENTRANT` | `permission_request` の同期リスナーがその場で承認する |
| `ENV_INPUT_AFTER_DEAD` | 停止・終了後のプロセスにも入力が届く |
| `ENV_ANYTIME` | メッセージや `canUseTool` がターンの外でも届く |

`M1`〜`M3` は仕込んだ退行（過去の不具合2つと、世代チェックを外したもの）。検査のたびに、対応する性質が破れることを確かめている。検査が空振りしていないことの確認になる。

## わかっている限界

- **ターンの外で承認要求が来る場合の入力（`P8_fair`）**: `ENV_BG` を許すと破れる。ターンの外で `canUseTool` が来て承認すると、`status` は `running` になるが、それを終わらせる `result` が来ない。以後の入力はキューに積まれたまま渡らない。本物の SDK がターンの外で承認を求めるかは確かめていない。`expected-liveness.tsv` に既知の違反として記録してある。直すなら、承認待ちに入る前の状態を覚えておき、最後の要求が決着したらそこへ戻す形になる。
- **範囲の大きさ**: 全探索はツール呼び出しID 2個、再開始1回、入力キュー2、同時のモード変更2まで。それより大きい範囲はランダム実行（ID 3個）だけ。
- **モデルにないもの**: ステアリング入力（`steerInput`）、バックグラウンドタスクの停止、認証、画像つき入力の経路、ツール呼び出しIDの再利用。
- **入力の経路**: `delivery` 指定なしの経路（`dispatchInput` と、その直後の `interrupt`）だけをモデルにしている。Bridge 側のキュー（`session.queuedInput`）は範囲外。

## evaluation/

ツール選定のときの成果物（FSL・TLA+ の仕様、3ツールへの出題、各エージェントのメモ）。コミット `5d75b6f0` 時点のコードに対するもので、保守していない。スクリプトはその時点のディレクトリ構成が前提なので、動かすならそのコミットをチェックアウトする。
