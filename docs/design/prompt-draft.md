# プロンプト下書き機能 (Prompt Draft)

## Context

ユーザーをロックインするための新機能。プロンプト履歴（過去の記録）と対になる「未来の計画」として、エージェントに送るプロンプトを事前に準備・推敲できる。

- Markdownエディタで下書きを作成
- 画像を添付して管理
- Bridge経由のClaude Codeセッションで壁打ち（プロンプトの改善）
- 下書きから直接新規セッションを開始（Execute）

## 設計判断

| 判断 | 決定 | 理由 |
|------|------|------|
| 画像保存 | ファイルシステム（app docs） | sqfliteにbase64を入れるとDB肥大化・クエリ低速化 |
| 下書き一覧UI | 独立画面（AppBarアイコン） | BottomSheetでは狭い、HomeのTabは過密 |
| 壁打ち連携 | 手動反映（自動同期なし） | 双方向同期は複雑すぎる。壁打ちの結果を見て手動で下書きを更新 |
| 整理方法 | フラットリスト + 検索 + ピン留め | タグ/フォルダはV1では過剰 |

## データモデル

### テーブル: `prompt_drafts` (DB version 1→2)

```sql
CREATE TABLE prompt_drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  project_path TEXT NOT NULL DEFAULT '',
  is_pinned INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_draft_updated ON prompt_drafts (updated_at DESC);
CREATE INDEX idx_draft_pinned ON prompt_drafts (is_pinned DESC, updated_at DESC);
```

### テーブル: `prompt_draft_images`

```sql
CREATE TABLE prompt_draft_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  draft_id INTEGER NOT NULL REFERENCES prompt_drafts(id) ON DELETE CASCADE,
  file_path TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_draft_image_draft ON prompt_draft_images (draft_id);
```

## 実装フェーズ

### Phase 1: データ層

**修正**: `apps/mobile/lib/services/database_service.dart`
- `_dbVersion` を 1→2 に変更
- `_onUpgrade` に version 1→2 マイグレーション追加（2テーブル + インデックス作成）
- `_onCreate` にも同テーブルを追加（新規インストール用）

**新規**: `apps/mobile/lib/services/prompt_draft_service.dart`
- `PromptDraftEntry` クラス（id, title, body, projectPath, isPinned, createdAt, updatedAt, images）
- `PromptDraftImageEntry` クラス（id, draftId, filePath, mimeType, sortOrder）
- `PromptDraftSortOrder` enum（recency, alphabetical, pinnedFirst）
- `PromptDraftService` クラス:
  - `createDraft(title, {body, projectPath})` → int
  - `updateDraft(id, {title?, body?, projectPath?, isPinned?})`
  - `deleteDraft(id)` — 画像ファイルも削除
  - `getDrafts({sort, search, limit, offset})` → List
  - `getDraft(id)` → 単体（画像込み）
  - `addImage(draftId, Uint8List, mimeType)` → ファイル保存 + DB挿入
  - `removeImage(imageId)` → ファイル削除 + DB削除
  - `togglePin(id)`
  - `getDraftCount()` → int
- パターン: `PromptHistoryService` を参考に

**修正**: `apps/mobile/lib/main.dart`
- `PromptDraftService(dbService)` を作成・RepositoryProvider登録

### Phase 2: 状態管理

**新規**: `apps/mobile/lib/features/prompt_draft/state/prompt_draft_list_state.dart`
```dart
@freezed
abstract class PromptDraftListState with _$PromptDraftListState {
  const factory PromptDraftListState({
    @Default([]) List<PromptDraftEntry> drafts,
    @Default(PromptDraftSortOrder.recency) PromptDraftSortOrder sortOrder,
    @Default('') String searchQuery,
    @Default(false) bool isLoading,
    @Default(true) bool hasMore,
  }) = _PromptDraftListState;
}
```

**新規**: `apps/mobile/lib/features/prompt_draft/state/prompt_draft_list_cubit.dart`
- `PromptHistoryCubit` と同じパターン（load, loadMore, setSearchQuery, setSortOrder, delete, togglePin）

**新規**: `apps/mobile/lib/features/prompt_draft/state/prompt_draft_editor_state.dart`
```dart
@freezed
abstract class PromptDraftEditorState with _$PromptDraftEditorState {
  const factory PromptDraftEditorState({
    PromptDraftEntry? draft,
    @Default([]) List<PromptDraftImageEntry> images,
    @Default(false) bool isSaving,
    @Default(false) bool isDirty,
  }) = _PromptDraftEditorState;
}
```

**新規**: `apps/mobile/lib/features/prompt_draft/state/prompt_draft_editor_cubit.dart`
- `loadDraft(id)`, `createDraft(title)`, `updateTitle()`, `updateBody()`, `save()`
- `addImage(bytes, mimeType)`, `removeImage(imageId)`
- dispose時の自動保存

### Phase 3: 下書き一覧画面

**新規**: `apps/mobile/lib/features/prompt_draft/prompt_draft_list_screen.dart`
- `@RoutePage()` アノテーション
- 検索バー + ソートチップ（最近更新 / アルファベット / ピン優先）
- `ListView.builder` + ページネーション
- FABで新規下書き作成
- タップでエディタへ遷移

**新規**: `apps/mobile/lib/features/prompt_draft/widgets/prompt_draft_tile.dart`
- タイトル、本文プレビュー（2行）、プロジェクトパスchip、画像数バッジ、ピンアイコン、更新日時
- スワイプで削除

**修正**: `apps/mobile/lib/router/app_router.dart`
- `AutoRoute(page: PromptDraftListRoute.page, path: '/drafts')` 追加
- `AutoRoute(page: PromptDraftEditorRoute.page, path: '/draft-editor')` 追加

**修正**: `apps/mobile/lib/features/session_list/session_list_screen.dart`
- AppBarに下書きアイコン（`Icons.edit_note`）追加

### Phase 4: エディタ画面

**新規**: `apps/mobile/lib/features/prompt_draft/prompt_draft_editor_screen.dart`
- AppBar: タイトル編集、保存インジケータ
- 本文: スクロール可能なTextField（Markdown入力）
- 画像セクション: 横スクロールのサムネイル一覧 + 追加ボタン
- プロジェクトパス選択（NewSessionSheetと同じパターン）
- ボトムアクションバー: 壁打ち / 実行

**新規**: `apps/mobile/lib/features/prompt_draft/widgets/draft_image_strip.dart`
- 横スクロールの画像サムネイル一覧
- 「+」ボタンでギャラリー/クリップボードから追加
- タップでフルスクリーンプレビュー、長押しで削除

### Phase 5: 実行 & 壁打ちフロー

**実行フロー** (エディタ画面から):
1. 「実行」ボタンタップ → `NewSessionSheet` 表示（projectPath pre-fill）
2. Sheet確認 → `ClientMessage.start(...)` 送信
3. セッション画面へ遷移
4. セッション作成後、下書き本文を `ClientMessage.input(body, imageBase64)` で送信

**壁打ちフロー** (エディタ画面から):
1. 「壁打ち」ボタンタップ → `NewSessionSheet` 表示（projectPath pre-fill）
2. Sheet確認 → 通常セッション開始
3. 初回メッセージとして壁打ち用プロンプトを送信:
   ```
   以下のプロンプト下書きを壁打ちしてください。改善点や不足している情報を指摘してください。

   ---
   # {title}
   {body}
   ---
   ```
4. 壁打ち結果は手動で下書きに反映

### Phase 6: 統合 & テスト

**プロンプト履歴→下書き変換**:
- `PromptHistoryTile` に「下書きとして保存」アクションを追加

**テスト**:
- `apps/mobile/test/services/prompt_draft_service_test.dart` — CRUD操作
- `apps/mobile/test/features/prompt_draft/` — Cubitテスト

## 検証計画

### 静的検証
```bash
dart analyze apps/mobile
dart format apps/mobile
cd apps/mobile && flutter test
```

### E2E検証 (`/mobile-automation`)
1. ホーム画面 → 下書きアイコンタップ → 一覧画面表示
2. FABタップ → 新規下書き作成 → タイトル・本文入力 → 保存
3. 画像添付 → サムネイル表示確認
4. 一覧に戻る → 作成した下書きが表示される
5. 下書き → 実行 → セッション画面で本文が送信される

### セルフレビュー (`/self-review`)
- 全変更のdiffレビュー

## ファイル一覧

### 新規 (10ファイル + generated)
- `apps/mobile/lib/services/prompt_draft_service.dart`
- `apps/mobile/lib/features/prompt_draft/state/prompt_draft_list_state.dart`
- `apps/mobile/lib/features/prompt_draft/state/prompt_draft_list_cubit.dart`
- `apps/mobile/lib/features/prompt_draft/state/prompt_draft_editor_state.dart`
- `apps/mobile/lib/features/prompt_draft/state/prompt_draft_editor_cubit.dart`
- `apps/mobile/lib/features/prompt_draft/prompt_draft_list_screen.dart`
- `apps/mobile/lib/features/prompt_draft/prompt_draft_editor_screen.dart`
- `apps/mobile/lib/features/prompt_draft/widgets/prompt_draft_tile.dart`
- `apps/mobile/lib/features/prompt_draft/widgets/draft_image_strip.dart`
- `apps/mobile/test/services/prompt_draft_service_test.dart`

### 修正 (4ファイル)
- `apps/mobile/lib/services/database_service.dart` — DBマイグレーション v1→v2
- `apps/mobile/lib/main.dart` — サービス登録
- `apps/mobile/lib/router/app_router.dart` — ルート追加
- `apps/mobile/lib/features/session_list/session_list_screen.dart` — 下書きアイコン追加
