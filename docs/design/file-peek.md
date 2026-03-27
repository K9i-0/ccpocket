# File Peek

## Context

エージェントのメッセージ内に登場するファイルパス（`` `lib/main.dart` `` など）をタップ可能にし、
ボトムシートでファイル内容をその場で閲覧できる機能。

セッション中にエージェントが参照・編集したファイルを、アプリを離れずに確認できることで
コードレビューや状況把握のフローを改善する。

## データフロー

```
AssistantMessage (markdown)
  ↓ FilePathSyntax がバッククォート内のパスを検出
  ↓ FilePathBuilder がタップ可能リンクとして描画
  ↓ ユーザータップ
  ↓ onFileTap → showFilePeekSheet()
  ↓ ClientMessage.readFile(projectPath, filePath) を Bridge に送信
  ↓
Bridge Server (websocket.ts)
  1. パス許可チェック (isPathAllowed)
  2. ファイル存在確認
  3. 非同期読み込み + 言語検出
  4. 5000行超は切り詰め (truncated)
  5. FileContentMessage を返却
  ↓
FilePeekSheet (fileContent stream で受信)
  - .md → Markdownレンダリング
  - その他 → 行番号付きコード表示
```

## ファイルパス検出ルール (FilePathSyntax)

Markdownのインライン構文として実装。バッククォート内のテキストを対象にする。

| 条件 | 例 |
|------|-----|
| `/` を1つ以上含む | `src/main.dart`, `packages/bridge/src/index.ts` |
| 既知の拡張子を持つ | `pubspec.yaml`, `README.md`, `Dockerfile` |

対応拡張子: dart, ts, tsx, js, py, rb, rs, go, java, kt, swift, c, cpp, cs,
sh, yml, yaml, json, toml, md, html, css, scss, sql, xml, gradle, dockerfile, makefile, txt

## Bridge プロトコル

### Client → Server

```json
{
  "type": "read_file",
  "projectPath": "/home/user/project",
  "filePath": "lib/main.dart",
  "maxLines": 5000
}
```

```json
{
  "type": "list_dir",
  "projectPath": "/home/user/project",
  "dirPath": "lib"
}
```

### Server → Client

```json
{
  "type": "file_content",
  "filePath": "lib/main.dart",
  "content": "import ...",
  "language": "dart",
  "totalLines": 287,
  "truncated": false
}
```

```json
{
  "type": "dir_listing",
  "dirPath": "lib",
  "entries": [
    { "name": "src", "isDirectory": true },
    { "name": "main.dart", "isDirectory": false, "size": 1024 }
  ]
}
```

エラー時は `error` フィールドで返却: `"Path not allowed"`, `"File not found"` など。

## UI 設計

### FilePeekSheet (ボトムシート)

- `DraggableScrollableSheet` (初期85%, 最大95%, 最小40%)
- ヘッダー: ファイル名、フルパス（モノスペース）、コピーボタン、閉じるボタン
- メタデータ: 行数 + 言語 + truncated表示
- コンテンツ:
  - Markdownファイル → `flutter_markdown` でレンダリング
  - コードファイル → 行番号付き、水平スクロール対応、選択可能テキスト
- ローディング中: スピナー表示
- エラー時: アイコン + メッセージ

### ファイルパスリンク

- 青色テキスト + 点線下線 + ドキュメントアイコン
- Markdownの `builders` に `FilePathBuilder` として登録

## セキュリティ

- Bridge側で `isPathAllowed()` によるパス検証（BRIDGE_ALLOWED_DIRS 準拠）
- `projectPath` が未設定の場合はタップしても何も起きない（silent failure）
- ファイルは読み取り専用（書き込みAPIなし）

## 設計判断

### 遅延ロード方式

ファイル内容はタップ時に初めて取得する（プリロードしない）。
メッセージ中に多数のパスが含まれる場合でも、不要な通信を避けられる。

### Broadcast Stream

`BridgeService.fileContent` はbroadcast streamで実装。
FilePeekSheet側で `filePath` フィルタリングして自身のリクエストのみ処理する。

### projectPath の伝播

`ChatSessionState.projectPath` ではなくウィジェットツリー経由で伝播。
`ClaudeSessionScreen` / `CodexSessionScreen` → `ChatMessageList.projectPath` → `onFileTap`。

## モック対応

`MockBridgeService` が `read_file` / `list_dir` を処理し、
拡張子に応じたサンプルコンテンツを返却する（.dart, .md, .yaml, .json, .ts）。
モックプレビューの「File Peek」シナリオで動作確認可能。

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `features/file_peek/file_peek_sheet.dart` | ボトムシートUI |
| `features/file_peek/file_path_syntax.dart` | Markdownインライン構文 |
| `models/messages.dart` | FileContentMessage, DirListingMessage |
| `services/bridge_service.dart` | Stream管理・メッセージルーティング |
| `packages/bridge/src/websocket.ts` | read_file / list_dir ハンドラー |
| `mock/mock_scenarios.dart` | File Peekモックシナリオ |
| `services/mock_bridge_service.dart` | モック用ファイル内容返却 |
