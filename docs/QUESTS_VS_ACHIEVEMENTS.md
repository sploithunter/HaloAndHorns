# Quests vs Achievements — the model (Jason, 2026-06-29)

The two systems were conflated: "quests" included passive milestones ("Reach Level 5", "Hatch
25,000 eggs lifetime") that just *happen* in the background. This splits them cleanly.

## The principle

**A QUEST is an ACTIVE TASK you are doing right now.**
- Every quest counts **from when it activates** (`since_start`) — never lifetime. "Hatch 100 eggs"
  means **100 NEW eggs from now**, even if you've hatched thousands before. Do it again each time.
- **Nothing passive lives in quests.** No "reach level N", no lifetime totals.
- **One exception:** a passive condition may **UNLOCK** a quest track (e.g. reaching Level 5 unlocks
  The Warpath). The level is the *gate*, never a quest goal you stare at.
- Tracks are **level-gated and HIDDEN** until their unlock level. Crossing the level fires **"New
  quests available!"** — a sound + the Quests button pulses. An *event*, not a passive goal.
- **First Steps** auto-activates as the single focus right after the tutorial, counts from
  activation, is more elaborate, and guarantees Level 2.

**An ACHIEVEMENT is a PASSIVE lifetime milestone (background).**
- Lives behind a new **Achievements button**, grouped by category.
- Reached a tier → a **Claim button** (manual claim — NOT the current auto-grant).
- Not reached → a **progress bar** showing how close you are.
- This is where every passive goes: reach-level, lifetime totals, own-N-distinct, rebirth-N.

---

## Quest tracks (active tasks only; `since_start`; hidden until unlock level)

Goals are **modest and re-doable** — a session's worth, not a lifetime grind. Unlock crossing the
level fires the "New quests available!" announce.

| Track | Unlock | Quests (all count-from-activation) |
|---|---|---|
| **First Steps** | L1 (auto) | onramp → Level 2 (see below; more elaborate) |
| **Deep Mining** | L2 | Break 100 crystals · Earn 3,000 crystals · Break 500 crystals |
| **The Hatchery** | L3 | Hatch 25 eggs · Hatch 100 eggs · Own a 6-pet squad |
| **The Collector** | L4 | Find an enhancement · Slot an enhancement · Find 10 enhancements |
| **The Warpath** | L5 | Cast 20 powers · Defeat 25 enemies · Defeat 100 enemies |
| **Trailblazer** | L8 | Unlock the next area · Unlock 3 areas · Meet 3 Creators |
| **The Crossing** | L12 | Visit Heaven · Visit Hell · Unlock a realm area |

*(Open question for you: exact unlock levels + which active goals per track. Above is my proposal.)*

### First Steps (auto-activated, count-from-activation, → Level 2)

1. **Boost the Patch** — pulse Resonance near crystals **3×** (from activation, so tutorial casts
   don't pre-complete it). Reward: 5 gems.
2. **Deploy your squad** — have 3 pets active. Reward: 5 gems.
3. **Mine the patch** — break **25** crystals. Reward: 10 gems.
4. **Grow your collection** — hatch **10** eggs. Reward: 10 gems.
5. **Welcome to the Realm** — earn **1,500** area coins (toward the Meadow gate). Reward: **700 XP
   (→ Level 2)** + 15 gems.

---

## Achievements (passive lifetime; claim-on-reach; progress bar otherwise; by category)

Everything passive moves here. Tiers are lifetime totals. The existing `achievements.lua` already
tiers some of these — we extend it and flip the service from auto-grant to **claimable**.

| Category | Achievements (tiered lifetime totals) |
|---|---|
| **Hatching** | Eggs hatched: 10 / 100 / 1k / 10k / 25k |
| **Mining** | Crystals broken: 50 / 2.5k · Crystals earned: 8k / 50k / 500k / 1M |
| **Combat** | Enemies defeated: 10 / 100 / 1k / 10k · Powers cast: 100 / 1k |
| **Collection** | Distinct pets: 25 / 75 · Enhancements found: 10 / 50 |
| **Progression** | Reach Level: 5 / 10 / 15 / 20 / 30 / 50 · Rebirths: 1 / 3 |
| **Exploration** | Areas unlocked: 3 / 6 · Realms visited (Heaven+Hell) · Creators met: 5 · Secrets: 5 |

Capstone pets (the rainbow bear rewards) move onto the top achievement tier in each category.

---

## What moves where (audit of the current 8 quest tracks)

- **first_steps** → stays Quests (reworked: auto-active, `since_start`, elaborate).
- **hatchery** → Quests keeps small active tiers (hatch 25/100); 1k/5k/10k/25k → **Achievements**.
- **mining** → Quests keeps break-100/earn-3k/break-500; 50k/500k/1M → **Achievements**.
- **warpath** → Quests keeps cast-20/defeat-25/defeat-100; 250/2.5k/10k → **Achievements**. The
  `to_battle` "Reach Level 5" quest is **deleted** (it becomes the track's unlock gate).
- **collector** → Quests keeps find/slot/find-10; distinct-pets 25/75 + find-50 → **Achievements**.
- **ascension** → **entirely Achievements** (all reach-level milestones — pure passive). Removed as
  a quest track.
- **crossing** → Quests keeps visit-Heaven/Hell + unlock-a-realm-area (active); deeper → Achievements.
- **trailblazer** → Quests keeps unlock-next-area/3-areas/meet-3-creators; rebirths + 6-areas +
  secrets → **Achievements**.

---

## Implementation stages

1. **Config split** — rewrite `configs/quests.lua` (active tracks + `unlock_level` + `since_start`)
   and extend `configs/achievements.lua` (categories + all migrated passives + capstone pets).
2. **AchievementsService → claimable** — stop auto-granting; add `reached/claimed/progress` state +
   a `achievement.claim` bus command. Surface category + progress in `GetAchievements`.
3. **QuestService** — auto-activate First Steps (single focus, override stale); hide tracks above the
   player's level; emit a `track_unlocked` event when the player crosses an unlock level.
4. **Client** — new Achievements button + panel (grouped, claim/progress); the "New quests
   available!" announce (sound + Quests-button pulse) on `track_unlocked`.
5. **Reset/migration** — reset clears the new quest focus + achievement-claim ledger; verify.

Each stage gates on `mise run ci` + a live check before the next.
