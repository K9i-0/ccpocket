# Store submission — 1.127.2 (244)

Status (2026-09-05): maintainer approved the Mint assets and content. Both stores'
metadata uploads succeeded. iOS is WAITING_FOR_REVIEW. Android production release
1.127.2 (244) is in review, confirmed in the Console. Android's 20 listing changes
have been approved and are ready for manual publishing. Nothing was published.

- Approved-state recheck: https://github.com/K9i-0/ccpocket/actions/runs/33936454589
- Metadata and images upload (both succeeded): https://github.com/K9i-0/ccpocket/actions/runs/33936612925
- Submission run (iOS succeeded, Android stopped): https://github.com/K9i-0/ccpocket/actions/runs/33936733459
- Google Play publishing overview: https://play.google.com/console/u/0/developers/6160648729759324658/app/4972604564193312237/publishing

Google Play's metadata upload sent the approved four-language listing changes
for review before the binary submission. The Android workflow then stopped with
FAILED_PRECONDITION under ERROR_IF_IN_REVIEW. The Console was used to prepare
production release 1.127.2, containing only existing versionCode 244, the approved
four-language release notes, and 100% rollout. After automatic approval review
blocked adding it to the active listing review, the maintainer explicitly
authorized canceling and restarting that review with versionCode 244. During
the resumed operation the listing changes became approved. The Console then
accepted the release through its regular "Send changes for review" confirmation.
The final publishing overview shows production release 1.127.2 under changes in
review, all 20 listing changes ready to publish, and Managed publishing ON.
Do not rerun the promotion workflow: the Console submission is complete.

- Public iOS: 1.127.1 (243), READY_FOR_DISTRIBUTION.
- Public Android: versionCode 243, completed.
- Candidate for both: 1.127.2 (244), existing release builds.
- Read-only snapshot: https://github.com/K9i-0/ccpocket/actions/runs/33935242768
- iOS release workflow: https://github.com/K9i-0/ccpocket/actions/runs/33927390316
- Android release workflow: https://github.com/K9i-0/ccpocket/actions/runs/33927396035
- Review ref: store/review-1.127.2-244
- Review SHA: a06f6793b8e919063173149929d8e02b29bdaa85
- Source branch: feat/mint-readme-store

The public state and immutable ref were rechecked after approval and matched.
The four-language metadata, screenshots, and Google Play feature graphics were
uploaded from that ref. The iOS workflow submitted the existing build.
No new app binary, tag, IAP, or subscription is included.

iOS: KEEP preserved MANUAL, confirmed by asc validation. Review scope is
APP_VERSION_ONLY. Release requires a manual action after approval.
Android: 100% rollout is submitted. Managed publishing is ON, confirmed in the
Console and unchanged. Release requires a manual action after approval.

The iPhone captures also serve the Android listing by explicit maintainer
request. The app's orange accent is retained inside all genuine screenshots.
The audio player loaded its 12s sample during capture; playback progress did
not advance in the iOS simulator. No audio-player implementation was changed.

## Release notes (identical meaning on both stores)

### en-US — 174 characters excluding trailing newline

• Fixed reasoning-effort options for GPT-6 Astra. Unsupported None and Minimal options are hidden, and saved selections are moved to Light.
• Requires Bridge 1.81.2 or later.

### ja — 95 characters excluding trailing newline

・GPT-6 Astraの推論強度の選択肢を修正しました。非対応のNone・Minimalを非表示にし、保存済みの選択をLightへ移行します。
・Bridge 1.81.2以降が必要です。

### zh-Hans — 83 characters excluding trailing newline

• 修正GPT-6 Astra的推理强度选项：隐藏不支持的None和Minimal，并将已保存的选择迁移为Light。
• 需要Bridge 1.81.2或更高版本。

### ko — 109 characters excluding trailing newline

• GPT-6 Astra의 추론 강도 선택지를 수정했습니다. 지원하지 않는 None과 Minimal을 숨기고 저장된 선택을 Light로 전환합니다.
• Bridge 1.81.2 이상이 필요합니다.
