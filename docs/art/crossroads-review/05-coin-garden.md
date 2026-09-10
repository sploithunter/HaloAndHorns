# 05 — Coin Garden: the Celestial Harvest Cloister

Design review, 2026-09-08. Plan only; no scene, code, gameplay, asset upload, or generation was changed by this review.

## Design judgment

Keep the generous, unobstructed collection lawn. Make its **edges and destination** extraordinary: a pale stone garden cloister, richly planted outside the playable rectangle, terminating in an open, sculpted weekly-egg pavilion. The native egg and Hall pedestal remain the hero. Quiet pink/cloud vegetation and aged gold connect it to Heaven without making another enormous gate. The garden should feel like a place to collect, meet friends and discover this week's egg, not a vacant sports field or a second leaderboard hall.

The field is intentionally empty of physical coins. Do not restore static coin examples, decorative coin piles, reward fountains or fake collectible sparkles. Future Hall-style drops, hatching and economy bind later; this review selects no prices, schedules, reward probabilities or weekly roster.

## Evidence and fixed contract

Inspected all supplied images: `05-coin-garden-1.png` (overhead), `-2.png` (approach), `-3.png` (pavilion front), `-4.png` (pavilion oblique), and `00-whole-map.png`, under `output/realm_crossroads/design-review/screenshots/`. The replacement whole-map capture was also inspected: it confirms the paired functional lawns and the garden's position between Heaven pond, gateway and Bragg. Distant objects are omitted in that capture, so section views and current configs govern vegetation and capacity judgments.

- **S1 / overhead:** a protected rectangular lawn, extremely thin perimeter lines, large pale circulation slabs, a narrow connection toward the pavilion and a neighboring pond immediately to the west. The grass and paving read as separate blockout objects rather than a designed garden.
- **S2 / approach:** two isolated quartz chunks dominate the foreground while the intended destination is distant. Long unbroken ivory surfaces and thin curbs make the useful open space feel unfinished. The Bragg exterior presents broad blank panels to the right.
- **S3 / front:** the native egg and pedestal have much greater detail than their plain four-post pergola. The giant rectangular title band dominates; small square planters look incidental. Existing trees already provide an excellent pastel palette.
- **S4 / oblique:** the uncovered sides and repetitive roof slats read as construction framing. The floor's projecting edge and isolated planting expose the assembly rather than a coherent landmark.

Source verification: `configs/realm_crossroads_activities.json`, `realm_crossroads_landscape.json`, `realm_crossroads_fishing.json`, `tools/realm_crossroads/bake_activities.luau`, and `docs/wiki/REALM_CROSSROADS.md`. Coordinates below are proposed authoring targets, not live measurements. Field center is **(-120,4,18)**; clear footprint **X[-152,-88], Z[-27,63]**, 64×90 studs. Pavilion center is **(-120,4,-61)**; existing floor 72×28. Gathering terrace is centered **(-120,4,82)**, 76×20. Walking speed is **24 studs/sec**. Y=4 is the architectural datum; use measured finished surface heights when joining geometry. Existing six-stud side promenades and 18-stud pavilion approach need circulation review, not an assumption of spare land. Heaven pond center (-216,8 in X/Z), radii44×56, reserves its own ten stations and 12-stud walking clearance.

## Exactly 20 improvements

Effort is an indicative focused art/implementation estimate after assets and interfaces are approved: S ≈ half day, M ≈ one–two days, L ≈ three–five days. These are proposals, not completed work or delivery promises.

### 1. Give the weekly egg a sculpted, open crown pavilion

**Observation:** S3–S4 show a richly made pedestal under a generic rectangular pergola. **Design:** retain the four-post footprint at X=-139/-101, Z=-71/-51, but replace the roof silhouette with two shallow, feather-rib arches supporting a broken halo crown. Limit the total roof to Y≈24–25, below the principal gates' visual importance. Keep the center sky-open and a 12-stud-high clear foreground opening. Finish the rear with the same curved rib profile and carved capitals as the front, with no blank billboard backing; both pond-side and Bragg-side approaches see finished architecture. Keep rear posts out of the pavilion floor's return circulation. **Method:** reuse stone/gold palette; Blender-authored structural kit with separate decorative feather brackets. ImageGen → Meshy only for organic bracket studies, then Blender cleanup. **Benefit:** recognizable hero destination with a premium silhouette. **Dependencies:** roof bounds agreed with Bragg sightlines; existing stand preserved. **Effort/risk:** L; oversized ornament could compete with the gate. **Acceptance:** the egg stays unobstructed in S2–S4 cameras and from both side paths; default camera never clips roof at the stand.

### 2. Turn the title into crafted architectural lettering

**Observation:** S3's solid band consumes the entire facade. **Design:** replace the 36×3.2 plain slab with a gently bowed 32×3.2 carved lintel between the existing front posts; inset the text into a darker recessed field with a visible stone reveal and restrained gold letter faces. Retain exact copy “EGG OF THE WEEK.” **Method:** existing native glyph system for precise spelling, Blender for the lintel, no billboard. **Benefit:** readable purpose integrated with architecture. **Dependencies:** item1 proportions and reusable glyph availability. **Effort/risk:** M; excessive metallic glare or shadows can reduce legibility. **Acceptance:** readable from the south end of the lawn at standard third-person view and low graphics; no letter/backplate coplanarity or reversed text.

### 3. Frame the existing pedestal with a fitted floor rosette

**Observation:** S3 has no visual connection between pedestal and floor. **Design:** an approximately 18-stud-diameter eight-petal stone/aged-gold rosette centered on (-120,-61), with a central cutout precisely matching the stand's contact footprint. Petal seams point toward the four openings. No raised ring blocks approach. **Method:** Blender or native polygon tessellation, separate adjoining material regions with real shared boundaries. **Benefit:** anchors the hero and suggests a deliberate hatching destination. **Dependencies:** measure actual native stand bounds; future hatch camera envelope. **Effort/risk:** M; incorrectly placed inlays could recreate the reported blinking floors. **Acceptance:** one visible top face at every sample point; no shimmer while circling at low camera height; no collision lip above 0.1 stud.

### 4. Create a welcoming pavilion forecourt

**Observation:** S1 has an 18-stud neck meeting an expansive floor; S4 shows abrupt slab geometry. **Design:** fan the last 12 studs of the approach from 18 to 26 studs wide before reaching the existing front edge at Z=-47. Keep the earlier approach and the full lawn unchanged. Chamfer the pavilion's front corners with matching stonework, preserving an 8-stud clear circulation zone around the stand rather than adding another raised stage. **Method:** explicit plan polygons replacing old floor pieces, not overlays. **Benefit:** accommodates a small group without a bottleneck. **Dependencies:** items1/3; owner of shared north circulation. **Effort/risk:** M; nearby Bragg connection. **Acceptance:** six avatar proxies can approach and disperse while a seventh passes through; no floor holes or duplicate faces.

### 5. Make a coherent stone circulation circuit

**Observation:** S1–S2 show uninterrupted cream strips without paving scale. **Design:** re-author the existing side/end walk footprints in 4–6-stud-long stone modules, with a 0.12-stud dark recessed joint rather than grass cracks. Keep six-stud clear width where expansion is unavailable; flare only junctions into verified spare space. Use the arrival path's accepted joint language. **Method:** one low-complexity mesh per run or a small repeated kit, with genuine thickness and exclusive top polygons. **Benefit:** human scale and an unmistakable route around the field. **Dependencies:** shared paving owner and pond corridor survey. **Effort/risk:** M; excess individual parts. **Acceptance:** no flicker at grazing angles, no notch at any route interface, uninterrupted walk around the lawn at speed24.

### 6. Replace pencil-thin field edging with deliberate thresholds

**Observation:** S1–S2 curbs look fragile and arbitrary. **Design:** keep all64×90 usable grass; put a 0.8-stud-wide stone edge outside it, with gently beveled top up to0.2 above field. At the south center and east stair access, create 12–16-stud-wide flush entry breaks identified by different stone grain. Do not create a fence or trench. **Method:** repeatable native/Blender border kit. **Benefit:** legible activity boundary without impeding collection. **Dependencies:** item5 common datum. **Effort/risk:** S; lip snagging. **Acceptance:** default and small avatars cross at every edge without jumping; props never intrude inside the protected rectangle.

### 7. Give the lawn a believable, calm material finish

**Observation:** S1 shows a flat dark rectangular mat different from surrounding Terrain. **Design:** retain the same level planar play surface and tint family, introduce restrained broad color variation and fine grass roughness; use a seamless, non-directional material. Avoid mown stripes suggesting lanes or collectible zones. **Method:** test an existing grass material first; if inadequate, a modest reusable MaterialVariant or UV-mapped surface authored in Blender. **Benefit:** removes the blockout mat appearance while preserving clear future drops. **Dependencies:** chosen surface renderer and ground seam tests. **Effort/risk:** M; overly detailed texture can hide small drops. **Acceptance:** lawn boundary remains flush; existing sample drop silhouettes remain distinguishable at24/48studs in a temporary offline visual test, with no static drops retained in the map.

### 8. Compose four substantial flowering entrance beds

**Observation:** S2's isolated rocks and S3's tiny bushes do not frame arrivals. **Design:** place paired 6×10 beds outside the south lawn corners, approximately X=-148/-92, Z=70–75 where surveyed clearance allows; a second smaller pair flanks the pavilion approach outside its clear18studs. Keep plants below2.5studs near intersections. **Method:** reuse field_flower_bush and softglow_bloom, grouped in odd-number clusters; native stone planters with faceted corners. **Benefit:** color and depth at decision points. **Dependencies:** items4–6 and exact terrace joins. **Effort/risk:** M; planting might consume circulation. **Acceptance:**12studs remain at each principal entrance and no plant crosses the lawn boundary; forward visibility from avatar eye height remains clear.

### 9. Replace random quartz placement with embedded garden geology

**Observation:** S2 foreground quartz reads as loose obstacles. **Design:** move these same rocks into the beds, bury their lower25–35%, and use one main stone with two smaller fragments per cluster. Limit route-adjacent height to3–4studs. **Method:** native pearl_quartz assets scaled and oriented from visible bounds, no new meshes. **Benefit:** believable planting anchors with fewer obstructions. **Dependencies:** item8. **Effort/risk:** S; visible underside/pivot mistakes. **Acceptance:** no floating bases from four angles; all rocks outside path envelopes and CameraQuery disabled where decorative.

### 10. Develop an asymmetric orchard backdrop behind the pavilion

**Observation:** S3 has appealing trees but little composition around the egg silhouette. **Design:** at Z≈-80 to-96, place a taller cloud tree off one side and a lower cherry cluster opposite; leave a12stud-wide opening behind the egg for its outline. Use existing flora in three depth groups rather than adding a solid row. **Method:** redistribute existing cherry/cloud/pine models; prune with mesh selection only if necessary. **Benefit:** a composed destination shot with depth and sky. **Dependencies:** Bragg and rear-route owner must approve bounds. **Effort/risk:** M; trees can hide podiums or overlap neighboring terrain. **Acceptance:** egg/crown silhouettes stay clear in S3, Bragg return path is unblocked, no new trunk inside pedestrian clearance.

### 11. Turn the side-facing blank wall into a garden relief

**Observation:** S2/S4 show large plain Bragg exterior panels. **Design:** propose removable low-relief botanical/wing motifs on the **garden-facing** surfaces, 6–8studs wide and0.25–0.4 deep, with planting at their feet. Do not change podium wall structure or titles. **Method:** Blender relief from an ImageGen orthographic concept if needed, one shared atlas/material. **Benefit:** makes the borrowed backdrop intentional. **Dependencies:** Bragg owner approval and facade measurement; this item is an interface proposal only. **Effort/risk:** M; visual ownership conflict. **Acceptance:** original Bragg signage and winner sightlines remain unchanged; no duplicated face surfaces; relief visible without emissive effects.

### 12. Make the gathering terrace a real social room

**Observation:** S1 shows two small parallel benches at the end of a broad slab. **Design:** retain the terrace footprint; arrange two pairs of inward-facing 8–10stud benches near X=-141/-99, Z≈82–88, leaving an uninterrupted central18stud route. Six to eight discrete native Seats can sit within crafted bench geometry. **Method:** reuse bench style with carved end caps; actual Seats, not decorative seats only. **Benefit:** useful waiting and meeting space without standing in the lawn. **Dependencies:** arrival-ramp landing clearance and sit/stand behavior. **Effort/risk:** M; automatic seating could snag passersby. **Acceptance:** all seats sit/exit cleanly; occupied avatars do not project into the central route; sitting is avoided by normal through-travel.

### 13. Add one sheltered conversation nook

**Observation:** S2 has no intermediate-height structure between field and high tree line. **Design:** a light12×8 vine arbor over the **outermost terrace seating**, not across the principal entrance. Roof around10–12studs above datum, one open face toward the lawn, no solid canopy blocking the camera. **Method:** reuse pavilion bracket/stone kit at simpler scale; existing foliage clusters, no cloth simulation. **Benefit:** an intimate place within the much larger map. **Dependencies:** item12 and pond approach corridor. **Effort/risk:** M; a second pavilion could weaken hierarchy. **Acceptance:** visually subordinate to the egg pavilion in S2, eight-stud headroom and unblocked seat cameras.

### 14. Clarify the garden–pond connection with two deliberate openings

**Observation:** S1 has a continuous thin west boundary between two activities; the nearby fishing dock/shore makes casual widening risky. **Design:** retain the field and pond station bounds. Use north/south openings in the garden-side parapet, aligned to the pond owner's bank route, with a common12stud pedestrian corridor wherever the two circulation systems meet. If the middle east-bank fishing station conflicts, agree a shared route outside its standing zone rather than deleting capacity. **Method:** surveyed layout and cleaved matching stone thresholds; no bridge unless pond designer requests one. **Benefit:** visitors understand how to move between activities. **Dependencies:** fishing owner; ten stations and their12stud rear clearance are hard constraints. **Effort/risk:** M; tightest interface in this section. **Acceptance:** two-way avatar traffic can pass an occupied nearest fishing station without entering casting space or water.

### 15. Add modest physical garden wayfinding

**Observation:** S2 reveals the egg title but not the collection lawn's identity. **Design:** one low sculpted marker at the southern entry outside the central18stud route, approximately8wide×4high, reading “COIN GARDEN” with a leaf/egg relief. A smaller side pointer can identify the pond once its name is settled. No price, countdown or unimplemented reward promise. **Method:** existing native glyph pipeline and carved stone shape. **Benefit:** purpose is legible before entry. **Dependencies:** navigation vocabulary shared with arrival and fishing owners. **Effort/risk:** S–M; extra signage clutter. **Acceptance:** readable within24studs, no collision on route, distinct from the principal gate title hierarchy.

### 16. Use jewel-like garden lights instead of broad illumination

**Observation:** S3's gold details and foliage lack material separation in flat daylight. **Design:** four low,3stud garden lanterns at pavilion/terrace beds, plus at most two shielded egg key lights. Pearl glass or opaque crystal cores with warm metal settings; keep light radius local, beginning at8–12studs. **Method:** existing bloom/quartz motifs and native lights; no global Lighting changes. **Benefit:** readable stone/metal relief and gentle focal hierarchy. **Dependencies:** whole-map lighting owner and performance baseline. **Effort/risk:** M; additive glare. **Acceptance:** egg color remains recognizable at low/high graphics, no light spill changes the neighboring pond or Heaven gate, no flashing.

### 17. Add sparse drifting petals above planting only

**Observation:** S2–S4 foliage is completely static; the lawn needs clear visibility. **Design:** three localized emitters above the planting, tiny0.2–0.5stud petals with4–6sec life and low rate, descending away from entrances. Keep the collection field free of gold/sparkle emitters that resemble rewards. **Method:** existing texture first; optional ImageGen transparent petal texture, native ParticleEmitter. **Benefit:** life and Heaven identity at low visual noise. **Dependencies:** graphics settings and effect texture ownership. **Effort/risk:** S–M; transparent overdraw. **Acceptance:** no more than roughly40 live ambient particles in this section at the starting budget; disabled ambient setting preserves all navigation information. Roblox documents particle size/count and overlap costs.[1]

### 18. Give the egg a restrained, optional presentation motion

**Observation:** S3's stationary display has no sense of discovery. **Design:** preview-only slow yaw of the existing egg, full rotation over35–50sec, optionally a≤0.2stud bob; never rotate the stand or require viewers to wait to see the egg. Disable motion for reduced-motion settings and pause when future hatch presentation owns the egg. **Method:** separate egg pivot and one client presentation controller; authored static fallback. **Benefit:** subtle hero focus without noisy effects. **Dependencies:** actual native model split/pivot and later hatching ownership. **Effort/risk:** M; competing with future hatch code. **Acceptance:** no collision/moving platform behavior, stop/start cleanly, original stand remains fixed, motion disabled yields the same readable silhouette.

### 19. Design a future hatch flourish around the real FX capability

**Observation:** S3's native pedestal deserves a crafted payoff, but no hatch gameplay is connected. **Design:** specify a short, contained feather-petal bloom within6studs of the stand and below roof level, with a soft outward ring and settling glints. Preview only on explicit artist trigger; never a perpetual reward-like burst. **Method:** native particles and possibly separate feather meshes, borrowing deterministic timeline/cleanup patterns from RBX-FX-GEN. **Benefit:** a distinctive future hatch presentation. **Dependencies:** server-authorized hatch event and existing presentation contract, art approval, mobile lab. **Effort/risk:** L; **new effect work**, not an existing preset. **Acceptance:** explicit begin/end, all instances cleaned after playback, repeated50times produces no growth, low-FX fallback and no ambient auto-trigger. RBX-FX-GEN currently implements crystal eruption only; it does not already provide this bloom or hatching integration.

### 20. Give the pavilion a quiet local sound identity

**Observation:** screenshots establish an open garden setting; they provide no evidence about current audio, so this is a proposed audition rather than a claim that sound is missing. **Design:** one localized soft wind/chime layer near the crown, with occasional gentle timbre variation; keep radius about20–28studs and exclude the lawn from a constant musical loop. **Method:** existing approved audio assets first, positional Sound with deliberate rolloff; configuration-owned gain and range. **Benefit:** proximity gives the destination presence without louder visual clutter. **Dependencies:** audio asset audit and map ambience mix. **Effort/risk:** S–M; repetitive or competing sound. **Acceptance:** inaudible from spawn, no interference with fishing cues, mute works, position/rolloff auditioned at three distances. Roblox supports positional audio and distance attenuation.[2]

## Top five priorities

1. **Pavilion silhouette and title (1–2):** largest mismatch between detailed existing assets and primitive surrounding construction.
2. **Paving circuit and field edge (5–6):** establish a precise visual foundation and avoid another regression in the user's repeatedly reviewed joints.
3. **Fitted rosette and forecourt (3–4):** make the native egg display feel intentional and accommodate groups.
4. **Planted beds and embedded quartz (8–9):** reuse the excellent existing assets to change the immediate player view quickly.
5. **Shared pond connection and social terrace (12,14):** guarantee usable space before spending on optional motion/FX.

## Phased execution plan

**Phase A — measured design and coordination, before generation.** Supplement the inspected overview with close rear/roof and garden–pond interface captures. In the existing Studio instance, survey finished floor heights, actual native stand bounds, pond dock/standing envelopes, Bragg facade and all path endpoints. Lock a plan drawing with protected field64×90, no new collision inside it, central terrace route18, pavilion clear opening12high, and no loss of ten-person pond capacity. Coordinate items10–11/14 with their owners. Record config-owned dimensions and palettes. Capture the same four section cameras plus a six-avatar group view.

**Phase B — architectural gray pass.** Implement5/6/4 first, then block1/2/3 with simple exact geometry. Replace intersecting floor polygons instead of stacking. Retain native pedestal/egg and all route endpoints. Walk every circuit, stair and ramp at24; test the smallest/default/tall avatar envelopes. Compare photographs before adding material complexity. The entire phase must remain reversible under a single section model plus explicit terrain/paving ownership; do not rerun an old whole-map baker that deletes later work.

**Phase C — asset kit and materials.** Finalize the crown/bracket silhouette in a local ImageGen sheet only if the native/Blender kit is insufficient; use Meshy for decorative organic components, not precision text or interlocking paving. Blender handles dimensions, material slots, UVs, decimation, normals, pivots and separate moving parts. Store source and provenance in Assets, then upload approved assets to Roblox and record IDs in configs. Build1–3,5–9,11,15–16 using the existing assets wherever possible. Compare noon, low/high graphics and grazing-angle captures. Roblox SurfaceAppearance supports PBR texture channels; use those for stone/metal differentiation rather than excessive geometry.[3]

**Phase D — landscaping and social use.** Redistribute rather than blanket-add trees for10. Implement12–14 after shared circulation agreement. Set collision/query only where needed, confirm occupied seats and angler proxy coexistence. Do not place static coins or add an unapproved seasonal economy. The plant mass should read from the approach but disappear below eye-level at all junctions.

**Phase E — motion and sound polish.** Start with17 and20; profile before18. Develop19 in an isolated FX preview only after the pavilion silhouette is approved. Reuse existing settings ownership; do not add a rival global lighting or accessibility controller. A nearby player should see one clear hero, not five concurrent effects. Integrate gameplay presentation later as a separate change.

**Phase F — final section acceptance.** Capture all four original views, close-up seams, seated camera, pond interface with ten anglers, and distant arrival. Run a before/after native performance pass with the same camera, resolution, graphics settings and proxy population. Review with the adjacent sections in place. Document remaining gameplay bindings explicitly; artwork does not imply functional coin collection or a scheduled weekly egg.

## Asset briefs and reuse

| Deliverable | Brief and method | Initial budget/constraints |
| --- | --- | --- |
| Pavilion stone kit | Pale faceted limestone, aged gold joints, shallow feather arches, open halo crown; practical structure visible from all sides. Blender precision assembly; optional ImageGen→Meshy feather brackets. | Four reusable structural modules; target≤12k triangles for unique kit before measurement; one shared1k–2k atlas. No opaque roof or merged egg. |
| Rosette/paving kit | Calm celestial botanical geometry, readable4–6stud stone scale, true seams and bevels. Blender/native direct construction. | No generated text; no overlapping flat layers; collision simplified to walkable surface. |
| Garden wall relief | Stylized leaves opening into a wing, broad features readable at15–30studs, no egg/currency icon spam. ImageGen concept if helpful; Blender low relief. | One shared relief module under2k tris; owner-approved facade attachment. |
| Lantern | Pearl/quartz core, warm bronze cage, small stone base; derived from existing meshes. | Four instances, shared materials; initially at most two nearby active light sources beyond egg lights, adjust after profiling. |
| Native flora | field_flower_bush, softglow_bloom, pearl_quartz, cloud_sapling, cherry_heaven_tree_1, frosted_pine_1. | Redistribute existing flora first; no collisions in routes; do not flatten all texture variation through tinting. |
| Petal / hatch FX | A real petal silhouette, optional feather bloom; transparent texture with clean alpha. ImageGen texture only if library lacks one; mesh feathers via Blender. | One reusable small texture; ambient and hatch visuals distinct from live collectibles; no new VFX engine implied. |

## Interfaces, performance and accessibility

- **Pond:** do not modify water, docks, fish content or bank without its owner. Keep ten stations and12stud rear walking route. Shared garden opening locations remain provisional until surveyed; the eastmost dock makes this a real constraint.
- **Bragg:** no podium/category changes. Reliefs and backdrop trees need facade/sightline approval. Do not duplicate the Confluence fountain or occupy its approach.
- **Arrival/Heaven gate:** preserve garden stairs and1:8 ramp. New floor runs meet approved joins at the same measured surface elevation. Gate title remains the dominant navigation cue from spawn.
- **Gameplay:** preserve WeeklyEggAnchor and CoinDropField intent/metadata. Keep runtime geometry out of gameplay services. Future Hall drop binding, hatching, schedules, prices and reward settlement are explicitly outside this art pass.
- **Effects tool reality:** RBX-FX-GEN wiki INDEX/CURRENT_STATUS/ARCHITECTURE were read. It contains native mesh crystal eruption, deterministic timeline/seek/update/stop, config/schema/preset bridge, standalone lab and a narrow crystal CombatFX adapter. Final visual approval, extracted-lab native verification, production integration and mobile budgets remain incomplete. Its architecture is useful for item19; a garden flower or hatch preset is new work. No expensive generation or tool session was started by this review.
- **Proposed starting budgets, not measured guarantees:** keep added unique architectural triangles around25k or less, reuse texture atlases, prefer≤80 new static mesh/part instances across this section, and no default always-running per-prop loops. Measure existing instances before choosing the actual ceiling. Aim for no more than1ms added median client frame time on the agreed reference low-end device; treat failure as a reason to reduce/merge art, not to silently lower the acceptance target. Report p95, instance/memory deltas and overlapping neighboring FX too.
- **FX:** approximately40 ambient particles or fewer initially; small screen coverage matters as much as count. Low graphics/reduced-effects mode disables petals and the hatch flourish while retaining static art. Reuse textures rather than making many unique flipbooks; Roblox documents both fill-rate and flipbook memory costs.[1]
- **Accessibility:** never encode destinations by color alone. Keep text/relief and geometry cues. No strobing, forced camera, dense fog or unavoidable seated trigger. Reduced motion freezes item18. Low-vision readability checks include grayscale and darkened lighting; muted audio loses no essential information.
- **Streaming:** integration must use the game's existing streaming policy. Group each pavilion assembly coherently and test clients arriving from either side; do not change map-wide streaming settings solely for this section. Roblox documents model streaming controls, but policy belongs to the broader integration owner.[4]

## Primary-source references

1. [Roblox: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters) — native particle textures, tuning, quality variation, fill-rate/overdraw and flipbook memory constraints.
2. [Roblox: Sound objects](https://create.roblox.com/docs/sound/objects) — positional audio and rolloff configuration.
3. [Roblox: PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance) — mesh surface material channels; supports the proposed restrained stone/metal material pass.
4. [Roblox: Instance streaming](https://create.roblox.com/docs/workspace/streaming) — model/instance streaming behavior to evaluate during production integration.

These sources establish available rendering capabilities; they do not validate the proposed section's performance or certify a specific aesthetic result. All dimensions/budgets above require the measured in-map review described in Phase A.

## FX implementation clarification

The user subsequently clarified that worthwhile modest new effects should be built in
RBX-FX-GEN. Current crystal-only capability is not a restriction on this design. Use the
[shared small-effect backlog](FX_IMPLEMENTATION.md) to implement narrow ambient, flow,
ripple or burst primitives and reusable presets; a general-purpose editor is not required.
Larger tooling work remains a separate scope decision.
