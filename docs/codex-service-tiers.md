# Codex service tiers

CC Pocket reads the current model's speed candidates from Codex app-server
`model/list`. The catalog is not proof of account entitlement: Codex/OpenAI still
authorizes requests, and an advertised tier may not be usable on an account.

## Protocol compatibility

- `codexModelServiceTiers` keeps its existing model-to-id-list shape. The historic
  `priority` id is normalized to `fast`.
- `codexModelServiceTierMetadata` adds model-to-entry lists, with `id`, `name`, and
  optional `description` retained from the catalog. An explicitly empty catalog
  is authoritative. Older `additionalSpeedTiers` responses remain supported.
- The `codex_service_tiers_v1` capability means Bridge understands extended tier
  ids and rejects unsupported selections instead of coercing them to Standard.
  It does not mean that Ultrafast is authorized for the account.
- A new app connected to an older Bridge keeps Standard/Fast compatibility and
  does not send extended tiers, even if its saved defaults contain one.

Extended-speed selection is explicit. Switching models or restoring saved
extended tiers never silently substitutes another speed. Unavailable extended
tiers remain visible so the user can choose a supported option. The existing
Standard/Fast behavior is retained: switching to a model without Fast visibly
normalizes the draft to Standard, and older clients' model-then-Standard message
sequence remains compatible. Runtime setting changes are displayed
after Bridge acknowledges them, not optimistically before a possible rejection.

Ultrafast consumes usage faster than Standard. Review OpenAI's current
[speed and usage billing documentation](https://learn.chatgpt.com/docs/agent-configuration/speed#ultrafast-mode)
before opting in; a faster token-generation rate does not imply the same speedup
for a whole task, including tool execution and network waits.

New and resumed threads retain extended-tier requests. Extended tiers require an
explicit matching tier in the thread response; an old CLI that ignores the
field cannot appear to have accepted it. Inherited extended settings are checked
against the resolved model before any prompt is sent. A confirmed thread setting
is still not proof that a subsequent inference used that tier. Legacy CLI
Standard/Fast responses retain their existing compatibility behavior, while an
unrequested switch to an extended tier is rejected.

## Validation boundary

Development regression tests use synthetic catalogs, including Ultrafast, plus
the tier shape observed with Codex CLI 0.162.1. That CLI returned `priority` / Fast
and `ultrafast` / Ultrafast for Astra and Sol in a read-only `model/list` probe.
No account details are needed for the catalog and none should be included in
bug reports.

Before treating Ultrafast as verified end to end, use an eligible account to
confirm its catalog, new/resumed session behavior, actual effective processing
tier and usage. UI selection or successful settings submission alone does not
establish entitlement, billing or a throughput improvement.
