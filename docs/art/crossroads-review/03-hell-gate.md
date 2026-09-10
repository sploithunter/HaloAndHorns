# 03 — Hell / Pet Siege gate: the Ember Covenant

Design review, 2026-09-08. Proposal only; no map changes, generated assets, uploads or production integration performed. Section owner: Hell gate design agent.

## Design judgment

Keep the existing Gothic gate, correctly facing demon, and sculpted **SIEGE** crest. They are the recognizable centerpiece. Make the surrounding space feel like a maintained infernal stronghold: dark worked stone, restrained hot metal, small living ember gardens, and a welcoming route into shared pet combat. Richness should come from construction and composition before particles.

The main opportunity is continuity. The screenshots show an elaborate gate dropped onto a comparatively blank, cross-shaped brown slab; trees and arena architecture live at the distant edge, while the foreground has little middle scale. The rear crest and instruction panel expose flat black backs. The floating demon has a good silhouette but little spatial framing. Address those weaknesses without enlarging the gate, hiding it in smoke, or lengthening the first destination choice.

### Evidence inspected

All four screenshots were opened and visually inspected individually:

- [03-hell-gate-1.png](screenshots/03-hell-gate-1.png): overhead. Clear angular landing and path footprint; large bare triangular ground parcels; gate lies between central circulation and arena.
- [03-hell-gate-2.png](screenshots/03-hell-gate-2.png): arrival-facing view. Excellent SIEGE silhouette; dark face and small relief icons; long uninterrupted brown approach; arena spectators visually compete in the background.
- [03-hell-gate-3.png](screenshots/03-hell-gate-3.png): side. Gate mesh already has substantial PBR detail; crest reads as a broad slab on relatively simple supports; nearby ground does not share its craftsmanship.
- [03-hell-gate-4.png](screenshots/03-hell-gate-4.png): rear. Plain backs to crest and instruction panel; demon rear faces the secondary route; landing edge floats visually above the ground.

Screenshots cannot prove collision defects, z-fighting, readability on a phone, audio state, or live FX performance. The geometry concerns here are composition findings and hypotheses to verify in Studio.

Read: `docs/wiki/INDEX.md`, `REALM_CROSSROADS.md`, `CLIENT_PERFORMANCE.md`, `docs/ASSET_PIPELINE.md`; `configs/realm_crossroads_crests.json`, `realm_crossroads_gate_study.json`; relevant `bake_terrain.luau` and `bake_crests.luau` sections. Also read RBX-FX-GEN's wiki INDEX, CURRENT_STATUS and ARCHITECTURE.

## Spatial contract

Preserve gate center approximately **(40, 0, 42)**, yaw **−34.59°**, native 30% scale, and 40×30 landing envelope. Gate art is approximately 29.9 wide ×28.1 high ×13 deep. Keep current sculpted title at its existing height and width. The gate-study collision samples are approximate: the 6-stud clear-width /9-stud clear-height target needs a fresh character test, not inference from mesh bounds.

Use gate-local coordinates in implementation: **u** across its face, **v** toward arrival, **h** above finished walking surface. Confirm local forward from the current gate before baking. Dimensions below are starting design envelopes; the real non-overlapping paving footprint and measured arch bases take precedence. Keep a minimum 10-stud unobstructed approach, preserve the existing aperture, and keep ornament outside the walking envelope. Spawn-to-gate straight-line distance remains about 70.5 studs, or 2.94 seconds at 24 studs/sec before turning and acceleration. Never move the gate to accommodate decoration.

Color direction: charcoal stone with readable warm midtones, oxidized copper, ember orange, and very small sulfur-gold accents. Reserve thick green mist for the fishing pool; this area should look like a forge, not another cesspool. All eventual palettes, asset IDs, placements and FX timings belong in configs.

## Exactly 20 improvements

### 01. Rebuild the approach as a fitted basalt-stone fan

**Finding:** Shots 1–2 show a long, unarticulated brown strip and abrupt branches. **Build:** Lay 3–5-stud stone courses along the actual existing approach, fanning the last 12 studs into the landing. Use dark stone with broad readable bevels and sparse copper crosspieces. Cut at every branch boundary; keep all walking tops at the existing finished level. A single shared polygon set must own each surface area, with 0.08–0.12-stud recessed mortar reveals and no underlaid coplanar slab. **Method/dependencies:** Blender or native Edit-time polygon/CSG paving, after arrival-path ownership is locked. No Meshy for precision joints. **Benefit/acceptance:** The gate gains a crafted base; orbit every joint at low grazing angles with no blinking, and walk all branches at 24 studs/sec without snagging. **Effort/risk:** M / medium, because prior joint repairs must survive.

### 02. Give the landing a real foundation edge

**Finding:** Shot 4 exposes the thin landing lip against bare ground. **Build:** Replace the visible outer slab edge with a 0.6–0.9-stud-deep fitted stone fascia, embedded down into terrain; bevel its upper edge. Follow the existing trimmed footprint exactly, leaving path junctions open. Do not add a raised curb across any route. **Method/dependencies:** Native solids or a low-poly Blender perimeter mesh after item 01. Match actual surface elevation rather than assuming world Y=0. **Benefit/acceptance:** The arch feels seated in the land; side/rear eye-level screenshots show no hovering edge or grass penetration, and wheel-width routes remain level. **Effort/risk:** S / low.

### 03. Install a recessed threshold seal

**Finding:** Shots 2 and 4 offer little distinction between ordinary walkway and mode threshold. **Build:** A 5×2.5-stud horn-and-paw seal beneath the opening, formed from separate dark stone and brass pieces. Recess it 0.06–0.1 stud into an actual cutout; do not put a decal-sized plate on another top face. Add two small directional ticks on the arrival side. **Method/dependencies:** Blender vector extrusion or existing glyph/CSG tooling; exact aperture measurement and item 01. **Benefit/acceptance:** The destination has a legible physical boundary without mandatory UI. All avatar sizes step over it; the symbol remains visible with FX disabled and in grayscale. **Effort/risk:** S / low.

### 04. Finish the back of the SIEGE crest

**Finding:** Shot 4 exposes a large unworked black back, visible from normal hub circulation. **Build:** Retain front typography untouched. Add a shallow segmented metal backplate, a central embossed horn/paw insignia approximately 6 studs across, and two visible ribs running toward the existing mount sockets. Keep new relief within 0.4 stud of the rear surface and clear of the original tower tips. **Method/dependencies:** Native/Blender mechanical kit; use existing crest palette and glyph motifs, no generative text. **Benefit/acceptance:** The gate reads as finished from both directions. Four cardinal views show intentional craftsmanship and no protrusion through the crown. **Effort/risk:** M / low.

### 05. Strengthen the crest's visible mounting logic

**Finding:** Shot 3 shows a heavy sign supported by simple narrow members. **Build:** Add two tapered copper/iron saddle brackets, approximately 1.2 studs wide, with paired rivet caps and short diagonal gussets at existing strap locations. They should visibly terminate into the gate shoulders, without replacing native tower geometry. **Method/dependencies:** Blender reusable bracket mesh or native wedges; measure current crest/gate intersections. **Benefit/acceptance:** The title feels constructed, not suspended by temporary posts. Side captures show connected endpoints; no bracket obscures a letter from the spawn camera. **Effort/risk:** S / low.

### 06. Frame the demon with a broken ember aureole

**Finding:** The demon floats unsupported in the open arch in shots 2 and 4. **Build:** Mount a sparse, broken metal ring behind it, outer diameter 6.5–7 studs, three separated crescent pieces, thin enough to leave sky between them. Place at least 0.8 stud behind the deepest face surface after measuring bounds; preserve the demon's current rotation and 5-stud height. Avoid a complete disk that blocks the rear view. **Method/dependencies:** Blender swept metal geometry; static attachments for optional item 13. **Benefit/acceptance:** The character appears deliberately summoned. Eyes, horns and jaw remain unobscured from the front and ±45°; passage collision is unchanged. **Effort/risk:** M / medium, visual clutter risk.

### 07. Relight the face as the second focal point

**Finding:** Shot 2's demon is much darker than the title and sky. Existing source already has face lights; their presence is not missing functionality. **Build:** Retune existing keys first, adding at most one small nonshadowing fill only if needed: warm front/side key and dim neutral rim. Keep a short 8–12-stud working range and avoid washing out eye detail. **Method/dependencies:** Native light tuning, checked with the existing 26-stud approach blend. **Benefit/acceptance:** The demon's features are readable at 20 studs while SIEGE remains the strongest distant cue. Compare shadows On/Off and lowest/highest graphics; nothing becomes featureless orange. **Effort/risk:** S / medium, dark PBR can need material-aware lighting.

### 08. Turn the instruction panel into a small carved lectern

**Finding:** Shots 2–4 show tiny icons and a conspicuous blank rectangular back. **Build:** Preserve Merge / Share / Defend copy and physical lettering, but seat the existing panel in a sloped, carved stone plinth with a finished rear shield. Enlarge icon silhouettes by roughly 25% within the existing 13×5.8 panel envelope; keep the top around current height. Rotate only enough to favor the incoming approach. **Method/dependencies:** Reuse native glyphs; Blender/native plinth with 3D frame; coordinate outer panel edge with Bragg circulation. **Benefit/acceptance:** It looks like world furniture. A standing avatar can identify all three icons from 8–12 studs, and no panel collider narrows the path. **Effort/risk:** M / low.

### 09. Add a tiny physical pet-defense diorama

**Finding:** SIEGE conveys combat, but shot 2 alone does not convey shared pets or egg defense. **Build:** On the lectern's outer wing, use a 4×2.5-stud shelf showing one existing egg specimen behind a small shield and two existing pet miniatures aimed outward. Keep silhouettes above the shelf by 1–1.5 studs; do not add mechanics or rotating shop presentations. **Method/dependencies:** Reuse existing models, stripped of scripts/tags and simplified in Blender if needed; item 08. **Benefit/acceptance:** A new visitor can infer pets protecting an egg without reading every caption. Test 5-second recognition with unbriefed viewers; remove a miniature if the group reads as clutter. **Effort/risk:** M / medium, species/scale selection.

### 10. Build two low ember planting pockets

**Finding:** Shots 1–2 have large empty dark ground shapes beside the landing. **Build:** Two asymmetrical 5×8-stud beds just outside the landing shoulders, framed by 0.6-stud broken stone. Combine existing ash brush, dead grass and one small cold-fire accent per bed. Keep growth below 2.5 studs next to sightlines and at least 2 studs from passage edges. **Method/dependencies:** Existing CrossroadsLandscapeAssets; blend with item 02 without moving paths. **Benefit/acceptance:** Middle-scale detail connects the gate to perimeter flora. Arrival view retains an unobscured opening, and no vegetation intersects paving. **Effort/risk:** S / low.

### 11. Place one asymmetric horned-rock composition

**Finding:** Shot 3's immediate outer ground is empty despite detailed distant trees. **Build:** On the arena-facing outer flank only, arrange one existing bone rock and one dark spire within a 6×5-stud footprint, tallest point 4–5 studs. Sink their bases, rotate silhouettes toward the gate, and leave the arena walkway untouched. **Method/dependencies:** Existing rock/skull/spire assets; item 10 palette, arena boundary check. **Benefit/acceptance:** Adds an intentional foreground depth cue without another giant landmark. It must not cover more than one quarter of a gate column from the principal approach or intrude into the arena's entry sightline. **Effort/risk:** S / low.

### 12. Add a pair of compact forge braziers

**Finding:** Ember is present in the arch's texture but absent as a physical material source at ground level. **Build:** Two 2×2-stud braziers, 2.5–3 studs tall, beyond the outer column bases, behind rather than inside the approach fan. Reuse an appropriate existing Hell lantern first; otherwise author one broken crown bowl with a separate ember insert. **Method/dependencies:** Existing assets or new ImageGen → Meshy → Blender prop; item 01 clearance. Native emitter attachment, no damage or interaction scripts. **Benefit/acceptance:** Warm light has a believable source. Both are visible at eye level but cannot be mistaken for new entrances. **Effort/risk:** M / low for reuse, medium for new asset.

### 13. Introduce thin rising ember ribbons

**Finding:** The opening in shot 2 is spatially empty around the demon. **Build:** Up to four narrow textured Beams tracing the inner sides/aureole, width 0.15–0.35 stud, slow upward flow, preserving an open center. No full transparent portal sheet. **Method/dependencies:** Native Beams between measured attachments; item 06 and shared quality controller. Roblox documents textured, curved attachment-based beams and quality-dependent appearance; these are practical tools, not custom shaders. [Roblox Beams](https://create.roblox.com/docs/effects/beams). **Benefit/acceptance:** The portal feels active while the scene beyond remains legible. Front, side and rear review must show no flat-sheet reveal, clipping or obscured face. **Effort/risk:** M / medium, camera-angle behavior.

### 14. Let braziers shed sparse warm sparks

**Finding:** Current stills offer little small-scale atmospheric life near the gate. **Build:** One emitter per brazier, initial 3–5 particles/sec each, 1.5–2.5-second life, maximum size about 0.2–0.4 stud. Sparks rise and extinguish below the title; no broad smoke cloud. **Method/dependencies:** Native ParticleEmitter using existing spark texture or a small ImageGen alpha texture; item 12. Roblox notes particle size and overlapping transparency affect GPU cost; counts here are proposed budgets, not measured guarantees. [Roblox Particle emitters](https://create.roblox.com/docs/effects/particle-emitters). **Benefit/acceptance:** A quiet living forge, with no spark crossing the face often enough to distract; lowest-quality fallback stays attractive. **Effort/risk:** S / low.

### 15. Carve two sheltered cooling fissures

**Finding:** Large flat side parcels in shot 1 can support texture depth without crowding circulation. **Build:** Two 4–6-stud hairline ember seams inside the planting beds, 0.15–0.25 stud wide and recessed below stone caps; one visible inner emissive mesh, not stacked floor planes. Their paths stop before the route. **Method/dependencies:** Blender cut channels or native Edit geometry; items 02/10. Reuse existing lava material; no terrain Basalt experiments or water changes. **Benefit/acceptance:** Heat seems to inhabit the ground, yet no visitor reads the walkway as harmful lava. Inspect grazing angles: solid channel walls hide the emissive insert's edges and never blink. **Effort/risk:** M / medium, joint precision.

### 16. Refine the approach atmosphere into three readable zones

**Finding:** The gate is dark against a bright shared sky; source already implements a client-local tint with outer radius 26 and full radius 10. **Build:** Retune that existing effect rather than adding another global Lighting system: neutral at arrival, warm midtones on approach, modest contrast close to the arch. Keep the 28-stud neutral separation between the two gate zones. Never darken black stone below readable detail. **Method/dependencies:** Existing CrossroadsPreviewTint and crest controller; coordinate Heaven team. ColorCorrectionEffect supports tint, contrast and brightness, but these affect the camera's view rather than selectively repainting geometry. [Roblox ColorCorrectionEffect](https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect). **Benefit/acceptance:** Walk in/out repeatedly without jumps or stale tint; spawn, Bragg and Heaven restore their intended look. **Effort/risk:** M / medium, multiple-controller conflicts.

### 17. Create a restrained positional forge soundscape

**Finding:** Rich visual machinery warrants a nearby sonic identity; still images provide no evidence of current audio. **Build:** First audit existing audio. If absent, one quiet stone/forge air loop at the gate plus a sparse metal resonance from the aureole; initial rolloff roughly 6–26 studs. No global music change and no constant combat screams. **Method/dependencies:** Existing licensed library first, config-owned IDs; one SoundGroup and local mix. Roblox supports position-based sound attenuation and min/max rolloff distances. [Roblox Sound objects](https://create.roblox.com/docs/sound/objects). **Benefit/acceptance:** Audible beside the gate, silent at neutral spawn, intelligible under voice/chat, and fully optional via the game's audio controls. **Effort/risk:** S–M / medium, suitable licensed source selection.

### 18. Give the demon a restrained acknowledgment

**Finding:** The face is recognizable but inert; it can welcome a visitor without a large animation rig. **Build:** On deliberate close approach, a single 1.2-second illumination swell in the aureole/eyes, followed by a slow return. Keep the mesh rotation fixed; no head tracking, mouth movement, camera shake, or mandatory dialogue. At most one acknowledgment per visitor every 12 seconds. **Method/dependencies:** Client presentation controller, items 06/07; later connect only to an approved interaction hook. **Benefit/acceptance:** Feels responsive without pretending travel is enabled. Ten nearby users do not multiply client FX; reduced-motion mode keeps a static readable glow. **Effort/risk:** M / low.

### 19. Add a quiet gathering recess beside the lectern

**Finding:** The threshold is narrow, and future talk/enter interactions could cause people to stop in it. **Build:** Reserve a 6×8-stud standing pocket on the lectern's outer side within available ground, with two low stone leaning blocks rather than a second audience stand. Connect by fitted paving, keep a 10-stud through lane, and do not expand toward Bragg ramps. **Method/dependencies:** Arrival/Bragg owner signoff on exact footprint; items 01/08. Pure environment now; no party or teleport UI. **Benefit/acceptance:** Three player dummies can gather without blocking three others walking past; camera can orbit without clipping a new tall wall. **Effort/risk:** S–M / medium, adjacent route space.

### 20. Compose the rear as a real exit-side view

**Finding:** Shot 4 is a legitimate visitor view but currently exposes stage backs and blank pavement. **Build:** Beyond the arch, use a 4–6-stud-deep fan of matching pavers and a low broken crest fragment at one outer edge, guiding the eye toward central circulation. Finish the rear of the lectern with the same stone vocabulary. Preserve visibility through the opening, and leave a clear turn toward the arena without implying the arena is Pet Siege itself. **Method/dependencies:** Items 01/04/08, rear route and arena owner coordination; existing crest motifs and rock kit. **Benefit/acceptance:** Capture the same rear camera as shot 4: every prominent back has a finished material, the next route is obvious, and no rear decoration hides the face silhouette or creates a false doorway. **Effort/risk:** M / low.

## Top five priorities

1. **01 — Fitted approach paving:** highest visible gain and directly addresses the user's repeated joint concern.
2. **04 — Finished rear crest:** large, undeniable unfinished surface on an otherwise admired asset.
3. **08 — Lectern treatment:** strengthens close-range detail and the mode explanation together.
4. **07 — Demon lighting:** preserves and reveals the recognizable avatar before adding spectacle.
5. **10 — Ember planting pockets:** bridges the current gap between elaborate gate and distant landscape.

Then build 02/03/05/20 as one construction pass; only introduce 06/12–18 after the still composition works. Items 09/11/19 are useful finishing choices, not permission to clutter the opening.

## Detailed implementation sequence

**Phase A — Record and fit (roughly half a day).** In the existing editable preview, capture the four source cameras plus default spawn and avatar-scale threshold. Inventory gate bounds, face bounds, current collision aperture, trim history and existing lights/audio. Resolve ownership of the central-path seam, Bragg-facing lane and arena-facing lane with the adjacent sections. Save backup art under ServerStorage and a config snapshot. No duplicate Studio opening.

**Phase B — Construction first (1–2 focused days).** Build 01–05, 08 and 20 in Edit. Floor polygons must partition one common surface; use an edge ledger identifying which section owns each seam. Walk the path, threshold and lateral routes immediately after geometry. Capture all four cameras before adding props. Reject any pavement that needs nearly coincident top surfaces to look joined.

**Phase C — Character and landscape (1–2 focused days).** Tune 07, fit 06, reuse assets for 09–12 and 19. Test with three waiting dummies and three passing players/reference rigs. Keep all new decorative collision off except intentional foundation/leaning furniture; broad walkable surfaces use simple collision. Decide whether the single custom brazier is actually needed after reuse trials.

**Phase D — Native FX and audio (1–2 focused days).** Implement 13–18 in a local preview controller using existing config conventions. Stage a static fallback first. Add each layer separately and compare identical cameras. Do not import the whole RBX-FX-GEN lab or combat adapter into the hub. Capture 60 seconds at lowest and highest graphics, arrival and threshold, both with effects off/on.

**Phase E — Whole-hub acceptance (half to one day).** Review with Heaven, arrival and arena sections active together. Repeat default walk at 24, all rear/side views, respawn, graphics/audio preferences and leave/re-enter transitions. Commit authored config/assets and wiki notes through the parent workstream only after validation. These are human-equivalent effort ranges, not elapsed automation promises; a new Meshy prop can add an unpredictable iteration cycle.

## Asset briefs and pipeline choices

**Reuse immediately:** original Hell bay-end mesh and PBR maps, demon face, 3D glyphs and crest, ash/dead brush, bone rock, dark spire, appropriate Hell lantern, egg/pet miniatures. Clone art only; strip source gameplay scripts, prompts and tags. Do not change native model IDs in services.

**Precision kit — Blender/native, not image-to-3D:** fitted pavers, bevelled foundation fascia, crest ribs/brackets, broken aureole, threshold seal and lectern. Shared warm stone/metal atlas where practical. Split independently animated/glowing elements into separate named objects. Ground pivot, gate-local axis convention, clear aperture proxy and simple collision proxy must accompany exports. Budget proposed: all new solid detail combined under 15,000 visible triangles, with a lower-detail version for small props. Verify actual output rather than trusting generation targets.

**Conditional new prop — Crown Brazier:** concept brief: “Stylized premium voxel-compatible infernal courtyard brazier, low three-pronged forged crown bowl, weathered charcoal stone foot, copper heat discoloration, carved paw-and-horn relief, broad readable bevels, no skull face competing with the demon, no smoke/fire baked into geometry, separate removable ember core, orthographic front/side/back on neutral ground.” Use ImageGen for the reference, Meshy Smart Topology for a geometry candidate, Blender for integrity, silhouette, UV seams, decimation and separated core; texture only the accepted geometry. Archive source/concept/export/manifest under Assets before a group-owned Roblox upload. Generate one versatile prop, not separate near-identical variants. This review did not generate or upload it.

**Texture-only brief:** an irregular tapered grayscale ember filament with clean alpha and a tiny spark fleck; no baked orange background, no rectangular borders. ImageGen may produce source texture; final alpha cleanup and tiling verification are required. Prefer existing textures if their silhouette works. Texture motion uses native Beam properties rather than a custom shader.

**RBX-FX-GEN reality:** its inspected current implementation is a deterministic crystal-eruption renderer and lab with seek/update/stop handles, native facets, rubble, fissures, vapor, glints and one light. It is not a complete generic FX editor, and standalone extraction/performance validation is still pending. Its preset validation, bounded lifetime and local-layer architecture are useful references. A portal/aureole preset would be new work; there is no existing “Hell gate” export button. The full crystal eruption is the wrong ambient effect here. A future event may borrow its fissure/glint vocabulary after separate adaptation and review, but this 20-item plan does not depend on it.

## Performance, accessibility and acceptance envelope

- Proposed maximum incremental ambient load per nearby client: four narrow Beams, two small spark emitters totaling 10 particles/sec, at most three added nonshadowing lights including braziers, one steady audio loop. Additional face lighting should first replace/rebalance existing lights. These are starting caps, not proof of acceptable performance.
- Disable decorative motion beyond 60 studs, with hysteresis and a static fallback; retain the existing 26-stud atmospheric blend. Use a small indexed registry and one update loop, never recurring full-Workspace scans. Existing project profiling already identified that failure mode.
- Transparent layers must not overlap into a solid bright mass. Particle/Beam screen area matters; examine from the doorway, not only the distant camera. Start with no broad smoke and no full-screen portal plane.
- Low graphics and reduced-motion presentations retain all direction signs, demon silhouette and threshold seal. No flashes, forced camera changes, camera shake, tiny essential copy, or color-only destination differentiation. Muting audio loses no instructions. A new motion setting is proposed integration, not claimed current UI.
- Compare identical camera/device/quality runs with 10 visible reference avatars. Initial gate: no more than 1 ms median incremental GPU frame time and no more than 2 ms p95 total frame-time regression against effects-off on the team's chosen minimum device. Record hardware and distribution; revise budgets or strip optional layers if missed. Studio-only measurements cannot certify mobile performance.
- All new scripts/configs are presentation only in this phase. Travel and talk remain disabled unless separately integrated. Never clone Merge's bay spawn tags, enemy hooks, lightning routing or return prompts into this hub.
- Final screenshot set: original four matched cameras, spawn first impression, lectern close-up, threshold eye-height, rear junction grazing angle, and the same views on low graphics. Add short motion captures for light blending, ribbons and acknowledgment; screenshots alone do not validate those.

## Adjacent-section interfaces

**Arrival owner:** central-to-Hell paving endpoint is a shared measured boundary. Keep SIEGE readable from spawn, preserve gate centers and path travel time, carry over repaired joint geometry, and let only one baker own each top polygon. No new floor surface may overlap the arrival owner's paving.

**Heaven owner:** same level of craftsmanship and approximately equal silhouette weight, different materials. Agree on sign-back finish, lectern scale and client tint ownership. Hell's ambient sound/FX must fade before the neutral gap.

**Arena owner:** protect the arena entry/cross-route and spectators' sightlines. The forge gathering pocket cannot become a queue on the arena access. Reuse the Hell material family, but reserve bulwarks, combat confinement cues and crowd spectacle for the arena so the actual Pet Siege destination remains unambiguous.

**Bragg/landscape owner:** no new tall tree or brazier smoke between arrival and the rear landmark. Use existing flora caches and avoid moving perimeter assets without that owner's review. The gate's rear improvement should support the ring walk rather than claim extra frontage.

## FX implementation clarification

The user subsequently clarified that worthwhile modest new effects should be built in
RBX-FX-GEN. Current crystal-only capability is not a restriction on this design. Use the
[shared small-effect backlog](FX_IMPLEMENTATION.md) to implement narrow ambient, flow,
ripple or burst primitives and reusable presets; a general-purpose editor is not required.
Larger tooling work remains a separate scope decision.
