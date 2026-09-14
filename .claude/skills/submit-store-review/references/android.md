# Google Play Review (Fastlane + Developer API)

## 自動化の範囲

`submit-store-review.yml` の Android job は、既存の `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` と Fastlane `supply` を使う。内部テストにある対象 versionCode を本番トラックへ昇格し、Google Play Developer API の edit を審査へ送る。

`inspect-store-state.yml` の `android store_state` lane は、読み取り用editでproduction trackを取得し、commitせずabortする。`completed` または `inProgress` のうち最大versionCodeを現在の公開版として `android-store-state` に出力する。成果物にサービスアカウント情報は含めない。

新しいAABはアップロードしない。対象は `android/vX.Y.Z+N` で既に作成された versionCode `N` に限定する。

## workflow が行う安全確認

1. `android/vX.Y.Z+N` が存在し、タグ内の `pubspec.yaml` が `X.Y.Z+N` と一致することを確認する。
2. 全ロケールに `<N>.txt` の本番リリースノートがあり、500文字以内であることを確認する。
3. 内部テストのリリースから versionCode `N` だけを選択する。
4. 本番トラックへ `inProgress` または `completed` で昇格する。
5. `changesNotSentForReview=false` で審査へ送る。
6. commit時に `changesInReviewBehavior=ERROR_IF_IN_REVIEW` を指定する。
7. 内部リリースに複数versionCodeが含まれていたら停止し、指定外のビルドを同時昇格しない。
8. 同じ versionCode が既に本番にある場合は無変更で停止する。APIだけでは「審査へ送信済み」と「反映済みだが未送信」を区別できないため、成功扱いにせず前回workflowを確認する。

最後の指定が重要。Google API のデフォルトは、別の変更が審査中でもそれを取り消して新しいeditを送る挙動になり得る。Fastlane 2.235.0 はこのオプションを直接公開していないため、Fastfileの安全なcommitラッパーで明示する。固定済みAPIクライアントがこの引数をサポートしない場合も、危険なフォールバックをせず停止する。

## 配信方式

既定は全ユーザーへの100%公開。

```text
android_release_status=completed
```

段階配信を使うのはユーザーが明示した場合だけ。配信率の指定があれば優先し、未指定ならworkflowの既定値 `0.1`（10%）を使い、採用した率を報告して進める。

```text
android_release_status=inProgress
android_user_fraction=0.1
```

Google Play の Managed publishing 設定は API workflow から変更しない。有効なら審査承認後に手動公開が必要で、無効なら承認後に指定した段階配信または全体配信が始まる。

## 本番リリースノート

審査提出では `default.txt` を使わず、versionCode別ファイルを必須にする。

```text
fastlane/metadata/android/en-US/changelogs/<N>.txt
fastlane/metadata/android/ja-JP/changelogs/<N>.txt
fastlane/metadata/android/ko-KR/changelogs/<N>.txt
fastlane/metadata/android/zh-CN/changelogs/<N>.txt
```

カジュアルリリースを複数回挟んだ場合、最後の本番配信版から対象候補までのユーザー向け変更をまとめる。

## エラー時

- `ERROR_IF_IN_REVIEW` で失敗: 既存の審査を維持したまま停止している。現在の審査完了後に再実行するか、対象を確認する。
- versionCodeが内部トラックにない: release workflowの成功とGoogle Play側の処理状況を確認する。新しいAABをこのスキルで作らない。
- ポリシー申告や契約の未完了: APIで扱えない項目を報告し、提出を止める。
- commit成功: editは審査へ送られている。Managed publishingに応じて承認後の公開操作が別途必要か報告する。
