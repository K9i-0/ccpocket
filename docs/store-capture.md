# Store capture set

The current phone set is defined by `apps/mobile/fastlane/screenshots/compose.sh`.
Use `mobile-automation` to launch the current app and connect Marionette.
Capture each phone scenario with the dark theme in en, ja, zh, and ko, saving
raw PNGs under en-US, ja, zh-CN, and ko respectively.

| File key | Scenario | Extension |
| --- | --- | --- |
| 01_conversation | LP Conversation | ccpocket.mock.openScenario |
| 02_recent_sessions | Recent Sessions | ccpocket.navigateToStoreScenario |
| 03_approval_list | Approval List | ccpocket.navigateToStoreScenario |
| 04_git_review | Git Actions | ccpocket.navigateToStoreScenario |
| 05_network_resilience | LP Network | ccpocket.mock.openScenario |
| 06_imagegen | LP Imagegen | ccpocket.mock.openScenario |
| 07_video | LP Video | ccpocket.mock.openScenario |
| 08_audio | LP Audio | ccpocket.mock.openScenario |

Call `ccpocket.popToRoot` between scenarios and wait for rendering before
capturing. For media fixtures, run `scripts/landing-preview/prepare.sh` and
`scripts/landing-preview/serve.mjs`; stop the server after capture. Verify
the players show the loaded 12-second duration.

The Git Actions mock supplies a dedicated `store-git-review` feedback binding.
Long-press a hunk, choose Comment, enter a review note, and finish editing
before capture. This uses the shipping comment UI with mock Git data.

The iPad set remains Workspace Overview, Workspace Explorer, Approval In
Context, Approval Queue, and Dark Workspace, in landscape. Capture English
raw images; compose.sh applies the four localized headings. Use light mode
except for Dark Workspace.

Use simctl screenshots at native resolution, inspect for system permission
dialogs and layout overflow, then run `LOCALIZED_PHONE_CAPTURES=true bash fastlane/screenshots/compose.sh`
from apps/mobile. Without that flag, compose.sh uses English raw images for
all localized headings. Output sizes are 1320×2868
for phone and 2752×2064 for iPad. The script also updates Play Store images
and the README banner.
