# Game Events — one hook, config-driven reactions

> **Vision (Jason):** when something happens by functionality — a level changes, a death, a hit, an
> area unlock — code fires a *named event*, and **configuration** decides what reacts: audio, a
> visualization, (later) a toast or callback. They're all linked through one hook, so you change
> reactions in config without touching the firing code.

## The shape

```
code DETECTS an event ─► GameEvents.fire("level_up", ctx) ─► configs/game_events.lua[name] ─► reactions
                                                               level_up = {                    ├─ sound  ✅
                                                                 sound = "celebratory_jingle",  ├─ vfx    ✅
                                                                 vfx   = { kind="burst", ... }, ├─ toast  (todo)
                                                               }                                └─ callback (todo)
```

- **Event** = a named thing that happens (`level_up`, `area_unlocked`, …). Detecting it is the only
  inherently-code part.
- **Reaction kind** = `sound`, `vfx`, … Each kind has ONE generic handler registered in the
  dispatcher. Adding a kind makes it usable from config everywhere.
- **Binding** = `configs/game_events.lua` maps event → `{ kind = spec, ... }`. Pure config.

## Files

| Piece | Path |
|---|---|
| Event → reactions registry (config) | `configs/game_events.lua` |
| Client dispatcher (`fire` + reaction handlers + server bridge) | `src/Client/Systems/GameEvents.lua` |
| Sound catalog (referenced by `sound` reactions; each has a `bus`) | `configs/sounds.lua` |
| Server→client bridge remote | `Signals.GameEvent` (`src/Shared/Network/Signals.lua`) |
| Config-integrity guardrail | `tests/headless/specs/game_events.spec.luau` |

## How to add an EVENT SOURCE (fire it)

- **Client-detected** (an attribute changed, a UI result): `require(...Systems.GameEvents).fire("name", ctx)`.
  Examples already wired: `level_up` (ClaimedLevel increase, in `LevelUpController`),
  `area_unlocked` (ZoneUnlockResult ok, in `init.client`).
- **Server-originated** (death, hit, purchase): `Signals.GameEvent:FireClient(player, "name", ctx)`.
  The client `GameEvents.start()` bridge forwards it to `fire()`. No new service needed.

Then add the reactions in `configs/game_events.lua`. Done — no dispatcher code.

## How to add a REACTION KIND

In `src/Client/Systems/GameEvents.lua`, register a handler: `REACTIONS.<kind> = function(spec, ctx) ... end`.
Add `<kind>` to `KNOWN_KINDS` in the spec. Now any event can use `<kind> = <spec>` in config.

Current kinds:
- `sound = "<key in configs/sounds.lua>"` — one-shot on the sound's configured `bus`.
- `vfx = { kind = "burst", color = {r,g,b}?, count = n? }` — self-contained celebratory burst at the
  local player (no asset dependency). Extend with more `kind`s or route to `CombatFX`.
- `float = { color = {r,g,b}?, prefix = ""?, size = px? }` — rising text whose CONTENT comes from
  the event ctx (`ctx.name`), anchored at `ctx.position` (a Vector3 — e.g. the broken crystal)
  when given, else at the local player. Used by `enhancement_pickup` and `coin_payout` (#172).

## Status

- ✅ Bus + dispatcher + server bridge + guardrail spec.
- ✅ Reaction kinds: `sound`, `vfx` (burst).
- ✅ Sources wired: `level_up`, `area_unlocked` (both audio + visual, config-only).
- ⏳ More sources to route — but several (`egg_hatch`, `purchase`, combat `hit`) already have ad-hoc
  reactions; migrating them onto the bus means refactoring working systems + re-tuning feel, so do it
  deliberately (with eyes on the result), not as a blind sweep.
- ⏳ Reaction kinds to add: `toast`, `callback`, and a richer `vfx` (CombatFX-backed).

## Migration worklist — COMPLETE (every migratable moment is on the bus)

Legend: ✅ on the bus · 🔌 source wired, reactions config-optional (add a row to react) ·
⚠️ intentionally OFF the bus (high-frequency; use coin-floats #172/#173, not stingers).

### Progression
- ✅ `level_up` — ClaimedLevel↑ (`LevelUpController`) — jingle + gold burst
- ✅ `area_unlocked` — ZoneUnlockResult ok (`init.client`) — jingle + green burst
- ⚠️ `ascend_prompt` — stepping on the altar; skipped (low value)
- ~~rank_up~~ — turned out to be the QUEST tracker banner ("Seasoned Soul" is a quest name);
  covered by `quest_complete`. No separate rank system exists.

### Economy
- ✅ `purchase_success` (EconomyService) — small gold burst (toast stays)
- ✅ `sell_success` (EconomyService) — small green burst (toast stays)
- 🔌 `economy_error` (EconomyService:_sendError) — wired; add an error blip when uploaded
- ✅ `first_purchase_bonus` (MonetizationService) — jingle + big warm burst
- ✅ `coin_payout` (BreakableSpawner, per contributor at the NODE position) — silent gold float (#172)
- ⚠️ `currency_gain` — per-pickup; superseded by `coin_payout` above

### Eggs & Pets
- 🔌 `egg_hatch` (EggService, per successful batch) — wired; reveal pop stays animation-synced
- ✅ `egg_hatch_rare` (EggService, ONCE per batch when specials > 0) — jingle + rainbow burst
- ✅ `new_species` (PetIndexService first discovery) — jingle + star-gold burst
- ✅ `pet_fusion` (FusionService) — jingle + chaotic purple burst
- ⚠️ `pet_equip` — minor UI moment; skipped

### Combat
- ⚠️ `pet_hit` / `heal` / `power_cast` — already FX'd per-action; stay as-is by design
- ✅ `pet_down` (EnemyService:_downPet, owner-resolved) — somber low thud
- ✅ `pet_revive` (PowerService revive family) — power-up sting + green burst
- ✅ `enemy_defeated` (EnemyService:_onDefeated, per contributor) — small SILENT burst (frequent)
- ⚠️ `crystal_broken` — very frequent; belongs to coin-float #172

### Social
- ✅ `trade_complete` (TradeService — fired to BOTH players) — jingle + white sparkle
- ✅ `enchant_success` (EnchantService, at the reveal moment) — spell-cast sting + arcane burst
- trade_request — already handled by the dedicated popup; not a bus moment

### Meta / UI
- ✅ `achievement_completed` (AchievementsService) — jingle + magenta burst
- ✅ `quest_complete` (QuestService:Claim) — jingle + sky-blue burst
- ✅ `daily_claim` (DailyService:Claim) — jingle + teal burst

### Ambient
- `area_change` — the area-music crossfade (AreaMusicController) IS the reaction; no extra event

All celebrations currently share `celebratory_jingle` (differentiated by burst colour); giving any
event its own sound is a one-line config swap once more stingers are uploaded.
