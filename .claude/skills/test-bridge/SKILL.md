---
name: test-bridge
description: Bridge Server (TypeScript) のテスト実行・型チェック・テスト記述ガイド
allowed-tools: Bash(npx:*), Bash(npm:*), Read, Glob, Grep
---

# Bridge Server テスト

## 実行手順

変更した挙動に対応するテストと静的検証を選ぶ。全体テストは、共通基盤・依存関係への変更や回帰懸念がある場合、または全体検証を依頼された場合に実行する。成功済みの検証を理由なく繰り返さない。以下はコマンドの選択肢。

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

### 4. ミューテーションテスト (任意)

ソースを少しずつ壊してテストが落ちるかを見る。カバレッジでは分からない「実行はされるが検証されていない」箇所が見つかる。CI では回さず、ロジック中心のモジュールのテストを見直すときに手元で使う。

```bash
bash scripts/mutation-bridge.sh path-utils cli-args     # src/<name>.ts を対象にする
bash scripts/mutation-bridge.sh src/parser.ts:100-250   # 行範囲を絞る
```

- 終了時に、生き残った変異 (`survived`) とテストが通らない箇所 (`untested`) の一覧、ファイル別スコアを出す。JSON レポートを読み直すときは `node scripts/mutation-report.mjs <report.json>`。
- 小さなモジュールは 1〜2 分、`parser.ts` 全体は 10 分ほどかかる。
- 生き残った変異のうち、挙動として守りたいものだけテストを足す。等価な変異 (挙動が変わらない)、ログ文言だけの変異は追わない。100% は目標にしない。
- 必ずこのスクリプト経由で実行する。変異はパス検査や git 操作のガードを外しうるため、スクリプトがサンドボックスをリポジトリ外に置き、`HOME` を空のディレクトリに差し替え、テストを fork プールで動かす。
- プロセス起動やネットワークを伴うモジュール (`websocket.ts`、`*-process.ts`、`git-operations.ts` など) は対象にしない。

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
