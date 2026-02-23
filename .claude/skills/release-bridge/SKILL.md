---
name: release-bridge
description: Bridge Server のリリース（バージョンbump + CHANGELOG + タグ → GH Actions で npm publish）
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(grep:*), Read, Edit
---

# Bridge Server リリース

Bridge Server (`@ccpocket/bridge`) のリリースを行う。
タグ push 後は GH Actions が自動で npm publish + GitHub Release を作成する。

## 前提

- main ブランチで作業中であること
- 未コミットの変更がないこと

## 手順

### 1. 現在のバージョン確認

```bash
grep '"version"' packages/bridge/package.json
```

### 2. 変更内容の確認

前回リリースのタグからの差分を確認する:

```bash
# 前回のタグ
git tag -l 'bridge/v*' --sort=-v:refname | head -1

# 差分コミット
git log $(git tag -l 'bridge/v*' --sort=-v:refname | head -1)..HEAD --oneline -- packages/bridge/
```

### 3. バージョン bump

`packages/bridge/package.json` の `version` を更新する。
Semver に従う:
- **patch**: バグ修正のみ
- **minor**: 新機能追加（後方互換あり）
- **major**: 破壊的変更

### 4. CHANGELOG 更新

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

ステップ 2 で確認したコミットを元に、Added / Changed / Fixed に分類する。

### 5. コミット

```bash
git add packages/bridge/package.json packages/bridge/CHANGELOG.md
git commit -m "chore(bridge): release vX.Y.Z"
git push origin main
```

### 6. タグ打ち

```bash
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
