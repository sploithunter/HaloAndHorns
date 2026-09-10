# Section 08 — The Sulfur Pool

Design review, 2026-09-08. **Proposal only.** Preserve the real water, the green mist and the eight-station capacity. Make this feel like a carefully maintained fishing refuge behind the arena: weathered timber, small iron fittings, mineral-crusted banks, quiet supernatural life and one memorable fossil landmark. Its premium character should come from construction, composition and restrained motion.

## Evidence, measurements and protected decisions

All five [review screenshots](screenshots/08-hell-fishing-1.png) through [image 5](screenshots/08-hell-fishing-5.png) were opened and visually inspected. Image 1 exposes the eight identical deck slabs, elliptical shoreline, stand adjacency and repeated outer tree row. Image 2 exposes thin pier posts, an abrupt bank and scenery apparently floating above the ground. Image 3 makes the stand's blank rear wall especially prominent and shows a large isolated pale mineral. Image 4 shows the water corridor between stations and a faint green tint; image 5 shows the broad undecorated approach and repeating platform silhouettes. Still images cannot establish the mist's motion or density in Play; they are not evidence that it is missing.

Read `docs/wiki/INDEX.md`, `REALM_CROSSROADS.md`, `configs/realm_crossroads_fishing.json`, `bake_fishing.luau`, `bake_pool_mist.luau` and the neighboring section 06 proposal. Source is authoritative for dimensions. Pool center is **X244/Z8**, radii **28/48**, nominal footprint **56×96**, surface **Y2**, bottom **Y−4**, bank **Y4**. Actual voxel shoreline/surface must be sampled in Studio before construction. The eight decks are **10×12×0.5**, top **Y4.5**, radial offset **1**. Terrain extends to X300 locally; invisible boundary is X296 on the east segment. Flora rows are X284/291.

The west shore X216 and stand rear X199 leave **17 studs before deck intrusion**. Station 5 center is X215/Z8; its 12-stud radial depth extends west to **X209**, leaving **10 studs**, not 12. That calculation excludes any rear-wall ornament and avatar/camera clearance. Do not add buttresses, furniture or a rear access ramp in this strip. All dimensions below are proposed envelopes, not completed native measurements. North is −Z; positions use `(X,Y,Z)`; platform local forward points into the pool.

The existing mist baker authors 20 sources: rate 4 each, lifetime 5–8 seconds, size sequence 10/18/23, opacity 0.45, source Y3. Mean steady-state population is approximately **20 × 4 × 6.5 = 520 particles**, with approximately 400–640 for the lifetime endpoints at that emission rate; device quality and rendering can differ. These are estimates, not GPU measurements. The same Terrain water color must remain for both ponds: Roblox documents WaterColor as affecting all Terrain water [S1]. The obsolete-looking `hell_liquid` color fields are not permission to restore a plastic water plane; current mode is `terrain_water`.

## Twenty detailed improvements

Effort is focused implementation time after design review; asset queues and gameplay integration are excluded. Every acceptance statement is a future check.

### 01 — Recover a measured twelve-stud rear passage

**Design and placement:** Keep the pool ellipse unchanged. Trial moving only west Station 5 two studs toward the pool, from center `(215,4.25,8)` to `(217,4.25,8)`. Its back edge becomes X211, creating a nominal **12-stud strip X199–211** behind the stands. Retain 10×12 deck size and all eight stations; add a flush, four-stud-long bank-to-deck approach within the existing deck width where needed. Do not put a side rail, planter or sign into this strip.

**Method/benefit:** Config-owned per-station offset; native decking. This resolves the known pinch without widening the land or water. **Dependencies:** Section 06 rear-wall outer plane must stay at or inside X199; sample real terrain and stand mesh bounds. **Effort/risk:** 0.5–1 day; stronger cantilever and potential dock approach step. **Acceptance:** Measure 12 clear studs with final wall skin and platform; two avatars pass, camera stays usable, and all eight station approaches work at speed 24. If the measurement fails, resolve the local geometry before considering expansion.

### 02 — Give fishing two legible end approaches

**Design and placement:** Continue section 06's nominal 12-stud stand-end walks at Z−35 and Z51 toward the fishing bank, then turn around the diagonal station envelopes. Use **12-stud clear turning landings**, with an inner route through the recovered rear passage and a branch around each pool end. End stations centered near Z−41 and Z57 extend to approximately Z−47 and Z63; the outer circulation must pass beyond those deck backs, approximately Z−53 and Z69 centerlines, subject to measured clearance.

**Method/benefit:** Cleaved native stone paving, dark enough to belong to Hell but lighter than the soil. This makes access feel intentional and keeps visitors out of combat. **Dependencies:** 01; shared arena end walks and actual rotated deck bounds. **Effort/risk:** 1 day; a straight connection would cross diagonal platforms. **Acceptance:** A connected 12-stud route drawing and native walkthrough demonstrate both approaches and turn corners. No overlapping floor sheets, dead-end pockets or assumed widths based only on centerlines.

### 03 — Turn the eight slabs into crafted fishing piers

**Design and placement:** Preserve each 10×12 top envelope and Y4.5 level. Divide visible tops into five broad planks with uneven end grain, a **0.7-stud fascia**, two **0.8-stud support beams** below, and the four existing post locations refined to **0.7×0.7**. Add diagonal braces entirely below deck and above the bed; dark iron shoes sit at connections. Keep the functional floor continuous under visual seams.

**Method/benefit:** Native structural parts plus one shared Blender end-grain/iron detail kit, existing WoodPlanks material where it looks good. Credible construction gives the largest close-range improvement. **Dependencies:** 01 station move; water/bed samples. **Effort/risk:** 1–2 days; too many individual plank details raise instance count. **Acceptance:** Eight identical collision envelopes, varied superficial wear, no floating posts, no snagging gaps, braces invisible above the fishing edge. Repeated parts share meshes/materials; no decorative screws modeled individually.

### 04 — Frame safe standing without fencing off the water

**Design and placement:** Mark a **6×6 clear angler zone** at each deck's water-facing half using shallow iron corner inlays. Add only **two 2.5-stud-high corner bollards**, **0.6 stud thick**, at the lateral water-facing corners; keep the middle **8 studs open** to cast. Put a low **0.2-stud visual toe strip** on lateral edges, inside deck bounds, without a tripping collider. Omit landward rails entirely at Station 5.

**Method/benefit:** Native parts and shared low-relief fittings; simple deck collision. Players can read a comfortable place to stand while the pool stays visually open. **Dependencies:** 03; future fishing stance/camera envelope. **Effort/risk:** 0.5 day; attachments might clip large avatars or rods. **Acceptance:** Default and largest supported avatar can turn, equip a rod proxy and enter each zone; no rail across cast direction, no loss of eight-station count. This is layout, not a reservation system.

### 05 — Compose a mineral shoreline in broken bands

**Design and placement:** Keep the current ellipse and exposed real-water edge. Place **1–2-stud-wide**, **0.4–1.2-stud-high** broken charcoal stone/mineral clusters on roughly one-third of the bank, concentrated between stations rather than forming a complete curb. Use 3–5-piece clusters over **5–8 studs**, feathered into Terrain. Within the rear strip use inset material wear only; do not grow rocks into X199–211.

**Method/benefit:** Reuse bone_rock and tinted pearl_quartz where their silhouettes work; Blender a small basalt cap only if native assets cannot produce low profiles. This breaks the machine-cut ellipse without replacing or hiding water. **Dependencies:** 01–04 route/deck envelopes. **Effort/risk:** 1 day; excessive rocks read as obstacles or disguise bad terrain joins. **Acceptance:** At least two-thirds of shoreline remains visually open; all station approaches clear; no underwater full-surface mask, z-fighting, or shoreline geometry presented as liquid.

### 06 — Explain the green mist with quiet mineral seeps

**Design and placement:** Set three small **3×2×1.2-stud** sulfur deposits between stations on the east/northeast/southeast bank. Select positions from the inter-station ring, then move outside the measured approach routes. One hairline seam or narrow wet streak points toward the water at each deposit; it ends at the edge rather than becoming a new stream. Muted olive/sulfur accents echo the existing mist.

**Method/benefit:** Existing tinted mineral meshes, baked roughness/color variation and at most three tiny local vapor sources taken from, not added above, the existing mist allocation. Gives the effect a believable environmental origin. **Dependencies:** 05 and 07; final texture-tint test because textured assets may not recolor uniformly. **Effort/risk:** 0.5–1 day; could imply toxic damage. **Acceptance:** Reads as scenic mineral activity with no warning signage, damage volume or promised mechanic; no luminous puddle plane and no occlusion of bobbers.

### 07 — Art-direct the approved mist around the casting lanes

**Design and placement:** Preserve the current green palette and baseline as a selectable comparison preset. Trial a softly broken central body over **X228–260/Z−26–42**, with station-facing emission reduced within **6 studs** of each cast target. Tune emitter positions/rates within the existing 20-source budget before adding anything. Keep shore cameras able to see opposite deck edges through the plume; retain visible water reflections between curls.

**Method/benefit:** Native ParticleEmitters with current smoke texture first, no new water or global Atmosphere. Particle size, overlapping transparency and graphics quality matter more than emitter count alone [S2]. **Dependencies:** 04 targets, 18 quality tiers and a Play recording of the approved baseline. **Effort/risk:** 1 day; still screenshots can encourage over-thickening. **Acceptance:** Compare matched 20-second Play clips at bank/deck/stand and low/high graphics; approve retained character and readable water before saving. No claim that the current effect needs replacement merely because still captures are weak.

### 08 — Add intermittent tiny surface life

**Design and placement:** Place three potential bubble/ripple anchors in the central water, initially near `(236,2,−12)`, `(251,2,12)`, `(241,2,32)`, corrected to the actual surface. At most one cluster active: **1–2.5-stud** ripple footprint, **0.8–1.2 seconds**, proposed interval **8–14 seconds**. Keep four studs from future bobber targets.

**Method/benefit:** Client-local short native particle bursts using a simple ring/bubble texture; no transparent rectangular surface or physics bubbles. Gives the pool a living rhythm. **Dependencies:** 07 and a future shared ambient scheduler; remain disabled if no client companion exists. **Effort/risk:** 0.5–1 day; could be mistaken for a bite. **Acceptance:** Ambient motion stays visibly weaker than any future bite cue, no synchronized flashing, no gameplay signal implied. Reduced-motion mode disables it, and the quiet pool still reads correctly.

### 09 — Make the stand rear a finished architectural edge

**Design and placement:** Coordinate section 06's wall design: inset panels **8–10 studs wide**, shallow vertical seams and a **0.4-stud cap** recessed into the existing wall volume. Put a subtle fishing-side mineral damp band across the bottom **1.5 studs**, with relief fish/ripple details only at the end bays. The exterior face remains **X199 maximum** after finishing; do not attach outward buttresses.

**Method/benefit:** Shared native stone panels or a Blender low-relief skin replacing, not layering over, the face. The largest blank object becomes an intentional backdrop without stealing passage width. **Dependencies:** Arena sightline/tier height decision and 01; arena owns structural work, this section owns desired pond-facing finish. **Effort/risk:** 1 day shared with section 06; two independently authored wall skins conflict. **Acceptance:** One owner and one wall assembly, no duplicated caps; X199 boundary verified and mist remains distinguishable against the wall from images 3/4 cameras.

### 10 — Re-seat every outer landscape asset

**Design and placement:** At the current X284/291 rows, ground every visible trunk, bone and brush using its actual mesh bottom rather than pivot. Embed roots **0.3–0.8 stud** into sampled ground, add **3–5-stud** root/stone collars only where needed, and keep branches beyond the clear station routes. Do not simply lower all tree pivots by one common amount.

**Method/benefit:** Reposition existing native textured flora; no new tree generation. Images 2/4 show apparent air beneath several silhouettes; proper seating immediately removes a prototype cue. **Dependencies:** Final terrain surface and boundary survey. **Effort/risk:** 0.5–1 day; visual bounds can include hanging spikes. **Acceptance:** Inspect low bank cameras around the pool: no visible sky gap beneath intended root contact, no buried crowns, and existing invisible safety boundary still blocks departure. Record which roots intentionally cantilever over cliff versus genuinely float.

### 11 — Break the perimeter's repeated tree rhythm

**Design and placement:** Keep the existing Hell tree species, but arrange three loose groups of **2–3 trees**, separated by **10–16-stud visual gaps**, within the current eastern planting zone. Vary visible heights approximately **18/24/30 studs**, using actual existing model quality to decide which leads. Alternate a lava-eye tree with plain dead silhouettes; allow a few branches to frame the pool without crossing the center view at avatar head height.

**Method/benefit:** Native instance reuse, config-owned scale/yaw/placement. This replaces a pasted row with depth while preserving the accepted Hell vocabulary. **Dependencies:** 10 and 12 hero composition; do not enlarge the island. **Effort/risk:** 0.5–1 day; tall repeated eyes can dominate the water or expose the boundary. **Acceptance:** Three clear groups in overhead view and asymmetrical silhouettes in images 2/4/5 matching cameras; no tree trunk inside route/deck envelopes, no newly exposed walk-off.

### 12 — Commission one small fossil fishing landmark

**Design and placement:** A weathered horned fish fossil cradled in black stone, **10 wide × 6 deep × 9 high**, provisionally centered around `(282,4,8)` in a deliberately cleared outer planting pocket. Tail curls upward, skull faces obliquely toward the south approach; avoid a cavern mouth or monumental arch. Keep its nearest edge at least **12 studs beyond the east deck's landward edge**, adjusting within the existing planting area or reducing width if the measured route fails.

**Method/benefit:** New hero via ImageGen → Meshy → Blender → Assets → Roblox, with separable stone/fossil/optional dull mineral inserts. One authored landmark makes this fishing pool recognizable. **Dependencies:** 11 route/tree composition and actual rotated bounds; may require a smaller 8-stud variant. **Effort/risk:** 2–4 days plus queue; generated bones can become noisy or grim. **Acceptance:** Friendly stylized silhouette, no gore, reads from both end approaches, does not block water or imply a boss/reward. High/low asset versions pass the shared asset brief below.

### 13 — Replace isolated pebbles with ecological clusters

**Design and placement:** Recompose the current bone_rock/dead_brush/pearl_quartz specimens into six low clusters, each **4–6 studs across and 1–3 high**, biased toward outer bank and pool ends. Use one large shape, two small shapes and a patch of dead brush per cluster; avoid equal spacing and keep the recovered rear passage empty. Use pale bone sparingly against dark soil, with olive minerals nearest seeps.

**Method/benefit:** Existing native assets scaled by visible bounds, shared textures retained. The ground looks inhabited rather than sprinkled with unrelated samples. **Dependencies:** 05/06 routes and hero footprint. **Effort/risk:** 0.5 day; pale specimens can overpower the pool. **Acceptance:** Every cluster has a ground contact and clear silhouette; no identical triplets at repeated angles, no lonely floating specimen, and two low-detail clusters can be omitted on low tier without changing function.

### 14 — Introduce a compact physical fishing identifier

**Design and placement:** At the southern approach outside the route, trial a **4×1.5-stud base**, **5-stud total height** sign with a **3×2** carved fish/ripple emblem and short “FISHING” title. Position only after the Z69 circulation line is checked, preferably on its landward side; no sign in the west pinch. A second small emblem at the north approach is optional within this same item.

**Method/benefit:** Existing extruded glyph pipeline, native stone/metal relief. Makes the activity findable without floating UI or fabricated prices. **Dependencies:** 02 and copy localization policy. **Effort/risk:** 0.5–1 day; a fully operational sign could overpromise the layout-only feature. **Acceptance:** In the current preview, label accompanying review metadata clearly as unconnected fishing; production enablement awaits the real feature. Symbol remains recognizable at 20 studs and in grayscale; no rods-for-sale/reward/economy text.

### 15 — Give each station a small, consistent identity

**Design and placement:** Add an inset **1.2×0.8-stud** fish-hook plate at each landward deck corner, plus a stable station numeral 1–8. Mount a **0.25-stud-wide rod socket** on one lateral fascia, below standing height and within existing bounds. No bins, chairs or large tackle chests on the 10×12 decks.

**Method/benefit:** Shared relief kit, deterministic station metadata. Helps friends identify a pier and makes a later interaction anchor obvious. **Dependencies:** 03/04 and shared future fishing convention with Heaven. **Effort/risk:** 0.5 day; numbers can look like ranking or paid tiers. **Acceptance:** All plates use equal materials/scale and no rarity colors; preserve StationIndex exactly; markings are decorative and do not reserve ownership. Socket does not catch avatars or change collision.

### 16 — Design a readable Hell fishing rod

**Design and placement:** New prop **5.5 studs long**, shaft maximum **0.25 stud thick**, grip **1 stud**, a curved blackwood/bronze tip and a small dull-green mineral knot. Future hand grip and line-tip Attachments are explicitly named. Preview one rod in an off-route display fixture, not eight permanently equipped dummy rods. Fish line uses a thin native Beam only during later local interaction.

**Method/benefit:** ImageGen style sheet → Meshy optional rough concept → Blender precision rebuild/cleanup → Assets → Roblox. A simple tool silhouette suits the compact docks and avoids a giant weapon-like rod. **Dependencies:** 04 cast envelope and actual avatar tool grip contract. **Effort/risk:** 1–2 days plus queue; generated topology is poor for thin shafts, hence Blender owns final dimensions. **Acceptance:** Correct hand scale and pivot, readable tip against mist, no idle luminous trail; display contains no functional Tool or prompt until gameplay is separately implemented.

### 17 — Create two distinctive fish silhouettes for future use

**Design and placement:** Commission a **2.5×1×1-stud lantern-fin fish** and a **3.5×1.2×1.2-stud blunt horned eel**, sized for catch presentation. Use charcoal bodies, warm bone fins and restrained sulfur markings; avoid covering them in full-body neon. They are art candidates, not additions to catch odds or reward tables. Optional later ambient preview shows only one fish silhouette at a time **1–2 studs beneath the sampled water surface**, away from cast targets.

**Method/benefit:** ImageGen → Meshy → Blender retopology/UV and a simple 3–5-bone swim rig → Assets → Roblox. Distinct body shapes retain identity through tinted water. **Dependencies:** 07 visual contrast and a separately approved fishing feature; shared fish pipeline with Heaven. **Effort/risk:** 2–3 days plus queue; underwater readability and swimming expectations. **Acceptance:** Each reads in grayscale, static display and basic swim pose without fin collapse; no ambient swimmer enabled unless quality/streaming lifecycle exists. No species rarity, currency, prices or rewards invented.

### 18 — Make quality and motion settings preserve the mood

**Design and placement:** Retain authored mist sources but propose client quality presets: Full starts at the accepted 20×4 baseline; Reduced trials **20×2** with the same green character and smaller maximum sprites; Minimal retains a sparse **8-source** layer near the center, with exact rates decided by measurement. Additional bubbles/swimmers turn off first. The physical mineral composition carries identity if particles are unavailable.

**Method/benefit:** Future shared client FX quality adapter, respecting the existing game's graphics preferences rather than a separate pond-only menu. RBX-FX-GEN currently provides a crystal eruption lab, deterministic timeline, preset validation and a narrow crystal adapter; it is not a ready general ambient-fishing editor. Extend that pipeline with the small reusable ambient renderer and schemas below; its present crystal scope does not limit this proposal. **Dependencies:** 07 and global budgets across all eight areas. **Effort/risk:** 1–2 days integration; independent local FX scripts can leak effects. **Acceptance:** No flicker or abrupt clearing on thresholds, no camera shake/flashes, no essential cue conveyed only by green; disabling decorative motion retains clear deck edges and fishing identity.

### 19 — Give the pool a restrained local sound bed

**Design and placement:** Proposed one low bubbling/water emitter near `(244,3,8)`, audible mainly within **35–50 studs**, with a subtle wood creak at a nearby occupied station only when future interactions warrant it. Start with one loop, no ambient screams or repeating jump scares. Exact volume and rolloff belong in config after arena comparison.

**Method/benefit:** Licensed/authored audio imported through the established asset path; native positional Sound or the game's existing sound system. Adds atmosphere without more transparent screen coverage. **Dependencies:** Whole-hub sound mix and real gameplay event contract for creaks. **Effort/risk:** 0.5–1 day plus sound sourcing; arena and pool loops can mask each other. **Acceptance:** Pool sound falls away before dominating the arena/arrival, existing volume/mute preferences work, and no sound is the sole indication of a future bite. Layout-only build may ship with ambient loop alone or silence until shared routing exists.

### 20 — Add two discreet points of warm night readability

**Design and placement:** Put two existing Hell skull-lantern variants on **3.5-stud posts**, each in a **1.5×1.5-stud** footprint outside the north/south approach clearances. Keep illumination warm amber to contrast green mist; proposed light radius **12 studs**, static brightness, shadows off. Use no lights on all eight piers and none in the X199–211 passage.

**Method/benefit:** Reuse native lantern art, restrained PointLight only if lighting tests show it is useful. Gives small orientation anchors against the dark ground without replacing daytime art direction. **Dependencies:** 02/14, existing global lighting and shared light budget. **Effort/risk:** 0.5 day; emissive accents can compete with mist and hero. **Acceptance:** Deck edges readable in supported lighting, no distracting pulse or glare, no illumination spill dominating stands; low tier can remove lights while keeping visible lantern geometry. If the world never uses dim lighting, retain only non-emissive fixtures or omit until needed.

## Five priorities

| Order | Improvement | Why first | Gate before proceeding |
| --- | --- | --- | --- |
| 1 | 01 — Rear passage | Known 10-stud pinch undermines every finish decision | Actual wall/deck clearance recorded; eight station access retained |
| 2 | 03 — Crafted piers | Eight highly visible repeated objects define the activity | One prototype accepted from bank and water before cloning |
| 3 | 07 — Mist composition | Protects the effect the user already likes | Approved baseline versus candidate Play clips; water stays visible |
| 4 | 09 — Stand rear | Largest plain surface in opposite-shore views | One coordinated arena owner; exterior plane preserves passage |
| 5 | 10 — Flora seating | Apparent floating roots expose the blockout immediately | Low-camera contact pass on every visible eastern specimen |

## Asset briefs and production contracts

These are proposed art budgets, not Roblox platform limits or verified performance outcomes. Native reuse is the default for decking, trees, bones, brush, quartz, signs and lanterns. The general import/model specifications are the current compatibility reference [S3]; profile the assembled scene rather than relying on triangle count alone [S4].

| Asset | Brief and deliverable | Proposed budget and fit checks |
| --- | --- | --- |
| Pier detail kit | One fascia/end-grain module, iron shoe, brace and hook plate; native timber remains primary | Shared 512px material atlas where useful; detail meshes under 1,500 triangles combined per unique kit; simple collision proxies only |
| Fossil landmark | Three-quarter and side concept; closed friendly fish skull, curling tail, clear stone base; separate inserts | About 8,000 triangles high / 3,000 low total; one shared 1024px set; 10×6×9 maximum; bottom pivot and forward axis verified |
| Rod | Orthographic silhouette/grip reference; blackwood shaft, bronze tip, tiny mineral knot | About 1,500 triangles; one 512px set; Grip and LineTip attachments; 5.5-stud visible length; no decorative collider |
| Two fish | Matched silhouette sheet; broad fins versus long body; neutral swim/catch pose; original designs | About 3,000 triangles each, 512px set per fish or shared atlas; 3–5 bones if rigged; scale and normals checked underwater |
| Optional ripple texture | Soft broken ring plus tiny bubble, transparent padded border; keep current mist texture first | One 256–512px static alpha sheet; no new flipbook unless motion cannot be achieved simply |

For the three newly commissioned hero/tool/fish assets, use **ImageGen → Meshy → Blender → Assets → Roblox** as a traceable sequence. Review the image before committing to mesh detail; Meshy is a starting mesh, not final topology. Blender must repair silhouette, disconnected fragments, UV seams, normals, pivot, scale, material count and rig where needed. Keep source image, generated mesh, `.blend`, clean export, texture maps and native `.rbxm` with provenance. Assign uploaded asset IDs and all palette/dimension values only in config. Compare the Roblox result to Blender because import orientation/material handling may differ. Do not reuse a pet quadruped rig for a fish by assumption. Thin rod geometry may be rebuilt almost entirely in Blender while retaining the concept's design.

## Phased implementation plan

| Phase | Work sequence and outputs | Dependencies / acceptance / rollback |
| --- | --- | --- |
| A — Survey and freeze | 0.5–1 day. Capture current Play mist for 20 seconds from all five review camera positions. Sample terrain water/bank heights; export actual rotated station/wall/tree bounds. Draw station and avatar/rod/camera envelopes. Record particle/render counters with arena and nearby gate effects visible. | No asset generation needed. Deliver measured plan including X199–209 pinch. Retain source config and native model/terrain backups. This review itself performs none of those live measurements. |
| B — Access prototype | 1–2 days. Implement 01/02 on one isolated local candidate: per-station offset, end-route paths, shared arena-wall envelope. Use plain geometry first; preserve water ellipse and eight station anchors. | Walk and two-avatar passing tests at speed 24 plus mobile camera check. If inadequate, revise offset/route geometry before new footprints; rollback only this candidate's route/deck transform. |
| C — Construction and native landscape | 3–5 days. Prototype 03/04 on one dock; approve then clone. Coordinate 09 wall finish. Re-seat flora 10, group 11, finish bank 05/06 and clusters 13. Add 14/15 identifiers. | Requires Phase B route freeze and section 06 tier/wall decision. Check placement bounds and screenshot matches after each family. Back up model folders separately; never rebake all terrain over the authored preview casually. |
| D — Hero and equipment art | 3–6 focused days plus asset queues. Concept 12/16/17 together for shared language; process assets through the stated pipeline, import into a staging collection, compare scale with avatar/deck proxies. Place hero only after outer-route test. | Art review gates image, cleaned mesh and native material/scale. Fish/rod stay static previews; no gameplay/reward integration. Native reused landscape remains a complete fallback if new assets fail quality. |
| E — Effects and audio | 2–3 days. Preserve baseline; tune 07, prototype 08/18, mix 19, test whether 20 is necessary. Use a small native preview with clear settings and deterministic replay where applicable. | Requires shared client graphics/audio interfaces. Build the modest RBX-FX-GEN extensions specified below rather than waiting for a general editor. Disable optional layers first on performance failure; retain accepted mist preset as rollback. |
| F — Integrated acceptance | 1–2 days. Walk every platform and route; compare full/low graphics and reduced motion; test overlapping arena/gate/fishing effects. Verify imports, streaming cleanup and supported avatars. Capture five stills plus motion clips and measured timings. | `mise run ci` and wiki updates when implementation changes source, plus native tests that CI cannot substitute. No production routing, catches, prompts or rewards enabled by an art approval. Final review records remaining gaps explicitly. |

Effort ranges overlap where the same person owns a kit; do not sum every item as independent work. A native-reuse pass can finish before hero assets and client FX integration. Future implementation follows the repo's work-claim/draft-PR/CI rules; this document is the design deliverable only.

## Modest FX-GEN extensions worth building

The user authorizes planning small additions to `/Users/jason/Documents/RBX-FX-GEN`; current crystal-only scope is a starting point, not a creative ceiling. Implementation belongs to the later build phase. Keep its preset-validation, deterministic preview and cleanup conventions, and add narrowly scoped effects that can also serve other ponds and environmental scenes.

| Addition | Concrete renderer/preset and assets | Effort, acceptance and cleanup |
| --- | --- | --- |
| `ambient_mist` | New ambient emitter renderer with a config-owned emitter layout, colors, size/alpha curves, local drift, quality tier and station-clearance masks. Add schema bounds and a pond preview fixture to the existing lab. Reuse the current smoke texture initially; optional custom soft-edged wisp PNG can follow if it improves the native review. Preserve the accepted 20-source preset as `hell_pool_baseline`. | Approximately 1–2 days for minimal renderer/schema/lab wiring, overlapping item 18. Create/start/stop/destroy lifecycle; native simulation is visually reviewed, not claimed bitwise deterministic under scrubbing. Replay resets emitters, fixed preview camera and recorded intervals make comparisons repeatable. Stop prevents new emission; destroy clears remaining particles and source instances. No extra continuous population above baseline until budget review. |
| `surface_bubbles` | New seeded timed-burst preset: anchor list, 8–14-second delay range, at most one active 1–2.5-stud burst, 0.8–1.2-second life, ring and tiny bubble textures. Renderer uses pooled native emitters, no physics or water plane. Lab adds pause/reset/preview trigger and a mock water surface. | Approximately 0.5–1 day after lifecycle support. Verify same seeded event schedule, surface attachment, zero lingering instances after stop/destroy, no new burst at low quality/reduced motion. Judge whether a two-frame or four-frame ring sheet is actually better before spending additional texture memory; static ring is the default. |
| `mineral_seep` | Thin vapor preset sharing `ambient_mist` renderer, with three anchor points, 1–3-stud sprites, restrained upward drift and the same smoke texture. Uses three sources reallocated from the 20-source field, not a separate unlimited layer. | Approximately 0.5 day for preset/art pass after renderer. No new general layer editor required. Test that seep density does not hide shore geometry or imply danger; destroy alongside pool unload, and return the source allocation to the central field if seeps are rejected. |

These additions need a small native lab scene, reusable lifecycle, preset validator and adapter into the host game's existing client quality/audio boundaries. Do not fork the entire crystal CombatFX facade or add server reward logic. Test schema rejection, seeded burst scheduling, repeated start/stop, quality switches, distance re-entry and renderer cleanup; then compare actual Roblox low/high graphics clips. A timeline with arbitrary layer tracks, a full asset browser, generalized export UI or a fluid simulator would be a larger tooling project and is unnecessary for these three effects. Fish swimming can use a later small game presentation controller once the fish rig is accepted; it does not require expanding FX-GEN into an AI system.

## Interfaces, ownership and operational budgets

- **Arena:** Section 06 owns stands, seats, wall structure, height and end access. This section supplies pond-facing requirements: exterior wall plane at/before X199, uncluttered rear route, coordinated Z−35/51 approach joins. No independent wall rebuild or rear ramp. Arena and fishing designers sign off the same measured corner plan.
- **Heaven fishing:** Share station schema, rod grip/line attachments, cast/standing envelopes, quality preferences and eventual input accessibility. Keep Hell art/palette/mist distinct. Pool geometry and 8 versus 10 stations are not forced into symmetry.
- **Configuration:** Extend the existing fishing config with proposed `station_overrides`, `shore_clusters`, `asset_refs`, `fx_quality` and `ambient_audio` structures only during implementation. Preserve `terrain_water`, pool radii, station numbering and current mist preset. All placements, tunables, IDs and text live in config; no content constants in services.
- **Authored versus runtime:** Edit bakers produce static Terrain/decks/decor. Optional motion/audio use one shared client lifecycle with distance/quality gating, not one loop per pier. Decorative colliders remain disabled; retain deck floor and safety boundary collision. No active fishing tag or server request is created by adding art markers.
- **Future gameplay:** Stable metadata can define `StationIndex`, Standing/Cast/LineTip anchors and intended binding. Later server authority must own catch eligibility/outcomes and existing reward systems; ambient fish, mist and bubbles are cosmetic. No economy, catch tables, rarity or new currency is designed here.
- **FX budget:** Baseline ~520 live mist particles is already meaningful. The first pass adds no net continuous mist sources. Optional ripples cap at one short burst; swimmers cap at one visible; two shadowless lights are a proposal, zero on Minimal. These are local ceilings subject to a **single whole-hub budget** across all eight review areas, not allocations that each section can independently spend.
- **Performance gate:** On the agreed lowest supported real device, compare baseline and candidate under the same route/camera, graphics quality and nearby activity load. Provisional goal: total frame time supports at least 30 FPS and this art pass adds no more than 2 ms at the 95th percentile after warm-up; confirm project-wide target before implementation. Measure GPU/CPU separately, transparent screen coverage, instances, texture memory, draw calls and cleanup after leave/re-enter. Studio desktop FPS alone is insufficient. These targets are proposed, not measurements or guarantees [S4].
- **Accessibility:** Keep navigable silhouettes and symbols independent of green perception; avoid flashed lights, compulsory camera motion and loud startling loops. Future bite cues need visual and audio/haptic alternatives through existing input systems. Deck approach and standing pads must work with supported avatars, controller and touch. Reduced effects preserve green atmosphere where possible without sacrificing function; essential fishing cues must never be disabled with decorative mist.

## Sources and research limits

Primary Roblox documentation checked on 2026-09-08; technical guidance supports the methods, while the art direction and all numeric design proposals above are this review's recommendations.

- **[S1]** [Environmental terrain — water properties](https://create.roblox.com/docs/parts/terrain): WaterColor affects all Terrain water. Supports retaining the common water system and creating Hell identity with local scenery/mist.
- **[S2]** [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters): native emitter controls, graphic-quality differences and the cost of large/overlapping particles. Supports Play comparisons, bounded sprites and texture reuse.
- **[S3]** [General model specifications](https://create.roblox.com/docs/art/modeling/specifications): compatibility checks before export/import. The budgets in this document are deliberately separate proposed project budgets.
- **[S4]** [Improve performance](https://create.roblox.com/docs/performance-optimization/improve): scene/asset rendering and runtime optimization guidance. Supports measuring the complete scene and sharing reusable assets rather than asserting that any proposed asset count is safe.

Local FX source reviewed: `/Users/jason/Documents/RBX-FX-GEN/docs/wiki/INDEX.md`, `CURRENT_STATUS.md`, `ARCHITECTURE.md`. Current implementation is a crystal eruption effect, deterministic timeline, standalone lab/preset bridge and limited crystal CombatFX adapter. General effects editing, ambient pond export, production/mobile validation and broader packaging are not completed; no such capabilities are presumed here.
