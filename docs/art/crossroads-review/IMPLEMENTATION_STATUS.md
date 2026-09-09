# Crossroads implementation status

2026-09-08. **The current craft passes are applied to the existing isolated preview. Production gameplay remains disconnected.** This is a first construction pass, not completion of all 160 design recommendations. Evidence below combines inspected source with the lead's explicit native results; section agents did not independently repeat Studio tests.

| Review section | Actually implemented and native result | Native checks still needed | Remaining art priorities |
| --- | --- | --- | --- |
| 01 Arrival / overlook | Shared core pass: 300 fitted pavers across configured approach surfaces, fitted two-realm bronze/stone compass inlay, 36 native plants and overlook finish. Counts are for the shared pass, not 300 arrival-only tiles. Lead visually reviewed. | Whole route walking/collision and grazing-angle joins; overlook rail continuity; combined mobile cost. | More deliberate architectural edge/landscape rhythm; any further finish should preserve current routes and fitted surfaces. |
| 02 Heaven gate | Native rear sculpted titles and heraldic field/border and adapted relief backing from existing gate artwork; shared face-light adjustment, disabled travel anchor. Included in two gate backs completed by core pass. | Rear/side camera clearance, threshold walking, final lighting at supported graphics settings. | Higher-quality sculpted organic feather/face details if commissioned; no smoke pretending to be petals. |
| 03 Hell gate | Matching native rear sculpted title and construction and disabled travel anchor. Small client ember preset anchored to the Merge Arch's ground-relative frame. | Actual ember appearance/placement, travel threshold and aggregate transparent-effects cost. | Custom horn/iron details after silhouette review; effects remain restrained around existing approved gate art. |
| 04 Bragg | 14 bays finished, 24 preview figures repaired, 13 corner closures and fitted cut annulus installed. Existing Confluence geometry and motion retained. 24 inert cap-rank anchors and three initial native category emblems added; eight category emblems now await the final orientation correction. Lead visually reviewed. | Annulus walk/collision and CSG cost, rear joins, camera/figure contact, rerun counts; confirm fountain motion unchanged in Play. | Final category-emblem orientation/visual acceptance, finer podium bevels/medals, complete radial paving and exterior landscape composition; bounded real winner loading is gameplay/display integration, not finished art. |
| 05 Coin garden | Four native Seats and ten native plants; sculpted open pavilion/frame/halo and inert egg presentation anchors. Revision 2 fixed the undersized CSG arch to full **41.2-stud span**; lead reapplied/reviewed. Original egg/stand/title retained. | Sit/exit four Seats, approach/pond corridor widths, low-angle arch-support contact and camera clearance. | Organic feather capital ornaments, forecourt/field-edge composition, optional approved petal texture; no weekly offer or hatch flow installed. |
| 06 Arena / stands | 32 native Seats retained, eight enabled; 16 contrasting stair replacements, eight rear façade bays, four reused native ornaments, rails and pavilion masonry. Three inert semantic anchors. Lead visually reviewed. | Eight visitor seat/egress tests, seated sightlines, central stairs, façade max X≤199 and actual pond clearance, rail collision. | Measured sightline improvements, arena-floor identity, receiver/cover finishes, selective story relief; avoid adding structures into the pond passage. |
| 07 Heaven fishing | Crafted native pier details on all ten stations, numbered plates, rod rests, Standing/Cast/LineTip anchors and local cast/reel rehearsal. Uploaded 5.5-stud Pearlwing/Cinderbone Blender rods are mounted on all 18 stations with true tip anchors. Shared fishing pass returned **18 stations, 17 approaches, 121 grounded assets, 27 new flora** across both ponds. | Walk every approach, station/avatar/rod envelope and camera, low-end cost; preserve real water. Shared aggregate counts must not be presented as Heaven-only. Shelter RestSeat_1_1 passed native sit/exit; remaining shelter Seats need coverage. | Four-seat bowed timber shelter, two dry pet/display bays, three native backdrop trees and physical fishing wayfinding now installed. Remaining fish assets and ecology; no reservation/catch/reward system yet. |
| 08 Hell fishing | Eight crafted stations, Station 5 shifted +2 world X, rear strip protected. Real water retained; original GreenPoolMist replaced by client-owned approved baseline: 20 emitters, rate 4, lifetime 5–8s. No old workspace mist remains. Local fishing rehearsal enabled. | Actual mist motion/appearance approval remains pending because screenshot capture omits the cloud; bank/deck cameras, measured 12-stud passage, performance and all routes. | Version 2 textured fossil landmark and physical fishing wayfinding installed; remaining fish art, broken mineral banks and stronger tree grouping; no extra water widening and no plastic liquid plane. |

## Confirmed behavior checks

- Cosmetic FX installed: **two fields / 22 sources** (20 pool mist, two gate embers). Near full-quality mist has all 20 emitters enabled at rate 4. Native lifecycle smoke passed full/off/stop/restart/double-destroy; off tier produced rate 0. Old GreenPoolMist is archived rather than emitting alongside the replacement. Appearance acceptance and real-device GPU cost are still separate checks.
- Fishing rehearsal: **18 local prompts enabled**. Native prompt hold produced bobber plus line; second trigger showed reel cleanup; walking away cleared it. Current sampled Terrain water is **Y0**, so the installer corrects Cast to actual water+configured offset; older nominal config Y2 must not be treated as the measured surface.
- Native Seat behavior is preserved by source; 32 stand Seats/eight enabled and four pavilion Seats are confirmed counts. A count is not a completed sit/egress or sightline test.
- Gate and weekly egg prompts remain disabled. Fishing rehearsal is Studio/PlaceId0-only, client-owned and cosmetic. No travel, catches, currency, inventory, weekly rotation, arena outcomes or leaderboard writes were implemented.

## Validation and remaining delivery gate

Owned scripts/configs received Selene/StyLua/JSON checks in section work. Standalone RBX-FX-GEN passed its complete `mise run check` (10 headless tests, two Python tests, lint/style/Rojo build); the map installer and extracted controller passed lint/style and baseline-preservation checks. These do not substitute for the lead's final whole-repo CI result.

Lead still owns complete walking/collision sweeps, supported-avatar/controller/touch checks, aggregate FX/CSG/avatar performance, save/export verification and final whole-repo CI. Record the final native artifact paths and test results when those checks finish; do not infer a published or exported build from the existence of source. Missing organic hero assets and deeper art recommendations remain visible above rather than being counted as complete.

See [Gameplay integration contract](GAMEPLAY_INTEGRATION.md) for exact anchors, server authority boundaries, existing-service reuse, new fishing/cleared-wave/global-boss work and future production cutover. Preserve the preview's isolation until that separate integration is reviewed.

## Lead checkpoint additions

- Both fishing rods loaded natively with five textured MeshParts each, height5.5; installed18props/18tipanchors and reviewed the loaded Heaven texture in the live viewport. Source recipe/generator and uploaded IDs are retained.
- Native stand Seat_02_05 accepted the player Humanoid and supplied a seated arena sightline. Movement speed remains24. Native character navigation reached the central gallery entrance; broad route/device testing remains open.
- QA corrected a confirmed coplanar skin inside the arrival compass using a tall boolean cutter, closed the30overlook baluster-to-rail gaps, and archived two decorative props from the12-stud Hell passage. [Measured native QA](NATIVE_QA.md) records evidence and limits.
- Full `mise run ci` passed, including2,842headless tests; all ten new Studio authoring/client scripts separately passed Selene with zero errors/warnings.
- Eight [implementation screenshots](implemented-screenshots/01-arrival.png) supplement the preserved pre-build atlas.

- RBX-FX-GEN pooled ripple extension (code commit `bcd1619`) is installed. A cast endpoint emits one thin expanding ring on sampled water; native pooling/reuse/reduced/off/reduced-motion/expiry/double-destroy tests pass. The ring was visually reviewed on real water with the rod line/bobber. Walking away clears both cast and ripple.
- Bragg floor is now three independently authored solids (outer court, viewing annulus, inner court). Native rendering is clean; a localized east-side collision query reports both outer court and annulus despite the explicit subtraction. This remaining query ambiguity is documented in NATIVE_QA, rather than described as a confirmed visible overlap.

- Both revised bank passages passed native character navigation: Heaven(-158,27)→(-158,-12), Hell(205,30)→(205,-20). The garden VisitorSeat accepted the Humanoid. Shore routes paint500dry top-solid cells as Cobblestone; both occupancy channels remain unchanged. Heaven wall westface−152.7 leaves12.3studs behind station1 while preserving the64-stud field. Six planter/flower items are archived.
- Lossless [R11 checkpoint](../../../assets/source/maps/realm_crossroads/RealmCrossroads-R11.rbxl) remains the retained artifact path. The latest saved geometry checkpoint and its historical hashes are recorded in NATIVE_QA.md. No duplicate Studio was opened.

## Latest native completion additions

- Heaven rest shelter applied: four native Seats, two inert dry pet/display bays, bowed timber roof top Y14.2, 18 material-only spur cells and unchanged terrain occupancy. Three cached native backdrop trees frame the shelter; two small bushes remain. Lead reviewed the composition and verified `HeavenFishingRestShelterR11.RestSeat_1_1` accepted the player Humanoid and allowed exit in Play. This is one sampled Seat, not all-seat/avatar acceptance.
- Both physical FISHING signs are installed from `realm_crossroads_fishing_wayfinding.json` / `fishing_wayfinding.luau`, using sculpted glyph geometry and rod emblems rather than BillboardGui. They are cosmetic wayfinding, with no interaction or reward authority.
- The version 2 fossil is placed: Model `116671594170630`, texture `105991804065229`; provenance and placement remain in `configs/crossroads_fossil.json`. All eight Bragg category emblems are present. Revision4 corrected the generated wave medals’ pivot; a native close view confirms the medal faces inward.
- The authoring registry now contains **17 passes**. The refreshed native checkpoint round-trip passes: 17,593 instances,18rods,18stations,16enabled visitorSeats, Terrain and visual scripts retained. Whole-map/device QA, fish art and the east-annulus collision-query ambiguity remain open.

## Follow-up construction and seating review

The arena now has28broad fitted stone panels, a cut20-stud shared crest, recessed mortar and two14-stud receiver faces. Its64×102footprint/top4.38 and fourcoverparts remain unchanged. The original floor survives as an archived source and invisible noncolliding bounds proxy. Native overhead review shows a restrained, continuous playing surface; low-view and target tests follow.

The fossil setting now reuses12grounded native meshes, including a15-stud withered-tree backdrop whose farthest X is291.30, inside the outer barrier. Pier construction now samples real solid Terrain under water;22posts extended, all72penetrate bed by at least0.3stud, with tops unchanged.

All8enabled stand Seats passed native sit/jump-exit checks. Four reconstructed eye views showed some lower-field obstruction; the measured raised-tier alternative gains only0.15–0.18stud over preceding chairs at center. Temporary rendered target checks, rather than query-only rays, determine whether tier changes are warranted. See ARENA_SEAT_QA.md and ARENA_TIER_CHANGE_PLAN.md. These QA fixtures are not part of the authoring registry or saved map.

Rendered baseline review completed with16images:8all-target seat views and8focused views. Current tier heights are retained because center and actual entrance middle/upper targets remain readable. Closest-edge lower body remains partially occluded by the native bulwark; this is recorded, not hidden by an unproven tier change. AlltemporaryQAgeometry was removed.

A10-second local frame probe returned21samples, median966.30ms/p95983.71ms, with4,914.52MB total shared Studio memory. The Mac was then independently reported locked by the native UI tool; foreground activation was unavailable. This is an invalid foreground/device acceptance sample, not evidence of a quantified map regression or a performance pass. Repeat in an unlocked focused session and later supported target devices.

## Route and interaction readiness

The native route sweep completed 49 navigation checks at WalkSpeed 24, with actual end positions retained in [ROUTE_QA.md](ROUTE_QA.md). Three independent reset boundaries are explicit. Both gates, the gallery, a clean eight-point fountain loop, both activity areas, stand aisle, Heaven shore/shelter, and Hell rear passage/north shore were reached. Tight fountain chords produced jump states; the wider loop is the verified walking route. This does not certify every perimeter route or controller/device behavior.

All 37 bulwark pieces now have stable, config-owned IDs and side/segment metadata, including four entrance pieces. No collision or movement behavior was enabled. The [interaction audit](INTERACTION_STUB_AUDIT.md) records existing anchors and the later binding contract.

## Pond life and final access coverage

All 18 fishing stations passed sequential back→Standing→back access checks and both full bank loops closed. All eight garden/shelter Seats passed sit/jump smoke. The initial same-location navigation error is retained in [station-access results](fishing-capacity-qa/RESULTS.md); this is one-player access coverage, not concurrent crowd proof.

An original pearl/gold fish now swims in both ponds with a skinned tail and occasional short surface leaps. Native appearance, 96 water/bed samples, quality/distance/reduced-motion controls, ripple triggering and cleanup pass. [Pond-fish implementation](IMPLEMENTED_POND_FISH.md) records asset provenance and the cosmetic-only boundary. The water appearance was preserved. Foreground timing/performance acceptance remains pending because the Mac was locked.
