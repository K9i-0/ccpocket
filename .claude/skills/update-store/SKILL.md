---
name: update-store
description: ストア情報の更新自動化 — スクリーンショット撮影（シミュレーター × モック画面 × Marionette MCP）とメタデータテキスト更新。ストア更新、スクショ更新、App Store / Google Play のメタデータ更新、リリースノート作成の際に使用すること。
---

# Update Store

ストアスクリーンショットの自動撮影・合成と、メタデータテキスト（description, release_notes等）の更新を行う。

## 前提

- デバッグモードのアプリにはストアスクショ用のカスタムエクステンション（`ccpocket.navigateToStoreScenario`）が登録済み
- Marionette MCPの`call_custom_extension`が使用可能
- ImageMagickがインストール済み（`compose.sh`で使用）

## ワークフロー

### Step 1: バージョン確認 & 変更分析

```bash
# 最新リリースタグ
git tag -l 'ios/v*' --sort=-v:refname | head -1

# 現在のバージョン
grep '^version:' apps/mobile/pubspec.yaml

# 前回リリースからの変更コミット
git log $(git tag -l 'ios/v*' --sort=-v:refname | head -1)..HEAD --oneline -- apps/mobile/
```

CHANGELOGの最新セクションも確認:
```bash
head -80 CHANGELOG.md
```

変更内容を分析し、UI変更があったかどうかを判断する。

### Step 2: 更新対象の選択

AskUserQuestion（multiSelect）で更新対象を確認する。
変更分析結果に基づいて推奨をdescriptionに含める。

**スクリーンショット（8シナリオ）:**

| Key | シナリオ名 | 内容 |
|-----|-----------|------|
| `01_session_list` | Session List (Recent) | ホーム画面（最近のセッション） |
| `02_approval_list` | Session List | 承認待ち一覧（3セッション） |
| `03_multi_question` | Multi-Question Approval | 質問UI（3問） |
| `04_markdown_input` | Markdown Input | Markdown箇条書き入力 |
| `05_named_sessions` | Session List (Named) | 名前付きセッション |
| `06_image_attach` | Image Attach | 画像添付UI |
| `07_git_diff` | Git Diff | Diff表示画面 |
| `08_new_session` | New Session | 新規セッションシート |

**メタデータテキスト:**

| ファイル | 対象 |
|---------|------|
| `fastlane/metadata/en-US/release_notes.txt` | iOS リリースノート (EN) |
| `fastlane/metadata/ja/release_notes.txt` | iOS リリースノート (JA) |
| `fastlane/metadata/en-US/description.txt` | App Store 説明文 (EN) |
| `fastlane/metadata/ja/description.txt` | App Store 説明文 (JA) |
| `fastlane/metadata/en-US/promotional_text.txt` | プロモーションテキスト (EN) |
| `fastlane/metadata/android/en-US/full_description.txt` | Play Store 説明文 (EN) |
| `fastlane/metadata/android/ja-JP/full_description.txt` | Play Store 説明文 (JA) |
| `fastlane/metadata/android/en-US/changelogs/default.txt` | Play Store リリースノート (EN) |
| `fastlane/metadata/android/ja-JP/changelogs/default.txt` | Play Store リリースノート (JA) |

上記のファイルパスは `apps/mobile/` からの相対パス。

### Step 3: メタデータテキスト更新（選択された場合）

CHANGELOGの内容をベースに:
- **release_notes** — CHANGELOG最新セクションを簡潔にまとめる
- **description** — 新機能に応じて追記・修正
- **promotional_text** — キャッチコピーを更新

更新後、AskUserQuestionで内容確認を挟む。

### Step 4: iPhone スクリーンショット撮影（選択された場合）

#### 4-1. デバイス確認 & シミュレーター起動

```bash
xcrun simctl list devices available | grep -E "iPhone 17|iPad Pro.*13"
```

iPhone 17 Proシミュレーターを起動し、ダークモードに設定:
```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl ui booted appearance dark
```

**重要**: アプリは `ThemeMode.system` がデフォルトのため、シミュレーターの外観をダークに設定するだけでダークテーマが適用される。

#### 4-2. アプリ起動 & Marionette接続

dart-mcp `launch_app` でアプリを起動:
```
root: /Users/k9i-mini/Workspace/ccpocket/apps/mobile
device: <iPhone 17 Pro の device ID>
```

起動後、dart-mcp `list_running_apps` でDTD URIを取得し、`connect_dart_tooling_daemon` で接続。

dart-mcp `get_app_logs` でVM Service URIを取得し、marionette `connect` で接続。

#### 4-3. 各シナリオのスクショ撮影

選択された各シナリオに対して:

1. **遷移**: marionette `call_custom_extension`
   - extension: `ccpocket.navigateToStoreScenario`
   - params: `{ "scenario": "<シナリオ名>" }`

2. **待機**: 2-3秒（描画完了を待つ。New SessionやImage Attachなど複雑なUIは3秒推奨）

3. **Markdown Input のみ — キーボード表示**:
   marionette `tap` で入力フィールドをタップしてフォーカスを当て、ソフトウェアキーボードを表示させる。
   ```
   marionette tap (text field をタップ)
   ```
   1秒待機してキーボード表示完了を待つ。

4. **撮影**:
   ```bash
   xcrun simctl io booted screenshot apps/mobile/fastlane/screenshots/en-US/<key>.png
   ```

5. **戻る**: marionette `call_custom_extension`
   - extension: `ccpocket.popToRoot`

6. **待機**: 1秒（ルートへの遷移完了）

#### 4-4. アプリ停止

dart-mcp `stop_app` でアプリを停止。

```bash
xcrun simctl shutdown "iPhone 17 Pro" 2>/dev/null || true
```

### Step 5: iPad スクリーンショット撮影（選択された場合）

Step 4と同じフローをiPadで実行。

```bash
xcrun simctl boot "iPad Pro 13-inch (M4)" 2>/dev/null || true
xcrun simctl ui booted appearance dark
```

保存先は `ipad_<key>.png`:
```bash
xcrun simctl io booted screenshot apps/mobile/fastlane/screenshots/en-US/ipad_<key>.png
```

アプリ停止後:
```bash
xcrun simctl shutdown "iPad Pro 13-inch (M4)" 2>/dev/null || true
```

### Step 6: スクリーンショット合成 & 配置

```bash
cd apps/mobile && bash fastlane/screenshots/compose.sh
```

このスクリプトが行うこと:
- iPhone/iPad の raw スクショにデバイスフレーム・テキストオーバーレイを追加
- en-US と ja の両方のframed画像を生成
- `fastlane/screenshots/store/` へコピー（fastlane deliver用）
- `fastlane/metadata/android/` へコピー（Google Play用）
- `docs/images/screenshots.png` を更新（READMEバナー）

### Step 7: 確認

```bash
# 生成画像の確認
ls -la apps/mobile/fastlane/screenshots/store/en-US/
ls -la apps/mobile/fastlane/screenshots/store/ja/

# 変更ファイル一覧
git diff --stat
```

## シナリオ名 ↔ ファイルキー対応表

| シナリオ名（extension引数） | ファイルキー（スクショファイル名） |
|---------------------------|-------------------------------|
| Session List (Recent) | `01_session_list` |
| Session List | `02_approval_list` |
| Multi-Question Approval | `03_multi_question` |
| Markdown Input | `04_markdown_input` |
| Session List (Named) | `05_named_sessions` |
| Image Attach | `06_image_attach` |
| Git Diff | `07_git_diff` |
| New Session | `08_new_session` |

## 注意事項

- **New Session シナリオ**: ボトムシートが`addPostFrameCallback`で自動表示されるため、3秒待機推奨
- **Markdown Input シナリオ**: DraftServiceで入力欄にテキストが事前セットされる。撮影前にmarionetteで入力フィールドをtapしてキーボードを表示させること
- **Image Attach シナリオ**: モック画像が自動的に添付される
- **シミュレーターデバイス名**: Xcode バージョンにより正確な名前が異なる場合がある。`xcrun simctl list devices available` で確認
- **compose.sh**: ImageMagick (`convert` / `magick`) が必要。PNGタイムスタンプを除去して不要なgit diffを防止
