# Pet Realm — Progression, Power & Teaming Design

> Companion to `PET_REALM_DESIGN_DOCUMENT.md`. Captures the power/level/teaming model worked
> out in design discussion. This is the spec the accuracy curve (first build) and everything
> after it bind to. Everything here is **config-as-code** — every number a dev knob.

---

## 0. Context

Two flat spots surfaced: **accuracy** was a flat 8% miss regardless of target, while **damage**
already scaled by level + rank (asymmetry to fix). And **pet power** had never been scaled, so we
can set the rules *before* power creep forces our hand. Out of that came a unified model: three
identity numbers, one shared combat curve, and a bounded "pets-are-stars" power system that can't
trivialize the level ladder. This doc pins all of it.

---

## 1. The three identity numbers

A player is described by three orthogonal numbers. **Never conflate them.**

| Number | What it means | Drives | Teaming effect |
|---|---|---|---|
| **Effective Level** | combat strength | the level-diff curve (accuracy + damage), enemy con colours, pet *realization* | **synced** while teamed (sidekick up / exemplar down) |
| **Claimed Level** | what you've earned | powers, pets, equip/power slots, egg-hatch | never changed by teaming |
| **Soul** | which side (Halo↔Horns) | realm access + the heaven/hell gates | never changed by teaming (guests earn none) |

- **Effective Level** = normally your own level; overridden by team-sync. **Every combat curve
  reads Effective Level**, so sidekick/exemplar/solo all flow through one value.
- **Entitlement level = `min(Claimed, Effective)`** — exemplar *down* claws back slots/powers
  (CoH-style); sidekick *up* never grants powers you haven't earned.
- Already built: the level system splits **earned** (XP-derived, combat/egg) from **claimed**
  (entitlements). Effective Level is the combat one with a team-sync override layered on.

---

## 2. Accuracy & damage curve (FIRST BUILD)

**Today:** pet attacks are a flat `hit_chance = 0.92` (8% miss) with **no level/rank variation**
— and the roll isn't gated, so **mining whiffs 8% on inert crystals** (a bug). Damage, by
contrast, already scales: `LevelScale.factor` = ±8%/level (clamp 0.3–2.5), enemies spawn at
`effectiveLevel(base, rank_offset)` (trash +0 / lieutenant +1 / boss +2), and armor mitigates on
the `k/(armor+k)` curve (boss ~70%).

**Fix — bring accuracy to parity with damage, reusing the same inputs:**
- A pure `Accuracy` resolver: `toHit(effAtkLevel, targetLevel, targetRank, cfg)` →
  `base_to_hit` × level-diff "purple-patch" step × rank penalty, clamped `[floor, cap]`.
- **Combat** (enemy target) → full curve. **Mining** (no `EnemyId`, no level/rank) → `mining_hit_chance = 1.0` (crystals never dodge; crit stays as an upside). This also **fixes the
  8% mining whiff**.
- Build it to read **`EffectiveLevel(player)` from day one** — today it returns your real level
  (nothing changes); teaming later just makes that accessor return the synced value and **every
  curve picks it up for free**.

Config sketch (`combat.lua accuracy`):
```
base_to_hit = 0.92, per_level_step = 0.04, floor = 0.05, cap = 0.95,
rank_to_hit = { trash_mob = 0, mid_tier = -0.05, boss = -0.10 },
mining_hit_chance = 1.0,
```

---

## 3. World structure & gating (heaven/hell — two axes)

- **Geometry:** a 4-biome surface ring + **5 Heaven layers** + **5 Hell layers**, each layer the
  4-biome ring re-themed = **44 areas** (reskins, not 44 bespoke maps). A single run traverses
  *surface + one direction* ≈ 24 areas → ~**2 player levels per area** to cap (50).
- **Two gating axes, paced differently:**
  - **Depth (the layers) → LEVEL-gated** (`requires_level`, ~5 levels/layer) + the existing
    `requires_soul` + `token_cost`. "Level decides how deep."
  - **The ring (4 biomes per layer) → CURRENCY-gated** (the existing grind). "Coins decide how
    wide."
- **Side separation is Soul, not level** (this is the key insight): Heaven layers need **soul ≥
  +20/+40/+60/+80/+100**, Hell layers **≤ −20…−100**, paid in **light_tokens / shadow_tokens**
  (non-tradeable). A maxed Horns player clears every *level* gate but is **hard-locked out of
  Heaven** by soul sign + having the wrong tokens (and a side's tokens are only earned *on* that
  side — chicken-and-egg by design).
- **"No easy way up" = the Soul ratchet.** Soul polarizes with conquest; the **surface is the
  only neutral crossing point**. Retreat-to-surface is always free; crossing to the *opposite
  deep realm* requires re-aligning Soul across zero (~24 conquests) and earning the new side's
  tokens from scratch — a deliberate **fall/redemption arc**, not a portal hop.
- **Pacing rule:** area at depth D spawns enemies ≈ level **2D**; arriving on-level = even-con,
  the level-diff curve soft-walls under-levelling and trivializes over-levelling. (Currently
  built: cap 50, layers config has 3/side + soul + token gates — to expand to 5/side + add the
  `requires_level` third gate.)

---

## 4. Teaming — guest pass + sidekick/exemplar

> **One rule: teaming syncs the POWER axis (Effective Level + XP); it never grants the SIDE axis
> (tokens / soul / realm-progress).**

- **Guest pass:** while partied with a *resident* of a realm you can't access, you ride in as a
  **guest** — present, fight, earn **XP** — but **zero tokens / soul / conquest**, can't use that
  realm's altar/shop/eggs, your alignment untouched, access lapses when the host leaves (graceful
  auto-recall to surface). The angel walks Hell at the demon's side and gains nothing but the
  fight (and a small **"Arrangement" buff** for cross-aligned teams).
- **Sidekick / exemplar (both):** **lead-anchored** — the team's Effective Level = the host's
  (NOT the highest; "highest dictates" invites passive carries/exploits). Low members sidekick
  *up* to lead−1; high members exemplar *down* to the lead. Reuses the level-diff curve (sync the
  effective level → the curve does the rest). Exemplar also claws back slots/powers via
  `min(Claimed, Effective)`.
- **Why it can't be gamed:** a low Halo + high Horns in Hell — the low player fights at tier
  (survives) but with his own low kit, earns XP only, **no** shadow tokens / soul / Halo
  progress, and **no** high-level entitlements. He plays; he doesn't *become*. (Non-tradeable
  side-tokens already block handing keys across.)

---

## 5. Pet power model — pets are stars, but bounded

> **Realized power = `Baseline(EffectiveLevel vs pet tier) × PetMultiplier × situational(buffs /
> auras / element)`.** The pet is the headline number and the chase; **Effective Level gates how
> much of it is realized**; a hard ceiling caps the top.

- **Pets are the star** (this is a pet game — diverging from CoH's player-centric model), but with
  **hard caps**, so a god-pet on a low player can't break the curve: it realizes only at *their*
  baseline and **blooms as they level**. This is exactly what makes a rare/dream hatch *safe* in a
  noob's hands.
- **Acquisition is world-gated:** strong pets only hatch **deep** (behind level + soul). The only
  leak is trade — handled by the realization gate (an over-tier traded pet under-performs until you
  grow into it).
- **Numbers = integers for display** (Roblox is float64 underneath; compute in float, display
  rounded). **Start base high (~1,000)** so per-tier steps don't round-collide; use K/M suffixes
  past thousands.
- **Tier curve, not hand-authored numbers:** `power = tierBase(layer/rarity) × variant × aptitude`,
  `tierBase` geometric (~1.3–1.5×/tier, ~25–35 tiers). Thousands of ordered, collision-free,
  progressing pets from a tiny config. Adjacent tiers ≥ ~25–40% apart so each reads as an upgrade.
- **Hard ceiling = the Creator value, code-enforced:** a single `max_pet_power` clamp in the
  resolver. Nothing — huge, titanic, colossal, anything — can exceed it. Proposed apex ≈ **1,000,000** (TBD at balance); starter ~1,000.
- Variant multipliers: basic 1.0 / golden 1.5 / rainbow 2.5 (existing `pet_power.lua`).
- The **⛏ mining / ⚔ combat** aptitude split (already shipped) drives specialists → the trading
  economy. Element matchups (resonance) + support/buffers add team-comp depth.

---

## 6. Pet identity — five orthogonal axes

| Axis | Values | Role |
|---|---|---|
| **Species** | colorado, bear, penguin, … | base power + aptitude split |
| **Variant** | basic / golden / rainbow | multiplier (1.0 / 1.5 / 2.5) + look |
| **Size** | normal / huge / titanic / colossal | bounded prestige ladder, all **under** the cap |
| **Class** | normal / **Creator** | Creator = the apex cap + permanently untradeable |
| **Shiny** | yes / no | **cosmetic prestige only** (`shiny_mult = 1.0`, never balance) |

`huge` stays a normal, meaningful multiplier; the apex is **not** "a huge," it's its own **Creator
class** (decoupled from size math).

---

## 7. Creator & Meet-the-Creator pets + Shiny

- **Creator class** = the apex (`max_pet_power`), e.g. **Creator Rainbow Colorado**.
  - **Creator accounts only** — a `creators = { <userId>, … }` allowlist (just the dev now;
    extensible to teammates). Players can never obtain one.
  - **Untradeable, always, hardcoded** (intrinsic to the class — not a flippable flag). The
    absolute ceiling cannot leak.
  - It's the dev flex *and* the balance/test anchor: held by a creator at level 50, it measures
    max-power pacing; content is tuned knowing players can't reach it. Player's *real* ceiling =
    the top **normal-class** pet.
  - `Creator` is an **extensible class** (future creators' apexes tie at the cap), with the
    Rainbow Colorado as flagship.
- **Meet-the-Creator pet** (the player memento, kept from Colorful Hatchers):
  - Granted **once ever per player** (a profile flag) when an allowlisted **creator joins the
    server**; auto-hatches.
  - **Normal odds** (the regular egg config) — can roll **huge / golden / rainbow** like any pet
    (a huge-rainbow MtC is its own grail).
  - **Always shiny** (its defining exclusive trait), and **tradeable** — a circulating prestige
    collectible whose supply is throttled by how often creators actually show up.
- **Shiny** = a new **5th orthogonal trait**, **power-neutral** (sparkle/VFX only). `base_chance =
  0` for now → the *only* shiny source today is the Meet-the-Creator egg, so "shiny" literally
  reads as "you met the Creator" until/unless shiny odds are sprinkled elsewhere.

---

## 8. Open knobs (set at the balance pass)

- Accuracy curve: `per_level_step`, rank penalties, floor/cap.
- Pet ceiling magnitude (Creator value), tier step %, tier count, starter base.
- Pet-multiplier band width vs Effective-Level baseline weight (how "star" vs "gated").
- `requires_level` thresholds per layer; soul thresholds for layers 4–5; reward multipliers.
- Meet-the-Creator hatch rates (huge/golden/rainbow chances).
- Sidekick XP scaling (power-level pace) — side-progress stays resident-gated regardless.

---

## 9. Already built (so this binds to real code)

- Level cap 50; claimed/earned split; claimable level-up + Ascension Altar (hybrid: filler
  auto-claims, training claimed at the altar); +1 egg-hatch/level.
- Pet caps raised to **10 equip + 10 active**; **10 power picks** across `{3,7,11,15,19,24,29,34,40,46}`.
- Soul/alignment (`soul.lua`, `AlignmentService`), layers (`layers.lua`, 3/side + soul + token
  gates), `light_tokens`/`shadow_tokens` (non-tradeable).
- PetPower resolver + `pet_power.lua` (variant mults, context placeholders), ⛏/⚔ aptitude split.
- LevelScale (damage curve) + enemy rank/armor; CombatRoll (the flat hit roll to replace).

---

## 10. Mining economy baseline (locked by live balance, grass→ice→lava)

The mining economy is anchored to a single ratio. **Read this before tuning any zone's income.**

- **Income identity: `coins/sec = DPS × (value ÷ HP)`.** The current ratio is **0.2** (crystal
  `value` scales with `HP` so every tier — Small/Medium/Large — pays the *same* coins/sec; bigger
  crystals just take longer to break, they don't pay more per second). Set in
  `configs/breakables.lua` `ORE_TIERS` (20/100, 100/500, 400/2000). To raise/lower income, move the
  ratio (e.g. 0.2 → 0.15), **not** individual tiers.
- **Verified live (grass, farming `Near`):** 3 fresh dogs ≈ 46 DPS → ~10 cps; 3 fresh bears ≈ 25
  DPS → ~6 cps (tanks mine slow *by design*, `mining_mult 0.6`); a graduated 2-golden+1-rainbow dog
  squad ≈ 85 DPS → ~17 cps. Ice/lava hold the same ratio (150-DPS squads → ~30 cps). The small
  overshoot vs `DPS×0.2` is the active-mining boost + crits — expected.
- **Pacing anchor — the "200-egg arc":** ~200 hatches reliably yields strong variants (golden /
  rainbow). At 100-coin grass eggs that's ~20,000 coins ≈ **~33 min fresh / ~20 min upgraded** to
  "graduate your starter squad." Size new zones' egg cost + income so the graduate arc lands in
  that ballpark. The hatch loop itself is snappy from minute one (an egg every ~10 s at 10 cps).
- **Targeting modes (`configs/auto_systems.lua`):** `free_mode = nearest` (minimize travel — the
  best DPS the flat ~26 studs/s pet speed allows), `paid_mode = highest_value` (camp big payouts).
  `weakest` is the *worst* free mode (chases scattered small crystals → travel overhead halves
  effective DPS); never make it the default. Pet speed is **flat across levels** (nothing scales
  `PetMoveSpeed`); if we ever scale it, floor it at today's value so low levels never regress.
- **Density depletion is a designed throttle, not a bug.** Outer zones spawn `max=100` with a
  5–60 s distributed respawn. A strong squad mines its local cluster faster than it heals, so DPS
  starts at peak and sags until refills arrive — this *enforces* active > passive (§11) and caps
  sustained income. **Keep it.** Do not "fix" the sag by fast/at-location respawn unless we
  explicitly want a frictionless arcade-farm (which raises sustained income ~30–50%).

---

## 11. Monetization & anti-cheat philosophy (steers every gamepass)

Three tenets, in priority order. **Read before designing any gamepass or AFK feature.**

1. **Active always beats passive.** Engaged play (roaming to fresh density, targeting, managing the
   squad) out-earns idle/AFK — *never* the reverse. The mining depletion throttle (§10) is the
   live enforcement: campers sag, roamers sustain peak — true even among paying players. *Live
   evidence:* a desert squad reads 115–190 DPS / 18–29 cps **moving vs idle** — the player's own
   movement is worth ~40% more income, with zero gear difference.
2. **Gamepasses absorb the cheating demand.** What cheaters script is *convenience/automation* —
   auto-farm, auto-target, AFK macros, auto-hatch. Ship those as official gamepasses instead of
   fighting an injector arms race.
3. **Undercut the injector.** Price the legit pass below the cost/friction/ban-risk of a script. A
   player willing to pay for an injector becomes a customer, and the cheating incentive dies.

**Hard constraint (keeps #2 from violating #1):** gamepasses sell **convenience, not power**. A
paying *passive* player must still earn ≤ an active *free* player — the pass removes friction; the
depletion throttle preserves the active edge. Never sell a flat earnings/power multiplier that lets
AFK out-earn active. That's pay-to-win and breaks tenet #1.

**Boundary of the philosophy — three complementary anti-cheat tools:**
- *Automation cheats* (auto-click, auto-walk, AFK macros) → **cheap convenience gamepasses** (this §).
- *Value-injection cheats* (fabricated coins/pets, speed hacks) → **server authority** (already in
  place: the server owns inventory, coins, pet records; the client can't fabricate them). Gamepasses
  can't and shouldn't try to cover this class.
- *Abnormally-high earners* (botted farms AND legit whales) → **earning-rate enemy pressure**
  (below). Don't *detect* cheating — make high income inherently *come with combat*.

**Earning-rate enemy pressure (anti-cheat tool #3 + endgame challenge).** Track each player's
*real-time* coins/sec (and/or DPS) per area; when it exceeds an area threshold, spawn enemies that
scale with the overage. A bot raking coins gets swarmed (combat is far harder to auto-handle than
mining); a legit high earner gets a fair challenge (and better drops). It self-balances — no
allow/deny lists, no arms race — and reinforces tenet #1 (you can't passively rake while idle).
**Critical caveat:** the coin counter is seeded from the DataStore on join, so the *first* sample
shows a multi-thousand/sec spike that is NOT real earning. The rate tracker MUST **seed its baseline
from the loaded total and only measure deltas after join + a grace window** (same pattern the
DevMetricsHud client overlay already uses — `seedCoins()` on connect). Knobs: per-area thresholds,
spawn rate/strength vs overage, grace period, cooldown.

**Gamepass candidates that fit (all convenience, all common script targets):** auto-target
`highest_value` (built — the `High` mode), auto-/bulk-hatch, offline/AFK earnings (capped *below*
active), wider farm radius / multi-zone, extra target or equip slots. Price low.

---

## 12. Gates are on-ramps, not retention (the terminal-zone problem)

A linear unlock chain (farm zone N coins → buy zone N+1) pulls players *forward* through the
midgame but **cannot make them stay anywhere** — the moment the terminal zone/realm is unlocked,
its currency buys nothing and the forward pull is gone. Reordering doesn't help: *whichever* zone
ends up last inherits the dead-end. So gates are one-time **on-ramps**; retention is designed
separately, via three levers (a zone — especially the last — needs all three):

1. **Resident loop.** Each zone's coins must buy something *in that zone*, repeatedly — its
   eggs/upgrades/pets — not just the next gate. (Partly built: ice coins → ice eggs → polar bears;
   lava → ember owls.) The next-gate cost is a *secondary, one-time* use of the currency.
2. **Desirability escalates with depth.** The resident loop only sticks if the *deepest* zone is
   the *best place to be* — rarest variants, best shiny odds, exclusive species, apex chases.
   Because pet power is bounded (Creator ceiling, §5), "best" means **rarity / variant / cosmetic
   desirability, not bigger numbers** — shiny + exclusive-species hunting, never raw power creep.
3. **The realm axis is the non-terminal endgame.** Heaven/hell are not "more zones to finish" —
   they're loops that don't end: **conquest** (soul ±, recurring, social), **token-gated traversal**
   (light/shadow tokens spent to move between layers — a *permanent sink*, not a one-time gate), and
   exclusive realm pets. The deepest realm sticks because conquest + the rarest hunts live there,
   not because a gate sits after it.

**Consequence for layout:** the homeworld ring's terminal zone is not an endpoint — it's the
**on-ramp into the realm axis** (this is the role "Meadow-as-gateway" was reaching toward; see §3).
Meadow's exact pricing/position stays unresolved pending that decision.

---

## 13. Support pets — active targeted buff/debuff (experimental)

Today's support pets are passive **auras** (radius heal/defense/offense/yield — built, task #135).
The next experiment: support pets that **target like combat pets**, where the "hit" applies a buff
or debuff instead of HP damage.

- **Same engagement loop as combat** (perceive → pick target → "attack" on a cadence); the payload
  is a status effect, not damage.
- **Friendly target → buff** (e.g. PetDamageBuff / TeamDefenseBuff on an ally pet).
- **Enemy target → debuff** (e.g. Vulnerable / weaken — the support's "indirect target").
- **Heals are moot in mining** (no incoming damage to undo) — fine; they matter in combat only.
- **Reuse existing channels:** the buff/debuff infrastructure already exists (PetDamageBuff,
  PetTeamDamageBuff, Vulnerable, TeamDefenseBuff + status-effect badges, tasks #115/#125). The new
  work is making a **friendly pet a valid target class** (combat targeting assumes enemies), plus
  buff stacking/duration rules.
- **Risk (flagged):** a "friendly pet" target class may perturb existing combat targeting/aggro.
  Build behind a flag; verify enemy targeting is untouched.

---

## 14. Realm endgame loop — resolved knobs (World S3, §12 made concrete)

- **Token earning = multi-source (fork 1).** `light_tokens`/`shadow_tokens` flow from THREE channels,
  each a config-driven rate: (a) a *cut* of realm mining/combat income, (b) *conquest* events
  (which also shift soul), and (c) possibly *in-realm egg hatches*. This is the loop's fuel — the
  sink (traversal) was always there; this feeds it.
- **Traversal sink = a knob, not a hardcode (fork 2).** `UseLayer` already deducts per-move.
  Make the charge model a config switch — `charge_on = "deeper_only"` (free to retreat toward
  neutral, pay to descend deeper) vs `"every_move"` — defaulting to `deeper_only`. Gameplay decides
  the final feel, so it must be tunable live, not committed in code.
- **Depth = desirability (fork 3) → Eternal pets** live in the deepest/rarest sources (§15).

**Build status — World S3 logic COMPLETE (drivable via the `layer.*` bus):**
- S3.1 ✅ 5 layers/side + soul/level/token access gates (`LayerAccess`, `configs/layers.lua`).
- S3.3 ✅ traversal sink as a config knob (`traversal.charge_on = deeper_only`, free to retreat).
- S3.2 ✅ token earning (`RealmTokens` + `LayerService:Grant*`): income cut wired into the mining
  payout; conquest hook in `AlignmentService`; hatch grant available.
- S3.4 ✅ reward multiplier on income (deeper = richer) + depth-scaled hatch luck
  (`RealmHatchLuckBonus` attr → `HatchEntitlementService`).
- The loop: enter a realm (richer income + earns tokens) → spend tokens to descend (bigger
  multiplier + better hatch luck), gated by soul/level. Headless-verified; bus-drivable.
- **Remaining = authored art, not code:** in-world portal geometry at the layer Y-offsets
  (±2000…±10000) so you can physically travel/feel it, + a live multiplayer verify. Until then
  the realm is a logical state (CurrentLayer) entered via `layer.use`.

---

## 15. Eternal pets (EXISTING mechanic — already built; this just records it here)

**Eternal is dynamic team-scaling, NOT a fixed "higher level."** An eternal pet's effective power =
`power_percent` × the **eternal power base** = the average of the player's **top-N non-eternal pets**
(N = equip capacity). So it *auto-scales with your account* and stays relevant forever — the whole
point is **eternal relevance, not raw dominance.** An eternal at 80–90% sits just under your best and
never falls out of usefulness as you grow; it is *not* necessarily better than your top pet.

- **Source of truth:** `configs/pets.lua` `eternal { huge_power_percent = 120,
  baseline_includes_eternal = false }` + per-pet `eternal { enabled, power_percent }`. Resolved
  server-side in `PetHandler.resolveEffectivePetPower` (the pet's configured base power is a FLOOR).
  Wiki: `ARCHITECTURE.md`, `DECISIONS.md` (Pet Power SoT), smoke `tests/studio/EternalPowerSmoke.lua`.
- **Huge is eternal** at 120% (clamped ≥100%) — always ≈1.2× your best non-eternal average.
- **Respects the §5 ceiling for free:** it's a % of *your own* pets, which are themselves bounded
  by `max_pet_power`; the Creator apex still holds. No new cap-breaking axis.
- **Secret / Exclusive are existing rarities** (enchant slots: Secret 2 / Exclusive 2 / Huge 3;
  stored as unique pet records). They are the *classes/sources* that carry the eternal flag:
  **Exclusive** = rare hatch / exclusive egg / dev encounter (§7 Meet-the-Creator); **Secret** =
  ultra-rare hidden-odds hatch.
- **Why this is the §12 depth-desirability payoff:** deep-realm / rare-source rewards are *eternal*
  pets — perpetually worth chasing precisely because eternal scaling keeps them good forever, while
  the bounded model stops them from trivializing the ladder.
