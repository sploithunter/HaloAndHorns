# Fishing polish construction pass — delivery contract

2026-09-08. **Source implemented; live application and visual acceptance are owned by the lead agent.** No Studio tool was called by this section agent. Do not treat source checks as completed in-map review.

## Files

- `configs/realm_crossroads_polish_fishing.json`: all art palettes, dimensions, placement corrections, cache names, protected extents and integration tunables.
- `tools/realm_crossroads/polish_fishing.luau`: `return function(world, cfg)` Edit-only, PlaceId=0 when preview_only; operates on existing `world.CrossroadsFishingR10`.
- This delivery note. No gameplay service, shared registry or other agent's files edited.

## What the pass actually constructs

Eighteen crafted fishing piers preserve the original ten Heaven / eight Hell deck colliders and footprints. Visible old slabs become transparent; five separated WoodPlanks top boards fill each footprint with narrow true grooves, plus perimeter fascia, longitudinal support beams, four diagonal braces, two metal mooring cleats, a forked rod rest and a metal plate carrying physical raised station numerals. Deck top remains at its current height. Fascia lives below the plank top and remains within the original lateral footprint; there are no stacked top floor sheets or collision on detail props. Native original support posts become thicker and match frame color.

Hell station 5 shifts exactly +2 world X from its saved original CFrame. Its four original PierPost siblings are identified by their local ±4/±4 horizontal positions, store original CFrames, and move by the same offset. This yields a nominal deck back X211, giving 12 studs from the stand rear at X199 **if the final stand geometry respects that plane**. Full in-map clearance still requires measurement.

Up to seventeen 7.5×4 sloped timber bank approaches are authored only when nine dry-ground samples hit Terrain directly in the allowed height range and do not intersect any other deck. Station 5 deliberately has no bank approach so its recovered rear passage stays empty. Any architectural paving/water/uneven-ground hit skips the candidate; the returned `skippedApproaches` list explains where a later measured join is required. These short approaches are **not** a claim that full 12-stud pond loops were built or verified.

Existing textured flower/quartz/bone/brush assets are cloned from `ServerStorage.CrossroadsLandscapeAssets` into low inter-station clusters, respecting deck protection and the Hell rear strip. No catalog imports occur. Cluster geometry is scaled by actual bounds and grounded with Terrain raycasts. Existing whitelisted near-bank/perimeter native trees and rocks in |X|164–296, Z−76…92 are individually seated by their bounds with 0.35-stud embed, rejecting shifts over 14 studs. No tree reordering, terrain editing or water setting changes occur.

Real Terrain water, both pond ellipses, Hell mist, spectator stands, land extent, perimeter safety walls and existing flora templates remain present.

## Apply and idempotence

1. Remain in the **same existing isolated Studio preview**, stop Play, preserve its current save/export first.
2. Read JSON config and execute the Luau returned function with `workspace.RealmCrossroadsR4` and that decoded config. Apply after R10 fishing and existing mist; do not rebake terrain/leisure/fishing from historical sources.
3. On rerun the pass removes only `CrossroadsFishingR10.FishingPolishR11`, recreates detail art and anchors, and uses saved original deck/post CFrames to prevent repeated translation. Deck `FishingPolishBaseCFrame` and `FishingPolishOriginalTransparency`; post `FishingPolishBaseCFrame`, `FishingPolishOriginalSize`, `FishingPolishOriginalColor` are retained for restoration. Existing nearshore model grounding converges to the same sampled base height.
4. Runtime preview scripts should be installed/bound **after** this pass because it replaces Standing/Cast/LineTip attachments and their child prompt. Do not rerun in Play.
5. Inspect returned counts: `stations` must be 18; `postsMoved` should be 4; compare `approaches`, `skippedApproaches`, `grounded`, and `flora`. Missing cache means art-kit still succeeds but native clusters do not appear. No generated organic substitutes are used.

## Stable interaction stubs

Every original `FishingStationN` BasePart receives:

| Element | Contract |
| --- | --- |
| `StationKey` | `HeavenFishingPond:1` … `:10`, `HellFishingPool:1` … `:8` |
| `StationIndex` | Existing numerical index retained |
| `FishingConnected` | Always false; this pass never claims gameplay exists |
| `StubAction` | `fishing_preview` |
| `Standing` Attachment | Center/front work-zone reference at local (0,0.25,-1); attachment sits at deck top, not humanoid root height |
| `LineTip` Attachment | Artist-preview rod-tip point at local (0.7,5,-4.7); a real equipped rod later supplies its own tip |
| `Cast` Attachment | Eighteen studs toward water from deck center, at configured water Y+0.2; stored relative to deck |
| `Standing.PreviewCast` ProximityPrompt | ActionText Preview cast; stable StationKey and StubAction attributes; **disabled until a responding visual handler binds** |

The lead's shared visual script can enumerate `ProximityPrompt` descendants carrying `StubAction=fishing_preview`, connect `Triggered`, enable them only after handler setup, draw a bounded temporary line/ripple between LineTip and Cast, then clean it up. A preview response must make no currency, fish, XP, profile, inventory or catch result changes. It should identify itself as a visual demonstration. Use `Standing.WorldCFrame` only as a reference; no forced player teleport or movement is implemented here.

Real fishing integration remains: server-authoritative occupancy/leave cleanup; validated cast location and cooldown; genuine rod Tool/animation/attachments; restrained client visual acknowledgements; fish catalogue/behavior; catch selection and receipts; agreed Enhancements/potion/egg rewards; inventory policy; cancellation/death/disconnect/streaming; input/accessibility and exploitation checks. Land-shark wander math is only a candidate reference, not a copied dependency. Keep `FishingConnected=false` until the genuine feature is ready.

## Coverage against the two 20-item reviews

Legend: **Built-source** means represented in this pass and awaiting native acceptance; **Partial** means bounded subset only; **Deferred** means no implementation in this pass; **Preserved** means existing accepted behavior intentionally retained. These are coverage records, not an assertion of all 40 ideas being finished.

| # | Heaven / section07 | Coverage |
| --- | --- | --- |
| 01 | Full continuous promenade | Partial: measured dry short approaches only; no full loop |
| 02 | Crafted pier kit | Built-source: planks/fascia/supports/cleats |
| 03 | Bank thresholds | Partial: safe sampled approaches; skips reported |
| 04 | Angler working bay | Partial: rodrest, physical number, anchors; no tackle caddy |
| 05 | Natural shoreline | Partial: low existing-art clusters; no terrain sculpting |
| 06 | Shallow/deep bed | Deferred; existing Terrain bed preserved |
| 07 | Lily/reed habitats | Deferred; new organic art needs pipeline |
| 08 | Ground quartz/trees | Built-source within scoped bounds; visual root check pending |
| 09 | Grove grouping | Deferred to landscape composition owner |
| 10 | Meadow drifts | Partial: five nearshore clusters; no six outer crescent beds |
| 11 | Pearl spring landmark | Deferred; precise section then existing assets/new bowl pipeline |
| 12 | Spring flow FX | Deferred; shared FX-GEN follow-up |
| 13 | Shelter | Deferred |
| 14 | Social seats | Deferred |
| 15 | Physical wayfinding | Partial: station markers only; no new place name or title |
| 16 | Celestial rod kit | Partial: rests and preview tip attachment; real rod asset deferred |
| 17 | Heaven fish trio | Deferred ImageGen → Meshy → Blender → Assets → Roblox |
| 18 | Cast/bobber language | Partial: Cast/LineTip and prompt contract; lead supplies preview FX |
| 19 | Ambient life/audio | Deferred |
| 20 | Catch-photo nook | Deferred |

| # | Hell / section08 | Coverage |
| --- | --- | --- |
| 01 | Twelve-stud rear passage | Built-source +2X station/post shift; final measurement pending |
| 02 | End approaches | Partial: short dry bank ramps, no arena-end walks |
| 03 | Crafted piers | Built-source |
| 04 | Standing definition | Partial: cleats/rest/anchors; no enclosing rail |
| 05 | Mineral shoreline bands | Partial: native low clusters, no continuous band |
| 06 | Sulfur seeps | Deferred |
| 07 | Mist composition | Preserved; no rate/position/color changes |
| 08 | Surface-life FX | Deferred to lead/FX-GEN |
| 09 | Stand rear finish | Deferred to arena owner; X199 interface protected |
| 10 | Re-seat native scenery | Built-source in scoped bounds |
| 11 | Tree rhythm | Deferred to landscape composition owner |
| 12 | Fossil hero | Deferred ImageGen → Meshy → Blender → Assets → Roblox |
| 13 | Ecological clusters | Partial: four triple clusters subject to dry/clear checks |
| 14 | Fishing identifier | Partial: station plates only |
| 15 | Station identity/socket | Built-source physical numerals/rest and stable metadata |
| 16 | Hell rod | Partial: preview attachment only; real rod deferred |
| 17 | Hell fish | Deferred asset pipeline |
| 18 | Quality tiers | Deferred; existing mist preserved |
| 19 | Sound bed | Deferred |
| 20 | Approach lanterns | Deferred |

## Validation and required native review

Source formatted with StyLua and passes Selene with zero errors/warnings. Configuration JSON parses; a configuration-derived geometry check confirms 18 station definitions and all 18 proposed cast targets lie inside their respective pond ellipses. This does not establish actual voxel water coverage. No native build, capacity walkthrough, screenshot comparison or performance test was run by this agent.

Lead acceptance: execute twice in Edit; both runs report 18 stations and four corrected posts; compare transform equality and no duplicate prompt/details. Sample Hell station5 back edge and final stand face; walk with two avatars. Check all approach skips and low-angle deck seams. Inspect source plank gaps with shadows/low graphics, confirm fascia/braces are below water-facing floor and props leave at least six studs clear. Compare tree root grounding at bank height; bounds-based corrections can still need mesh-specific eye review. Verify ten Heaven/eight Hell standing/casting references, real water/mist preservation, disabled prompts until binding, then test preview-trigger cleanup. Capture original section07/08 cameras before saving.
