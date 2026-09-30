# iOS App Review (asc)

## 自動化の範囲

`submit-store-review.yml` の iOS job は、App Store Connect API を使う `asc` 4.9.2 を固定して実行する。ブラウザや Computer Use は使わない。

`inspect-store-state.yml` は `asc versions list --paginate` の結果から、新APIの `appVersionState=READY_FOR_DISTRIBUTION` または旧APIの `appStoreState=READY_FOR_SALE` で作成日時が最新のiOS版を選ぶ。新APIの状態があればそちらを優先し、`asc versions view --include-build` で正確なバージョンとbuild numberを取得する。新旧stateは同じ `--state` filterに混在できないため、CLI側ではfilterせずローカルで絞り込む。成果物 `ios-store-state` は公開状態だけを含み、認証情報やAPIの生レスポンスは含めない。

既存の GitHub Secrets をそのまま利用する。

- `APP_STORE_CONNECT_ISSUER_ID` → `ASC_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER` → `ASC_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY` → `ASC_PRIVATE_KEY`

APIキーには対象アプリを管理し審査へ提出できる権限が必要。契約・税務・銀行情報の同意はAPIで完結しない場合があるため、そのエラーが出たら提出を止める。

## workflow が行う安全確認

1. `ios/vX.Y.Z+N` が存在し、タグ内の `pubspec.yaml` が `X.Y.Z+N` と一致することを確認する。
2. bundle ID `com.k9i.ccpocket` からアプリを一意に解決する。
3. TestFlight の `X.Y.Z (N)` を完全一致で選び、処理完了まで待つ。
4. 公開方式の既定は `AFTER_APPROVAL`（承認後に自動公開）。App Storeバージョンがなければ作成する。`KEEP` の場合、新規バージョンだけ安全側の `MANUAL` にする。
5. 既に別ビルドが添付されていれば停止し、勝手に差し替えない。
6. 対象ビルドを添付し、`asc validate` と `asc review doctor` を実行する。
7. `asc review submit --confirm` で審査へ提出する。
8. `WAITING_FOR_REVIEW` または `IN_REVIEW` を再取得して確認する。提出済みなら冪等に成功する。

主な読み取りコマンドは以下。

```bash
asc apps list --bundle-id com.k9i.ccpocket --paginate
asc builds info --app <app-id> --build-number <N> --version <X.Y.Z> --platform IOS
asc versions view --version-id <version-id> --include-build --include-submission
asc validate --app <app-id> --version-id <version-id> --platform IOS
asc review status --app <app-id> --version-id <version-id> --platform IOS
asc review doctor --app <app-id> --version-id <version-id> --platform IOS
```

## メタデータと課金商品

`upload-metadata.yml` には `ios_version=X.Y.Z` を渡し、別の下書きバージョンへリリースノートを誤反映しない。審査refのiOSメタデータは対象候補タグを基準にする。

英語、日本語、韓国語、簡体字中国語について次を確認する。

- 概要、プロモーション用テキスト、このバージョンの最新情報
- スクリーンショット、キーワード、サポートURL、プライバシーポリシー
- App Reviewの連絡先、メモ、デモ動画、ログイン情報

新しい課金商品がある場合は、アプリ内購入とサブスクリプションの状態、価格、ローカライズ、審査への追加を確認する。`asc validate iap` と `asc validate subscriptions` も利用する。

このworkflowが提出項目へ追加するのはアプリバージョンだけである。新規IAPまたはサブスクリプションを同じ審査へ含める必要がある場合は `ios_review_scope=INCLUDES_NEW_IAP_OR_SUBSCRIPTION` として事前検査を意図的に失敗させ、専用のreview item追加フローを準備する。既存商品の通常動作だけを含む更新は `APP_VERSION_ONLY` を選ぶ。

Appleへの審査メッセージ返信など、App Store Connect APIで扱えない操作が必要なら、その操作だけを未完了として報告する。通常のビルド選択と審査提出はworkflowで完結させる。
