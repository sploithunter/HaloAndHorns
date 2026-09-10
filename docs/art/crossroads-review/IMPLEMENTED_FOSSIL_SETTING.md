# Hell fossil setting — authored, awaiting native apply

2026-09-08. Config/source implementation is complete; the lead owns native application and visual acceptance. This pass groups existing landscape assets around the placed v2 fossil. It creates no new mesh upload, Terrain paint, water surface, mist, gameplay or travel behavior.

## Composition and native survey

The fossil is centered at X280/Z77 on the dry outer bank, with native bottom ground Y4 and its original yaw85/embedding unchanged. Existing coldfire pines near(284,68)/(291,68), a lava-eye tree near(284,60), and shard/brush near(284,68) already establish the northern background. The added crescent connects that planting to the fossil instead of adding another large tree.

Eleven small cached native models create three levels: a roughly4-stud shard and3.2-stud brush behind the fossil to the east; a2.6-stud bone rock and1.4-stud ash tuft at the rear base; low0.6–1.25-stud fragments/tufts around the north and south ends. The western central viewing face stays empty. Native textures and material colors remain intact. The pale fossil remains taller and lighter than the new immediate dressing.

Read-only native Terrain measurements returned Ground material throughout: (285,79)/(285,74)Y4.4375, (286.5,81.5)Y4.71875, (286.3,76.7)Y4.68125, (283.3,83)Y4.20625, (280.3,84.4)Y4.01875; western points around X276.5–279 returned Y4.0. The north brush moved0.4stud north after bounding review; its final support is remeasured by the baker. No scene instances, terrain or mode were changed during the survey.

Read-only native cache bounding simulation confirms all11models/11MeshParts fit the config pocket X275–289/Z70.5–86. Every rotated bounds box avoids both the protected fossil rectangle X277.8–282.2/Z72.8–81.2 and viewing rectangle X274–282.5/Z74–80. Actual tallest shard height is3.969studs after its width cap. The nearest surveyed station approach was near(270.19,48.33), well north of this pocket. The existing southern connector terminates near(244,73); this pass does not enter it. Full route/barrier visual acceptance remains with the applying lead, rather than treating these bounds checks as avatar-walk validation.

## Rebuild contract

- Config: `configs/realm_crossroads_fossil_setting.json`.
- Source: `tools/realm_crossroads/fossil_setting.luau`, returning `function(world, cfg)`.
- Input world: `Workspace.RealmCrossroadsR4`, local PlaceId0 in Edit only.
- Required placed landmark: `SulfurPoolFossilR11`. Its bounds center must still match the configured anchor within0.5stud, or application stops for recomposition.
- Required ServerStorage cache: `CrossroadsLandscapeAssets`, with `bone_rock`, `ash_tuft`, `dead_brush`, `dark_ice_shard` Models.
- Output sibling: `SulfurFossilSettingR11`, marked `CosmeticOnly`.

The baker builds a detached model, validates every item, and replaces only its own previous output after success. A failed validation destroys the detached candidate and preserves the earlier setting. It measures center plus four inset bounding-footprint corners against real dry Terrain, uses the lowest support sample with0.16stud embed, and rejects large slope differences or unexpected elevation. Each model records its actual ground min/max and source cache name. No terrain is written. Every part is anchored, noncolliding, nontouching, nonqueryable and shadowless; scripts, prompts, click detectors, particles, lights and sounds are stripped from clones. Budget cap16BaseParts; measured cache count11. No per-frame scripts or new assets.

## Checks and remaining acceptance

- StyLua formatting and Selene: pass,0errors/0warnings.
- JSON parse and all entry names/cache references: checked.
- Native read-only rotated bounding simulation:11inside pocket,0view overlaps,0fossil-envelope overlaps.
- Await native application report with11models/11parts and dry-ground sample ranges, then rerun to confirm idempotent count.
- Inspect west/northwest pond approach and south connector: fossil skull/ribs/tail stay readable; no tuft floats on the rising bank; low fragments appear naturally embedded, not evenly spaced edging. Confirm setting remains inside the visible outer barrier and clear of walking routes.
- Native visual review may adjust entry coordinates/heights only in config. Do not enlarge the pool, alter the landmark, or move stations to accommodate dressing.

## Revision2 — one taller backdrop

Lead applied the first11props and reported clean grounding, but the agreed wide camera still showed a bare horizon behind the fossil. Add one cached `withered_sapling` centered(287,95),15studs tall, rotated45degrees. This narrow, open branch silhouette frames the fossil without another dense lava-eye canopy. Config source-local width allowance10studs accommodates the original9.873-stud crown; the separate **world-space** width guard is9studs after rotation. Native read-only calculation gives an8.592×8.592-stud footprint: X282.704–291.296, Z90.704–99.296. Its outerX remains2.704studs inside the barrier atX294 and below the requestedX293limit. Expanded setting guard is X275–292.9/Z70.5–100; fossil/view protection rectangles are unchanged.

Real Terrain center is Y4.8125. Four trunk-support samples are Ground at Y4.69168–4.93333. The tree's configured15percent footprint samples its trunk vicinity instead of treating unsupported crown tips as ground contacts. It uses the same minimum-support/embed method; no invented floor or Terrain writes. Count becomes12models/12parts, within the existing16part ceiling. Selene passes. Revision2 awaits lead native apply and the exact review camera(269,13,61) looking at(280,7,77); check tall framing, visible fossil ribs/skull and grounded trunk.

### Lead native application

Revision2 applied with12models/12parts and unchanged Terrain. Dry ground sample range4.0–4.9863; the15-stud backdrop tree roots sample4.6917–4.9333. Lead inspected the agreed west approach camera: skull/ribs/tail remain visible, low setting and tall backdrop remain separate silhouettes. All dressing is noncolliding and inside the measured outer barrier.
