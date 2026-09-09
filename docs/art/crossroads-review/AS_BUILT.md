# Crossroads as-built coordination sheet

2026-09-08. [Architectural sheet SVG](as-built/crossroads-as-built.svg) · [PNG preview](as-built/crossroads-as-built.png) · [Browser sheet](as-built/index.html) · [Source generator](as-built/draw_sheet.py).

The sheet combines current source dimensions with native read-only gate and previously recorded dock/seat/route measurements. It describes the isolated R11 preview, not production deployment. No Studio camera, player, mode or map was modified to make it. A read-only Client query initially found the preview already in Edit; the subsequent read-only Edit query supplied gate bounds. Root retained exclusive native replay control.

## How to read it

- Plan orientation: negativeZ at top; Heaven negativeX/left, Hell positiveX/right. Coordinates and lengths are Roblox studs. The A1 plan scale is 1.6 SVG units per stud; its 100-stud scale bar remains authoritative when resized. Lower section/occupancy sketches are labeled diagrams, not the plan's scale.
- Solid polygons show usable major footprints; organic canopy/rock detail and many sculpted façade elements are omitted for readability. Pond ellipse outlines are configured water footprints, not an exact voxel shoreline trace. Pavilion rectangles are source slab envelopes, not every roof/arch projection.
- Dark dashed perimeter is the **safety-wall centerline**,592 studs acrossX±296 and 312 acrossZ±156. Wall thickness 4 means the extreme inner face isX±294; nominal outer land extent isX±300. This is not a terrain contour survey. Colored background panels distinguish realm sides only.
- Ochre solid route strokes are schematic primary circulation links, not floor material polygons or a width measurement. Ochre dashed bank circuits follow sampled station-back positions and completed native navigation loops. All 18 deck footprints use actual rotated station transforms; dots indicate occupied proxy locations, not gameplay reservation markers.
- Orange short lines mark the critical shore passage areas. Heaven clearance 12.3 is measured from station 1 deckrearX−165 to corrected wallwestfaceX−152.7; Hell clearance 12 is standrearX 199 to station 5 deckrearX 211. These values are specific bottleneck planes, not a guarantee of identical width at every corner.

## Built dimensions and evidence

| Element | Dimension / current level | Authority |
| --- | --- | --- |
| Heaven gate Arch | center(−40,14.102,42), local box 29.836 wide×28.204 high×12.004 deep | [Native gate survey](as-built/native-gate-survey.json); top 28.204 |
| Hell gate Arch | center(40,14.031,42), local box 29.934 wide×28.063 high×13.008 deep | Native survey; top 28.063 |
| Doorway clearance |6 wide×9 high retained **design intent**, not a new minimum aperture measurement | Terrain gate config; native route QA reached both threshold anchors |
| Gate travel anchors | approximately(±38.865,3,43.646) | Native route survey; visual stubs, no travel enabled |
| Bragg court | center(0,−88), outer radius 58; viewing ring 34–38; floor 4.44 | Bragg config/source + native floor audit |
| Fountain | diameter 22; cardinal radius 22/eight-point walking loop clear | Fountain config + native route QA; no tight 16 radius chord shortcut assumed |
| Coin field / arena |64×90 /64×102; garden nominal 4; current arena 4.38 | Current activity config and applied native floor |
| Built Bragg entrance |26 wide staircase,8 risers×0.5,2 treads; flanking 16 wide×32 run ramps | Current `bake_bragg.luau`, centerline Z−26…−10 stairs; rampsZ−26…6 |
| Side garden stairs / ramps |8 risers over 16 run,24 wide; side ramp 16 wide×32 run | R4 transition source; west/east activity access passed |
| Stand tiers |4 rows×10 depth, decktops 6/8/10/12, aisle 8 wide;32 Seats,8 free | Source/native survey; hold current heights after rendered target QA |
| Stand front/rear passages |7 /12; standX 159…199 | Geometry/route checks; no new external ramp shown |
| Ponds | Heaven 88×112 with 10 docks; Hell 56×96 with 8 docks | Current fishing source; actual deck transforms surveyed |
| Docks / occupied figures |10×12 deck, top 4.5;5.5 high standard-body proxies,4.246×1.232 footprints | All 18 access and occupied-layout QA; fixed-rod envelopes disjoint |
| Shelter |22×14 at(−213,−85), roof top 14.2,4 nativeSeats | Applied native shelter result;4 sit/jump checks passed |
| Water / bottom |last native water surfaceY 0; nominal pondbottom−4 | Sampled water supersedes older configsurface 2; not a new full bathymetric survey |

## Applied arena access ramp

The owning Bragg agent reports the new arena access ramp applied and reapplied in native Edit: 74 parts, two flights, 32 Seats preserved; first apply archived four originals and second archived zero. It is now shown on the plan in muted green. Source: `configs/realm_crossroads_arena_access_ramp.json`.

- Lower flight centerline (182,4,−44) → (182,8,−76), width 8, run 32.
- Turn landing X178…198 / Z−84…−76, top Y8, footprint 20 × 8.
- Upper flight centerline (194,8,−76) → (194,12,−44), width 8, run 32.
- Bridge X190…198 / Z−44…−28, top Y12, footprint 8 × 16.
- Both flights slope 1:8; guard/stringer maximum X198.67 preserves the rear protected plane. Ground promenade Z−42…−28 passes beneath bridge with 7.5 studs headroom.

The owner verified native height samples 4/6/8/10/12 and inspected screenshots. Subsequent direct Play traversal passed 16 up/down/underpass segments with no Jumping, Freefall or Swimming in 634 sampled frames; see IMPLEMENTED_ARENA_ACCESS.md for the separate pathfinder-shortcut limitation. Existing original Bragg entry ramps are separate and remain shown. The ramp drawing follows native application evidence, not source presence alone.

## Limits, provenance and update procedure

Read alongside [native geometry QA](NATIVE_QA.md), [route QA](ROUTE_QA.md), [seat target QA](ARENA_SEAT_QA.md), [all-station access](fishing-capacity-qa/RESULTS.md) and [occupied fishing QA](OCCUPIED_FISHING_QA.md). The east-annulus collision-query ambiguity remains unresolved. Occupied figures prove static geometry fit, not 18 simultaneous clients or physics/performance capacity. Historical raised-tier proposal remains unbuilt; no height change is implied.

The generator reads current fishing, terrain and source gates plus the retained actual station survey. It deliberately excludes obsolete R2 concept footprints and R9 smallpond dimensions. The read-only gate survey is retained as raw evidence. Regenerate with `python3 docs/art/crossroads-review/as-built/draw_sheet.py`. PNG was rendered through native QuickLook using a temporary square viewport to avoid its non-square thumbnail crop, then cropped from the top-left with Pillow to the exact sheet aspect ratio (1600 × 1309), preserving the title and removing bottom padding; the SVG is the durable resolution-independent artifact. Rendered sheet was visually inspected, including right-side notes and bottom details. No final checkpoint bytes/hash/instance count is asserted.

To regenerate the inspected PNG after SVG changes, run `python3 docs/art/crossroads-review/as-built/render_preview.py`. The explicit top-left crop avoids the centered-crop behavior that clipped the first export.
