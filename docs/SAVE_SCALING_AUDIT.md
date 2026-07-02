# Save / DataStore Serialization — Scaling Audit

A forward-looking look at persistence cost. Today (1 test player, small profile) saves are tiny and
are **not** the source of the current frame spikes — those are the engine memory/GC side (see the
"overnight memory leak" item + the 5 GB `Internal` measurement). But the save path is the thing most
likely to bite at scale, so this documents the risks and the plan.

## The one rule that governs all of it

**A DataStore call yields; a serialize blocks.** `SetAsync`/`UpdateAsync` hand the network round-trip
off and let other coroutines run — network latency does **not** stall a frame. What stalls a frame is
the **synchronous JSON-encode of a large Lua table** that happens before the send. So persistence cost
= *size of the thing being encoded × how often you encode it*. Everything below follows from that.

## Inventory of what we persist

| Store | Payload | Per-write cost | Scaling risk |
|---|---|---|---|
| **ProfileStore** (per-player profile) | hundreds of pets + inventory + every system's state | grows with profile | **HIGH** — the only big serialize; the 4 MB key ceiling is a hard wall |
| **PetSerialService** (global serials/census) | `key -> integer` (e.g. `huge:bear:basic = 47`) | microseconds | LOW size, but a **shared key** → write contention across servers |
| **LeaderboardService** | one number per player (OrderedDataStore) | microseconds | LOW |
| **OpsAlert** | a daily telemetry list (append) | grows over a day | MED — unbounded append in one key |

## The real risks at scale

1. **Profile size → serialize cost AND the 4 MB ceiling.** A full 500-pet account + uniques + every
   subsystem's state encodes to a large blob. Two failure modes: (a) each save's encode blocks a frame
   proportional to size; (b) crossing **4 MB per key = the save throws and you lose data.** The SSOT
   compact-stacks work already fights this; it must stay disciplined.
2. **Interval saves × N players.** A 30s autosave with 30 players = up to 30 encodes every 30s, often
   bunched on the same frame. This is the thrash. (`PlayerEffectsService.SAVE_INTERVAL = 30` is one.)
3. **Unbounded global structures.** If the global census/world-first index ever moves from
   "integer per key" to "a growing list in one key," every `UpdateAsync` deserializes + reserializes
   the whole list AND fights cross-server write contention. Keep globals as counters or shard them.
4. **Append-only logs** (OpsAlert daily list) grow within their window and re-encode the whole list per
   write. Cap/rotate them.

## The plan (in priority order)

1. **Debounced, event-driven saves** (your design — it's the standard pattern, not hacky):
   - *Safety nets, mostly free:* `BindToClose` + `PlayerRemoving` (ProfileStore already does both on
     session release). Covers the 99%.
   - *Flagged event saves:* a single `DataService:MarkDirty(player, reason)` called from the sites that
     mint irreversible value — hatch secret+/huge/exclusive, level-up, rare drop, big purchase, trade
     complete. Set a dirty flag + debounce ("save within ~5s of a flag, at most once per ~60s") so a
     hatch-streak collapses into one save.
   - *Drop / stretch the interval:* remove the 30s autosave, or make it a 2–3 min **dirty-only**
     backstop, jittered per-player so saves never bunch on one frame.
2. **Profile-size budget + monitoring.** The `[SAVEPERF]` instrumentation now logs `encode=Nms
   (bytes / % of 4MB)`. Bake a permanent version into the save path: warn at ~50% of 4 MB, alert at
   ~80%. Never let a profile silently approach the ceiling.
3. **Schema bloat audit.** Walk `profile.Data` and remove anything derived/transient/redundant that
   doesn't need persisting (recomputable stats, debug fields, UI state). Smaller blob = cheaper every
   save AND more 4 MB headroom.
4. **Keep globals as counters, not lists.** Audit the census/world-first path so it stays integer/
   sharded; if a leaderboard-style "top N" is needed, use OrderedDataStore (designed for it), not a
   hand-serialized list in one key.
5. **Cap/rotate OpsAlert** so its daily list can't grow unbounded.

## What the instrumentation will tell us

- `[SAVEPERF] encode=Nms (bytes / % of 4MB)` per save → the synchronous serialize cost + current size.
  Multiply by a realistic 500-pet profile to project the at-scale frame cost and 4 MB margin.
- `[SLOWFRAME] Ns` for any frame > 0.3s. A `[SLOWFRAME]` with **no** `[SAVEPERF]` beside it = not a
  save (datastores yield) → the GC/leak side.

Both `[SAVEPERF]` and `[SLOWFRAME]` are tagged temporary; strip once the live-stall question is settled.
The structural items above stand on their own regardless.
