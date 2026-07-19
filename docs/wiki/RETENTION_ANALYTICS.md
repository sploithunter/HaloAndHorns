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

For an immediate long-form export, create a read-only Open Cloud key with list/read access, then:

```bash
export ROBLOX_API_KEY='...'
python3 tools/export_retention.py \
  --universe-id <UNIVERSE_ID> \
  --date 20260718 \
  --output retention-export-20260718
```

The exporter writes lossless `chunks.jsonl`, event-grain `events.jsonl`, analyst-friendly
`events.csv`, and a count manifest. The key is read only from the environment and is never written
to an output file.

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
