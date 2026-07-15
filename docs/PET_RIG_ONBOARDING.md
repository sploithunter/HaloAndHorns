# Pet Rig Onboarding — the reproducible runbook

Turning a Meshy rig zip into a live animated pet. Everything scripted is in
`scripts/onboard_pet_rig.sh`; this doc is the full picture plus the manual
tail and every gotcha we paid for. Two live references: Cinderling Imp
(biped, 2026-07-15) and Camel (quadruped, 2026-07-15) — both GLB zips.

## The one-command front half

```sh
scripts/onboard_pet_rig.sh <pet_id> ~/Downloads/Meshy_AI_<Name>_biped.zip
```

Does: GLB→FBX conversion when needed (`scripts/blender/rig_glb_to_fbx.py`,
textures EMBEDDED so the rig upload arrives pre-textured), rig upload
(group Model asset), every `*_Animation_*_withSkin.*` clip through
`scripts/import_animation.sh` (anim2rbx → 180°-Y pose fix → group Animation
asset, ids into `scripts/animation_ids.json`), and the
`scripts/pet_rig_manifest.json` entry.

`<pet_id>` must be the EXACT `configs/pets.lua` key (e.g. `camel`, not
`blue_eyed_baby_camel`). Meshy names ≠ pet ids; when unsure check the zip's
texture against `assets/exports/pets/<pet_id>_basic/` (that is what
`scripts/identify_pet_zip.py` fingerprints, FBX zips only).

## The manual tail

4. **configs/pets.lua** — on the pet: `rig_class = "biped" | "quadruped"`
   plus a provenance comment (rig asset id, zip, date). The static
   `mesh_asset`/`texture_asset` fields STAY — they are the golden/rainbow
   look and the fallback rebuild.
5. **configs/animations.lua** — add the new walk to the class `walk` pool
   (squads vary gaits via the seeded per-pet pick). If a pool clip
   misbehaves on this pet (see gotchas), pin a substitute in
   `clip_overrides.<pet_id>`.
6. **scripts/studio/rebuild_rigged_prebakes.luau** — add
   `<pet_id> = { rig = <asset>, height = <static bbox Y> }`. Measure the
   static prebake first:
   `ReplicatedStorage.Assets.Models.Pets.<pet_id>.basic:GetBoundingBox()`.
7. **Install the prebake** (Studio EDIT mode, via MCP or command bar): run
   the rebuild script — or just its loop body for the one pet. It inserts
   the rig asset, ensures AnimationController+Animator, normalizes pivot →
   scales to the static height → recenters pivot at bbox CENTER (frac 0.50
   — the convention PetFollowController's pivot-to-feet measure expects).
8. **Play-verify**: the equipped pet spawns with bones + `RigClass`
   stamped; the walk track fires while it moves. A standing QUADRUPED
   playing nothing is correct — that class has no idle clip yet.
9. **CAPTURE, SAME SESSION**: Play until fully booted → right-click
   `ReplicatedStorage.Assets.Models` in the RUNNING game → Save to File →
   `assets/place/Models.rbxm` → commit. Skipping this re-arms the Rojo
   time bomb: the next Rojo reconnect serves the stale file and silently
   strips every rig not in it (docs/ASSET_PREBAKE.md).

## Gotchas (each one cost a debugging session)

- **GLB rig units are chaos.** The imp arrived ~2× oversize, the camel
  MICROSCOPIC (ScaleTo ×654). Never trust the authored size — always scale
  to the static prebake's bbox height.
- **`GetBoundingBox()` is PIVOT-aligned.** Some rigs (imp) arrive with a
  rotated `char1` CFrame, so "bbox.Y" isn't world-vertical until you
  normalize the pivot to world-identity FIRST. The rebuild script does
  this; hand-rolled snippets must too.
- **Rigs insert upright, front on the pivot look axis.** No rotation
  needed. (The 2026-07-14 lying-down golemite was a hand-drop mishap, not
  an asset property.)
- **Embed textures in every FBX** (`rig_glb_to_fbx.py` does). A bare FBX
  upload arrives grey and needs a TextureID patch — and for STATIC
  (non-rigged) meshes a bare upload can kaleidoscope entirely
  (docs/ROBLOX_MESH_TEXTURE_KALEIDOSCOPE.md).
- **`add_leaf_bones=False` in any FBX export.** Extra `_end` leaf bones
  change the skeleton and break the shared-clip-per-class contract
  (identical bone names across all Meshy rigs of a class).
- **Clip 180°-Y mirror**: anim2rbx output poses come out mirrored;
  `import_animation.sh` runs `fix_anim_axes.luau` automatically — never
  upload a clip that skipped it.
- **Idle clips can carry root motion.** MeshyStretchIdle lifts the model
  ("flying up" imp). Fix = `clip_overrides.<pet_id>.idle` in
  configs/animations.lua, or ban the clip from the pool.
- **Variants**: golden/rainbow stay static (code gait) unless separately
  minted — same-generation textures map onto the rig mesh only when the
  Meshy source is identical.

## Clip library status / wishlist

Banked (scripts/animation_ids.json): biped idle ×2 (stretch, lazy), walks
×4, run ×3, jumps, punches, casts; quadruped walks ×4 and NOTHING else.
Wanted from Meshy's animation library (one download serves the whole
class): more biped rests (sit, look-around, yawn…), any quadruped idle at
all, quadruped run/attack.
