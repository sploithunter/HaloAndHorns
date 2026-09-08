# 01 — Arrival, Crossroads and Overlook: The Treaty Walk

Design proposal, 2026-09-08. No geometry, assets or gameplay changed for this review. All dimensions below are proposed unless explicitly identified as current. The premium direction is a carefully built neutral avenue between two living realms: ivory and bronze meet charcoal and aged copper through shared stone craftsmanship. The two admired gates remain the primary silhouettes. Detail becomes richer as players approach; the initial choice stays immediate.

## Evidence and scope

Inspected every supplied image in `output/realm_crossroads/design-review/screenshots/`:

- `01-arrival-1.png`: overhead. Strong bilateral organization and clear gate branches; large empty foreground lawns, broad unarticulated activity connections, a plain straight central strip, and an exposed overlook composition. The north end of the strip reads as a stop before the next terrace; verify the connecting footprint before decorating it.
- `01-arrival-2.png`: spawn toward gates. Existing crests already create a memorable choice. The foreground occupies much of the frame with near-identical pale slabs; dark border lines terminate visually without a destination. Distant Bragg walls read as blockout masses.
- `01-arrival-3.png`: oblique across overlook stairs and gates. Stair construction is legible but bare, landscape reaches straight into architectural edges, and the existing broad approach could support attractive small resting pockets without lengthening primary travel.
- `01-arrival-4.png`: toward spawn/overlook. Plain guardrails and large empty ground planes dominate; the tiny gold spawn marker has no architectural explanation. Hell trees are interesting silhouettes but need rooted foreground composition.

Verified `configs/realm_crossroads_terrain.json`, `configs/realm_crossroads_paving.json`, `tools/realm_crossroads/finish_arrival.luau`, and the current Crossroads wiki. Current central paving is 20 studs wide, Z6–120, top Y0.44, with 0.6-stud edges and 4×19 pavers. Spawn is X0/Z100. Gates are X±40/Z42, angled toward arrival. Walking speed is 24 studs/sec. Overlook is Y−4 around Z136–152, reached by 8 steps over 16 studs or flanking 1:8 ramps. Later fishing/leisure configs supersede original island side extents; this proposal does not undo those expansions. Older wiki proposals are not evidence of the live geometry.

Ownership: this section owns the neutral spine, arrival-side foreground, branch junction finish, and south overlook. Gate internals, garden activity floors, fishing shorelines, audience stands and Bragg rotunda are adjacent owners. “Rear overlook” here means the lower terrace behind spawn at positive Z; it is distinct from the northern Bragg terrace.

## Twenty detailed improvements

### 1. Make the repaired pavement a single architectural kit

**Observation:** Images 1–3 show a coherent center but very broad, differently finished side pieces. **Build:** retain the current footprints and corrected cleaved boundaries; replace large flat expanses with a shared 4–6-stud stone module, warm neutral joints and corner blocks. Use a common edge profile where branches meet the 20-stud avenue. Preserve exact shared polygon boundaries rather than placing a decorative slab on top. **Method:** Blender for a small reusable bevel kit; existing Limestone/Slate materials for the first pass. **Benefit:** expensive-looking craftsmanship without new obstructions. **Dependencies:** approved junction geometry and adjacent gate landing boundaries. **Effort/risk:** M / medium, because rebaking can reintroduce overlaps. **Acceptance:** no two visible horizontal faces occupy the same footprint/elevation; no flicker in a 360° grazing-angle camera sweep; 20-stud lane remains clear and walking crosses every join without a bump.

### 2. Replace the tiny marker with a flush Treaty Seal

**Observation:** the small gold square in images 1, 3 and 4 reads as a development marker. **Build:** a 10-stud circular medallion centered at X0/Z100, halo and horn forms enclosing a simple meeting-line motif. Cut the circle out of surrounding pavers and insert it flush at Y0.44. Keep the actual invisible SpawnLocation unchanged. **Method:** ImageGen motif sheet if needed; trace controlled contours in Blender, shallow relief in the inset mesh. Avoid Meshy for exact tiling geometry. **Benefit:** deliberate arrival identity and an obvious rendezvous point. **Dependencies:** item 1. **Effort/risk:** M / low. **Acceptance:** no raised lip, no coplanar backing under the visible seal, two players can stand on it while routes remain unobstructed, no text required to understand its role.

### 3. Give the gate fork a legible decision apron

**Observation:** in image 2, the long straight route visually favors the distant terrace over the two immediate modes. **Build:** at the existing diagonal branch intersections, replace selected center stones with a bilateral chevron band; its two arms point toward the gates while straight stones continue to Bragg. Band width 1.2–1.8 studs; no widening or gate movement. **Method:** native or Blender-cut inserts using bronze left and dark copper right plus different engraved shapes. **Benefit:** eyes and feet discover the intended first choice. **Dependencies:** gate owner confirms approach axes. **Effort/risk:** S / low. **Acceptance:** first-time visitors identify both mode entrances from spawn within five seconds; direction survives grayscale and lowest graphics.

### 4. Carry the spine visibly into the Bragg approach

**Observation:** image 1 shows the central strip ending before the broad stair composition, reading as unfinished. **Build:** audit the current end at Z6 against the actual Bragg entry; extend the same paving rhythm through the existing walkable connection, ending on one deliberate threshold course at the terrace interface. Do not blindly bridge grass, steps or a fountain route. **Method:** measured polygon drafting and the same kit as item 1. **Benefit:** a continuous destination hierarchy and fewer ambiguous dead ends. **Dependencies:** Bragg owner supplies the exact boundary/height and approves ownership handoff. **Effort/risk:** M / medium. **Acceptance:** an overhead trace contains no unintentional gap between arrival avenue and Bragg accessible entry; route remains open around the fountain; no duplicate floor geometry at the handoff.

### 5. Turn branch leftovers into planted wedges

**Observation:** images 1 and 3 contain broad empty triangular grass/dark-ground pockets around the diagonal routes. **Build:** compose three groups per realm in these existing pockets: low groundcover at the point, medium flower/bone cluster, one offset taller accent at the wide end. Keep plants at least 2 studs outside usable pavement and under 2.5 studs inside arrival-to-gate sight cones. **Method:** reuse flower bushes, softglow blooms, ash brush, skull lanterns and stone catalog assets; vary group composition rather than blanket scatter. **Benefit:** intentional geometry and a softer human-scale foreground. **Dependencies:** junction polygon registry. **Effort/risk:** S / low. **Acceptance:** both gate faces and mode titles remain fully visible from spawn; no foliage clips shoes or pavement; every group has a visible ground contact.

### 6. Shape the realm seam as an intentional border

**Observation:** image 4 exposes a stark grass-to-dark-ground divide that looks like a paint boundary. **Build:** outside the avenue only, use a 4–6-stud-wide transition garden: pale stone fragments become charcoal fragments with sparse shared silver grass. Stop the border at each path with a cut stone end block. **Method:** existing rocks/plants and careful 4-stud voxel terrain shaping; no glowing fissure under the player. **Benefit:** Heaven and Hell feel geographically joined. **Dependencies:** landscape owner and pavement masks. **Effort/risk:** M / medium. **Acceptance:** no alteration to collision paths; no terrain pokes through paving; colors remain distinct even with FX disabled.

### 7. Build paired arrival framing trees

**Observation:** screenshot 1 puts all substantial vegetation near the outer corners; image 2 has little near-camera framing. **Build:** one existing Heaven tree and one Hell tree in outer foreground lawns, roughly X±46/Z108, after checking ramp setbacks. Match canopy visual mass rather than identical mesh scale. Keep trunks outside ramp envelopes and canopies outside crest silhouettes. **Method:** existing pink/cloud tree and twisted Hell tree; authored roots or rocks seat them. **Benefit:** layered depth and an immediate realm contrast around the gate view. **Dependencies:** overlook ramp survey and landscape owner. **Effort/risk:** S / medium, possible occlusion. **Acceptance:** both complete gate titles fit unobstructed in a standard third-person spawn view and in a tall-avatar camera; route clearance remains at least its current width.

### 8. Craft the stair sides into real retaining architecture

**Observation:** image 3 shows clean steps but exposed bare ends. **Build:** add 1.5–2-stud cheek walls outside the 32-stud central stair width, matching the −4 elevation descent; a continuous stone cap and 0.5-stud recessed vertical seam articulate each side. Heaven-facing side uses pale stone, Hell-facing side dark stone, with shared bronze cap details. **Method:** native solid geometry, Blender endcaps only if required. **Benefit:** the stair reads as built into the island. **Dependencies:** item 1 and current stair colliders. **Effort/risk:** M / low. **Acceptance:** original stair width is preserved, cheeks do not intrude into first/last treads, no overlapping top slabs, avatars traverse without camera obstruction.

### 9. Make the alternate ramps visibly inviting

**Observation:** overhead image 1 shows flanking access paths, but their relationship to the overlook is weak at eye level. **Build:** retain both 16-stud-wide 1:8 ramps; use matching inset stone strips, clear terminal landings and low warm lamps at the outer edge. Add a small carved continuous-route symbol at each approach rather than a stair-only direction. **Method:** shared paving kit and existing lamp forms. **Benefit:** accessible routes feel equally intentional. **Dependencies:** stair and rail revisions. **Effort/risk:** S / low. **Acceptance:** uninterrupted collision route from court to overlook in both directions; lamp bases stay outside all 16 studs; no unavoidable steps or snagging at landings.

### 10. Replace the overlook railing with a paired balustrade

**Observation:** images 1 and 4 show thin blank rail bars against sky. **Build:** replace only the visible south overlook rail with 8-stud modular segments, 3.5–4 studs high, alternating open arches and modest stone piers. Heaven piers carry a feather relief, Hell piers a horn relief; the central panel combines both. Preserve the independent invisible safety wall. **Method:** Blender modular kit; reference existing gate carving language without cloning entire gates. **Benefit:** a credible destination and a finished island edge. **Dependencies:** safety-wall positions and item 8. **Effort/risk:** M / medium. **Acceptance:** no climbable route bypasses outer safety collision; 60% or more of the outward view stays visually open; no thin sparkling coplanar rail overlays.

### 11. Compose a social overlook with four usable benches

**Observation:** image 4 shows empty space with no reason to linger. **Build:** two bench pairs on the left/right widened ends of the existing overlook, about 8 studs long each, leaving the central stair exit and a continuous 12-stud circulation aisle clear. Orient one pair toward the realm panorama and one toward companions. **Method:** reuse seats/bench assets with native Seat instances; no ranking dummies in this zone. **Benefit:** a quiet meeting place distinct from combat spectators. **Dependencies:** measured usable terrace footprint and rail revision. **Effort/risk:** S / low. **Acceptance:** eight seated avatars plus two walking visitors fit without collisions, dismount toward clear pavement, camera does not enter the rail or tree trunk.

### 12. Add a low sculpted world directory beside arrival

**Observation:** screenshots communicate the two modes well, but fishing, spectator access and rankings are invisible from spawn. **Build:** a 7×5-stud angled stone relief table in a small pull-off near X−20/Z106, subject to ramp clearance. A physical miniature shows the two crests, trophy, fishing hook and arena symbol; carved arrows map to actual routes. Limit text to short destination names. **Method:** Blender exact relief and existing glyph workflow; optional SurfaceGui only for future localized supplementary copy, never the main identity. **Benefit:** optional exploration help without an onboarding interruption. **Dependencies:** all section owners confirm names and geography. **Effort/risk:** M / medium, legibility/localization. **Acceptance:** readable from 6–8 studs, a player studying it never blocks the 20-stud spine, no unimplemented reward promises.

### 13. Introduce a consistent physical wayfinding family

**Observation:** side activity links in image 1 look similar despite different purposes. **Build:** paired low 3-stud markers at the outward branch exits near X±48/Z80, with a fishing-hook symbol, egg symbol or arena motif placed according to actual route. Put taller 6-stud narrow posts only at secondary forks beyond the gate view. **Method:** reusable stone/metal frame and separate replaceable icon inserts, palette in config. **Benefit:** exploration remains readable as the map grows. **Dependencies:** shared icon and destination registry with adjacent owners. **Effort/risk:** M / low. **Acceptance:** each marker points to a verified route, identical symbols mean identical destinations map-wide, symbols remain recognizable in grayscale; no FUTURE placeholders.

### 14. Create restrained lantern pools along the avenue

**Observation:** image 2 is uniformly lit, making the crafted stone and dark route comparatively flat. **Build:** four low lanterns per side, outside the 20-stud route, concentrated at arrival, fork and overlook landing rather than a repetitive fence. Use warm neutral light near spawn and localized pale-gold/copper housings outward. **Method:** existing lantern meshes, small native lights; shadow casting disabled on decorative light sources unless a measured visual need justifies it. **Benefit:** evening readability and material depth. **Dependencies:** lighting ownership and gate approach lights. **Effort/risk:** S / medium, cumulative lighting. **Acceptance:** dark-side floor remains legible at low graphics; lights do not wash out crest letters; no more than four new local lights affect one close-up view in the target composition.

### 15. Add a quiet arrival pulse to the seal

**Observation:** spawn has no ceremonial moment despite the dramatic destination gates. **Build:** on arrival only, a thin halo traces the seal edge over 1.5–2 seconds and disappears; a few gold/silver motes rise under ankle-to-waist height. No camera takeover. Static seal remains complete without it. **Method:** small curved Beams plus one ParticleEmitter; this is new arrival logic, not an existing RBX-FX-GEN feature. [Roblox Beams support textured spans between attachments](https://create.roblox.com/docs/reference/engine/classes/Beam). **Benefit:** a memorable but brief welcome. **Dependencies:** production spawn event and reduced-motion setting; preview trigger first. **Effort/risk:** M / medium. **Acceptance:** one pulse per actual arrival, none on ordinary crossing, no effect obscures a player or title, reduced-motion mode uses a steady short glow or no pulse.

### 16. Animate the realm edges with sparse drifting detail

**Observation:** screenshots show static foregrounds even though existing tree shapes imply wind and magic. **Build:** two small emitter groups per realm, around planting pockets rather than over pavement. Heaven: slow petals; Hell: sparse cooled ash with occasional ember. Limit each group to a proposed 3 particles/sec and 3-second life. **Method:** reuse suitable textures; ImageGen transparent sprite sheet only if catalog lacks a strong silhouette. Native emitters support color sequences and wind-aware drift; graphics settings affect appearance, so test low and high. [Particle authoring](https://create.roblox.com/docs/effects/particle-emitters). **Benefit:** life without visual noise. **Dependencies:** item 5 and FX budget. **Effort/risk:** S / medium. **Acceptance:** at most about 36 steady-state particles for these four groups, fade in/out, never look like pickups or hazards, static low-quality fallback remains attractive.

### 17. Create spatial audio that follows the geography

**Observation:** screenshots cannot establish audio; visual realm contrast suggests an opportunity to verify the current soundscape. **Build:** if absent, add a subtle wind/chime bed on Heaven foreground and distant low crackle on Hell foreground, attenuating before the central lane. The overlook receives quiet open-air wind. **Method:** existing licensed game audio first, separate ambient sound group, explicit minimum/maximum distances. Roblox documents distance rolloff for [spatial Sound objects](https://create.roblox.com/docs/sound/objects). **Benefit:** emotional atmosphere without bigger geometry. **Dependencies:** audio inventory and accessibility settings. **Effort/risk:** S / medium, overlapping loops. **Acceptance:** no abrupt sound boundary at 24 studs/sec, central spawn remains acoustically calm, mute/volume controls work, no gameplay information exists only in audio.

### 18. Add a paired memory relief at the overlook

**Observation:** image 4 offers sky and rail but no close-range discovery. **Build:** two 6×3-stud carved panels integrated into outer balustrade piers: a gentle scene of pets tending growth and a companion scene of pets standing together against a siege. Keep relief depth under 0.5 stud and outward view open. **Method:** ImageGen orthographic composition brief, Meshy only for sculptural relief draft, Blender retopology and exact backing plane, existing asset pipeline. **Benefit:** lore and photo detail without an extra tower or tutorial. **Dependencies:** narrative/art review and rail module dimensions. **Effort/risk:** L / medium, generated detail may be muddy. **Acceptance:** readable silhouettes at 10 studs, no unintended symbols/text, separate background and relief geometry, shared material atlas where practical.

### 19. Give the side slopes rooted, layered geology

**Observation:** image 4 has bare terrain slopes with interesting Hell trees appearing isolated above them. **Build:** two or three low outcrop clusters per side outside ramp/pavement boundaries, with the existing rock palette emerging from terrain in broad 6–10-stud masses. Place roots, shrubs and small stones at contacts. Avoid repeating spires along every edge. **Method:** existing quartz/bone/dark-rock assets, Blender variants only if source silhouettes cannot provide variety. **Benefit:** believable ground contact and richer oblique views. **Dependencies:** landscape owner and safety boundary. **Effort/risk:** M / low. **Acceptance:** every large prop has an intentional seated base, no accidental collision shortcut to the outer edge, no new foreground outcrop hides mode captions.

### 20. Add a distant split-realm vista from the overlook

**Observation:** image 4 looks across a mostly empty horizon, weakening the purpose of the viewing terrace. **Build:** beyond the playable safety boundary, compose three distant Heaven floating stone/island silhouettes on the left and three dark fractured silhouettes on the right, below gate-title height from spawn where possible. Use 20–40-stud silhouettes at a trial 150–250-stud distance; size and distance are camera-tested proposals. **Method:** reuse existing rocks/spires; Blender combine and simplify; no colliders, no local lights, no invitation to jump. A new skybox is unnecessary. **Benefit:** the hub feels part of a world while its playable area stays compact. **Dependencies:** island/skyline owner, streaming/performance strategy. **Effort/risk:** M / medium, landmark competition. **Acceptance:** the vista is legible from the overlook but subordinate in the spawn view; no apparent reachable reward or platform; low graphics preserves two clear realm silhouettes.

## Top five priorities and sequence

| Priority | Improvement | Reason |
| --- | --- | --- |
| P1 | 1 — shared paving kit | Protects the hard-won rendering correction and establishes all later craft. |
| P2 | 4 — continuous Bragg connection | Resolves the overhead impression of an unfinished route before dressing it. |
| P3 | 5 — planted wedges | Highest visual return using owned assets; gives the branch geometry purpose. |
| P4 | 10 — overlook balustrade | Makes the currently bare edge a credible destination. |
| P5 | 2 — Treaty Seal | Establishes a unique arrival identity at modest scale. |

Effort definitions: S ≈ half to one focused implementation day; M ≈ one to two; L ≈ two to four including art iteration. These are planning ranges, not delivery promises, and exclude gameplay integration or asset moderation delays. The twenty entries are a coordinated menu; implement foundations first and reject any decoration that weakens the gate view.

## Detailed implementation plan

**Phase A — survey and locked interfaces.** Work in the existing Studio preview. Record current part footprints, true top elevations, gate view cones, collision paths and saved cameras corresponding to all four evidence images. Capture baseline CPU/GPU time, memory and instance count. Agree boundaries with Bragg/gate/landscape owners. Mark an uninterrupted 20-stud spine, all existing 16-stud ramps, and the 32-stud overlook stair as exclusion volumes. Deliver a dimensioned overhead diagram and a cross-section through stair/overlook; no new art yet.

**Phase B — architecture first.** Implement 1, 4, 8 and 9 in the Edit baker. Preserve existing terrain backups and never layer slabs to mask an error. Draft shared edge intersections before generating geometry. Walk every junction both ways at 24 studs/sec and compare grazing-angle images. Then implement 10 and reserve bench/directory footprints. Stop and repair any collision or overlap before dressing the map.

**Phase C — identity and furnishing.** Prototype 2, 3, 11, 12 and 13 using accurate low-cost geometry. Test spawn readability with 10–20 avatar silhouettes, including tall accessories. Finalize exact signs in Blender/the existing glyph workflow. Ensure players seeking fishing, combat or rankings can discover their route without entering a mode gate. Document localizable text separately from baked art. Implement gameplay-dependent seating/arrival only through the appropriate later integration owner.

**Phase D — landscape composition.** Implement 5, 6, 7 and 19 with owned assets. Review three depth layers: low foreground, gate-height middle ground and taller perimeter. Keep left and right equal in visual weight rather than copying placement one-to-one. Coordinate 20 as a vista prototype before any new mesh generation; remove it if it distracts from the gates.

**Phase E — specialty art.** Generate concept sheets only for unresolved seal, balustrade or relief design. Process selected sculptural assets through ImageGen → Meshy → Blender → Assets → Roblox. Exact modular geometry, readable type and tile boundaries go directly through Blender. Inspect UVs, silhouette, base contact, material atlas and collisions in the actual map; no raw generated asset is accepted merely because it looks good in a turntable.

**Phase F — atmosphere.** Implement 14, 16 and 17 at low initial intensity. Prototype 15 through a manual preview trigger until spawn integration exists. Build 18 only after core composition is strong. Check low/high graphics, audio mute and reduced motion. Compare against the Phase A baseline and trim effects before raising visual intensity. Final captures repeat all four views plus eye-level routes and seated overlook views.

## Asset briefs and tool selection

- **Treaty stone kit:** four paver sizes, straight/inside/outside edge pieces, stair cheek, pier and cap. Warm worn limestone; charcoal counterpart shares proportions. Direct Blender construction; exact planar contact; one reusable atlas if custom PBR is justified. Target each ordinary module under 1,000 triangles, tiny trim far lower.
- **Seal:** top-down halo/horn union, no text, broad readable shapes, neutral bronze with two realm accents. ImageGen can explore composition; Blender authors measured 10-stud round insert and perimeter topology. No animation baked into the mesh.
- **Balustrade:** airy arches, chunky piers, separate feather/horn medallions, only enough weathering to break perfect surfaces. Direct Blender base; Meshy can draft a medallion if existing gate motifs are insufficient. Target under 2,000 triangles per decorative module before instances.
- **Memory relief pair:** orthographic, side-lit sculptural panels, pets clearly helping/gathering or defending together, no lettering or intricate miniature faces. ImageGen composition; Meshy draft; Blender rebuild backing, reduce hidden geometry and unify UVs. Proposed total target under 8,000 triangles for both panels, revised after camera review.
- **Petal/ash:** shared small transparent atlas where possible. ImageGen only if no existing usable texture. Motion supplied by Roblox emitters, not Meshy. No green pool mist duplicated into this area.

RBX-FX-GEN is currently a **config-driven crystal eruption** renderer/lab with deterministic timeline, seeded variation, mesh facets, rubble, fissures, vapor, glints and local light. Its own wiki explicitly says the general multi-effect editor, standalone verification, mobile budgets and production integration are unfinished. It is useful as a reference for preset validation, bounded lifetime and preview tooling. It does **not** currently supply the proposed arrival seal, petals, audio or a universal map FX package. Do not import explosive crystal eruptions into the spawn just because the tool exists. Any reuse needs a small explicit adaptation with configuration ownership, client-only rendering and measured budgets.

## Performance, accessibility and integration contracts

Provisional arrival-section incremental budgets: ≤60,000 visible added triangles, ≤200 added static instances, four small ambient emitter groups, about 36 steady-state particles from item 16, and a maximum of four new lights affecting one close camera. These are design targets to validate, not Roblox limits. Reuse meshes/materials, avoid large overlapping transparent sheets, and disable unnecessary decorative collisions/shadows. Roblox notes particle size/overdraw costs and recommends checking graphics levels; its [performance guidance](https://create.roblox.com/docs/performance-optimization/improve) informs the comparison, not a claim that these budgets are already proven.

Profile the same spawn-to-gates/overlook traversal before and after on a representative mobile device: target less than 1 ms added median frame time from this section, with a 30 FPS low-tier floor for the whole scene and no sustained regression beyond the baseline device's margin. If baseline already fails, record that and reduce scene cost before accepting more detail. Run with the fountain and neighboring FX visible, not in isolation. Disable ambient FX at distance and retain static readability.

No floor decal or thin sheet should cover another floor to hide a seam. Insets replace their host face; borders share exact edges. Paths retain their current widths and ≤1:8 ramps. Light, color, sound and motion are supplementary: physical silhouettes and direction remain sufficient without them. No camera shake, forced pan, rapid strobe or automatically looping arrival spectacle. Test mobile aspect ratios, default third-person, tall avatars, and crowding at 24 studs/sec.

Gate interface: preserve X±40/Z42 centers, scale, faces, existing admired crests, entrance clearance and title sightlines. Gate owner owns approach atmosphere/interaction; arrival must not install a competing Lighting controller. Bragg interface: agree a single shared threshold polygon and route finish; fountain and ranking displays are untouched. Activities/fishing interface: icon destinations and paths must match actual access; no new catch economy, leaderboard or arena logic. Landscape interface: one owner approves trees, realm seam and vista so placements are not overwritten by scatter bakes. Safety interface: decorative rail changes never replace or weaken invisible perimeter containment.

All new IDs, dimensions, palettes, FX rates and budgets belong in config or config-named art sources. Build geometry once in Edit. Production spawn/travel, one-shot arrival triggers and dynamic directory text are separate integration work; the map review must not claim those systems exist.

## FX implementation clarification

The user subsequently clarified that worthwhile modest new effects should be built in
RBX-FX-GEN. Current crystal-only capability is not a restriction on this design. Use the
[shared small-effect backlog](FX_IMPLEMENTATION.md) to implement narrow ambient, flow,
ripple or burst primitives and reusable presets; a general-purpose editor is not required.
Larger tooling work remains a separate scope decision.
