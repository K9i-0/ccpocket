# SDK Plan Editing & Context Clearing 調査結果

## 調査日: 2025-05

## 1. プラン編集 (ExitPlanMode の updatedInput)

### 結論: 可能

SDK の `canUseTool` コールバックで `PermissionResult.updatedInput` を使うことで、`ExitPlanMode` のプランテキストを編集して承認できる。

### 仕組み

```typescript
// SDK の canUseTool コールバック
canUseTool(tool, input) {
  // ユーザーが編集したプランで承認する場合
  return {
    behavior: "allow",
    updatedInput: {
      plan: "edited plan text here"
    }
  };
}
```

- `PermissionResult` の型: `{ behavior: "allow" | "deny", updatedInput?: Record<string, unknown> }`
- `updatedInput` は元の `input` と浅いマージされる (`{ ...input, ...updatedInput }`)
- `ExitPlanModeInput` の型: `{ plan: string, allowedPrompts?: Array<{ tool: string, prompt: string }> }`

### 既存の実装パターン

`sdk-process.ts` の `answer()` メソッド (AskUserQuestion 応答) が同じパターンを使用:

```typescript
// answer() での updatedInput マージ例
const merged = updatedInput
  ? { ...pending.input, ...updatedInput }
  : pending.input;
pending.resolve({ behavior: "allow", updatedInput: merged });
```

## 2. コンテキストクリア (Approve with Clear Context)

### 結論: SDK に直接 API なし (CLI のみの機能)

CLI の `Shift+Tab` による "Clear context and approve" は CLI 固有の UI 機能で、SDK には対応する API がない。

### 代替手段

| 方法 | 説明 | 制限 |
|------|------|------|
| `updatedPermissions.setMode` | 承認時に permission mode を変更 | コンテキストクリアとは別機能 |
| `/compact` コマンド送信 | ユーザーメッセージとして送信 | 承認と同時ではなく別操作 |
| セッション再作成 | 新規セッションで `continue` | 完全リセットになる |

### 参考: updatedPermissions

```typescript
// permission mode の変更は可能
return {
  behavior: "allow",
  updatedPermissions: {
    setMode: "acceptEdits"  // permission mode を変更
  }
};
```

## 3. ccpocket での実装方針

### プラン編集フロー

```
PlanDetailSheet (編集モード)
  → edited plan text を Navigator.pop で返す
    → chat_screen.dart: approve(toolUseId, updatedInput: {plan: edited})
      → ClientMessage.approve(id, updatedInput: {plan: edited})
        → WebSocket → Bridge Server
          → sdk-process.ts: pending.resolve({behavior:"allow", updatedInput: merged})
```

### コンテキストクリアについて

現時点では SDK に API がないため実装しない。将来 SDK が対応した場合に追加を検討する。
