# Farm and Fight import — 2026-09-09

R11 is now imported into Farm and Fight (place 77766176054993), saved through Studio **Save to Roblox** at 07:11:05 local time. No Publish action was performed. The original preview was saved and closed; Farm remains open in Edit.

## Placement and contents

`Workspace.RealmCrossroadsR4` is translated by (-8192, 0, 0), outside existing maps and mission slots. Keep it top-level: putting it under Maps would expose decorative specimens to broad gameplay scanners. Configuration: `configs/realm_crossroads_farm_import.json`. The source package is `assets/source/maps/realm_crossroads/CrossroadsFarmTransfer-R11.rbxm`; build it with `package_farm_import.luau` and apply it once with `install_farm_import.luau`, both under `tools/realm_crossroads`. These scripts return functions accepting the config (installer additionally accepts the deserialized package).

The importer checks Edit mode, place identity, name collisions, empty destination geometry and Terrain. It copies native Terrain with geometry, translates bulwark pivot attributes and absolute cosmetic field/fish origins, and retains an empty destination Terrain backup for rollback. Terrain bounds are inclusive cell coordinates in config; destination stud bounds are (-8512,-64,-192) through exclusive (-7868,132,196).

Four visual clients are installed: CrossroadsCrestLight, ConfluenceSurfaceFlow, CrossroadsVisualFXClient and CrossroadsPondLife. The latter two have matching ReplicatedStorage folders. Decorative fish are enabled in the destination, with no catch or reward behavior. Original authoring inputs/caches are inert in ServerStorage.CrossroadsAuthoringR11. Those archives retain source coordinates and original cache paths; do not rerun source bakers directly in Farm.

The generic preview GUI, global preview movement/tint override, duplicate preview config and interaction rehearsal client are excluded. Farm global Lighting/water, existing maps, game scripts and spawn routing are preserved. The transferred spawn is disabled, all 21 prompts are disabled, and GameplayConnected remains false. Resolve authored anchors from their current world transforms for future gameplay integration.

## Verification

Source and destination both have 5,518 BaseParts, 40 Seats, 18 internal RodDisplay references, 72,742 occupied Terrain cells including 744 Water cells, and matching ordered material/occupancy hash 1203769828. All 37 bulwark stored pivots were translated. Runtime streaming warmup reached two visual fields / 22 sources and two nearby decorative fish. No Crossroads script error was observed. Farm's player profile timed out, so this was a cosmetic integration smoke test, not a complete gameplay test.

## Recovery and next work

Before any rollback, stop Play and preserve subsequent edits. Remove only the imported root, four named visual clients and two named runtime folders; restore DestinationTerrainBeforeImport at the configured minimum cell plus translation/4 with PasteRegion(..., true). Remove the authoring archive last. The installer performs this cleanup automatically if its install operation fails.

Next: bind spawn and gate travel, coin/weekly-egg activity, arena containment/alliances, leaderboards and fishing to existing server-authoritative services. See GAMEPLAY_INTEGRATION.md. Cosmetic fish are not catch targets. Do not enable all prompts or tag all decorative models to bypass those bindings.

The isolated R11 source was re-saved using native Studio Save to File before closing: 2,251,742 bytes, SHA256 `43ee2453b4b5b37a861f012ba6dcd324e56ec57dc99b93cf863911bad5046151`. Earlier checkpoint hashes in REBUILD_QA and IMPLEMENTATION_STATUS describe the prior serialized checkpoint; no new full source replay is claimed for this native re-save. The transfer package was serialized from the validated open source before closing.

## Midpoint relocation and paving correction

2026-09-09: User requested the gap between Home and old Merge instead of hiding remote maps. Moved from X -4096 to -8192 with `relocate_farm_import.luau`; target parts and Terrain were empty. Restored the original location from its empty pre-import Terrain backup. Stored bulwark pivots and both FX/fish origins moved with native geometry. No visibility client was installed and streaming settings remain unchanged.

`configs/realm_crossroads_surface_finish.json` and `finish_imported_surfaces.luau` replace Grass with Ground beneath named pavers/spawn, preserving occupancy. Pavers changed 438 voxels; entry steps/ramps/apron changed another 126 (564 total). Both reruns changed zero. Original Terrain is archived under TerrainBeforeSurfaceFinish at the new location. TerrainBeforeRelocation retains the previous-location terrain and translation metadata. 5,518 BaseParts remain. Future fresh import: use the updated import config, then apply surface finish. The portable original package and isolated source remain the original art inputs.

Terrain GrassLength was changed through Studio Properties from 0.7 to 0.25 (global across this place, recorded in surface config); Decoration stays enabled. These properties are Studio UI settings and cannot be read by the ordinary Luau execution context. Do not probe them with unguarded runtime commands. The surface/relocation scripts and surface config are also archived as inert StringValues in Farm ServerStorage.

Native Play review confirmed clear central paving and shortened grass. All 72,742 occupied cells / 744 water cells remain at the midpoint; previous location has zero occupied cells. Heaven/Hell and old Merge had zero client BaseParts, while Home/FuturePath still retained 1,360/230; increased distance must not be reported as a memory-unloading fix. Full CI passed 2,842/2,842 tests; both new tools passed StyLua/Selene.

2026-09-09 follow-up: user requested complete temporary removal of Grass Terrain after residual grass remained in the Bragg court. Surface config now sets replace_all_grass=true for the bounded Crossroads region. Replaced the remaining 960 voxels with Ground; zero Grass remains. Occupancy stays 72,742, Water 744, rerun changes zero. Existing geometry and outside maps are unchanged; original Terrain backup remains available.

### Final-terrain foliage pass

After importing and completing Terrain changes, run `tools/realm_crossroads/ground_foliage.luau`
with `(Workspace.RealmCrossroadsR4, decoded configs/realm_crossroads_foliage_grounding.json)` in Edit.
It operates in the imported models' world coordinates and only lowers floating perimeter models.
Use a fresh ModuleScript instance when refreshing the helper source. Its optional third `true`
argument audits without mutation. The 2026-09-09 pass lowered 51 of 225 models; a second pass
moved none. Keep the original-pivot attributes for rollback and save the place after verification.
