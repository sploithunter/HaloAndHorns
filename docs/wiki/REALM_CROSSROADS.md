# Realm Crossroads

Status: first blockout scale rejected; R2 architectural proposal for review (2026-09-08).

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
