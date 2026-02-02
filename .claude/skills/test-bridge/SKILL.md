---
name: test-bridge
description: Bridge Server (TypeScript) のテスト実行・型チェック・テスト記述ガイド
disable-model-invocation: true
allowed-tools: Bash(npx:*), Bash(npm:*), Read, Glob, Grep
---

# Bridge Server テスト

## 実行手順

以下を順番に実行し、全てパスすることを確認する。

### 1. ユニットテスト

```bash
npm run test:bridge
```

特定ファイルのみ:
```bash
cd packages/bridge && npx vitest run src/<filename>.test.ts
```

ウォッチモード (開発中):
```bash
cd packages/bridge && npx vitest src/<filename>.test.ts
```

### 2. TypeScript 型チェック

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
```

テストファイル (`*.test.ts`) と `vitest.config.ts` は `tsconfig.json` の exclude に入っているため、型チェック対象外。

### 3. カバレッジ (任意)

```bash
npm run test:bridge:coverage
```

## テスト記述規約

### ファイル配置・命名

- テストファイルはソースと同じディレクトリに `<module>.test.ts` として配置
  - 例: `src/parser.ts` → `src/parser.test.ts`
- vitest.config.ts の include パターン: `src/**/*.test.ts`

### import

```typescript
import { describe, it, expect } from "vitest";
```

- vitest からのみ import する (jest の互換 API は使わない)
- テスト対象モジュールは `.js` 拡張子で import する (NodeNext moduleResolution)
  - 例: `import { parseRule } from "./claude-process.js";`

### テスト構造

```typescript
describe("関数名 or クラス名", () => {
  it("動作の説明 (英語)", () => {
    expect(actual).toBe(expected);
  });
});
```

- `describe` でテスト対象の関数/クラス単位にグルーピング
- `it` の説明は英語で、三人称現在形 (`"returns null for empty string"`)
- 1つの `it` で1つの振る舞いを検証する

### テスト対象の方針

- 純粋関数・ロジック中心にテストする (高ROI)
- プロセスspawn, ファイルシステム, WebSocket等の外部依存は対象外
- 現在テスト対象のモジュール:
  - `parser.ts` — parseClaudeEvent, claudeEventToServerMessage, parseClientMessage, normalizeToolResultContent
  - `claude-process.ts` — parseRule, matchesSessionRule, buildSessionRule, toolNeedsApproval, ACCEPT_EDITS_AUTO_APPROVE
  - `image-store.ts` — ImageStore.extractImagePaths

### 新しいテスト追加時

1. export されている純粋関数があればテスト追加を検討
2. internal関数をテストしたい場合は `export` に変更する (テスト可能性のための export は OK)
3. テスト追加後は型チェックが通ること (`npx tsc --noEmit`) も確認
