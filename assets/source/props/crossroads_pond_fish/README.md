# Original pearl pond fish

Decorative living fish for the Crossroads ponds. Original ImageGen concept, two geometry-only Meshy candidates, local topology repair, exact repaired-GLB retexture, Blender texture seam closure and two-bone skin. No catalog geometry, texture or rig contributed to this asset.

Uploaded Model107641909625364, group15872767. Native mesh/texture/Bones, forward axis and underwater appearance await lead verification. Expected native dimensions(width,height,length)0.85×1.2×3studs, center pivot, head−Z/up+Y. Source Blender head+Y; FBX axis conversion uses forward−Z/upY.

## Source choice and provenance

Local source/manifest searches and active preview ServerStorage/ReplicatedStorage contained no living fish, only old fishing layout and the dead fossil. Approved Polyfork search found a [Firefish Goby](https://polyfork.dev/asset/firefish-goby-18d0dd) with a skinned named-part rig; its public preview had no animation clips. Download authorization was unavailable locally, and `gh repo view` confirmed this repo is public. Lead directed original generation. Preview-only catalog files were moved outside the repo; do not stage or reuse them. This folder's production sources are original ImageGen/Meshy outputs.

Original concept: `concept-v1.png`; ImageGen source job image `exec-d900757b-660f-4aed-ba7e-767ab0b1e361.png`. Prompt requested one elegant horizontal pearl/ivory fantasy pond fish, restrained gold fins, clear broad forked tail, dark eyes, short fins, no halo, text, props, environment or water. No catalog image was supplied to ImageGen or Meshy.

| Stage | Result |
| --- | --- |
| Geometry4000, task01a08384-6271-73c5-b67b-99d9de2fcac9 | 4236tri,34openedges; rejected topology |
| Geometry4500, task01a08384-cd3d-7724-a46d-fda050824166 | 4723tri,5openedges; chosen silhouette |
| Local repair | 4724tri, strict boundary/nonmanifold pass; no voxel remesh |
| Retexture task01a08385-b005-72d9-8454-e723fd37185d | Exact repaired input,4712tri,4openedges after texture-stage processing |
| Texture closure | UV-interpolated center fan closes4edge seam;4716tri, strict pass |
| Final FBX | 4716tri,3closed components,0boundary/nonmanifold/degenerate geometry,0UV-conflicting vertices |

Two geometry jobs5credits each plus10credit retexture:20Meshycredits total. Sanitized task records contain IDs/credits/local paths, no data URLs or keys. The standard quad filler chose an occupied diagonal on the texture-stage seam; `repair_texture_seam.py` supplies a small center fan without remeshing or rebaking the atlas. Failed generic intermediate stays unselected locally.

## Rig and export

`Root` holds the main body. `Tail` uses a smooth weight transition through the distal peduncle, with no disconnected animation parts. Tail localZ rotation bends laterally; FBX reimport testing at12degrees moved tail vertices about0.175stud along Blender/worldX. Both bones and normalized skin weights survived that round trip. No animation clip/animation asset is supplied: a cosmetic client may drive Tail.Transform, subject to native verification. Rigid whole-model glide remains a valid fallback if the Roblox upload strips bones.

One fresh packed1024×1024PNG atlas is loaded into a new Blender image datablock, rebound to the material and packed. Reopened `.blend` and independently reimported embedded FBX both verify1024dimensions. This avoids the stale packed2048bytes encountered in the fossil v1 pipeline. Both sides, front, top and posed-tail top renders were reviewed; pearl body, readable gold tail and seam closure are clean. Material metallic0, roughness0.6; no emission.

Rebuild from repo root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/source/props/crossroads_pond_fish/prepare_asset.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/source/props/crossroads_pond_fish/verify_export.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/blender/check_mesh_integrity.py -- --input assets/source/props/crossroads_pond_fish/final/PearlPondFish.fbx --report assets/source/props/crossroads_pond_fish/final/integrity_fbx.json
```

The default input is the retained `textured_closed/model.glb`; no API generation needed to rerun final preparation. Asset dimensions, orientation, rig names/weight transition and material settings are in `configs/realm_crossroads_pond_fish.json`. Retain concept, exact textured_closed input, final packed `.blend`, one preview and scripts/reports; duplicate FBX/GLB and intermediate renders are optional convenience files. `provenance.json` hashes all selected artifacts. No raw Polyfork files may be included.

## Native acceptance

Lead must inspect loaded asset shape/orientation and confirm Root/Tail as Roblox Bones, set a small localZ Tail.Transform and observe a lateral tail bend. Confirm Model/mesh/texture identifiers in config/manifest. Then inspect2–3fish per pond at centerY−0.9…−1.3 against actual Terrain water surfaceY0. Preserve global water appearance; no emission/Neon fake fish or surface plane. Decorative fish cannot reserve fishing stations, react as a bite, grant rewards, or become catchable. Native controller/performance/distance/reduced-motion lifecycle belongs to the lead's separate integration.


Native import update: lead temporary ServerPlay load verified one PearlPondFish MeshPart with dimensions0.85000002×1.19999981×3, Mesh86628776776675, Texture92346256478119, and Root/Tail Bones retained. The temporary model was destroyed after query. This closes asset-loading/bone-preservation checks; underwater facing, visibility and live tail motion remain pending. Root's cosmetic controller uses localTailZ oscillation14degrees; no animation clip is asserted.
