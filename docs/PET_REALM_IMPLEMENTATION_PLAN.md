# Pet Realm — Implementation Plan

**Status:** Draft v1 (planning only — no game code written yet)
**Source of truth:** `DESIGN_DOCUMENT.md` + `GWT_ACCEPTANCE_SPEC.md` (currently in `~/Downloads/game_idea_files/`; to be copied into `docs/` when work starts)
**Repo strategy:** This repo *becomes* the game (Pet Realm). Template/prototype separation is preserved by discipline, not by a separate fork. Tag `template-base` before game content lands.

This plan turns the design doc + Gherkin acceptance spec into an ordered, test-driven build. It is organized as:

1. Principles
2. Test strategy & infrastructure (incl. Studio access)
3. The feedback-loop ladder
4. Phased roadmap (Phase 0 → Phase 6)
5. Per-phase detail with GWT test mapping
6. Studio-access decisions to confirm
7. Open design questions

---

## 1. Principles

- **Config-as-code, never hardcode.** Biome order, deltas, multipliers, costs, cooldown tiers, curves all live in `configs/*.lua`. Service code reads data; it never assumes a fixed ring, theme, or value. (Enforced by spec scenarios like "Adding a biome to config does not require service code changes".)
- **Identity vs. state.** Pet records store identity + mutable state only. Power is *always* computed at runtime through the modifier pipeline, never persisted. (Existing RBX-Template rule; extended, not changed.)
- **`[TEMPLATE]` vs `[PROTOTYPE]`.** Generic mechanics go in core services + new config schemas; heaven/hell specifics go in prototype config values. Keep them separable.
- **Test early, test often.** Every `[required]` scenario in the GWT spec maps to a test. Pure logic gets a fast headless/unit test; cross-service behavior gets a Studio smoke. Write the test alongside (ideally before) the implementation.
- **Pure logic at the core.** The foundation mechanics (adjacency, Soul, stack pool, power formula) are authored as **Roblox-API-free modules that take injected config tables**. This is both a design requirement and what makes fast testing possible.

---

## 2. Test Strategy & Infrastructure

### 2.1 The three test levels (from the GWT spec)

- **`[unit]`** — pure logic, no Roblox services. Target: `tests/unit/*.spec.lua` (TestEZ) and, if we add a headless runner, runnable outside Studio.
- **`[integration]`** — ProfileStore, modifier pipeline, multiple services. Target: `tests/integration/*.spec.lua` (dir does not exist yet — `TestBootstrap` already references it; create it) and/or Studio smoke via `StudioSmokeTestService`.
- **`[studio]`** — real player/world state. Target: `tests/studio/*.lua` runners following the existing `Phase*Smoke` pattern (`runText({...})` pasted into the Studio command bar, backed by a `StudioSmokeTestService` bridge that asserts and **restores profile state**).

### 2.2 Current reality: tests run *inside Studio*

`mise test` resolves to "Run `tests/TestBootstrap.lua` in Roblox Studio." `TestBootstrap` loads TestEZ from `Packages` and runs specs against the live DataModel. There is **no headless Lua VM** in the toolchain today. Consequences:

- The only feedback I can produce *without Studio* is: `rojo build` (compile), `selene` (lint), `stylua --check` (format).
- All behavioral tests (`[unit]` TestEZ + `[studio]` smokes) require Studio open with the synced place.

### 2.3 Recommended infra investment: a headless `[unit]` runner

Add **lune** (standalone Luau runtime) + a thin spec shim so pure-logic modules run in milliseconds in CI/locally with zero Studio. This is viable *only* because the foundation modules are authored API-free (Principle 5). Scope:

- New modules under `src/Shared/...` (e.g. `RingTopology`, `SoulMath`, `StackPool`, `PowerFormula`) take plain config tables, return plain values.
- A `lune` script discovers `*.purespec.lua` (or reuses TestEZ via a compatibility shim) and runs them headless.
- TestEZ-in-Studio remains the canonical runner for anything touching Roblox APIs.

**Decision needed (see §6):** invest in lune now (fast loop for all of Phase 0–1 math) vs. defer and rely on Studio for everything.

### 2.4 Studio access for the agent

- **Preferred: Roblox Studio MCP.** The wiki (`STUDIO_WORKFLOW.md`) documents it: list/select instances, capture screen, `get_console_output`, start/stop play, inspect tree, **execute Luau**, edit scripts. It is currently registered for **Codex**, not this Claude Code harness. To let the agent run tests autonomously, wire the same MCP server into this harness.
- **Not recommended: computer use.** This harness only has browser automation (Chrome/Preview MCP), not desktop control of the Studio app. MCP supersedes it.
- **Always** confirm the active Studio instance is `RBX-Template` before mutating live state (wiki rule).

### 2.5 Profile-safe smoke pattern (reuse)

New `[studio]`/`[integration]` smokes follow the established contract: a `StudioSmokeTestService` handler invoked via the `StudioSmokeTest` RemoteFunction, which sets temporary state, exercises the real code path, asserts, and **restores the player's original profile** (currency, pets, unlocks). Every new smoke must restore.

---

## 3. The Feedback-Loop Ladder

Run cheapest → most expensive on every change:

1. **`rojo build --output /tmp/petrealm.rbxl`** — compiles; catches syntax/structure. (headless, seconds)
2. **`selene --allow-warnings src configs tests`** — lint. (headless)
3. **`stylua --check src configs tests`** — format. (headless)
4. **Headless `[unit]`** (if lune adopted) — pure-logic specs. (headless, ms)
5. **TestEZ `[unit]`/`[integration]` in Studio** — `TestBootstrap`. (Studio)
6. **`[studio]` smokes** — `runText({...})` in command bar. (Studio)

CLI invocations use mise shims when not on PATH, e.g. `/Users/jason/.local/share/mise/shims/rojo`.

---

## 4. Phased Roadmap

Ordering follows the design doc's own guidance (ship Heaven first; Hell is the expensive new-systems v2) and the dependency graph. Each phase ends with a green test bar at its applicable levels + a wiki `LOG.md` entry.

| Phase | Theme | Features (GWT) | Net-new vs. extends | Test weight |
|---|---|---|---|---|
| 0 | Data spine | Ring topology (1), Soul stat (2), Themed currencies (4) | mostly config + light services | heavy `[unit]` |
| 1 | Pets & power | Element-at-hatch (5), Power calc providers (6) | extends EggService + ModifierPipeline | `[unit]` + `[integration]` |
| 2 | Heaven slice | Layers & portals (3), Heaven farming (11) | extends portal/travel + breakables | `[integration]` + `[studio]` |
| 3 | Pet party core | Spirit form (7), Stack pool (8), Active squad (9) | new services | `[unit]` + `[studio]` |
| 4 | Combat | Combat (10), Player/Focus (12) | new `CombatService`, `FocusService` | `[studio]` |
| 5 | Build depth | Archetypes (13), Powers (14), Augments (15), Hotbar (16), Rosters (17) | new services + progression config | mixed |
| 6 | Social/endgame | Multiplayer (18), Trade (19), Fusion (20), Chaos Rifts | extends party/trade | `[integration]` + `[studio]` |

A **playable vertical slice** exists at the end of Phase 2: walk the ring → conquer biomes → Soul shifts (HUD) → ascend via portal → farm scaled rewards with element-tagged pets.

---

## 5. Per-Phase Detail

### Phase 0 — Data Spine

**Goal:** the config-driven world model + alignment + currencies, almost entirely pure and unit-tested.

**0.1 Ring Topology (Feature 1)**
- Config: extend/author `configs/areas.lua` with explicit clockwise biome order + per-biome `theme` + `dichotomy` partner. Prototype order: `[earth, ice, lava, desert, beach]`; dichotomies `earth↔desert`, `ice↔lava`.
- Module: `src/Shared/.../RingTopology.lua` (pure): `clockwiseNeighbor(id)`, `counterclockwiseNeighbor(id)` (wraps), `theme(id)`, `dichotomyPartner(id)` (nil if none).
- Tests (`[unit]`): clockwise/counterclockwise/wrap neighbor, theme is config-driven, dichotomy lookup incl. nil. `[integration]`: adding a 6th biome requires no service change.

**0.2 Soul Stat (Feature 2)**
- Persistence: add `soul` (signed int, range from config, default 0) and `last_conquered_biome` (nil) to the ProfileStore schema via `DataService`/`configs` profile template.
- Service: `AlignmentService` with pure core `SoulMath.applyConquest(state, conqueredBiome, topology, config) -> newState` (delta from clockwise/counterclockwise/non-adjacent, cap to `[-100,100]`, first-conquest no-op, re-conquest no-op).
- Config: `soul_delta_per_conquest` (default 5), `soul_range`.
- Tests (`[unit]`): initial 0, clockwise +5, counterclockwise −5, non-adjacent no change, first conquest no-op, re-conquest no-op, upper/lower cap, config-driven delta. `[integration]`: persists across sessions. `[studio]`: HUD reflects value + notification (deferred to when HUD exists; stub the service event now).

**0.3 Themed Currencies (Feature 4)**
- Config: `configs/currencies.lua` — add `earth_coins/desert_coins/ice_coins/lava_coins`, `light_tokens`, `shadow_tokens`; mark all non-tradeable; layer reward multipliers table.
- Service: extend `EconomyService` reward resolution to pick currency by current biome theme and apply layer multiplier.
- Tests (`[integration]`): biome breakable drops themed coin; Heaven/Hell multiplier (same currency, no "blessed/cursed" variant); per-biome currency isolation; non-tradeable enforcement (server reject + log); Light tokens only in Heaven, Shadow only in Hell.

**Exit:** all Phase-0 `[unit]` green (headless if lune adopted; else Studio TestEZ); `rojo build`/lint/format clean.

---

### Phase 1 — Pets & Power

**1.1 Element-at-hatch (Feature 5)** — *fold into in-flight egg work.*
- Pet record: add `element` field (`neutral|light|shadow|chaotic`).
- `EggService`/`PetGrantService`: assign element from current layer at hatch (base→neutral, Heaven→light, Hell→shadow; chaotic only via fusion).
- Stacking: element is **not** a stack-key axis in the realized content model. Realm eggs hatch distinct pet IDs/species (base, Heaven, and Hell pets are separate catalog entries), so stack identity remains pet id + variant (+ stack enchant where configured).
- Tests (`[integration]`): hatch in base/Heaven/Hell → correct element; element immutable except fusion (`[unit]`); realm eggs resolve to their realm-specific pet IDs; variant remains independent of element (`[unit]`).

**1.2 Power Calc Providers (Feature 6)**
- Module: `PowerFormula` (pure) composing base × variant × level × enchant × element × theme-utility × stack × buffs (execution order per design §10).
- New providers in `ModifierPipeline`/`ModifierService`: `ElementResonanceProvider` (reads `configs/elements.lua` 3×3 matrix), `ThemeUtilityProvider` (reads `configs/theme_utility.lua`; returns passives, conditional on dichotomy biome).
- Tests (`[unit]`): base from config; variant mult; element mult home/opposing/neutral; chaotic flat; multiplicative stacking (100×2×1.5×1.5=450); power never persisted; theme utility applies only in dichotomy biome. `[studio]`: power recalculates on biome change with no save mutation.

**Exit:** power matches spec arithmetic exactly; provider additions don't regress existing pipeline tests.

---

### Phase 2 — Heaven Vertical Slice

**2.1 Layers & Portals (Feature 3)**
- Config: layer table (y-offset, requires_soul, token_cost) per design §6.2.
- Service: `LayerService` extending existing server-authoritative portal travel; validates Soul threshold + token cost **server-side**; sets `profile.current_layer`.
- World: stacked geometry at Y offsets; tune `StreamingTargetRadius`.
- Tests: base accessible (`[unit]`); reject on low Soul / low tokens (no deduction); successful ascend deducts tokens + sets layer (`[studio]`); can't descend with positive Soul; cross-path visit portal ignores Soul; server re-validates cost (`[integration]`); layer persists across sessions; geometry Y offsets correct (`[studio]`).

**2.2 Heaven Farming (Feature 11)**
- Mostly content scaling on existing breakable/auto-target systems: scaled currency, Light Token drop rate, faster spirit recovery (stub until Phase 3), idle farming.
- Tests (`[integration]`): scaled currency; Light Token drop probability; (deferred `[studio]`: minor encounters; idle farming).

**Exit:** end-to-end Heaven loop demonstrable in Studio.

---

### Phases 3–6 (summarized; detail expanded when reached)

- **Phase 3 — Pet party core:** `SpiritFormService` (`lastDownedAt`, staged degradation, Heaven 2× recharge, instant-recharge consumable, persistence); `StackPoolService` (token-bucket `ready_count`/`last_update`, lazy refill, contribution curves); `ActiveSquadService` (inventory/equipped/active hierarchy, swap cooldown, auto-return on down). Heavy `[unit]` for pool math + `[studio]` for degradation visuals.
- **Phase 4 — Combat:** `CombatService` (spawners, auto-target, loot), `FocusService` (no HP, Focus cost/regen/sundering, invulnerable player). Mostly `[studio]`.
- **Phase 5 — Build depth:** `ArchetypeService`, `PowerService` (level-up selection), `AugmentationService` (slots + set bonuses through pipeline), `HotbarService`, `RosterService`. Mixed levels; lots of `[unit]` for roster injury rules + slot bonuses.
- **Phase 6 — Social/endgame:** party scaling, trade constraints (pets tradeable, currencies not, atomic anti-dup, audit log), Chaotic fusion, Chaos Rifts.

---

## 6. Studio-Access Decisions — RESOLVED & BUILT

Decisions confirmed 2026-05-28. Both infrastructure pieces are in place and verified:

1. **Headless `[unit]` runner (lune): DONE.** `lune 0.10.4` added to `.mise.toml` (`github:lune-org/lune` backend). Harness lives in `tests/headless/`:
   - `run.luau` — runner: discovers `specs/*.spec.luau`, provides a TestEZ-compatible subset (`describe`/`it`/`expect`/`beforeEach`), reports, exits non-zero on failure.
   - `specs/selftest.spec.luau` — proves the loop (delete once Phase 0 specs land).
   - Run with **`mise run test-headless`**. Verified: green→exit 0, red→exit 1 with file:line.
   - `tests/headless/**` is excluded from selene (`selene.toml`) because lune stdlib (`@lune/*`) isn't in the Roblox std. StyLua still formats it.
   - **TODO (Phase 0):** wire relative `require()` of the module-under-test into the runner env so pure `src/Shared` modules can be exercised headless.
2. **Roblox Studio MCP into this harness: CONFIGURED.** `.mcp.json` adds a `Roblox_Studio` stdio server (`/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`). **Requires a Claude Code restart to load**, plus the Studio-side toggle (`Manage MCP Servers → Enable Studio as MCP server`) per `STUDIO_WORKFLOW.md`.
3. **Canonical test command:** TestEZ-in-Studio remains canonical for Roblox-coupled code; lune is for pure modules only.

Working loop now: agent writes pure module + `*.spec.luau` → **`mise run test-headless`** (instant) → `rojo build`/`selene`/`stylua` → Studio TestEZ/smokes (via MCP once restarted, else human-run command bar).

---

## 7. Open Questions (from GWT `[open]` + design)

- Focus-at-zero behavior (instant regen vs. stun window) — Feature 12.
- Respec vs. archetype-change ritual — Features 13/14.
- Augmentation slot tradeability — Feature 19.
- Soul reset/switch policy (permanent vs. costly ritual) — design §4.6 recommends resettable-but-expensive.
- Stack contribution curve choice (linear/sqrt/log) for the prototype.

---

## 8. Immediate Next Actions (when we start coding)

1. `git tag template-base` (insurance snapshot).
2. Copy design doc + GWT spec into `docs/`.
3. Decide §6.1 and §6.2.
4. Begin Phase 0.1 (RingTopology module + `[unit]` specs straight from the Gherkin).
