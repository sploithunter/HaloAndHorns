# Foundation & Functional Requirements

**Status:** Draft v0.1
**Scope:** Progression / economy / content systems built on top of the existing RBX‑Template (Matter + Reflex + ProfileStore + config‑as‑code networking).
**Companion doc:** `docs/IMPLEMENTATION_PLAN.md` (sequenced build plan that satisfies these requirements).

---

## 1. How to read this document

This is both an **architectural foundation** and a **functional requirements specification**. Requirements are written as **Given / When / Then** acceptance criteria so they double as a test checklist.

- **MUST / MUST NOT** — hard requirement; a violation is a bug.
- **SHOULD** — strong default; deviation needs a reason recorded in the relevant config or doc.
- **MAY** — optional / per‑game‑template choice, typically gated behind a feature flag.

Every requirement has a stable ID (e.g. `FR-STATS-3`) so the implementation plan, tests, and commits can reference it.

**Design thesis (the north star):** the reference game has the right *ideas* (progression breadth, daily/event cadence, pet depth) but the wrong *shape* (logic scattered across one‑off scripts, magic numbers, Workspace‑value state). We keep the magic and invert the shape: **designer‑editable configs + a small number of authoritative services + one place where values are resolved.**

---

## 2. Architectural principles

| # | Principle | Consequence |
|---|-----------|-------------|
| P1 | **Config‑as‑code is the source of truth.** | Content and tuning live in `configs/*.lua`. Adding content = editing config, not writing a service. Code reads config; code does not hardcode content. |
| P2 | **Server is authoritative.** | Clients request; the server validates, decides, and persists. No client‑trusted economy values. |
| P3 | **One resolution pipeline for derived values.** | All multipliers/bonuses (pets, enchants, upgrades, boosts, events, rebirth, gamepass, Pet‑of‑the‑Day) combine in **one** ordered function, not inside each feature. |
| P4 | **Deterministic shared time.** | Daily/scheduled content derives from a shared day‑number/seed so all servers agree with zero coordination. Cross‑server messaging is a nudge, never the source of truth. |
| P5 | **Durable, versioned saves.** | The profile schema has a version. Old profiles migrate forward deterministically on load. |
| P6 | **Features are flagged.** | This is a *template*. Every major system can be turned on/off per game in config without deleting code. |
| P7 | **Fail loud at boot, not silent at runtime.** | Bad config is rejected at startup with a precise message. A misconfigured game never half‑boots. |
| P8 | **Stats are infrastructure, not a feature.** | Achievements, leaderboards, the pet index, daily goals, and rebirth gates are *views* over one tracked‑counter store. |
| P9 | **Geometry is authored in Studio; behavior binds by contract.** | A modeler/world‑builder builds the environment and drops *invisible markers* (tagged parts, zones, attribute‑annotated instances). Config + code bind to those tags/attributes — code never hardcodes positions or instance paths. Tags + attributes are the **only** interface between hand‑built geometry and config‑driven logic. |
| P10 | **Expandable by config; only active zones run.** | The world is a hierarchy of zones (world → island → area) of arbitrary depth. New worlds/islands/areas are added by config + tagged markers with **no code change** — content is potentially unbounded. For performance, only the player's **active** zone subtree runs (spawners/effects live); distant zones are dormant and activate on entry/teleport, so runtime cost scales with *active* content, not *total* content. |

> **The Rojo boundary (consequence of P1 + P9).** This is config‑as‑code over Rojo, so ownership splits cleanly: **Rojo owns** `src/` (scripts) and `configs/` (data) as text. **Studio owns** the hand‑built Workspace geometry (meshes, terrain, UI art) and the placement of invisible markers. The two never fight because they meet only at the **marker contract** (CollectionService tags + Instance attributes, defined in K8). `default.project.json` MUST scope Rojo so it manages scripts/config and does **not** overwrite designer‑authored Workspace geometry. A modeler can rebuild a world and, as long as the markers carry the right tags/attributes, every config‑driven system keeps working with zero code changes.

---

## 3. Foundation layer — the keystones

These are prerequisites for the feature tiers. Build order and rationale are in the implementation plan; this section defines *what they must do*.

### K1 — Unified Stat / Counter layer  (`StatsService` + `configs/stats.lua`)

A single, config‑defined set of per‑player counters with one authoritative increment path. This is the keystone the reference game lacks (its `AchievementsServer` is a hardcoded if/elseif ladder over leaderstats with magic bases).

- **FR-STATS-1** — *Given* a counter `taps` is declared in `configs/stats.lua`, *When* the server calls `StatsService:Increment(player, "taps", 1)`, *Then* the player's `taps` counter increases by 1 in the profile and the change is durable across rejoin.
- **FR-STATS-2** — *Given* a counter is not declared in `configs/stats.lua`, *When* any code attempts to increment it, *Then* the call MUST error at boot‑time validation (declared counters only) — no silent counter creation.
- **FR-STATS-3** — *Given* a counter declares `scope = "lifetime"` vs `scope = "session"` vs `scope = "daily"`, *When* a session ends or the day rolls over (see K5), *Then* session/daily counters reset at the correct boundary while lifetime counters persist.
- **FR-STATS-4** — *Given* any gameplay event that other systems care about (hatch, break, rebirth, purchase, secret found), *When* it occurs, *Then* the owning service MUST funnel it through `StatsService` rather than tracking its own private counter.
- **FR-STATS-5** — *When* a counter changes, *Then* `StatsService` MUST emit a change signal (Reflex action / Signal) so achievements, leaderboards, and UI react without polling.

### K2 — Modifier resolution pipeline  (`Shared/Economy/ModifierPipeline` + `configs/economy.lua`)

One ordered function that turns a base value into a final value given a context. Today `EconomyService` reaches into `PlayerEffectsService` and `GlobalEffectsService` directly; that is the scatter we are removing.

- **FR-PIPE-1** — *Given* a base economy value (e.g. breakable coin reward) and a context (player, currency, source), *When* the value is needed, *Then* it MUST be produced by `ModifierPipeline:Resolve(base, context)` and not computed ad hoc inside the feature service.
- **FR-PIPE-2** — *Given* the pipeline stage order is declared in `configs/economy.lua`, *When* resolving, *Then* stages apply in that declared order. Default order: `base → pet_stats → enchants → permanent_upgrades → rebirth → boosts → active_events → pet_of_the_day → gamepass`.
- **FR-PIPE-3** — *Given* each stage declares a combine mode (`add`, `multiply`, `override`, `cap`), *When* stages combine, *Then* the math follows the declared mode so designers can reason about it without reading code.
- **FR-PIPE-4** — *Given* the same `(base, context)`, *When* resolved twice with no state change, *Then* the result is identical (pure function; no hidden RNG inside resolution — luck rolls happen *before* resolution and enter as context).
- **FR-PIPE-5** — *When* resolving, *Then* the pipeline MUST be able to emit an itemized breakdown (which stage contributed what) for tooltips, admin inspection, and balancing.
- **FR-PIPE-6** — *Given* a new modifier source (e.g. a future "pet personality" stat), *When* it is added, *Then* it plugs in as a declared stage + config contribution with **zero** edits to feature services that consume resolved values.

### K3 — Save schema versioning & migration  (`DataService`)

- **FR-SAVE-1** — *Given* the profile template declares `SchemaVersion = N`, *When* a profile with version `M < N` loads, *Then* registered migration steps `M→M+1→…→N` run in order before the profile is used.
- **FR-SAVE-2** — *Given* a migration step, *When* it runs, *Then* it MUST be idempotent and MUST NOT destroy unrelated fields.
- **FR-SAVE-3** — *Given* a profile already at version `N`, *When* it loads, *Then* no migration runs.
- **FR-SAVE-4** — *Given* a new currency/pet field is introduced via config, *When* an existing profile lacks it, *Then* the value is backfilled from config defaults (not left nil).

### K4 — Config validation & loading  (`ConfigLoader`)

- **FR-CFG-1** — *Given* a config declares a schema (shape + required keys + value types), *When* the game boots, *Then* `ConfigLoader` validates every config and **halts with a precise error** (file, key, expected vs actual) on any violation.
- **FR-CFG-2** — *Given* a config references another (e.g. an egg's `currency` must exist in `currencies.lua`, a reward's `pet` must exist in `pets.lua`), *When* validating, *Then* cross‑references are checked and dangling references fail the boot.
- **FR-CFG-3** — *Given* configs are loaded, *When* code requests one, *Then* it is returned through a typed accessor (existing pattern: `LoadConfig`, `GetCurrency`, `GetItem`, …) and cached.

### K5 — Deterministic shared clock & daily seed  (`ServerClockService`)

- **FR-CLOCK-1** — *Given* the server clock, *When* `ServerClockService:GetServerDayNumber()` is called on any server at the same wall‑clock day, *Then* it returns the same integer (UTC day index) regardless of which server.
- **FR-CLOCK-2** — *Given* a day number `d` and a salt string, *When* `ServerClockService:GetDailySeed(salt)` is called, *Then* it returns a deterministic seed derived from `d` so daily content (Pet‑of‑the‑Day, daily gift, lucky day) is identical across all servers without messaging.
- **FR-CLOCK-3** — *Given* a duration, *When* `CreateExpirationTime(duration)` / `HasExpired(ts)` are used, *Then* effect expiry is computed from server time (existing behavior) — clients never decide expiry.

### K6 — Currency source/sink ledger  (`EconomyService` + `DataService`)

- **FR-LEDGER-1** — *Given* any currency mutation, *When* it is applied, *Then* it MUST be tagged with a `source` (e.g. `breakable`, `egg_refund`, `daily_gift`, `rebirth_reset`, `gamepass`) and a sign (source vs sink).
- **FR-LEDGER-2** — *When* tagged mutations occur, *Then* aggregate source/sink totals are queryable (admin + analytics) so the economy is balanced from data, not intuition.

### K7 — Feature flags  (`configs/game.lua`)

- **FR-FLAG-1** — *Given* a major system declares a flag (e.g. `features.rebirths = false`), *When* the game boots, *Then* the system's service is not registered/started and its network bridges are inert.
- **FR-FLAG-2** — *Given* a feature is flagged off, *When* the game runs, *Then* no errors are produced by its absence (other systems degrade gracefully / hide UI).

### K8 — Map Integration Contract (Studio ↔ config binding)  (`WorldBindingService` + `configs/markers.lua`)

The seam between an art‑directed, hand‑built map and deterministic, config‑driven systems. The map is free to look like anything; the systems bind to **stable hooks** the map exposes — never to coordinates or fragile visual model names. This lets the world be rebuilt freely while the game stays mechanically deterministic and testable.

**Ownership split (the whole point):**

| Rojo owns (text, source‑controlled) | World Builder owns (in the place) |
|-------------------------------------|-----------------------------------|
| `configs/areas.lua`, `configs/breakables.lua`, `configs/eggs.lua`, `configs/pets.lua`, `configs/markers.lua` | terrain / islands / decorations |
| spawn logic, rewards, economy | exact placement & visual polish |
| UI, networking, data contracts | invisible spawn volumes (zones) |
| admin/testing tools | portals / signs / stands / podiums |
| validation warnings/errors | named attachment points |

**The convention (how a hook is expressed in the map):**
- **Containers** — a model/folder named by convention, e.g. `CrystalSpawnZone_SpawnIsland`.
- **Tags** — invisible parts tagged via CollectionService, e.g. `Zone` (world/island/area grouping, with a `Kind` attribute), `AreaZone` (= `Zone` with `Kind="area"`), `SpawnZone`, `TeleportPad`, `Portal`.
- **Attributes** — the binding payload on the tagged instance, e.g. `ZoneId`/`AreaId`, `ParentZoneId`, `Kind`, `SpawnerId = "spawn_crystals"`, `DepthOffset = -1.25`, `TargetZoneId = "desert"`.
- **Child markers** — named anchor points inside a container, e.g. `EggStand_Basic`, `Portal_Desert`, `PetDisplay_Podium`.

At boot, `WorldBindingService` scans the loaded Workspace, validates the discovered hooks against config, raises clear errors for anything missing/invalid, and hands each owning service its bound instances. Code and config store *bindings* (AreaId / SpawnerId / tag), never positions.

**The five contract rules (canonical):**
1. **C1** — Every gameplay area has a stable `AreaId`.
2. **C2** — Every gameplay object in the map is discoverable by **tag, name, or attribute** (in that order of preference; tags first).
3. **C3** — Scripts never depend on fragile visual model names *unless that name is explicitly part of the contract* (a declared child‑marker name like `PetDisplay_Podium`).
4. **C4** — The game validates map hooks at **server startup** and reports missing/invalid pieces precisely.
5. **C5** — Designers add a new area by placing tagged invisible zones + editing config — **no core‑code changes.**

**Requirements:**
- **FR-MAP-1** — *Given* `configs/markers.lua` declares each tag, its required attributes, and the config table each attribute references, *When* the game boots, *Then* `WorldBindingService` enumerates every instance carrying that tag and binds it to its referenced config entry (satisfies C2).
- **FR-MAP-2** — *Given* a hook is missing a required tag/attribute, or an attribute references a non‑existent config entry (e.g. `SpawnerId = "spawn_crystals"` with no such breakable spawner, or `AreaId` not in `areas.lua`), *When* startup validation runs, *Then* the server reports a precise error — instance full name, tag, offending attribute, expected vs actual — and refuses to boot the affected system rather than failing later (satisfies C4, and K4 for the map).
- **FR-MAP-3** — *Given* an `AreaZone` invisible volume with an `AreaId`, *When* a player enters/exits it, *Then* `WorldBindingService` raises centralized enter/exit events keyed by `AreaId` that area/teleport/event/economy systems subscribe to — zone detection is implemented once, not per feature (satisfies C1).
- **FR-MAP-4** — *Given* a service needs a world location (spawn volume, podium, portal, stand), *When* it initializes, *Then* it requests bound hooks from `WorldBindingService` by tag/attribute/contracted‑name and MUST NOT use hardcoded instance paths, positions, or fragile model names (satisfies C3; this is precisely the rule the reference game's `PetOfTheDay` podium and Workspace‑NumberValue state violate).
- **FR-MAP-5** — *Given* a world builder adds, moves, art‑directs, or fully rebuilds the map, *When* the hooks keep their contracted tags/attributes/names, *Then* behavior is unchanged with **zero** edits to `src/` (and config changes only when introducing genuinely new content the hook references) — satisfies C5.
- **FR-MAP-6** — *Given* hooks are authored in Studio (not Rojo‑managed text), *When* Rojo syncs, *Then* `default.project.json` MUST be scoped so Rojo does not delete or overwrite Workspace geometry or markers; the map lives on the Studio side of the boundary and is *validated, not generated,* by code.
- **FR-MAP-7** — *Given* spawn volumes carry placement attributes (e.g. `DepthOffset`, density, max‑count overrides), *When* a spawner binds to a zone, *Then* per‑instance attributes refine the config defaults for that zone (config = behavior; attributes = local placement tuning) — and over‑broad attribute overrides are themselves validated against config‑declared bounds.
- **FR-MAP-8** — *Given* the template ships, *When* a developer needs a starting point, *Then* a documented **reference map** with one correctly‑authored example of each hook (a tagged `SpawnZone`, an `AreaZone`, a `TeleportPad`, an `EggStand_Basic`, a `PetDisplay_Podium`) is provided so the authoring workflow is copyable, plus a tag/attribute reference table in `docs/`.

**Synthetic / fallback map (test without a world):** the marker contract works in reverse for testing — if no authored map exists, the game fabricates one from config so it runs on a bare baseplate. This removes the slow "edit → Rojo apply → re‑apply for a tiny change" loop and gives automated tests a deterministic substrate.

- **FR-MAP-9** — *Given* the game starts, *When* `WorldBindingService` detects no authored map (no contracted hooks present — e.g. no designated `MapRoot` / no `AreaZone` / no `SpawnZone`), *Then* it generates a **synthetic baseplate map** from config: it fabricates the required area zones, spawn volumes, egg stands, teleport pads, and podium as correctly tagged/attributed instances at deterministic baseplate offsets, so every config‑driven system binds and runs with no hand‑built geometry.
- **FR-MAP-10** — *Given* a synthetic map is generated, *When* feature services bind, *Then* they use the **same** `WorldBindingService` API and the **same** contract as for an authored map — there MUST be no `if testMode` branching in feature code. The only difference between baseplate and shipped world is *who created the hooks*, which guarantees behavior tested on the baseplate matches the authored world.
- **FR-MAP-11** — *Given* `configs/game.lua` declares a map mode (`auto` | `authored` | `synthetic`), *When* set to `auto` (default), *Then* an authored map is used if present and the synthetic map otherwise. `synthetic` forces the baseplate (fast iteration + CI); `authored` forces the real map and fails loud if hooks are missing (shipping safety, ties to C4/FR-MAP-2).
- **FR-MAP-12** — *Given* the synthetic builder fabricates hooks, *When* it runs, *Then* its output MUST itself satisfy FR-MAP-2 validation (the generated map is a valid map), so the synthetic path can never mask a contract bug.
- **FR-MAP-13** — *Given* an authored map provides **some but not all** areas declared in `areas.lua` (e.g. an island map with 2 of 5 areas built), *When* `WorldBindingService` runs in `auto` mode, *Then* it synthesizes only the **missing** areas per‑`AreaId` — each with its child hooks (spawn volumes, egg stands, pads) — places them at deterministic baseplate offsets, and wires `TeleportPad`s between authored and synthetic areas so the full multi‑area progression and teleport loop is testable from a partial map. (`authored` mode instead fails loud on any missing area; `synthetic` mode ignores authored geometry entirely.)
- **FR-MAP-14** — *Given* a mixed authored/synthetic map, *When* a player teleports from an authored area to a synthesized one (or back), *Then* the teleport, spawning, rewards, and zone events behave identically to a fully‑authored map — the only difference is visual/artistic polish, never mechanics.
- **FR-MAP-15** — *Given* a multi‑level zone hierarchy declared in config (worlds → islands → areas), *When* synthesis runs (FR-MAP-9/13), *Then* it fabricates the **full hierarchy** for any missing zones — grouping zones and their child areas — at deterministic baseplate offsets, and wires `Portal`s between worlds/islands and `TeleportPad`s between areas, so the entire expandable structure (including cross‑world travel and cascading unlocks) is testable without authored art.
- **FR-MAP-16** — *Given* P10's active‑zone activation, *When* running on either an authored or synthetic map, *Then* zone activation/dormancy behaves identically, so performance characteristics of the expansion model are observable in baseplate testing.

---

## 4. Cross‑cutting requirements

- **FR-X-AUTH-1** — Every `client_to_server` packet MUST be validated server‑side (type + range + ownership) before any state change. Client‑supplied currency amounts, prices, or pet IDs are treated as untrusted.
- **FR-X-RATE-1** — Every mutating packet MUST declare a `rateLimit` in `network.lua` and be enforced by `RateLimitService`.
- **FR-X-NET-1** — New client/server communication MUST be added as `network.lua` bridge/packet entries with a `handler = "Service.Method"`; no manually created RemoteEvents.
- **FR-X-OBS-1** — Services MUST log through `Logger` at appropriate levels; no bare `print`. State that other systems consume MUST be observable (signal/Reflex), not scraped from Workspace values.
- **FR-X-AUTH-2** — Authority‑sensitive features (trade, marketplace, admin grants) MUST be server‑only modules and MUST NOT trust replicated client state.

---

## 5. Functional requirements by domain

### 5.1 Core economy loop  (`breakables → currencies → eggs → pets → stronger breakables`)

- **FR-LOOP-1** — *Given* a breakable defined in `configs/breakables.lua` with health and reward, *When* a player depletes its health, *Then* the configured currency reward is granted **through K2 (resolved)** and **K6 (tagged)**, and relevant K1 counters (`breakables_broken`, `coins_earned_lifetime`) increment.
- **FR-LOOP-2** — *Given* an egg in `configs/eggs.lua` with a cost/currency and hatch odds, *When* a player can afford it and hatches, *Then* currency is deducted (resolved+tagged), a pet is rolled using odds modified by resolved luck (K2), the pet is added to inventory, and `eggs_hatched` increments.
- **FR-LOOP-3** — *Given* equipped pets with stats, *When* a player attacks a breakable, *Then* damage/reward output is the **resolved** combination of pet stats + enchants + upgrades + boosts + events (K2).
- **FR-LOOP-4** — *Given* stronger breakables gated behind currency thresholds or areas, *When* a player meets the gate, *Then* the stronger breakables become available (see 5.2).

### 5.2 Zone hierarchy, unlocks & travel  (`configs/areas.lua` — NEW; binds via K8)

> Gap: no `areas` config exists yet. This is "core" and must be added. Zones are the backbone of the Map Integration Contract — every zone has a stable id (contract rule C1).

**Hierarchy & expandability.** The map is a tree of zones declared in config, each entry `{ id, kind = "world" | "island" | "area", parent = <id?>, unlock = {...} }`. `world` and `island` are grouping zones; `area` is the leaf gameplay surface that hosts spawners/eggs/pads. Depth is arbitrary (a world holds islands; an island holds areas; nothing stops a deeper nesting), so the game is config‑expandable without bound.

- **FR-ZONE-1** — *Given* zones declared with `kind` + `parent`, *When* loaded, *Then* a valid zone tree is built (no orphans, no cycles); leaf `area` zones carry gameplay, grouping zones carry unlocks/boosts.
- **FR-ZONE-2** — *Given* a developer wants to expand the game, *When* they add a new world/island/area entry to config and place its tagged markers in the map (or rely on synthetic fallback), *Then* it works with **zero** core‑code changes (C5 applied at every level).
- **FR-ZONE-3** — *Given* a progression graph (which zone unlocks gate which), *When* a player unlocks a parent zone, *Then* child zones become reachable per config; unlock state persists in `GameData.UnlockedAreas` keyed by zone id.
- **FR-ZONE-4** — *Given* P10, *When* a player is in a zone, *Then* only that zone's active subtree runs spawners/effects; entering/teleporting activates the destination subtree and dormants the previous one. Runtime cost MUST scale with active zones, not total declared zones.
- **FR-ZONE-5** — *Given* travel hooks, *When* a player uses a `Portal` (between worlds/islands) or `TeleportPad` (between areas) bound by marker with a `TargetZoneId`, *Then* the server validates the unlock and relocates the player to the bound destination zone's spawn — never a hardcoded coordinate.

Areas (the `kind = "area"` leaves) additionally satisfy:

- **FR-AREA-1** — *Given* an area defined in `configs/areas.lua` with an `AreaId`, `unlock_cost`, `required_currency`, optional `required_area`, and `boosts`, *When* a player pays the cost and meets prerequisites, *Then* the area unlocks, persists in the profile (`GameData.UnlockedAreas`), and its boosts enter K2 as a stage/context contribution.
- **FR-AREA-2** — *Given* an area's geometry is bound by an `AreaZone` marker carrying the matching `AreaId` (K8) and a `TeleportPad` with `TargetZoneId`, *When* a player on an unlocked area requests teleport, *Then* the server validates the unlock and relocates the player to the bound spawn region — never to a hardcoded coordinate.
- **FR-AREA-3** — *Given* a locked area, *When* a player attempts entry (zone enter event, FR-MAP-3) or teleport, *Then* the server denies it (authority) and the client shows the unlock requirement from config.
- **FR-AREA-4** — *Given* an `AreaId` exists in `configs/areas.lua` but no `AreaZone` marker carries it (or vice‑versa), *When* startup validation runs, *Then* the mismatch fails loud (C4 / FR-MAP-2).

### 5.3 Eggs & hatching

- **FR-EGG-1** — *Given* hatch odds + secret odds in config, *When* hatching, *Then* the roll respects resolved luck and resolved secret‑luck (K2) and the outcome distribution matches config over large N (testable).
- **FR-EGG-2** — *Given* a secret/huge outcome, *When* it is rolled, *Then* the pet is flagged special, an announcement is emitted, and (if enabled) a serial number is assigned (see 5.14).
- **FR-EGG-3** — *Given* an auto‑delete filter (5.9), *When* a pet is hatched that matches the delete filter, *Then* it is not added to active inventory (or is auto‑deleted) per the player's configured rule.

### 5.4 Pets: stats, equip & storage limits, upgrades

- **FR-PET-1** — *Given* equip‑limit and storage‑limit values in config with upgrade paths, *When* a player equips/stores pets, *Then* the server enforces current limits and rejects over‑limit actions.
- **FR-PET-2** — *Given* a storage/equip upgrade purchased (5.8), *When* applied, *Then* the limit increases per config and persists.
- **FR-PET-3** — *Given* equipped pets, *When* computing output, *Then* per‑pet contributions enter K2 as the `pet_stats` and `enchants` stages.

### 5.5 Enchants  (`configs/enchants.lua`)

> Port the reference data shape (tier → weighted `Chances` with value range + `Scale`); add the missing *effect* layer.

- **FR-ENCH-1** — *Given* an enchantable pet tier with weighted enchant chances, *When* a pet is enchanted, *Then* enchants are rolled from config weights up to the tier's `MaxEnchant` and stored on the pet instance in the profile.
- **FR-ENCH-2** — *Given* an enchant (HomeWorld, Efficiency, Tactics, Luck, Leadership, SecretLuck) maps to a declared modifier, *When* output is resolved, *Then* the enchant contributes through the K2 `enchants` stage — enchants are pipeline inputs, never bespoke multipliers.
- **FR-ENCH-3** — *Given* an enchant has no declared effect mapping, *When* validating config, *Then* boot fails (K4) — every enchant must resolve to a real modifier.

### 5.6 Achievements  (`configs/achievements.lua` — view over K1)

- **FR-ACH-1** — *Given* an achievement declares `{ stat, tiers = [{goal, reward}], reward_type }`, *When* the underlying K1 counter crosses a tier goal, *Then* the tier is marked complete and the reward is granted (resolved+tagged) exactly once.
- **FR-ACH-2** — *Given* progress, *When* the player opens the achievements UI, *Then* progress is read from K1 counters (no separate achievement‑only tracking).
- **FR-ACH-3** — *Given* a new achievement, *When* added to config, *Then* it requires **no** new service code (pure config), assuming its stat already exists in K1.

### 5.7 Leaderboards  (`configs/leaderboards.lua` — view over K1)

- **FR-LB-1** — *Given* a leaderboard declares a K1 counter and a sort order, *When* displayed, *Then* it ranks players by that counter.
- **FR-LB-2** — *Given* a global/cross‑server leaderboard, *When* updated, *Then* it uses an OrderedDataStore (durable) refreshed on an interval; live servers never block on it.

### 5.8 Upgrades  (`configs/upgrades.lua`)

- **FR-UPG-1** — *Given* purchasable upgrades for click value / reward / luck / storage / equip with cost curves in config, *When* purchased, *Then* the level persists and the effect enters K2 as the `permanent_upgrades` stage (or limit changes for storage/equip).
- **FR-UPG-2** — *Given* a cost curve, *When* a player buys the next level, *Then* the price follows the configured curve (no hardcoded growth).

### 5.9 Auto‑target modes & auto‑delete filters

- **FR-AUTO-1** — *Given* auto‑target modes (nearest, highest value, weakest, strongest, selected currency), *When* a player selects one, *Then* `AutoTargetService` selects targets accordingly and the choice persists.
- **FR-AUTO-2** — *Given* auto‑delete filters by rarity/type, *When* configured by a player, *Then* matching hatched pets are filtered per FR-EGG-3. Filters are player settings validated against config‑declared rarities/types.

### 5.10 Rebirths  (`configs/rebirths.lua`)

- **FR-REB-1** — *Given* a rebirth requirement (e.g. currency threshold), *When* a player rebirths, *Then* the configured economy layer resets, the configured permanent currency/boost is granted, the `rebirths` counter increments, and the reset is tagged in the ledger (K6).
- **FR-REB-2** — *Given* a rebirth level, *When* output is resolved, *Then* the rebirth bonus enters K2 as the `rebirth` stage.
- **FR-REB-3** — *Given* a rebirth, *When* it executes, *Then* it is transactional — a mid‑operation failure MUST NOT both reset progress and fail to grant the reward.

### 5.11 Pet index / collection rewards  (`configs/pet_index.lua` — view over K1)

- **FR-IDX-1** — *Given* a pet is obtained for the first time, *When* added, *Then* it is recorded in a distinct‑pets index in the profile and `distinct_pets` (K1) increments.
- **FR-IDX-2** — *Given* index milestones with rewards, *When* a milestone count is reached, *Then* the reward is granted once.

### 5.12 Global events & scheduled luck days  (extend existing `configs/events.lua` + `EventService`)

> Foundation already exists (modifier composition + stacking). Add scheduling + determinism.

- **FR-EVT-1** — *Given* global events declare modifiers + duration + stacking (existing), *When* active, *Then* their modifiers enter K2 as the `active_events` stage (replacing direct `GlobalEffectsService` reads in `EconomyService`).
- **FR-EVT-2** — *Given* a scheduled event (e.g. "Lucky Day") declares a recurrence, *When* the shared day/seed (K5) matches, *Then* the event activates identically on every server with no cross‑server coordination.
- **FR-EVT-3** — *Given* an admin triggers an event manually, *When* triggered, *Then* it activates and (optionally) publishes a cross‑server nudge — the nudge refreshes peers but is not the source of truth.

### 5.13 Pet of the Day  (`PetOfTheDayService` + `configs/pet_of_the_day.lua`)

> Keep the reference's clever determinism; drop its Workspace‑NumberValue implementation.

- **FR-POTD-1** — *Given* an eligibility filter in config (e.g. rarity ∈ {Secret, Exclusive, Huge}), *When* the day rolls over, *Then* the selected pet is derived from `GetDailySeed` (K5) so all servers show the same pet.
- **FR-POTD-2** — *Given* a Pet of the Day, *When* output is resolved for that pet, *Then* its temporary multiplier enters K2 as the `pet_of_the_day` stage.
- **FR-POTD-3** — *Given* a podium display, *When* the day's pet is chosen, *Then* the display is driven from config/asset ids, not hardcoded instance paths.

### 5.14 Secret / huge pet handling

- **FR-SEC-1** — *Given* a secret/huge pet is obtained, *When* granted, *Then* a server‑wide announcement is emitted and a monotonic serial number is assigned and stored.
- **FR-SEC-2** — *Given* serials, *When* assigned, *Then* allocation is authoritative and collision‑free across servers (durable counter).

### 5.15 Daily rewards / codes / gifts  (`configs/rewards.lua`)

- **FR-RWD-1** — *Given* a daily reward track in config, *When* a player claims on a new day (K5), *Then* the reward is granted once per day and the streak advances/resets per config.
- **FR-RWD-2** — *Given* redeemable codes in config (value + per‑player one‑time), *When* redeemed, *Then* the server validates uniqueness per player and grants the reward (resolved+tagged).
- **FR-RWD-3** — *Given* codes/gifts, *When* used, *Then* they exist to test economy pacing without manual admin grants (explicit design goal).

### 5.16 Rare / dark breakable variants  (extend `configs/breakables.lua`)

- **FR-RARE-1** — *Given* rare variant breakables with very low spawn weight and high HP/value, *When* spawn tables roll, *Then* variants appear at configured rarity and reward through K2/K6.

### 5.17 Seasonal chaseables  (`configs/chaseables.lua`)

- **FR-CHASE-1** — *Given* a seasonal chaseable (temporary spawner awarding event currency) gated by date/event window, *When* the window is active (K5), *Then* it spawns in the configured area and rewards event currency; outside the window it does not spawn.

### 5.18 Limited stock pets / items  (`configs/stock.lua`)

- **FR-STOCK-1** — *Given* a server‑wide (or global) limited stock with countdown, *When* players purchase, *Then* remaining stock decrements authoritatively and reaching zero blocks further purchase until restock.
- **FR-STOCK-2** — *Given* global stock, *When* shared across servers, *Then* it uses MemoryStore for live count + MessagingService for nudges; a single server crash MUST NOT corrupt the shared count.

### 5.19 Marketplace / pet exchange  (deferred — Roblox‑native)

> Defer until the economy is stable. Do **not** port the reference's external‑DB (Robase/Firebase) + Discord‑webhook approach; treat it as inspiration only.

- **FR-MKT-1** — *Given* a player lists a pet with a min bid + duration, *When* listed, *Then* the pet is escrowed (removed from usable inventory) and the listing is written to durable global storage (DataStore) with a live index (MemoryStore).
- **FR-MKT-2** — *Given* a listing, *When* a player on any server bids above the current bid, *Then* the bid is accepted authoritatively, the previous high bidder is refunded, and peers are nudged via MessagingService.
- **FR-MKT-3** — *Given* a listing expires (K5/server time), *When* it resolves, *Then* the winner claims the pet and the seller claims the proceeds; if no bids, the pet returns from escrow to the seller.
- **FR-MKT-4** — *Given* the abuse surface, *When* any exchange action occurs, *Then* it MUST pass rate limits, ownership checks, and anti‑duplication guarantees (escrow is the single source of truth; no path duplicates a pet).

### 5.20 Monetization (deferred polish)

- **FR-MON-1** — *Given* gamepasses/products in `configs/monetization.lua`, *When* a purchase is processed, *Then* its benefit enters K2 as the `gamepass` stage and/or grants tagged currency. Defer until the base loop feels good.

---

## 6. Non‑functional requirements

- **NFR-PERF-1** — Per‑frame work (spawning, auto‑target, event expiry) MUST scale with active content, not total config size; no per‑frame full‑config scans.
- **NFR-PERF-2** — Resolution (K2) for a single payout MUST be O(stages) and allocation‑light on the hot path.
- **NFR-PERF-3** — Runtime cost MUST scale with the player's **active** zone subtree, not the total number of declared zones (P10/FR-ZONE-4). Adding worlds/islands to config MUST NOT increase per‑frame cost for players elsewhere — this is what makes "infinitely expandable" safe.
- **NFR-DATA-1** — No gameplay state of record lives in Workspace `Value` objects; Workspace is presentation. State of record is the profile (durable) or an explicit in‑memory authoritative store.
- **NFR-TEST-1** — K1, K2, K3, K4, K8 MUST have TestEZ unit coverage. Odds (FR-EGG-1) MUST have a statistical test. Manual test scripts live in `tests/manual/`.
- **NFR-TEST-2** — The synthetic map (FR-MAP-9..12) MUST allow the full economy loop to be exercised on a bare baseplate with no authored geometry, both in‑Studio (fast iteration, no Rojo re‑apply for small changes) and in automated runs.
- **NFR-BAL-1** — The ledger (K6) and pipeline breakdown (FR-PIPE-5) MUST be sufficient to answer "where did this number come from?" for any payout.

---

## 7. Data ownership map

| Concern | Lives in | Notes |
|---------|----------|-------|
| Content & tuning | `configs/*.lua` | Designer‑editable; validated at boot (K4). |
| Per‑player state of record | ProfileStore profile | Versioned + migrated (K3). Currencies, inventory, equipped, unlocks, upgrades, enchants, counters, index, settings. |
| Derived values | computed via K2 at use time | Never stored as the source of truth; cache only with explicit invalidation. |
| Shared time / daily selection | `ServerClockService` (K5) | Deterministic; cross‑server consistent. |
| Live cross‑server counts (stock, listings) | MemoryStore + DataStore | MessagingService = nudge only (P4). |
| Map hooks (zones, spawn volumes, pads, stands, podium) | Studio instances: CollectionService tags + attributes + contracted names (K8) | World Builder owns; code *validates*, never generates (except the synthetic fallback). |
| Synthetic baseplate map | generated at runtime by `WorldBindingService` from config | Only when no authored map present; satisfies the same contract. |
| Presentation | Workspace / UI | Driven from config + replicated state; holds no state of record. |

---

## 8. Open questions (resolve before/while implementing)

1. **Idle/offline progression:** does the template assume offline earnings? This affects K3 (save), K2 (resolution at login), and economy math. Decide before Phase 1.
2. **Soft vs premium currency count at template baseline:** recommend shipping 2 (soft + premium); additional currencies are pure config adds (P1) with no currency‑specific service.
3. **Enchant effect magnitudes:** the reference stores `Scale`/value ranges but the *effect semantics* live in code there. We must define each enchant's modifier mapping (FR-ENCH-2) as config.
4. **Trade vs marketplace:** is direct player‑to‑player trade in scope, or only the auction‑style marketplace? Both share escrow/anti‑dupe requirements (FR-MKT-4).
