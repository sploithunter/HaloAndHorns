# The Prologue — a playable cold open (design spec, DRAFT)

**Status:** proposed, not built. Jason 2026-07-24.

## The problem this solves

> "Our player retention bottleneck is literally in the first 15 seconds. They drop into a
> game, the map's not great... we need to hook them some way that shows them immediately
> this game is not a normal pet hatching game."

A new player's first frame is currently a homeworld that doesn't yet sell the game, and a
starter egg that reads as every other Roblox pet hatcher. The depth — powers, archetypes,
squad combat, realms — isn't visible for many minutes, and most of them leave first.

## The shape

Spawn a genuinely-new player into a **dressed dungeon room mid-battle at level 50**, hand
them one button, let them flatten a room, tease the endgame, then hard-cut to the starter
egg with an explicit "one year from now" frame.

### What this is NOT

- **Not a boot-screen filler.** Measured boot: 8.1s cold / 3.5s warm, but only ~3s of the
  cold start is usable (the rest is before anything renders). Three seconds is not a set
  piece. The prologue does not try to hide inside boot.
- **Not added time.** It replaces the first ~8 seconds of gameplay, which are currently the
  weakest in the session. The comparison is prologue-vs-bad-first-impression, not
  prologue-vs-nothing.
- **Not a cutscene.** Interactive by second two. The failure mode of a cold open is
  passivity, not length — 8 seconds of watching is a cost, 8 seconds of tapping is the game
  having started.

### The usable boot window (~3s)

One **static title card** — reuse the CHOOSE YOUR SIDE heaven/hell art already produced for
the ad thumbnail. Single image, loads instantly, primes tone, zero engineering. This is the
whole boot-screen ambition; nothing dynamic goes here.

---

## Beat sheet (~8 seconds)

Timings from prologue start (post-spawn). Every beat is **skippable** and the whole
sequence is **hard-capped**.

| t | Beat |
|---|---|
| 0.0 | **Snap in** — no slow fade (slow fades read as "cutscene, skip me"). Camera already framed on the player character, mid-room. Battle is *already in progress*: squad pets fighting, enemies pouring through a breach, VFX live. |
| 0.0–1.5 | **Establish.** HUD reads level 50 — full level ring, populated hotbar. The player is visibly powerful before they've done anything. |
| 1.5–2.0 | **The ask.** Ambient action softens; one hotbar slot pulses large. Single prompt: **TAP**. |
| 2.0 | **The payoff.** They tap → screen-clearing AoE. Mass evaporation, damage numbers everywhere, shake, the good sound. This is the moment the whole feature exists for. |
| 3.5–5.5 | **Escalate.** A bigger wave floods in. Second button pulses — a *different* power. Teaches "there are many of these," not "there is a button." |
| 6.5 | **The tease.** Boss silhouette drops through the breach — recommend the **Empyrean Dragon / Abysmal Wyrm** pairing from the ad art, so the thing they clicked the ad for appears in-game within 7 seconds. Beat of menace. No fight. |
| 7.5 | **Cut.** Whiteout. Caption: **ONE MONTH FROM NOW.** |
| 8.0 | **Land.** Warp to the real spawn, level 1, starter egg glowing, tutorial step `hatch_first_egg` active. Optional caption: **Today.** |

The closing frame is load-bearing. Without the explicit flash-forward framing, level 1 reads
as a *demotion* and the prologue engineers its own letdown — the known failure mode of
power-fantasy cold opens. The cut must say "that was your future," not "that was a demo."

**"One month," not "one year"** (Jason): a month is a promise the game can actually keep —
he estimates a determined player gets there in a week. A distant horizon reads as *grind* and
pushes the payoff outside the window a new player is willing to imagine; a near one reads as
*reachable* and converts the fantasy into an intention. Never quote a timeframe longer than
the game's real pace — an over-promise here is a broken promise later.

---

## Architecture

### Real combat, rigged outcome (Jason's call — supersedes the scripted-diorama draft)

> "Could we throw an NPC character in there and use the sidekicking code? We still want them
> to have powers, but it might be a better coding path."

Right, and better than the diorama this spec originally proposed — because it's **honest**.
Real stats, real damage numbers, real to-hit curve. A faked set piece is a promise the game
might not keep; this is the actual game running.

Determinism is still the hard requirement (an 8-second set piece that occasionally whiffs is
worse than none), but it's bought a better way: **real combat against rigged enemies.** The
onramp already does exactly this — `BaddieSpawnerService` clones a real def and scales it by
`engagement.onramp` `hp_mult` / `dmg_mult`. Same trick, harder numbers: trivial HP, zero
outgoing damage. Real system end to end, guaranteed result.

### The lift: a third `GetEffectiveLevel` branch, not an NPC anchor

The existing sidekick branches (`TeamLead`, `AllianceAnchor`) both resolve their anchor with
`Players:FindFirstChild(name)` — **an NPC has no Player object**, so neither can anchor to
one as written.

The fix is smaller than making NPCs anchorable. `GetEffectiveLevel` is already a clean branch
chain; the prologue is a third link reading a `PrologueLevel` attribute:

```
team lead  →  alliance anchor  →  PROLOGUE  →  own earned level
```

~10 lines, structurally identical to its neighbours, and since it's the same pipe every
consumer — pet damage, the accuracy curve, enemy spawn tuning — inherits it for free. Clear
the attribute at warp-out and the player is level 1 again with no teardown.

### So the NPC becomes a character, not plumbing

Freed from being the lift mechanism, the NPC ally is worth having for what it *says*: a
veteran fighting beside you, with the **TEMPORARY ALLIANCE** banner up. The prologue then
teaches the exact mechanic that will rescue this player at a camped cave three days later —
onboarding a real system instead of only showing off.

### Ghost pets — RESOLVED: the world folder is the interface

The prologue runs **before** the starter-pet choice, so the player owns nothing. Jason asked
whether we could inject fake entries into the `Equipped` folder. **We don't need to — and
shouldn't.**

Code read (2026-07-24) settles it. `workspace.PlayerPets/<name>` is the real seam, and
everything downstream reads that folder *directly*, with no inventory or `Equipped` lookup:

| Consumer | What it reads |
|---|---|
| `PetFollowService:_tickPlayer` | every `Model` with a `PrimaryPart` in the folder — movement, mining, combat |
| `SquadHud` | the same folder's children — **this is what builds the HUD cards** |

`Equipped` sits *upstream* of that: it's the profile→world builder that `loadEquipped`
consumes. Injecting there means fighting the save layer for a result the world folder gives
us for free.

**So: spawn plain pet models straight into `workspace.PlayerPets/<name>`.** They follow,
fight, mine, and render squad cards — with zero profile contact. The isolation rule holds by
construction: ghost pets are never inventory records, and cleanup is destroying the models.

### Why the Genie doesn't show in the pet HUD (and why the prologue must not copy it)

> "We kinda have similar code for the Genie of the Sands... it's not a real pet but it
> manifests everything. The only thing is it doesn't show up in the pet HUD. I kind of always
> thought it should."

Mystery solved, and it's not a missing feature. `SummonService` parents guardians to its own
`Workspace.Guardians` folder — **not** `PlayerPets`. `SquadHud` is already built to render
exactly what Jason wants; the genie simply isn't in the room the HUD is looking at.

**Implication for the prologue:** ghost pets must be *plain pet models in `PlayerPets`*
(driven by `PetFollowService`), NOT guardian-style self-driven models. Copying the guardian
pattern would inherit the exact HUD gap we need to avoid — a level-50 fantasy with an empty
squad rail is not the fantasy.

**Implication for the genie** (separate task, not this one): moving guardians into
`PlayerPets` would get HUD cards, but `PetFollowService` would immediately start driving a
model `SummonService._step` is *also* driving — two movers, one model. The fix needs a
movement-ownership marker the follow service skips. Small, but not free, and out of scope
here.

### The cast: heaven pets vs hell adversaries (Jason)

Player fights with **heaven** pets; the enemy wave is **hell** — scarier silhouettes, and the
right visual read for an 8-second threat. Both are temporary (see ghost pets below).

**Tension worth naming:** the ad creative promises CHOOSE YOUR SIDE with both dragons as
equals, and the whole realm identity is that hell is *playable*, not villainous. A prologue
that casts hell as the monsters prejudices a choice the game wants to keep open — the player
who was going to pick hell just watched hell get flattened as the bad guys.

**Recommended resolution: randomize the sides per player.** Same room, same beats, swapped
casts. It costs nothing (both rosters exist), keeps faith with the ad, foreshadows the choice
rather than pre-empting it, and doubles as a free A/B on which framing converts better. If it
has to be one fixed framing, Jason's is the right one — hell reads scarier.

### Profile isolation (hard rule) — and where the reward goes

The prologue itself is **read-only with respect to the player profile.** It grants nothing,
saves nothing, spends nothing, and touches no inventory. If it errors, times out, or the
player disconnects mid-sequence, they land at normal spawn in a clean level-1 state and the
tutorial proceeds. Same doctrine as the economy work: no partial state, ever.

**The reward is granted at landing, not during** (Jason: "players should have some kind of
reward for the experience"). One atomic grant through the existing `RewardService`, fired
after the warp-out, in normal game state — so a crash mid-sequence can never leave a half-paid
player, and the isolation rule survives intact.

What it should *be* is constrained by two collisions:

- **Not a pet.** The starter-pet chooser is the very next thing that happens; a granted pet
  competes with the choice the prologue exists to set up.
- **Nothing that outclasses level 1.** The prologue's whole job is to make the early game feel
  like the first step toward power, not to hand over the power.

**Recommendation: an achievement + a small gem grant.** The achievement matters more than the
gems — it lands as the *first entry in their Achievements panel*, so the trophy case isn't
empty in minute one. Empty-state avoidance is a real retention lever and this gets it for
free. The gems are the tangible "that counted."

Open: whether the achievement is visible to everyone (a permanent "was there at the start"
marker, which ages well) or is a standard tiered entry.

### Components

| Piece | Responsibility |
|---|---|
| `configs/prologue.lua` | Everything tunable: beats + timings, room kit, pet/enemy cast, the two powers, captions, flag + A/B split, caps. |
| `PrologueService` (server) | Eligibility gate, room build, cast spawn, sequence authority, warp-out, telemetry fire. |
| `PrologueController` (client) | Camera, the tap prompts, captions, skip button, whiteout. |
| `Shared/Game/PrologueFlow.lua` | Pure beat-timeline resolver + eligibility predicate → headless spec. |

### Reuse

- **Room build + dressing:** `MissionInstanceService` already generates, dresses, and
  populates interior rooms (`_applyDressing`, `_placeTreasures`). The prologue room should be
  a mission kit, not a new authoring path.
- **Warp-out:** `MissionInstanceService:_safeWarp` already exists and is proven.
- **Telemetry:** `RetentionService` already logs the onboarding funnel to Roblox analytics.

### Eligibility — the starter-pet gate, exactly (Jason)

Same one-time mechanism as the first-pet selection, not a new one. `StarterPetService`
persists `data.StarterPet = { choice, chosenAt, version }`; its absence *is* the "new player"
signal. The prologue mirrors that shape:

```
data.Prologue = { seenAt = <os.time>, version = <config version>, completed = <bool> }
```

Absent → eligible. Present → never again, on any server, forever. `version` leaves room to
re-show a reworked prologue later without a migration.

Write the record **on start, not on completion** — a player who rage-quits three seconds in
must not get it again on rejoin. `completed` distinguishes "saw it" from "watched it through"
for the analytics, but eligibility keys off the record existing at all.

### Testing path — admin reset must clear it

The admin **Reset to Beginning** (`Admin_ResetToBeginning`, `resetData` permission,
Studio-gated) is how the starter-pet flow gets retested: it wipes pets, so
`StarterPetChoice.findGrantedStarter` returns nil and the chooser fires again.

**The reset must also clear `data.Prologue`** — otherwise the prologue is a one-shot that
can never be re-observed after the first run, which makes it effectively untestable. This is
a required part of the build, not a nice-to-have.

### Ordering: prologue before starter-pet choice

Hook first, then choose. Two consequences worth being deliberate about:

- The prologue's squad should be **apex pets, not starters** — the dragons from the ad art.
  If it showed starter pets it would preempt a choice the player hasn't made yet.
- Better still, that turns the starter-pet screen into the first step *toward* what they just
  saw, rather than an unrelated menu. The prologue shows the destination; the chooser is the
  first move.

---

## Asset budget

**Rule: the prologue may not introduce assets beyond (a) what the game already preloads for
normal play, plus (b) one room kit and one boss model.**

This keeps the marginal load cost near zero on the mid-range phone that ad traffic will
actually arrive on — the prologue runs while the rest of the world is still streaming, so it
cannot afford its own asset tail.

- Room: 1 mission kit, heavy mesh reuse
- Squad: 2–3 pets, drawn from already-loaded starter/apex sets
- Enemies: 1–2 types, many instances (count sells the spectacle, not variety)
- Boss: 1 model, may be dark-tinted / low-detail — it is a silhouette, not a fight
- VFX + sound: existing registry only

---

## Telemetry

Fire through `RetentionService`:

| Event | Why |
|---|---|
| `prologue_start` | denominator |
| `prologue_tap` | **the key engagement metric** — did the hook land? |
| `prologue_skip` | with the beat index they bailed at |
| `prologue_complete` | reached the warp-out |

Then the existing funnel continues (`hatch_first_egg`, `equip_pet`, …) so the prologue's
effect on *downstream* steps is directly readable.

## Ship it behind a flag

`prologue.enabled` + `prologue.ab_split = 0.5`.

The ad run is about to buy the exact sample needed to settle this. Prologue-on vs
prologue-off, compared on D1 and on `hatch_first_egg` completion. "We think it feels better"
is how studios keep expensive prologues that lose — and this one costs real player seconds,
so it should have to earn them.

---

## Risks

| Risk | Mitigation |
|---|---|
| Perf on mid-range phone while world streams | asset-subset rule above; count over variety |
| "Why am I level 50 / where did my pets go" | explicit ONE YEAR FROM NOW → Today framing |
| Level 1 feels weak after the power fantasy | fast handoff — egg is glowing and actionable on landing |
| Replay annoyance on rejoin | one-time `data.Prologue` record, written on START |
| Non-determinism ruining the set piece | scripted outcomes, not simulated combat |
| Disconnect / error mid-sequence | profile isolation — always lands clean at normal spawn |

## Open questions

1. **Fixed or randomized sides** — Jason's call is heaven-player / hell-adversary; the
   recommendation above is to randomize and A/B it. Needs a decision.
2. **Which two powers** for the tap moments? Wants maximum visual read — a screen-clearing
   AoE first, then something structurally different (summon? control?) for the second.
3. **Boss tease** — confirm the Empyrean Dragon / Abysmal Wyrm pairing, for continuity with
   the ad creative.
4. **Skip button** — visible from t=0, or after ~2s so the tap moment gets its chance?
5. **Reward shape** — achievement + gems as recommended, and is the achievement a permanent
   "was there at the start" marker or a normal tiered entry?

## Build order

1. `configs/prologue.lua` + pure `PrologueFlow` (eligibility predicate + beat timeline) + spec
   — the ghost-pet unknown that used to live here is **resolved** (see above), so step 1 is
   back to being cheap
2. `PrologueService` — gate, `data.Prologue` record, room build, warp-out. **Plus the
   admin-reset clear**, so it's testable from step two onward
3. `PrologueController` — camera, prompts, captions, skip
4. The set piece itself — cast, scripted beats, the two power moments
5. Telemetry + A/B flag
6. Live verify on a real phone via Reset to Beginning, then ship into the ad run
