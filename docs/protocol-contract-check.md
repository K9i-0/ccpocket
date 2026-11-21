# App / Bridge protocol contract check

## Purpose

The wire protocol is written twice by hand: as TypeScript types in
`packages/bridge/src/parser.ts`, and as Dart code in
`apps/mobile/lib/models/messages.dart`. This check fails the build when the two
disagree about message types or keys. It adds no hand-written fixtures; both
inputs are the sources themselves.

## How it works

1. `apps/mobile/tool/protocol_surface.dart` parses the Dart sources (syntax
   only) and extracts:
   - for each map literal that becomes a client message: its `type`, the keys
     that are always present, and the keys that are conditional
     (`if (...) 'k': v`, `'k': ?v`, or assigned afterwards);
   - for each case of `ServerMessage.fromJson`: the keys it reads, split into
     keys cast to a non-null type (the message is lost without them) and keys
     read in a way that tolerates absence. Calls that receive the whole map
     (`Foo.fromJson(json)`, `_helper(json)`) are followed;
   - the default `supportedServerMessages` of `client_capabilities`.
2. It writes that as types to
   `packages/bridge/src/protocol-contract/app-surface.generated.ts`, which is
   committed.
3. `packages/bridge/src/protocol-contract/check.ts` compares those types with
   `ClientMessage` and `ServerMessage`. It has no runtime code: a mismatch is a
   type error from `tsc`, and the error text names the message and the keys.

Two existing CI steps cover it: the Bridge type check runs the comparison, and
`apps/mobile/test/protocol_surface_test.dart` fails when the generated file is
not what the current Dart sources produce.

## What is checked

| Direction | Rule |
| --- | --- |
| App → Bridge | Every `type` the app sends is a `ClientMessage`. |
| App → Bridge | Every key the app sends is declared for that message. |
| App → Bridge | Every key the Bridge requires is always sent. |
| Bridge → App | Every `ServerMessage` type is parsed by the app, or listed in `ServerMessagesIgnoredByApp` with a reason. |
| Bridge → App | Every type the app parses is a `ServerMessage`. |
| Bridge → App | Every key the app reads is declared, or listed in `LegacyKeysReadByApp` with a reason. |
| Bridge → App | Every key the app casts to a non-null type is required in all variants of that message. |
| Bridge → App | Every opt-in server message the app parses is requested by default. |

## When it fails

- After changing `messages.dart` or adding a client message elsewhere: run
  `dart run tool/protocol_surface.dart` in `apps/mobile` and commit the
  generated file.
- A type error in `check.ts`: read the type in the message. It says which side
  disagrees. Fix the Dart code or the type in `parser.ts`; within protocol 1 a
  field cannot be renamed, removed or made required
  ([protocol-versioning.md](protocol-versioning.md)).
- Only when the difference is intended, add it to one of the two exception
  lists in `check.ts`, with the reason and the condition for removing it.

Build client messages with a `ClientMessage` factory. A map passed to
`ClientMessage.raw` is only seen when it is a literal at the call site.

## Limits

- Keys only, at the top level of a message. Value types and nested objects are
  not compared.
- It compares against the declared types, not against what the Bridge really
  sends: `send()` also accepts untyped records. Declaring a message in
  `ServerMessage` is what brings it under the check.
- `parseClientMessage` validates more strictly than the types say (non-empty
  strings, enum values). That is not visible here.
- The types describe the current Bridge. Whether the app tolerates an older
  Bridge that omits a now-required key is not checked.
- A key read through a variable (`final m = json['x'] as Map; m['y']`) or
  built through a non-literal spread is not seen. The generated file lists
  such places under "Not covered"; the list is currently empty.

## What the first run found

- Ten server messages the Bridge sent without declaring them (`session_list`,
  `recent_sessions`, `input_ack`, `input_rejected`, `past_history`,
  `project_setup_result`, `recording_list`, `recording_content`,
  `archive_result`, `branch_update`), and four undeclared keys of `system`
  (`effort`, `fastMode`, `ultracode`, `forked`). All are now declared; nothing
  on the wire changed.
- `bootstrap_project`, `trust_project` and `initialize_git` were sent as raw
  maps with the `requestId` added later. They are `ClientMessage` factories
  now, with the same keys, except that `initialize_git` no longer carries a
  `sessionId`: no Bridge has ever declared or read it for that message.
- Two legacy keys the app still reads as fallbacks (`file_list.ignoredFiles`,
  `gallery_list.project`), recorded in `LegacyKeysReadByApp`.
