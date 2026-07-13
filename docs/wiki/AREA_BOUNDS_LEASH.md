# Area Bounds & Movement Leash

Status: current (enemy leash implemented) + one recorded **possibility** (player confinement).

How movement is confined to authored areas. The core is a pure, reusable union-of-shapes clamp;
today it leashes enemies, and it is designed to extend to the player.

## Core: analytic and exact-surface regions

`src/Shared/Game/EnemyLeash.lua` — point-in-region containment + clamp over a **union** of simple
X/Z footprint shapes (no Roblox APIs, headlessly tested in `tests/headless/specs/enemy_leash`):

- `box    = { kind = "box",    cx, cz, halfX, halfZ }`
- `circle = { kind = "circle", cx, cz, r }`
- `EnemyLeash.inside(x, z, shapes, margin)` → bool (inside ANY shape)
- `EnemyLeash.clamp(x, z, shapes, margin)` → x, z (inside any shape = unchanged; else snap to the
  nearest shape's boundary). `margin` insets every edge so a mover stops just inside.

A **region is a union of shapes**, so one pen can span differently-shaped, adjacent parts. Home
biomes now use `surface` shapes: `EnemyService` filters a downward raycast to the configured authored
floor part and accepts a movement destination only when that exact part supports the X/Z point. The
pure box/circle helper remains available for intentionally analytic pens.

## Implemented: enemy leash (hard wall per spawn area)

An enemy is confined to the area it spawned in — it chases up to the boundary and no further, so it
never trails the player across the map.

- **Source of truth = live map parts, not the player-area zones.** `configs/areas.lua` zones only
  coincidentally match the geometry (Desert/Ice/Lava), there is **no Grass zone**, and the config
  `Spawn` box does not match the real `SpawnCircle` part. So the leash reads the actual floor parts
  under `Workspace.Maps.Home` via `configs/enemy_leash.lua`. See [enemy-leash-geometry] in memory.
- **Regions** (`configs/enemy_leash.lua`): `Desert`/`Ice`/`Lava` use their exact biome floor meshes;
  **`GrassSpawn` = exact Grass surface ∪ exact SpawnCircle surface** (the starter pen spans both).
  Broad MeshPart bounding boxes are not authoritative because the four boxes overlap.
- **Deterministic ownership:** `region_order` handles true authored seams; Home cave suffixes bind to
  their area/region through `spawner_bindings`, and `EnemyService` validates that an explicitly bound
  spawn is actually supported by that surface. Realm/mission spawners cannot inherit Home territory.
- **One movement gate:** `_leashToHomeArea` is used by chase, fear, knockback, and idle loiter. An
  irregular-surface move that would leave the configured union holds the last supported point.
  Enemies are server-anchored and moved through `MoveTarget`, so this is exact without rubber-banding.
- **Elevation:** the leash is an X/Z territory rule, so enemies may climb authored mountains inside
  their biome. Ground movement permits gradual per-step rises (`ground_climb_max`); chase no longer
  has the old 28-stud jump-assist, so abrupt wall/ledge tops are rejected.
- **Diagnostics:** spawned enemy models expose `HomeArea` and `LeashRegion` attributes.
- **Not covered:** Meadow / bare-Spawn (no enemies there). Add a region + part to extend.
- **Legacy caveat:** box/circle regions are still axis-aligned/analytic. Prefer `surface` for irregular
  authored MeshParts.

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
