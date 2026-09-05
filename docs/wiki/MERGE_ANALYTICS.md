# Merge analytics

Updated 2026-09-04. `configs/merge_analytics.lua` owns the versioned native Roblox event contract.
`MergeAnalyticsService` runs only in the dedicated Merge place and observes authoritative server
outcomes. It does not write profiles, grant rewards, change gameplay, or add client remotes.
Existing Homeworld Onboarding, Activation, and Combat Training remain unchanged.

## Creator Hub readout

Open the experience in Creator Hub → Analytics → Funnels. After publishing and real eligible
traffic, look for the seven **Merge … v1** funnels below. Do not rename/reorder their steps in
place: publish a new version if meanings change. Existing three plus these seven use the ten-tab
budget. Roblox ingestion/dashboard delay applies; Studio tests cannot populate these charts.

| Funnel | Denominator / grain | Steps and interpretation |
| --- | --- | --- |
| Merge Entry v1 | One player visit to a Merge server, starting when this service registers the player | Joined → profile ready → bay assigned → session armed/restored → first live wave started. The last step can take longer for a fresh board. Entry failures are separate diagnostics. |
| Merge Activation v1 | One **fresh-board** bay session, not an experience-first-time user | Board ready → egg bought → egg placed on defense line → wave started → wave resolved alive. Restored saves/checkpoints are excluded. A returning player starting an empty board can qualify; do not label this new-user conversion. |
| Merge Run Depth v1 | One armed bay session, including restored boards | Ready → 1 / 5 / 10 / 25 / 50 / 100 newly resolved waves. Resuming wave 308 and resolving it counts **one**. This is engagement depth, not highest-wave achievement. |
| Merge Artillery v1 | First accepted artillery interaction per bay session | Interaction → installation or upgrade → upgrade. A restored cannon's first upgrade legitimately meets the last two steps. Unlocking alone is not installation. |
| Merge Bulwark v1 | First accepted bulwark interaction per bay session | Same definition as artillery. Autoplay's accepted purchase counts as an interaction even without a visible menu. |
| Merge Rebirth v1 | First observed egg requirements **and wallet** eligibility per bay session | Eligible → valid confirmed request admitted → completed rebirth with rearmed session. Confirmation can fail after admission; successful debit alone is not completion. No automatic rebirth is introduced. |
| Merge Autoplay v1 | Owned entitlement observed in a bay session | Owned → enabled → one successful automated action → ten successful actions. This is pass utilization, **not purchase conversion**. |

Primary measures: entry success = step 4 / step 1; fresh-board activation = step 5 / step 1;
run depth = each threshold / ready. Use funnel sessions (not unique-user totals) consistently.
Review daily after traffic arrives, with a weekly cohort view to reduce small-sample noise.
No baseline or target is claimed yet. The game owner owns interpretation and tuning decisions.

## Filters and diagnostic events

Funnel custom fields: **01** board cohort (`fresh`, `restored`, `unknown` at entry), **02** control
mode (`manual` / `autoplay`) when that funnel first starts, **03** published place version.
Roblox freezes filters at the first step; a manual starter who enables autoplay remains in that
funnel's manual cohort. Use current-mode custom events for subsequent actions. Do not infer a
causal autoplay benefit by comparing these self-selected cohorts.

Custom events use field 01 = event/reason/stage, field 02 = context below, field 03 = **current**
manual/autoplay mode. Names and finite allowlists live in config; never use player names, raw
errors, bay IDs, currency amounts, GUIDs, or arbitrary client text as dimensions.

- **Merge Milestone v1**: once per milestone per bay session: collected an actually credited
  Merge coin drop, bought/placed/combined eggs, upgraded the base, installed/unlocked defenses,
  completed rebirth, enabled/used autoplay, or suffered a defense overrun. Field 02 = board cohort.
- **Merge Tutorial v1**: once per entered configured tutorial stage per bay session. Field 02 =
  board cohort. Includes setup, workshop, cannon, egg upgrade, and quartermaster stages. Entry
  is **not** completion; stages are an optional branch and are not added to core activation.
- **Merge Failure v1**: once per bounded reason/action pair per bay session (or entry visit
  before a bay exists). Field 02 = action category. Includes entry timeout, missing profile/root,
  session cancellation, and rejected board requests. Unknown errors bucket to `other`.
  These counts are affected **sessions**, not total failed clicks.
- **Merge Exit v1**: once per ended bay session, or failed/no-bay visit. Field 01 = last tutorial
  stage, activation prefix, restored-session marker, or entry prefix. Field 02 = end reason.
  Event **value is elapsed seconds**; use event count for exits and average value for duration.
  Bay reset/switch/character removal is an ending, not necessarily a player quitting the game.

Start diagnosis with entry step 2→4 loss and Failure `session_ended` / `entry_timeout`, then fresh
activation loss and Tutorial/Exit stage. Follow with run depth and `defense_overrun`. Workshop
and rebirth funnels answer optional-system utilization without falsely marking non-buyers as
core onboarding failures. Purchase receipts and the existing economy analytics remain the money
source of truth; these events are **not** a revenue ledger or a highest-wave save migration.

## Correctness and operational guardrails

- GUIDs are native funnel session IDs only. Entry is per player visit; other funnels are per bay
  claim. Record identity rejects stale callbacks after a switch/respawn. Player cleanup is isolated.
- Buffer observed steps until their real contiguous predecessors exist: Roblox otherwise
  automatically fills skipped steps. Repeated callbacks don't resend milestones.
- Wave counters use only live resolution callbacks while the defense survives. Escapes can occur:
  “resolved alive” does not mean every enemy was killed. Duplicate/checkpoint replay waves at or
  below the session high-water mark don't increment depth. A successful rebirth resets that wave
  identity, not the visit's accumulated depth; all counters cap at the final configured threshold.
- Studio and configured internal accounts are excluded from **all native Merge analytics**.
  Studio keeps a bounded trace for QA. No synthetic test data or historical achievements are sent.
- A bounded FIFO sends at the configured cadence, with bounded retries. Overflow or exhausted
  retries block subsequent steps of that same funnel so missing predecessors cannot be fabricated.
  Departures prioritize the independent exit summary and flush a bounded ordered remainder.
  Very short visits, overload, API failures, abrupt server termination, or Roblox rate limits can
  lose events. This is best-effort product telemetry, not a durable transaction log. No extra
  Datastore writes or per-attack network traffic. Native calls are protected from gameplay.
- No historical backfill: charts start with the published build. Funnel conversion is grouped by
  funnel start date. Check cohort sizes and transport health before diagnosing a drop as gameplay.

## Verification

- `mise run ci` includes `tests/headless/specs/merge_analytics.spec.luau`: strict ordering,
  deduplication, restored waves, bounded counters, three independent players, optional paths.
- `tests/studio/MergeAnalyticsSmoke.lua`: isolated actors, stale-record rejection, exit/tutorial
  attribution, arbitrary error bucketing, no Studio native traffic, retries and overflow preventing
  fabricated conversion. No real wallets/profiles are modified.
- In Studio Server, inspect the actual bound service with
  `game.ServerStorage.MergeAnalyticsStudioSnapshot:Invoke(player)` (read-only, Studio only).
  It returns entry/bay prefixes, bounded trace, queue size and dropped events.
- Final acceptance in production: Quick Publish Merge, join with a non-internal account, perform
  a fresh-board activation and a restored visit, then verify v1 funnel counts/fields in Creator Hub
  after ingestion. Internal accounts and Studio alone cannot satisfy this check.

Sources: [Roblox funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)
and [AnalyticsService](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService).
See also [Retention Analytics](RETENTION_ANALYTICS.md) and [Merge Autoplay](MERGE_AUTOPLAY.md).
