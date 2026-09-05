# Store submission prepared for review

Status: awaiting the maintainer's visual/content check. No store metadata upload or review submission has run.

- Public iOS: 1.127.1 (243), READY_FOR_DISTRIBUTION.
- Public Android: versionCode 243, completed.
- Candidate for both: 1.127.2 (244), existing release builds.
- Read-only snapshot: https://github.com/K9i-0/ccpocket/actions/runs/33935242768
- iOS release workflow: https://github.com/K9i-0/ccpocket/actions/runs/33927390316
- Android release workflow: https://github.com/K9i-0/ccpocket/actions/runs/33927396035
- Review ref: store/review-1.127.2-244
- Review SHA: a06f6793b8e919063173149929d8e02b29bdaa85
- Source branch: feat/mint-readme-store

After approval, re-read the public store state and verify the review ref still
points to the SHA above. Upload the four-language metadata, screenshots, and
Google Play feature graphics from that ref, then submit the existing builds.
No new app binary, tag, IAP, or subscription is included.

iOS: KEEP the existing release setting; if a new App Store version must be
created, the workflow defaults to MANUAL. Review scope is APP_VERSION_ONLY.
Android: completed (100% rollout after approval). Managed publishing is not
changed; if enabled, publishing still requires the existing manual action.
The read-only workflow does not expose Managed publishing or every required
console form, so these remain subject to the submission workflow checks.

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
