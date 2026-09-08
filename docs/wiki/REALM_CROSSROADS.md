# Realm Crossroads

Status: walkable blockout proposal, not a live spawn/routing change (2026-09-08).

## Approved direction

A neutral arrival courtyard inside Farm & Fight lets players choose Farm & Fight, Merge,
or future modes. Voxel terrain and mesh landmarks follow Merge's art direction. An angel
and demon sit over equally prominent mode entrances. The optional rear champions arcade
contains ranked 2 / 1 / 3 podiums. Side gardens reserve future mode entrances.

The initial concept was approved in conversation. Footprint and walking distances remain
subject to the user's Roblox walkthrough. First pass: 240 × 220 studs, 20-stud paths,
18-stud gateway openings, roughly 65 studs from spawn to each gateway center. Gallery
is approximately 160 studs beyond spawn, with paths around the central landmark.

## Local preview

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
