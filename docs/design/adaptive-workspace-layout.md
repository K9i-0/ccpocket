# Adaptive Workspace Layout

## Context

タブレット、フォルダブル横持ち、macOS での体験を改善するため、
CC Pocket のワークスペースを `1 / 2 / 3 pane` で可変表示できる
adaptive layout に拡張する。

ベンチマークとする Codex App には以下の特徴がある。

- 左: チャット一覧
- 中央: チャット詳細
- 右: Git などの補助機能
- 左右 pane は折りたたみ可能

CC Pocket でも同様に、
「一覧」「会話」「ツール」を同時に扱える構成を目指す。

## Goals

- 左にセッション一覧を常時表示できる
- 中央をチャット詳細の主表示領域とする
- 右に `Git` / `Explorer` などの補助画面を表示できる
- 画面幅で自動的に `1 / 2 / 3 pane` を切り替える
- `2 pane` 幅では右 pane を開くと左 pane を自動で折りたためる
- スマホ幅では既存の full-screen 遷移を維持する

## Non-Goals

- 4 pane 以上のレイアウト
- すべての modal / dialog の即時最適化
- 端末種別ベースの分岐

## Pane Roles

### Left pane

- セッション一覧
- 新規セッション
- 設定、ギャラリーなどの一部導線

### Center pane

- `ClaudeSessionScreen`
- `CodexSessionScreen`
- ワークスペースの主表示領域

### Right pane

- `GitScreen`
- `ExploreScreen`
- 将来的には `GalleryScreen` などの補助ビュー

原則として、
中央 pane は常に主役、
左右 pane は補助領域として扱う。

## Breakpoints

レイアウト切り替えは端末名ではなく、利用可能幅で判定する。

- `< 600dp` → 1 pane
- `600 - 1099dp` → 2 pane
- `1100dp+` → 3 pane

左 pane 幅は段階的に拡張する。

| 幅 | 左 pane |
|---|---|
| `600 - 1099dp` | `320dp` |
| `1100 - 1279dp` | `320dp` |
| `1280dp+` | `360dp` |

右 pane も同様に、
ツール画面が窮屈になりすぎない幅を優先して配分する。

## Layout Modes

### 1 pane

- 現行どおり full-screen
- 一覧と詳細は route push で遷移

### 2 pane

基本形は `left + center`。

- 左: セッション一覧
- 中央: チャット詳細

右 pane を開く要求が来た場合は、
`left + center` から `center + right` に切り替える。

- 左 pane を自動で折りたたむ
- 中央 pane は維持
- 右 pane に `Git` / `Explorer` を表示

右 pane を閉じたら、
左 pane を自動で再展開して `left + center` に戻す。

### 3 pane

- 左: セッション一覧
- 中央: チャット詳細
- 右: Git / Explorer などの補助画面

左右 pane はどちらも手動で折りたたみ可能とする。

## Route Structure

従来は `SessionListScreen` が `/` を担当し、
詳細画面を root stack に push していた。

まずは一覧常駐のための shell route を導入済みであり、
これは adaptive workspace の基礎としてそのまま利用する。

```
WorkspaceShellRoute (/)
├── WorkspacePlaceholderRoute
├── ClaudeSessionRoute
├── CodexSessionRoute
├── ExploreRoute
├── GalleryRoute
├── GitRoute
├── SettingsRoute
├── LicensesRoute
├── ChangelogRoute
├── AuthHelpRoute
├── SupporterRoute
├── QrScanRoute
├── MockPreviewRoute
├── SetupGuideRoute
└── DebugRoute
```

ただし最終形では、
「中央 pane の route」と「右 pane の tool panel」を分離して扱うのが望ましい。

## Recommended Architecture

### 現段階

- `WorkspaceShellRoute`
- 左一覧を `SessionListScreen(embedded: true)` として再利用
- child route を右側に表示

### 次段の拡張

shell 内で以下を分離する。

- 中央: conversation route host
- 右: tool panel host

この構成にすると、
チャット遷移とツール表示を別々に制御しやすい。

## Workspace State

layout の挙動を route だけで表現せず、
専用 state を持つ。

例:

```dart
class WorkspaceLayoutState {
  final bool showLeftPane;
  final bool showRightPane;
  final WorkspaceRightPaneTab? rightPaneTab;
}
```

`rightPaneTab` の候補:

- `git`
- `explore`
- `gallery`

これにより、
以下のような遷移を明示的に表現できる。

- 通常の 2 pane: `showLeftPane = true`, `showRightPane = false`
- 2 pane で Git を開く:
  `showLeftPane = false`, `showRightPane = true`, `rightPaneTab = git`
- 右 pane を閉じる:
  `showLeftPane = true`, `showRightPane = false`

## Navigation Rules

### 1 pane

- 従来どおり `push`

### 2 pane

- セッション選択時は `left + center`
- `Git` / `Explorer` を開くと `center + right`
- 右 pane を閉じると `left + center`

### 3 pane

- セッション選択で中央 pane を更新
- `Git` / `Explorer` を右 pane に表示
- 左右 pane は必要に応じて手動折りたたみ

## Session List Adaptation

`SessionListScreen` は `embedded` モードで再利用する。

### 通常モード

- `AppBar`
- `NestedScrollView + SessionListSliverAppBar`
- `FAB(New)`

### embedded モード

- 左 pane 専用ヘッダ `SessionListPaneHeader`
- `New`, `Settings`, `Gallery`, `Disconnect` をヘッダに集約
- `FAB` は非表示
- 本文は `HomeContent` を再利用

## Right Pane Targets

右 pane に表示したい対象は以下。

### 優先度 high

- `GitScreen`
- `ExploreScreen`

### 優先度 medium

- `GalleryScreen`

### 原則中央のまま

- `ClaudeSessionScreen`
- `CodexSessionScreen`

### 右 pane に載せないほうがよいもの

- 新規セッション作成
- 接続画面
- マシン管理
- アプリ全体設定
- 破壊的確認ダイアログ

## Placeholder

2 pane / 3 pane で中央または右が未選択の場合、
空白ではなく placeholder を表示する。

- アプリタイトル
- セッション選択を促す短い文言
- macOS / タブレットでの未選択状態を自然に見せる

## Modal Policy

今回の段階では modal 最適化は未完了。

### 方針

- セッション詳細由来の軽量補助UI:
  将来的に右 pane 文脈へ寄せる
- 設定、接続、マシン管理、破壊的確認:
  全体モーダルのまま維持

### 重点確認対象

- `showPlanDetailSheet`
- `showScreenshotSheet`
- `PromptHistorySheet`
- `UserMessageHistorySheet`
- `RewindActionSheet`
- `showBranchSelectorSheet`
- Git の file/hunk action sheet
- `showNewSessionSheet`
- `MachineEditSheet`

## Design Decisions

### 幅ベースの切り替え

端末名ベースではなく幅ベースで切り替える。
フォルダブルと macOS の可変ウィンドウに自然に対応できる。

### 中央 pane を常に優先

一覧よりも会話詳細を優先する。
`2 pane` 幅で右 pane を開くときに左を畳むのはこのため。

### 一覧ロジックの再利用

左 pane 専用の別 feature は作らず、
`SessionListScreen(embedded: true)` を再利用する。

### 右 pane は tool host として扱う

最終形では route を全面的に増やすより、
right tool host で `git / explore / gallery` を切り替えるほうが扱いやすい。

## Risks

- `2 pane` 幅での自動折りたたみは、戻る挙動の設計を誤ると混乱を生みやすい
- `showModalBottomSheet` / `showDialog` が全画面基準のまま残る箇所がある
- `280dp` 幅で表示は成立しても、Git や Explorer は情報密度的に窮屈になる可能性がある
- 中央 route と右 pane state の責務分離が曖昧だと、shell が複雑化しやすい

## Implementation Plan

1. `WorkspaceLayoutCubit` を追加
2. shell を `1 / 2 / 3 pane` 対応に拡張
3. 右 pane host を追加
4. `Git` と `Explorer` を先に右 pane 対応
5. `2 pane` 幅での `left auto collapse / restore` を導入
6. 左右 pane の手動トグルを追加

## Validation

最低限の確認項目は以下。

- `dart analyze apps/mobile`
- `flutter test`
- iPad mini 横持ち相当 (`>= 600dp`) で 2 pane になること
- iPad Pro / macOS 幅 (`>= 1100dp`) で 3 pane になること
- `2 pane` 幅で `Git` を開くと左 pane が自動で畳まれること
- 右 pane を閉じると左 pane が自動で戻ること
- 3 pane 幅で `Git` / `Explorer` が右 pane に共存表示されること
- スマホ幅 (`< 600dp`) で従来どおり full-screen 遷移すること

## Related Files

| ファイル | 役割 |
|---|---|
| `apps/mobile/lib/features/session_list/workspace_shell_screen.dart` | 現行 shell と 1/2 pane 切り替え |
| `apps/mobile/lib/router/app_router.dart` | shell 配下の route 構成 |
| `apps/mobile/lib/features/session_list/session_list_screen.dart` | 一覧の通常/embedded 表示 |
| `apps/mobile/lib/features/session_list/widgets/session_list_app_bar.dart` | 左 pane 用ヘッダ |
