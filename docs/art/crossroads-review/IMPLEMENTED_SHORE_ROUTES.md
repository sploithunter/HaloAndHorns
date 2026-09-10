# Shore circulation — material-only route installer

Source and **read-only native dry-run** completed 2026-09-08. The lead subsequently applied the first 410 cells successfully, confirmed both occupancy channels unchanged, and moved the parapet/archived six garden items. A further canopy-mask refinement is ready for the lead to apply. See [the dimensioned route diagram](shore-routes.svg) and [native audit](shore-routes-dry-run.json).

## Concrete implementation

`configs/realm_crossroads_polish_shore_routes.json` names `tools/realm_crossroads/polish_shore_routes.luau`, returning `function(world,cfg)`. `dry_run=true` makes **no datamodel writes**, including no attributes or backups. The lead has set the on-disk config to `dry_run=false` for application; leave that state intact. For read-only audit, override a decoded copy in memory to true. The pass is Edit-only and restricted to PlaceId0.

For each pond, the installer reads **actual rotated FishingStationN CFrames and sizes**, builds the convex outer envelope of all deck corners, then selects a nominal **12-stud strip outside that envelope** plus 12-stud north/south connectors. This includes existing walkable timber aprons and shared garden paving as parts of circulation. Those surfaces remain untouched. It paints only exposed, dry Terrain top-solid cells; it does not promise an uninterrupted 12-stud-wide band of identical stone.

Chosen material is existing native **Cobblestone**, with its current color. Read-only native terrain audit across X−304…304, Y−8…24, Z−160…160 found LeafyGrass13,756, Ground14,204, Grass1,152, Rock30, Water744 occupied cells; no Cobblestone or Pavement in that surveyed slice. **No SetMaterialColor call occurs**, including on the newly used material; Grass/Ground/water/global lighting remain unchanged.

## Exact pinches and the authorized correction

- Heaven station1 centerX−171, rear deck edgeX−165. Existing Coin Garden OuterParapet was centeredX−158, width1.3, west faceX−158.65, leaving only **6.35 studs**. Its west apron ends≈X−160.96, leaving only2.31 studs beyond the apron. Three collidable planters centeredX−160/Z−5,23,49 further blocked this route.
- The lead explicitly authorized moving the same OuterParapet to **X−152.35**, reducing world-X thickness to **0.7**, keeping Y/Z, length, height and appearance. East face becomes−152, preserving the **64×90 field X−152…−88**; west face−152.7 leaves **12.3 studs behind the deck**. Native CFrame was verified identity, and installer asserts localX still aligns with worldX before applying. Original CFrame/Size are saved in attributes.
- The three conflicting EdgePlanter Parts and their three matching `softglow_bloom` Models are archived intact in ServerStorage; removing only the bases would leave floating flowers. No other garden décor is moved. All six preserve original-parent metadata.
- Hell station5 already corrected to centerX217: rear edgeX211, façade atX199, leaving **12 studs**. This strip is the route itself and may receive material paint; no props/walls are added there.
- Hell east station1 rear deck edgeX279; apron ends≈X283.04; outer wall inner face≈X294. A full12stud band wholly **beyond the apron** would not fit (10.96studs). The approved mixed-surface loop spans roughlyX279…291, incorporating the safe apron.
- The eastern Hell bank already grades upward: native raycasts returned Y4@X280,4.25@284,5@288,5.4@290,5.81@292. The route uses this existing mild grade, with dry-ground guard Y3.7…6.15 and normalY≥0.92. **No occupancy/grading work occurs.**

Parapet end positions remain Z−34 and70; they are not extended into northern pavilion or southern gathering floor. Material paint skips existing architecture instead of layering additional path slabs. Root should still inspect the shifted wall's end join and adjacent existing FieldKerb after application.

## Per-cell guards and water guarantee

Each candidate4×4XZ cell receives nine Terrain-only downward samples (corners, edges, center), excluding water and ground outside the permitted Y/normal range. Cells overlapping protected Coin Garden field, deck/approach structure, architecture, collidable invisible barriers or visible low flora bounds remain unpainted. The bounding-box guard remains conservative for low decorations and collision geometry. Following native visual review, **noncolliding descendants of CrossroadsLandscapeR8.PerimeterFlora are exempt** so large tree-canopy bounds do not leave giant grass holes in a valid route. Collidable tree parts still block paint. No tree is moved or made noncolliding by this exemption. Nearshore rocks/flowers outside that specified perimeter group retain their footprint protection.

The installer reads separate `SolidMaterial`, `SolidOccupancy`, `LiquidOccupancy` arrays. A cell changes only if its top existing solid material is allowlisted and its column has no liquid occupancy. It calls **WriteVoxelChannels with SolidMaterial only**, omitting both occupancy channels. After application it rereads and compares **every solid/liquid occupancy sample** in each affected region; any difference raises an error. No FillRegion, FillBlock, WriteVoxels, water recolor, global terrain recolor, new floor Part or terrain resizing occurs. This uses Roblox's documented support for writing an individual voxel channel. [Official Terrain API](https://create.roblox.com/docs/reference/engine/classes/Terrain#WriteVoxelChannels).

Original changed-cell world-grid coordinates and material names are appended once into per-pond StringValues under `ServerStorage.CrossroadsShoreRoutesBackup`, alongside archived planter/flower originals. Repeating the same pass sees already-painted cells and does not overwrite original material history. Reversing a material pass should restore **only saved SolidMaterial values**, not a stale all-channel terrain snapshot. Parapet restoration uses its stored attributes; archived planters/flowers retain original parents.

## Native read-only dry-run result

Audit executed against the current Edit map with the parapet/planter changes applied **virtually in guards only**:

| Pond | Stations | Existing aprons preserved | Eligible top cells | Structure-protected cells | Wet/grade failures | Protected-field paint |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Heaven |10|10|199|173|0|0|
| Hell |8|7|211|121|0|0|

No actual native mutation has been made by this agent; the lead applied this first 410-cell pass and verified occupancy unchanged. Counts are not a physical width certification; many excluded cells already have usable deck, approach or paving, while others hold scenery. The returned blocker paths and hull points identify those distinctions for review. All18 stations and17 aprons were found in the actual native map.

## Connection diagram / remaining QA

- Heaven north connector: X−188…−156 atZ−61, joining the existing pavilion floor's west edge. South: X−188…−158 atZ82, joining gathering-terrace west edge. Existing architectural surfaces are preserved.
- Hell north: (190,−35)→(205,−35)→(211,−54)→(244,−57). South: (190,51)→(205,51)→(211,70)→(244,73). These skirt stand ends and connect to the outside dock envelope. No connector travels through arena bounds.
- Hull-based stone selection uses actual rotated dock envelopes; it does not cut diagonals across a pier corner using a guessed ellipse offset.

After apply, verify `occupancyVerifiedUnchanged=true`, nominal12.3/12stud critical gaps, unchanged water/mist/rods, and six intact archived garden items. Walk the full mixed-material loop on both sides at 24 with occupied angler proxies and two opposing pedestrians, including Heaven's shifted-wall ends and Hell's mild eastern grade. Compare matched overhead and low-angle screenshots; note any conservatively unpainted scenery pocket that looks like an unintended break. Do not widen the island or move more assets solely to make the cobblestone color perfectly continuous. Full10/8-player capacity and path usability still require this native walkthrough.

Source JSON parses; StyLua and Selene pass with zero errors/warnings. Native dry-run exercised hull construction, all guards, lookups and route generation. The lead confirmed material-only writing and occupancy post-check passed for the initial 410 cells; the canopy refinement awaits reapplication.

## Canopy refinement after native review

Root found large unpainted gaps on the Hell eastern/northern route because noncolliding tree MeshPart bounding boxes included wide overhead crowns. Config now contains `noncolliding_canopy_exclusions=[["CrossroadsLandscapeR8","PerimeterFlora"]]`. Read-only audit against the already-applied map reports **34 additional Heaven cells and 56 Hell cells**, plus the existing 199/211. There are zero new ground/water/field failures, and zero additional structural archives. Expected aggregate after reapplication is **233 Heaven +267 Hell =500 painted cells** for this unchanged route configuration. Other structure/nearshore décor guards remain active. No widening, occupancy change, canopy removal, collision setting or global color change accompanies this fix.
