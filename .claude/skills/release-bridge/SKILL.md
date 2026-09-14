---
name: release-bridge
description: Bridge Server のリリース（バージョンbump + CHANGELOG + タグ → GH Actions で npm publish）
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(grep:*), Bash(npm run test:bridge), Bash(npx tsc:*), Bash(npm run bridge:build), Read, Edit, AskUserQuestion
---

# Bridge Server リリース

Bridge Server (`@ccpocket/bridge`) のリリースを行う。
タグ push 後は GH Actions が自動で npm publish + GitHub Release を作成する。

## 前提

- main ブランチで作業中であること
- 未コミットの変更がないこと

指定済みのバージョン・対象を優先する。未指定の項目は以下の既定ルールで決定し、決定内容と理由を報告してリリースを進める。リリース依頼に含まれるコミット・push・タグ作成に追加の承認を求めない。

## 手順

### 1. 現在のバージョン確認 & 変更内容の収集

```bash
grep '"version"' packages/bridge/package.json
```

前回リリースのタグからの差分を確認する:

```bash
# 前回のタグ
git tag -l 'bridge/v*' --sort=-v:refname | head -1

# 差分コミット
git log $(git tag -l 'bridge/v*' --sort=-v:refname | head -1)..HEAD --oneline -- packages/bridge/
```

### 2. バージョンを決定

差分コミットと実装内容から、次の優先順で決定する。指定済みのバージョンは再確認しない。

- 破壊的変更（`!`、`BREAKING CHANGE`、実際の互換性破壊）がある → `major`。未承認の場合だけ、具体的なバージョンと互換性への影響を示してユーザーに確認する。
- 破壊的変更がなく `feat` / 新機能がある → `minor` を自動採用する。
- その他の修正・改善・保守変更 → `patch` を自動採用する。

### 3. CHANGELOG 更新

`packages/bridge/CHANGELOG.md` の先頭に新しいセクションを追加する。

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

ステップ 1 で確認したコミットを元に、Added / Changed / Fixed に分類する。
空のセクション（該当なし）は省略する。

### 4. バージョン bump

`packages/bridge/package.json` の `version` をステップ 2 で決定したバージョンに更新する。

### 4.5. Flutter 側の expectedBridgeVersion を同期

`apps/mobile/lib/constants/app_constants.dart` の `expectedBridgeVersion` を
ステップ 4 で設定した新バージョンに合わせて更新する。

```dart
static const String expectedBridgeVersion = 'X.Y.Z';  // ← 新バージョンに変更
```

これにより、アプリが古い Bridge に接続した際に更新バナーが正しく表示される。
忘れるとアプリ側のバージョンチェックがずれたまま残る。

### 5. ローカル検証

タグ push 前に、CD と同じチェックをローカルで実行する。
**すべて pass しなければ次のステップに進まない。**

```bash
# テスト
npm run test:bridge

# 型チェック
npx tsc --noEmit -p packages/bridge/tsconfig.json

# ビルド
npm run bridge:build
```

失敗した場合は原因を調査し、今回の変更に起因する問題を修正・再検証する。既存の無関係な問題や権限・認証など自力で解消できない障害が残る場合は、失敗内容と必要な対応を報告し、タグをpushしない。

### 6. コミット & タグ

```bash
git add packages/bridge/package.json packages/bridge/CHANGELOG.md apps/mobile/lib/constants/app_constants.dart
git commit -m "chore(bridge): release vX.Y.Z"
git push origin main
git tag bridge/vX.Y.Z
git push origin bridge/vX.Y.Z
```

### 7. 完了確認

タグ push 後、GH Actions (`bridge-release.yml`) が自動実行される:
- テスト + 型チェック + ビルド
- npm publish（OIDC Trusted Publishing）
- GitHub Release 作成（CHANGELOG から自動抽出）

```bash
gh run list --workflow=bridge-release.yml --limit 1
```

成功を確認したら完了。
