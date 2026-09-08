# Realm Crossroads

Status: first blockout scale rejected; R3 existing-gate and local-lighting study for review (2026-09-08).

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
