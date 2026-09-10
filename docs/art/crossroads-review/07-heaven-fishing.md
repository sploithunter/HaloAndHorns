# Section 07 — Heaven fishing: The Stillwater Sanctuary

Design proposal, 2026-09-08. Plan only; no map, gameplay, asset upload, or FX changes made. This section owns the Heaven pond, ten fishing stations, bank circulation and adjacent outer planting. All dimensions below are proposed unless identified as existing. Coordinate pairs are world **X,Z**; heights are world Y. North means decreasing Z.

## Evidence and design direction

Reviewed all four supplied local captures: [overhead](screenshots/07-heaven-fishing-1.png), [bank approach](screenshots/07-heaven-fishing-2.png), [water toward hub](screenshots/07-heaven-fishing-3.png), and [water toward trees](screenshots/07-heaven-fishing-4.png). They show a generous native-water oval with ten evenly spaced rectangular decks; decks read as bare tables, banks are uniformly grassy and steep, isolated decorative objects feel scattered, and repeated large trees/quartz form an abrupt perimeter. Several quartz clusters appear suspended in the ground views. This is a visible grounding problem to investigate, not proof that every instance floats. The pond has useful openness, clear blue water and appealing pink/mint foliage worth retaining.

The tier-one direction is a **crafted celestial fishing sanctuary**: pale timber piers with small bronze details, naturally cleft pearl-stone shores, a continuous legible promenade, clustered meadow planting and one modest spring grotto. Preserve a large readable water surface. Create richness at human scale, with hierarchy and intentional empty space; the pond must remain calmer than the gates and arena. “Stillwater Sanctuary” is a proposed physical place name, not a rename of the internal HeavenFishingPond key.

Verified source: `configs/realm_crossroads_fishing.json` and `tools/realm_crossroads/bake_fishing.luau` supersede the small leisure pond. Existing pond center (-216,8), radii 44,56; bottom -4, water 2, bank 4, deck top 4.5; ten 10×12 decks. Existing land reaches |X|300; wall at X=-296 on this flank; outer flora rows X=-284/-291. Keep these land and water extents. The old 48×80 pond dimensions are obsolete.

The platform centers, reconstructed directly from the baker, are:

| Station | X | Z |
| --- | ---: | ---: |
| 1 | -171.0 | 8.0 |
| 2 | -179.6 | 41.5 |
| 3 | -202.1 | 62.2 |
| 4 | -229.9 | 62.2 |
| 5 | -252.4 | 41.5 |
| 6 | -261.0 | 8.0 |
| 7 | -252.4 | -25.5 |
| 8 | -229.9 | -46.2 |
| 9 | -202.1 | -46.2 |
| 10 | -179.6 | -25.5 |

Closest center separation is about 27.8 studs. Preserve station count and initial positions; larger decks or another island widening are not justified by these captures. Test ten simultaneous anglers with rod envelopes before changing dimensions.

## Exactly 20 improvements

Effort bands are relative authoring estimates: S ≈ half day, M ≈ 1–2 days, L ≈ 3–5 days; they exclude external generation/upload waiting and future gameplay. Acceptance criteria are proposed tests, not results already obtained.

### 01 — An uninterrupted promenade behind every angler

**Evidence:** Capture 1 shows grass separating all platforms; captures 2–4 offer no clear route around seated/standing anglers. **Build:** Author a 12-stud-clear walk loop outside the decks, nominally occupying radial offsets 8–20 studs beyond the water ellipse. The western extreme is approximately X=-280 and eastern extreme X=-152. Lay pale compacted gravel with occasional single-thickness stone landings, using an actual offset curve around measured rotated deck footprints rather than merely inflating the ellipse. Maintain one stud between deck back edge and promenade, filled by a flush apron. Use Blender to generate nonoverlapping strip geometry or an Edit-time polygon baker; no stacked floor planes. **Benefit:** Ten occupied stations remain accessible and passing traffic never crosses a cast. **Depends:** Measured deck corners, Coin Garden interface. **Effort/risk:** M; eastern join has only a small margin before the existing garden. **Accept:** Two 4-stud-wide avatar envelopes pass behind each of ten occupied 10×12 stations; full loop at speed 24 without jumps, invisible-wall contact or z-fighting from grazing cameras.

### 02 — Replace the table silhouette with a coherent pier kit

**Evidence:** Captures 2–4 expose thin decks and long featureless legs. **Build:** Retain each 10×12 footprint; create a reusable pale timber module with 0.5-stud perimeter fascia, eight broad plank strips, submerged 0.7-stud posts, two diagonal braces and restrained bronze post collars. Cut plank grooves into a single mesh or normal map rather than stacking strips on a solid top. Keep original orientation and top Y=4.5. Native geometry is adequate; Blender supplies bevels and one shared atlas. **Benefit:** Platforms read as built fishing piers at eye level. **Depends:** 01's attachment seams. **Effort/risk:** M; imported collision detail must not catch feet. **Accept:** One simple deck collider per station, no exposed underside gaps to shore, no flicker across the top at minimum and maximum graphics; all ten visually use one family.

### 03 — Flush, broad bank-to-deck thresholds

**Evidence:** Capture 3 shows decks elevated above the grassy edge; exact terrain transitions vary. **Build:** Give each station a 10-wide by 4-deep timber/stone threshold rising from bank Y=4 to deck Y=4.5, slope 1:8, behind the deck. Trim adjoining walk-loop skin to that threshold's footprint and replace intersecting material completely. Terrain remains supporting substrate. **Benefit:** No tiny jumps or snags entering a fishing station. **Depends:** 01–02. **Effort/risk:** S; rotated corner clipping. **Accept:** R6, default R15 and a large supported avatar enter/exit all stations using walking only at speed 24, including oblique approaches; dry floor heights raycast continuously.

### 04 — Give each angler a deliberate working bay

**Evidence:** Capture 1's identical empty decks establish capacity but communicate no fishing orientation. **Build:** On every deck reserve an unobstructed 6×8 central work area. Place a 1.2×1.2 rod-rest socket at the left rear corner and a 1.8×1.2×1.5 tackle caddy at the right rear, outside that rectangle. A low inset fish medallion at the landward threshold distinguishes the station without a floating label. Reuse simple native shapes; create one Blender relief if needed. **Benefit:** It is immediately clear where to stand and aim; future props have assigned space. **Depends:** 02; no prompt yet. **Effort/risk:** S; prop clutter. **Accept:** Ten avatar-and-rod mockups simultaneously occupy stations with no collision, silhouette overlap or obstruction of the promenade; all fronts remain open.

### 05 — Naturalize the sharp grass-to-water cut

**Evidence:** Captures 3–4 show an abrupt uniform grassy wall ending directly in water. **Build:** Between stations only, replace selected 6–10-stud shoreline arcs with alternating pearl-stone shelves and shallow gravel coves, 3–5 studs wide. Limit inward intrusion to 3 studs; stay at least 5 studs from projected cast fronts. Use voxel-aware terrain sculpting backed by low-poly shoreline meshes where 4-stud cells cannot describe a clean lip. Reuse pearl_quartz in lower, broader arrangements instead of adding a continuous wall. **Benefit:** The pond gains geology and waterline detail without losing capacity. **Depends:** 01 station protection masks. **Effort/risk:** M; terrain-water reconstruction can move a shoreline. **Accept:** Water extent changes by less than 5% in overhead area, no dry shelves cross station cast corridors, and underwater/above-water cameras reveal no air pockets or intersecting coplanar surfaces.

### 06 — Shape a readable shallow-to-deep pond bed

**Evidence:** Capture 3 reads as one flat reflective water field with little visible depth story. **Build:** Keep global water settings unchanged. In the outer 4–6-stud water band between piers, sculpt sand/pebble shelves near Y=0, transitioning into the current Y=-4 center. Use quiet pale bed material only after testing actual visibility; no giant transparent surface overlay. Create three darker pebble patches approximately 6×8 at (-230,-16), (-205,28), (-235,35), below water and outside cast landing markers. **Benefit:** Anglers see habitat and depth without obscuring the native water. **Depends:** 05; voxel test patch. **Effort/risk:** M; visibility depends on global water transparency. **Accept:** Shore remains naturally swimmable, no shelf protrudes unexpectedly, and at least one shallow band is visible from each of captures 3/4 without altering the Hell pool water appearance.

### 07 — Three small lily and reed habitats

**Evidence:** Captures 1 and 4 show no aquatic vegetation, despite dense trees elsewhere. **Build:** Add three loose 6×8 aquatic clusters between station pairs 2/3, 5/6 and 8/9. Keep the first two studs in front of each deck completely clear and reserve each cast wedge. Each habitat gets 5–7 leaf pads, at most two small pale flowers and 3 reed tufts under 3.5 studs high. First inspect existing flower assets; Blender-model missing simple leaves/reeds rather than spend a Meshy run on basic geometry. Leaf surfaces sit 0.15 above water, never as one coplanar water-covering sheet. **Benefit:** A small amount of recognizable habitat makes fishing believable. **Depends:** 05–06. **Effort/risk:** S/M; water waves may intersect flat leaves, requiring gentle bobbing or higher placement. **Accept:** Vegetation occupies less than 5% of visible water; every station sees its mock bobber clearly.

### 08 — Ground the existing quartz and trees convincingly

**Evidence:** Captures 2 and 4 show pearl-quartz masses apparently floating among trunks. **Build:** Audit every existing outer-row model within X=-296…-278, Z=-76…92 by visible mesh bounds, not Model pivot. Raycast ground and bury rock bases 0.4–1 stud; seat trunks at their actual root base. Large rocks become ground-attached 3–6-stud outcrops rather than hanging masses unless an explicit magical support is added later. **Benefit:** Removes one of the most distracting unfinished details with existing assets. **Depends:** Existing instance inventory; do not globally mutate templates. **Effort/risk:** S; shared models may bundle roots and rocks. **Accept:** Low camera sweep around all ten stations finds no unintended daylight below trunks/rocks and no plant buried above its intended root crown.

### 09 — Compose the outer grove in groups and windows

**Evidence:** Captures 1/2/4 show a near-continuous repeated row of pink, mint and pine crowns at similar heights. **Build:** Reposition existing trees into five loose groups along the current outer belt, alternating dominant cherry and cloud crowns. Three height bands: 14–18, 21–25 and 28–32 studs. Keep trunks west of X=-282 except at north/south terminal groups, so promenade stays clear. Leave two 12–16-stud canopy windows aligned with the view from stations 2 and 10 across the pond. Avoid dense foliage directly behind station 6's camera. **Benefit:** Creates composed vistas and layered depth instead of an asset wall. **Depends:** 08, 01. **Effort/risk:** M; bounds differ widely among native meshes. **Accept:** Walking loop has 10 studs of camera/head clearance; all invisible perimeter walls stay visually screened at standing eye height, but water-to-hub sightlines remain open.

### 10 — Replace scattered sprinkles with meadow drifts

**Evidence:** Capture 1 shows tiny lone bushes/rocks at regular intervals; capture 2 has extensive undifferentiated lawn. **Build:** Form six crescent beds outside the promenade, each about 5×12, using existing field_flower_bush and softglow_bloom. Group 3/5/7 specimens at varied scale with 30–40% grass gaps; flowers under 2.5 studs near paths, taller specimens only behind. Use mint/white as the dominant visual mass and pink as a small accent. Remove/move singleton decorations that now occupy circulation. **Benefit:** Deliberate garden composition and a clear edge between walking space and scenery. **Depends:** 01 and 09. **Effort/risk:** S; transparent foliage overdraw. **Accept:** No bed narrows the 12-stud loop; overhead shows six readable clusters, not a carpet; reduced graphics still reveal the route.

### 11 — A low pearl spring as the local landmark

**Evidence:** Capture 2 has broad sky and trees but no modest destination within the pond scene. **Build:** Place an approximately 14×12, maximum 8-stud-high spring at (-265,-72), outside the northwestern promenade. Assemble existing pearl_quartz and a shallow stone bowl; a 4-stud-wide, bank-contained rill curves to the northwestern shore between stations 7/8, crossing under the walk loop through a genuine arched culvert with a separate solid walking top. The rill must not create a new pond or widen the island. Draft its section before sculpting. **Benefit:** A recognizable “source of the sanctuary” and a premium focal detail that stays below gate importance. **Depends:** 01/05/08; neighbor north-edge clearance. **Effort/risk:** L; the culvert is the most involved geometry here. **Accept:** Water route has no disconnected floating sheet, promenade remains 12 studs clear, and the spring is visible from the eastern approach without concealing the pond.

### 12 — Restrained spring flow and splash FX

**Evidence:** Captures 3/4 show water motion but no specific source or shoreline activity. **Build:** At 11's spring, use two narrow curved Beams between attachments for a 2–4-stud fall, with slow texture scroll and one small splash ParticleEmitter at impact. Use one shared transparent texture, pale cyan-white, no large opaque fog. Attachments/curvature are native Beam capabilities; source art can come from ImageGen and be cleaned into an alpha texture in Blender/compositing. [Roblox Beam reference](https://create.roblox.com/docs/reference/engine/classes/Beam). **Benefit:** Motion focuses attention on one meaningful object. **Depends:** 11 plus texture provenance. **Effort/risk:** M; translucent sorting and water intersections. **Accept:** No beam edges visible in the four review cameras; at most 24 live splash particles, no coverage of fishing bobbers, and effect disabled cleanly at reduced FX settings.

### 13 — A small waterside shelter, away from fishing fronts

**Evidence:** Capture 2's wide unstructured bank provides no welcoming stopping point; the existing egg pavilion visible in capture 3 belongs to another function. **Build:** Add a 22×14 open-sided shelter centered (-213,-85), roof top no higher than Y=16, with a 10-wide spur to the north loop. Use pale timber, four slim posts, a subtly bowed roof and one small fish-and-halo finial. Keep the pond-facing side fully open and distinguish its roof silhouette from Egg of the Week. Blender/native kit construction before considering a generated ornament. **Benefit:** A memorable arrival/rest point and a place for future fishing information. **Depends:** 01; coordinate with northern landscape/Bragg owner. **Effort/risk:** M; visual duplication of egg pavilion. **Accept:** Shelter occupies no fishing station or boundary corridor, its roof does not block pond views from the egg pavilion, and its footprint connects without a new level change.

### 14 — Comfortable social seats with dry pet parking

**Evidence:** Captures 2–4 contain standing decks only; companions would congregate behind anglers. **Build:** Put four genuine Seats in two short bench assemblies under 13, seat height 1.7 above floor, with 4-stud side access. Beside each bench leave a 5×6 clear pet/display bay; do not automatically relocate players or pets. Native seats plus crafted timber shells; no decorative collider over a Seat. **Benefit:** Spectating and conversation happen off the circulation ring. **Depends:** 13; pet display logic deferred. **Effort/risk:** S; avatar scale and seat egress. **Accept:** Four players sit simultaneously, stand without snagging roof/posts, and a fifth can pass the seating zone; no Seat is placed in an angler work rectangle.

### 15 — Physical wayfinding with a fishing identity

**Evidence:** Capture 3 shows Egg of the Week signage beyond the pond, while the fishing area has no own identifier. **Build:** At the east approach near (-162,64), place a 6-wide, 4.5-high carved stone sign beside—not inside—the route. Relief rod/fish icon and a short extruded title, “Stillwater,” with a subtle arrow to the loop; final name can change before generating glyphs. Put a matching small emblem on the shelter. Reuse the gate project's extruded type workflow and palette family. **Benefit:** Fishing becomes discoverable without a BillboardGui or confusion with the egg feature. **Depends:** Coin Garden route agreement, final copy. **Effort/risk:** S/M; lettering size/localization. **Accept:** Icon is recognizable from 25 studs on low graphics; title readable at 12; nobody must read text to find the water; no overlap with existing path junctions.

### 16 — A celestial rod kit designed for animation

**Evidence:** All captures lack any recognizable fishing equipment. **Build:** Prototype one 6-stud rod with separated shaft/reel/line-guide components, feather-shaped reel casing and subdued bronze fittings; display three on a 5×1×5 rack under the shelter and one at a mock station. ImageGen orthographic concept → Meshy only for the sculpted reel ornament if warranted → Blender retopology/UVs, correct hand grip and rod-tip attachment → Assets manifest → group-owned Roblox upload. Keep a native Beam line separate from the rod mesh. **Benefit:** Strong local identity and an asset that can later be equipped correctly. **Depends:** 04/13; actual Tool/animation integration deferred. **Effort/risk:** L; generated disconnected parts or grip mismatch. **Accept:** Source model has explicit grip and tip markers, test-held by small/default/large avatar references; rod points over water without clipping head/neighbor and rack stays outside circulation.

### 17 — Three visually distinct Heaven fish, not reward promises

**Evidence:** Captures 3/4 show empty water; the fishing purpose needs a believable catch identity. **Build:** Concept a 2.5-stud Pearl Koi, 3.5-stud Ribbonfin and 4.5-stud Halo Ray with distinct silhouettes, restrained pearlescent bodies and no baked glow. Use ImageGen reference sheets → Meshy → Blender cleanup, mouth/fin separation, simple 3–5-bone rig where needed → Assets → Roblox. First place static study specimens under the shelter or on a separate review plate; only then consider six noncolliding cosmetic fish beneath the pond. **Benefit:** Makes the destination particular to Heaven while preparing reusable assets. **Depends:** Verified pipeline budgets; catch tables, ownership, rewards and fish behavior remain future work. **Effort/risk:** L; thin fins/UVs and water visibility. **Accept:** Species distinguishable by grayscale silhouette at 15 studs, every asset has scale/orientation/provenance and animation test, and no displayed label promises Enhancements, potions or eggs before economy approval.

### 18 — A readable cast-and-bobber visual language

**Evidence:** Capture 1 has ample station separation; capture 3's bright reflection could hide small interaction cues. **Build:** In the future FX preview, reserve each station's inward-facing ±12° wedge with bobber centers 12–18 studs from its waterward edge. Use a 0.8-stud two-tone floating bobber with a 2.5-stud expanding ripple at bite time and a restrained line Beam; never cover the entire water with ripple decals. Author an explicit ten-station envelope diagram before code. **Benefit:** Ten players can identify their own line/catch area and see activity. **Depends:** 04/16, later fishing interaction design. **Effort/risk:** M; central line convergence and mobile visibility. **Accept:** Ten mock lines/bobbers remain distinguishable from default player cameras; no casts share landing footprints; silhouette/motion communicate bite without relying only on color. Gameplay remains disabled in map review.

### 19 — Small, localized life in the air and soundscape

**Evidence:** Capture 2's open bank feels silent and static despite colorful foliage. **Build:** Add four small petal/mote emitters under outer cherry clusters, each 0.5–1 particle/sec, 3–5-second lifetime and 0.2–0.5-stud sprites; exclude all deck work areas and camera-height paths. Add localized soft spring sound at 11 and one quiet grove loop near (-279,8), with initial max rolloff 50 studs and separate ambience gain. No blanket Heaven fog, global wind change or soundtrack replacement. Native particles support textured alpha sprites; small sizes and low overlap matter to GPU cost. [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters). Positional sound falloff can be tuned independently. [Sound objects](https://create.roblox.com/docs/sound/objects). **Benefit:** Peaceful life that does not imitate Hell's thick green mist. **Depends:** Asset/audio rights and shared audio/FX settings. **Effort/risk:** M; ambient fatigue and transparent fill rate. **Accept:** At most 20 live airborne particles here, no audible loop seam after two minutes, ambience inaudible at the main gate approach, and mute/reduced-motion leaves the scene legible.

### 20 — A quiet catch-photo nook with room for future celebration

**Evidence:** Captures 2/4 have pleasant foliage but no composed location to show a fish with friends. **Build:** At (-235,94), outside the southern promenade, create an 18×10 dry terrace facing the pond, with a 6-stud-wide low carved fish crest and a background of three existing cherry/cloud specimens. Keep a 10-wide spur to the loop and a clear 8×8 posing area. No forced camera or daily-reward marker. Future catch celebration may use a 1-second, low-intensity pearl glint around the held fish, isolated from the rest of the pond. **Benefit:** A social screenshot destination that reinforces the map's first impression and potential fishing rewards without building that economy now. **Depends:** 01/09/17 and southern neighbor sightline review. **Effort/risk:** M; excessive secondary landmarks. **Accept:** Three avatars fit a default-camera photo with pond, foliage and fish visible; no special lens/teleport is required, sign and props remain below Y=10, and the nook does not obscure Heaven gate visibility from the main approach.

## Delivery sequence and five priorities

**Top five, in order:** 01 promenade, 08 grounding, 02 pier kit, 05 shoreline, 11 spring landmark. These transform function and perceived quality before adding FX or fishing code.

- **Phase A — measurable architecture:** 01, 03, 04; mark ten avatar/rod envelopes, capture top-down plan and walk all interfaces. Establish locked ground polygons before dressing.
- **Phase B — native asset finish:** 08, 02, 05, 06, 09, 10, 07. Reuse library assets, fix grounding and collision, then compare the same four cameras.
- **Phase C — destination composition:** 11, 13, 14, 15, 20. Review silhouettes with Coin Garden and northern/southern landscape owners; remove any focal object that competes with the gates.
- **Phase D — art and atmosphere:** 12, 19, 16, 17. Generate only approved missing assets after native options are exhausted; QA models/FX separately before importing into the existing preview.
- **Phase E — future integration design:** 18 plus rod equip, fish motion, catches and rewards. This phase requires a gameplay contract and is not implicitly authorized map work. Keep review specimens inert meanwhile.

## Asset briefs and pipeline choices

| Asset family | Art direction and deliverable | Initial review target |
| --- | --- | --- |
| Pier/shelter kit | Pale limewashed wood with bronze joinery; clean modular planks, posts, brace, fascia and modest bowed roof. Blender/native construction, one shared trim atlas. | Pier decorative mesh ≤1,500 triangles per station, simple separate collider; shelter ≤6,000 triangles. |
| Pearl spring | Existing pearl_quartz first; only generate a missing carved bowl/finial. If needed, ImageGen: “small stylized celestial spring bowl, hand-cleft ivory rock, modest bronze halo, broad stable base, no water, no background, game prop orthographic reference.” Meshy then Blender. | One focal assembly ≤8,000 triangles; animated water kept separate. |
| Fishing rod | Long readable tapered shaft, small feather reel, explicit hand grip, no attached fishing line in generated mesh. | ≤2,500 triangles, one 512–1024 atlas, separately pivotable reel; final budget measured. |
| Fish trio | Distinct koi, ribbonfish and ray silhouettes; broad readable fins, pearl/cyan/pink restrained palette; no thin strands. Separate side/front views before Meshy. | ≤2,000 triangles each initially, shared material where practical, 3–5-bone simple swim test in Blender. |
| FX textures | Small alpha petal and ripple, grayscale splash ribbon; reuse existing legally available textures before ImageGen. | One 512 atlas where viable; no unique 4K flipbooks for small effects. |

Targets above are proposal budgets, not platform limits or achieved counts. Preserve source references, generator provenance, Blender file, processed exports and Assets manifests. Meshy (“Meshi” in the request) is available in the established pipeline; it is not required for precise board/plank geometry. All IDs, placements, palettes, effect distances and tunables belong in config or the config-named art companion. Do not hardcode art in gameplay services.

## FX tooling reality and movement reuse

Inspected `/Users/jason/Documents/RBX-FX-GEN/docs/wiki/INDEX.md`, `CURRENT_STATUS.md`, and `ARCHITECTURE.md`. The existing lab implements **crystal eruption** with deterministic seekable timing, config validation, local preset saving, textured meshes/vapor/glints, and a minimal crystal CombatFX adapter. A generalized effect editor, multi-effect tracks, export browser, mining and production/mobile verification are **not complete**. Use its configuration, seeded timeline and preview/cleanup patterns as references for a future fishing FX preset; do not claim it already produces water, fish or rod effects. Native Beam/ParticleEmitter prototypes are sufficient to validate the visuals, but the current crystal-only lab must not constrain the design. The user explicitly welcomes modest extensions within RBX-FX-GEN. Build the small reusable effect modules below there during implementation; keep game-specific placements and event authority in Halo & Horns.

### Modest FX-GEN extensions to implement for this section

These support improvements 12, 18 and 19; they are implementation tasks within those improvements, not additional design items. None exist yet.

| Reusable extension | Concrete renderer/preset work and assets | Effort and validation |
| --- | --- | --- |
| `flow_ribbon` (12) | Add a renderer for two attachment-defined curved Beams plus a bounded impact emitter. Preset schema: endpoints, curve, widths, texture scroll, palette, splash rate, seed, duration/loop flag. Reuse crystal lab transport and save validation; add a simple effect selector for this renderer only. One splash/ribbon alpha texture shared with fountain where suitable. | M, roughly 1–2 days after a visual proof; preview seek/pause at 0/25/50/100% for finite variants, start/stop loop 100 times with no surviving instances or listeners. At most two Beams and 24 splash particles here. No water simulation or generic node editor required. |
| `fishing_ripple` (18) | Small reusable burst renderer: attached bobber position, one expanding ring mesh or oriented particle, optional small splash, analytic scale/fade over 0.8–1.2 seconds. Optional line Beam supplied with two external attachments. Preset owns ring size, timing, palette and emission; gameplay only triggers it later. One alpha ring texture, with static fall-back if animated texture is unavailable. | S/M, roughly 0.5–1 day; deterministic seek before/after lifetime, repeated stop/dispose, ten simultaneous mocked stations; cap at two visible rings per station, no sustained frame loop per station, reduced-motion variant keeps a static cue. |
| `ambient_drift` (19) | Native ParticleEmitter wrapper with bounded region, seeded start phases, rate/size/lifetime/palette preset and distance/reduced-FX toggles. Reuse existing petal alpha where possible; image-generated new sprite only if missing. A generic small emitter preset also serves leaf, ash and snow drifts elsewhere. | S/M, roughly 0.5–1 day; test enable/disable 100 times, distant retirement and settings changes; no orphan source Parts. Four emitters and 20 live particles maximum here. True deterministic reconstruction of every built-in particle is unnecessary: lab seeking can clear/restart with documented preview semantics. |

Add schema tests and a native Studio smoke check for each renderer; use the current preset writer's fixed validated paths, expanding its approved effect registry narrowly. Record measured render cost under ten mocked anglers and worst-case camera overlap. A universal track editor, arbitrary asset browser, fluid simulation or cross-game packaging UI would be a separate larger tooling project; none is prerequisite for these effects.

Read `src/Client/Systems/MergeEggPrototypeObserver.lua` around `inferLandSharkField`, `landSharkWander`, and `registerLandSharkRig`. The deterministic sinusoidal wander function is a plausible motion reference. The registration/field logic depends on Merge bay IDs, Bulwark anchors, rectangular fields, chase/drag/bite/breach tuning and combat-oriented attributes. It is **not a drop-in pond controller**. Future fish need an ellipse-constrained habitat, water depth, schooling/visibility rules and cosmetic versus authoritative catch separation. Review/extract only the useful movement math in a later scoped implementation; do not bring the whole observer into this hub.

## Neighbor interfaces and acceptance gate

- **Coin Garden, east:** Preserve its 64-stud field and Egg of the Week routes. Promenade's eastern edge is near X=-152; survey actual garden/path faces before finalizing, use one shared cleaved boundary, and connect through existing northern/southern circulation rather than across the drop lawn. If eastern loop clearance fails, first reshape its material boundary within available land; do not widen island by default.
- **Outer boundary:** Existing wall X=-296 and clipped corners remain authoritative. Western promenade ends about X=-280, allowing a narrow planting/safety margin. Place scenery by visible bounds, never force users against an unseen wall. No collision gap after shoreline work.
- **North / Bragg:** Shelter/spring are local landmarks below the gate title hierarchy; maintain the existing rim/rotunda routes. Their exact final footprints require shared top-down intersection review with the neighboring section.
- **South / Heaven gate:** Preserve gate-facing sightlines and the established arrival path. No sign, camera force, bright FX or photo nook redirects a newly spawned user before the main choice.
- **Hell counterpart:** Same global native-water settings, independent atmosphere and habitat art. No generalized water recolor. Heaven calm water is the visual counterpoint to Hell's approved thick green mist; balanced importance does not require duplicated geometry.

Ten simultaneous players is the functional gate: test all ten station work zones with rods, all ten behind-station passing routes, two opposing pedestrians, seating egress, swim return where accessible, and all protected sightlines at 24 studs/sec. Place temporary full-size references before art approval. Repeat original four screenshots plus a low grazing-angle seam sweep after each phase; check lowest/highest graphics and supported avatar sizes. No overlaps repaired by stacking nearly coplanar surfaces.

Initial section-only performance targets: total added decorative geometry ≤60,000 triangles, one shared wood atlas and one shared small-prop atlas where possible, ≤44 simultaneously live ambient/spring particles, ≤2 spring Beams, and ≤6 optional visible cosmetic fish on high settings (0–3 low). Fishing lines would add up to ten only when gameplay exists. These are provisional caps; profile in the populated whole map, especially water/foliage overdraw. Disable distant optional FX beyond roughly 100 studs with hysteresis, use pooled updates rather than ten independent frame loops, and keep decorative parts noncolliding/non-touching/non-querying. Dynamic shadow-casting lights are unnecessary here. Review added CPU/GPU frame time against the same-device baseline; a suggested rejection trigger is >2 ms p95 increment, subject to the project's actual target-device budget.

Accessibility: maintain 12-stud circulation and gentle thresholds; no forced swimming, camera manipulation, flashes or fog through working areas. Distinguish stations and future bite cues through shapes and motion as well as color; reduced motion retains static bobber visibility. Quiet ambience remains optional and independent of gameplay signals. None of these suggested budgets or acceptance tests have been executed by this design-only review.
