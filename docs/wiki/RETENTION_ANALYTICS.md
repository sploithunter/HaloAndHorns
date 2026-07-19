# Retention Analytics

Status: implemented 2026-07-18.

`RetentionService` is the server-side observer for activation telemetry. Gameplay systems continue
to publish semantic events through `FireGameEvent`; the retention service maps those events through
`configs/retention.lua`.

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

## Admin access

- Aggregate: Creator Dashboard → Analytics → Funnels / Explore. The custom event is
  `RetentionMilestone`, broken down by category and milestone id.
- Individual live player: `retention.get` on the server Game API returns the ordered funnel and
  full milestone list.
- Individual offline player: Creator Hub Data Stores Manager can inspect the existing
  `PlayerData_v2_mixedPets` profile store; no second player database is created.

Only genuine first-session profiles enter the Roblox onboarding funnel. All profiles retain new
milestones for support diagnosis. Analytics calls are server-only and suppressed in Studio.
