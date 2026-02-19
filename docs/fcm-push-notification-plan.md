# FCM Push Notification 導入プラン（Bridge中心）

## 目的

ccpocket を公開運用する前提で、ユーザーがアプリをバックグラウンドにしていても以下を受け取れるようにする。

- セッション完了
- 承認待ち
- AskUserQuestion の回答待ち

## 実装ステータス（2026-02-14）

### 完了（人手不要）

- Bridge:
  - `push_register` / `push_unregister` のWS受信
  - `PushRelayClient` 実装（`register`/`unregister`/`notify`）
  - `permission_request` / `result` から通知トリガー
  - `AskUserQuestion` 判定と `toolUseId` 重複通知抑制
- Mobile:
  - `firebase_core` / `firebase_messaging` 依存追加
  - FlutterFire CLI で Firebase アプリ登録（Android / iOS）
  - `apps/mobile/lib/firebase_options.dart` 生成
  - `apps/mobile/android/app/google-services.json` 生成
  - `apps/mobile/ios/Runner/GoogleService-Info.plist` 生成
  - `FcmService` 実装（permission, token取得, token refresh）
  - Settings画面に Push ON/OFF を追加
  - `SettingsCubit` で register/unregister 同期を実装
- Cloud Functions:
  - `functions/` 新設
  - Relay API (`register` / `unregister` / `notify`) 実装
  - Firestore upsert + invalid token cleanup 実装
- Firebase Project:
  - ルート `firebase.json` / `.firebaserc` を作成（project: `ccpocket-ca33b`）
  - `apps/mobile/firebase.json` を生成

### 明日やる（手動）

- Firebase プロジェクトを Blaze にアップグレード（Functions/SecretManager デプロイブロッカー）
- Cloud Functions deploy
  - `firebase deploy --only functions --project ccpocket-ca33b`
- `PUSH_RELAY_SECRET` の本番設定
  - `firebase functions:secrets:set PUSH_RELAY_SECRET --project ccpocket-ca33b`
- APNs証明書/キー設定（iOS通知）
- Functionsデプロイ後、Bridge側 env を設定
  - `PUSH_RELAY_URL`
  - `PUSH_RELAY_SECRET`
  - `PUSH_BRIDGE_ID`（任意）

## 設計方針

1. **Bridge を唯一の通知起点にする**
   - Claude/Codex イベントの意味を理解しているのは Bridge。
   - 通知トリガー判定は Bridge に集約する。

2. **Mobile から Firestore に直接書かない**
   - Mobile は FCM token を取得し、WebSocket で Bridge に登録依頼するだけ。
   - Firestore 書き込み・通知送信は Cloud Functions (Admin SDK) に限定する。

3. **`BRIDGE_API_KEY` に依存しない通知認証**
   - Bridge接続の認証（`BRIDGE_API_KEY`）と通知認証（`PUSH_RELAY_SECRET`）を分離する。
   - `BRIDGE_API_KEY` 未設定運用でも通知機能が壊れない設計にする。

4. **通知URLはクライアント入力禁止**
   - `register_notification_url` のようなクライアント指定URLは採用しない。
   - 通知先は Bridge 環境変数で固定する。

## 全体アーキテクチャ

```
Flutter App                         Bridge Server                        Cloud Functions + Firestore
──────────                         ─────────────                        ───────────────────────────
1. FCM token取得
2. ws: push_register ───────────→ 3. token受理
                                      4. HTTPS POST(op=register) ───→   5. token保存

6. Claude/Codex event発生
   (result / permission_request)
                                → 7. 通知要否判定
                                      8. HTTPS POST(op=notify) ─────→   9. FCM送信

10. ws: push_unregister ───────→ 11. HTTPS POST(op=unregister) ───→   12. token削除
```

## WebSocket プロトコル追加

### Client → Server

- `push_register`
  - `token: string`
  - `platform: "ios" | "android" | "web"`
- `push_unregister`
  - `token: string`

### Server → Client

- 既存の `error` を利用（登録失敗時）
- 成功時は基本 silent（必要なら将来 `push_status` を追加）

## Cloud Relay API（Bridge → Cloud Functions）

Bridge は単一の Relay URL に `op` を付けて POST する。

- `op: "register"`
  - `bridgeId`, `token`, `platform`
- `op: "unregister"`
  - `bridgeId`, `token`
- `op: "notify"`
  - `bridgeId`, `eventType`, `title`, `body`, `data?`

### 認証

- Header: `Authorization: Bearer <PUSH_RELAY_SECRET>`
- Cloud Functions 側で Secret 検証必須

### Bridge 識別子

- `PUSH_BRIDGE_ID` を優先
- 未指定時はホスト名ベースで生成（例: `os.hostname()`）

## Firestore スキーマ（Cloud Functions 管理）

```
/bridges/{bridgeId}/tokens/{tokenId}
  - token: string
  - platform: string
  - createdAt: timestamp
  - updatedAt: timestamp
```

- token重複登録は upsert
- FCM send で invalid token 判定時は自動削除

## 通知イベント定義

| Bridgeイベント | 条件 | eventType | タイトル例 | 本文例 |
|---|---|---|---|---|
| `permission_request` | `toolName == AskUserQuestion` | `ask_user_question` | 回答待ち | Claude が質問しています |
| `permission_request` | 上記以外 | `approval_required` | 承認待ち | ツール実行の承認が必要です |
| `result` | `subtype=success` | `session_completed` | タスク完了 | セッションが完了しました |
| `result` | `subtype=error` | `session_failed` | エラー発生 | セッションが失敗しました |

### 重複抑制

- `permission_request` は `toolUseId` 単位で重複通知しない
- `result` の `stopped` は通知しない

## 実装ステップ

### Phase 1: Bridge 実装（先行）

- `packages/bridge/src/parser.ts`
  - `push_register` / `push_unregister` 追加
- `packages/bridge/src/push-relay.ts`（新規）
  - Cloud Relay HTTP クライアント
- `packages/bridge/src/websocket.ts`
  - `push_register` / `push_unregister` ハンドラ
  - `broadcastSessionMessage()` で通知トリガー
  - `AskUserQuestion` 分岐
  - `toolUseId` 重複通知抑制

### Phase 2: Mobile 実装

- `apps/mobile/pubspec.yaml`
  - `firebase_core`
  - `firebase_messaging`
- `apps/mobile/lib/services/fcm_service.dart`（新規）
  - パーミッション要求
  - token取得
  - `onTokenRefresh` で再登録
- `apps/mobile/lib/models/messages.dart`
  - `ClientMessage.pushRegister()` / `pushUnregister()`
- `apps/mobile/lib/services/bridge_service.dart`
  - push register/unregister送信 API
- `apps/mobile/lib/features/settings/*`
  - Push ON/OFF 設定

### Phase 3: Cloud Functions 実装（別ディレクトリ）

- `functions/` を新設
- Relay API (`register` / `unregister` / `notify`) 実装
- Firestore 書き込みと FCM 送信
- invalid token cleanup

## 認証方式（Bridge → Cloud Functions）

**Firebase Anonymous Authentication** を使用。Bridge起動時に自動で匿名認証を行い、
Firebase IDトークンをBearer tokenとしてCloud Functionsに送信する。

- 環境変数の設定は**不要**
- bridgeId = Firebase UID（自動で一意）
- Cloud Functions側で `verifyIdToken()` によりIDトークンを検証
- リクエストbodyの `bridgeId` はUIDで上書きされるため、他Bridgeのデータにアクセス不可

## 検証

### 静的検証

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
dart analyze apps/mobile
cd apps/mobile && flutter test
```

### E2E 検証

1. Bridge を Push env 付きで起動
2. Mobile で Push ON（token register）
3. セッション実行で `permission_request` / `AskUserQuestion` / `result` を発生
4. Cloud Functions ログで `op=notify` と送信件数を確認
5. 実機で通知受信確認

## 非採用案

- Mobile → Firestore 直接書き込み（責務分散・セキュリティルール複雑化）
- `bridgeApiKey` を通知識別子に再利用（未設定運用で破綻）
- クライアントから通知先URLを受け取る方式（SSRFリスク）
