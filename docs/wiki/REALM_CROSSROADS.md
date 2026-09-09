# Realm Crossroads

Status: R11 imported into Farm and Fight and saved to Roblox (2026-09-09). Root: `Workspace.RealmCrossroadsR4`, translated (-8192, 0, 0). Visual companions, spaced Crossroads arrivals and the local Farm gate run. Homeworld’s former Merge doorway now returns locally to Crossroads using its existing E prompt. Pet Siege and activity gameplay remain disconnected. See [import contract](../art/crossroads-review/FARM_IMPORT.md).



## R8: realm landscape and outer safety boundary

Heaven occupies negative X (left) and Hell positive X (right), matching the gates.
Config-named Edit baker `bake_landscape.luau` themes terrain and structural surfaces,
keeps the center neutral, and places 225 existing textured perimeter flora models, plus two Hell accent trees around the rim:
pale/pink/cyan trees, flowers and quartz left; dark/coldfire/lava-eye trees, ash/brush,
bones and spires right. Staggered canopy and understory rows leave activity floors,
Bragg and the central overlook approach clear. Native templates are cached under
ServerStorage.CrossroadsLandscapeAssets. Landscape bake follows the activity bake.

Eight overlapping invisible collidable walls follow an inset clipped rectangle around
the island. They extend from Y=-32 to +68, behind perimeter vegetation, preventing ordinary
walking/jumping off the outer edge. These global safety walls are separate from the future
combatant-only arena containment rule. Cardinal approach tests blocked at all four outer sides, including the front away from
the overlook rail. The arena entry remains walkable in this map preview.

## R7: side activities — map only

The hub will live inside Farm & Fight. User explicitly deferred gameplay integration.
The two +4 garden terraces now contain a west **Coin Garden** and east **Patrol Grove**:

- Coin Garden: 64×90 open drop lawn, perimeter circulation (coin specimens removed after scale review),
  original Hall stand and Wayfinder egg as display-only specimens under an open pergola.
  The physical title is **Egg of the Week**; no weekly schedule, roster or price is set yet.
- Patrol Grove: 64×102 combat footprint, low staggered cover, four invisible route markers,
  and the existing tier-2 Impaler Palisade bulwarks. Lightning was removed at user request.
  Two 14-stud entry spans are shown retracted; each segment stores DeployedPivot/RetractedPivot
  for later rise animation. Bulwark meshes are currently noncolliding;
  combatant-only containment belongs to later gameplay integration,
  rear encounter anchor and Heaven/Hell banner ruins. Southern gathering terrace and benches
  keep waiting players outside the marked combat footprint. Temporary alliances remain
  the existing gameplay system to bind later; none are simulated by the map.
- Both retain the existing +4 garden stairs and 1:8 ramps. Both stair and ramp routes, plus the egg-pavilion approach, passed walking checks at speed 24. Existing flowers, saplings, skulls,
  quartz and bone rocks decorate edges instead of replacing the playable floor.
- Both fields are now 64 studs wide, centered at X=±120. Inner edges remain X=±88.
  Symmetric terrain extensions keep +4 terraces through |X|=160 and rise to the +12 rim
  by |X|=176; the island remains 360×320. Original flank terrain is backed up in
  ServerStorage.ActivityTerrainWestBefore/EastBefore. Multiplayer squad crowding still
  needs a live gameplay test; this is the authored space, not a capacity guarantee.
- `configs/realm_crossroads_activities.json` names `tools/realm_crossroads/bake_activities.luau`.
  `ServerStorage.CrossroadsActivityAssets` caches original textured geometry from Farm & Fight
  and Merge. Author after the terrain/crest/Bragg passes. Geometry is not generated in Play.
- Markers have `IntendedBinding` metadata only, no active gameplay tags. All example assets
  are static, noncolliding and stripped of scripts/prompts/tags. Bind Hall-style shared
  BreakableSpawner/DropService/Magnet, existing EggStand hatch logic, bounded patrols and
  RealmAllianceService when integrating into Farm & Fight. Do not revive Hall entry routing.
- Patrol bounds and alliance engagement radii need an explicit integration review: current
  realm engagement radii are much larger than this compact garden. Keep recruitment and
  chase/leash behavior inside the activity; do not pull hub bystanders into fights.

## R6: Bragg Rotunda and Siege ranking plan

User accepted the R5 gate artwork and requested more Bragg capacity plus Siege-specific
rankings using existing leaderboard rules. The [R6 design](../REALM_CROSSROADS_BRAGG_PLAN.md)
now has a +4 circular court, 116 studs across, with a low 18-stud fountain, fourteen
2/1/3 alcoves, eight initial categories, and six reserve bays. Shared stairs/ramp landings
avoid routing visitors through podiums. Geometry is built; production tracking remains pending. Eight podium groups have physical PREVIEW nameplates; six reserve bays at positions 2/4/6/9/11/13 alternate among the rankings, with three Heaven flower displays alternating with three Hell skull displays. These reuse Merge's field_flower_bush, softglow_bloom, crystal_bloom and horned animal_skull meshes, plus the catalog hell_skull_lantern. Improvised flowers and floral medallions were removed. No FUTURE signage remains. A low halo-and-horns fountain anchors the center.

The source already saves **highest wave reached** when a wave starts. New Highest Wave
Cleared and Total Waves Cleared require durable server-side settlement counters. User replaced
the redundant boss-wave proposal with **Bosses Defeated — All Realms**, counting actual
boss defeats in both Farm & Fight and Pet Siege; do not relabel or migrate reached-wave values as clears. The plan defines receipt
idempotency, legitimate offline provenance, reset/migration behavior, existing internal-ID
exclusions and publication cadence, and bounded winner-avatar loading before expansion.
`configs/realm_crossroads_bragg_plan.json` names the Edit-only `bake_bragg.luau` art companion.
Regenerate in order: TerrainBake, CrestBake, BraggBake. No runtime geometry generation.
`BeforeBraggR6` retains original terrain and superseded gallery geometry. Stairs, both ramps
and the fountain-side aisle passed walk tests at speed 24. Reuse the existing Studio instance.

## R5: Pet Siege naming and architectural gate titles

User accepted **Pet Siege** as the mode name, with **SIEGE** as the large gate title.
The internal Merge place/key is unchanged. User rejected simple billboard-style labels
and approved paired architectural crests with sculpted lettering, contrasting materials,
and separately controllable lighting/ornaments. Blender and Meshy were authorized tools.

The first built pass uses Blender 5.1.2 to sample Georgia Bold outlines, then authors
extruded native CSG letter solids in Studio Edit. The sampled geometry is tracked in
`configs/realm_crossroads_glyphs.json`; no font binary is redistributed. This gives exact
spelling and editable native geometry without external asset uploads. Meshy was not needed
for this precise typography pass. Each letter, border, ornament and light remains separate.

- Farm & Fight: two-line bronze lettering in a pale stone field, gold border, halo and feathers.
- Siege: large warm-metal lettering in a dark field, ember border, horn silhouette and crown.
- Physical information panels: Grow / Hatch / Fight and Merge / Share / Defend, with relief
  icons and extruded captions. Zero title/relief GUIs.
- Crest mounting straps connect to the arch shoulders. Face key lights and crest lights use
  restrained six-second pulses and an approach boost; static geometry never animates or
  rebuilds at runtime. The engineering overlay is hidden for judging the arrival view.

`configs/realm_crossroads_crests.json` names the font geometry and Edit-only art companion
`tools/realm_crossroads/bake_crests.luau`. Blender generator:
`Blender --background --factory-startup --python tools/realm_crossroads/build_crest_glyphs.py`.
The seed preparer now embeds both bakers; require TerrainBake first, then CrestBake in Edit.
Do not run the seed preparer over an existing saved authored preview. Crests may be rebuilt
in the existing local preview; that replaces only `GateCrestR5` under each gate. Native
letter templates are cached in ServerStorage. Copy edits that introduce new letters require
regenerating the glyph config first.

Verified in Play: both gate paths pass at speed 24; new art has zero colliders; 50/40 native
solids in Farm & Fight/Siege; zero title GUIs; proximity light brightness changes; no console
errors. Full repo CI passes 2,842 headless tests and native crest baker passes Selene.
Saved in the same `RealmCrossroads-R4-Terrain.rbxl` local file, without opening another copy.
`output/realm_crossroads/Gate-Crests-R5.jpg` records the arrival view. This is the first
architectural art pass, not finished whole-island art or production routing integration.

Native serialization exports over 100 KB exceed the MCP response cap. Store export text
in temporary 50 KB StringValue chunks (a single StringValue caps at 200 KB), transfer all
chunks, join/decompress locally, then wrap the native payload with `save_native_terrain.luau`.
Remove the temporary export folder afterward; exclude it from its own serialization.

## R4: authored terrain and elevation walkthrough

The user requested assessing every elevation change before shaping the Roblox map.
`configs/realm_crossroads_terrain.json` owns the grading plan; its named
`tools/realm_crossroads/bake_terrain.luau` authors real Terrain once in **Edit**, only
in a local PlaceId=0 preview. No runtime geometry builder is installed.

| Area | Elevation | Transition |
| --- | --- | --- |
| Spawn, court, both gate landings | 0 | Level choice routes |
| Side gardens and Champions terrace | +4 | Vertical stone retaining faces; stairs and alternate ramps |
| Lower arrival overlook | -4 | Central stair and paired ramps |
| Planted outer/rear rim | +12 target | Landscape slopes around 1:2 to 1:2.5; not primary routes |
| Island underside | -24 | Steep voxel rock perimeter cliff |

Each stair rises/drops 4 across eight 0.5-stud risers with 2-stud treads. Each
alternate ramp runs 32, giving 1:8, and is 16 wide. Terrain supports raised
landings and the grades under stairs. Stone skins give precise risers and
vertical retaining faces where Roblox's 4-stud voxel reconstruction rounds edges.
The +12 planted rim is approximate; the rear marker raycasts near 11.6. Primary
terraces raycast exactly 0/+4/-4. A half-cell occupancy adjustment was necessary
to prevent Terrain from burying the paths 2 studs above the intended datum.

The saved preview uses the actual Merge bay arches at 30%, native SurfaceAppearance,
and 5-stud noncolliding inset faces. The demon mesh is natively upright: use identity
mesh rotation plus 180-degree facing yaw. The older source-placement matrix tilted it
sideways/down and was removed after visual verification in the gate. Spawn-to-gate distance remains 70.5 studs,
about 2.9 seconds at the configured Merge default speed of 24. Client-local
proximity tint demonstrates the 26-to-10-stud Heaven/Hell lighting transition.
Travel, dialogue, live leaderboards, and finished landscaping remain unimplemented.

Validation: direct Humanoid MoveTo tests at speed 24 passed both arch openings,
gallery stairs/ramp, garden stairs/ramp, and overlook stairs/ramp. Testing found a
center gallery column obstructing the stair entrance; columns now leave the
center approach open. These are representative routes with the current avatar,
not a claim that all avatar scales and every terrain edge are tested. Repo CI
passed 2,842 headless tests; native bake passed targeted Selene.

Artifacts under `output/realm_crossroads/`:
- `RealmCrossroads-R4-Terrain.rbxl`: saved native terrain/art in a standalone place.
- `Realm-Crossroads-Grading-R4.svg`: grading plan, transition key and stair/ramp section.
- `R4-Saved-Terrain.jpg`: saved-place overview.

Rebuild: `mise exec -- lune run tools/realm_crossroads/prepare_terrain.luau` creates
an **unbaked seed** (overwrites the local output, so preserve an existing baked file).
Open that seed once in Studio, then require `ServerStorage.CrossroadsTerrainBake`
in Edit. Save locally. The alternate native export flow serializes Terrain and
non-service art with SerializationService, wraps children in service-named folders,
then runs `save_native_terrain.luau` on `native-r4-export.rbxm`. This preserves the
native Terrain payload instead of approximating it with Parts. Saved-file reopening
verified terrain heights and speed. **Do not open a second copy of the same local
place to verify it:** duplicate Studio windows lock editing. Reuse the current
instance; the user explicitly flagged this workflow issue.

R1/R2 drawings below remain historical. R4 supersedes the R2 +12 Champions level
with a +4 usable terrace and reserves +12 for the planted rim.

## R3: existing Merge arches, inset faces, separated lighting

The user requested evaluating the large gates at the enemy-spawn end of each Merge bay,
plus the circular Farm & Fight return portals. They prefer reusing the larger detailed meshes,
scaled down, with the angel/demon **inside** the doorway to talk to or walk through. This replaces
the earlier face-above-gate arrangement. They also requested separated Heaven/Hell approach
lighting like Merge, while preserving short walks from spawn.

Read-only inspection in the active Merge **Server** datamodel on 2026-09-08 found:

| Family | Native mesh W × H × D | Evaluation |
| --- | --- | --- |
| Heaven bay arch | 99.5 × 94.0 × 40.0 | Preferred matched architectural pair; at 30% becomes 29.8 × 28.2 × 12.0 |
| Hell bay arch | 99.8 × 93.5 × 43.4 | At 30% becomes 29.9 × 28.1 × 13.0 |
| Celestial return ring | 23.6 × 24.0 × 22.1 | Usable fallback; raised base and deep platform |
| Infernal return ring | 34.7 × 34.9 × 32.0 | At 24 high becomes 23.8 wide × 22.0 deep; coordinated travel-station pair |

Exact source paths, mesh/SurfaceAppearance IDs, dimensions, and measurement caveats live in
`configs/realm_crossroads_gate_study.json`. Source captures are under
`docs/art/realm_crossroads/gate-study/`. `tools/realm_crossroads/draw_gate_study.py` generates
`output/pdf/Realm-Crossroads-Gate-Study-R3.pdf`: A-04 asset comparison, A-05 inset-face elevation,
and A-06 wider entrance spacing / lighting plan. The elevation is diagrammatic, not replacement art.

### Scale and fitting constraints

- Trial the bay arches at 25%, 30%, and 35%, with identical player references. The 30% example
  is a sizing proposal, not a completed scale test. A roughly 5-stud face centered at Y=6.5
  fits within the arch; keep it non-colliding and fit by visible bounds.
- Coarse full-depth raycasts of the current **Default collision**, in 1-stud horizontal /
  2-stud vertical samples, found native base openings around 18–20 studs, widening to about 32.
  At 30%, that is only **5.4–6 at the base**, widening to 9.6. R2's 10 × 12 clear opening is
  **not established for these meshes**. Test a real character at the smaller scale, including
  the base/stair lips, before accepting passage width or final landing height.
- Hell gate Model bounds include high lightning hooks and report ~414 studs of height;
  scale using the visible mesh, not that Model bound. Preserve SurfaceAppearance maps:
  all four inspected gate meshes have empty `TextureID`.
- Clone art only. Do not import Merge bay attributes, enemy spawn hooks, existing return
  prompts, or lightning marker towers into Crossroads. No existing Merge assets were edited.

### Revised placement and lighting proposal

Keep the 360 × 320 island proposal. Spawn remains X=0/Z=100; move gate centers to X=±40/Z=42
(**80 studs apart**) and turn each ~34.6° toward spawn. Direct spawn-to-center distance is
70.5 studs, about **2.9 seconds at Merge's default 24 studs/s**; the entrance threshold is
slightly closer. The user selected the Merge default speed for Crossroads on 2026-09-08.
Its source is `configs/places.lua` → `roles.merge.walk_speed`, consumed by
`PlaceRuntime.walkSpeedFor`; this excludes movement buffs. Use that configured speed for the
next walkthrough, even if the hub ultimately lives inside Farm & Fight. This is a hub-specific
design requirement, not authorization to increase all Farm & Fight movement speeds.
This supersedes R2's gate positions and the R3 study's earlier 16-stud/s / 4.4-second estimate.
R1/R2 historical drawings and the rejected preview remain unchanged.

Each gate gets a proposed 26-stud outer lighting radius, easing to full theme within 10 studs.
The circles leave a **28-stud neutral gap** along the line joining their centers. Spawn and the
gallery remain outside these regions. Heaven uses pale/gold light; Hell uses darker ambience
with ember highlights. Preserve floor, face, and sign readability. Final camera visibility and
walking times still need a Roblox pass; do not claim the wider layout is verified in Play.

`src/Client/Systems/RealmAtmosphere.lua` already owns client-local realm looks. In Merge it
selects spatial zones with hysteresis and tweens numeric lighting; elsewhere it follows
`CurrentLayer`. Extend that ownership when implementing hub proximity later, rather than
adding a competing lighting controller. Restore the neutral/base look on leaving a gate zone;
handle sky swaps deliberately instead of assuming sky textures blend like numeric properties.

Interaction proposal: a Talk / Enter prompt plus optional threshold crossing; no required
dialogue and no teleport merely for standing nearby. Face recedes/fades as the player enters.
These remain design proposals, with no new production routing or lighting implemented.

## R2 takes precedence over the first blockout

The user walked/reviewed the initial scale and found the **doorways too large and the island
too small**. Stop adjusting the existing Roblox build by eye. Develop and review dimensioned
architecture before the next bake. The concept's composition remains approved; R2's numeric
dimensions are proposed, not yet approved or implemented in Roblox.

`configs/realm_crossroads_design.json` records R2 dimensions separately from the superseded
`realm_crossroads.json` first-bake parameters. `tools/realm_crossroads/draw_architecture.py`
produces three landscape architectural sheets in `output/pdf/Realm-Crossroads-Architecture-R2.pdf`:

- **A-01 site plan:** 360 × 320 island; 290 × 270 walkable terrace. Spawn X=0/Z=100;
  gate centers X=±26/Z=54, angled 29.5° toward spawn. Each gate is approximately 53 studs
  from spawn, or 3.3 seconds at the 16-stud/second reference speed.
- **A-02 elevation and passage section:** 10 × 12 clear openings; structure 18 wide,
  18 high, 6 deep; avatar envelope 9 high, starting at Y=19. Total height 28. Reference
  player height 5.5; actual Roblox avatar sizes vary. Match visible mesh bounds, not pivots.
- **A-03 longitudinal section and iteration contract:** court Y=0; side gardens +4 via
  32-stud ramps at maximum 1:8; rear terrace +12; cliff base -16. Low central landmark
  20 diameter / 12 high. Gallery 120 × 28 × 22, front Z=-88; target walking route 12–15 sec.

The approved generated concept is retained at `docs/art/realm_crossroads/approved-concept.png`.
It is an aesthetic reference, not a source for exact dimensions or the real avatar mesh identity.
Render the PDF and inspect all three sheets after drawing changes. The drawing script requires
Python with ReportLab. Its detailed drafted geometry is part of the design source; update the
drawings and dimension registry together when a dimension changes.

### Instructions for the next Roblox revision

1. Ground/camera pass: only terrain footprint, paths, spawn, doorway placeholders, and 5.5-stud
   player references. Confirm both entrances fit a default third-person arrival view.
2. Architectural pass: follow A-02. Keep the complete 10 × 12 clear opening, level thresholds,
   readable mode labels, 18-stud clear routes, and matched avatar/gateway envelopes.
3. Landscape/art pass: add terraces, art meshes, planting, and water outside the arrival
   sightline. Keep four podium alcoves, each ordered 2 / 1 / 3. Measure walking times.
4. Compare the same three cameras after every revision: arrival eye level, overhead plan,
   and gallery looking toward spawn. Change one dimension family at a time; save revisions
   separately. Obtain the user's scale feedback before production spawn/travel integration.

Do not claim R2 is walk-tested based on the first build. R2 remains a paper proposal.

## Approved direction

A neutral arrival courtyard inside Farm & Fight lets players choose Farm & Fight, Merge,
or future modes. Voxel terrain and mesh landmarks follow Merge's art direction. An angel
and demon sit over equally prominent mode entrances. The optional rear champions arcade
contains ranked 2 / 1 / 3 podiums. Side gardens reserve future mode entrances.

The initial concept was approved in conversation. Footprint and walking distances remain
subject to the user's Roblox walkthrough. First pass: 240 × 220 studs, 20-stud paths,
18-stud gateway openings, roughly 65 studs from spawn to each gateway center. Gallery
is approximately 160 studs beyond spawn, with paths around the central landmark.

## Superseded first local preview (R1)

Run from repository root:

```sh
mise exec -- lune run tools/realm_crossroads/build.luau
```

Outputs (local, reproducible; not deployed):

- `output/realm_crossroads/RealmCrossroads-Preview.rbxl`: standalone place, default avatar
  controls at 16 studs/second, enabled spawn, and Return to spawn button.
- `output/realm_crossroads/RealmCrossroads.rbxm`: authored map model with its preview spawn
  disabled. No runtime scripts, active game tags, or automatic travel are in this model.

`configs/realm_crossroads.json` owns layout parameters, palette, gate labels, and the exact
angel/demon mesh references inspected in Merge Edit. Those are the existing Watcher face
meshes, not the full-body stand-ins depicted by the generated concept image. Preview figures
on the podiums are placeholders; ranking categories and periods are deliberately unassigned.

The baker only creates local files. It does not overwrite a live Studio map, Terrain, game
spawn, profile, or place setting. Geometry is baked once for Studio editing, not built at
runtime. Import as a separate Model; choose the final Farm & Fight location and wire the
spawn and travel contracts after the scale walkthrough. Do not enable the preview spawn
in the production game without reconciling Homeworld's forced spawn and tutorial rules.

## Next decisions

- Walkthrough feedback on footprint, gateway proportions, and gallery distance.
- Final Farm & Fight placement and terrain/mesh art pass.
- Ranking categories and periods; real avatar displays.
- Production spawn, tutorial entry, return routing, and future mode registry.

See [Hall of Worlds](HALL_OF_WORLDS.md), [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md),
and [Studio Workflow](STUDIO_WORKFLOW.md).

Existing Bragg decor is cached in ServerStorage.CrossroadsExistingDecor, preserving the Merge mesh/textures. Model IDs, scaled heights, placements and yaw live in the Bragg config; the Edit baker loads catalog models only if the template cache is missing. All decorative mesh collisions are disabled.

## Standalone Confluence fountain candidate (2026-09-08)

A separate agent completed the user-requested ImageGen → Meshy → Blender → Assets → Roblox
pipeline for a circular Heaven/Hell fountain. It remains outside the map for review.
`configs/confluence_fountain.json` owns the contract and IDs; `assets/place/Confluence.rbxm`
is the 22-stud diameter, 7.8-stud height native assembly with 24 textured MeshParts and nine
scrolling fluid Beams. The group-owned raw geometry Model is recorded in config. Raw FBX
import reverses the horizontal orientation; the native companion corrects Heaven to negative X
and Hell to positive X. Source, provenance, checks and placement limitations are documented in
`assets/source/props/confluence/README.md`. The shared Models/MissionProps libraries and
all open maps were left unchanged. Production placement and visual effect review are pending.

The Confluence is now placed in the existing isolated Bragg map at (0,4.44,-88),
seated on the actual court surface. Prior fountain is retained under ServerStorage.FountainBeforeConfluence.
Both side routes passed at speed 24; native nine Beam effects are enabled for in-map review.

Confluence pool tops now use 383 conservative rectangular masks sampled from the original
Blender pool meshes. Original pool meshes are hidden; colored noncolliding surfaces carry
tiled textures. StarterPlayerScripts.ConfluenceSurfaceFlow scrolls them locally at 15 Hz
within 100 studs (water U=.25, lava U=.075 studs/sec, config-owned). Both rates were measured
in Play. No stone/metal geometry or production gameplay is animated. Copy the client companion
when integrating the native fountain into Farm & Fight; a standalone model alone does not run it.

Paving junctions now receive an Edit-time CSG trim after all art/theme bakes. Config
`realm_crossroads_paving.json` names the selected floor patches and footprint priority;
`trim_paving.luau` subtracts higher-priority footprints through lower-priority slabs.
Twelve overlapping pieces were cut in the current preview, including arrival/gate branches
and garden links. Original slabs are backed up in ServerStorage.CrossroadsPavingBeforeTrim.
Rebuild floor geometry before rerunning this finishing pass. Do not solve floor intersections
by stacking nearly coplanar faces; adjacent materials need cleaved, non-overlapping boundaries.

## Spectator stands and fishing pond (2026-09-08)

`configs/realm_crossroads_leisure.json` and its Edit baker extend the side lobes to
X±228 (safety boundary ±224), locally around the activity gardens. East has four
ascending rows of eight native Seats, a central stair aisle and rear/end rails.
Twenty-four static seated copies of podium height references preview the audience;
eight aisle-side seats remain enabled for visitors. These are dummies, not rankings.
West has a 48×80 oval Terrain-water pond with a walkable bank and two wooden fishing
platforms. Existing flora was moved to the new outer edge; 16 invisible wall segments
replace the old footprint boundary. Terrain backups remain in ServerStorage.

Fishing is layout only: fish and rods need assets; land-shark code reuse needs review.
Possible catches/rewards are Enhancements, potions and eggs, with economy unspecified.
No fishing or automatic podium-audience gameplay has been added.

The arrival path now continues from Z6 through Z120 to the rear stair landing. The
visible raised spawn pad is removed (spawn remains enabled but invisible/noncolliding).
`finish_arrival.luau` prepares the continuous footprint before the paving trim, then
replaces the center with individual stone pavers and separate edge strips. Its returned
finish function must run after trim. Floor intersections share a common surface height.

After paving trim, run the configured `side_junction.bake_source` finishing repair.
The garden-ramp links reach inward to |X|16; their former |X|20 endpoints missed the
outside diagonal edge at Z88, leaving small mirrored notches. The repair subtracts
the existing diagonal solid, preserving a clean shared boundary with no stacked faces.

## Fishing capacity revision (R10, 2026-09-08)

`configs/realm_crossroads_fishing.json` and `bake_fishing.luau` supersede the small R9
pond after the leisure pass. Heaven is now 88×112 studs with ten 10×12 platforms
around the bank. Hell has a 56×96 pool behind the stands with eight platforms.
Both use real Terrain water. Water color is global to the place and is left unchanged;
the Hell setting comes from the surrounding landscape. Catches are not wired. Existing flower/quartz and
bone/brush assets decorate spaces between stations. Perimeter flora is relocated,
with matched side land extensions reaching |X|300 and invisible walls at |X|296.
Terrain and old pond/boundary backups are preserved in ServerStorage. Fishing assets,
rod interaction, catch tables and rewards remain future gameplay work.

Hell water now has a local green mist layer: `hell_mist` in the fishing config and
`bake_pool_mist.luau` author 20 noncolliding sources across the ellipse. Native particle
emitters animate without a gameplay script. Reviewed at the fishing bank in Play;
water reflections and fishing platforms remain visible. Run this after the fishing bake.

## Premium design review (2026-09-08)

[Eight-section design package](../art/crossroads-review/README.md) retains 37 screenshots,
independent section reviews and a coordinated implementation plan. Each area receives 20
specific improvements, phased build steps, asset briefs and acceptance criteria. This is
planning evidence, not implemented geometry. The screenshot atlas preserves the current
preview before the proposed art pass; distant overview omissions are documented.

The user explicitly supports modest new FX built in `~/Documents/RBX-FX-GEN` when useful.
Its current crystal-only scope is not a creative ceiling. The package identifies narrow
ambient/ripple/burst extensions and separates them from larger editor/platform investments.

## Premium construction checkpoint (R11, 2026-09-08)

The review now has a native first construction pass: 300 fitted approach pavers,
36 arrival plants, rear sculpted gate titles, Bragg masonry/24 figure fixes, a
fitted two-realm arrival inlay, a supported garden arch pavilion with four Seats,
32 crafted stand chairs, recessed rear masonry, and 18 detailed fishing docks.
Two source-first Blender rods are uploaded and mounted, with actual tip anchors.
The retained map remains a local PlaceId0 preview; production content is unchanged.

`configs/realm_crossroads_polish.json` lists seventeen authoring passes in application
order. The native exporter refreshes their embedded modules/configs from disk,
without rebaking serialized CSG/terrain. Apply core before heraldry and fishing
polish before rod placement/interaction setup. Source and uploaded rod provenance
are named by `configs/realm_crossroads_fishing_rods.json`.

The standalone RBX-FX-GEN ambient extension is locally committed at `503334d`; a
config-named bundle is vendored into this preview. It replaces the old Hell mist
with one client-owned field at the approved 20×4/s density, adds restrained gate
embers, and supports distance/quality/reduced-motion lifecycle controls. Native
full/off/stop/restart/destroy checks passed. Screenshot capture does not reliably
show the particle cloud, so property checks are not a new visual approval.

A Studio-only local cast/reel rehearsal uses the 18 station attachments and leaves
no catches or rewards. Cast height is sampled from actual Terrain water (currently
Y0), correcting the older nominal Y2 assumption. Leaving the station/respawning
cleans the bobber and line. Gates and the weekly egg remain disabled authored stubs.

[Implementation status](../art/crossroads-review/IMPLEMENTATION_STATUS.md) records
completed craft and remaining art/device QA. [Gameplay integration contract](../art/crossroads-review/GAMEPLAY_INTEGRATION.md)
details server authority, fishing reservations/settlement, authored podium binding,
wave-clear versus reached metrics, global boss deduplication and future cutover.
Do not enable production podium tags directly: the existing AwardPodium renderer
would generate duplicate geometry unless adapted to these authored anchors.

The ambient bundle also includes the small pooled ripple extension (`bcd1619`):
a cast emits one 32-segment Beam ring, expanding/fading above sampled water,
with no texture plane. The two-ring pool and reduced/off/reduced-motion cleanup
passed native smoke checks; the integrated cast and water contact were viewed.

The R11 lossless native checkpoint is retained under
`assets/source/maps/realm_crossroads/RealmCrossroads-R11.rbxl`, named by the polish
registry and deliberately absent from production Rojo mappings. It retains Terrain, cached source assets, authoring modules and cosmetic scripts.
The latest additions are saved in the native checkpoint; round-trip verifies17,593instances,18rods,18stations and16enabled visitorSeats.
The dry-bank route finish changes only SolidMaterial, verifies both occupancies
unchanged, and widens the Heaven dock-wall passage to12.3studs without reducing
the64-stud coin field. Both bank passages passed native navigation.

The latest native additions include a22×14 bowed timber fishing shelter with four
genuine Seats, two inert dry pet/display bays, two small bushes and three cached
backdrop trees. Its roof tops atY14.2; the18-cell material spur changes neither
terrain occupancy channel. Lead verified RestSeat_1_1 Humanoid sit and exit in Play.
Both pond approaches now have physical sculpted FISHING signs. The version2
textured fossil is placed using `configs/crossroads_fossil.json`; eight Bragg
category emblems are installed; the corrected wave medal orientation passed a native close view. Remaining
whole-map/device QA and the east-annulus collision-query ambiguity are retained
in the linked status/audit. Pet bays perform no automatic pet placement.

The follow-up arena floor pass replaces only the measured64×102Playfield with
fitted stone and a cut crest, preserving top4.38 and a hidden authoring-bounds proxy.
The fossil setting adds12cached grounded meshes; pier posts now extend into sampled
solid bed while preserving their tops. Temporary sightline fixtures are isolated in
`arena_sightline_qa.luau` and excluded from the saved authoring registry. Native Seat
smoke tests cover all8visitor slots; rendered target visibility is a separate check.

A native route sweep reached 49 recorded endpoints at speed 24, including the
larger fountain walking loop and both fishing connectors. All 37 bulwarks now
have stable config-owned side/segment IDs for future containment binding; this
adds no gameplay. The outer 12-wall collision loop passed 1,080 radial samples
at three heights, with no sampled gap. See ROUTE_QA.md, BOUNDARY_QA.md and
INTERACTION_STUB_AUDIT.md under the section-review directory for evidence and limits.

Original pearl/gold pond fish are retained through ImageGen→Meshy→Blender source,
with a two-bone skin and native texture verification. `realm_crossroads_pond_life.json`
owns the shallow paths, local tail/surfacing motion and quality controls. The companion
reuses RBX-FX-GEN WaterRipple; visual FX must be installed before pond life. Both ponds
passed appearance and lifecycle checks without water changes. All18station approaches
and eight social Seats also passed sequential native checks. Decorative fish are not
catch targets; future catches remain server-authorized integration work.

The completion audit and dimensioned as-built drawing now live in the review
folder. All 18 standard-body fishing proxies fit simultaneously; both rear-bank
loops remained navigable. These noncolliding fixtures establish layout clearance,
not multiplayer load or server reservation correctness. The 17 finishing passes
also replayed twice on the existing authored preview. Retained landscape grounding
uses a fixed world-height ray to prevent small cumulative vertical shifts on rerun.
A replay still requires the original native geometry and cached assets; it is not
an empty-place build. See REBUILD_QA.md for inputs and verification limits.

Checkpoint saving now archives the ordered registry and supplementary glyph,
FX-bundle and client sources in inert `ServerStorage.CrossroadsAuthoringInputs`
StringValues. This does not rerun installers or refresh installed runtime code.
`tools/realm_crossroads/validate_checkpoint.luau` compares both source archives and
installed runtime sources/configs, native caches and accepted paving count, and
rejects temporary whole-world QA backups. Use explicit input/output paths from
`tools/realm_crossroads/CHECKPOINT_WORKFLOW.md`; the legacy wrapper defaults still
name R4. Five deliberately broken checkpoint fixtures verify stale/missing input
rejection without altering the saved map.

The alternate spectator access is now built: two 8-stud-clear, 1:8 flights reach
existing tier Y12 from ground Y4, with a 7.5-stud-clear underpass. It is pass 18,
after arena polish; two interfering native flora and two end rails are retained
in its dedicated original archive. All 32 Seats and the 12-stud pond passage stay
in place. Direct up/down/underpass movement passed without sampled jumping,
falling or swimming. The latest 17,695-instance save passes source/runtime/cache
validation; its hash and precise limits are in IMPLEMENTATION_STATUS.md.
