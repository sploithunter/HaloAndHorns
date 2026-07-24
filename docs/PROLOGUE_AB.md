# Prologue A/B Test — Design (NOT YET IMPLEMENTED)

> Status: **design only** (Jason 2026-07-24: "design how we're gonna do the A/B testing —
> don't implement that yet; I want durability proven a couple times first").
> Prerequisite before implementation: the once-ever durability fix (b0d2e46) confirmed
> across several stop/start cycles, and `duration` dropped from its 30s debug value.

## The question

Does the cold open (docs/PROLOGUE.md) improve new-player retention enough to earn its
seconds? Concretely: **the bottleneck is the first 15 seconds** — does replacing them with
the flash-forward battle move D1 return and early-funnel completion?

## Assignment

- **Unit: player, assigned once, sticky forever.** Session-level assignment would show the
  same player both experiences across visits and poison both arms.
- **Method: deterministic hash of UserId** — `hash(UserId) % 1000 < ab_split * 1000`
  → arm `prologue`, else `control`. Chosen over random-then-persist because it has **no
  save dependency**: the exact class of save-loss bug we just fixed (a lost record) cannot
  flip a hash-derived arm. The record still *stores* the arm for analytics joins, but the
  hash is the authority.
- **Split knob:** `configs/prologue.lua` `ab_split` (already present, 0.5). It doubles as
  the rollout dial: `1.0` = ship the prologue to everyone (post-experiment), `0.0` = off.
  `enabled = false` remains the master kill switch. All config-only — no code deploy to
  end or ship the experiment.
- **Population: genuinely new players only.** Anyone with an existing `data.Prologue`
  record (or any pre-experiment save) is out of the experiment by construction — the gate
  already reads the record first.
- **Exclusions:** admins/testers (`IsAdmin` attribute) are assigned an arm for consistency
  but **flagged `tester=true` in every event** so our replay sessions can be filtered out
  of analysis. The admin reset / `admin.replayPrologue` paths force the prologue regardless
  of arm (testing beats the experiment).

## Gate wiring (the one code touch-point)

`PrologueService:IsEligible` gains one branch after the existing checks pass:

```
arm = AB.armFor(player.UserId, config.ab_split)   -- pure, Shared/Game/PrologueAB.lua + headless spec
if arm == "control" then
    write data.Prologue = { seenAt, version, completed = true, ab = "control" }  + critical save
    return false, "ab_control"
end
-- prologue arm: Begin as today; Begin's record gains ab = "prologue"
```

Control players fall through to the current normal flow (chooser → tutorial) — zero new
code on their path. Writing the control record immediately (same durability contract as
Finish) means the decision is made exactly once and survives everything. The
`PrologueGate` attribute carries `"ab_control"`, so the starter/tutorial gates see a
resolved gate and proceed — no new deferral states.

## Instrumentation (rides RetentionService — nothing new to build)

`RetentionService` already keeps a raw per-session event store (`RetentionEvents_v1`
DataStore), cohort aggregates, and submits the tutorial funnel to Roblox's native
`LogOnboardingFunnelStepEvent`. The A/B layer adds:

1. **`ab_arm` on the session context** — one field in `_rawPayload`/`_aggregateFor`,
   sourced from the record (`data.Prologue.ab`). Every existing event and aggregate is
   then already arm-tagged; no per-event changes.
2. **Three prologue events** through the existing `_appendRawEvent` path:
   - `prologue_start` (Begin) — context: fresh boot vs admin replay
   - `prologue_victory` (wave wiped) vs absent → timeout cut; context: seconds, kills
   - `prologue_complete` (Finish) — context: seconds total. A session with `start` and no
     `complete` = quit-during-prologue, itself a key measurement.
3. **Roblox onboarding funnel step 0.** The native funnel currently starts at the first
   tutorial step; the prologue becomes a step *before* it for the prologue arm only. The
   Creator Hub funnel view then shows the two arms' drop-off shapes side by side when
   filtered by the custom field.

## Metrics

| Metric | Source | Why it decides |
|---|---|---|
| **D1 return** (primary) | Retention aggregates (cohort day joins) | The stated goal of the whole feature |
| Quit-during-first-2-min | raw session end < 120s | The "first 15 seconds" hypothesis, directly |
| Tutorial step 1..10 completion | existing funnel | Does the preview *motivate* the grind that follows |
| First egg hatched | existing milestone | The first real progression commitment |
| Session length (first session) | raw session | Secondary engagement |
| prologue_quit rate (prologue arm only) | new events | Is the cold open itself losing people |

## Sample size honesty

At the ~500-player first-run target (~250/arm), only a **large** D1 effect is detectable
(roughly: 12% → 22%+ at conventional thresholds). Plan reads: run the ad spend, treat
<1000 new players as **directional**, and either (a) extend to ~1000+/arm for a real
verdict, or (b) accept the directional read plus the secondary metrics (quit-rate and
funnel shape converge much faster — hundreds of players give usable signal within days).
Don't stop early on a good-looking first weekend; novelty cohorts skew positive.

## Implementation checklist (when green-lit)

1. `Shared/Game/PrologueAB.lua` — pure `armFor(userId, split)` + headless spec
   (boundaries: split 0, 1, determinism, distribution over a userId range).
2. `IsEligible` control branch + control-record write (durability contract from b0d2e46).
3. `Begin`/`Finish`/victory watcher → the three `_appendRawEvent` calls.
4. `RetentionService` session context + aggregate: `ab_arm`, `tester` flag.
5. Funnel step 0 registration for the prologue arm.
6. Verify: two fake accounts on either side of the hash boundary (or a temporary
   `ab_force` config override) — one sees the battle, one sees the chooser; both records
   durable across stop/start; events arm-tagged in the raw store.

## Open questions for Jason

- Ship threshold: what D1 delta (directional) is enough to set `ab_split = 1.0`?
- Should the control arm ever get the prologue later (e.g., as a replayable "vision"
  moment at level 10), or stay clean as a holdout until the experiment ends?
