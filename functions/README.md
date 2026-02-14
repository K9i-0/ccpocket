# ccpocket Push Relay Functions

Bridge からの Push Relay (`register` / `unregister` / `notify`) を受けて
Firestore と FCM を操作する Firebase Functions 実装です。

## 事前準備（手動）

1. Firebase プロジェクト作成
2. Cloud Firestore 有効化
3. Cloud Messaging 設定
4. Functions 用の `PUSH_RELAY_SECRET` を設定

```bash
firebase functions:secrets:set PUSH_RELAY_SECRET
```

## ローカル開発

```bash
cd functions
npm install
npm run typecheck
```

## デプロイ

```bash
cd functions
npm run deploy
```

デプロイ後のエンドポイント URL を Bridge の `PUSH_RELAY_URL` に設定する。
