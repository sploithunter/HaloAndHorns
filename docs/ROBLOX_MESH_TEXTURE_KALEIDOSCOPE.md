# Roblox mesh looks "shattered" / kaleidoscope after upload — root cause and fix

If your mesh uploads to Roblox looking like broken glass, camouflage, or a
kaleidoscope — but ONLY when textured — this document is for you. We chased
this for weeks across dozens of props and misdiagnosed it three different
ways before pinning it. Published in the open because the failure mode is
nearly invisible to diagnose from the outside.

## Symptoms

- The textured mesh renders as jagged triangular smears ("shattered glass",
  "camo garbage") in game and in Studio.
- The SAME asset's grey preview on create.roblox.com looks **perfect**.
- Remove the TextureID in Studio: the geometry is **pristine**.
- Your local Blender/Maya render of the exact mesh + texture is **correct**.
- Importing the exact same FBX through Studio's **3D Import** renders
  **correctly**, textures and all.
- Re-uploading the identical FBX through Open Cloud sometimes "fixes" it,
  sometimes doesn't (looks like nondeterministic processing "roulette").

## Root cause

**Roblox Open Cloud's FBX converter keeps only ONE UV per position-vertex.**

FBX stores UVs per face-corner (per loop). A vertex that sits on a UV island
border legitimately carries different UVs for different faces. Studio's 3D
Import honors that. The Open Cloud asset upload path (`assetType: Model`,
`model/fbx`) does not — it collapses per-corner UVs to a single UV per
vertex.

If your mesh has **welded vertices along UV seams** (e.g. Blender's
`remove_doubles` / Merge by Distance, done for decimation quality), every
seam vertex is shared between islands. The collapse assigns it one island's
UV; triangles from the other island now stretch across the atlas. Result:
kaleidoscope. Geometry is untouched, which is why every untextured view
looks fine.

Why it looks random ("roulette"): which UV survives the collapse depends on
mesh internals, so some uploads of the same object smear less visibly than
others. It was never random — it was always the seams.

Why most assets never break: Meshy (and most AI mesh generators, and most
game-ready exports) ship with seam vertices **pre-split** — position
duplicated, one UV each. The collapse is a no-op on those. You only get bit
when YOUR pipeline welds the mesh and then uploads via Open Cloud.

## The fix (Blender)

After all geometry work (weld, decimate, UV project, bake), **re-split the
mesh along UV island borders** so every seam vertex is again unique, then
export:

```python
# mark seams from UV islands, then split those edges
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.seams_from_islands(mark_seams=True, mark_sharp=False)
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for e in obj.data.edges:
    e.select = e.use_seam
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.edge_split(type="EDGE")
bpy.ops.object.mode_set(mode="OBJECT")
```

Also **embed the texture in the FBX** (`embed_textures=True,
path_mode="COPY"`): the uploaded Model then arrives with TextureID already
set to a freshly minted image — no separate texture upload, no
Decal-vs-Image id confusion, no risk of pairing a texture with a mesh whose
UVs it wasn't baked for.

Working reference implementation: `scripts/blender/rebake_for_roblox.py`
(`split_uv_seams()`), driver `scripts/rebake_mission_decor.sh`.

## A/B proof

Identical mesh and atlas, uploaded twice on 2026-07-14:

| upload | seam verts | result |
|---|---|---|
| 133639172611896 | welded | kaleidoscope |
| 83409245331595 | split | correct |

## UPDATE (next day): the seam-split fix is NOT enough — delayed re-encode rot

One day after publishing the fix above, the seam-split uploads rotted
ANYWAY. Timeline, same asset ids throughout:

- Day 0: uploaded via Open Cloud, processed clean, verified in-game.
- Day 1: fresh `InsertService:LoadAsset` of the same ids returns scrambled
  UVs, kilometer-long degenerate spike triangles, and in one case a dead
  texture (mesh loads, texture returns nothing).

Conclusion: Roblox runs a **delayed server-side re-encode** on mesh assets
after initial ingest, and that pass re-collapses/mangles what upload-time
processing preserved. Seam-splitting protects you at upload time only.

What never rots, in our observation:
- Assets ingested via **Studio's 3D Importer** (same FBX files — stable
  across re-fetches; the importer also previews the processed result
  before minting).
- **Raw, unprocessed Meshy FBX uploads** via Open Cloud (rigged pets, gem
  meshes — weeks stable). The rot correlates specifically with
  Blender-processed/re-exported FBX through the API lane.

Our final doctrine: decorative/static meshes that went through any DCC
processing get ingested through **Studio 3D Import only** (bulk
multi-select makes this a two-minute manual step per batch). The Open Cloud
model-upload API is reserved for raw generator output (rigs, simple
meshes), which has proven durable.

## FINAL UPDATE: the actual variable is SKINNED vs STATIC — and the fix is a bone

After the seam-split fix failed (delayed rot) and the Studio-import lane
failed too (same rot, different day), the decisive observation came from
asking why PET meshes never break: on a day when every static upload was
being mangled within hours — every lane, raw and rebaked alike — rigged
meshes uploaded the same morning stayed perfect, as had every rigged
upload for weeks.

**Roblox's delayed optimizer/re-encode pass does not touch skinned
meshes.** Static meshes get re-processed (and, in bad windows, mangled —
UV collapse, torn shells, degenerate spikes). Vertex data carrying bone
weights evidently can't be safely re-indexed, so skinned uploads skip the
pass entirely.

Also useful: `AssetService:CreateEditableMeshAsync` reads the SOURCE
channel, which stays intact even when the render channel rots — so a
geometry-hash tripwire built on EditableMesh will report CLEAN on a
visibly shattered asset. Detect render rot with your eyes (or a render
capture), not EditableMesh.

**The workaround (bone armor):** give every static prop a single root
bone with all vertices weighted to it, and upload that. The mesh becomes
technically skinned, the optimizer leaves it alone, and it renders
identically (an anchored, never-animated prop doesn't care about its
inert bone). In Blender:

```python
arm = bpy.data.objects.new("Armature", bpy.data.armatures.new("Armature"))
# one edit-mode bone, then per mesh:
vg = mesh_obj.vertex_groups.new(name="Root")
vg.add(range(len(mesh_obj.data.vertices)), 1.0, "REPLACE")
mod = mesh_obj.modifiers.new("Armature", "ARMATURE"); mod.object = arm
mesh_obj.parent = arm
```

Verified same-day: an un-boned upload of a prop shattered within the
hour; the bone-armored upload of the same GLB rendered flawlessly.

## Related lessons (hard-won, same family)

1. **A texture only maps onto the exact mesh generation it was baked/authored
   for.** Two Meshy generations of the "same" object have different UV
   unwraps; so does your decimated remesh vs the original. Never share one
   texture across mesh generations, and never ship the original hi-poly
   atlas on a decimated mesh — re-BAKE onto the shipping mesh's UVs.
2. **Judge texture health from the FRONT of the model, in engine.** Local
   renders validate the bake, not the upload. Back views hide (or fake)
   damage.
3. **Alternative ingestion lane:** Studio 3D Import handles per-corner UVs
   correctly and shows a preview of the processed result BEFORE minting the
   asset. Manual, but a solid escape hatch — and the reason our
   Studio-imported landmarks/altars never exhibited the bug.
4. If you set textures at runtime: `TextureID` needs the **Image** asset id,
   not the Decal id. Resolve via `InsertService:LoadAsset(decalId)` →
   `Decal.Texture`.
