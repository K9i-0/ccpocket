---
name: submit-store-review
description: 既存の安定ビルドをApp Store / Google Playの審査へ提出・再提出する。新規ビルドはrelease-appを使う。
---

# Submit Store Review

`release-app` で作成済みの候補を、ストアの公開版との差分から審査へ提出する。新しいタグ、バージョン、ビルドは作成しない。

## 責務と安全境界

- 提出は `.github/workflows/submit-store-review.yml` を使う。iOS は `asc`、Android は Fastlane と Google Play Developer API で処理する。
- 公開状態は `.github/workflows/inspect-store-state.yml` で読む。iOS は新APIの `READY_FOR_DISTRIBUTION` または旧APIの `READY_FOR_SALE`、Android は production track の `completed` / `inProgress` を正とする。
- Computer Use は通常使わない。APIで処理できない契約・税務・銀行情報や質問項目が残る場合だけ、理由と未完了項目を報告して止める。
- 新しいリリースが必要なら `$release-app`、説明文やスクリーンショット全体の更新なら `$update-store` を使う。
- 新規IAP・サブスクリプションを同じiOS審査へ含める場合、この自動提出は止める。アプリバージョン単体だけを自動化する。

## 「最新を審査提出して」の既定動作

プラットフォーム指定がなければ iOS と Android の両方を対象に、次を連続して行う。

1. ストアAPIから現在の公開版を取得する。
2. 各プラットフォームの最新リリースタグと成功した release workflow を確認する。
3. 公開版タグから候補タグまでの累積差分を読む。
4. 英語、日本語、韓国語、簡体字中国語のリリースノートを作る。
5. 審査専用refへメタデータだけをコミットしてpushする。
6. 公開版、候補、リリースノートの要点、公開方式、対象refを報告する。
7. iOSメタデータ反映と審査提出をdispatchし、完了まで監視する。

審査提出の依頼を、既定ルールでの候補選択・ノート作成・メタデータ反映・審査提出の承認として扱い、途中や最後に追加の承認を求めない。ノート作成や提出準備だけの依頼では、ストアへの反映・提出は行わない。

## 1. 公開版と最新候補を特定する

最初にリモートとタグを更新し、ローカルの未コミット変更を上書きしない。

```bash
git status --short
git fetch origin main
git fetch --prune origin \
  '+refs/tags/ios/*:refs/store-review/remote-tags/ios/*' \
  '+refs/tags/android/*:refs/store-review/remote-tags/android/*'
```

候補版と公開版の比較には `refs/store-review/remote-tags/` 配下の隔離refを使う。既存のローカルタグは上書きしない。

公開状態の取得は `main` 上の読み取り専用workflowを使う。dispatch前のUTC時刻を記録し、その時刻より後に作られた同じref・同じplatformのrunだけを採用する。該当runが複数あり一意に決められなければ止める。

```bash
gh workflow run inspect-store-state.yml --ref main -f platform=<ios|android|both>
gh run list --workflow=inspect-store-state.yml --event workflow_dispatch --limit 10 \
  --json databaseId,displayTitle,headBranch,status,conclusion,createdAt,url
gh run watch <run-id> --exit-status

state_dir=$(mktemp -d)
gh run download <run-id> -n ios-store-state -D "$state_dir/ios"
gh run download <run-id> -n android-store-state -D "$state_dir/android"
```

JSONから基準タグを厳密に解決する。

- iOS: `ios/v<version>+<buildNumber>` が存在すること。
- Android: `publicRelease.versionCodes` の最大値を `N` とし、`android/v*+N` がちょうど1つ存在すること。
- 基準タグ内の `apps/mobile/pubspec.yaml` がタグ表記と一致すること。

候補は各プラットフォームで最も新しいタグにする。次をすべて満たさなければ提出しない。

- タグ `platform/vX.Y.Z+N` が存在し、タグ内の `pubspec.yaml` が一致する。
- 対応する `ios-release.yml` / `android-release.yml` のrunが、タグcommitと同じ `headSha` で `success`。
- ストア側でビルド処理が完了し、既知の重大な不具合や待機中hotfixがない。
- 最新タグのworkflowが失敗している場合、古いタグへ黙って戻さず停止する。

公開版と候補が同一なら「審査提出する新しいビルドなし」と報告して終了する。公開版タグが候補タグの祖先でない、または公開版の方が新しい場合も、差分を推測せず停止する。

## 2. 累積差分からリリースノートを作る

プラットフォームごとに公開版から候補までを調べる。

```bash
git merge-base --is-ancestor <public-tag> <candidate-tag>
git log --no-merges --format='%h %s' <public-tag>..<candidate-tag> -- apps/mobile CHANGELOG.md
git diff --stat <public-tag>..<candidate-tag> -- apps/mobile
git diff <public-tag>..<candidate-tag> -- CHANGELOG.md
```

リリースノートは途中のカジュアルリリースを含む累積内容にする。

- ユーザーが認識できる新機能、操作改善、不具合修正だけを書く。
- CI、依存更新、テスト、内部リファクタだけの変更は書かない。
- コミット件名だけで判断できない変更は実diffと該当コードを読む。
- Bridgeの最低バージョンなど利用条件が増えた場合は明記する。
- 4言語の意味と箇条書きの対応を揃える。製品名や技術名は不自然に翻訳しない。
- iOSは各4000文字以内、Google Playは各500文字以内。空ファイルは禁止する。

保存先は次のとおり。

```text
# iOS
apps/mobile/fastlane/metadata/en-US/release_notes.txt
apps/mobile/fastlane/metadata/ja/release_notes.txt
apps/mobile/fastlane/metadata/ko/release_notes.txt
apps/mobile/fastlane/metadata/zh-Hans/release_notes.txt

# Android
apps/mobile/fastlane/metadata/android/en-US/changelogs/<N>.txt
apps/mobile/fastlane/metadata/android/ja-JP/changelogs/<N>.txt
apps/mobile/fastlane/metadata/android/ko-KR/changelogs/<N>.txt
apps/mobile/fastlane/metadata/android/zh-CN/changelogs/<N>.txt
```

## 3. 審査refを準備する

作業ツリーがdirtyなら直接切り替えず、一時worktreeを使う。審査refは最新の `origin/main` から作り、workflowと安全確認スクリプトを含める。iOSメタデータはiOS候補タグ、AndroidメタデータはAndroid候補タグから復元してから、生成したリリースノートだけを更新する。アプリのソースコードは変更しない。

ブランチ名は同じ候補なら `store/review-X.Y.Z-N`、異なる候補なら `store/review-<platform>-X.Y.Z-N` とする。既存ブランチをforce pushしない。既存refがある場合は内容と親commitを検査し、安全に再利用できなければ別名を使う。

次を確認して Conventional Commit でコミットし、明示した審査refへpushする。push後の完全な40文字commit SHAを `review_sha` として記録し、`git ls-remote origin refs/heads/<target-ref>` が同じSHAを返すことを確認する。以後はref名だけでなく、このSHAを提出内容の固定・workflow入力・run追跡に使う。

```bash
scripts/store-review/preflight.sh \
  <ios|android|both> <X.Y.Z> <N> 'SUBMIT <X.Y.Z>+<N>' \
  KEEP completed 0.1 APP_VERSION_ONLY
git diff --check
```

iOSとAndroidの候補バージョンまたはビルド番号が異なる場合、`both` を使わず、プラットフォーム別refと提出runに分ける。

## 4. 提出内容を検証・報告する

ストアを変更する前に、次をエージェントが検証し、対象と公開方式を簡潔に報告して進める。ノート全文はファイル参照で示し、承認待ちにしない。

- 各ストアの `公開版 → 候補` と候補release workflow URL
- 4言語のリリースノート全文と文字数
- iOS: `KEEP`、審査対象 `APP_VERSION_ONLY`
- Android: `completed`（全ユーザーへ100%公開）
- 対象ref、完全なcommit SHA、メタデータ反映・審査提出を続けて行うこと
- Managed publishing、既知の警告、APIで確認できない必須項目

通常の文言・翻訳・要約は差分に基づいて自動決定する。workflowの `confirmation` は選択した候補からエージェントが生成する誤操作防止入力であり、ユーザーから合言葉の入力を求めない。

## 5. メタデータ反映と審査提出

詳細は [references/ios.md](references/ios.md) と [references/android.md](references/android.md) を読む。

反映直前に `inspect-store-state.yml` をもう一度実行し、iOSのversion/build numberとAndroidのpublic release versionCodes/status/userFractionがノート作成時のsnapshotと一致することを確認する。公開版が変わっていたら未反映のまま手順1〜4をやり直し、差分・ノート・ref・SHAを更新して続行する。再計算は1回までとし、再び状態が変わる場合は競合を報告して停止する。候補が公開済みなら提出不要として終了する。

各dispatch直前にも `git ls-remote` で対象refが検証済み `review_sha` を指すことを確認する。workflowへ `expected_ref_sha` を渡し、workflow側でもcheckout済み `${GITHUB_SHA}` と完全一致しなければ、ストア操作前に停止させる。

iOSは対象バージョンを明示してメタデータを先に反映し、成功を確認する。

```bash
gh workflow run upload-metadata.yml \
  --ref <target-ref> \
  -f platform=ios \
  -f ios_version=<X.Y.Z> \
  -f expected_ref_sha=<review-sha> \
  -f upload_screenshots=false \
  -f upload_metadata=true \
  -f upload_images=false
```

その後、同じrefで審査提出する。iOSとAndroidの候補が同一なら `both`、異なるなら別runを使う。

```bash
gh workflow run submit-store-review.yml \
  --ref <target-ref> \
  -f platform=<ios|android|both> \
  -f version=<X.Y.Z> \
  -f build_number=<N> \
  -f confirmation='SUBMIT <X.Y.Z>+<N>' \
  -f expected_ref_sha=<review-sha> \
  -f ios_release_type=KEEP \
  -f ios_review_scope=APP_VERSION_ONLY \
  -f android_release_status=completed \
  -f android_user_fraction=0.1
```

Androidは全ユーザーへの100%公開（`completed`）を既定にする。段階配信を使うのはユーザーが明示した場合だけで、そのときは `inProgress` と指定された初期配信率（未指定なら `0.1`）を使う。GitHub Environment `store-review` の Required reviewers は追加の組織側ゲートとして維持する。

## 6. 完了を検証する

workflowを起動しただけで完了としない。dispatch時刻・ref・表示名でrunを一意に特定し、終了まで監視する。

```bash
gh run list --workflow=upload-metadata.yml --limit 10 \
  --json databaseId,displayTitle,headBranch,headSha,status,conclusion,createdAt,url
gh run list --workflow=submit-store-review.yml --limit 10 \
  --json databaseId,displayTitle,headBranch,headSha,status,conclusion,createdAt,url
gh run watch <run-id> --exit-status
```

対象runは `headBranch == <target-ref>` かつ `headSha == <review-sha>` のものだけを採用する。どちらかが一致しなければ、そのrunを提出結果として扱わない。

- iOSは `WAITING_FOR_REVIEW`、`IN_REVIEW`、または既に `COMPLETE` をAPIで確認する。
- Androidは対象versionCodeだけをproductionへ昇格し、editのcommit成功を確認する。
- Google Playに別変更が審査中なら `ERROR_IF_IN_REVIEW` で停止し、既存審査を取り消さない。
- Android対象versionCodeが既にproductionにある再実行は、APIだけで審査送信済みか断定できないため無変更で停止する。前回runを確認する。
- Managed publishingは変更しない。有効なら承認後の手動公開が必要と報告する。

最後に、公開版、候補、各workflow URL、公開方式、審査状態、残る手動項目をまとめる。
