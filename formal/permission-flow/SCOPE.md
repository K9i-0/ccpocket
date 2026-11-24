# 権限承認フローの検証範囲

形式手法ツール（FSL / Quint / TLA+）を同じ課題で比べるための共通の出題。
3つのツールはこの文書だけを共有し、仕様は各自がコードを読んで書く。

## 対象

Claude 用プロセス `packages/bridge/src/sdk-process.ts` の `SdkProcess` クラスのうち、
権限承認・状態・入力キュー・権限モードに関わる部分。

| 部分 | 場所 |
|---|---|
| 状態の型 `ProcessStatus`（5状態） | `packages/bridge/src/parser.ts:1651` |
| 開始 `start` / 停止 `stop` / 中断 `interrupt` | `sdk-process.ts:1176` / `:1368` / `:1403` |
| 入力 `dispatchInput` と入力ストリーム `createUserMessageStream` | `sdk-process.ts:1445` / `:1803` |
| 承認 `approve` `approveAlways` `reject` `answer` | `sdk-process.ts:1505`〜`1612` |
| モード変更 `setPermissionMode` | `sdk-process.ts:1618` |
| 承認要求の受付 `handleCanUseTool` `waitForPermission` | `sdk-process.ts:2160`〜`2227` |
| 一括拒否 `denyAllPendingPermissions` と決着 `resolvePendingPermission` | `sdk-process.ts:2235`〜`2270` |
| SDK メッセージによる状態更新 `updateStatusFromMessage` | `sdk-process.ts:2666` |
| クライアントからの入口 | `packages/bridge/src/websocket.ts:1350`〜`1530` と各 `handle*` |

Codex・Antigravity の実装、認証、費用、バックグラウンドタスク、画像は対象外。

## 登場するもの

**状態変数（最低限）**

- `status`: `starting / idle / running / waiting_approval / compacting`
- `pendingPermissions`: 保留中の承認要求（ツール呼び出しID → 要求）
- SDK 側が待っている `canUseTool` の約束（Bridge の保留表とは別物として持つ）
- `pendingInputQueue`、`userMessageResolve`（SDK が次の入力を待っているか）
- `permissionMode`、`permissionModeGeneration`、処理中のモード変更
- `stopped`、`queryInstance` の有無
- クライアントが見ている保留中の要求（`permission_request` と `permission_resolved` から組み立てたもの）

**環境からのイベント**

- SDK: `canUseTool` の呼び出し（サブエージェントがあるので複数が同時に保留になりうる）、
  その中止シグナル、`system`（`status: compacting / requesting / null`）、`assistant`、`user`、`result`、異常終了
- クライアント: 入力、`approve` / `approve_always` / `reject` / `answer`、
  `set_permission_mode`、`interrupt`、`stop_session`、再開始（`start` の再呼び出し）

**抽象化の目安**

- ツール呼び出しIDは2〜3個、入力キューの長さは2まで、モードは2〜3種で足りる。
- メッセージの中身や時刻は捨ててよい。順序と有無だけを扱う。
- 非同期の `await`（`setPermissionMode` の途中など）は、途中で他のイベントが割り込める別ステップにする。

## 確かめたい性質

意図から書いたもので、今のコードが満たしているとは限らない。

| ID | 種類 | 性質 |
|---|---|---|
| P1a | 安全性 | 保留中の承認要求が1件でもあれば、`status` は `waiting_approval` である |
| P1b | 安全性 | `status` が `waiting_approval` なら、保留中の承認要求が1件以上ある |
| P2 | 安全性 | SDK が待っている `canUseTool` の約束は、Bridge の保留表に載っているか、決着済みである（忘れられたまま残らない） |
| P3 | 安全性 | 1つの承認要求が決着するのは高々1回である |
| P4 | 安全性 | クライアントに `permission_request` が届いた要求は、決着したら `permission_resolved` も届く。イベントを配り終えた時点で、クライアントが見ている保留集合は Bridge の保留表と一致する |
| P5 | 安全性 | `stop` のあとは保留表と入力キューが空で、`status` は `idle`。停止後に届いた承認は何も起こさない |
| P6 | 安全性 | 再開始より前に出したモード変更は、再開始後の `permissionMode` を書き換えない |
| P7 | 活性 | 保留中の承認要求は、いずれ必ず決着する |
| P8 | 活性 | セッションが止まらない限り、入力キューに積まれた入力はいずれ SDK に渡る |

P1a・P1b は「イベント1つの処理が終わった時点」で成り立てばよい（処理の途中は問わない）。
活性の性質には公平性の仮定が要る。置いた仮定を仕様とメモに明記する。
ツールが活性を表現できない場合は、その旨と代わりに書いた安全性の性質を記録する。

## 仕込む退行（仕様が空振りしていないかの確認）

現在のコードの仕様が書けたら、モデルを次のように壊し、どの性質が反例を出すかを記録する。
どれも過去に実際にあった不具合か、今あるガードを外したもの。

| ID | 壊し方 | 元になった修正 |
|---|---|---|
| M1 | `interrupt` / `stop` / `result` / 再開始で、保留表を消すだけにして SDK の約束を決着させない | `ce064bf0` |
| M2 | `permission_request` を保留表への登録より前に送り、決着時に `permission_resolved` を送らない | `d6c7e677` |
| M3 | `setPermissionMode` の世代チェック（`sdk-process.ts:1621` と `:1627`）を外す | 現行のガード |

修正前のコードは `git show ce064bf0^:packages/bridge/src/sdk-process.ts` などで読める。

## 成果物（ツールごとに `formal/permission-flow/<ツール名>/`）

1. 仕様ファイル一式
2. `run.sh`: 検証を最初から再現するコマンドを全部書いたもの。リポジトリのルートから `bash formal/permission-flow/<ツール名>/run.sh` で動くこと
3. `out/`: 検証器の生の出力（性質ごと、退行ごと）
4. `NOTES.md`（日本語）:
   - 性質ごとの結果（成立 / 反例あり / 表現できず）と、検査の深さや状態数
   - 反例の一覧。それぞれ、イベントの並び、対応するコード（`ファイル:行`）、分類（実装の不具合の疑い / モデルの誤り / コードで対処済み）
   - 退行 M1〜M3 を検出できたか、どの性質で検出したか
   - 仕様が通るまでの「書く → 検証 → 直す」の往復回数と、つまずいた点
   - 活性の扱いと公平性の仮定
   - モデルが単純化したこと、コードと対応が取れていない部分

## 守ること

- 書き込むのは自分の `formal/permission-flow/<ツール名>/` の中だけ。
- `packages/` 以下のソースは読むだけで、編集しない。
- コミットしない。
- 反例が出ても、性質やモデルを都合よく弱めて通さない。弱めた場合は理由を `NOTES.md` に書く。
- 反例を「実装の不具合の疑い」とする前に、モデルがコードと合っているかを該当行で確かめる。
