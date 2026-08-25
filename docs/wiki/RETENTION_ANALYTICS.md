# Retention Analytics

Status: implemented 2026-07-18.

`RetentionService` is the server-side observer for activation telemetry. Gameplay systems continue
to publish semantic events through `FireGameEvent`; the retention service maps those events through
`configs/retention.lua` and archives the complete server-observed event stream.

## What is measured

The native Roblox onboarding funnel starts at join, contains every Homeworld
and combat-training tutorial completion, and **ends at Rally**. First quest
(`fs_boost`), First Steps (`fs_cave`), and the first paid area unlock are
optional, so they live on a separate named **Activation** funnel
(`LogFunnelStepEvent`) that also starts at join. Out-of-order achievements
are persisted immediately but submitted only when the contiguous prefix
exists, because Roblox treats skipped funnel steps as completed.

Creator Hub snapshots from 2026-08-24 (7-day / 28-day / 1-day) are archived
at [raw/retention/2026-08-24_creator_hub_funnels.md](raw/retention/2026-08-24_creator_hub_funnels.md).

Every configured milestone plus every unique claimed quest and unlocked area is stored once:

`profile.Analytics.Retention.Milestones[id] = { at, session, seconds, category, detail }`

This record answers how far one player reached and in which session/how many seconds. Existing
`Analytics.SessionCount`, `TotalPlayTime`, and `LastSessionDuration` remain the session source of
truth.

Distinct return-window claims are stored on the profile under
`Analytics.Retention.ReturnTracking`. The immutable UTC first-join cohort and a three-key claim
ledger ensure that repeat sessions cannot increment the same player's window twice.

The first-companion role lesson has its own pre-hatch microfunnel. The semantic events
`starter_pet_choice_shown` and `starter_pet_selected` are present in the raw stream, and daily
aggregate shards expose `starterChoice.shown`, `selected`, `totalSecondsToSelect`, and `byPet`.
These are first-session distinct counts, so the selector's conversion, average decision time, and
role preference are available without downloading raw chunks. They deliberately do not alter the
already-live Roblox onboarding funnel step order.

Committed power picks (`power_selected`, `{power, level}`) are counted in every session, not just
the first. Daily shards expose `powerPicks.total`, `byPower`, and `byLevel`. Share is
`count / total` among committed picks — not pick-rate-among-offered, because the POWERS menu
shows the remaining pool rather than a rolled subset. After publish, Creator Hub → Analytics →
Events → `PowerPicked` breaks down Custom Field 1 = power id and Custom Field 2 = claimed
level. Internal accounts are omitted from that custom event and from the dashboard. Historical
`RetentionEvents_v1` already contains `power_selected`; `tools/export_retention.py` writes
`power_picks.csv` from those raw events so a percentage readout does not have to wait for new
shards.

Tutorial definition v5 (2026-08-24) is the Resonance-before-combat restore after the
v4 Hall rollback. Funnel step **order** matches that path; live milestone **IDs** stay
stable (`tutorial_completed` still means enhance Resonance / `slot_power`).

Retention config v7 (2026-08-24) keeps the 32 combat-training beats between
`tutorial_completed` and `tutorial_first_fight`, then ends onboarding at
Rally. Combat events use prefixed step ids (`combat_ready`, …) so they
cannot collide with Homeworld `first_fight`. Compare cohorts by
`placeVersion`; do not read old step 9 as the new combat lobby. The
published Creator Hub chart on 2026-08-24 is still the 14-step list
without those combat beats.

Tutorial definition v2 is the 2026-08-10 FTUE reorder boundary. It replaces the redundant
`tutorial_equip_pet` milestone with `tutorial_build_squad`; the canonical opening is now first egg,
mine, second egg, contextual squad review, then combat. Existing raw events and dated dashboard
shards remain historical truth under their original step ids. Persisted active v1 tutorial progress
is explicitly migrated, while players already at the fight or later are not sent backward to the
new review lesson. Cohort comparisons across this boundary must use `placeVersion`/build fields and
must not interpret the two step names as the same action.

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

The server envelope includes Roblox's `placeVersion` as the authoritative
published-build boundary. It increments on every Roblox publish independently of
Rojo or the generated git label; `buildCommit` remains the source-code mapping
when the stamp is available.

The same store contains mergeable daily counter shards:

`aYYYYMMDD/j<serverJobId>`

Each server owns its shard, so no live servers contend on one counter key. Shards count sessions,
completed-session seconds, first-session players, tutorial step reach and total time-to-step,
tutorial exits by active step, quest/area completions, level events, and earned/claimed level at
exit, plus the starter-choice microfunnel and pet split. The raw events remain the source of truth for medians, quantiles, segmentation, and metric
recomputation; shard sums provide an immediate launch readout.

## External-player quick dashboard

`RetentionDashboard_v1` is the operational projection for daily launch reads. It is a second
DataStore containing counters only; `RetentionEvents_v1` remains the forensic source of truth.
The dashboard uses exactly 16 known daily keys:

`dYYYYMMDD/b00` through `dYYYYMMDD/b15`

Each production server hashes its job id into one bucket and uses `UpdateAsync` to replace its
absolute contribution. Repeated flushes are therefore idempotent rather than additive, while the
fixed buckets avoid one globally contended key. A read never calls `ListKeysAsync` and never
downloads event chunks.

The quick dashboard excludes Jason's tester accounts from
`configs/internal_accounts.lua` before counters increment. Colorado
accounts are matched by immutable user ID only — never a `Colorado*`
name prefix, because other players use that word. `waxillium` /
`waxilium` / `sploit` / `macros` may still use name prefixes for
unlisted alts. Internal traces remain in the raw store.

Counters include sessions and completed-session time, new players, the starter-choice shown/selected
microfunnel and pet split, every first-session tutorial step with time-to-step and active-step exits,
tutorial completion, quest completion, area unlocks, earned/claimed levels, and first-session exit
levels. Dashboard schema v2 also records distinct D1, D2–7, and D8–30 returners against the
player's original first-join UTC cohort. Every server contribution retains `placeVersion` and the
generated git build fields, so a same-day read exposes build populations instead of silently
blending a pre-publish and post-publish cohort.

After the build containing this feature is published, the quick CLI read is:

```bash
export ROBLOX_API_KEY='...'
python3 tools/read_retention_dashboard.py \
  --universe-id 10307183003 \
  --date 20260725 \
  --json-output retention-dashboard-20260725.json
```

For the routine acquisition/retention read, `tools/read_live_metrics.py` loads the active universe
and read key from the gitignored `.env.local`, pulls the current partial UTC day, and compares the
last seven complete UTC days with the preceding seven:

```bash
python3 tools/read_live_metrics.py \
  --json-output /tmp/hnh-live-metrics.json
```

Use `--days 1` for the quickest day-over-day spot check. The report treats `newPlayers` as internal
acquisition and reports distinct returners directly from the original cohort's fixed dashboard
buckets. `sessionsStarted - newPlayers` remains labeled **repeat-session volume** because it is not
a unique-player measure. Paid impressions/clicks/attributed plays still come from Creator Hub or the
Analytics Query API. Quest completion counters are all-session one-time events, so their ratio to
daily new players is directional rather than a strict first-session cohort rate.

The same read is available to an authorized live admin through
`retention.dashboard { dateUtc = "YYYYMMDD" }`. Neither path backfills dates from before this
instrumentation was published.

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
- D1 retention = distinct cohort players returning on UTC calendar-day offset 1 / new players in
  that first-join UTC cohort.
- D2–7 retention = distinct cohort players with at least one return on offsets 2 through 7 / new
  players in that cohort.
- D8–30 retention = distinct cohort players with at least one return on offsets 8 through 30 / new
  players in that cohort.

Distinct retention instrumentation starts with UTC cohort `20260816`; earlier cohorts are not
partially backfilled. A cohort's D1, D2–7, and D8–30 values are not mature until 1, 7, and 30 full
UTC days have elapsed. Reads before those boundaries are explicitly provisional.

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
`event_counts.csv`, `power_picks.csv`, `cohort_summary.csv`, and a count manifest. The key is read only from the
environment and is never written to an output file.

## Admin access

- Aggregate: Creator Dashboard → Analytics → Funnels / Explore. The custom event is
  `RetentionMilestone`, broken down by category and milestone id. Power pick share is
  `PowerPicked`, broken down by power id (Custom Field 1).
- Daily operational dashboard: `RetentionDashboard_v1`, the fixed-key
  `tools/read_retention_dashboard.py` reader, or the admin-only `retention.dashboard` Game API
  command.
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

## Optional external analytics

The 2026-07-25 evaluation found that the old Colorful Clickers place used the official
GameAnalytics Roblox SDK. GameAnalytics currently advertises its core realtime reporting, custom
events, funnels, cohorts, retention, and custom dashboards as free with no MAU limit; paid features
add hourly granularity, deeper user analysis, scheduled reports, API access, and raw-data pipelines.
It is the lowest-friction optional mirror because it has a maintained Roblox SDK and the existing
semantic `FireGameEvent` bus is already one server-side integration point.

Do not make a third-party dashboard the only retention record. If enabled later, create fresh
Halo & Horns credentials, keep the secret server-side, send only the bounded launch events/counters,
and retain the internal dashboard plus raw archive. The extracted Colorful Clickers SDK contains
old embedded credentials and must not be copied or treated as reusable.
