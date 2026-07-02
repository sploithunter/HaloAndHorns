# Map Integration Contract

Status: current

## Summary

The map can be hand-built in Studio, but gameplay systems must bind to stable hooks. The contract is CollectionService tags, attributes, and a few declared child-marker names. This lets a world builder reshape the map without rewriting services.

## Ownership

Rojo owns:

- `src/`
- `configs/`
- UI and networking code
- validation and admin tools
- server/client behavior

Studio owns:

- Workspace geometry
- terrain and decorations
- invisible zones and spawn volumes
- portals, pads, stands, podiums, and anchor placement

An AI-assisted deployment pass may normalize the Studio-owned map before Rojo sync: quarantine old scripts, regroup art, rename ambiguous imported objects, add invisible helper parts, and stamp tags/attributes. That is considered part of map integration, not a burden on the builder, as long as original art is preserved and the resulting hook contract is documented.

## Canonical Hooks

- `Zone`
- `AreaZone`
- `PlayerSpawn`
- `SpawnZone`
- `TeleportPad`
- `Portal`
- `EggStand` or contracted names like `EggStand_Basic`
- `EnchanterStation`
- `PODPodium` or contracted names like `PetDisplay_Podium`
- `ChaseableRegion`
- `ShopAnchor` / `NPCAnchor`

## Rules

1. Every gameplay area has a stable id.
2. Every gameplay object is discoverable by tag, attribute, or contracted name.
3. Services do not use hardcoded coordinates or fragile Workspace paths.
4. Startup validation reports missing or invalid hooks precisely.
5. New areas require config plus Studio markers, not core code changes.

## Synthetic Fallback

If no authored map exists, or if `map.mode = "synthetic"`, `WorldBindingService` should fabricate valid zones, spawn volumes, egg stands, portals, teleport pads, and displays from config. Feature services should not know whether hooks were authored or synthesized.

In `auto` mode, the first authored contract hook is treated as a real-map signal. Once a non-synthetic hook such as `EggStand` exists, Rojo should sync scripts/configs only and should not fabricate visual fallback floors, spawn pads, placeholder egg stands, portals, teleport pads, or breakable spawn regions. Additional gameplay regions must then be stamped explicitly on the map, usually by an AI-assisted setup pass.

## Current Implementation

`configs/areas.lua` declares the starter zone tree:

- `spawn_world -> spawn_island -> Spawn`
- `spawn_world -> meadow_island -> Meadow`

`configs/markers.lua` declares marker schemas for canonical hooks. `WorldBindingService` validates those configs, detects authored hooks, and synthesizes hooks only for synthetic maps or for `auto` maps with no authored hooks.

For authored-map tests, `scripts/studio/create_reference_map.luau` creates a tiny Studio-owned `AuthoredReferenceMap` with the same `Spawn`/`Meadow` contract. `tests/studio/MapContractSmoke.lua` verifies whether the live hooks are authored or synthetic.

The current synthetic baseline creates:

- `Zone` hooks for `spawn_world`, `spawn_island`, `meadow_island`, `Spawn`, and `Meadow`;
- `AreaZone` hooks for `Spawn` and `Meadow`;
- `SpawnZone` hooks for `spawn_crystals` at `Workspace.Game.Breakables.Crystals.<AreaId>.SpawnArea`;
- one invisible `EggStand` hook for `basic_egg` that also satisfies the legacy `EggSpawnPoint` search and uses `SpawnMode = "spawn_model"` so the template can spawn a placeholder egg visual;
- `PODPodium` hooks for each area;
- bidirectional `TeleportPad` hooks between `Spawn` and `Meadow`;
- bidirectional `Portal` hooks between `spawn_island` and `meadow_island`.

`BreakableSpawner` now asks `WorldBindingService` for `SpawnZone` parts before falling back to legacy child-name scanning. A `SpawnZone` can be either an invisible volume for synthetic/template maps or a real surface mesh for authored maps. Surface spawners use `SurfaceOnly = true` plus clearance attributes to raycast onto the tagged surface and reject candidates that overlap props, paths, eggs, portals, trees, rocks, or existing breakables. On imported mesh maps, use `ClearanceMode = "ray_samples"` so giant mesh bounding boxes do not block playable grass unless downward obstacle rays actually hit visible/queryable geometry.

`ZoneService` consumes the zone tree plus bound `TeleportPad`/`Portal` hooks. It validates unlocks on the server, persists `GameData.UnlockedAreas`, moves the character to the target zone spawn, and updates the active area through `WorldBindingService`.

Travel hooks also get a server-created `ProximityPrompt` named `ZoneTravelPrompt` for paid locked destinations. The client hides this prompt for destinations the local player already owns, so normal unlocked travel remains touch-only. Pressing `E` on a visible locked prompt attempts the paid unlock before travel. Touching a locked hook still returns `ZoneTravelResult.reason = "locked"` and the client shows a visible locked-area notice with the configured cost.

For manual portal testing, use the admin panel's developer controls to toggle, lock, paid-unlock, or bypass-unlock `Meadow`. Admin locking removes the persisted unlocked area without refunding, which lets the same player repeatedly test locked and unlocked portal states.

Spawn placement is resolved from the live map before falling back to configured synthetic coordinates. `WorldBindingService:GetSpawnCFrameForZone` first uses a `PlayerSpawn` hook for the area when one exists, then the area's authored `AreaZone` center, raycasts down to real floor geometry while excluding marker parts, and returns a safe above-floor CFrame. If no floor hit is found, it falls back to the area's `SpawnZone`, then finally to config `synthetic.spawn_position`. This keeps Studio-authored maps portable when islands move. In `NewWorld Map Cleanup Copy`, `Workspace.SpawnLocation` is stamped as `PlayerSpawn` with `AreaId = "Spawn"` so the template does not fall back to the old baseplate origin.

Active-zone dormancy is implemented for breakable spawning: Spawn is live for the starter loop, while non-default configured areas stay dormant until a player enters/travels there. Entering/traveling to an area fills that area's configured spawner.

When authored `TeleportPad`/`Portal` hooks already exist for a source/target pair, `WorldBindingService` does not create duplicate synthetic travel hooks.

Pet enchant/reroll stations are authored map fixtures. Tag the station model or its touch part with `EnchanterStation`, set `EnchanterId` to a key in `configs/enchants.lua` `stations`, and optionally set `TouchPartName` if the touch volume is a named child such as `EnchantTouchPart`. Cosmetic movement scripts can remain inside the model; gameplay touch/prompt behavior belongs to `EnchantService`. The current ColorfulClickers-imported `Workspace.Enchanter` uses `EnchanterId = "basic_enchanter"` and keeps its floating scripts, while the copied touch script is disabled because the service owns activation. Use `scripts/studio/tag_enchanter_station.luau` to repeat that setup after reimporting the model.

Builder-authored egg visuals are map fixtures too. A visible model can have any builder-friendly name, then a setup pass stamps the intended interaction anchor part with `EggStand`, `EggId`/`EggType`, optional `AreaId`/`SpawnId`, `AuthoredVisual = true`, and `SpawnMode = "authored"`. For large hatchers, tag the egg/rock part players approach rather than the full decorative container so proximity distance and billboards attach to the right spot. `scripts/studio/audit_authored_map_candidates.luau` lists likely imported objects, and `scripts/studio/stamp_authored_egg_stands.luau` is the current repeatable helper for the assisted mapping pass. Blank/template maps still use synthetic invisible egg hooks and spawned placeholder egg models.

For the NewWorld migration, `Workspace.Maps.Home.LegacyEggHatchers.BasicEarth.EggModel` is the authored `basic_egg` stand. Golden hatching is not modeled as a separate default egg stand; it is controlled by `egg_sources.<id>.variant_rolls` and `rarity_rates`. Egg previews always show the first-stage pet roll in basic form; golden/rainbow is a second hidden variant roll. Premium/no-basic egg settings can use `variant_rolls.allow_basic = false` and optional `variant_rolls.cost_multiplier` to price the hidden variant mode from the base egg cost.

For NewWorld breakables, `Workspace.Maps.Home.Grass` is stamped as the authored `Spawn` crystal `SpawnZone`. It uses surface raycasting plus `ClearanceMode = "ray_samples"` so crystals/coins appear on playable grass and avoid the hatcher, sidewalks, trees, rocks, portals, and other map art without letting oversized imported mesh bounds falsely block open grass.

For imported enchanter cosmetics such as `FloatingCoinScript`, leave `configs/enchants.lua` `stations.<id>.animation.active_when_near = false` unless the designer explicitly wants proximity-driven ambient animation. The current model expects its floating scripts to run continuously.

Successful rerolls can also trigger station-authored VFX through `stations.<id>.animation.lightning`. The default `basic_enchanter` effect temporarily clones the selected pet from preloaded pet assets, places it at the station, and calls the reusable `Shared.Effects.EnchantLightning` module. That module fires ColorfulClickers-style procedural neon cylinder bolts from configured origin parts into the cloned pet's primary/first part. Use `origin_part_paths` for exact station-relative child paths, such as `RuneStone1.Rune`, when an imported model has extra parts with the same name; use `origin_part_name` or `origin_part_names` only when name-based discovery is unambiguous. Designers can swap the top endpoint contract to a single named part such as `LightningTop` or an explicit `origin_part_paths` list without changing service code. The station config owns colors, duration, curve, jitter/radius, thickness, core/glow intensity, strand/segment counts, result delay, temporary pet placement, and independent thunder audio lifetime.

## Links

- [Foundation & Requirements K8](../FOUNDATION_AND_REQUIREMENTS.md)
- [Implementation Plan Phase 1](../IMPLEMENTATION_PLAN.md)
- [Map Marker Reference](../MAP_MARKER_REFERENCE.md)
- [Decisions](DECISIONS.md)
