---
name: submit-store-review
description: 既存の安定したiOS・Androidリリースビルドを選び、メタデータと課金商品を確認してApp Store ConnectまたはGoogle Play Consoleの審査へ提出・再提出する。新しいビルドを作るrelease-appとは分離し、「ストア審査へ提出して」「App Reviewに出して」「Google Playの審査を進めて」「却下対応して再提出して」と依頼されたときに使用する。
---

# Submit Store Review

`release-app` で作成済みの候補から、安定したビルドをストア審査へ出す。新しいタグ、バージョン、ビルドは作成しない。

## 責務を分ける

- 新しいリリースを作る必要がある場合は `$release-app` を使う。
- 説明文やスクリーンショット自体を作り直す場合は `$update-store` を使う。
- このスキルでは候補選定、審査前確認、既存ビルドの提出、却下後の再提出を行う。
- ストア画面の操作には `$computer-use:computer-use` を使い、CLIやAPIで確認できる情報は先にそちらで確認する。

## 1. 審査候補を決める

対象プラットフォームとバージョンが明示されていなければ、候補を調査してユーザーへ推奨する。最新ビルドを自動的に選ばず、より新しいカジュアルリリースを飛ばしてもよい。

```bash
git status --short
git tag -l 'ios/v*' --sort=-v:refname | head -10
git tag -l 'android/v*' --sort=-v:refname | head -10
gh run list --workflow=ios-release.yml --limit 10 --json databaseId,headBranch,status,conclusion,url,createdAt
gh run list --workflow=android-release.yml --limit 10 --json databaseId,headBranch,status,conclusion,url,createdAt
```

候補は以下を満たすものにする。

- 対象タグのリリースworkflowが `success`
- ストア側でビルド処理が完了している
- TestFlightまたは内部テストで既知の重大な不具合がなく、後続hotfixを待っていない
- ユーザーが安定版として明示的に選べる状態になっている
- バージョン `X.Y.Z` とビルド番号 `N` がタグ `platform/vX.Y.Z+N` と一致する

候補ごとにリリース日時、テスト経過、既知の問題、より新しい候補の有無を短く示す。固定の待機日数は設けず、安定性の最終判断はユーザーに委ねる。

候補が存在しない、またはworkflowが失敗している場合は提出を止め、`release-app` が必要と報告する。このスキル内で代わりにビルドしない。

## 2. 提出前ゲートを通す

ストアを変更する前に次を確認する。

- 対象ビルドと審査バージョンが一致する
- 現在配信中のストア版から対象候補までの累積変更と、各言語のリリースノートが一致する
- 説明文、スクリーンショット、サポートURL、プライバシー情報に明らかな不整合がない
- 新しいアプリ内購入・サブスクリプションを含む場合、商品が審査可能な状態で対象提出に含まれる
- App Review情報、デモ手順、ログイン情報が現在も有効
- ストア側の警告、未回答項目、却下メッセージを確認済み

リポジトリ内のチェックリストは参考情報として扱い、課金商品、RevenueCat offering、審査状態はライブの管理画面を正とする。

アプリの実装変更は通常行わない。実装修正が必要だと判明した場合は提出を止め、別タスクとして修正と新規リリースが必要だと報告する。

## 3. メタデータを安全に反映する

メタデータのアップロードには `.github/workflows/upload-metadata.yml` を優先する。

重要: iOS laneはref内の全メタデータを編集可能なApp Storeバージョンへアップロードする。`upload_metadata` 入力はiOSの項目絞り込みには使われていない。対象バージョンと異なる `main` のリリースノートを誤って送らない。

1. 現在配信中のストア版を確認し、そこから対象候補までのユーザー向け変更を集約する。
2. 対象refにある各言語の `description.txt`、`release_notes.txt`、`promotional_text.txt` を確認する。
3. `main` の内容が対象バージョンと一致しない場合、`store/<platform>-<version>-submission` ブランチを作り、対象バージョン用メタデータだけをコミットする。
4. テキストだけならスクリーンショットを送らず、プラットフォームごとにworkflowを実行する。
5. workflow成功後、ストア画面で対象バージョンへの反映を目視確認する。

```bash
gh workflow run upload-metadata.yml \
  --ref <target-ref> \
  -f platform=ios \
  -f upload_screenshots=false \
  -f upload_metadata=true \
  -f upload_images=false

gh workflow run upload-metadata.yml \
  --ref <target-ref> \
  -f platform=android \
  -f upload_screenshots=false \
  -f upload_metadata=true \
  -f upload_images=false \
  -f android_version_code=<build-number>
```

workflowを実行しない場合も、ストア上の内容が対象バージョンと一致することを確認する。

## 4. ストア別の手順を実行する

- iOSは [references/ios.md](references/ios.md) を読み、App Store Connectで処理する。
- Androidは [references/android.md](references/android.md) を読み、Google Play Consoleで処理する。
- 両方の場合も、候補バージョンとメタデータをプラットフォームごとに独立して確認する。

管理画面への移動、閲覧、状態確認は読み取り専用なので、追加確認を求めず自律的に進める。入力内容の準備も先に完了する。Appleへの返信、審査提出、Google Playへの変更送信など外部状態を変える操作は、Computer Useの確認ポリシーに従って実行直前にユーザー確認を取る。

## 5. 完了を検証する

提出ボタンを押しただけで完了としない。再読み込みして最終状態を確認する。

- iOS: `審査待ち` / `Waiting for Review`
- Android: `審査中の変更` / `Changes in review`
- 管理対象の公開が有効なら、承認後も自動公開されないことを報告する
- Appleへの返信を送った場合は、メッセージ履歴に表示されることを確認する

最後に、プラットフォーム、バージョン、ビルド番号、metadata workflow URL、ストアの状態、公開方式、残っている警告をまとめる。
