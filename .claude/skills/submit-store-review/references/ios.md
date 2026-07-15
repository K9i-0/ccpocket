# iOS App Review

## 候補確認

`ios/vX.Y.Z+N` と `ios-release.yml` の成功runを対応させる。workflowはIPAをTestFlightへ送るだけで、App Reviewには提出しない。

App Store Connectで次を確認する。

1. TestFlightに `X.Y.Z (N)` が存在し、処理済みである。
2. 配信ページに審査用バージョン `X.Y.Z` が存在する。なければ作成する。
3. 審査対象としてビルド `N` を選択する。より新しいビルドが表示されても勝手に差し替えない。

## メタデータ確認

英語、日本語、韓国語、簡体字中国語を確認する。

- 概要とプロモーション用テキスト
- このバージョンの最新情報
- スクリーンショット
- キーワード、サポートURL、プライバシーポリシー
- App Reviewの連絡先、メモ、デモ動画、ログイン情報

新しい課金商品がある場合は、アプリ内購入とサブスクリプションの状態、価格、ローカライズ、審査への追加を確認する。

メタデータの指摘で再提出するときは、指摘された言語だけでなく全ローカライズを同じ方針で修正する。Appleへ送る返信は簡潔にし、何を修正したかと対象バージョンを記載する。

例:

```text
Hello,

We updated all localized App Store descriptions to address the metadata issue and resubmitted version X.Y.Z (N) for review.

Thank you.
```

実際に再提出する前は `prepared for resubmission`、再提出後に送る場合は `resubmitted` と書き分ける。

## 提出

1. リリース方式（手動、自動、日時指定）を確認し、既存設定を勝手に変えない。
2. `審査内容を更新` または `Add for Review` で対象を提出項目へ追加する。
3. Appleへ必要な返信を送る。
4. 最終の `App Reviewに提出` / `Submit for Review` を実行する。
5. 再読み込みし、提出とアプリバージョンの両方が `審査待ち` になったことを確認する。

`審査準備完了` はまだ最終提出前であるため、完了扱いにしない。
