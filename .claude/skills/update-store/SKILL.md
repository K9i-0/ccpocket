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
- **sim-tap.swift**: 同梱のSwiftスクリプト（`scripts/sim-tap.swift`）。macOSアクセシビリティAPIでSimulatorのネイティブダイアログ（通知許可等）をラベル指定でタップできる

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

**iPhone スクリーンショット（8シナリオ）:**

| Key | シナリオ名 | 内容 | テーマ |
|-----|-----------|------|--------|
| `01_session_list` | Session List (Recent) | ホーム画面（名前付きセッション） | ライト |
| `02_approval_list` | Session List | 承認待ち一覧（3セッション） | ライト |
| `03_multi_question` | Multi-Question Approval | 質問UI（3問） | ライト |
| `04_markdown_input` | Markdown Input | Markdown箇条書き入力 | ライト |
| `05_image_attach` | Image Attach | 画像添付UI | ライト |
| `06_git_diff` | Git Diff | Diff表示画面 | ライト |
| `07_new_session` | New Session | 新規セッションシート | ライト |
| `08_dark_theme` | Session List | 承認待ち一覧（ダークモード訴求） | ダーク |

**iPad スクリーンショット（5シナリオ）:**

| Key | シナリオ名 | 内容 | テーマ |
|-----|-----------|------|--------|
| `01_workspace_overview` | Workspace Overview | 左一覧 + 中央チャット + 右Git | ライト |
| `02_workspace_explorer` | Workspace Explorer | 左一覧 + 中央チャット + 右Explorer | ライト |
| `03_approval_context` | Approval In Context | 左一覧 + 中央承認UI | ライト |
| `04_approval_queue` | Approval Queue | 複数の承認待ちセッションを同時に確認 | ライト |
| `05_dark_workspace` | Dark Workspace | 3-pane ワークスペースのダークテーマ訴求 | ダーク |

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

**ソフトウェアキーボードを無効化**（全デバイス共通、セッション冒頭で1回実行）:
```bash
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool true
```
これによりソフトウェアキーボードが表示されなくなり、日本語キーボードがスクショに映り込む問題を防止する。

iPhone 17 Proシミュレーターを起動し、ライトモードに設定:
```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl ui booted appearance light
```

#### 4-2. アプリ起動 & Marionette接続

dart-mcp `launch_app` でアプリを起動:
```
root: /Users/k9i-mini/Workspace/ccpocket/apps/mobile
device: <iPhone 17 Pro の device ID>
```

起動後、dart-mcp `list_running_apps` でDTD URIを取得し、`connect_dart_tooling_daemon` で接続。

dart-mcp `get_app_logs` でVM Service URIを取得し、marionette `connect` で接続。

#### 4-3. 各シナリオのスクショ撮影

**テーマ設定**: アプリ起動後、カスタムエクステンションでテーマを切り替える（01〜07はライトテーマ）:
- marionette `call_custom_extension`: `ccpocket.setTheme` / `{ "theme": "light" }`
- 値: `light`, `dark`, `system`

**言語設定**: 必要に応じてカスタムエクステンションで言語を切り替える:
- marionette `call_custom_extension`: `ccpocket.setLocale` / `{ "locale": "en" }`
- 値: `en`, `ja`, `zh`, `""` (システムデフォルト)

選択された各シナリオに対して:

1. **遷移**: marionette `call_custom_extension`
   - extension: `ccpocket.navigateToStoreScenario`
   - params: `{ "scenario": "<シナリオ名>" }`

2. **待機**: 2-3秒（描画完了を待つ。New SessionやImage Attachなど複雑なUIは3秒推奨）

3. **撮影**:
   ```bash
   xcrun simctl io booted screenshot apps/mobile/fastlane/screenshots/en-US/<key>.png
   ```

4. **戻る**: marionette `call_custom_extension`
   - extension: `ccpocket.popToRoot`

5. **待機**: 1秒（ルートへの遷移完了）

**08_dark_theme の撮影**: 01〜07撮影後、`ccpocket.setTheme` で `dark` に切り替え、Session List シナリオを撮影する。

#### 4-4. アプリ停止

dart-mcp `stop_app` でアプリを停止。
**シミュレーターはシャットダウンしない**。次のデバイスの起動に進む。

### Step 5: iPad スクリーンショット撮影（選択された場合）

iPad は iPhone とは別セットを撮影する。既存の mobile 専用シナリオを流用せず、
workspace レイアウト前提の 5 シナリオを撮る。

#### 5-1. iPadシミュレーターの全画面表示を保証

iPadでアプリが互換モード（iPhone用の小さいウィンドウ + 黒帯）で起動する場合がある。
これはシミュレーターのキャッシュが原因のため、撮影前にシミュレーターをリセットする:

```bash
# シミュレーターをシャットダウン（起動中の場合）
xcrun simctl shutdown "iPad Pro 13-inch (M4)" 2>/dev/null || true

# シミュレーターのコンテンツとキャッシュをリセット
xcrun simctl erase "iPad Pro 13-inch (M4)"

# 起動
xcrun simctl boot "iPad Pro 13-inch (M4)" 2>/dev/null || true
```

**重要**: `erase` を実行するとアプリもアンインストールされるため、必ずクリーンインストールが行われる。これにより互換モード問題を防止する。

**横向き前提**: iPad スクショは landscape で撮る。起動後に `sim-tap.swift` の準備コマンドを必ず実行する:
```bash
swift .claude/skills/update-store/scripts/sim-tap.swift prepare-store ipad
```
これで以下をまとめて行う:
- `simctl privacy grant` で通知 / 音声認識 / マイク権限を事前付与
- Simulator を前面化
- `Device > Orientation > Landscape Left` で iPad を明示的に横向き固定
- 通知許諾などのネイティブダイアログを dismiss

撮影中に向きが崩れた場合や許諾ダイアログが再表示された場合も、スクショを撮る前に再度これを実行する。

**ネイティブダイアログの自動dismiss**: `erase` 後は通知・音声認識・マイク等のパーミッションダイアログが再度表示される。

**事前権限付与** (erase 直後、アプリ起動前に実行):
```bash
xcrun simctl privacy booted grant notifications com.k9i.ccpocket
xcrun simctl privacy booted grant speech-recognition com.k9i.ccpocket
xcrun simctl privacy booted grant microphone com.k9i.ccpocket
```
これによりダイアログの表示自体を防止できる。`simctl privacy` が失敗する場合は以下のフォールバックを使う。

**フォールバック: sim-tap.swift の個別コマンド**:
ダイアログはホーム画面ではなく**セッション画面遷移後**に表示されることがある。
最初のシナリオ遷移後にdismissし、必要なら撮り直す。

AX API でボタンが見つからない場合（特にiPad）、CGEvent ベースのクリックで自動フォールバックする:
```bash
swift .claude/skills/update-store/scripts/sim-tap.swift rotate right
swift .claude/skills/update-store/scripts/sim-tap.swift dismiss-dialogs ipad
swift .claude/skills/update-store/scripts/sim-tap.swift dismiss-dialogs iphone
```

従来の個別タップも引き続き使用可能:
```bash
while swift .claude/skills/update-store/scripts/sim-tap.swift tap "許可" 2>/dev/null; do sleep 1; done
```

#### 5-2. シナリオ撮影 & 解像度検証

**テーマ設定**: iPad 側は `Dark Workspace` 以外をライトテーマで撮る。アプリ起動後に最初に一度:
marionette `call_custom_extension`
- extension: `ccpocket.setTheme`
- params: `{ "theme": "light" }`

`Dark Workspace` はシナリオ側で一時的にダークへ切り替わるため、個別に `setTheme dark` する必要はない。

各シナリオに対して:

1. marionette `call_custom_extension`
   - extension: `ccpocket.navigateToStoreScenario`
   - params: `{ "scenario": "<シナリオ名>" }`
   - 値:
     - `Workspace Overview`
     - `Workspace Explorer`
     - `Approval In Context`
     - `Approval Queue`
     - `Dark Workspace`

2. 2-3秒待機

3. 撮影
   ```bash
   swift .claude/skills/update-store/scripts/sim-tap.swift capture-store ipad apps/mobile/fastlane/screenshots/en-US/ipad_<key>.png
   ```

4. marionette `call_custom_extension`
   - extension: `ccpocket.popToRoot`

5. 1秒待機

#### 5-3. 解像度検証

撮影後、スクショの解像度がiPadのネイティブ解像度と一致するか検証する:

```bash
swift .claude/skills/update-store/scripts/sim-tap.swift capture-store ipad apps/mobile/fastlane/screenshots/en-US/ipad_<key>.png

# 解像度検証（互換モード検出）
WIDTH=$(sips -g pixelWidth apps/mobile/fastlane/screenshots/en-US/ipad_<key>.png | tail -1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight apps/mobile/fastlane/screenshots/en-US/ipad_<key>.png | tail -1 | awk '{print $2}')
echo "Screenshot: ${WIDTH}x${HEIGHT}"
# iPad Pro 13-inch (M4) landscape: 2752x2064 が期待値
# 解像度が大幅に小さい場合は互換モードで起動しているため、eraseからやり直す
```

もし解像度が期待値と異なる場合は、`flutter clean` → `flutter build ios --simulator` でクリーンビルドしてやり直すこと。

#### 5-4. アプリ停止

dart-mcp `stop_app` でアプリを停止。
**シミュレーターはシャットダウンしない**（compose.sh 実行や確認に支障はない）。

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

| シナリオ名（extension引数） | ファイルキー（スクショファイル名） | テーマ |
|---------------------------|-------------------------------|--------|
| Session List (Recent) | `01_session_list` | ライト |
| Session List | `02_approval_list` | ライト |
| Multi-Question Approval | `03_multi_question` | ライト |
| Markdown Input | `04_markdown_input` | ライト |
| Image Attach | `05_image_attach` | ライト |
| Git Diff | `06_git_diff` | ライト |
| New Session | `07_new_session` | ライト |
| Session List | `08_dark_theme` | ダーク |

## 注意事項

- **New Session シナリオ**: ボトムシートが`addPostFrameCallback`で自動表示されるため、3秒待機推奨
- **Markdown Input シナリオ**: DraftServiceで入力欄にテキストが事前セットされる。キーボードは非表示のまま撮影すること（`ConnectHardwareKeyboard` を有効化済み）
- **Image Attach シナリオ**: モック画像が自動的に添付される
- **シミュレーターデバイス名**: Xcode バージョンにより正確な名前が異なる場合がある。`xcrun simctl list devices available` で確認
- **compose.sh**: ImageMagick (`convert` / `magick`) が必要。PNGタイムスタンプを除去して不要なgit diffを防止
- **iPad スクショ**: landscape 前提。raw スクショも framed 画像も `2752x2064` を基準に扱う
