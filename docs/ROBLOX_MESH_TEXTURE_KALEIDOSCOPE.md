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
