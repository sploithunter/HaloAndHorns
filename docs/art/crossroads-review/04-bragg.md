# 04 — Bragg Rotunda: the Court of Champions

Design proposal, 2026-09-08. Plan only; no map changes, generation, upload, or ranking integration performed. Section owner: Bragg design agent.

## Direction

Make this feel like a ceremonial sculpture garden where real players are celebrated, organized around the already successful Confluence fountain. Preserve its scale and motion. Give the surrounding architecture the same craft: fitted stone, visibly supported cornices, beautiful figure displays, six distinctive living/relic exhibits, and restrained effects. The open court is useful social space; do not fill it with giant props or make the trip longer.

Use the neutral ivory/bronze rotunda to reconcile the two realms. Its six alternating Heaven/Hell exhibits remain alternating, even where their theme differs from the surrounding island half. Large landscape and light cues follow negative-X Heaven / positive-X Hell. No overhead dome, enormous second fountain, floating leaderboard billboards, or permanent fireworks.

## Evidence and measured contract

All six images were inspected individually:

| Reference | Actual evidence |
| --- | --- |
| `04-bragg-1.png` | Overhead reveals a strong circular footprint and alternating displays, but a large homogeneous floor and abrupt outer grass/dark-ground boundary. Entry and side approaches are visible. |
| `04-bragg-2.png` | Arrival view: near columns frame the court; black figures dominate, the fountain reads small at distance, and the skyline feels like thin disconnected straight lintels. |
| `04-bragg-3.png` | Floor-level panorama: two gold rings decorate a largely empty stone disk; eight board titles work but do not distinguish categories quickly. |
| `04-bragg-4.png` | Close alcoves: black figures, small scope copy, low PREVIEW plates, identical rectangular podiums, excellent skull/flower assets, exposed cornice joints. |
| `04-bragg-5.png` | Camera is caught in a narrow slot behind/between display walls, exposing plain backs and a sliver of fountain. This proves an undesirable camera view; it does not by itself prove the slot is physically traversable. |
| `04-bragg-6.png` | Fountain close-up: split water/lava, gold crown and carved basin are the quality benchmark. Surrounding floor/walls are less developed. |
| `00-whole-map.png` | Replacement capture inspected: distant central layout confirms the rotunda terminating the main approach between activity fields. Outer scenery is omitted at that distance; do not infer incomplete shorelines or missing flora. |

Coordinates below are authored proposals measured from the source contract, not image pixel estimates. Origin C=(0,4,-88); current visible court contact is approximately Y=4.44. Outer radius 58, podium radius 47, alcoves 18×10, entrance width 26. Existing eight-riser stairs climb four studs; alternate ramps are 16 wide, 32 long (1:8). Keep speed 24. Fountain remains 22 diameter, under eight high, at (0,4.44,-88), Heaven negative X. Preserve all 24 figures and rank order 2/1/3; retain current podium heights 2.7/4.1/2.1 until a specific sightline test supports changing them.

Bay numbering follows the baker: theta=33.75°+(bay−1)×22.5°, position=C+47×(sin(theta),0,cos(theta)). Existing active bays 1/3/5/7/8/10/12/14 remain Most Dragons, Crystal Crusher, Enemies Defeated, Team Power, Eggs Hatched, Highest Wave Cleared, Total Waves Cleared, Bosses Defeated—All Realms. Decorative bays 2/4/6/9/11/13 stay decorative. No reached-wave/cleared-wave substitution or new ranking semantics.

Source reviewed: `docs/wiki/INDEX.md`, `REALM_CROSSROADS.md`, `configs/realm_crossroads_bragg_plan.json`, `configs/confluence_fountain.json`, and `tools/realm_crossroads/bake_bragg.luau`. Config's `figure_budget_initial:12` is stale relative to the 24 current figures; do not treat it as permission to remove half the displays.

## Exactly 20 improvements

Effort is an initial single-artist/engineer estimate excluding external generation queues: S = under half a day; M = half to two days; L = two to four days. Dimensions are starting values for native review, not promises of tested fit.

### 01 — A deliberately fitted stone court

**Evidence:** 1/3/6 show a featureless floor and thin decorative circles. **Build:** retain radius 58 and elevation; replace the visible floor skin with 16 radial sectors, a central annulus from radius 11.25–16, broad paving from 16–36, and viewing promenade from 36–42. Use Blender-generated watertight sector meshes, shared stone UV density, and 0.06–0.10-stud recessed joints. Metal inlays occupy cut channels; the original disk must be removed beneath the new visible faces, not hidden 0.01 studs below them. Structural collision can remain one simpler slab with its top recessed at least 0.25 studs. **Benefit:** intentional craftsmanship without clutter. **Dependencies/effort/risk:** paving owner; M; bad triangulation and nearly coplanar faces. **Acceptance:** orbit each joint at shallow camera angles and walk all sectors at 24; zero blinking, holes or foot-catching edges.

### 02 — One generous ceremonial threshold

**Evidence:** 2 has the right frontal frame but the court begins as an unarticulated slab. **Build:** a 26-wide, eight-deep fitted threshold at the current entrance, with a recessed two-realm crest eight studs across and a 0.75-wide border. Keep the stair/ramp landing heights and all route widths. One 1.2-high carved title on the threshold's outer vertical fascia reads “CHAMPIONS”; do not put a tall arch in front of the fountain. **Benefit:** marks arrival while preserving sightline. **Dependencies/effort/risk:** 01 and arrival-section boundary; M; duplicating floor layers. **Acceptance:** standing at entry center sees the whole crown; ramp users encounter no lip over 0.1 stud.

### 03 — A real gallery promenade

**Evidence:** 1/3 show ample unused room but no obvious place to stop and inspect. **Build:** finish the radius-36–42 annulus as a six-wide darker stone viewing lane. Place eight flush 3×2 medal-shaped floor markers aligned with active bays at radius 38; keep their surface quiet rather than glowing. Leave the radius-16–36 space open for gatherings and photography. **Benefit:** guides visitors through eight categories without obstructing the fountain or shortening accessible routes. **Dependencies/effort/risk:** 01; S/M; visual over-striping. **Acceptance:** a clockwise lap needs no jumps and the lane can accommodate opposing avatars; all 24 figures visible from at least one lane position.

### 04 — Beautiful, honest preview champions

**Evidence:** 2/3/4/6 show black silhouettes that erase body detail. **Build:** keep the exact 24 static R15 references and foot anchors; assign coherent ivory/gray body materials and matching BodyColors in the authored dummy definition, with muted bronze sash or shoulder accents. Avoid scripts that recolor on every frame. Use three restrained static poses distributed across categories: neutral, hand-on-hip, proud shoulders; keep limbs inside a 4.2-wide envelope. Keep PREVIEW identification. **Benefit:** makes height/lighting review meaningful immediately. **Dependencies/effort/risk:** verify existing dummy creator and Play BodyColors behavior; M; poses may collide with neighboring display silhouettes. **Acceptance:** all 24 remain correctly colored after starting Play, feet sit on caps, no animation/network gameplay is introduced.

### 05 — Podiums that read as crafted trophies

**Evidence:** 4 shows plain rectangular blocks with very thin rank-colored caps. **Build:** retain current heights and 4.7×4.7 bodies; bevel the outer corners 0.18 studs, recess 0.1-deep fluted panels, and give caps a 0.25-stud metal lip. Replace flat rank numerals with 1.25-high fitted metal medal inserts, each clearly distinct in numeral and shape as well as color. Use one Blender modular mesh set with three material variants. **Benefit:** credible craftsmanship and readable 2/1/3 hierarchy. **Dependencies/effort/risk:** 04 and preserved anchors; M; oversized cap edges shrink the aisle. **Acceptance:** footprints no greater than existing five-stud caps, all three ranks readable in a grayscale screenshot.

### 06 — Integrated name-and-achievement plaques

**Evidence:** 4 has tiny ankle-level PREVIEW strips. **Build:** attach one 4.6×1.2 physical sloped plaque to each podium front, inset within its existing footprint; angle face 15° upward. Preview uses physical “PREVIEW CHAMPION” and an em dash for value, never invented scores. Reserve separate name/value planes for future world-surface text; no BillboardGui. Long production names later fit/wrap within two lines and remain text-accessible. **Benefit:** viewers understand who and what a podium celebrates. **Dependencies/effort/risk:** 05; M; exact long-name rendering deferred. **Acceptance:** preview status readable from six studs; production slots documented but disconnected, no leaderboard queries performed.

### 07 — Distinct category heraldry

**Evidence:** 3/4 repeated typography forces every title to be read in full. **Build:** eight 2.2-diameter, 0.25-deep medallions on upper cornice centers: dragon head; fractured crystal; crossed blades; linked shields; split egg; single crowned wave; stacked waves; horned boss crown. Preserve full existing titles and scope. Build precise reliefs in Blender, using existing dragon/crystal/egg silhouettes as reference; use ImageGen only for silhouette exploration where useful. **Benefit:** fast visual category recognition and collectible character. **Dependencies/effort/risk:** title clearance and asset provenance; M/L; confusing highest versus total waves. **Acceptance:** those two symbols visibly differ at 15 studs and icon edges do not obscure letters.

### 08 — A readable three-level title system

**Evidence:** 4 shows scope copy squeezed against champion heads. **Build:** retain sculpted category letters and their exact wording, fit them into a maximum 16×3.4 field with consistent cap height. Move scope into a separate 14×0.9 dark/ivory inset under the header, starting above the tallest allowed figure envelope plus one stud. Keep 0.7-stud minimum visual clearance between header and cornice decoration. If necessary lift all headers/cornices together by at most two studs, not individual bays. **Benefit:** title, scope, and person stop competing. **Dependencies/effort/risk:** 04 envelope and 07; M; unusually tall future avatars. **Acceptance:** category readable at 20 studs and scope at ten on desktop and representative mobile framing; no overlap with standard R15 figures.

### 09 — A continuous, supported stone crown

**Evidence:** 2/4 show butt-ended lintels and inconsistent capital junctions. **Build:** replace discrete 19-stud cornices with 16-sided fitted corner modules around existing angular bays, retaining the front entrance opening. Use 0.2-stud deep recessed joints, actual load-bearing-looking capitals, and a thin bronze inset inside a carved groove. Keep maximum crown height at current height plus the 08 allowance. **Benefit:** the rotunda becomes architecture rather than a row of freestanding signs. **Dependencies/effort/risk:** 08; L; polygon corner fitting and intersections. **Acceptance:** inspect every junction from above/inside/outside; no floating ends, crossing caps, or coplanar overlays.

### 10 — Seal accidental slots and finish the exterior

**Evidence:** 5 exposes an undesirable narrow slit and bare panel backs. **Build:** survey all inter-bay wedges first. Close unintended sub-six-stud apertures with fitted masonry fillets behind the columns; do not invent narrow exits. Preserve only the established broad entry and side ramp routes. Finish the outer backs with shallow stone panels and a continuous 1.2-high base course. Fillets fill the actual gap volume, rather than cover it with two intersecting skins. **Benefit:** eliminates camera traps and makes the gallery respectable from gardens. **Dependencies/effort/risk:** 09, route-owner agreement; M; accidentally sealing a real path. **Acceptance:** enumerate every opening; collision/camera tests from both sides confirm no narrow trapping aperture and no lost authorized route.

### 11 — Three individually composed Heaven exhibits

**Evidence:** 1/4 reveal the same tall central bloom and two side plants repeated. **Build:** keep all three native flower species and current 14×5.4 beds in bays 2/6/11. Differentiate compositions: low flowering meadow with one 5.5-high crystal bloom; asymmetric quartz garden with 6.8-high bloom; layered softglow grove with tallest plant offset three studs. Reuse catalog stones only after checking native scale. Add 3–5 low plants each, not a new tree canopy. **Benefit:** each reserve bay deserves a second look. **Dependencies/effort/risk:** asset inventory, 10; M; plant triangles and header occlusion. **Acceptance:** silhouettes distinguish all three at a glance; all props stay inside bed and below header zone.

### 12 — Three individually composed Hell exhibits

**Evidence:** 3/4 show strong skull meshes but repeated shrine arrangements. **Build:** retain native horned skull and lanterns in bays 4/9/13. One becomes an excavated relic in dark shale; one a skull suspended on visible bronze supports above a low ember tray; one a broken stone reliquary with two half-height bone clusters. Skull height stays at or below seven studs; preserve the existing 14×5.4 beds. Do not create dangling chains that require simulation. **Benefit:** recognizable curated relics instead of duplication. **Dependencies/effort/risk:** native-asset fit, small Blender support kit; M; grisly detail overwhelming the friendly hub. **Acceptance:** stylized fantasy treatment, no gore, supports visibly contact props, same circulation clearance as before.

### 13 — Six small moments of life

**Evidence:** static images 4/6 support strong forms but no visible life in exhibits; motion absence is a hypothesis, not proven by a still. **Build:** after live inspection, use at most one emitter per decorative bay: pollen in Heaven, sparse upward cinders in Hell. Initial rate 2/s, lifetime 2s, spread limited to the bed, size 0.12–0.3, no opaque smoke. Reduce/disable by quality and motion setting. Native ParticleEmitter supports texture flipbooks if a single sprite looks repetitive; animation does not require mesh rigging. [Roblox ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter). **Benefit:** atmosphere without blocking names. **Dependencies/effort/risk:** 11/12, FX configuration; M; transparent overdraw. **Acceptance:** no particles cross a plaque face from the viewing lane; low setting loses no information.

### 14 — Portrait lighting for champions

**Evidence:** 2/4 champions have no readable form; after material repair, test whether light is still needed. **Build:** add authored lamp housings under active-bay cornices, with downward/frontward native lights aimed at each trio, range about 12–16 studs. Start with one nonshadowed light per visible active bay, maximum four nearby enabled; static ivory fixture on left, warm dark-bronze on right. Keep color subtle so avatar colors remain accurate. **Benefit:** faces and silhouettes read against stone in varying realm lighting. **Dependencies/effort/risk:** 04, shared lighting controller review; M; many overlapping lights and blown-out white clothing. **Acceptance:** compare day/realm-transition/low graphics; readable heads with no glare or visible lighting popping during the 24-stud/s approach.

### 15 — Fountain footing and sculptural relief

**Evidence:** 6 has superb basin art sitting abruptly on generic floor. **Build:** retain fountain dimensions and location; surround it with a fitted 1.25-wide stone/bronze annular footing, top flush with court, outer radius 12.25. Use alternating ivory and dark carved side relief on its vertical inner edge, keeping fountain model intact. Rebalance PBR roughness on stone/metal only if a side-by-side test shows improvement; do not replace the approved pool textures or motion. SurfaceAppearance supports distinct color, normal, roughness and metalness maps. [Roblox PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance). **Benefit:** seats the hero asset naturally. **Dependencies/effort/risk:** 01; M; losing authored orientation or flicker from stacked annuli. **Acceptance:** original pool scroll speeds and nine falls remain; one clean boundary at basin perimeter, no new walking obstacle.

### 16 — Water and ember contact effects

**Evidence:** 6 shows falls/pools but little perceived contact at receiving points. **Build:** inspect nine existing fall endpoints, then add water spray only at Heaven impacts and tiny warm glints at Hell impacts. Up to four visible emitters total, water rate 3/s and lifetime 0.5s; lava rate 1/s and lifetime 1s. Keep effect extent under 1.2 studs; no smoke canopy or extra water plane. Create a small sprite/flipbook in Blender or ImageGen followed by controlled alpha cleanup. **Benefit:** motion feels connected to actual geometry. **Dependencies/effort/risk:** 15, FX budget; M; excessive froth obscures approved texture motion. **Acceptance:** top-down view retains surface pattern; effects originate at actual impacts, stop outside 100 studs, and vanish in reduced FX mode.

### 17 — Intimate two-realm fountain sound

**Evidence:** 6 identifies a natural source location; screenshots cannot establish current audio, so audit before adding. **Build:** two local, looping owned/cleared sound assets at basin halves: light cascading water and subdued simmer/crackle. Start rolloff minimum 5 and maximum 30 studs, mix both below game action and UI. No voices, choir loop, or automatic stingers on entering. Roblox provides distance rolloff and SoundGroups for balancing sources. [Roblox sound objects](https://create.roblox.com/docs/sound/objects). **Benefit:** the center feels alive without leaking into fishing/combat. **Dependencies/effort/risk:** audio catalog and shared mix; S/M; annoying repetition. **Acceptance:** walking away fades smoothly, both loops respect effects volume, inaudible at neighboring activity hubs under normal mix.

### 18 — Four quiet social benches

**Evidence:** 1/3 have space to pause but no place to sit. **Build:** four low backless curved benches, each eight studs long and two deep, at radius 23, angled near 45/135/225/315 degrees. Each has two native Seats; tops 1.6 studs above court. Orient toward fountain with positions adjusted to leave a 12-wide north/south sightline and at least eight studs between furniture and active routes. Use carved stone feet and warm timber/bronze sitting surface; no new NPCs. **Benefit:** turns a leaderboard lap into a social hangout and fountain viewing spot. **Dependencies/effort/risk:** 03/15, crowded-player test; M; benches becoming obstacles. **Acceptance:** eight seats function; 10 moving avatars can cross the center without mandatory jumping, and entry view of fountain remains open.

### 19 — A composed exterior landscape skirt

**Evidence:** 1 shows abrupt bare terrain behind a thin circle; 2/6 show existing trees as useful distant framing. **Build:** reserve radius 59–67 for shallow planting pockets, excluding entry/ramp connections and any overlapping neighbor route. Reuse native flowers/quartz west and bone rock/ash brush east. Five clusters per half, heights 0.5–3 studs; only move distant trees when they intrude on titles. Add a fitted stone drainage edge at the court retaining base, not a new outer wall. **Benefit:** connects architecture to the island and improves exterior views. **Dependencies/effort/risk:** landscape owner, 10, actual terrain survey; M; overlap with garden/back perimeter. **Acceptance:** no object reaches walking ramps or hides titles from inside; terrain/wall junction has no exposed void from exterior camera positions.

### 20 — A rare Confluence breathing sequence

**Evidence:** 6 crown is a natural focal point; constant spectacle would compete with the many displays in 2/3. **Build:** optional 12-second ambient sequence around the existing crown, at most once per 90 seconds while nearby: a faint gold arc appears, six light motes gather, then dissolve. Height envelope crown-top plus two studs, width under six. Never imply a reward or rank change. Prototype deterministic timing and scrubbing in the RBX-FX-GEN pattern, but implement a new fountain-specific preset/module only after geometry acceptance. **Benefit:** a memorable moment for seated spectators without replacing the admired fountain. **Dependencies/effort/risk:** 16–18 and proven FX budget; L; scope creep and distracting repetition. **Acceptance:** no flashes/strobes, no camera force, fully disabled by reduced motion; six captures across timeline show crown and leaderboard text always unobscured.

## Top five priorities

1. **04 — Preview champions:** most conspicuous current visual defect; makes subsequent judgement reliable.
2. **10 — Validate slots/finish exterior:** screenshot 5 demonstrates an undesirable camera view; survey geometry and collision before deciding which fillets are necessary.
3. **01 — Fitted floor:** solves the largest visible surface and enforces the user's explicit no-overlap standard.
4. **09 — Continuous supported crown:** unifies the entire room at eye level.
5. **08 — Title hierarchy:** preserves functional readability while establishing premium presentation.

## Phased implementation and review gates

**A. Freeze and measure (half day).** Capture the same six views plus a close contextual overview and both ramp approaches in the already-open editable preview. Record all figure foot anchors, door/route widths, lighting, triangle/instance counts and fountain client state. Save backup geometry; inventory existing model templates. Survey every slot from 10. Confirm neighboring section bounds before changing radial 59–67 land. Reconcile stale figure budget in config during implementation. Output dimensioned plan and one material board; no asset generation yet.

**B. First native craftsmanship pass (two to four days).** Implement 04 and 10 first, then floor/threshold/promenade 01–03 and crown 09. Keep all 24 figures and current category slots. Geometry should be authored once in Edit with a config-named baker; retain current Confluence cache/replacement safeguard. Rebuild only owned Bragg geometry. Perform shallow-angle joint review before adding anything that hides it. Gate: user sees the six comparable screenshots and a walkable, nonblinking native court.

**C. Display and art pass (three to five days).** Implement 05–08, 11–12, 15 and 19 from one shared material/module kit; seat 18 only after circulation check. Prototype one complete active bay and one exhibit of each realm first. Review these in native lighting before duplicating. Generate only gaps that existing assets cannot fill. Gate: readable category/scope/name placeholder, no black silhouettes, all supports and floor joints convincing.

**D. Restrained life (one to three days).** Audit current FX/audio, then add 13/14/16/17 with distance/quality controls. Profile in the complete hub, especially when looking from Bragg toward the combat and fishing mist. Only proceed with optional 20 if budget remains. Gate: low/mobile view looks finished without effects; high view feels alive without obscuring content.

**E. Acceptance and durable handoff (half to one day).** At speed 24 walk stairs, both ramps, promenade, four fountain quadrants and exterior edges. Test seating and 10-player circulation, representative tall/wide avatar visual envelopes, daytime/realm lighting, graphics minima/maxima and reduced motion. Capture all six views at matching camera transforms, plus 30-second motion clips; snapshots alone cannot prove lack of z-fighting or stable motion. Update relevant configs, asset manifest/provenance and wiki through the owning implementation branch. Production ranking hookups remain a separate task.

## Asset briefs and pipeline

| Brief | Deliverables and constraints | Route |
| --- | --- | --- |
| Champion masonry kit | 16-sided cornice corner/straight modules, capital, beveled podium, plaque socket, fitted radial pavers. Ivory limestone, restrained bronze, dark basalt-like stone; realistic joints with chunky voxel-compatible proportions. No baked writing. Shared texture density. | Blender exact dimensions first; ImageGen only for a material/concept sheet. Meshy is optional for small ornamental relief, never the precision tiling geometry. |
| Eight heraldic reliefs | Eight 2.2-stud medallions, same border and depth; bold silhouettes matching 07. Separate bronze/stone material regions. Distinct highest/total wave art. | ImageGen sheet → isolate promising organic icons → Meshy → Blender retopology/scale/UV cleanup → local Assets → Roblox upload → native comparison. Exact icons may be faster directly modeled in Blender. |
| Six exhibit support variants | Three flower beds retain native flowers; three relic supports retain native skulls/lanterns. New stone/bronze support geometry only where necessary; no re-generation of admired source meshes. | Native catalog reuse + small Blender modules, shared material atlas. |
| Fountain impact sprites | One 4×4 water contact flipbook and one ember sprite, transparent padded borders, restrained soft edges, no black fringe. No image generation required if procedural Blender render gives cleaner alpha. | ImageGen if useful for look → Blender controlled sprite render/packing → Assets texture → Roblox emitters. Meshy has no purpose for flat particle sheets. |
| Fountain breathing preset | Small arc/mote system with complete reduced-motion fallback, bounds, timing, seed, cleanup and distance test. No gameplay events. | New native FX prototype using existing lab's deterministic-timeline approach; not a claimed ready-made library feature. |

Every upload later needs source image/mesh, license/provenance, Blender scene, export, native model, palette/tuning and IDs in config. Static assembly is preferable here; do not accept a single fused Meshy mesh that prevents material separation or editing. Bake PBR assignments into templates in Edit rather than relying on runtime reassignment.

## FX tooling reality

Inspected `/Users/jason/Documents/RBX-FX-GEN/docs/wiki/INDEX.md`, `CURRENT_STATUS.md`, and `ARCHITECTURE.md`. Implemented today: a native mesh crystal-eruption effect, config timing/seed, deterministic seek/update/stop timeline, standalone lab controls, preset bridge and a narrow crystal CombatFX adapter. Not implemented/validated: general multi-effect editor, export/asset browser, fountain presets, standalone extraction's full native comparison, or mobile budgets. Use its architecture and lab practice as a starting point, not as a turnkey fountain generator. The recorded runtime PBR map capability issue is another reason to author SurfaceAppearance in imported templates.

The researched Roblox capabilities support the proposed implementation; the artistic choices and numeric budgets here are design inferences, not promises from the documentation. Particle flipbooks can create small spray/mote animation; PBR can improve stone/metal separation; positional audio can keep water localized. None requires replacing the whole fountain or adding simulated fluids.

## Interfaces and ownership boundaries

- Own `BraggRotundaR6` and its named future config/baker only. Preserve `ConfluenceFountain`, current native template and local `ConfluenceSurfaceFlow` companion; measured pool speeds remain water U=.25/lava U=.075, 15Hz, 100-stud radius unless separately reviewed.
- Proposed config groups: `masonry`, `display_art`, `category_emblems`, `exhibits`, `seating`, `fx`, `audio`, `quality`. All dimensions, colors, IDs, rates and ranges live there. New persistent runtime code, if needed, reads those values; no art constants in services.
- Keep existing BoardId values and untagged AwardPodiumHook. Future display renderer receives board/period/winner slots and uses saved anchor CFrames, independent of architectural mesh. No fake scores, polling, profile changes or automatic production tags in this pass.
- Future spectator-stands audience should consume the same approved leaderboard snapshot, not copy IDs inferred from these static figures. This review creates no such implementation.
- Entry interface is the existing 26-stud threshold; side ramps stay 16×32 at 1:8. Coordinate paving with arrival owner, landscape pockets with landscape owner, and audio/FX with whole-map controller. Do not globally alter Terrain water, Lighting or Atmosphere for this section.
- Avoid broad reruns of the old terrain baker over neighboring improvements. Its existing region includes terrain outside the circle; implementation must narrow/preserve nonowned geometry and use current backup/export workflow.

## Performance, accessibility and acceptance constraints

These are proposed budgets to measure, not measured results. Additional art target ≤50k visible triangles, ≤120 new static render parts after replacing old modules, ≤2 new 1024² shared PBR sets plus icon/sprite atlas. Count replacements separately from additions; current fountain already has 383 animated mask parts, 24 mesh parts and nine fall Beams, so do not casually duplicate it or add more pool surface layers. Preserve original top masks until a visually equivalent measured optimization exists.

Aim for ≤40 new live particles visible in Bragg at normal setting, ≤10 low, none reduced FX if requested. Permit at most four nearby nonshadowed portrait lights plus existing shared lights; no new shadow-casting point lights initially. FX outside 100 studs suspend; animation clock resumes deterministically. Disable physics/touch/query for ornaments, keep Seats and simple walking collisions only. Record whole-hub frame time before/after on the same camera route; initial acceptance target <1ms median added client frame work, with no sustained p95 regression over 2ms on the selected representative device. If exceeded, cut 20 first, then light concurrency/particles before reducing readable signs or champion count. Twenty-four static figure references stay present; optimize their inactive behaviors instead of adding live Humanoids or high-resolution wardrobe assets.

Keep minimum eight-stud clear secondary circulation and 12-stud principal fountain sight/approach axes; preserve accessible ramps. Rank, realm and scope are communicated through shape/text as well as color. No flicker, strobe, forced camera, fog over text, constant applause or compulsory interactions. Reduced-motion mode freezes optional sequences but retains clear static art; respect sound controls. Review text from seated camera height, low phone framing and standard 5–6-stud avatars. Approval means the native map survives a slow orbit, fast crossing and crowded social test—not just a favorable screenshot.

## FX implementation clarification

The user subsequently clarified that worthwhile modest new effects should be built in
RBX-FX-GEN. Current crystal-only capability is not a restriction on this design. Use the
[shared small-effect backlog](FX_IMPLEMENTATION.md) to implement narrow ambient, flow,
ripple or burst primitives and reusable presets; a general-purpose editor is not required.
Larger tooling work remains a separate scope decision.
