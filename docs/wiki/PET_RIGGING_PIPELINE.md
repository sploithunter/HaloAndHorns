# Pet Rigging Pipeline — Canonical Quadruped Skeleton

**Status (2026-08-14):** WORKING, verified on doggy, bear, kitty — all three play the identical
attack clip with zero manual weight painting. Pending: Roblox FBX import verification, marketplace
animation-pack retarget, sitting-pose pets (bunny, aurora dragon).

Doggy's replacement is a deployment-only geometry override: every deployed Doggy variant clones
the unified `basic` rig, then applies the pet's saved golden/rainbow treatment. Inventory cards keep
using their existing flat images, and the independent static variant templates remain intact. Do
not replace every variant template with the rig; that couples unrelated catalog and runtime paths.

## Why

Meshy auto-rigs each pet with its own skeleton, and its quadruped animation library is
walk-cycles only. Attack/combat animations would need authoring per pet per rig. Instead, every
quadruped is skinned to **one canonical skeleton** (identical bone names, hierarchy, and rest
stance), so any clip — hand-keyed or retargeted from a purchased pack — plays on every current and
future quadruped. Roblox animations store per-joint rotations relative to rest pose, so bone
*lengths* may differ per pet (chibi vs lanky) as long as names/hierarchy/rest stance match: this is
the same mechanism that lets R15 bodies share animations.

## Canonical skeleton (19 bones)

```
Root ─ Spine1 ─ Chest ─ Neck ─ Head
  │                └─ UpperLeg_FL/FR ─ LowerLeg_* ─ Foot_*
  ├─ Tail1 ─ Tail2
  └─ UpperLeg_HL/HR ─ LowerLeg_* ─ Foot_*
```

Optional chains (tail, ears) exist on every rig; pets without the geometry simply get no weights
there and clips animate the bones harmlessly. Winged quadrupeds (dragons) will be a separate class
with a superset skeleton.

## Pipeline (one command per pet)

```
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/rigging/rig_pet.py -- <pet_name> assets/source/pets/<pet>_basic.glb
```

Stages, each automated ([tools/rigging/rig_pet.py](../../tools/rigging/rig_pet.py)):

1. **Import + weld.** Meshy GLBs are polygon soup (doggy: 4,775 loose shells, 14.5k verts →
   welded to 2.5k). `remove_doubles` first — heat weighting needs connectivity. UVs survive.
2. **Facing detection.** The head end has far more mesh mass than the tail end; if the head is at
   +Y the mesh is rotated 180° so all rigs face −Y.
3. **Landmark fit.** Leg columns found by clustering the lower 30% of verts into x/y quadrants;
   spine height, head centroid, and tail tip measured from the mesh; the canonical armature's bones
   are scaled/positioned to those landmarks.
4. **Auto-skin** (`ARMATURE_AUTO` bone-heat weights).
5. **Orphan rescue.** Detached shells (inner ears, claws, collars) get zero heat weights; each
   orphan copies weights from its nearest weighted vertex.
6. **Skull cleanup.** Chibi heads are huge; a badly-fit head bone lets torso bones win the skull.
   The Head bone is aimed through the skull centroid (raised toward the top of the head mass), and
   any skull-region vert still dominated by a torso bone is rebound to Head, preserving the Neck
   blend. (This was the "kitty ears don't follow the head shake" bug.)
7. **Shared clip + preview render.** [tools/rigging/anim_clip.py](../../tools/rigging/anim_clip.py)
   keys the reference attack clip (idle → crouch → pounce → paw swipes → bite shake → wag) with
   root motion scaled to body height; EEVEE renders frames (this Blender build has no FFMPEG —
   encode with `ffmpeg -framerate 24 -i f_%04d.png`).
8. **FBX export** (rest pose, textures embedded) for Roblox import.

Outputs land in the gitignored scratch area `assets/model_test/rig_experiments/`
(`<pet>_rigged.blend`, `<pet>_canonical_rig.fbx`, preview MP4s) — regenerable, not committed.

## Verification discipline

Pose checks are **measured, not eyeballed**: dominant-bone counts per region and evaluated-depsgraph
vertex displacement (e.g. kitty ear tip must travel ~0.4 units during the head-shake segment).
A rest-pose render can look "fine" while weights are wrong.

## The clip converter (2026-08-13, replaces anim2rbx for new clips)

Blender-5.1 FBX exports broke the July anim2rbx+180°Y lane: clips played with scrambled
per-bone motion axes (gait phases fine, vertical amplitude ~6×; diagnosed by tracing foot
positions against a Blender ground-truth render — never eyeball-debug this class of bug).
Replacement: **direct KeyframeSequence export**, no FBX/anim2rbx in the clip path:

1. [tools/rigging/export_pose_deltas.py](../../tools/rigging/export_pose_deltas.py) /
   [mint_clips_direct.py](../../tools/rigging/mint_clips_direct.py) (Blender) — dump per-frame
   bone-local pose deltas; the mint variant first world-delta-retargets a Quaternius clip onto
   the Meshy rig (`SRC_FBX` + `CLIP_SPEC` env vars select source/clips).
2. [tools/rigging/convert_deltas.py](../../tools/rigging/convert_deltas.py) — the verified
   formula: world-space rotation deltas, conjugated by `Ry(180)·Rx(-90)`, vertical-axis
   component negated, applied onto the Roblox rig's rest world frames, **rotations only**
   (engine multiplies Pose translations by the rig's ScaleTo factor — a 632×-scaled prebake
   turned half-stud offsets into a map-sized dog). Requires the rig's bone rest dumps
   (blender_rests / roblox_rests JSONs, one pair per rig class).
   **Two lanes, two signs**: Meshy-authored clips (walk) use the base formula; Quaternius-
   retargeted clips additionally need the pitch axis negated (`invpitch` arg) — live-verified
   both ways, cause of the sign split not fully explained, the in-game lineup is the oracle.
3. [tools/rigging/build_keyframes.luau](../../tools/rigging/build_keyframes.luau) (lune) —
   poses JSON → KeyframeSequence rbxm → `scripts/upload_animations.js`.

Wired set (all live-verified in a 7-dog lineup): idle ×2, walk (doggy-pinned), gallop,
attack, hit-reacts banked; class defaults are wolf-sourced, doggy overrides use ShibaInu
dog-flavored attack/gallop. Flavor plan: the 12 Quaternius animals share one skeleton, so
per-species sets (horse for hooved, headbutt/kick for stag/goat/camel — stag headbutt already
banked) are one `CLIP_SPEC` run each, assigned via `clip_overrides`.

## Gotchas learned

- **Meshy origin is the mesh center, not the feet** (feet ≈ −H/2). Ground planes, and eventually
  the Roblox import, must offset by measured foot height.
- **Blender 5.x appended Actions bind but never evaluate** (slotted-actions quirk): an Action
  appended from another .blend shows an assigned slot yet deforms nothing. Share clips as keyframe
  *code* in Blender; real sharing in Roblox happens via clips published once per skeleton.
- **Chibi proportions break naive head fitting** — see stage 6.
- **Sitting-pose meshes** (bunny, aurora dragon) defeat standing-quadruped landmark fitting AND
  third-party auto-riggers equally; they need regenerated standing meshes or their own class.

## Animation sources

- **VALIDATED (2026-08-13): pack retargeting works.** The Quaternius
  [Ultimate Animated Animal Pack](https://quaternius.com/packs/ultimateanimatedanimals.html)
  (CC0, 12 quadrupeds × 12+ clips incl. Attack / Death / HitReact L+R / Gallop / Walk / Idles) was
  retargeted onto the canonical rig with
  [tools/rigging/retarget_clip.py](../../tools/rigging/retarget_clip.py): map the pack's bones to
  canonical bones (chains compressed, e.g. Torso2/3→Spine1/Chest, 8 tail bones→2), copy
  rest-relative local rotations (`matrix_basis`) per frame plus height-scaled Body root motion.
  The Wolf's Attack, Gallop, and HitReact play cleanly on the auto-skinned Meshy doggy with no
  axis corrections. Usage:
  `blender --background --python tools/rigging/retarget_clip.py -- <pet>.blend <pack>.fbx <ClipName> <out>`
- The same machinery applies to paid Unity Asset Store packs (e.g. Dogs Big Pack, 74 clips) —
  `.unitypackage` files are tar.gz archives, so FBX extraction needs no Unity install. One bone-map
  dict per pack vendor.
- Sitters use the same bone names via the sitter-variant fit
  ([tools/rigging/rig_bunny.py](../../tools/rigging/rig_bunny.py)) but want their own clip set —
  quadruped paw swipes read as face-blocking "bunny boxing" from a sitting rest pose.
- Anything World ($50/mo, 300 credits; 5/rig + 5/animate) remains an untested comparison for
  rig quality and library breadth — free-tier credits reserved (site was down 2026-08-13; the
  upload-ready dragon GLB sits in the scratch area).

## Planned: vision-annotated landmark stage

Landmark heuristics are the pipeline's weak point (kitty head bone, bunny neck — both were
landmark failures). Next architecture: render calibrated orthographic side+front views, have a
vision model place labeled joint markers (Meshy-marker style: chin/shoulders/waist/buttocks/tail/
forearm/hand/shin/foot) as pixel-coordinate JSON, unproject to 3D (side=(y,z), front=(x,z)), and
build the skeleton pose-agnostically. Annotator is pluggable — Claude in-session, or a cheap batch
model (e.g. Grok) for ~100-model runs; the marker JSON schema is the contract, and measured
verification (dominant-bone regions, vertex displacement) stays as the referee.

## Roblox integration (next step)

Import `<pet>_canonical_rig.fbx` via the Studio rig importer, upload group-owned (`--creator-group`,
see [Group asset uploads](../../docs/wiki/STUDIO_WORKFLOW.md)), publish the clip set once against
the canonical bone names, and confirm the same published clips play on doggy/bear/kitty rigs.
