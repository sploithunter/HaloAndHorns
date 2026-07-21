# Retention Analytics

Status: implemented 2026-07-18.

`RetentionService` is the server-side observer for activation telemetry. Gameplay systems continue
to publish semantic events through `FireGameEvent`; the retention service maps those events through
`configs/retention.lua` and archives the complete server-observed event stream.

## What is measured

The native Roblox onboarding funnel starts at join, contains every tutorial completion, then tracks
the first quest (`fs_boost`), the First Steps capstone (`fs_cave`), and the first paid area unlock.
Out-of-order achievements are persisted immediately but submitted to the funnel only when the
contiguous prefix exists, because Roblox treats skipped funnel steps as completed.

Every configured milestone plus every unique claimed quest and unlocked area is stored once:

`profile.Analytics.Retention.Milestones[id] = { at, session, seconds, category, detail }`

This record answers how far one player reached and in which session/how many seconds. Existing
`Analytics.SessionCount`, `TotalPlayTime`, and `LastSessionDuration` remain the session source of
truth.

The first-companion role lesson has its own pre-hatch microfunnel. The semantic events
`starter_pet_choice_shown` and `starter_pet_selected` are present in the raw stream, and daily
aggregate shards expose `starterChoice.shown`, `selected`, `totalSecondsToSelect`, and `byPet`.
These are first-session distinct counts, so the selector's conversion, average decision time, and
role preference are available without downloading raw chunks. They deliberately do not alter the
already-live Roblox onboarding funnel step order.

## Raw launch dataset

`RetentionEvents_v1` is the single standard DataStore for event-level launch analysis. It contains
all events observed on the semantic `FireGameEvent` bus, not only funnel milestones. It also records
session start/end progression snapshots and a whitelisted client-context event (derived device
class, locale, viewport, and available input types). Usernames and device identifiers are not
collected.

The grain is one event. Keys are partitioned rather than contended:

`dYYYYMMDD/u<userId>/s<sessionNumber>/c<chunkNumber>`

Each chunk repeats cohort, user, session, server, place, and start-time fields and holds up to 100
ordered events. Writes flush every 15 seconds, at 100 pending events, on player removal, and at
server shutdown. Partitioning keeps the dataset in one inspectable store without putting every
player behind one 4 MB key or one per-key write bottleneck.

The same store contains mergeable daily counter shards:

`aYYYYMMDD/j<serverJobId>`

Each server owns its shard, so no live servers contend on one counter key. Shards count sessions,
completed-session seconds, first-session players, tutorial step reach and total time-to-step,
tutorial exits by active step, quest/area completions, level events, and earned/claimed level at
exit, plus the starter-choice microfunnel and pet split. The raw events remain the source of truth for medians, quantiles, segmentation, and metric
recomputation; shard sums provide an immediate launch readout.

Canonical launch definitions:

- Average completed session time = total ended-session seconds / ended sessions.
- Tutorial completions = players firing the one-time completion event in any session.
- New-player tutorial completion rate = first-session tutorial completions / first-session players.
- Step reach rate = distinct first-session players completing a step / first-session players.
- Step conversion = distinct players completing a step / distinct players completing its previous
  step.
- Tutorial exit step = the active tutorial objective when a first-session player left unfinished.
- Pre-level-2 exit rate = first-session players leaving below earned (or claimed) level 2 /
  first-session players whose session ended.

For an immediate long-form export, create a read-only Open Cloud key with list/read access, then:

```bash
export ROBLOX_API_KEY='...'
python3 tools/export_retention.py \
  --universe-id <UNIVERSE_ID> \
  --date 20260718 \
  --output retention-export-20260718
```

The exporter writes lossless `chunks.jsonl`, event-grain `events.jsonl`, analyst-friendly
`events.csv`, raw `aggregates.jsonl`, `summary.json`, `tutorial_funnel.csv`, `level_exit.csv`,
`event_counts.csv`, `cohort_summary.csv`, and a count manifest. The key is read only from the
environment and is never written to an output file.

## Admin access

- Aggregate: Creator Dashboard → Analytics → Funnels / Explore. The custom event is
  `RetentionMilestone`, broken down by category and milestone id.
- Individual live player: `retention.get` on the server Game API returns the ordered funnel and
  full milestone list.
- Full launch dataset: Creator Hub Data Stores Manager can inspect `RetentionEvents_v1`; the
  read-only exporter produces all date-prefixed chunks for notebooks/SQL.
- Individual offline player: `PlayerData_v2_mixedPets` remains the authoritative gameplay profile,
  while `RetentionEvents_v1` provides the ordered behavioral trace.

Only genuine first-session profiles enter the Roblox onboarding funnel. All profiles retain new
milestones and raw events for diagnosis. Analytics calls and raw event-store writes are server-only
and suppressed in Studio.

## Launch readout: 2026-07-20 campaign cohort

The first campaign-coincident snapshot covered 43 production session-1 profiles beginning after
the Ads Manager schedule started at 2026-07-20 21:00 UTC. Internal telemetry was complete: every
session had an end event and client context, and the 761 raw chunks had no chunk gaps, event-sequence
gaps, or duplicate sequence numbers.

The main leak was join → first hatch: 29/43 (67.4%) reached the first tutorial objective. Tutorial
completion was 9/43 (20.9%; 95% Wilson interval 11.4%–35.2%) and canonical first-session activation
was 7/43 (16.3%; 8.1%–30.0%). Every later tutorial step converted at least 78.9% from the previous
step. Players who never hatched stayed a median 11.6 seconds versus 139 seconds among players who
hatched; this is descriptive rather than a causal estimate. Treat the opening 20 seconds as the
first product intervention and keep acquisition spend small until a fresh cohort improves.

Roblox Ads Manager still had no attributed plays in this snapshot, so the 43 internal first
sessions are not labeled as paid conversions. D1 was not mature when this readout was made.

## Pre-publish marker: consistent Home/Grass pets

At 2026-07-21 17:39:40 UTC (11:39:40 AM MDT), the aggregate-only production snapshot recorded 50
ended first sessions on the 2026-07-21 UTC cohort date. The consistent Home/Grass pet candidate was
Studio-verified at commit `a1eac80` but had not been merged or published; production still reported
build `bc337a4`. This is therefore a pre-exposure baseline, not a post-change result.

The exact counter snapshot is stored at
`docs/wiki/raw/retention/2026-07-21_home_grass_consistent_pets_baseline.json`. Future aggregate pulls
can subtract that snapshot from the current 2026-07-21 counters, then use full subsequent UTC days,
without downloading raw 100-event chunks. Raw chunks are reserved for medians, player timelines,
device cuts, and forensic follow-up.

`RetentionService` now stamps build version, commit, branch, build time, dirty state, and analytics
schema version into each future raw-session and aggregate-shard server record. The first production
publish containing that telemetry becomes the durable intervention boundary; build-grouped shards
will allow quick published-version comparisons without hand-matching server jobs.

## Export operations

`tools/export_retention.py` retries Roblox Open Cloud 429/5xx responses with bounded backoff and
paces entry reads. Use `--session-number 1` to avoid downloading veteran/test traces when the
question is first-session acquisition behavior; aggregate shards still cover all sessions for the
selected UTC date and the manifest records that distinction. The active production universe is
`10307183003` (place `77766176054993`). A stale local universe id can successfully authenticate but
list a different set of DataStores, so verify the universe before treating a missing
`RetentionEvents_v1` store as a telemetry failure.
