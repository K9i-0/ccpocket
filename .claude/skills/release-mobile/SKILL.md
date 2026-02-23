---
name: release-mobile
description: モバイルアプリのリリース（バージョンbump + CHANGELOG + タグ → GH Actions で Shorebird release + ストア配布）
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(grep:*), Read, Edit
---

# モバイルアプリ リリース

Flutter モバイルアプリのリリースを行う。
タグ push 後は GH Actions が自動で Shorebird release + ストア配布 + GitHub Release を作成する。

## 前提

- main ブランチで作業中であること
- 未コミットの変更がないこと

## 手順

### 1. 現在のバージョン確認

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

`version: X.Y.Z+N` の形式。`+N` は build number。

### 2. 変更内容の確認

前回リリースからの差分を確認する:

```bash
# 前回のタグ（iOS/Android どちらか新しい方）
git tag -l 'ios/v*' 'android/v*' --sort=-v:refname | head -1

# 差分コミット（bridge 以外）
git log $(git tag -l 'ios/v*' 'android/v*' --sort=-v:refname | head -1)..HEAD --oneline -- apps/mobile/ CHANGELOG.md
```

### 3. バージョン bump

`apps/mobile/pubspec.yaml` の `version` を更新する:
- **semver 部分** (X.Y.Z): Semver に従う
- **build number** (+N): 必ずインクリメントする（iOS/Android ストアの要件）

### 4. CHANGELOG 更新

`CHANGELOG.md`（ルート）の先頭に新しいセクションを追加する。

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
git add apps/mobile/pubspec.yaml CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z+N"
git push origin main
```

### 6. タグ打ち

プラットフォームごとにタグを打つ。引数でプラットフォームが指定された場合はそれだけ、指定がなければ両方。

```bash
# iOS
git tag ios/vX.Y.Z+N
git push origin ios/vX.Y.Z+N

# Android
git tag android/vX.Y.Z+N
git push origin android/vX.Y.Z+N
```

### 7. 完了確認

タグ push 後、GH Actions が自動実行される:

| タグ | ワークフロー | 内容 |
|-----|------------|------|
| `ios/v*` | `ios-release.yml` | Shorebird release iOS → TestFlight → GitHub Release |
| `android/v*` | `android-release.yml` | Shorebird release Android → Google Play (internal draft) → GitHub Release |

```bash
gh run list --workflow=ios-release.yml --limit 1
gh run list --workflow=android-release.yml --limit 1
```

成功を確認したら完了。
