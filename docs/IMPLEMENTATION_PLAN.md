# Implementation Plan

**Status:** Draft v0.1
**Reads with:** `docs/FOUNDATION_AND_REQUIREMENTS.md` (the Given/When/Then spec; requirement IDs like `FR-PIPE-2` are referenced throughout).
**Principle:** build the *foundations* (stats, resolution pipeline, save versioning, config validation, map contract) before the feature tiers, so each feature collapses into config + a thin service instead of a bespoke system.

---

## 1. Sequencing rationale

The reference game's features were authored in player‑value order, which is why several "features" are secretly infrastructure that everything else leans on. We reorder so that infrastructure lands first:

```
Phase 0  Foundations (code)        K4 validation · K3 save versioning · K1 stats · K2 pipeline · K5 daily seed · K6 ledger · K7 flags
Phase 1  Map Integration Contract  K8 WorldBindingService · markers.lua · areas.lua zones · synthetic baseplate (incl. per-area gap-fill)
Phase 2  Economy depth             equip/storage limits · upgrades · area unlocks + teleports
Phase 3  Stats-derived wins        achievements · leaderboards · pet index   (≈ config only)
Phase 4  Progression depth         pet levels/XP · player-level power · enchant-slot unlocks · enchants · upgrade modifiers
Phase 5  Auto systems              auto-target modes · auto-delete filters
Phase 6  Cadence & events          scheduled luck days · Pet of the Day · daily rewards/codes/gifts
Phase 7  Content variety           rare/dark breakables · seasonal chaseables · limited stock
Phase 8  Marketplace + monetize    Roblox-native exchange (escrow) · gamepass/product polish
```

Every phase is gated behind a feature flag (K7), ships with migrations that are additive‑only (K3), and ends with a Definition of Done tied to GWT IDs.

---

## 2. The Rojo ↔ Studio workflow (read first)

Per **P1 + P9**, ownership splits at the **Map Integration Contract**:

- **Rojo owns** `src/` and `configs/` as text (scripts, data, UI, networking, validation, admin tools).
- **Studio / World Builder owns** Workspace geometry and the placement of tagged, attributed *markers*.
- They meet only at tags + attributes + contracted child‑marker names (K8).

**`default.project.json` scoping (do this in Phase 1):** Rojo MUST map `src/` into `ReplicatedStorage`/`ServerScriptService`/etc. and `configs/` into a `Configs` folder, but MUST NOT own the `Workspace` map subtree the World Builder edits. Concretely, do not point a Rojo `$path` at the authored map container; let Studio own it. This is the same non‑destructive scoping discipline used when extracting the reference games.

**Map modes (`configs/game.lua` → `map.mode`):**
- `auto` (default) — use authored areas where present; **synthesize missing areas** on a baseplate (FR-MAP-13). Best for day‑to‑day dev.
- `synthetic` — ignore authored geometry, always baseplate. Best for CI / fast iteration with zero Rojo re‑apply.
- `authored` — require the full authored map; fail loud on any missing hook (FR-MAP-2). Shipping safety.

**The fast iteration loop we're buying:** edit a config or script → Rojo live‑syncs → play on the baseplate (synthetic map binds instantly) → no "apply, re‑apply for a tiny change" cycle, and no dependency on a finished world.

---

## 3. Standard recipes (so phases stay terse)

**Add a config:** create `configs/<name>.lua` returning a table → add a schema entry (Phase 0 K4) → access via `ConfigLoader:LoadConfig("<name>")` or a typed getter.

**Add a service:** create `src/Server/Services/<Name>Service.lua` with `:Init(self._modules)` (and `:Start()` if needed) → register in `src/Server/init.server.lua`:
```lua
loader:RegisterModule("<Name>Service",
    ServerScriptService.Server.Services.<Name>Service,
    {"Logger", "ConfigLoader", --[[deps]] })
```
ModuleLoader handles topological ordering + circular‑dependency detection.

**Add client/server comms:** add a bridge/packet to `configs/network.lua` with `rateLimit`, `direction`, `validation`, and `handler = "<Service>.<Method>"`. No manual RemoteEvents (FR-X-NET-1).

**Add a saved field:** extend `generateProfileTemplate` in `DataService`, bump `SchemaVersion`, register a migration step that backfills from config defaults (FR-SAVE-1/4).

**Add a map hook:** declare the tag + required attributes in `configs/markers.lua`; consume it via `WorldBindingService:GetBound(tag)` / zone events. Provide a synthetic fabrication rule so it works on the baseplate (FR-MAP-9/13).

**Add a modifier source:** register a provider with `ModifierService:RegisterProvider(stage, providerFn)` at service init; add the stage's contribution shape to `configs/economy.lua`. Consumers of resolved values change nothing (FR-PIPE-6).

**Add a tracked stat:** declare it in `configs/stats.lua`; call `StatsService:Increment(player, key, n)` at the source event. Achievements/leaderboards/index read it for free.

---

## 4. Map contract reference (canonical tags & attributes)

> Authored in Studio; validated (not generated) by code, except synthetic fallback. Extend in `configs/markers.lua`.

| Tag (CollectionService) | Required attributes | Binds to config | Synthetic fallback |
|-------------------------|---------------------|-----------------|--------------------|
| `Zone` (world/island) | `ZoneId`, `Kind`, opt `ParentZoneId` | `areas.lua[ZoneId]` | grouping zone per missing id (FR-MAP-15) |
| `AreaZone` (= `Zone` Kind="area") | `AreaId`, opt `ParentZoneId` | `areas.lua[AreaId]` | box volume per missing AreaId |
| `SpawnZone` | `AreaId`, `SpawnerId`, opt `DepthOffset`, `MaxCountOverride` | `breakables.lua` spawner | volume inside the area |
| `TeleportPad` | `AreaId` (source), `TargetZoneId` | `areas.lua` | pad wired between areas (FR-MAP-13/14) |
| `Portal` | `ZoneId` (source), `TargetZoneId` | `areas.lua` | portal wired between worlds/islands (FR-MAP-15) |
| `EggStand_<id>` (contracted name) or tag `EggStand` + `EggId` | `EggId` | `eggs.lua[EggId]` | stand at area offset |
| `PetDisplay_Podium` (contracted name) or tag `PODPodium` | none / `Slot` | `pet_of_the_day.lua` | podium at spawn area |
| `ChaseableRegion` | `AreaId`, `ChaseableId` | `chaseables.lua` | volume in area (Phase 7) |
| `ShopAnchor` / `NPCAnchor` | `AnchorId` | UI/shop config | anchor at area offset |

Container naming convention: `<HookKind>_<Place>` (e.g. `CrystalSpawnZone_SpawnIsland`) for human readability; binding is by tag+attribute, never by the container name (C3).

---

## 5. Phases

### Phase 0 — Foundations (code only; no map dependency)

**Goal:** the four invisible systems everything else stands on.

| Item | Build |
|------|-------|
| **K4 Config validation** | Add a schema pass to `ConfigLoader:Init` — declare expected shape per config; validate types + required keys + cross‑references (egg.currency ∈ currencies, reward.pet ∈ pets). Halt boot with file/key/expected‑vs‑actual on failure. |
| **K3 Save versioning** | Add `SchemaVersion` to the profile template; add a `migrations` table in `DataService` (`[from] = fn`) applied in order on load; backfill new config‑driven fields from defaults. |
| **K1 Stats** | `configs/stats.lua` (counters: `taps`, `eggs_hatched`, `breakables_broken`, `secrets_found`, `rebirths`, `coins_earned_lifetime`, `distinct_pets`, each with `scope`). `StatsService` with `Increment` / `Get` / change signal. Store under profile `Stats.Counters`. |
| **K2 Modifier pipeline** | `src/Shared/Economy/ModifierPipeline.lua` (pure `Resolve(base, context, providers)` honoring stage order + combine modes from `configs/economy.lua`, with itemized breakdown). `ModifierService` aggregates `RegisterProvider(stage, fn)`. **Refactor `EconomyService` + `BreakableSpawner`** to route rewards/luck through it instead of reaching into `PlayerEffectsService`/`GlobalEffectsService` directly. |
| **K5 Daily seed** | Add `GetServerDayNumber()` + `GetDailySeed(salt)` to `ServerClockService`. |
| **K6 Ledger** | Tag every currency mutation in `EconomyService`/`DataService` with `source`; aggregate source/sink totals; expose to admin. |
| **K7 Flags** | Add `features = { ... }` to `configs/game.lua`; gate `RegisterModule` calls and bridge activation on flags. |

**Service registration added:** `StatsService` (`{"Logger","ConfigLoader","DataService","ServerClockService"}`), `ModifierService` (`{"Logger","ConfigLoader"}`).
**Migrations:** v→v+1 adds `Stats.Counters`, `Ledger` (additive).
**Definition of Done:** FR-CFG-1..3, FR-SAVE-1..4, FR-STATS-1..5, FR-PIPE-1..6, FR-CLOCK-1..3, FR-LEDGER-1..2, FR-FLAG-1..2. TestEZ units for each (NFR-TEST-1). EconomyService payouts now produce a pipeline breakdown.
**Risk:** refactoring EconomyService to the pipeline is the riskiest single step — do it behind a flag and snapshot before/after payout values for parity.

### Phase 1 — Map Integration Contract + synthetic map (K8)

**Goal:** the Studio↔config seam, plus the baseplate fallback that makes everything else testable without a world.

- `configs/markers.lua` — declare tags, required attributes, and the config table each references (Section 4 table).
- `configs/areas.lua` — the **zone tree**: each entry `{ id, kind = "world"|"island"|"area", parent, unlock, boosts }`. Arbitrary depth, config‑expandable (FR-ZONE-1/2). Boosts register as a K2 provider.
- `WorldBindingService` — at boot: scan Workspace via CollectionService, build/validate the zone tree (no orphans/cycles, FR-ZONE-1) and hooks (FR-MAP-2), index bound instances by tag/attribute, raise centralized zone enter/exit events keyed by id. Owns **active‑zone activation/dormancy** (FR-ZONE-4 / P10): only the player's active subtree runs spawners/effects.
- **Synthetic builder** (inside or beside `WorldBindingService`) — in `synthetic` mode, or in `auto` mode when no authored hooks exist, fabricate the **full missing hierarchy** (worlds → islands → areas) per id at deterministic baseplate offsets, wire `Portal`s between worlds/islands and `TeleportPad`s between areas (FR-MAP-9/13/14/15). Once `auto` detects any authored contract hook, treat the place as a real map and require missing gameplay hooks to be stamped explicitly instead of generating visual fallback content. Generated maps must pass their own validation (FR-MAP-12).
- Ship a **reference map** (one of each hook, correctly attributed) + a tag/attribute doc page (FR-MAP-8).
- Scope `default.project.json` so Rojo does not own the authored map subtree (FR-MAP-6).

**Service registration:** `WorldBindingService` (`{"Logger","ConfigLoader"}`), loaded **before** spawners; update `BreakableSpawner` deps to include `WorldBindingService`.
**Definition of Done:** FR-MAP-1..16, FR-AREA-4, FR-ZONE-1..5. Game boots and runs the core loop on a bare baseplate (`synthetic`), and an authored map can receive Rojo scripts/configs without synthetic floors, spawn pads, placeholder egg stands, or breakable regions appearing. Map-specific gameplay hooks are added by the assisted authoring pass and then smoke-tested.

### Phase 2 — Economy depth

- **Equip/storage limits + upgrades:** limits in `configs/inventory.lua`/`pets.lua`; enforce server‑side in `InventoryService`; upgrade paths in `configs/upgrades.lua`.
- **Zone unlocks + travel:** `ZoneService` consuming the `areas.lua` tree + `WorldBindingService` zones/portals/pads; cascading unlock graph (parent gates children, FR-ZONE-3); persist `GameData.UnlockedAreas` by zone id; server‑authoritative `Portal`/`TeleportPad` travel with active‑subtree activation (FR-ZONE-4/5, FR-AREA-1..4).
- Stronger breakables gated by zone/currency (FR-LOOP-4).

**Service registration:** `ZoneService` (`{"Logger","ConfigLoader","DataService","WorldBindingService","ModifierService"}`).
**Migration:** add `Upgrades`, ensure `UnlockedAreas` seeded (keyed by zone id).
**DoD:** FR-PET-1..2, FR-UPG-1..2, FR-ZONE-1..5, FR-AREA-1..4, FR-LOOP-4. Verify in `synthetic` mode that a multi‑world hierarchy generates, cross‑world portals work, and per‑frame cost is flat as zones are added (NFR-PERF-3).

### Phase 3 — Stats‑derived wins (mostly config)

- `configs/achievements.lua` — `{ stat, tiers=[{goal,reward}], reward_type }`; `AchievementsService` listens to K1 change signals, grants once (FR-ACH-1..3).
- `configs/leaderboards.lua` — counter + sort; `LeaderboardService` (in‑server live + OrderedDataStore for global, refreshed on interval) (FR-LB-1..2).
- `configs/pet_index.lua` — distinct‑pet milestones; index recorded on first obtain (FR-IDX-1..2).

**DoD:** these add **no** bespoke tracking — all read K1. Adding an achievement is a config‑only change.

### Phase 4 — Progression depth (pipeline inputs)

- `configs/pet_progression.lua` + `PetProgressionService` — unique-pet XP/levels, config-driven XP curve, rarity caps, capped power scaling, and enchant-slot unlocks. Stack pets do not carry XP/level and should not be generically promoted to unique pets. Pets that need per-copy state must be unique from grant/craft/reward time. Unique pets with enchant capacity start with one unlocked slot and gain remaining potential slots through level milestones.
- `scripts/balance_team_power.py` — offline config-reading calculator for rough team-power tuning across player level/XP assumptions, pet team size, pet levels, eternal/huge behavior, configured pet power values, and `configs/player_progression.lua`.
- Pet power source-of-truth rule — family base power + variant multipliers live in `configs/pets.lua`; saved pet inventory records must not carry power values. Use `tests/studio/BackfillPetPowerSourceOfTruth.lua` to clean legacy saves after tuning changes.
- `configs/player_progression.lua` + player-level provider — player level affects team power through config, and level rewards are configurable. The first reward is +1 equipped pet slot every configured number of levels, capped by config and the inventory max slot cap.
- `configs/enchants.lua` (port reference data shape: tier→weighted Chances + value range + Scale) + `EnchantService` — roll/store enchants; **map each enchant name to a declared modifier** and register the `enchants` provider (FR-ENCH-1..3). Validation fails if an enchant has no effect mapping.
- Wire all high-priority enchant consumers: `hatch_luck`, `secret_hatch_luck`, `pet_damage`, `team_power`, and `pet_efficiency`. Current live consumers include `breakable_reward`, `pet_xp`, and those high-priority Phase 4 kinds.
- Upgrades from Phase 2 register the `permanent_upgrades` provider.
- Rebirth is deferred out of Phase 4. If it returns, it should be rare/dramatic rather than a ColorfulClickers-style repeated multiplier loop.

**DoD:** pet progression is config-driven and applies only to unique pet records; player level affects team power through config; level rewards can alter equip capacity through config; all declared enchant modifier kinds either have live consumers or are explicitly marked future-only; upgrades and enchants remain K2 providers.

### Phase 5 — Auto systems

- `configs/auto_systems.lua` + `AutoTargetService` — server-selected modes (nearest, highest value, weakest, strongest, selected currency), persisted under `Settings.AutoSystems.auto_target` (FR-AUTO-1).
- Hatch auto-delete filters by rarity/type/variant are persisted under `Settings.AutoSystems.auto_delete`, validated against pet config, and enforced inside `EggService` before `PetGrantService` (FR-AUTO-2, FR-EGG-3).
- Existing Low/High UI buttons remain compatibility toggles for configured modes. Richer settings UI controls are follow-up polish.

**DoD:** target selection is server-authoritative and smoke-tested; hatch auto-delete never bypasses configured protected special rarities; choices persist as profile settings; config validation catches invalid modes, currencies, rarities, pet ids, and variants.

### Phase 6 — Cadence & events

- Extend `configs/events.lua` + `EventService` with **scheduled** activation via `GetDailySeed` so "Lucky Day"/rotations fire identically on every server with no coordination (FR-EVT-1..3). Migrate `EconomyService` event reads to the K2 `active_events` provider.
- `PetOfTheDayService` + `configs/pet_of_the_day.lua` — daily pick from `GetDailySeed`; podium via `PetDisplay_Podium` hook; temporary multiplier as K2 `pet_of_the_day` provider (FR-POTD-1..3). (Explicitly replaces the reference's Workspace‑NumberValue/hardcoded‑podium approach.)
- `configs/rewards.lua` + `RewardsService` — daily track, codes (per‑player one‑time), gifts; all using K5 day boundaries (FR-RWD-1..3). Doubles as the economy‑pacing test harness.

### Phase 7 — Content variety

- Rare/dark breakable variants — extend `breakables.lua` spawn tables with low‑weight high‑HP/value variants (FR-RARE-1).
- Seasonal chaseables — `configs/chaseables.lua` + `ChaseableRegion` hook + date/event‑window gating via K5 (FR-CHASE-1).
- Limited stock — `configs/stock.lua` + `StockService`; per‑server simple, global via MemoryStore (live count) + MessagingService (nudge) (FR-STOCK-1..2).

### Phase 8 — Marketplace + monetization

- **Marketplace (Roblox‑native, escrow):** `MarketplaceService`‑style `ExchangeService` using DataStore (durable listings/ownership) + MemoryStore (live index) + MessagingService (nudges). Escrow is the single source of truth; anti‑dupe is non‑negotiable (FR-MKT-1..4). **Do not** port the reference's external‑DB/Robase + Discord‑webhook design.
- **Monetization polish:** gamepass/product benefits register the K2 `gamepass` provider; first‑purchase bonus, premium benefits (FR-MON-1).

---

## 6. Feature → artifacts map

| Feature | Config(s) | Service(s) | Profile fields | Network bridges | Map hooks | GWT |
|---------|-----------|------------|----------------|-----------------|-----------|-----|
| Stats | `stats.lua` | StatsService | `Stats.Counters` | (read) | — | FR-STATS-* |
| Pipeline | `economy.lua` | ModifierService + ModifierPipeline | — | — | — | FR-PIPE-* |
| Map contract | `markers.lua`,`areas.lua` | WorldBindingService | `GameData.UnlockedAreas` | — | all | FR-MAP-*, FR-AREA-* |
| Areas/teleport | `areas.lua` | ZoneService | `UnlockedAreas` | `Zone.*` / `Area.*` | `AreaZone`,`TeleportPad`,`Portal` | FR-ZONE-*, FR-AREA-* |
| Upgrades | `upgrades.lua` | (Economy/Upgrade) | `Upgrades` | `Upgrade.*` | — | FR-UPG-* |
| Achievements | `achievements.lua` | AchievementsService | `Achievements` | `Achievement.*` | — | FR-ACH-* |
| Leaderboards | `leaderboards.lua` | LeaderboardService | — | `Leaderboard.*` | optional `ShopAnchor`‑style boards | FR-LB-* |
| Pet index | `pet_index.lua` | (Inventory/Index) | `PetIndex` | `Index.*` | — | FR-IDX-* |
| Rebirths | `rebirths.lua` | RebirthService | `Rebirths` | `Rebirth.*` | — | FR-REB-* |
| Pet progression | `pet_progression.lua` | PetProgressionService | pet.level, pet.exp, pet.unlocked_enchant_slots | `PetProgression.*` | — | Phase 4 |
| Enchants | `enchants.lua` | EnchantService | pet.enchants | `Enchant.*` | — | FR-ENCH-* |
| Auto systems | `pets.lua`/settings | AutoTargetService | `Settings.Auto*` | `Auto.*` | — | FR-AUTO-* |
| Events | `events.lua` | EventService | `ActiveEffects` | `Event.*` | — | FR-EVT-* |
| Pet of the Day | `pet_of_the_day.lua` | PetOfTheDayService | — | `POTD.*` | `PetDisplay_Podium` | FR-POTD-* |
| Rewards/codes | `rewards.lua` | RewardsService | `Rewards`,`Codes` | `Reward.*` | — | FR-RWD-* |
| Chaseables | `chaseables.lua` | ChaseableService | event currency | `Chaseable.*` | `ChaseableRegion` | FR-CHASE-* |
| Stock | `stock.lua` | StockService | — | `Stock.*` | `ShopAnchor` | FR-STOCK-* |
| Marketplace | `marketplace.lua` | ExchangeService | escrow/listings | `Exchange.*` | `ShopAnchor` | FR-MKT-* |

---

## 7. Testing strategy

- **Unit (TestEZ, `tests/unit/`):** keystones K1–K5, K8 binding/validation, ModifierPipeline math + breakdown, migration steps.
- **Statistical:** egg odds (FR-EGG-1) and enchant rolls over large N.
- **Synthetic‑map integration (`tests/manual/` + CI):** boot in `synthetic` mode and exercise the full loop (break → currency → egg → pet → stronger breakable), plus teleport between synthesized areas/worlds and active-zone dormancy (NFR-TEST-2, FR-MAP-14..16).
- **Parity:** Phase 0 pipeline refactor verified by before/after payout snapshots.
- **Authority/abuse (pre‑Phase 8):** rate limits, ownership checks, escrow anti‑dupe.

## 8. Risk register

| Risk | Mitigation |
|------|------------|
| EconomyService→pipeline refactor changes payouts | Flag + before/after parity snapshots (Phase 0). |
| Migrations corrupt profiles | Idempotent, additive‑only, backfill from defaults; test on copies (FR-SAVE-2). |
| Synthetic map hides authored‑map bugs | Synthetic output must pass the same validation (FR-MAP-12); CI also runs `authored` against the reference map. |
| Multi‑currency sprawl | Ship 2 currencies; new ones are pure config; ledger (K6) flags imbalance early. |
| Marketplace duplication exploits | Escrow as single source of truth; anti‑dupe tests gate release (FR-MKT-4); ship last. |
| Map contract drift (designers vs config) | Startup validation reports precise mismatches (C4/FR-MAP-2); reference map + doc table as the spec. |

---

## 9. Open decisions (carry from requirements §8)

1. Offline/idle progression — affects K2 (resolve‑at‑login), K3 (save), economy math. Decide before Phase 2.
2. Baseline currency count — recommend 2 (soft + premium).
3. Enchant effect magnitudes — define each enchant's modifier mapping as config (FR-ENCH-2).
4. Direct trade vs auction‑only marketplace — both share escrow/anti‑dupe (FR-MKT-4).
5. Reference map ownership — decide whether the starter reference map is a checked-in `.rbxlx`/model artifact, a Studio-authored template place, or generated by an internal authoring command. This affects FR-MAP-8 and CI `authored` validation.
