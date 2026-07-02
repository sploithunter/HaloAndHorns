# Area Bounds & Movement Leash

Status: current (enemy leash implemented) + one recorded **possibility** (player confinement).

How movement is confined to authored areas. The core is a pure, reusable union-of-shapes clamp;
today it leashes enemies, and it is designed to extend to the player.

## Core: `EnemyLeash` (pure union clamp)

`src/Shared/Game/EnemyLeash.lua` — point-in-region containment + clamp over a **union** of simple
X/Z footprint shapes (no Roblox APIs, headlessly tested in `tests/headless/specs/enemy_leash`):

- `box    = { kind = "box",    cx, cz, halfX, halfZ }`
- `circle = { kind = "circle", cx, cz, r }`
- `EnemyLeash.inside(x, z, shapes, margin)` → bool (inside ANY shape)
- `EnemyLeash.clamp(x, z, shapes, margin)` → x, z (inside any shape = unchanged; else snap to the
  nearest shape's boundary). `margin` insets every edge so a mover stops just inside.

A **region is a union of shapes**, so one pen can span differently-shaped, adjacent parts.

## Implemented: enemy leash (hard wall per spawn area)

An enemy is confined to the area it spawned in — it chases up to the boundary and no further, so it
never trails the player across the map.

- **Source of truth = live map parts, not the player-area zones.** `configs/areas.lua` zones only
  coincidentally match the geometry (Desert/Ice/Lava), there is **no Grass zone**, and the config
  `Spawn` box does not match the real `SpawnCircle` part. So the leash reads the actual floor parts
  under `Workspace.Maps.Home` via `configs/enemy_leash.lua`. See [enemy-leash-geometry] in memory.
- **Regions** (`configs/enemy_leash.lua`): `Desert`/`Ice`/`Lava` = the biome floor mesh box;
  **`GrassSpawn` = Grass mesh box ∪ SpawnCircle disc** (the starter pen spans both).
- **Wiring** (`EnemyService`): `_buildLeashRegions` resolves the parts at boot; `_leashRegionAt`
  stamps `entry.leashRegion` at spawn; `_leashToHomeArea` clamps each chase step via
  `EnemyLeash.clamp` (inset from config). Enemies are server-anchored (moved via `MoveTarget`), so
  clamping the computed step is exact — no rubber-banding.
- **Not covered:** Meadow / bare-Spawn (no enemies there). Add a region + part to extend.
- **Caveat:** boxes are axis-aligned bounding rectangles (square corners vs. a mesh's rounded edge);
  the SpawnCircle is an oval treated as a circle of radius ≈ half its larger dim (generous). Tune in
  config if it overshoots.

## Possibility (not implemented): confine the PLAYER to an area

Reuse the same union clamp to keep the **player** inside an area's bounds — the motivating case is a
future **flying power**: without bounds, a flyer could float up and over the scenery and leave the
playable world. Recorded here so the option is ready when we want it.

Feasible and small, but the *application* differs from enemies because the player is **physics-driven
and client-authoritative** (you can't overwrite their position from the server each frame without
rubber-banding):

- **Recommended mechanism — client-side clamp.** A client controller clamps the character's CFrame
  into the allowed union every frame via `EnemyLeash.clamp`, **plus a Y ceiling** for the flying
  case. Smooth, dynamic, reuses the pure code. Add a light server sanity-check as anti-cheat (this
  is a co-op pet game, not competitive PvP).
- **Alternative — invisible collision walls.** `CanCollide` parts around the footprint; a flyer
  bumps them physically. More "honest" but rigid: awkward to shape to a union, to open/close for
  transitions, and pressing a wall mid-flight feels stuck.
- **Transitions stay free.** Set the allowed union = **all of the current world's area footprints
  combined**, so there is no wall *between* biomes — only at the outer edge of the playable map.
- **World teleports bypass it** by definition (they reposition the character). Use a short
  "teleport grace" flag so the clamp doesn't yank the player back mid-transition (same pattern as the
  StreamingEnabled anchor-during-teleport fix in `LayerService`).
- **Rough scope:** one client controller + a small "allowed-union per world" config (reuse the
  `enemy_leash` part-sourcing) + a Y-cap + a teleport-grace flag.

This is an **open possibility**, not a committed feature — see [Open Questions](OPEN_QUESTIONS.md).
