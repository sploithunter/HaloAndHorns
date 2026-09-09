# Farm and Fight import — 2026-09-09

R11 is now imported into Farm and Fight (place 77766176054993), saved through Studio **Save to Roblox** at 07:11:05 local time. No Publish action was performed. The original preview was saved and closed; Farm remains open in Edit.

## Placement and contents

`Workspace.RealmCrossroadsR4` is translated by (-4096, 0, 0), outside existing maps and mission slots. Keep it top-level: putting it under Maps would expose decorative specimens to broad gameplay scanners. Configuration: `configs/realm_crossroads_farm_import.json`. The source package is `assets/source/maps/realm_crossroads/CrossroadsFarmTransfer-R11.rbxm`; build it with `package_farm_import.luau` and apply it once with `install_farm_import.luau`, both under `tools/realm_crossroads`. These scripts return functions accepting the config (installer additionally accepts the deserialized package).

The importer checks Edit mode, place identity, name collisions, empty destination geometry and Terrain. It copies native Terrain with geometry, translates bulwark pivot attributes and absolute cosmetic field/fish origins, and retains an empty destination Terrain backup for rollback. Terrain bounds are inclusive cell coordinates in config; destination stud bounds are (-4416,-64,-192) through exclusive (-3772,132,196).

Four visual clients are installed: CrossroadsCrestLight, ConfluenceSurfaceFlow, CrossroadsVisualFXClient and CrossroadsPondLife. The latter two have matching ReplicatedStorage folders. Decorative fish are enabled in the destination, with no catch or reward behavior. Original authoring inputs/caches are inert in ServerStorage.CrossroadsAuthoringR11. Those archives retain source coordinates and original cache paths; do not rerun source bakers directly in Farm.

The generic preview GUI, global preview movement/tint override, duplicate preview config and interaction rehearsal client are excluded. Farm global Lighting/water, existing maps, game scripts and spawn routing are preserved. The transferred spawn is disabled, all 21 prompts are disabled, and GameplayConnected remains false. Resolve authored anchors from their current world transforms for future gameplay integration.

## Verification

Source and destination both have 5,518 BaseParts, 40 Seats, 18 internal RodDisplay references, 72,742 occupied Terrain cells including 744 Water cells, and matching ordered material/occupancy hash 1203769828. All 37 bulwark stored pivots were translated. Runtime streaming warmup reached two visual fields / 22 sources and two nearby decorative fish. No Crossroads script error was observed. Farm's player profile timed out, so this was a cosmetic integration smoke test, not a complete gameplay test.

## Recovery and next work

Before any rollback, stop Play and preserve subsequent edits. Remove only the imported root, four named visual clients and two named runtime folders; restore DestinationTerrainBeforeImport at the configured minimum cell plus translation/4 with PasteRegion(..., true). Remove the authoring archive last. The installer performs this cleanup automatically if its install operation fails.

Next: bind spawn and gate travel, coin/weekly-egg activity, arena containment/alliances, leaderboards and fishing to existing server-authoritative services. See GAMEPLAY_INTEGRATION.md. Cosmetic fish are not catch targets. Do not enable all prompts or tag all decorative models to bypass those bindings.

The isolated R11 source was re-saved using native Studio Save to File before closing: 2,251,742 bytes, SHA256 `43ee2453b4b5b37a861f012ba6dcd324e56ec57dc99b93cf863911bad5046151`. Earlier checkpoint hashes in REBUILD_QA and IMPLEMENTATION_STATUS describe the prior serialized checkpoint; no new full source replay is claimed for this native re-save. The transfer package was serialized from the validated open source before closing.
