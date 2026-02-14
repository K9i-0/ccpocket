# FCM プッシュ通知導入プラン

## Context

ccpocket は公開アプリとして展開予定。ユーザーが外出中でも「タスク完了」「承認待ち」などをプッシュ通知で受け取りたい。
構成: Firebase Anonymous Auth + Firestore + Cloud Functions。Bridge Server は通知トリガーの HTTP リクエストだけ送る。

## アーキテクチャ

```
Flutter App                    Firebase                         Bridge Server (ユーザーのMac)
─────────                    ────────                         ──────────────
1. 匿名認証ログイン ──────→ Firebase Auth
2. FCMトークン取得
3. 設定画面で「通知ON」 ──→ Firestore に保存
   (uid + fcmToken +          /users/{uid}/tokens/{tokenId}
    bridgeApiKey)              { token, bridgeApiKey, createdAt }

4.                                                            セッション完了時
                                                              HTTP POST → Cloud Functions
                              Cloud Functions ←───────────────  /notify
                              bridgeApiKey で Firestore 検索     { bridgeApiKey, title, body }
                              → 該当トークンに FCM 送信
5. プッシュ通知受信 ←──── FCM
```

## 実装ステップ

### Phase 1: Firebase プロジェクトセットアップ（手動）

- Firebase Console でプロジェクト作成
- Anonymous Auth 有効化
- iOS アプリ登録 → `GoogleService-Info.plist` 配置
- Android アプリ登録 → `google-services.json` 配置
- APNs 設定（iOS Push Notification capability + APNs キー登録）

### Phase 2: Flutter App — Firebase 初期化 + 匿名認証

**追加パッケージ:**
```yaml
firebase_core: ^3.13.0
firebase_auth: ^5.5.2
firebase_messaging: ^15.2.5
cloud_firestore: ^5.6.8
```

**変更ファイル:**

1. **`apps/mobile/lib/main.dart`**
   - `Firebase.initializeApp()` 追加
   - `FirebaseAuth.instance.signInAnonymously()` 追加（アプリ起動時）

2. **`apps/mobile/lib/services/fcm_service.dart`** (新規)
   ```dart
   class FcmService {
     Future<void> init();              // FCM 初期化 + パーミッション要求
     Future<String?> getToken();       // FCM トークン取得
     Future<void> registerToken({      // Firestore に保存
       required String bridgeApiKey,
     });
     Future<void> unregisterToken();   // Firestore から削除
     Stream<RemoteMessage> onMessage;  // フォアグラウンド通知
   }
   ```

3. **`apps/mobile/lib/features/settings/state/settings_cubit.dart`**
   - `fcmEnabled` 状態追加
   - `toggleFcm()` メソッド追加
   - ON: トークン登録 → SharedPreferences に保存
   - OFF: トークン削除

4. **`apps/mobile/lib/features/settings/state/settings_state.dart`**
   - `fcmEnabled` フィールド追加 (Freezed)

5. **`apps/mobile/lib/features/settings/settings_screen.dart`**
   - 「プッシュ通知」セクション追加（SwitchListTile）
   - 接続中の Bridge API Key を自動取得して登録

### Phase 3: Firestore スキーマ + セキュリティルール

**コレクション構造:**
```
/users/{uid}/tokens/{tokenId}
  - token: string          // FCM トークン
  - bridgeApiKey: string   // Bridge Server の API Key (ハッシュ化)
  - platform: string       // "ios" | "android"
  - createdAt: timestamp
  - updatedAt: timestamp
```

**セキュリティルール:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/tokens/{tokenId} {
      // 自分のドキュメントのみ読み書き可
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    // Cloud Functions (admin SDK) は全アクセス可
  }
}
```

### Phase 4: Cloud Functions — 通知送信 API

**`functions/src/index.ts`** (新規)

```typescript
// POST /notify
// Body: { bridgeApiKey: string, title: string, body: string, data?: object }
// → bridgeApiKey のハッシュで Firestore を検索
// → 該当する全 FCM トークンにプッシュ送信
```

**ポイント:**
- bridgeApiKey は SHA-256 ハッシュで保存・照合（平文を Firestore に保存しない）
- Cloud Functions は認証なし（bridgeApiKey 自体が認証代わり）
  - Bridge Server は HTTPS で呼ぶだけ
  - bridgeApiKey を知らないと通知は送れない
- 無効トークンは自動削除

### Phase 5: Bridge Server — 通知トリガー

**変更ファイル:**

1. **`packages/bridge/src/parser.ts`**
   - `ClientMessage` に `register_notification_url` 型追加（オプション）
   - 通知先の Cloud Functions URL を Flutter App から受信

2. **`packages/bridge/src/notification.ts`** (新規)
   ```typescript
   export class NotificationSender {
     constructor(private functionUrl: string, private apiKey: string);
     async send(title: string, body: string, data?: Record<string, string>);
   }
   ```
   - シンプルな HTTP POST ラッパー
   - Cloud Functions の URL にリクエスト送信

3. **`packages/bridge/src/session.ts`**
   - `result` イベント時に通知送信
   - `permission_request` イベント時に通知送信
   - `error` イベント時に通知送信（オプション）

### Phase 6: 通知トリガーイベント

| イベント | タイトル | 本文例 |
|---------|---------|--------|
| `result` (完了) | タスク完了 ✅ | `セッション完了 (12.3s, $0.05)` |
| `result` (エラー) | エラー発生 ❌ | `エラー: ...` |
| `permission_request` | 承認待ち 🔔 | `ファイル変更の承認が必要です` |

## 依存関係まとめ

| 場所 | 追加パッケージ | 目的 |
|------|---------------|------|
| Flutter | `firebase_core` | Firebase 初期化 |
| Flutter | `firebase_auth` | 匿名認証 |
| Flutter | `firebase_messaging` | FCM トークン取得・受信 |
| Flutter | `cloud_firestore` | トークン保存 |
| Cloud Functions | `firebase-admin` | FCM 送信・Firestore アクセス |
| Cloud Functions | `firebase-functions` | HTTP トリガー |
| Bridge | なし（`fetch` のみ） | HTTP POST するだけ |

## 実装順序

1. Firebase プロジェクトセットアップ（手動）
2. Flutter: Firebase 初期化 + 匿名認証
3. Flutter: FcmService + 設定画面
4. Firestore: セキュリティルール
5. Cloud Functions: 通知 API
6. Bridge Server: 通知トリガー

## 検証

### 静的検証
```bash
dart analyze apps/mobile
cd apps/mobile && flutter test
npx tsc --noEmit -p packages/bridge/tsconfig.json
```

### E2E 検証
1. シミュレーターでアプリ起動
2. 設定画面で通知を ON にする
3. Firestore Console でトークンが保存されていることを確認
4. Bridge Server でセッション実行 → Cloud Functions ログで通知送信を確認
5. 実機でプッシュ通知受信を確認

### セルフレビュー
`/self-review` スキルで変更全体をレビュー
