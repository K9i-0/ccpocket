---
name: release-bridge
description: Bridge Server のリリース（バージョンbump + CHANGELOG + タグ → GH Actions で npm publish）
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(grep:*), Read, Edit, AskUserQuestion
---

# Bridge Server リリース

Bridge Server (`@ccpocket/bridge`) のリリースを行う。
タグ push 後は GH Actions が自動で npm publish + GitHub Release を作成する。

## 前提

- main ブランチで作業中であること
- 未コミットの変更がないこと

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

### 2. バージョンをユーザーに確認

差分コミットの内容を分析し、AskUserQuestion でバージョンを確認する。

**選択肢の決定ルール:**
- `feat` コミットがある → **minor** を推奨（1番目の選択肢にし「(Recommended)」を付ける）
- `feat` がなく `fix` のみ → **patch** を推奨
- 破壊的変更（`!` 付きや BREAKING CHANGE）がある → **major** を推奨

選択肢は具体的なバージョン番号で提示する（例: 「1.2.0 (minor)」「1.1.1 (patch)」）。

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

### 5. コミット & タグ

```bash
git add packages/bridge/package.json packages/bridge/CHANGELOG.md
git commit -m "chore(bridge): release vX.Y.Z"
git push origin main
git tag bridge/vX.Y.Z
git push origin bridge/vX.Y.Z
```

### 6. 完了確認

タグ push 後、GH Actions (`bridge-release.yml`) が自動実行される:
- テスト + 型チェック + ビルド
- npm publish（OIDC Trusted Publishing）
- GitHub Release 作成（CHANGELOG から自動抽出）

```bash
gh run list --workflow=bridge-release.yml --limit 1
```

成功を確認したら完了。
