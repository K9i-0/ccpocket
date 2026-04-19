# Two-Pane Layout

## Context

タブレット、フォルダブル横持ち、macOS での体験を改善するため、
セッション一覧を常時左ペインに表示し、右ペインにセッション画面や関連画面を表示する
`2ペインモード` を導入する。

既存UIは各画面がスマホ幅で成立しているため、
「左右それぞれがスマホ最小幅を満たせるなら 2ペインにする」という方針を採用する。

## Goals

- セッション一覧を常時左に表示する
- 右側にセッション画面やその遷移先画面を表示する
- 画面幅で自動的に 1ペイン / 2ペインを切り替える
- スマホ幅では既存の遷移体験を維持する

## Non-Goals

- モーダル/ダイアログの全面的な最適化
- 3ペイン以上のレイアウト
- 端末種別ベースの分岐

## Breakpoints

`2ペインモード` は端末種別ではなく、利用可能幅で判定する。

- `< 600dp` → 1ペイン
- `>= 600dp` → 2ペイン

左ペイン幅は段階的に拡張する。

| 幅 | 左ペイン |
|---|---|
| `600 - 719dp` | `280dp` |
| `720 - 1023dp` | `320dp` |
| `1024dp+` | `360dp` |

これにより iPad mini 横持ち、フォルダブル横持ち、macOS ウィンドウ拡張時を自然にカバーする。

## Route Structure

従来は `SessionListScreen` が `/` のルートで、
詳細画面 (`ClaudeSessionRoute`, `CodexSessionRoute`, `SettingsRoute` など) を
root stack に push していた。

2ペイン化では一覧を常駐させるため、親 shell route を導入する。

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

### 1ペイン時

- placeholder のときは `SessionListScreen` を表示
- 詳細 route が active のときはその画面を全面表示

### 2ペイン時

- 左ペインに `SessionListScreen(embedded: true)` を常駐表示
- 右ペインに child route を表示
- 初期状態は `WorkspacePlaceholderRoute` を表示

## Layout

`WorkspaceShellScreen` が `LayoutBuilder` で利用可能幅を監視し、
1ペイン / 2ペインを切り替える。

### 1ペイン

- 現行挙動を維持
- 一覧は `Scaffold + NestedScrollView + SliverAppBar`
- 詳細画面は full-screen push

### 2ペイン

- `Row`
  - 左: セッション一覧
  - 仕切り線: 1px
  - 右: `AutoRouter` の child route

## Session List Adaptation

`SessionListScreen` に `embedded` フラグを追加し、
同一のデータ取得・アクションロジックを保ったまま、表示レイアウトだけ切り替える。

### 通常モード

- 既存の `AppBar`
- `NestedScrollView` + `SessionListSliverAppBar`
- `FAB(New)`

### embedded モード

- 左ペイン専用ヘッダ `SessionListPaneHeader`
- `New`, `Settings`, `Gallery`, `Disconnect` をヘッダに集約
- `FAB` は非表示
- 本文は `HomeContent` をそのまま再利用

## Navigation Rules

### 1ペイン

- 従来どおり `push`

### 2ペイン

- 左一覧から右詳細への遷移は `replace`
- セッション切り替え時に右ペインの stack が深くなり続けるのを防ぐ

この方針により、
「左の一覧は固定、右の作業対象だけが差し替わる」挙動になる。

## Placeholder

2ペイン初期状態では右側に placeholder を表示する。

- 空白画面ではなく、アプリタイトルと
  “Select a session on the left, or start a new one.” を表示
- macOS / タブレットで未選択状態が不自然に見えないようにする

## Modal Policy

今回の段階では、モーダル最適化は未完了である。

### 当面のルール

- 詳細画面由来の軽量補助UI:
  将来的に右ペイン文脈へ寄せる
- 設定、接続、マシン管理、破壊的確認:
  当面は全体モーダルのまま維持する

### 今後の重点確認対象

- `showNewSessionSheet`
- `MachineEditSheet`
- `showPlanDetailSheet`
- `showScreenshotSheet`
- `PromptHistorySheet`
- `UserMessageHistorySheet`
- `RewindActionSheet`
- `showBranchSelectorSheet`
- Git の file/hunk action sheet

## Design Decisions

### 幅ベースの切り替え

端末名ベースではなく幅ベースで切り替える。
フォルダブルや macOS の可変ウィンドウに素直に対応できる。

### 一覧ロジックの再利用

2ペイン専用に別の一覧 feature は作らず、
`SessionListScreen` の `embedded` モードで再利用する。
状態管理や bridge 連携の重複を避けられる。

### child route をそのまま右ペインに載せる

セッション画面だけでなく `Settings`, `Gallery`, `Git`, `Explore` も
同じ shell 配下に置くことで、
「右ペインに関連画面を表示する」要件を単一のルーティング設計で満たす。

## Risks

- `replace` ベースのため、右ペイン内で期待する戻る挙動が一部変わる可能性がある
- `showModalBottomSheet` / `showDialog` が依然として全画面基準で出る箇所がある
- 既存画面はスマホ幅では成立していても、`280dp` 幅で情報密度が高い画面は窮屈に見える可能性がある

## Validation

最低限の確認項目は以下。

- `dart analyze apps/mobile`
- `flutter test`
- iPad mini 横持ち相当 (`>= 600dp`) で 2ペイン表示されること
- スマホ幅 (`< 600dp`) で従来どおり full-screen 遷移すること
- 左一覧から連続で別セッションを選んでも右側 stack が増殖しないこと
- `Settings`, `Gallery`, `Git`, `Explore` が右ペインに表示されること

## Related Files

| ファイル | 役割 |
|---|---|
| `apps/mobile/lib/features/session_list/workspace_shell_screen.dart` | 1/2ペイン切り替えと shell |
| `apps/mobile/lib/router/app_router.dart` | shell 配下の route 構成 |
| `apps/mobile/lib/features/session_list/session_list_screen.dart` | 一覧の通常/embedded 表示 |
| `apps/mobile/lib/features/session_list/widgets/session_list_app_bar.dart` | 左ペイン用ヘッダ |
