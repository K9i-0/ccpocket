# Codex Additional Writable Roots Mobile UI

## Context

Bridge 側では、Codex `thread/start` 前に `config/read` で effective `writable_roots` を取得し、
New Session で指定された追加 roots を merge して送る方針とする。

このドキュメントは、その機能をモバイルの New Session UI にどう載せるかを定義する。

対象は `apps/mobile/lib/widgets/new_session_sheet.dart` を中心とした New Session / Resume Session の UI。

関連設計:

- [codex-additional-writable-roots.md](/Users/kotahayashi/Workspace/ccpocket/docs/design/codex-additional-writable-roots.md)

## Goal

- Codex の New Session シートでのみ追加 writable projects を指定できる
- 「既存 config の writable roots に追加で有効になる」ことが UI から理解できる
- Chip ベースで軽く編集できる
- 候補は recent project と過去 add-dir 入力履歴から出せる
- Resume / Edit Settings Then Start でも可能な限り同じ UI を使う

## Non-Goals

- Claude 用 UI
- ファイル単位の path picker
- OS のフォルダ選択ダイアログ統合

## Placement

表示条件:

- `provider == Provider.codex` のときのみ表示

表示位置:

1. Project path
2. Additional Writable Projects
3. Codex profile
4. Approval
5. Sandbox
6. Model
7. Reasoning
8. Worktree
9. Advanced

理由:

- project path と意味的に最も近い
- `profile` や `sandbox` より前に見せることで「どこに書き込むか」の設定として理解しやすい

## Interaction Model

セクションは 3 要素で構成する。

### 1. Header

- タイトル: `Additional Writable Projects`
- 右側に `info_outline`
- info は tooltip か tap で補足を出す

補足文言の意図:

- グローバル / プロジェクト config で既に有効な writable roots に追加される
- このセッション用の追加設定である
- Resume 時には再利用される場合がある

英語イメージ:

`Adds more writable project folders on top of the roots already enabled by your Codex config for this workspace.`

### 2. Selected chips

- 追加済み roots を `InputChip` で表示
- chip には folder icon
- ラベルは basename を優先
- subtitle は出さず、full path は tooltip か下段 caption で補う
- remove icon で個別削除

chip 表示ルール:

- 1 行に収まらなければ `Wrap`
- 長い path でもラベルは末尾フォルダ名中心にして密度を保つ

### 3. Add action

- `+ Add Project` のアウトラインボタン or tonal button
- tap で候補 picker sheet を開く

## Candidate Picker Sheet

追加候補は専用 bottom sheet で選ばせる。

表示順:

1. `Recent Projects`
2. `Previously Added`
3. `Enter Path Manually`

### Recent Projects

ソース:

- `recentProjects(...)`

除外:

- 現在の `projectPath`
- すでに選択済みの roots

表示:

- project name
- 短縮 path (`shortenPath`)
- tap で即追加

### Previously Added

ソース:

- add-dir 用のローカル履歴

意図:

- `recentProjects` に出ない補助 workspace を再利用しやすくする
- 例: `/Users/me/Workspace/codex`, `/Users/me/Workspace/openclaw`

除外:

- すでに選択済みの roots

### Enter Path Manually

- シート下部に `TextField`
- `Add` ボタンで追加
- ここでは path の存在確認や allowlist 確認はしない
- 送信時のバリデーションは Bridge 側が担う

アプリ側では最低限の整形だけ行う:

- trim
- 空文字 reject
- 重複 reject

## New Session Sheet Behavior

### Empty state

何も追加していないとき:

- caption を 1 行表示
- 例: `Use this when Codex needs to edit another project or workspace.`

### Non-empty state

- chips を表示
- caption は薄く残すか、省略する
- `+ Add Project` は常に残す

### Read-only sandbox

read-only sandbox でもセクションは隠さない。

理由:

- Resume 時に sandbox mode が変わる可能性がある
- 入力を失わないほうが自然

ただし note を追加する:

- `Writable roots take effect when sandbox mode allows writes.`

## Resume / Edit Settings Then Start

方針:

- できるだけ有効にする

適用対象:

- `RecentSession` 長押し → `Edit Settings Then Start`
- active session 由来の再開導線
- 将来の explicit resume edit flow

挙動:

- 既存 session に `additionalWritableRoots` があれば初期値に入れる
- `lockProvider: true` の場合でも、Codex ならこのセクションは表示する

理由:

- provider が固定でも writable roots は編集したい
- resume 前に 1 つだけ追加したいケースが自然にある

## Persistence Strategy

UI 観点では 3 種のデータを分ける。

### 1. Session params

`NewSessionParams` に追加:

- `additionalWritableRoots: List<String>`

用途:

- New Session の submit payload
- Resume / Edit 再利用

### 2. Previously added history

ローカル履歴として保持する。

候補:

- `SharedPreferences`
- key 例: `codex_additional_writable_roots_history_v1`

用途:

- candidate picker の `Previously Added`

ルール:

- path 単位で dedupe
- 直近使用順
- 上限 20〜30 件

### 3. Session recreation state

Bridge / recent session から復元された `additionalWritableRoots` を
`NewSessionParams.initialParams` に渡す。

これは global default ではない。

理由:

- 毎回別 project に同じ roots を自動で付けるのは危険

## Defaults

`session_start_defaults_v1` には含めない。

理由:

- 追加 writable roots は project 固有性が高い
- 直前の別 project の roots が次回にも自動付与されると危険

代わりに:

- `Previously Added` 候補には残す
- per-session / per-recent-session 初期値としてのみ復元する

## Visual Design

既存 `new_session_sheet.dart` のトーンに合わせる。

### Section container

- 他の selector field と同じ card / surface
- ただしここは list-editing 要素なので、1 つの `modeSelectorField` にはしない
- 独立 section widget とする

### Chips

- `InputChip`
- compact density
- icon: `Icons.folder_outlined`
- remove: close icon

### Add button

- `OutlinedButton.icon`
- icon: `Icons.add`
- label: `Add Project`

### Candidate rows

- `ListTile` ベース
- title: project name or basename
- subtitle: shortened path

## Widget Split

`new_session_sheet.dart` が長いため、追加時は独立 widget に分ける。

候補:

- `apps/mobile/lib/widgets/codex_additional_writable_roots_section.dart`
- `apps/mobile/lib/widgets/additional_writable_roots_picker_sheet.dart`

状態は local state で十分。

新規 Cubit は不要。

## Suggested API Changes

### `NewSessionParams`

追加:

```dart
final List<String> additionalWritableRoots;
```

### `showNewSessionSheet`

既存の `initialParams` で十分。

### `RecentSession`

Bridge 側の実装後、必要なら追加:

```dart
final List<String> codexAdditionalWritableRoots;
```

または `codexSettings` 由来で持つ。

## Validation Rules

アプリ側:

- trim 後 empty は reject
- selected chips と重複なら reject

Bridge 側:

- absolute path 正規化
- allowlist 検証
- invalid path は start reject

エラー表示:

- start 失敗時は既存の error toast / snackbar に乗せる

## Accessibility

- remove chip は `delete` semantics を持つ
- `Add Project` ボタンに `ValueKey('dialog_codex_add_writable_root_button')`
- section root に `ValueKey('dialog_codex_additional_writable_roots_section')`
- chips には path ベースの stable key を付ける

## Localization Keys

追加候補:

- `additionalWritableProjects`
- `additionalWritableProjectsHint`
- `additionalWritableProjectsTooltip`
- `addProject`
- `previouslyAdded`
- `enterPathManually`
- `writableRootsReadOnlyNote`
- `additionalWritableProjectsEmptyHint`

## Test Plan

### Widget tests

- Codex 選択時のみ section が表示される
- Claude では表示されない
- chip 追加 / 削除ができる
- candidate picker から recent project を追加できる
- 同じ path は重複追加されない

### New Session integration

- `NewSessionParams.additionalWritableRoots` が submit に含まれる
- `initialParams` から復元される
- `Edit Settings Then Start` でも初期表示される

## Recommendation

初期実装は次の範囲に留める。

- Codex 専用 section を New Session シートに追加
- chip + add button + picker sheet
- 候補は `recentProjects` と local history
- `session_start_defaults` には保存しない
- resume/edit-start では `initialParams` から復元する

これで UI は軽く保ちつつ、Bridge の merge 方式と整合する。
