# Map Marker Reference

This project treats Studio-authored maps as geometry plus invisible gameplay hooks. Rojo owns scripts and config; Studio owns the world. The handoff is CollectionService tags plus Instance attributes.

## Required Tags

| Tag | Required Attributes | Optional Attributes | Purpose |
| --- | --- | --- | --- |
| `Zone` | `ZoneId`, `Kind` | `ParentZoneId` | World/island/area grouping zone. `Kind` is `world`, `island`, or `area`. |
| `AreaZone` | `AreaId` | `ParentZoneId` | Gameplay area volume. Player enter/exit events are centralized here. |
| `PlayerSpawn` | `AreaId` | `ZoneId` | Authored player spawn anchor for an area. `WorldBindingService:GetSpawnCFrameForZone` prefers this before raycasting from area volumes or falling back to synthetic config coordinates. |
| `SpawnZone` | `AreaId`, `SpawnerId` | `DepthOffset`, `MaxCountOverride`, `SurfaceOnly`, `ClearanceMode`, `ObstacleMode`, `ClearanceRadius`, `ClearanceHeight`, `ClearanceYOffset`, `RaySampleCount`, `ObstacleRaycastHeight`, `ObstacleRaycastDepth`, `RaycastHeight`, `NormalMinY`, `SpawnAttempts`, `SpawnAreaMargin`, `MinDistance`, `BalancedCells`, `CellSize` | Breakable/collectible spawn hook. Current crystal spawner uses `SpawnerId = "spawn_crystals"`. On authored maps this can be a real playable surface mesh, such as `Grass`, with surface sampling and obstruction clearance enabled. |
| `TeleportPad` | `AreaId`, `TargetZoneId` | none | Area-to-area travel hook. |
| `Portal` | `ZoneId`, `TargetZoneId` | none | World/island travel hook. |
| `EggStand` | `EggId` | `AreaId`, `SpawnId`, `AuthoredVisual`, `SpawnMode` | Egg interaction/placement hook. Builder-authored visible eggs should tag the actual interaction anchor part, such as the egg/rock inside a larger decorative hatcher, with `AuthoredVisual = true` and `SpawnMode = "authored"`. Invisible template spawn points can use `SpawnMode = "spawn_model"` to let the template spawn placeholder egg visuals. The legacy egg spawner also accepts a part named `EggSpawnPoint`. |
| `EnchanterStation` | `EnchanterId` | `AreaId`, `TouchPartName`, `AnimationRootName` | Map-built pet enchant/reroll station. `EnchanterId` references `configs/enchants.lua` `stations`; `TouchPartName` points at the child part players touch/prompt against. |
| `PODPodium` | none | `AreaId`, `Slot` | Pet-of-the-day display anchor. |
| `ChaseableRegion` | `AreaId`, `ChaseableId` | none | Future chaseable spawn region. |
| `ShopAnchor` | `AnchorId` | `AreaId` | Shop or UI world anchor. |
| `NPCAnchor` | `AnchorId` | `AreaId` | NPC placement anchor. |

## Config Source

- Marker schemas live in `configs/markers.lua`.
- Zone and area ids live in `configs/areas.lua`.
- Breakable world ids currently mirror area ids in `configs/breakables.lua`.
- Egg ids are read from `configs/pets.lua` under `egg_sources`.
- Enchanter ids are read from `configs/enchants.lua` under `stations`.

## Current Synthetic Baseline

`configs/game.lua` sets `map.mode = "auto"` and `features.map_binding = true`.

With no authored tagged map present, `WorldBindingService` creates:

- `Zone` hooks for `spawn_world`, `spawn_island`, `meadow_island`, `Spawn`, and `Meadow`;
- `AreaZone` hooks for `Spawn` and `Meadow`;
- `Workspace.Game.Breakables.Crystals.<AreaId>.SpawnArea` tagged as `SpawnZone`;
- one `EggStand`/`EggSpawnPoint` hook for `basic_egg`; golden/rainbow outcomes are configured as variant rolls on the egg rather than requiring separate map objects;
- per-area `PODPodium` hooks;
- bidirectional `TeleportPad` hooks between `Spawn` and `Meadow`;
- bidirectional `Portal` hooks between `spawn_island` and `meadow_island`.

Current expected play-mode hook counts are `Zone=5`, `AreaZone=2`, `SpawnZone=2`, `EggStand=1`, `PODPodium=2`, `TeleportPad=2`, and `Portal=2`.

Feature services should bind through `WorldBindingService` when possible. Legacy folder/name lookups should remain fallback paths while older systems are migrated.

Breakable spawners honor active-zone dormancy. Spawn is live for the starter loop; non-default areas such as Meadow do not fill until a player enters or travels there.

## Authored Surface Spawners

Real maps can tag a playable surface part, for example `Workspace.Maps.Home.Grass`, as `SpawnZone` instead of creating an invisible rectangular spawn volume. Set `SurfaceOnly = true` so the spawner samples random X/Z candidates, raycasts back onto that same surface, and rejects points outside the surface mesh. Set `ClearanceRadius`/`ClearanceHeight` so candidates overlapping sidewalks, egg platforms, trees, rocks, portals, or other props are discarded before a crystal is placed. Set `ClearanceMode = "ray_samples"` for imported mesh maps where oversized mesh bounding boxes would otherwise block valid grass; the spawner samples downward rays around the candidate and blocks only on actual visible/queryable geometry above or just below the spawn surface. Use `ObstacleRaycastDepth` to keep those rays from seeing hidden geometry beneath the playable surface. Set `BalancedCells = true` to spread picks across low-occupied cells instead of relying on pure random sampling.

Use `scripts/studio/stamp_authored_spawn_surfaces.luau` as the repeatable helper for this. The current NewWorld cleanup copy uses `AreaId = "Spawn"` and `SpawnerId = "spawn_crystals"` on `Workspace.Maps.Home.Grass`.

## Authored Player Spawns

Real maps should stamp a Studio-owned spawn part, usually the map's existing `SpawnLocation`, with `PlayerSpawn` and `AreaId = "Spawn"`. Add `ZoneId = "Spawn"` when the spawn belongs to the same configured area zone. This prevents the template from choosing a spawn by synthetic config coordinates, which may be meaningless after the game engine is overlaid onto an imported map.

## Authored Egg Models

Egg visuals belong to the world builder when a real map is imported. The template should not require every builder to name models exactly `EggSpawnPoint`; instead, a map setup pass stamps selected models/parts with the standard `EggStand` tag and configured attributes. For large decorative hatchers, stamp the egg/rock interaction part rather than the full container model so proximity and billboard UI use the part players actually approach.

Use `scripts/studio/stamp_authored_egg_stands.luau` as the repeatable helper. Edit its mapping table per map, point entries at exact model paths or nearest duplicate-name positions, run with `dry_run = true`, then set `dry_run = false` once the output matches the intended eggs.

The engine supports both modes:

- blank/template maps synthesize invisible `EggStand` hooks and spawn placeholder egg models from config;
- authored maps can tag visible egg models directly, and the engine attaches proximity UI/hatching behavior without cloning another egg on top.

Egg proximity distance is not a marker attribute today. It is controlled globally by `configs/egg_system.lua` `proximity.max_distance`; if the UI triggers from the wrong spot on an authored hatcher, first retag the actual interaction part, then tune the config if needed.

Golden and rainbow eggs are not required as separate authored stands. The current egg pipeline rolls the pet family first and the variant second, so a single authored `basic_egg` stand can still hatch Basic, Golden, or Rainbow outcomes according to `configs/pets.lua` `egg_sources.<id>.variant_rolls`.

## World Builder Rule

For an authored map, place invisible parts with the tags and attributes above. Visual names can change freely. Behavior must remain stable as long as the tags, attributes, and declared contracted names remain intact.

For the current imported enchanter, `scripts/studio/tag_enchanter_station.luau` can tag `Workspace.Enchanter`, set the required attributes, preserve cosmetic floating scripts, and disable the old copied touch gameplay script.
