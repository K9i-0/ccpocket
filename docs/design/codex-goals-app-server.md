# Codex Goals / App Server Protocol 調査

## Status: Implemented (updated 2026-07-13)

`openai/codex` の app-server protocol に追加された `thread/goal/*` RPC と、公式 docs の
`/goal` 機能を調査したメモ。

結論: goal は通常のチャットメッセージではなく、Codex スレッドに紐づく durable objective。
ccpocket で本格対応するなら、チャット入力に `/goal ...` を流すだけではなく、専用 UI と protocol
対応を持つのが妥当。

## 参照元

- OpenAI docs: https://developers.openai.com/codex/use-cases/follow-goals
- `openai/codex` app-server README: https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md
- Goal persistence PR: https://github.com/openai/codex/pull/18073
- Goal app-server API PR: https://github.com/openai/codex/pull/18074
- 調査時点の upstream HEAD: `408e6218ab7fadc192901ae28520471a4f990671` (`2026-05-08`)

## 公式 docs 上の位置づけ

`/goal` は、Codex に長時間の作業目標を与えるための experimental CLI 機能。

- 1ターンで終わる通常プロンプトではなく、複数ターンにまたがって追い続ける目的を設定する
- コード移行、大規模リファクタ、実験、プロトタイプ作成、評価改善ループのような作業が対象
- 成功条件、検証コマンド、停止条件が明確な仕事に向く
- loose な未整理バックログを丸ごと渡す用途には向かない
- `/experimental` で有効化するか、`config.toml` の `[features] goals = true` が必要

CLI 操作は以下の形。

```text
/goal <objective>
/goal
/goal pause
/goal resume
/goal clear
```

## App Server Protocol

2026-04 後半に `thread/goal/*` が app-server v2 protocol に追加された。

### RPC

```text
thread/goal/set
thread/goal/get
thread/goal/clear
```

### Notifications

```text
thread/goal/updated
thread/goal/cleared
```

### ThreadGoal

現在の protocol 型は以下の情報を持つ。

```text
threadId: string
objective: string
status: active | paused | blocked | usageLimited | budgetLimited | complete
tokenBudget: number | null
tokensUsed: number
timeUsedSeconds: number
createdAt: number
updatedAt: number
```

### ThreadGoalSetParams

```text
threadId: string
objective?: string | null
status?: active | paused | blocked | usageLimited | budgetLimited | complete | null
tokenBudget?: number | null
```

`tokenBudget` は指定する場合、正の数のみ許可される。

## 仕様メモ

### Goal は複数登録できるか

同一スレッドには 1つだけ。

app-server README では `single persisted goal for a materialized thread` と説明されている。
`thread/goal/set` に新しい `objective` を渡すと既存 goal を置き換え、`tokensUsed`,
`timeUsedSeconds`, `createdAt` などの usage accounting もリセットされる。

スレッドごとに 1つなので、アプリ全体では複数スレッドにそれぞれ goal が存在し得る。

### Goal の状態

Codex CLI 0.144.1 の生成 schema では状態は 6つ。

| 状態 | 意味 |
|---|---|
| `active` | Codex が goal を追う状態 |
| `paused` | goal は残るが自動継続しない状態 |
| `blocked` | 外部条件などにより進行できない状態 |
| `usageLimited` | 利用上限により停止した状態 |
| `budgetLimited` | token budget 到達など、予算制約で停止した状態 |
| `complete` | goal が達成された状態 |

`complete` と `clear` は別物。

- `complete`: goal は達成済み状態として残る
- `clear`: goal 自体を削除する

### 通常のプロンプトとの差

通常プロンプトは turn input。
goal は thread-level state。

CLI では slash command、app-server では専用 RPC で設定されるため、チャット本文に混ぜるものではない。
実装側でも `thread/goal/set` は state DB を更新し、`thread/goal/updated` を通知する。

### コンテキストウィンドウとの関係

goal は sqlite の thread-level state として永続化されるため、保存場所としては通常の会話履歴や
コンテキストウィンドウとは別管理。

ただし、モデルが各 turn で goal を考慮するには goal 情報をモデル入力へ反映する必要がある。
つまり「コンテキストを消費しない無限の記憶」ではない。
長時間作業の詳細な経緯は、通常どおり履歴、compaction、progress log、ファイル、memories などに依存する。

## Runtime 挙動

実装上、`thread_goal_processor` は `Feature::Goals` を確認し、無効なら
`goals feature is disabled` を返す。

`resume` 時には現在の goal snapshot を通知する wiring があり、active goal に対して
`continue_active_goal_if_idle()` を呼ぶ処理がある。
このため、goal は単なる表示用メタデータではなく、resume 後の継続実行にも関係する。

また、ephemeral thread は goal 非対応。
永続 rollout を持つ materialized thread に対する機能として扱う必要がある。

## ccpocket UI 方針

本格対応するなら、専用 UI を作る価値がある。

### 最小対応

- `thread/goal/updated` / `thread/goal/cleared` を未知イベントとして捨てずに扱う
- セッション状態に current goal を保持する
- `thread/resume` 後の goal snapshot で UI を復元する
- `goals feature is disabled` を受けたら experimental goals の有効化案内に落とす

### 推奨 UI

チャット画面上部に小さな Goal Bar を置く。

- goal 未設定: 非表示、または小さな追加ボタン
- goal 設定中: objective 1行、status、token budget 進捗、操作メニュー
- 詳細編集: bottom sheet

操作は以下を提供する。

- 作成 / 置換: `thread/goal/set` with `objective`
- 一時停止: `thread/goal/set` with `status: paused`
- 再開: `thread/goal/set` with `status: active`
- 完了: `thread/goal/set` with `status: complete`
- 削除: `thread/goal/clear`
- budget 設定 / 解除: `thread/goal/set` with `tokenBudget`

### 表示上の注意

- `budgetLimited` はエラーではなく、期待された停止状態として扱う
- `complete` と `clear` を UI 上で混同しない
- goal はスレッド単位なので、セッション一覧にも active goal の有無を出す余地がある
- experimental 機能なので、当面は設定で有効化したユーザーだけに表示するのが安全

## 実装時の確認事項

1. ccpocket Bridge が Codex app-server v2 protocol をどの層まで直接扱うか
2. `initialize.capabilities.experimentalApi = true` が必要か、現在の Codex SDK 経由でどう渡すか
3. Codex CLI / app-server の feature flag `goals = true` を Bridge 側から検出できるか
4. goal が active のまま Bridge / app が切断された場合、再接続後にどの通知順で復元されるか
5. token budget 到達時に `thread/goal/updated` 以外の status / result / error がどう流れるか
6. 通常のユーザー入力で goal を上書き・修正したい場合の UX
