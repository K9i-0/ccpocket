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

### ✅ P0: Codex の `ApprovalPolicy` に `on-request` を追加
- 背景:
  - Bridge 側は `"on-request"` を受け付けるが、Mobile の `ApprovalPolicy` enum に値がない。
- 対象:
  - `apps/mobile/lib/models/messages.dart`
  - `apps/mobile/lib/widgets/new_session_sheet.dart`
- 完了条件:
  - New Session ダイアログで `on-request` を選択できる。
  - 選択値が `ClientMessage.start` に正しく流れる。
- 状態:
  - 2026-02-13 対応済み（`ApprovalPolicy.onRequest` を追加し、New Session選択値を start/resume に反映）

### ✅ P1: Codex Chat の AppBar 機能パリティ（Screenshot / Branch 情報）
- 背景:
  - Claude chat には Screenshot と Branch/Worktree 情報があるが、Codex chat にはない。
- 対象:
  - `apps/mobile/lib/features/chat_codex/codex_chat_screen.dart`
  - 必要に応じて `apps/mobile/lib/features/session_list/session_list_screen.dart`
- 状態:
  - 2026-02-13 対応済み（Codex chat に Screenshot と BranchChip を追加、worktree導線を接続）
  - iOS E2E（8766）で Screenshot シート / Worktrees シート起動を確認

### ✅ P1: Running/Recent カードの provider UX を統一
- 背景:
  - provider バッジはあるが、Codex 設定（model/sandbox/approval）が一覧上で見えない。
- 対象:
  - `apps/mobile/lib/widgets/session_card.dart`
  - `apps/mobile/lib/models/messages.dart`
- 状態:
  - 2026-02-13 対応済み（Running/Recent 両カードに Codex 設定サマリ 1 行を追加）
  - `SessionInfo` に `codexSettings` 取り込みを追加
  - iOS E2E（8766）で `model/sandbox/approval` 表示を確認

### ✅ P2: Codex セッションで未対応機能の明示
- 背景:
  - Rewind/Approval UI は Codex で非対応だが、理由がユーザーに伝わりにくい。
- 対象:
  - `apps/mobile/lib/features/chat_codex/codex_chat_screen.dart`
  - `apps/mobile/lib/services/chat_message_handler.dart`
- 完了条件:
  - 非対応機能を触ったときに説明導線（tooltip/snackbar等）がある。
- 状態:
  - 2026-02-13 対応済み（Codex Chat AppBar に `Rewind (unsupported)` ボタンを追加）
  - タップ時に `Codex sessions currently do not support rewind.` を Snackbar 表示
  - iOS E2E（8766）で `codex_rewind_info_button` の表示とタップを確認

### ✅ P0: Codex resume 後に Codex 画面へ遷移するよう統一
- 背景:
  - `resume_session` 後の `session_created` 経由ナビゲーションで provider 情報が欠落し、
    Codex セッションでも Claude 画面に入るケースがある。
- 対象:
  - `apps/mobile/lib/features/session_list/session_list_screen.dart`
  - 必要に応じて `packages/bridge/src/websocket.ts` / `apps/mobile/lib/models/messages.dart`
- 完了条件:
  - Codex の resume/start のどちらでも `CodexChatScreen` に遷移する。
  - iOS E2E で `Message Codex...` ヒント表示を確認。
- 状態:
  - 2026-02-13 対応済み（`session_created` に `provider` を常時付与し、SessionListの遷移判定へ伝播）
  - iOS E2E（8766）で `resume_session` 実行後に `_CodexProviders` / `Message Codex...` を確認
  - `packages/bridge/src/websocket.test.ts` に provider 伝播の回帰テストを追加

---

## 2. Codex 特有で実装すべき機能

### ✅ P0: Codex usage（token）を result に載せて UI 表示
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
- 状態:
  - 2026-02-13 対応済み（Codex `turn.completed.usage` を result に載せてUI表示）

### ✅ P0: Codex 画像入力（`local_image`）対応
- 背景:
  - Codex SDK は画像入力をサポートするが、Bridge は Codex を text-only 扱いしている。
- 対象:
  - `packages/bridge/src/websocket.ts`
  - `packages/bridge/src/codex-process.ts`
  - `apps/mobile/lib/features/chat_codex/codex_chat_screen.dart`（必要なら送信導線確認）
- 完了条件:
  - Codex セッションで画像付き入力を送信できる。
  - 失敗時のエラーハンドリングが明示される。
- 状態:
  - 2026-02-13 対応済み（Codex入力に画像経路を追加し、Bridge経由で送信可能）

### ✅ P1: Codex Thread options の拡張（reasoning/network/web search）
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
- 状態:
  - 2026-02-13 対応済み（`modelReasoningEffort` / `networkAccessEnabled` / `webSearchMode` を start/resume に追加）
  - Mobile `NewSessionSheet` に Reasoning / Web Search / Network Access UI を追加
  - Bridge `SessionInfo.codexSettings` と Recent/Running parse を拡張
  - iOS E2E（8766）で開始した Codex セッションに対し、`session_list.codexSettings` で反映を確認

### ✅ P1: Codex 履歴復元の一致ロジックを厳密化
- 背景:
  - `findCodexSessionJsonlPath` が `endsWith("-threadId")` を許容しており誤一致余地がある。
- 対象:
  - `packages/bridge/src/sessions-index.ts`
  - `packages/bridge/src/sessions-index.test.ts`
- 状態:
  - 2026-02-13 対応済み（`findCodexSessionJsonlPath` の suffix 近似一致を削除）
  - `threadId` 完全一致または `session_meta.id` 一致のみで解決
  - `packages/bridge/src/sessions-index.test.ts` に誤一致防止ケースを追加

### ✅ P2: Codex イベント可視化の改善（tool分類・要約）
- 背景:
  - `command_execution/file_change/mcp_tool_call/web_search/todo_list` を最低限表示しているが、可読性が低い。
- 対象:
  - `packages/bridge/src/codex-process.ts`
  - `apps/mobile/lib/widgets/bubbles/*`
- 完了条件:
  - ツールイベントが種類ごとに判別しやすい表示になる。
  - 長い出力の折りたたみ/展開が可能。
- 状態:
  - 2026-02-13 確認済み（Bridge側で `command_execution/file_change/mcp_tool_call/web_search/todo_list` を tool単位で分類）
  - UI側 `ToolResultBubble` は collapsed/preview/expanded の3段階表示を実装済み
  - 既存テスト `apps/mobile/test/tool_result_bubble_test.dart` で折りたたみ挙動を検証済み

---

## 実行順（更新）
1. ✅ P0-1 `on-request` 追加
2. ✅ P0-2 Codex usage 表示
3. ✅ P0-3 Codex 画像入力対応
4. ✅ P1 AppBar parity / Running-Recent provider UX
5. ✅ P0 `Codex resume 後に Codex 画面へ遷移するよう統一`
6. ✅ P1 `Codex Thread options の拡張（reasoning/network/web search）`
7. ✅ P2 `Codex イベント可視化の改善（tool分類・要約）`

## 検証コマンド
- `npx tsc --noEmit -p packages/bridge/tsconfig.json`
- `dart analyze apps/mobile`
- `dart format apps/mobile`
- `cd apps/mobile && flutter test`
