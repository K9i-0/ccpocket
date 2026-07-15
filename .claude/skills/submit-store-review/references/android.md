# Google Play Review

## 候補確認

`android/vX.Y.Z+N` と `android-release.yml` の成功runを対応させる。workflowはAABを内部テストへ `draft` として送るため、本番審査への提出は別に行う。

Google Play Consoleで次を確認する。

1. App Bundle Explorerまたはリリースライブラリにversion code `N`、version name `X.Y.Z` が存在する。
2. 内部テストのdraftで処理エラーがない。
3. 本番トラックに同じversion codeの進行中リリースがない。

## 本番リリース準備

1. 本番トラックで新しいリリースを作成する。
2. リリースライブラリからversion code `N` のAABを選択する。
3. リリース名と各言語のリリースノートが対象バージョンと一致することを確認する。
4. 対象国、配信率、端末除外、警告を確認する。
5. Data safety、コンテンツレーティング、広告、アプリのアクセスなどの未完了項目がないことを確認する。

配信率が指定されていなければ推奨案を示し、最終送信前にユーザーの意図を確認する。既存のManaged publishing設定は勝手に変更しない。

現在の `upload-metadata.yml` はAndroidのストア説明文や画像を更新できるが、Fastlane laneで `skip_upload_changelogs: true` が指定されている。Google Playの本番リリースノートはworkflowで更新されたと仮定せず、本番リリース作成画面で全言語を入力・確認する。

カジュアルリリースを複数回挟んだ場合、リリースノートは最後の本番配信版から対象候補までのユーザー向け変更をまとめる。

## 提出

1. リリースを保存し、エラーと警告を確認する。
2. `Review release` でversion code、国、配信率、リリースノートを再確認する。
3. `Start rollout to production` または変更送信操作を行う。
4. Overviewの `Send changes for review` が別に必要なら実行する。
5. 再読み込みし、変更が `審査中` / `Changes in review` になったことを確認する。

Managed publishingが有効なら、承認後は手動公開が必要である。審査提出と本番公開を同じ操作として扱わず、公開は別途ユーザーが依頼した場合だけ行う。
