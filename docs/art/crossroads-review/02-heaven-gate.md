# Section 02 — Heaven / Farm & Fight gate

Design review, 2026-09-08. Proposal only; no scene edits, generation, uploads, or gameplay activation. Owner: Heaven gate design agent.

## Design thesis

Make the existing gate feel like the inhabited entrance to a celestial estate: a beautifully finished threshold, an unmistakable Angel host, and a small living garden that explains **Grow / Hatch / Fight**. Keep the approved native arch, physical FARM & FIGHT title, halo and wings. Its silhouette is already strong. Spend first on architectural completion and composition, then on quiet magic that rewards approach.

The gate stays at approximately (-40, 0, 42), facing spawn with the existing roughly 34.6-degree yaw, at the approved 30% scale. The current 40×30 landing is a starting envelope, not permission to enlarge the arch. All proposed dimensions below are design targets requiring a measured fit; screenshots alone cannot certify clearances. Use gate-local coordinates: center at the floor under the arch, **front** toward spawn, **rear** toward Bragg, left/right as viewed from spawn. Do not infer local signs from world X.

## Evidence reviewed

All four supplied screenshots were opened at original resolution:

- `output/realm_crossroads/design-review/screenshots/02-heaven-gate-1.png`: aerial shows a freestanding arch on a plain rectangular landing, empty triangular lawns, an oblique information slab and weak material transition to adjacent paths. It establishes interfaces with Coin Garden, central spine and Bragg.
- `02-heaven-gate-2.png`: arrival eye level shows a good title silhouette; pale paving, pale arch and strongly lit Angel compete at similar brightness. The low freestanding information board appears less crafted than the arch. This is a readability issue, not evidence of a broken face orientation.
- `02-heaven-gate-3.png`: close side view exposes the information slab's dark back, title thickness and small mounting pieces. Native blue inset windows and stone detail are worth preserving.
- `02-heaven-gate-4.png`: rear view shows the unadorned dark crest back dominating the skyline, the back of the floating face, and the broad unstructured slab. This entrance is seen from every direction, so its back needs a deliberate composition.

Source checked: `configs/realm_crossroads_crests.json`, `configs/realm_crossroads_terrain.json`, `tools/realm_crossroads/bake_crests.luau`, `tools/realm_crossroads/bake_terrain.luau`, `docs/wiki/REALM_CROSSROADS.md`, `docs/wiki/CLIENT_PERFORMANCE.md`. Source confirms current 5-stud face centered at Y6.5, 18-stud approach paths, 6-stud configured arch clearance, crest centered Y23.4, and existing restrained proximity lights. The 6-stud opening is a constraint to test, not an invitation to fill it with decoration.

## Exactly 20 proposed improvements

Each item includes its own acceptance test. Effort is focused person-days including native visual iteration, excluding approval/upload queues; ranges are estimates, not delivery promises. Risk refers to integration/visual risk.

### 01 — Cut-stone gate forecourt

**Observation/benefit:** The plain rectangle in views 1/4 makes an expensive gate appear placed on a temporary slab. Build a coherent floor that belongs to the architecture.

**Placement/build:** Reuse the 40×30 envelope. Replace the slab with a small number of large, beveled limestone paver meshes or native solids in a fan arrangement aimed at the opening; center has a quiet 12-stud walking band. Use real 0.06–0.10-stud joints with a recessed continuous supporting bed, not overlapping colored polygons. Crown/threshold surfaces stay at the surveyed existing path height. Existing stone palette first; Blender only for economical bevels.

**Dependency:** Arrival owner supplies final shared boundary polygon and height. **Accept:** no flicker on slow oblique camera orbit, no void through seams, no snag at 24 studs/sec crossing every boundary. **Effort/risk:** 0.75–1.5 days / medium, because paving regressions have already occurred.

### 02 — Finished rear face of the crest

**Observation/benefit:** View 4's dark back is the largest unfinished surface. Give Bragg-facing visitors a purposeful heraldic rear.

**Placement/build:** Keep front lettering, overall size and silhouette unchanged. Replace the rear face with a fitted ivory inset and shallow gold estate seal: wheat, egg and crossed blades within a halo. Two shallow engraved feather fields flank it. Use a separately fitted solid with exposed thickness; no coplanar overlay. Reuse glyph/ornament geometry where possible; a Blender relief is a fallback.

**Dependency:** Existing crest baker must preserve front and mount coordinates. **Accept:** rear reads as finished from Bragg stairs and close orbit; zero back-to-front reversed text; no additional height. **Effort/risk:** 0.5–1 day / low.

### 03 — Architectural housing for Grow / Hatch / Fight

**Observation/benefit:** Views 2–4 show a display-board-like slab and dark rear. Integrate the existing physical explanation into a low stone lectern beside the left gate pier.

**Placement/build:** Reuse all three relief icons/captions in a roughly 12×4.5-stud field, angled slightly upward in a 14×3 footprint. Position outside the main 18-stud approach corridor with 6 studs clear in front for inspection; rear gets matching masonry, not blank black backing. Keep visible captions physical. Do not add a new billboard or duplicate title.

**Dependency:** Survey actual pier/base envelope and Coin Garden path. **Accept:** all words readable from 10 studs at normal third-person camera; a standing reader does not block through travel; clean side/rear views. **Effort/risk:** 0.75–1 day / low.

### 04 — Angel portrait lighting and value separation

**Observation/benefit:** The Angel nearly washes into the bright gate in view 2. Preserve identity and scale while making the host readable.

**Placement/build:** Keep current native face, Y6.5 and 5-stud visible height initially. Retune the existing fixture, using a restrained warm key from above/front and a subtle cooler side value; test before adding any light. Darken only a narrow inner arch recess if needed, not the Angel texture. Keep face collision disabled; do not add a flat backdrop behind the whole opening.

**Dependency:** Existing gate/realm lighting owner; respect its approach blend. **Accept:** eyes and face silhouette recognizable in front/three-quarter screenshots at 12 and 30 studs on low/high quality, with no blown-out gold and no blocked view through arch. **Effort/risk:** 0.5–1 day / medium.

### 05 — Paired garden shoulders

**Observation/benefit:** Empty grass wedges in views 1/2 leave no middle scale between huge arch and ground. Add two compact, intentionally asymmetric flower compositions.

**Placement/build:** Two beds approximately 7×12 studs, outside landing shoulders; 1.5-stud-high masonry lips only on non-route edges. Existing `field_flower_bush`, `softglow_bloom`, `crystal_bloom` and small quartz provide 0.8–3-stud layers. The taller rear cluster belongs on the outward Heaven side; keep center/spawn side low. Real abutting soil/stone boundaries.

**Dependency:** Items 01/03; landscape owner shares asset palette. **Accept:** no flower enters arch/Angel/title silhouette from spawn; no narrowing of arrival or garden ramp paths; no improvised substitute meshes. **Effort/risk:** 0.5–1 day / low.

### 06 — Threshold seal integrated into masonry

**Observation/benefit:** Current floor has no legible moment of arrival. Add a 5-stud halo/seed medallion immediately before the opening as the visual travel threshold.

**Placement/build:** Recess a bronze ring and pale egg-shaped center into a matching cutout in the stone, flush at walking height. Use simple native solids/Blender geometry rather than a hovering decal. Shape communicates destination even without color. This is an authored marker now, not active teleport logic.

**Dependency:** Item 01 and future travel boundary definition. **Accept:** emblem visible with effects disabled, no overlap/flicker, walking through never triggers travel until deliberately integrated. **Effort/risk:** 0.25–0.5 day / low.

### 07 — Finished crest mounting assembly

**Observation/benefit:** View 3 exposes thin discrete mount pieces. Make the crest look structurally supported without replacing its approved wings.

**Placement/build:** Dress the two existing 0.5-stud straps with compact forked bronze brackets and fitted sockets at the existing shoulder contacts. Keep all ornament within current silhouette and above head clearance. Native geometry or one reusable mirrored Blender bracket; no added freestanding columns.

**Dependency:** Exact native arch surface survey. **Accept:** mounts visibly meet both arch and title from both side views, no floating ends or intersection shimmer, no title displacement. **Effort/risk:** 0.5–0.75 day / low.

### 08 — Celestial window depth

**Observation/benefit:** The blue windows in view 3 are excellent native detail that could carry more depth and life.

**Placement/build:** Reuse their shapes and maps; first adjust material/lighting around existing insets. Where needed, fit a shallow inner cyan/gold emissive insert behind the window aperture, inside the stone reveal, with no coplanar duplicate face. At most two tiny nonshadowed lights shared by all windows. No blanket Neon conversion of the arch.

**Dependency:** Determine whether windows are inseparable from the native textured mesh; if so, retain texture and use external controlled light only. **Accept:** stone ribs remain readable at noon, no white rectangles, no added transparency layers across the opening. **Effort/risk:** 0.5–1 day / medium.

### 09 — Quiet halo current

**Observation/benefit:** The halo can communicate celestial magic without another large object.

**Placement/build:** Add up to three narrow Beams along separate arcs inside the existing top halo, scrolling a soft streak texture over 8–12 seconds. Keep them recessed within its outline; no full opaque portal disk. Roblox Beams support textured spans between attachments and configurable curves; this is feasible native FX, not a custom shader claim. [Roblox effects](https://create.roblox.com/docs/effects)

**Dependency:** Small FX preset and shared client culling; optional existing streak sprite. **Accept:** visible gently at 20 studs, no flashes, title remains readable, static halo survives effects-off setting. **Effort/risk:** 0.5–1 day / medium.

### 10 — Sparse upward motes in the side recesses

**Observation/benefit:** Current gate has little localized motion. Add a restrained rise of warm dust around the pillars, keeping the host clear.

**Placement/build:** Two attachment emitters, each 2–3 particles/sec, 2–3 sec life, small 0.15–0.35-stud sprites; particles remain near pillars and terminate below the crest. Reuse an existing soft glint texture. The documented particle-size/fill-rate and overlap costs justify tiny sprites and low counts. [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)

**Dependency:** Effect settings/culling. **Accept:** no particle crosses face center in a 30-second capture; high setting targets fewer than 24 live motes; low setting can disable them with no loss of navigation. **Effort/risk:** 0.25–0.5 day / low.

### 11 — Two sculpted votive lamps

**Observation/benefit:** Views 2/4 lack human-scale detail. Put one 3.5–4-stud lamp beside each outer pier base, not in passage.

**Placement/build:** Reuse catalog lantern if a Heaven-appropriate asset exists; otherwise make a small seed-shaped bronze cage over pale crystal, mounted on a limestone foot. Budget one shared mesh with two instances. Light can be material-only on low quality and share item 08's light allocation.

**Dependency:** Asset search and items 01/05. **Accept:** default avatar comparison shows lamps below shoulder height, bases do not protrude into the 18-stud approach, visible even without dynamic lighting. **Effort/risk:** 0.5–1.25 days / low to medium if new asset needed.

### 12 — A living estate vignette

**Observation/benefit:** The title says Farm & Fight but the arch alone reads generic Heaven. Make one small display tell its particular story.

**Placement/build:** Within the outward shoulder bed, arrange an existing fruit/sprout planting, a cracked ornamental egg shell, and a sheathed tool/blade relief on a 6×4-stud stone shelf below 3.5 studs high. Treat this as a miniature still life, not a hatch stand. Reuse approved objects before generating a new shell.

**Dependency:** Coin Garden owner must distinguish this vignette from Egg of the Week; no egg price/prompt. **Accept:** viewers can name at least two of the three themes without text; never mistaken for the actual hatch interaction in a brief user review. **Effort/risk:** 0.5–1 day / medium.

### 13 — Outward tree framing

**Observation/benefit:** Background trees form a distant fence in views 2/3. One closer canopy adds depth.

**Placement/build:** Relocate one existing small pink or pale-cloud tree to the outer rear quarter, 14–18 studs outside the pier, roughly 12–16 studs tall. Keep its crown behind/beside the gate, not above title lettering. Use a second low shrub mass for balance instead of a symmetric tree wall.

**Dependency:** Landscape and Coin Garden sightline ownership. **Accept:** complete title/halo visible from spawn, garden ramp and Bragg stairs at typical camera zoom; tree not planted over paving or safety route. **Effort/risk:** 0.25–0.5 day / low.

### 14 — Return-side welcome composition

**Observation/benefit:** Rear view exposes the faceted back of the Angel with nothing framing it. Give the reverse approach a deliberate focal hierarchy.

**Placement/build:** Add a narrow physical rear-facing halo medallion on the arch crown below the back crest, aligned to the existing architecture. Keep the face unchanged; use rear floor markings and garden framing to lead returning visitors outward. Do not rotate the face continuously to chase cameras or create a duplicate face fighting the front one.

**Dependency:** Item 02; travel design decides whether rear is a through route. **Accept:** rear screenshot reads as an intentional reverse elevation, with no new face collision and no second large text banner. **Effort/risk:** 0.5–0.75 day / low.

### 15 — Local celestial sound pocket

**Observation/benefit:** A strong first impression benefits from a quiet audible threshold rather than only more particles.

**Placement/build:** One soft wind/chime source near the halo with approximately 8-stud near field and 26-stud maximum reach, using owned/licensed existing audio. No global music switch. Roblox supports positional sound with configured distance rolloff. [Sound objects](https://create.roblox.com/docs/sound/objects)

**Dependency:** Audio asset audit, shared mix/accessibility settings. **Accept:** inaudible in the central neutral gap and at the Siege gate; conversation/game cues dominate; disabling sound loses no instruction. **Effort/risk:** 0.5–0.75 day / medium for mixing.

### 16 — Host acknowledgement, not forced interruption

**Observation/benefit:** The static Angel is an identity asset that could feel present with very little motion.

**Placement/build:** Future client-only acknowledgement at roughly 10 studs: a maximum 0.15-stud lift and slight light change over 1.5–2 sec, returning to its current pose. No face rotation that exposes its back from the approach. Provide a static reduced-motion state. Later Talk/Enter controls must explicitly use routing ownership; proximity alone never teleports.

**Dependency:** Deferred interaction work and existing lighting controller. Roblox proximity prompts support camera line-of-sight visibility, useful for keeping a later prompt from appearing through pillars. [Proximity prompts](https://create.roblox.com/docs/ui/proximity-prompts)

**Accept:** only one acknowledgement on approach, no repeated jitter at radius edge, no camera takeover, no runtime behavior required for this map art pass. **Effort/risk:** 0.75–1.5 days / medium; deferred.

### 17 — Stone transitions to Coin Garden

**Observation/benefit:** View 1 shows several different path directions meeting near the gate. Finish one connective language rather than adding isolated paving patches.

**Placement/build:** Carry the gate's cut-stone edge band only to the agreed garden-path seam. Use a short 8–12-stud transition of increasing paver size, ending at a single full-width joint. Preserve the existing 1:8 ramp and its usable width; no stairs added here. Coordinate all intersections in plan before authoring.

**Dependency:** Arrival/Coin Garden owners jointly approve boundary; item 01. **Accept:** continuous 24-stud/sec route with no notch, protruding lip, coplanar overlap or route-width reduction at either end. **Effort/risk:** 0.5–1 day / medium.

### 18 — Accessible side waiting niche

**Observation/benefit:** A host and explanatory lectern will attract stopped players. Give them somewhere to pause off the approach.

**Placement/build:** Reserve a 10×8-stud outward-side pocket, connected by a minimum 6-stud aisle; one 7-stud stone bench with two functioning Seats faces diagonally toward the gate. Build outside all existing route envelopes. If survey shows insufficient room, omit the bench and keep the clear pocket; do not shrink travel space to fit it.

**Dependency:** Items 03/05 and boundary sign-off. **Accept:** two seated and two standing avatars leave full approach clearance; normal dismount cannot deposit a character into pier/bed; no automatic NPCs. **Effort/risk:** 0.5–0.75 day / medium.

### 19 — Shallow crystal bloom signature

**Observation/benefit:** A single authored magical accent can tie the gate to the wider visual language and demonstrate the new FX workflow.

**Placement/build:** One 2.5-stud quartz cluster in the outward bed gets a gentle internal glint sequence, not an eruption or combat flash. Explore a static mesh and subtle glow variant using RBX-FX-GEN's config/seed/timeline principles. Its current implementation is crystal eruption; this peaceful preset/adapter is new work and must be validated separately. No claim that the general-purpose FX editor already exists.

**Dependency:** FX lab standalone verification, existing crystal texture/template audit and effects-off fallback. **Accept:** no debris, fissures, damage implication or screen shake; one event no more often than 12 seconds, static appearance on low/reduced motion; approved beside rather than louder than the Angel. **Effort/risk:** 1–2 days / medium-high; optional final polish.

### 20 — Consistent material hierarchy and weathering

**Observation/benefit:** Pale slab/arch brightness in views 2/4 flattens depth. Unify materials while retaining native detail.

**Placement/build:** Keep arch's existing SurfaceAppearance intact. Match new stone to its slightly cool midtone, gold to its restrained warm highlights, and soil/low recesses to darker values. Add light grime only in actual base creases and joints through UV textures or material choice. Bake new asset roughness/color variation in Blender; do not layer planar stain sheets across walking surfaces. Exposed path edges receive solid thickness.

**Dependency:** Approved daylight and item 04 lighting, plus all new assets. **Accept:** grayscale captures clearly separate pavement, recess, Angel and lettering; low/high graphics and three camera angles show matching palettes; no new unique 2K texture for each small prop. **Effort/risk:** 0.75–1.25 days / medium.

## Top five priorities

| Order | Item | Why first |
| --- | --- | --- |
| A | 01 — forecourt | Makes every other addition sit in a coherent, technically sound place. |
| B | 02 — crest rear | Removes the most visible unfinished elevation without changing approved front. |
| C | 03 — relief housing | Fixes a conspicuous temporary-looking object and its dark rear. |
| D | 04 — Angel readability | Protects the character identity at the first decision point. |
| E | 05 — garden shoulders | Adds human-scale life and a sense of destination with existing assets. |

## Phased build and review plan

**Phase A — survey and freeze interfaces (0.5 day).** In the same open preview, record arch visible bounds/collision width, landing surface height, camera positions and every boundary to arrival/Coin Garden. Capture a 5.5-stud avatar and representative taller/wider avatars front, side, rear. Agree one polygon owner per floor region. Preserve current gate art. Do not rebake the whole terrain to change this section.

**Phase B — architectural completion (2–3 days).** Implement 01, 02, 03, 06, 07, 14 and 17 using existing materials and native pieces wherever exact cuts matter. Work in Edit with config-owned parameters. Inspect front/side/rear and low glancing floor cameras after each boundary change. Walk every route at speed 24. Stop adding content if the revised ground cannot pass the seam test.

**Phase C — living composition (1.5–2.5 days).** Fit 05, 11, 12, 13 and 18. First use actual existing assets at desired scale, not gray proxy foliage. Take matched screenshots with and without planting; remove any object that obscures identity/navigation. Compare gate and Siege dominance from spawn; Heaven should be equally legible, not physically larger.

**Phase D — controlled finish and FX (1.5–3 days).** Tune 04, 08 and 20 before judging any glow. Then add 09, 10 and 15 individually with performance captures. Optional 19 follows validated lab preset. Item 16 stays a documented interaction prototype until map placement/routing integration; it is not necessary for an impressive static scene.

**Phase E — acceptance package (0.5–1 day).** Matched four original camera views, eye-height walk-in video, reverse walk-out video, 30-second close orbit and low/high graphics captures. Test four stationary viewers with one walker. Report new mesh/texture/particle/light counts and measured frame deltas versus the same baseline camera/device. Share a reversible section model and config, plus source assets. Estimated overall art pass: roughly 6–10 focused days with shared batches, more if novel assets fail review; per-item figures overlap and must not simply be summed.

## Asset briefs and pipeline

**Estate bronze bracket kit (07):** Prefer native solids. If insufficient, Blender directly: two mirrored brackets, visible load-bearing fork, stone socket, worn gold edge, no lettering. Under 1,500 triangles for the reusable kit target; single shared small texture set. Export at studs scale, explicit mount pivots and collision-free art.

**Celestial seed lamp (11):** Search existing owned lanterns first. For a new asset, ImageGen contact sheet prompt: “Front, side and three-quarter orthographic views of a compact stylized celestial estate lantern, pale limestone foot, bronze seed-shaped cage, small cyan crystal core, broad readable silhouettes, voxel-compatible proportions, no text, no floating pieces, isolated neutral background; designed as a four-stud-tall Roblox environment prop.” Choose one view for Meshy, then Blender separates cage/core/base, repairs topology and UVs, sets lamp pivot, bakes shared maps, and creates simple collider only if truly needed. Assets stage and Roblox upload follow existing project recipe, with IDs registered only in config. Do not ask Meshy to invent exact captions or precise mounting geometry.

**Estate seal (02/14):** Draw/vector or Blender relief first; preserve native title font. Optional ImageGen studies supply ornamental composition only, not final text. Model shallow wheat/egg/blades forms, no tiny high-frequency detail; target under 2,000 triangles per reusable relief.

**Quiet magic (09/10/19):** Existing streak and glint sprites first. If missing, ImageGen supplies isolated transparent motif references; texture cleanup and atlas padding are a separate verification step. Native Beams/emitters provide motion. RBX-FX-GEN can inform deterministic presets and bounded lifetime/culling, but its extracted lab is not yet production-verified and currently supports crystal eruption only. Never paste the combat eruption with rubble into this peaceful gate. New preset schema and client adapter are explicit work.

## Interfaces, constraints and acceptance budget

**Arrival:** Owns central spine and shared approach until the approved boundary. Gate owner supplies a clipped landing polygon and exact height. Keep the complete 18-stud approach and current roughly 3-second spawn-to-gate-center travel at 24 studs/sec. No new compulsory detour, steps, or raised spawn ornament. Existing 6-stud arch collision opening must be validated with avatar sizes; decor cannot reduce it.

**Coin Garden / pond:** Gate art must not look like another egg purchase station or obscure the garden ramp. Share flowers/pavers/lantern kit, but retain distinct activity centers. Outward tree, lectern, waiting niche and vignette compete for space: fit by survey, omit optional bench/vignette before enlarging into another owner's area.

**Bragg / rear view:** Keep reverse route and stairs clear. The rear crest seal, not another full title, completes its skyline. Preserve visual access to the Bragg entry between both gates.

**Performance targets, to validate:** Added decoration target ≤25,000 rendered triangles, ≤120 new static BaseParts, ≤2 new shared 1K texture sets, ≤3 Beams, ≤24 concurrent motes and ≤2 added nonshadowed lights for this entire section. Count shared budgets across lamps/windows, not separately. No broad Workspace scan per frame; register local instances once and clean up on streaming/removal. Cull optional animation beyond 80 studs; no distant real-time lights needed. Match baseline and proposed captures on a representative mobile client: aim for <1 ms added GPU and <0.25 ms added client script time at the gate, and no repeatable 95th-percentile frame-time regression above 5%. These are proposed review thresholds, not measured guarantees. Reduce transparent layers before lowering core geometry quality. Roblox documents particle overdraw/quality differences and texture reuse considerations; use low and high quality QA. [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)

**Accessibility:** No flashes or full-screen bloom pulses; all motion optional; destination communicated by physical words and shape as well as hue. Maintain dark readable lettering and a recognizable Angel on pale architecture. Audio never carries exclusive instructions. Future interaction uses gamepad/touch/keyboard support through the established prompt system; no compulsory dialogue. Test standing/sitting/dismount routes and tallest supported avatar near all supports.

**Implementation discipline:** Design/art/tuning/asset IDs in configs or named art companions. Preserve original source meshes, SurfaceAppearance maps and authored transforms. No runtime geometry rebuilder, production spawn change or travel activation in this art pass. The current working preview is reused; do not reopen a duplicate file to review changes.

## FX implementation clarification

The user subsequently clarified that worthwhile modest new effects should be built in
RBX-FX-GEN. Current crystal-only capability is not a restriction on this design. Use the
[shared small-effect backlog](FX_IMPLEMENTATION.md) to implement narrow ambient, flow,
ripple or burst primitives and reusable presets; a general-purpose editor is not required.
Larger tooling work remains a separate scope decision.
