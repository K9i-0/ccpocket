# Codex 対応 TODO（再作成）

最終更新: 2026-02-13

## 調査スコープ
- Bridge: `packages/bridge/src/websocket.ts`, `packages/bridge/src/session.ts`, `packages/bridge/src/codex-process.ts`, `packages/bridge/src/sessions-index.ts`
- Mobile: `apps/mobile/lib/features/chat/*`, `apps/mobile/lib/features/chat_codex/*`, `apps/mobile/lib/features/session_list/*`, `apps/mobile/lib/widgets/new_session_sheet.dart`, `apps/mobile/lib/widgets/session_card.dart`, `apps/mobile/lib/models/messages.dart`

## 現状サマリ
- Codex セッションの開始/再開、履歴復元、session list 統合は実装済み。
- ただし、Claude chat 側にあるUI/機能で Codex chat 側に未搭載のものが残っている。
- Codex SDK 固有機能（usage、image input、Thread options 追加項目）の取り込みが未実装。

---

## 1. Claude Code の方にあるのに不足している機能

### P0: Codex の `ApprovalPolicy` に `on-request` を追加
- 背景:
  - Bridge 側は `"on-request"` を受け付けるが、Mobile の `ApprovalPolicy` enum に値がない。
- 対象:
  - `apps/mobile/lib/models/messages.dart`
  - `apps/mobile/lib/widgets/new_session_sheet.dart`
- 完了条件:
  - New Session ダイアログで `on-request` を選択できる。
  - 選択値が `ClientMessage.start` に正しく流れる。

### P1: Codex Chat の AppBar 機能パリティ（Screenshot / Branch 情報）
- 背景:
  - Claude chat には Screenshot と Branch/Worktree 情報があるが、Codex chat にはない。
- 対象:
  - `apps/mobile/lib/features/chat_codex/codex_chat_screen.dart`
  - 必要に応じて `apps/mobile/lib/features/session_list/session_list_screen.dart`
- 完了条件:
  - Codex chat から Screenshot を実行できる。
  - 現在ブランチ（または未取得時のフォールバック）を表示できる。

### P1: Running/Recent カードの provider UX を統一
- 背景:
  - provider バッジはあるが、Codex 設定（model/sandbox/approval）が一覧上で見えない。
- 対象:
  - `apps/mobile/lib/widgets/session_card.dart`
  - `apps/mobile/lib/models/messages.dart`
- 完了条件:
  - Codex セッションで設定サマリを視認できる（最低1行）。
  - 既存の Claude 表示は崩さない。

### P2: Codex セッションで未対応機能の明示
- 背景:
  - Rewind/Approval UI は Codex で非対応だが、理由がユーザーに伝わりにくい。
- 対象:
  - `apps/mobile/lib/features/chat_codex/codex_chat_screen.dart`
  - `apps/mobile/lib/services/chat_message_handler.dart`
- 完了条件:
  - 非対応機能を触ったときに説明導線（tooltip/snackbar等）がある。

---

## 2. Codex 特有で実装すべき機能

### P0: Codex usage（token）を result に載せて UI 表示
- 背景:
  - `turn.completed.usage` が `codex-process.ts` で捨てられており、利用量が見えない。
- 対象:
  - `packages/bridge/src/codex-process.ts`
  - `packages/bridge/src/parser.ts`（必要なら型拡張）
  - `apps/mobile/lib/services/chat_message_handler.dart`
  - `apps/mobile/lib/features/chat/*` / `apps/mobile/lib/features/chat_codex/*`
- 完了条件:
  - Codex セッション完了時に入力/出力トークン数を確認できる。
  - Claude 側の cost 表示に回帰がない。

### P0: Codex 画像入力（`local_image`）対応
- 背景:
  - Codex SDK は画像入力をサポートするが、Bridge は Codex を text-only 扱いしている。
- 対象:
  - `packages/bridge/src/websocket.ts`
  - `packages/bridge/src/codex-process.ts`
  - `apps/mobile/lib/features/chat_codex/codex_chat_screen.dart`（必要なら送信導線確認）
- 完了条件:
  - Codex セッションで画像付き入力を送信できる。
  - 失敗時のエラーハンドリングが明示される。

### P1: Codex Thread options の拡張（reasoning/network/web search）
- 背景:
  - SDK側の `ThreadOptions` にある設定を現在UI/Bridgeで渡せていない。
- 対象:
  - `apps/mobile/lib/widgets/new_session_sheet.dart`
  - `apps/mobile/lib/models/messages.dart`
  - `packages/bridge/src/parser.ts`
  - `packages/bridge/src/websocket.ts`
  - `packages/bridge/src/codex-process.ts`
- 候補項目:
  - `modelReasoningEffort`
  - `networkAccessEnabled`
  - `webSearchMode` / `webSearchEnabled`
- 完了条件:
  - 追加設定が start/resume の両方で反映される。

### P1: Codex 履歴復元の一致ロジックを厳密化
- 背景:
  - `findCodexSessionJsonlPath` が `endsWith("-threadId")` を許容しており誤一致余地がある。
- 対象:
  - `packages/bridge/src/sessions-index.ts`
  - `packages/bridge/src/sessions-index.test.ts`
- 完了条件:
  - threadId 完全一致 or session_meta.id 一致のみで解決する。
  - 近似IDファイルが混在しても誤ファイルを拾わない。

### P2: Codex イベント可視化の改善（tool分類・要約）
- 背景:
  - `command_execution/file_change/mcp_tool_call/web_search/todo_list` を最低限表示しているが、可読性が低い。
- 対象:
  - `packages/bridge/src/codex-process.ts`
  - `apps/mobile/lib/widgets/bubbles/*`
- 完了条件:
  - ツールイベントが種類ごとに判別しやすい表示になる。
  - 長い出力の折りたたみ/展開が可能。

---

## 実行順（推奨）
1. P0-1 `on-request` 追加（小さく確実）
2. P0-2 Codex usage 表示
3. P0-3 Codex 画像入力対応
4. P1群（AppBar parity / settings拡張 / 履歴一致厳密化）
5. P2群（UX改善）

## 検証コマンド
- `npx tsc --noEmit -p packages/bridge/tsconfig.json`
- `dart analyze apps/mobile`
- `dart format apps/mobile`
- `cd apps/mobile && flutter test`
