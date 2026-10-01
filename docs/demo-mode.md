# Offline demo

CC Pocket's connection screen includes **Try without connecting** (Japanese:
**接続せずに試す**). It is available in release builds to all users, without a
Bridge server, AI account, or purchase.

The walkthrough shows a sample request, an edit approval or rejection, and a
code diff. A custom message starts the same scripted example; it is not sent to
an AI. A persistent banner identifies the sample behavior. Starting again or
leaving the screen discards the demo input and state.

## Implementation boundary

`features/demo/` uses its own `DemoCubit` and reuses the shipping assistant/user
bubbles and diff renderer. It does not create a `BridgeService`, read live
sessions, or write connection settings, drafts, files, or approval preferences.
The sample edit changes only local presentation state. Existing developer mock
scenarios are not exposed as the public demo.

## Review instructions

1. Launch the app and tap **Try without connecting** on the connection screen.
2. Tap **Make the welcome message friendlier**, or type a sample request.
3. Tap **Allow once** to inspect the sample diff, or **Reject** to decline it.
4. Use **Start again** to repeat the walkthrough, or close it to return to setup.

This demonstrates the interaction model; it does not execute AI tools or test
real Bridge connectivity. It is not a substitute for all app functionality or a
guarantee of store review acceptance. Explain that limitation accurately when
submitting, and supplement with a real-workflow video where requested.

## Validation

`flutter test test/demo_test.dart` covers state transitions, the public entry,
custom input, approval/rejection, re-entry, unsent-draft reset, and all four
locales on a small screen with enlarged text. The widget harness deliberately
provides no Bridge or persistence services.
