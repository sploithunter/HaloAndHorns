# Heaven fishing rest shelter — source delivery

2026-09-08. Section 07 items 13/14: source constructed, read-only site survey completed; root owns application, visual review and actual seat tests. No Studio mutation was made by this agent.

## Files and apply order

- `configs/realm_crossroads_fishing_shelter.json`
- `tools/realm_crossroads/fishing_shelter.luau`, returning `function(world,cfg)`

Apply in the existing Edit preview after fishing/shore routes, with `workspace.RealmCrossroadsR4`. Repeated application replaces only `HeavenFishingRestShelterR11`; it refuses to replace a shelter containing an occupied native Seat. Material changes append original cell materials under `ServerStorage.CrossroadsFishingShelterBackup`. No other structure or gameplay service is rebuilt.

## Measured site and architecture

Native read-only terrain rays: fifteen points across X−224…−202, Z−92…−78 and the spur toZ−63 all returned dry ground atY 4. No nearby authored part centers were found in the expanded X−234…−192 / Z−102…−68 search. Existing Cobblestone promenade crosses Z−63. This supports the proposed location; root still checks full roof/foliage bounds in native view.

The shelter occupies **22×14**, centered **(-213,4,-85)**, with a low, shallow bowed slat roof whose highest top is **Y14.2**, safely below the 16 limit. Four timber posts stand on small stone feet; two longitudinal supports, two bowed ribs and four knee braces visibly support the roof. Roof slats use short native chord segments following one consistent curve. Roof is airy timber, contrasting with the Egg Pavilion's stone arch vocabulary. There is no counter, signage, vendor, fish promise, teleporter or new hero ornament.

The **+Z side toward the pond is open**. Two crafted six-stud bench assemblies face the water, each containing **two genuine enabled Seats**. Seat tops are **1.7 studs above sampled ground**, centers 1.525 above ground for the 0.35-thick pad. Native Seat objects provide the visible pads; no coplanar extra cushion is placed over them. Four grounded legs, underframe, slatted back and restrained bronze armrests complete each bench. Four people can sit; no preview dummies occupy these seats.

Two **5×6 dry display/pet bays** in the forward side pockets are marked by invisible noncolliding metadata only, not physical plates. They do not relocate pets or reserve space. The central approach remains open. Two small existing `field_flower_bush` clones decorate the rear post-foot corners; unavailable native cache simply omits those accents. No new organic generation, model upload or external IDs are required.

## Connection and preservation

A nominal **10-stud Cobblestone spur** runs X−218…−208, Z−89…−63, extending into the shelter's central dry floor and joining the existing promenade. Native 4-stud cells make the material edge approximate (potential 12-stud painted width); no floor Part, stacked paving sheet or new elevation is added. Each cell gets nine dry Terrain rays, source-material allowlisting and zero-liquid checks. Only its top solid material changes through `WriteVoxelChannels({SolidMaterial=...})`; neither occupancy channel is written. Full solid/liquid arrays are compared afterward and must match exactly.

Existing pond water/ellipse, ten angler stations, 12-stud promenade, nearby fields, boundary, foliage, rod displays and main architecture remain unchanged. The structure ends atZ−78; existing outer pond promenade is nearZ−65 there, leaving a short independent spur rather than placing posts in the ring.

## Validation and root acceptance

JSON parses; StyLua/Selene pass with zero errors/warnings. Site rays were read-only. Expected return: `seats=4`, `roofTopY=14.2`, a positive first-run `materialCells` count and `occupancyVerifiedUnchanged=true`. Rerun should leave four Seats and add no duplicate geometry or already-Cobblestone material records.

Root should inspect roof/rib/post contact from front, side and rear; native chord joins are actual changing slopes, not overlapped flat floor planes. Sit and exit all four Seats, check back/arm clearance with default and larger supported avatars, and walk the center and both dry side bays. Confirm native touch seating works (`CanTouch=true` on Seats) and no character hits roof members. Walk spur to the pond at 24; compare water and fields before/after. Inspect the two flower/post corners and adjust only if native meshes look crowded. No camera forcing, pet relocation or non-native sitting script is included.

## Applied review and backdrop completion

Root reports the shelter applied successfully: four Seats, 18 material cells, roof top Y14.2 and unchanged occupancy. Native screenshots show the roof and benches correctly. Actual avatar sit/exit testing remains a separate root acceptance check.

The finishing source revision preserves both small flower bushes and adds three existing cached native trees behind the shelter: west cherry at(-227,-106), cloud sapling at(-208,-110), east cherry at(-193,-104). Read-only Terrain rays at all three centers returned dry LeafyGrass at approximately Y4. Each clone is independently grounded by its actual bounding-box bottom with the existing 0.12 embed; no terrain occupancy, geometry or water is changed.

Per-entry horizontal limits are 18,14,18 studs. Both cherry assets naturally have almost equal width and height, so the 18-stud width cap yields approximately 17.89-stud height, including the eastern tree whose preferred target is 20. This deliberately preserves the requested width limit instead of stretching the mesh. The cloud remains 14 studs tall and approximately 10.28 wide. Two existing bushes retain their original 2-stud width limit.

Backdrop bounds are centered on their configured X/Z coordinates. An installer assertion requires each entire canopy to remain at least 2 studs behind the roof rear edge Z−92; native source proportions yield front edges approximately−99.89,−106.34,−97.89. The three canopies therefore avoid the roof, forward seat access, dry pet bays, pond and southern promenade/spur. All cloned parts are anchored and noncolliding; source textures remain intact. Root should reapply the same installer/config and inspect the completed silhouette from the pond. No new mesh generation or uploads are required. JSON validation, StyLua and Selene pass for this revision.
