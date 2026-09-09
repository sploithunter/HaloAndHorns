# Crossroads fossil brief and provenance

Requested 2026-09-08. Asset-only addition for the Hell pool. Intended pocket near X282/Z8 is a candidate, not a placement approval. Envelope at most 8W×5D×7H, friendly fantasy horned fish fossil in low charcoal stone, warm bone and restrained sulfur accents. No gameplay, rewards, collision requirement or Studio mutation.

Reference reviewed: docs/art/crossroads-review/implemented-screenshots/07-hell-fishing.png. Native vocabulary: bone stones, dark earth and gnarled Hell trees around real Terrain water. The generated concept is an original new prop, not a copy of any catalog model.

Built-in imagegen used (no CLI fallback), concept generated at /Users/jason/.codex/generated_images/01a0834d-2d4f-7820-beb0-a5d5980d6652/exec-5bb0b666-1586-4ee6-bca5-09c66e8919c6.png, copied to concept-v1.png.

## Exact ImageGen prompt

Use case: stylized-concept. Create ONE isolated 3D game prop reference for a Roblox fantasy fishing pool: a small FRIENDLY horned fish FOSSIL cradled upright in a low charcoal-black volcanic stone base. A single readable sculptural silhouette, wide curving fish skeleton flowing upward from a low oval stone cradle: rounded expressive fish skull at one end with two short backward horns, closed gentle jaw (no snarling teeth), substantial elegant rib-and-spine shapes, recognizable fish tail curved up on the other side. Pale warm weathered bone against simple dark faceted basalt; only a tiny muted sulfur-olive mineral accent in the base. Chunky elegant handcrafted fantasy collectible-landmark quality, slightly faceted, coherent thick strong geometry for watertight game modeling. Fossil is merged naturally into its cradle at several support points, not floating. Fits a compact 8 wide ×5 deep×7 high envelope, base no taller than one fifth total height. A prop near an eerie but friendly fishing pond with dark soil, bone stones and gnarled stylized trees. Show the entire standalone object, single three-quarter front view with clear side silhouette, neutral off-white plain background, soft even studio lighting and slight ground contact shadow. No scene, water, text, labels, diagram, extra props, characters, foliage, pedestal tower, sharp scary teeth, gore, blood, realistic corpse, glowing eyes or particle effects.

## Geometry gate

Smart Topology T2 first trial target6500 produced6891tris but73boundary edges. Four cardinal previews inspected: good chunky fish/skull/tail and open rib silhouettes, no gore or extraneous floating decoration. It failed strict integrity and was not sent to retexture. Second trial changes target to9300 per pipeline guidance before local repair.

All Meshy request/task records are under their named output directories; they retain task IDs/source hashes without API keys. No raw credentials are logged. Final material/mesh report, editable .blend, embedded-texture FBX and cardinal renders will be under final/. Existing root .gitignore excludes assets/source/props/*; source is retained locally in the shared worktree and not silently committed or included in a public extraction.

Second target9300 trial produced10242triangles and50boundary edges, with no useful silhouette improvement. Chose the lighter first geometry and repaired a separate copy using the existing repair_mesh_integrity helper: six closed boundary loops capped, no voxel remesh or decimation, final6952triangles. Re-imported repaired GLB passes strict integrity with zero boundary/nonmanifold/wire/degenerate edges/faces. Geometry retains31 face components (authored separate rib/stone forms); no claim of a single watertight connected shell. Repaired-review exporter normalizes to8W×3.578125D×5.21875H and saves cardinal renders before retexture.

Root native survey supersedes the original candidate: (282,8) intrudes east circulation. Preferred clear pocket is **(280,4,77)**, alternative (278,4,-61), with sampled ground Y4 and no visible authored geometry in a12×12×10 query. Face west/northwest toward the pond approach after native orientation review. Asset stays bottom-centered at local origin; no world placement is baked into source/export. These placement measurements are lead-reported, not rerun by this asset agent.

## Final asset delivery

Exact repaired GLB retexture task `01a0836c-f763-71d7-af1a-241e5df5ec6a` succeeded. Textured GLB and final embedded-texture FBX both pass the strict integrity gate with6952triangles and zero boundary/nonmanifold/wire/degenerate geometry. Final FBX has zero vertices carrying conflicting UV coordinates; Meshy already split its seams, so the export guard needed no extra seam-edge splits. One material and one1024×1024 texture. All five final views inspected: clear warm bone versus charcoal cradle, restrained sulfur stones, friendly rounded skull, uninterrupted open-rib silhouette.

**Group15872767 Model asset: `77687797463306`**, uploaded through the existing `scripts/upload_models.js` helper from the main checkout so its existing local credentials loader is used. No credentials printed and no shared helper changed. The final embedded-texture FBX is `final/CrossroadsFossil.fbx`; editable packed-texture Blender file is `final/CrossroadsFossil.blend`. GLB, texture and five renders remain beside them. `provenance.json` stores source/export hashes, sizes and Meshy task metadata; total consumed Meshy credits20 (5+5+10).

Native Roblox size/material/orientation review remains with the root agent; upload success alone does not establish that check. Load this Model into staging, verify one textured MeshPart, maintain white Part.Color so the atlas is not tinted, scale by actual native visible bounds to config dimensions `[8,5.2187519,3.5781281]` if the FBX importer changes unit scale, disable decorative collisions/touch/query, and ground the base at sampled Terrain before placement. No world position is baked. Preferred placement candidate `(280,4,77)` must retain root-measured circulation. No Studio mutation, production publishing or gameplay code was performed by this asset agent.

## Native verification — integrating lead report

Lead loaded Model77687797463306: **one MeshPart**, TextureID**103342164515277**, dimensions**8×5.21875×3.57813**. Placed in the isolated preview at**(280,4,77)** with yaw85° and0.2-stud embed. Textured native viewport matches the reference front; stone base is grounded, with no floating base or route intrusion. This closes the pending basic native geometry/appearance/placement check above. It does not claim a production publish or whole-device performance measurement. Placement config/baker were added by the lead; this asset agent did not modify them or touch Studio.

## Durable source selection and texture audit

Read-only Blender reopening confirms **one mesh and a packed Image_0**, so the `.blend` is self-contained for final mesh/material editing. It also exposed a packaging nuance: Image_0 reopens at **2048×2048**, while the external `final/texture_0.png` is independently confirmed **1024×1024**. The pre-export in-memory downscale did not replace the original packed bytes in the saved Blender file. Consequently, the earlier generic “one1024 texture” statement applies to the external PNG and must **not** be treated as proof of the uploaded/native texture's dimensions. Native TextureID is confirmed, its pixel dimensions are not measured. This audit changes documentation only; no reupload, regeneration or source modification followed the accepted native appearance.

Recommended minimal source set, approximately **9.54MB decimal** including the files below (brief size varies with this appended record):

| File | Bytes at audit | Purpose |
| --- | ---: | --- |
| concept-v1.png | 2,138,120 | Original ImageGen reference |
| repaired/model.glb | 539,172 | Exact topology-clean input sent to Meshy Retexture |
| final/CrossroadsFossil.blend | 4,003,134 | Editable final mesh/material with packed original-resolution image |
| final/texture_0.png | 1,826,053 | External1024px atlas; can deliberately relink for a future downscaled export |
| final/front.png | 1,015,497 | Native-comparison art reference |
| prepare_asset.py; verify_uv.py | 4,908;920 | Generation/export recipe and UV-collapse guard |
| brief.md; provenance.json; upload.json | small metadata | Prompt, source hashes, stage lineage, real upload identity and native report |
| repaired/repair.json; repaired/integrity.json | 1,154;1,069 | Exact repair and strict clean-input evidence |
| final/report.json; final/integrity_fbx.json; final/uv_guard.json | 511;1,079;99 | Final dimensions/triangle/UV integrity evidence |
| geometry/task.json; geometry_9300/task.json; textured/task.json | about4KB combined | Both geometry attempts and exact retexture task lineage/credit usage |

Do not force-add the entire intermediate tree. Omit alternate geometry binaries, repaired-review renders/.blend, unused extra final camera renders, `.blend1` backups and duplicate FBX/GLBs from Git if minimizing history. The final GLB is **2,053,696bytes (1.96MiB;2.05MB decimal)** and can replace a convenience artifact choice if desired; it is not required alongside the editable final `.blend`. The FBX is3,909,676bytes and remains available locally for direct import, but need not duplicate the durable source set in Git.

To recover the final artifact without another API job, open the retained final `.blend`, select only the CrossroadsFossil mesh and export embedded-texture FBX using the documented axis/UV guard settings. `prepare_asset.py` documents the original transformation from textured/model.glb; that3,854,804-byte intermediate is deliberately omitted from the minimal Git set, so rerunning that script from its default input is not the minimal-pack recovery path. Preserve the final mesh/UVs in the `.blend`; do not rerun Meshy to approximate them.

All JSON under this asset folder was parsed and scanned for embedded `data:image`, `data:model`, `data:application`, API-key/authorization/bearer/x-api-key markers: **none found**. The three task records contain sanitized task metadata, local file paths, hashes and credit counts, not data URLs or credentials. `provenance.json` contains file hashes/sizes and sanitized task summaries. No secrets were printed during this audit. Existing Git ignore rules still apply; root owns any explicit limited force-add decision.


## V2 actual texture packaging correction

The earlier audit above is the preserved v1 record. A subsequent authorized fix now produces a separate `final_v2/` without modifying `final/` or the accepted v1 upload. `prepare_asset.py` saves the downscaled PNG, loads it as a **new image datablock**, rebinds material texture nodes, removes the unused original image, then packs/exports. It reopens the saved `.blend` and asserts all packed images are1024×1024. Independent FBX reimport also reports a1024×1024 embedded texture. These are actual file checks, not in-memory assumptions.

V2 **Model116671594170630**, `Crossroads_Friendly_Fish_Fossil_v2`, group15872767, was uploaded through the existing model helper. Native TextureID and v2 native visual acceptance remain for the lead's Studio check. Map config and placement were untouched. The strict integrity check retains6952triangles, no boundary/nonmanifold/degenerate geometry; UV guard has0conflicting vertices. GLB position/normal/UV/index buffers are byte-identical to v1. Front render inspected: readable pale horned fossil and charcoal cradle, no texture seams or changed silhouette. No Meshy job or new image generation was performed.

Use `upload_v2.json` and `provenance_v2.json` for the new asset identity and hashes; v1 records remain intact. V2 `.blend` is2,244,101bytes, FBX2,150,652bytes, GLB2,053,696bytes, external atlas1,826,053bytes, front reference1,015,497bytes. For a smaller durable Git source set, select the v2 `.blend` in place of v1's larger `.blend`, alongside concept, repaired GLB, v2 atlas/front, helpers, both upload/provenance records, sanitized task records and validation reports. This is about7.8MB plus small metadata. Preserve the v1 binary folder locally for provenance; do not force-add both full export folders. The packed v2 `.blend` alone remains the exact editable geometry/material recovery source; final FBX/GLB are optional duplicate convenience exports.


## Native v2 verification and retained source recovery

Lead-owned Studio insertion verified v2 Model116671594170630, Mesh116191368702768, Texture105991804065229 and dimensions8×5.21875×3.57813. Placement remains(280,4,77), yaw85, embed0.2, preview only. Correct folder spelling is `final_v2/`; config paths were repaired without changing placement keys.

The minimal staged pack retains the packed v2 `.blend` as the exact mesh, UV and material input. The helper now also accepts that `.blend` directly, so the expensive Meshy textured intermediate and duplicate FBX/GLB are unnecessary for reproduction. From repo root run:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/source/props/crossroads_fossil/prepare_asset.py -- --input assets/source/props/crossroads_fossil/final_v2/CrossroadsFossil.blend --output assets/source/props/crossroads_fossil/rebuild
```

Use a new output directory; the helper explicitly rejects overwriting its retained blend input. Original repaired geometry, concept, sanitized task records and versioned upload/hash evidence preserve upstream lineage. V1 binaries remain locally, while compact v1 records remain in Git. No new generation or remote publish occurred.
