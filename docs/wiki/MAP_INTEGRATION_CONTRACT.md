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

The Merge an Egg venue follows this split without joining the general map-hook registry. Studio
owns the complete `Workspace.Maps.MergeEggRealm`: ten atomic bay Models under `Bays` plus the
shared `CentralHall`. The current hall contract is a sunken mall with ten bay approaches, opposing
lava/water end plazas, a central convergence landmark, bridges, and a lower waterfall park. Every
bay carries `MergeEggBayId` and the normal named parts (`PlayerSpawn`,
controls, `ArenaBounds`, one enemy spawn area, and one finish line). Runtime validates those hooks
and owns temporary claims, but never clones, transforms, recolors, decorates, or replaces map
geometry. To rebuild the blockout deliberately, run the one-bay source pass followed by
`scripts/studio/bake_merge_egg_realm.luau`; the bake consumes the temporary
`Workspace.Maps.MergeEggPrototype` source and stamps `MergeEggAuthoredRealm = true`,
`UsesTileSystem = false`, and `UsesTileStreaming = false` on the permanent root. Runtime fails
closed if that authored root or any contracted bay is missing. See
[Merge an Egg Prototype](MERGE_EGG_PROTOTYPE.md).

Claim displays are authored geometry too. A bay may expose more than one BasePart tagged with
`MergeEggBayClaimPad`; each must contain `MergeEggBayClaimPrompt` and
`BayClaimSurface.Label`. Runtime binds every such fixture to the same claim, owner-name, and release
state without moving it. The current bay pattern has one display on the upper terrace and another
at the lower stair landing.

The shipping extraction now also has a dedicated place role: `configs/places.lua` maps the main
place (`77766176054993`) and Merge place (`84544653387905`) inside universe `10307183003`.
`PlaceRuntime` is the only code seam that identifies those roles. In the Merge role, unrelated
Home systems (crystals/breakables, ordinary world binding, zone unlock prompts, egg stands,
hoverboards, and Home daily-reward fixtures) fail closed rather than inferring behavior from
coordinates. Entry waits for the player's profile before creating the isolated Merge wallet and
session; cross-place exit returns to the configured main place.

The dedicated map deliberately separates portable gameplay hooks from finished art. Bay Models
under `Workspace.Maps.MergeEggRealm.Bays` retain the stable spawn, bounds, lines, controls, and
session attributes. Finished floor fixtures live in `Workspace.GeneratedMap_MergeEggVoxel`.
At runtime the matching authored 4×4 board is adopted as the bay's single `MergeBoard`, and
interaction pads are aligned to the matching authored hatcher stands. The portable hovering board
is removed for that runtime session; drag/drop, inventory sync, tutorial targets, and Equip Best
therefore all resolve the same visible floor geometry. The board's saved Studio transform is part
of the authored-map contract: runtime may adopt and reparent it, but must not reposition it. The
central nine-card management control is the playable UI. The oversized legacy `EggCreateControl`
and `EggBaseUpgradeControl` remain only as invisible compatibility anchors and must never render or
accept input when the central wall exists.

Merge edge towers follow the same art-versus-hook boundary. Studio owns the two armored pad Models
per bay and their invisible `TowerAnchor` parts under
`Workspace.GeneratedMap_MergeEggVoxel.TowerStations`; it must not retain visible cannon review
objects. Rojo owns the cannon templates in `assets/place/Models.rbxm` at
`Models.MergeCannons/<Role>/<Tier>`. Runtime clones and grounds a selected template through
`src/Shared/Game/MergeTowerModels.lua`, so changing tower role or tier never mutates or duplicates
the permanent map. A claimed bay currently grounds the current-art Repulsor at `tier_1_scale`
and lofts a labeled sphere from each pad; the cannon aims along the launch tangent. Upgrades
and role acquisition stay later.

Each selected bay also derives runtime containment from its authored `ArenaBounds` and
`LandStrip`. Two 64-stud invisible side walls and one enemy-end wall are collidable, while the
player-end entrance remains open to the public mall. Their inner faces align with the authored
play rectangle, so decorative low sightline walls cannot be jumped to escape the terrace. Physical
currency uses the same per-session `ArenaBounds` with an inset reflected landing path: a pop that
would cross an edge visibly hits that edge and returns inside. Never call the Merge drop-options
resolver without its player session record, or it will lose the selected bay reference.

An AI-assisted deployment pass may normalize the Studio-owned map before Rojo sync: quarantine old scripts, regroup art, rename ambiguous imported objects, add invisible helper parts, and stamp tags/attributes. That is considered part of map integration, not a burden on the builder, as long as original art is preserved and the resulting hook contract is documented.

### Imported landmark visuals

Studio owns landmark placement and non-code effects, but the mesh source and asset identity are
repo-owned configuration. Do not rely on a Studio `RBX_ReimportId` as source control. For durable
landmarks, retain the source under `assets/source/`, generate a welded/cleaned Roblox-budget export,
record its group-owned IDs and target paths in config, then apply it through one repeatable Studio
script. The current contract is `src/Shared/Assets/LandmarkAssets.lua` plus
`scripts/studio/repair_landmarks.luau`.

The repair path replaces only MeshPart visuals. It preserves authored children such as
`NativeFX`, `AscensionAltarHost`, `LightEmit`, and `HeavenMissionDoor`, as well as the original
visual bounds. Because Roblox protects `RBX_ReimportId` from ordinary writes, the script moves
those preserved children into a plain canonical Model rather than attempting to clear the imported
root in place. Multi-part scenes keep a configured per-MeshPart budget (currently four parts at
10k each); the limit must never be applied once to the entire scene. This prevents a future Studio
reimport from silently restoring unsafe source meshes without throwing away landmark detail.

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
- `AwardPodium` (`BoardId` = origin leaderboard id)
- `LeaderboardBoard` (`BoardId` = board id; SurfaceGui on the sign `Screen`)
- `ChallengeGuide` (`GuideMode` = `range` / `training_ground`)
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

### Homeworld challenge fixtures

During the Hall repair rollback, the original Range and Training Ground fixture Instances were
moved in Edit mode to `Workspace.Maps.Home.ChallengeBindings`. Range is positioned in Lava and
Training Ground in Desert. Each fixture remains a complete authored unit: the invisible
`MissionDoor` pad, visual arch and `ArchLightning` markers, title, `ChallengeGuide`, and
`LeaderboardBoard`. Runtime code continues to discover these by tags/attributes and must not
depend on their former `FuturePath` paths. Run
`scripts/studio/relocate_home_challenge_gates.luau` to reproduce or audit the move; it reparents
the originals and never clones them. Historical Hall wiring scripts detect the destination and
must not recreate a second pair in Hall.

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

Large authored play fields may add `SlotLayout = "random"` and a local-space polygon string in
`OutlinePath` (`"x,z;x,z;..."`). The shared breakable spawner then samples non-lattice candidates
inside that polygon while preserving normal occupancy/min-distance checks. A presentation system
may consume the same outline only through a feature-specific opt-in tag; generic `SpawnZone`
markers must not acquire editor-style runtime visuals globally.

`ZoneService` consumes the zone tree plus bound `TeleportPad`/`Portal` hooks. It validates unlocks on the server, persists `GameData.UnlockedAreas`, moves the character to the target zone spawn, and updates the active area through `WorldBindingService`.

Travel hooks also get a server-created `ProximityPrompt` named `ZoneTravelPrompt` for paid locked destinations. The client hides this prompt for destinations the local player already owns, so normal unlocked travel remains touch-only. Pressing `E` on a visible locked prompt attempts the paid unlock before travel. Touching a locked hook still returns `ZoneTravelResult.reason = "locked"` and the client shows a visible locked-area notice with the configured cost.

For manual portal testing, use the admin panel's developer controls to toggle, lock, paid-unlock, or bypass-unlock `Meadow`. Admin locking removes the persisted unlocked area without refunding, which lets the same player repeatedly test locked and unlocked portal states.

Spawn placement is resolved from the live map before falling back to configured synthetic coordinates. `WorldBindingService:GetSpawnCFrameForZone` first uses a `PlayerSpawn` hook for the area when one exists, then the area's authored `AreaZone` center, raycasts down to real floor geometry while excluding marker parts, and returns a safe above-floor CFrame. If no floor hit is found, it falls back to the area's `SpawnZone`, then finally to config `synthetic.spawn_position`. This keeps Studio-authored maps portable when islands move. `ZoneService:PlacePlayerAtZoneSpawn` treats that CFrame as an anchor and distributes normal arrivals among deterministic, occupancy-aware ring slots configured by `areas.player_spawn_spread`; `spread = false` remains an explicit exact-anchor escape hatch for special scripted placement. In `NewWorld Map Cleanup Copy`, `Workspace.SpawnLocation` is stamped as `PlayerSpawn` with `AreaId = "Spawn"` so the template does not fall back to the old baseplate origin.

Active-zone dormancy is implemented for breakable spawning: Spawn is live for the starter loop, while non-default configured areas stay dormant until a player enters/travels there. Entering/traveling to an area fills that area's configured spawner.

When authored `TeleportPad`/`Portal` hooks already exist for a source/target pair, `WorldBindingService` does not create duplicate synthetic travel hooks.

Pet enchant/reroll stations are authored map fixtures. Tag the station model or its touch part with `EnchanterStation`, set `EnchanterId` to a key in `configs/enchants.lua` `stations`, and optionally set `TouchPartName` if the touch volume is a named child such as `EnchantTouchPart`. Cosmetic movement scripts can remain inside the model; gameplay touch/prompt behavior belongs to `EnchantService`. The current ColorfulClickers-imported `Workspace.Enchanter` uses `EnchanterId = "basic_enchanter"` and keeps its floating scripts, while the copied touch script is disabled because the service owns activation. Use `scripts/studio/tag_enchanter_station.luau` to repeat that setup after reimporting the model.

Potion tents follow the same fixture rule. `configs/potions.lua` contracts
`HomePotionShop`, `HeavenPotionShop`, and `HellPotionShop`; `PotionShopService` finds every matching
model under Workspace and attaches its prompt to the authored `PotionBannerLabel`. The five current
tents (Home plus two Heaven and two Hell layers) carry art and lettering only. Pricing, stock,
proximity authorization, inventory mutation, and currency mutation remain config/service-owned.

Builder-authored egg visuals are map fixtures too. A visible model can have any builder-friendly name, then a setup pass stamps the intended interaction anchor part with `EggStand`, `EggId`/`EggType`, optional `AreaId`/`SpawnId`, `AuthoredVisual = true`, and `SpawnMode = "authored"`. For large hatchers, tag the egg/rock part players approach rather than the full decorative container so proximity distance and billboards attach to the right spot. `scripts/studio/audit_authored_map_candidates.luau` lists likely imported objects, and `scripts/studio/stamp_authored_egg_stands.luau` is the current repeatable helper for the assisted mapping pass. Blank/template maps still use synthetic invisible egg hooks and spawned placeholder egg models.

Flora follows an anchor-only authored contract. Each invisible `FloraAnchor` BasePart owns `Kind`,
`Variant`, and authored-height `Scale`; `FloraService` selects and places the runtime model from
`configs/flora.lua`. Do not retain a copied visible tree/rock/plant beside the anchor. In particular,
an `ObjectValue` named `FloraSpawn` linking an old visual to its anchor is migration metadata, not
permission for both objects to survive. Layer 3 removes those linked visuals through
`scripts/studio/remove_layer3_authored_flora_visuals.luau`; its exact runtime dressing can be
inspected with `scripts/studio/preview_layer3_flora.luau`, whose `_Layer3FloraPreview` folders must
be deleted before saving the place.

Ambient fauna use invisible BaseParts tagged `AmbientFaunaAnchor`. Each anchor supplies
`ModelName`, `Motion` (`hover` or `ground`), `MoveRadius` (or elliptical `PathRadiusX` and
`PathRadiusZ`), `HoverHeight`, `BobHeight`, `Speed`, `VisualSize`, and `Phase`;
`AmbientFaunaService` clones the matching
`Assets.Models.AmbientFauna` visual and owns its deterministic 30 Hz motion. These models are
environmental dressing only: every part is anchored and non-colliding/non-touching/non-queryable,
and fauna have no health, target, damage, or drop hooks. The repeatable Layer 3 authoring pass is
`scripts/studio/place_layer3_ambient_fauna_anchors.luau`.

Fauna face the tangent of their authored route and layer their motion through the shared `Gait`
module used by pets and enemies; do not derive orientation directly from elapsed time. Heaven 3's
three Bloomwing Butterflies are deliberately miniature (0.85–1.15 studs) and confined to distinct
loops within the authored garden rather than the player walkway.

An imported fauna mesh that faces backward in local space may set `FacingYawDegrees` on its anchor;
the motion service applies that visual-only correction after tangent facing. Pearlback Snails use
180 degrees. Do not reverse their path or special-case the shared motion math.

Dark textured dressing may opt into `configs/flora.lua` `glow_models`. The shared
`EnvironmentGlow` treatment changes MeshParts to Neon so colored texture texels lift while black
texels remain dark, then optionally attaches one no-shadow `PointLight` to the model. Hell 3 uses
this selectively for red/purple accent flora and its two fauna families. Keep persistent dressing
lights below combat-FX brightness, use a range smaller than a moving fauna route, and prefer
Neon-only entries in dense plant clusters instead of giving every prop a dynamic light.

The physical realm portals may temporarily bypass their per-player gate through
`layers.realm_portals.testing_open_layers`. This switch affects only the named portal geometry and
client lock presentation; it must not modify `layers.access`, `LayerAccess.canAccess`, World
Travel, or persisted player progression. Production keeps that table empty so Heaven/Hell 3
stay locked until Level 21.

`CurrentLayer` and the character's nearest stacked-map Y offset are one invariant. A character
whose logical layer is `hell_3` but whose body is at Home will see Home eggs under Hell lighting,
and Home's default `Spawn` unlock will masquerade as an unlocked Hell area. `LayerService` streams
and restores the current layer after respawn and also runs a one-second reconciliation check for
other split-state paths. Mission characters are excluded because their instance geometry does not
live on the realm stack.

Ascension altars use an invisible child part named `AscensionAltarHost`, tagged
`AscensionAltar`, as their interaction contract. `AscensionAltarService` creates the prompt and
level-training behavior at that host; altar meshes and `NativeFX` remain Studio-owned. Home's
replacement altar is normalized by `scripts/studio/wire_home_ascension_altar.luau`, which maps the
buried old altar's complete effect assembly into the replacement host's coordinate space and
removes the gameplay tag from the buried host. The wiring pass anchors every replacement BasePart
so the visible imported mesh cannot enter physics and drift away from the world-space beam. It
preserves authored collision settings. The native interaction prompt mounts to a runtime Attachment
at the configurable `level_track.altar.prompt_world_offset`, keeping it below the quest HUD and
ASCEND nudge without moving the host or its effects. World-space placement avoids screen-dependent
pixel tuning. Reimports must preserve the host and `NativeFX`.

For the NewWorld migration, `Workspace.Maps.Home.LegacyEggHatchers.BasicEarth.EggModel` is the authored `basic_egg` stand. Golden hatching is not modeled as a separate default egg stand; it is controlled by `egg_sources.<id>.variant_rolls` and `rarity_rates`. Egg previews always show the first-stage pet roll in basic form; golden/rainbow is a second hidden variant roll. Premium/no-basic egg settings can use `variant_rolls.allow_basic = false` and optional `variant_rolls.cost_multiplier` to price the hidden variant mode from the base egg cost.

For NewWorld breakables, `Workspace.Maps.Home.Grass` is stamped as the authored `Spawn` crystal `SpawnZone`. It uses surface raycasting plus `ClearanceMode = "ray_samples"` so crystals/coins appear on playable grass and avoid the hatcher, sidewalks, trees, rocks, portals, and other map art without letting oversized imported mesh bounds falsely block open grass.

For imported enchanter cosmetics such as `FloatingCoinScript`, leave `configs/enchants.lua` `stations.<id>.animation.active_when_near = false` unless the designer explicitly wants proximity-driven ambient animation. The current model expects its floating scripts to run continuously.

Successful rerolls can also trigger station-authored VFX through `stations.<id>.animation.lightning`. The default `basic_enchanter` effect temporarily clones the selected pet from preloaded pet assets, places it at the station, and calls the reusable `Shared.Effects.EnchantLightning` module. That module fires ColorfulClickers-style procedural neon cylinder bolts from configured origin parts into the cloned pet's primary/first part. Use `origin_part_paths` for exact station-relative child paths, such as `RuneStone1.Rune`, when an imported model has extra parts with the same name; use `origin_part_name` or `origin_part_names` only when name-based discovery is unambiguous. Designers can swap the top endpoint contract to a single named part such as `LightningTop` or an explicit `origin_part_paths` list without changing service code. The station config owns colors, duration, curve, jitter/radius, thickness, core/glow intensity, strand/segment counts, result delay, temporary pet placement, and independent thunder audio lifetime.

## Hall of Worlds Studio layout

The baked `Workspace.Maps.FuturePath` Hall of Worlds is Studio-owned geometry positioned on the
positive X lane, approximately X 1,478–3,090, rather than on the realm stack's Z lane. Home remains
near Y 0; Heaven layers occupy Y +2,000 through +10,000 and Hell layers occupy Y -2,000 through
-10,000. Heaven 3–5 are current geometry copies of Heaven 2, and Hell 3–5 are geometry copies of
Hell 2 pending their own authored content.

Moving a Model does not move Roblox voxel Terrain. After importing or relocating a baked map,
inspect `Workspace.Terrain` independently. The initial Hall integration left one broad horizontal
terrain island and two malformed vertical terrain sheets far outside every authored map bound;
those orphan components were removed in Studio on 2026-08-18. Do not recreate them when rerunning
the map generator or applying the Hall lane offset.

The Heaven 3 duplication omitted the south/entry terrain section present in Heaven 2. The bounded,
additive repair is `scripts/studio/restore_heaven3_missing_terrain.luau`: it copies only non-Air
source voxels at the exact +2,000-stud layer offset and is safe to rerun. The audited target changed
from 0 to 1,703 occupied voxels; Hell 3 had no corresponding deficit and must not be pasted over.

## Links

- [Foundation & Requirements K8](../FOUNDATION_AND_REQUIREMENTS.md)
- [Implementation Plan Phase 1](../IMPLEMENTATION_PLAN.md)
- [Map Marker Reference](../MAP_MARKER_REFERENCE.md)
- [Decisions](DECISIONS.md)
