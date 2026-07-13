# Mission Worldgen — Tile-Kit Contract & Generator Design

**Status:** M1 + M2 + M3 SHIPPED. Pure solver + CI seed sweep (M1); gray-box
kit + TileKitBuilder + MissionStamper (M2); MissionInstanceService lifecycle +
MissionDoor prompts + configs/missions.lua + schemas (M3 — full play-mode
loop live-verified over MCP: door prompt → Open → party teleport → character
walked to the beacon → exit prompt → teardown + return; re-entry minted a
fresh per_attempt seed). M4+ pending. SSOT for the procedural mission-map
system.

**M3 field notes:**
- Exit = a `MissionExitPrompt` on the entrance SpawnPad (CoH: leave through
  the door you came in); it lives inside the container so teardown removes
  it, and only the instance's own team can trigger it.
- **`WorldBindingIgnore` container attribute** (set by MissionStamper,
  honored by WorldBindingService `_bindInstance`): generated mission hooks
  carry `mission:*` area ids and must NEVER be swept as authored map hooks —
  without the gate, a persisted instance HARD-FAILS server boot ("AreaId
  must reference an area zone"). This resolves gap §5.3 #2 at the binder
  level; it was found live when the M2 demo instance leaked into a play
  session's boot.
- MCP verification note: the MCP Server VM is separate from the game VM (no
  `_G.RBXTemplateServices`) — verify through real product surfaces
  (CollectionService-tagged door + ProximityPrompt `InputHoldBegin/End` from
  the Client VM), not service calls.
**Scope:** CoH-style door missions: a door in the authored world leads to a
procedurally generated, **deterministic** (seeded) mission map. The main world
stays 100% human-authored — this system only builds disposable mission
interiors.

Related: `docs/wiki/MAP_INTEGRATION_CONTRACT.md` (hook ownership),
`configs/markers.lua` (tag contract), `src/Shared/Game/SpawnSlots.lua`
(the pure/injected-rng idiom this follows).

---

## 1. Architecture at a glance

```
mission door (authored, tagged MissionDoor)
        │ ProximityPrompt → MissionInstanceService:Open(team, missionId)
        ▼
MissionSeed        seed = hash(missionId, contextKey)         [pure]
        ▼
LayoutSolver       (catalog, params, layoutSeed) → LayoutSpec [pure, CI-tested]
        ▼
MissionStamper     LayoutSpec → cloned tiles under slot       [server, Instances]
        ▼
MissionInstanceService   slot pool, party teleport, teardown  [server]
```

Two hard rules carried over from the rest of the codebase:

1. **The solver is pure.** No Roblox APIs, no `math.random`, no `os.time` —
   rng is injected (SpawnSlots-style). Same seed ⇒ byte-identical LayoutSpec.
   CI sweeps seeds headlessly; Studio is only needed to *look* at maps.
2. **Tiles are authored Models placed by `Clone()` + `PivotTo()`.** No
   terrain voxels, no CSG, no EditableMesh. The generator's job is layout,
   not geometry (the egg-hatcher lesson: place authored things, don't
   synthesize bespoke geometry per site).

Mission instances are **same-server slots** (not sub-places): a pool of
reserved origins far from the authored map on the X axis. No cross-place
profile handoff, instant fade-teleports, and every existing service
(enemies, drops, teaming, shared FX) works unchanged. If server memory ever
demands it, the same LayoutSpec can be stamped in a reserved-server sub-place
without touching the solver.

---

## 2. Tile-kit contract

A **kit** is a themed set of tile Models (e.g. `hell_catacombs`,
`heaven_archive`). Kits live in the canonical model store:

```
ReplicatedStorage.Assets.Models.MissionTiles.<kitId>.<tileId>   (Model)
```

built/loaded by AssetPreloadService like every other model family (prebake
fast-path applies). Registered in `configs/mission_tiles.lua` (§6).

### 2.1 Tile Model spec

| Element | Requirement |
|---|---|
| **PrimaryPart** | An invisible anchored part named `TileRoot`. The Model pivot == `TileRoot` CFrame. Convention: pivot sits at **floor level, center of the footprint**, yaw-aligned to tile-local axes. All placement is `PivotTo(pivotWorld)`. |
| **`Bounds` part** | One invisible box part enclosing the tile's collidable envelope, axis-aligned in tile-local space. The catalog extracts its size/offset once; the solver does pure AABB math against it. The stamper deletes it (or sets CanQuery=false) after placement. |
| **Doors** | Child parts named `Door_1..Door_n`, tagged `TileConnector` (§2.2). |
| **Hooks** | Tagged marker parts per §2.3. |
| **Geometry** | Everything anchored, `CanTouch=false`/`CanQuery=false` except gameplay surfaces. Floor top at tile-local Y=0. |

Model attributes:

| Attribute | Type | Meaning |
|---|---|---|
| `TileClass` | string | `entrance` \| `room` \| `corridor` \| `junction` \| `objective` \| `cap` |
| `Weight` | number | Selection weight within its class (default 1). |
| `MaxPerMap` | number | 0/absent = unlimited. |
| `MinDepth` / `MaxDepth` | number? | Optional graph-depth gating (e.g. boss rooms only deep). |

Every kit MUST contain: exactly ≥1 `entrance` tile, ≥1 `objective` tile, and
**≥1 `cap` tile per DoorClass** (blind plug for unused doors — a map is never
emitted with an open doorway).

### 2.2 Connector (door) convention

A door is a part (invisible, anchored) whose CFrame encodes the mating
transform:

- **Position:** center of the doorway aperture, at floor level (part center Y
  = tile-local 0).
- **Orientation:** `LookVector` points **OUT** of the tile, perpendicular to
  the wall.
- **Axis alignment:** door directions MUST be axis-aligned in tile-local
  space (±X or ±Z). Combined with axis-aligned `Bounds`, every placement is a
  yaw multiple of 90°, so the solver's AABB overlap test is exact — no
  physics queries, no rotated-box math.
- Attribute `DoorClass` (string, default `"std"`). Two doors mate iff their
  DoorClass matches. Each DoorClass fixes one aperture size kit-wide
  (`std` = 12 studs wide × 14 high unless a kit overrides in config), so any
  `std` door mates flush with any other `std` door in the kit.

**Mating rule** (the whole trick): placing tile B's door `b` onto placed tile
A's door `a`:

```lua
-- doorOffset = pivot-relative CFrame captured by the catalog:
--   doorOffset = tileModel:GetPivot():ToObjectSpace(doorPart.CFrame)
local ROT_180 = CFrame.Angles(0, math.pi, 0)
pivotWorldB = doorWorldA * ROT_180 * doorOffsetB:Inverse()
```

Faces opposed, positions coincident, floor heights equal by construction.

### 2.3 Hook emission (what tiles carry inside)

Tiles reuse the existing `configs/markers.lua` tag contract so the live
spawner services work inside missions with zero new spawning code:

| Tag | Where | Notes |
|---|---|---|
| `PlayerSpawn` | entrance tile only | Party arrival point. |
| `SpawnZone` | any tile | Breakables/loot surfaces (existing clearance attrs apply). |
| `BaddieSpawner*` named parts | any tile | Enemy wave points (BaddieSpawnerService name-prefix contract). |
| `MissionObjective` **(new tag)** | objective tiles | required attrs: `ObjectiveId` (string); optional `ObjectiveKind`. Add to `markers.lua` + ConfigLoader schema in the same commit. |
| `MissionDoor` **(new tag)** | authored MAIN-world doors, not tiles | required attrs: `MissionId`. Bound by MissionInstanceService (RealmPortalService prompt pattern). |

**Attribute templating:** area-scoped hook attributes are authored with the
literal placeholder `$MISSION` (e.g. `AreaId = "$MISSION"`,
`SpawnerId = "$MISSION_ore"`). The stamper string-replaces `$MISSION` with
the instance's synthetic area id (`mission:<instanceId>`) on every
attribute of every stamped hook. Tiles stay instance-agnostic; services see
ordinary fully-qualified hooks.

---

## 3. Determinism & seeds

```lua
-- MissionSeed.lua (pure)
seed        = fnv1a32(missionId .. "|" .. contextKey)
streamSeed  = fnv1a32(tostring(seed) .. "|" .. phaseName)  -- "layout" | "decor" | "spawns"
```

- `contextKey` policy comes from the mission def (`configs/missions.lua`):
  - `team_stable`: `teamId` — the same party re-entering gets the same map.
  - `per_attempt`: `teamId .. "#" .. attemptCounter` — fresh each run, but
    reproducible: the instance record stores the resolved seed, so any map a
    player saw can be regenerated exactly for debugging ("what seed was that
    broken room?" → stamp it in Studio).
- **Stream isolation:** each phase gets its own rng stream. Adding a
  decoration draw can never shift the layout; layout changes only when the
  layout stream's consumption changes.
- **PRNG is ours, not Roblox's:** `MissionSeed.mulberry32(streamSeed)` (same
  injected `rng() → [0,1)` shape SpawnSlots uses), NOT `Random.new` — so the
  map contract never depends on Roblox's RNG implementation and the exact
  same maps generate on server, client, and the headless lune runner.
- The seed is replicated to clients (instance container attribute) so any
  future client-side cosmetic generation is free.
- One global knob `worldgen_version` (config) is folded into the hash so a
  solver algorithm change deliberately invalidates old seeds instead of
  silently producing different maps for "the same" seed.

---

## 4. LayoutSolver (pure)

**Signature:** `LayoutSolver.solve(catalog, params, layoutSeed) → LayoutSpec, report`
(spec `nil` on failure; failed attempts restart internally on rng streams
derived from `layoutSeed`, so the result is still a pure function of it).

**No CFrames:** placements are `{ x, z, rot }` with `rot` ∈ 0..3 quarter
turns (doors are axis-aligned, so every placement is a 90° yaw multiple —
plain table math, exact AABBs, loadable headless). The M2 stamper converts:
`slotOrigin * CFrame.new(x, 0, z) * CFrame.Angles(0, rot * math.pi/2, 0)`.

`catalog` = pure data extracted once by TileCatalog (per tile: class, weight,
caps, bounds box, door list as pivot-relative CFrame components — no
Instances). `params` from the mission def: `tileBudget`, `targetDepth`
(min/max graph distance to objective), class weights by depth band, overlap
margin.

**Algorithm — frontier growth with bounded backtrack:**

1. Place the entrance tile at origin (identity pivot). Push its doors onto
   the frontier.
2. While frontier nonempty and budget remains: pop a frontier door (rng),
   choose a tile class from the depth-band policy (corridors early, rooms
   mid, junctions for branching), choose a tile by weight (respecting
   `MaxPerMap`, `MinDepth`/`MaxDepth`), try each of its doors as the mating
   door; compute the pivot via the mating rule; **AABB-test** the tile's
   bounds (+margin) against all placed bounds. First fit wins; bounded
   retries per door, then the door is deferred.
3. **Objective guarantee (band is strict):** while the objective is
   pending, only frontier doors with depth ≤ `target_depth.max` may grow
   (deeper doors wait), objective tiles join the class weights from
   `target_depth.min`, and a door AT `target_depth.max` forces an
   objective — so a placed objective always lands within `[min, max]` of
   the growth tree. An attempt that can't satisfy that (budget exhausted,
   pool emptied, cap blocked) restarts the whole solve on the next
   deterministically derived rng stream, up to `max_attempts`.
4. **Facing-door rule:** two open doors left exactly coincident and
   opposed MUST connect (their caps would occupy each other's tile
   volume) — this is also how loops emerge. Recorded tile depth is
   growth-tree depth, not shortest path, so loop shortcuts don't
   retroactively shrink objective depth.
5. Cap every remaining open door with a class-matching `cap` tile.
   Author caps THINNER than `overlap_margin` (e.g. 0.4 deep vs margin
   0.5) so a cap always fits even flush against neighbouring geometry.
6. Emit the spec + a report (`attempts`, `growthTiles`, `caps`,
   `loopMates`, `deferred`).

**LayoutSpec** (pure table, CFrames relative to slot origin):

```lua
{
  version = 1, seed = 812559104, kitId = "hell_catacombs",
  tiles = {
    { tileId = "entry_A", cf = {...}, depth = 0 },
    { tileId = "corr_straight", cf = {...}, depth = 1, viaDoor = {1,"Door_2"} },
    ...
  },
  objectiveTileIndices = { 7 },
  bbox = { min = {...}, max = {...} },
}
```

**Invariants (CI, pure — `tests/worldgen/`):** exactly one entrance; ≥1
objective within `[targetDepth.min, targetDepth.max]`; every door mated or
capped; no AABB overlaps beyond epsilon; tile counts respect `MaxPerMap`;
bbox fits the slot envelope; determinism (`solve(seed)` twice → deep-equal);
seed sweep (e.g. 500 seeds) all pass all invariants.

---

## 5. Server pieces

### 5.1 MissionStamper (`src/Server/World/MissionStamper.lua`)

`stamp(spec, slotOrigin, instanceId) → container, hooks`

- Builds everything under a **detached** Model, parents once at the end
  (single replication burst), into
  `Workspace.MissionInstances.<instanceId>`.
- Per tile: clone from the AssetPreloadService store,
  `PivotTo(slotOrigin * spec.tiles[i].cf)`, set
  `ModelStreamingMode = Atomic`, strip `Bounds`, apply `$MISSION`
  attribute templating (§2.3), collect hooks.
- Time-sliced: `task.wait()` every N tiles (budgeted build, no frame spike).
- Decoration pass: `SpawnSlots.layoutGrid` per room with the `decor` stream.
- Container attributes: `MissionId`, `Seed`, `KitId`, `TeamId`,
  `Synthetic = true` (matches the WorldBindingService convention).

### 5.2 MissionInstanceService (`src/Server/Services/`)

Slot pool + lifecycle owner.

- **Slots:** `configs/missions.lua` `slots = { origin_x = 24000, spacing = 2048, count = 8, y = 0 }`
  — an X-band well past the authored map, spacing > 2× the default
  streaming `StreamingTargetRadius` (1024) so instances never stream into
  each other. Stay under ~50k studs from origin (float precision).
- **API (server):**
  - `Open(teamId, missionId) → instanceId | err` — gate (one live instance
    per team, global concurrency cap), resolve seed, solve (pure), stamp,
    register dynamic hooks, then teleport the party:
    `RequestStreamAroundAsync(slotOrigin)` per player → fade →
    `PivotTo` characters onto the entrance `PlayerSpawn`.
  - `Complete(instanceId)` / `Abandon(instanceId)` — return party to the
    door, unregister hooks, `container:Destroy()`, release slot.
  - TTL sweep: instances older than `max_lifetime` are abandoned (leak
    guard — the 32k-crystal lesson: instance budget is a hard invariant,
    counted and logged per open/teardown).
- **Doors:** binds `MissionDoor`-tagged authored parts with
  ProximityPrompts (RealmPortalService pattern). Team comes from the
  shipped teaming system; solo = team of one.

### 5.3 Known integration gaps (owned by this feature, not the solver)

1. **Dynamic hook registration.** BreakableSpawner still activates per
   configured world and needs a `RegisterContainer(container)` /
   `UnregisterContainer` entry point if mission mining hooks are added.
   Mission combat population no longer relies on boot-scanned
   BaddieSpawners: MissionInstanceService fields every `MissionSpawn`
   directly. Each spawned enemy receives the containing room rectangle
   from the same pure `LayoutSolver.mapData` used by the minimap. All movement
   is clamped through the shared `EnemyLeash` path; an invariant check in the
   combat event loop recovers any externally displaced enemy to its authored
   clear spawn anchor without deleting objective population.
2. **Synthetic AreaId.** `mission:<instanceId>` must be accepted by
   services that key off AreaId (zone checks, reward attribution). Audit
   ZoneService/WorldContext for hard assumptions that every AreaId exists
   in `areas.zones`.
3. **ConfigLoader schemas** for `mission_tiles.lua` + `missions.lua` +
   markers additions land in the same commits as the configs (CI won't
   catch a miss; Studio boot will).

---

## 6. Config surface

`configs/mission_tiles.lua` — kit registry:

```lua
return {
  door_classes = { std = { width = 12, height = 14 } },
  kits = {
    hell_catacombs = {
      display = "Catacombs",
      door_class_overrides = {},        -- rare; kit-wide aperture changes
      solver = {                        -- per-kit defaults, mission can override
        tile_budget = 40,
        target_depth = { min = 6, max = 10 },
        class_weights_by_band = {       -- band = depth / target_depth.max
          { upto = 0.4, corridor = 3, room = 2, junction = 1 },
          { upto = 1.0, corridor = 1, room = 3, junction = 1 },
        },
        overlap_margin = 0.5,
        max_backtracks = 8,
      },
    },
  },
}
```

`configs/missions.lua` — mission defs + slots:

```lua
return {
  worldgen_version = 1,
  slots = { origin_x = 24000, spacing = 2048, count = 8, y = 0 },
  limits = { per_team = 1, global = 6, max_lifetime = 1800 },
  missions = {
    rescue_the_lost = {
      kit = "hell_catacombs",
      seed_policy = "per_attempt",     -- or "team_stable"
      objective = { kind = "defeat_boss" },
      solver_overrides = {},
    },
  },
}
```

---

## 7. File map (new code)

```
src/Shared/Worldgen/MissionSeed.lua      ✅ pure: fnv1a32 + mulberry32 + stream derivation
src/Shared/Worldgen/TileCatalog.lua      ✅ pure: kit def → catalog (validates §2 contract, hard-errors); M2 adds a Studio-side extractor emitting the same table shape from authored Models
src/Shared/Worldgen/LayoutSolver.lua     ✅ pure: frontier-growth solver + validate() invariant checker (§4)
src/Shared/Worldgen/GrayBoxKit.lua       ✅ pure: M2 gray-box kit — definition() (solver geometry) + parts() (primitive visual geometry) in ONE module so walls can never disagree with solver AABBs/doors
src/Server/World/TileKitBuilder.lua      ✅ kit (definition+parts) → Folder of tile Models (pivot=TileRoot, tags, $MISSION attrs verbatim). Edit-mode note: build into a scratch parent, NOT ReplicatedStorage.Assets.Models (Rojo-owned rbxm subtree)
src/Server/World/MissionStamper.lua      ✅ spec → Instances (§5.1)
scripts/studio/stamp_mission_graybox.luau ✅ Edit-mode smoke: solve seed → stamp → camera frame
src/Server/Services/MissionInstanceService.lua   ✅ lifecycle (§5.2): slots, caps, TTL sweep, door+exit prompts, party teleport; registered in init.server.lua
configs/missions.lua                             ✅ worldgen_version, slots, limits, solver knobs, mission defs (+ _validateMissionsConfig in ConfigLoader, same commit)
configs/markers.lua                              ✅ MissionDoor + MissionObjective tags added
configs/mission_tiles.lua, configs/missions.lua  (+ ConfigLoader schemas)
tests/headless/specs/mission_worldgen.spec.luau  ✅ invariant + 300-seed sweep (mise run test-headless); kit def sourced from GrayBoxKit (single SSOT)
tests/headless/specs/gray_box_kit.spec.luau      ✅ kit geometry invariants (contract parts, bounds containment, no wall across an aperture)
```

---

## 8. MCP-driven build & validation loop

- **Gray-box first:** the first kit is primitive-part tiles (M2 below) so
  the whole pipeline is proven before any art exists.
- **Kit production:** `generate_procedural_model` for parametric tiles
  (corridor length / door-count knobs as attributes), `generate_material`
  for per-theme surfaces, Blender MCP → group upload (`--creator-group
  15872767`) for hero set-pieces. Generated tiles are *curated into* the
  kit folder — the contract validator (TileCatalog) is the gate.
- **Seed-sweep smoke (Studio, serial):** stamp seed N in Edit mode at a
  test slot → `execute_luau` asserts PathfindingService reachability
  entrance→objective → `character_navigation` walks it → screenshot per
  room → next seed. This is the regression harness for the generator;
  CI covers the pure invariants, the sweep covers "does it *play*".

---

## 9. Phasing

| Phase | Deliverable | Verified by |
|---|---|---|
| **M1** ✅ | MissionSeed + TileCatalog + LayoutSolver + specs, gray-box catalog defined purely in test data | CI seed sweep (no Studio) — DONE 2026-07-08, 17 tests incl. 300-seed sweep |
| **M2** ✅ | Gray-box tile kit (primitives) + TileKitBuilder + MissionStamper; stamp seeds in Edit mode | DONE 2026-07-08 — MCP live: stamped at slot band X=24000, pivots/attrs verified, cross-env determinism (lune ≡ Studio byte-identical for seed 12345), PathfindingService entrance→objective Success 6/6 seeds, screenshots. Character walk needs Play mode → rolled into M3. Slot CONFIG also deferred to M3 (belongs with the service + ConfigLoader schema) |
| **M3** ✅ | MissionInstanceService lifecycle + MissionDoor binding + party teleport + configs | DONE 2026-07-08 — live play-mode SOLO loop: door prompt → stamp at slot 1 → teleport → character_navigation walk to beacon → exit prompt → teardown verified + fresh seed on re-entry. Duo (two-account) run still owed — fold into M4's live pass |
| **M4** ✅ | Enemies + objective auto-complete inside missions | DONE 2026-07-08 live: kit rooms/objective carry `BaddieSpawner` parts (name-prefix discovery — BaddieSpawnerService.Rescan() nudged at stamp, no registration API needed; `home` anchor = leash, static leash config untouched); 4-enemy wave (bear/dogs/crow) spawned in-mission; reach_beacon monitor auto-completed on approach; EnemyService.DespawnEnemiesInBounds at teardown → 0 leaked enemies. BREAKABLES deliberately deferred (BreakableSpawner is per-configured-world keyed on breakables.worlds[areaId]; missions are combat gauntlets — mining inside missions conflicts with pause_farm_in_combat anyway). Duo two-account pass still owed (Jason drives) |
| **M4.5** (live-tuning, 2026-07-08) | Playtest-driven mechanics pass | 6x tile scale (Jason: v1 "vastly too small") + doorway-sized openings with header strips; **CoH clear-gate**: static seeded population at MissionSpawn anchors (MissionPopulation.roll on the "spawns" stream; NO proximity waves in missions — anchors deliberately not BaddieSpawner-prefixed) + glowy inert until all enemies defeated (also the anti-cheese: invulnerable pet-less players can walk but never clear); "Defeat all enemies — N/X" via player attr MissionObjectiveText → MissionObjectiveHUD chip (pure attr render); 48-stud walls + per-mission CameraMaxZoomDistance clamp (no zoom-scouting the glowy), restored on exit |
| **M5** | First real themed kit (MCP-assisted art), reward wiring, polish | Live |

## 10. Mission sources: doors, RANDOM trials, and the quest ladder (2026-07-08)

A mission **config** (`missions.missions.<id>`) is decoupled from its **source** (what
launched it). Two sources exist:

- **Direct doors** — `MissionDoor`-tagged part, `MissionId = "<realId>"` (the realm
  gates in `Maps.Heaven_2` / `Maps.Hell_2`, plus StudioOnly plaza dev gates).
- **Random doors** — `MissionId = "random"`. `Open` rolls a real id from
  `missions.random.pool` per entry (fresh seed via the per-attempt counter) and stamps
  `record.source = "random"`. Gated by the profile flag
  `GameData.Unlocks.random_missions`; locked players get a rejection, the door prompt
  always shows. Future quest-tied missions are just another source pinning a config.

**Quest ladder** (`configs/quests.lua` track `trials`, Lv 14): `tr_first_trial`
(complete any mission) **unlocks random trials** via the generic `def.unlock` plumbing
(QuestService:Claim writes `GameData.Unlocks.<flag>` + publishes `Unlock_<flag>`
attribute; List republishes on rejoin). Then lifetime ladder: 10 / 100 / 1,000 /
10,000 random trials + Treasure Hunter (25 chests). Substrate counters
(configs/stats.lua, auto-backfilled): `missions_completed`,
`random_missions_completed` (both incremented per team member in `_close` when
`reason == "complete"`), `mission_chests_opened` (chest open handler).

**Realm-correct rosters**: each realm's trial fights its own kind — hell_trial fields
the lava natives; heaven_trial fields the CELESTIAL faction (zealous_cherub /
lance_seraph_guard / radiant_sprite_guard / prism_warden — role-balanced mirrors of
the lava set, meshes borrowed from the layer-2 heaven pets, drops pay grass_coins +
light_tokens).

## 11. Curated maps & named-boss objectives (design, 2026-07-09)

**Boss population contract (revised from live evidence, 2026-07-13)**: boss-marked
packs are objective anchors. `missions.population.boss_only_at_objective` excludes
them from ordinary room rolls, while the objective MissionSpawn receives exactly
one. This replaced the earlier incidental ~2-per-map weighted behavior after a
Heaven Grass run fielded four Worldbloom Ents.

**Curated map library** (planned): a curated mission = `{ display, mission, seed }` —
a map IS its seed, so vetting is play-testing randoms and saving winners by name.
Constraints: pin `worldgen_version` per entry + store a layout FINGERPRINT (tile
count / bbox / placement hash) + CI regen check so generator changes can't silently
reshape vetted maps (they become a visible re-vet task instead). Dev capture: admin
command printing the live instance's seed. Per-player layout history deliberately NOT
persisted (anti-repeat = rolling in-memory last-N seeds if ever needed).

**Named-boss objective** (planned): `objective = { kind = "defeat_named_boss",
boss = "<enemyId>" }` — population guarantees EXACTLY ONE of that enemy (objective
chamber, screened by its pack); tracker shows "Defeat <Display Name>!"; completion
watches that model, not the roster. Composes: boss-only / boss+clear / boss+beacon.
CoH rule: named it, so there's ONE of it.

## 12. Element trials & the trials endgame shape (2026-07-09)

**Trial matrix** (each type activates a different pet-choice axis):
- **Realm trials** (hell/heaven): light/shadow RESONANCE axis; random-origin drops
  (deliberately neutral rate — variety by Jason's call).
- **Element trials** (lava/ice, extensible to grass/desert): realm-NEUTRAL; the
  BIOME RPS is their axis (mission.area → kind="mission" pseudo-zone with an
  element); drops brand to the element's origin (area_origins). Bespoke
  THEME_PALETTES + MissionAtmosphere presets; prefab pools alias the realms
  (lava→hell, ice→heaven) until bespoke sets land.

**Aggression contract**: Trials are combat instances and use the config-driven `universal` aggression
policy. Any live pet can initiate against any mission enemy, and mission enemies can initiate against any
live squad. This overrides only target initiation; realm resonance remains independent (own realm 0.8x,
opposite realm 1.5x, base pets 1.0x). Normal Heaven overworld non-aggression is unchanged.

**Pet-model enemies**: packs accept `{ pet = id, rank = "minion|lieutenant|boss",
count }` — EnemyService.SynthesizePetEnemy (public over the patrol-invader
synthesizer) applies missions.pet_ranks; BOSS rank wears the pet's own
huge_scale ("boss versions = huges of them"). Boss rank also uses the pure
`MissionRankScale` path: its config owns a linear level-14 baseline through the
existing level-50 rank values, including HP, basic damage, armor, and ability
damage. The opener's level is captured once for the run. Realm rosters give every
element a full cast in both alignments.

**Curated themed quests** (the wrap for Trials, per Jason): use mission.replay
to HUNT the shared-sequence space at high numbers, vet maps per element/realm,
record winners as curated entries (§11 fingerprint rules apply) → themed
missions/quest lines per origin.

**Achievements**: per-trial counters (<missionId>s_completed, auto-derived in
_close, declared in stats.lua) make "complete 100 ice trials" a config row.

## 13. Trials endgame lattice — SHIPPED (2026-07-09, live-verified)

The full matrix + quest + Platinum-egg endgame is live. This section records the
shipped contract; the design sketches in §10–§12 stand as history.

**Matrix trials (8)**: `<realm>_<element>_trial` for hell/heaven × lava/ice/
grass/desert. Each is one `configs/missions.lua` block composing the three
independent fields — `theme` (dressing/palette/atmosphere), `area` (element
branding: `mission_<area>` pseudo-zone → biome RPS + `area_origins` drop
branding), `realm` (CurrentRealm override → light/shadow resonance, restored
via `LayerService:RefreshRealmAttributes` at close). All use
`seed_policy = "shared_sequence"` (everyone's trial #N is the same map),
declare `<id>s_completed` counters, and carry `boss_egg` (0.5% boss drop +
0.5% first-clear roll at sequence advance).

**Selection = quest activation (THE gate selector)**. Realm gates are
`MissionId = "auto"`: the active quest track's head `def.mission` binds the
trial; no binding → roll `random.pool` (the four base trials ONLY — matrix
trials are NEVER dealt at random, so their counters only move via activation).
QuestService puts `def.mission` on the wire; mission-bound quests count as
`activationGated` and show ⏸ paused when unfocused. QuestPanel: gate-steering
branches get "▶ Activate — realm gates will deal this trial"; the green active
banner is a BUTTON — tap to deactivate (`SetActiveTrack(nil)`) and gates revert
to random. Per-mission sequence heads keep your place across switches.

**Quest chains**: 5 sequential layers per combo — 10/25/50/90/100 (gems
30/60/120/250; the Century pays 500 + the Platinum egg). The Century condition
is `all_of(counter ≥ 100, level ≥ 50)` — the claim-once ledger + the level-50
CLAIM gate are the anti-alt teeth (sub-50 can play past 90 but can't claim).

**Platinum eggs**: `platinum_obsidian_egg` / `platinum_celestial_egg` — same
5 exclusive pets as the boss eggs, `fixed_odds` with stated 15% huge (policy:
odds bind per EGG; a different egg may state different odds). Real shells
wired (85c6c95). Granted via quest `reward.items` with `bucket = "eggs"`
(RewardService pass-through), hatched at any hatcher via the generalized
`egg_item.hatch` path.

**Gate UX**: the door E-prompt names the deal — MissionInstanceService
publishes per-player `NextTrialLabel` ("Hell Lava Trial #4" / "Random Trial";
refreshed on focus change, skip, and sequence advance via the published
`QuestActiveTrack` attribute), and the client `MissionGatePrompt` system stamps
it onto auto/random door prompts LOCALLY (a shared ProximityPrompt can't show
per-player text). Back-to-back realm portals are side-gated by
`RealmPortalSideGate` (pairs co-located `RealmPortalPrompt`s, locally Enables
only the face on the player's side — Roblox otherwise surfaces whichever
prompt PART is closest, and the hell anchor sits ~9 studs lower than the
heaven plane center). The generic and matrix Trials quest tracks unlock at
level 14, matching the first reachable doors in Heaven 2 / Hell 2.

**Player group-size tuning**: Settings exposes `Trial Enemy Group Size` as a
persistent percentage. Its default/min/max/step live only in
`missions.player_tuning.group_scale` (initial tuning range 25%–200% in 5%
steps), and the server clamps every request through `PackScale`. The player who
opens the mission controls the generated density for the entire party. That
value composes with the automatic `team_scaling` multiplier after seeded pack
selection, so changing it never changes Trial #N's map or pack roll. Scalable
roles retain at least one representative; boss/titan anchors stay singular and
the objective room still guarantees its boss pack. The resolved player and team
multipliers are stamped on the mission instance as `TrialGroupScale` and
`TrialTeamScale` for live diagnosis. Enemy XP/loot remains per defeated enemy;
the tuning range, baseline, and any future fixed-completion reward treatment
should be revisited from playtest evidence rather than encoded in UI logic.

**Dev ergonomics**: the spawn-plaza StudioOnly gates are DELETED (activation
covers trial selection in dev too); `admin.setCounter` (IsAdmin-gated bus
command) is the sanctioned counter override — `test.*` is unreachable from
network origin BY DESIGN, even in Studio. Validation: `MissionSchema` +
`ZoneSchema` (pure, shared by ConfigLoader, services, and the CI
`config_validation.spec`) catch unknown pet/enemy ids, missing counters,
non-fixed-odds boss/reward eggs, and quest bindings to unknown missions at
config load.
