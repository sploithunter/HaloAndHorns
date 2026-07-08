# Mission Worldgen — Tile-Kit Contract & Generator Design

**Status:** DESIGN (no code yet). SSOT for the procedural mission-map system.
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
LayoutSolver       (catalog, params, rng) → LayoutSpec        [pure, CI-tested]
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
- **Stream isolation:** each phase gets its own `Random.new(streamSeed)`.
  Adding a decoration draw can never shift the layout; layout changes only
  when the layout stream's consumption changes.
- The seed is replicated to clients (instance container attribute) so any
  future client-side cosmetic generation is free.
- One global knob `worldgen_version` (config) is folded into the hash so a
  solver algorithm change deliberately invalidates old seeds instead of
  silently producing different maps for "the same" seed.

---

## 4. LayoutSolver (pure)

**Signature:** `LayoutSolver.solve(catalog, params, rng) → LayoutSpec, report`

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
3. **Objective guarantee:** once a frontier door's graph depth reaches
   `targetDepth.min`, objective tiles become eligible; at
   `targetDepth.max` they become forced. If budget exhausts with no
   objective placed, pop the last `k` placements and retry with the next
   draws; after `maxBacktracks`, restart the whole solve with
   `rng = Random.new(streamSeed + attempt)` — attempt sequence is
   deterministic, so the final map is still a pure function of the seed.
4. Cap every remaining open door with a class-matching `cap` tile.
5. Emit the spec + a validation report.

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

1. **Dynamic hook registration.** BaddieSpawnerService scans Workspace by
   name-prefix at boot; BreakableSpawner activates per configured world.
   Each needs a `RegisterContainer(container)` / `UnregisterContainer`
   entry point (or a rescan call) so hooks born mid-session inside
   `MissionInstances` are honored. Same for leashes: `configs/enemy_leash.lua`
   is static dotted paths — add a runtime
   `EnemyLeash.registerRegion(areaId, parts)` used by the stamper (each
   room's floor = its leash region; room-scoped leashing falls out
   naturally).
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
src/Shared/Worldgen/MissionSeed.lua      pure: fnv1a32 + stream derivation
src/Shared/Worldgen/TileCatalog.lua      kit folder + config → pure catalog (validates §2 contract, hard-errors on violations)
src/Shared/Worldgen/LayoutSolver.lua     pure: frontier-growth solver (§4)
src/Server/World/MissionStamper.lua      spec → Instances (§5.1)
src/Server/Services/MissionInstanceService.lua   lifecycle (§5.2)
configs/mission_tiles.lua, configs/missions.lua  (+ ConfigLoader schemas)
tests/worldgen/*.spec.lua                invariant + seed-sweep tests
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
| **M1** | MissionSeed + TileCatalog + LayoutSolver + specs, gray-box catalog defined purely in test data | CI seed sweep (no Studio) |
| **M2** | Gray-box tile kit (primitives) + MissionStamper + slot config; stamp seeds in Edit mode | MCP: stamp + pathfind + walk + screenshots |
| **M3** | MissionInstanceService lifecycle + MissionDoor binding + party teleport | Live play-mode run, solo + duo |
| **M4** | Dynamic hook registration (spawners/leash) → enemies + breakables + objective inside missions | Live mission clear end-to-end |
| **M5** | First real themed kit (MCP-assisted art), reward wiring, polish | Live |
