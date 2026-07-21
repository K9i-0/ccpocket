# ccpocket Push Relay Functions

Bridge からの Push Relay (`register` / `unregister` / `notify`) を受けて
Firestore と FCM を操作する Firebase Functions 実装です。

## 認証

Bridge は Firebase Anonymous Auth で取得した ID token を Bearer token として送信する。
Relay は token を検証し、認証済み UID を Bridge ID として利用するため、環境変数や共有secretの設定は不要。

## ローカル開発

```bash
npm ci --prefix functions
npm --prefix functions test
npm --prefix functions run typecheck
npm --prefix functions run build
```

## デプロイ

```bash
npm run functions:deploy
```

`firebase.json` の predeploy hook がデプロイ前にFunctionsをビルドする。
デプロイ先は `ccpocket-ca33b` で、CDは使用せず手動で実行する。
