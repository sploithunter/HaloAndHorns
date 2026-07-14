# Asset Pipeline

This project tracks generated game assets in source control before they become Roblox asset IDs.

## Current State

- Runtime pet config lives in `configs/pets.lua`.
- Pet asset tracking lives in `assets/manifest/pets.json`.
- Local source exports should live in `assets/source/pets/`.
- Processed or temporary exports should live in `assets/exports/pets/`.

Run:

```sh
mise run asset-report
```

Use a stricter check for config/manifest drift:

```sh
mise run asset-check
```

Print Meshy-ready prompts:

```sh
mise run asset-prompts
```

Use the local Meshy helper:

```sh
mise run asset-balance
node scripts/meshy_asset.js prepare-reference elephant.basic --image ~/Downloads/elephant.png
node scripts/meshy_asset.js prepare-views elephant.basic --front ~/Downloads/elephant_front.png --right ~/Downloads/elephant_right.png --back ~/Downloads/elephant_back.png --left ~/Downloads/elephant_left.png --top ~/Downloads/elephant_top.png --bottom ~/Downloads/elephant_bottom.png
node scripts/meshy_asset.js image-to-3d elephant.basic --wait --download
node scripts/meshy_asset.js multi-image-to-3d elephant.basic --wait --download
node scripts/meshy_asset.js status <task_id> --download elephant.basic
node scripts/meshy_asset.js make-icon zebra.basic
node scripts/meshy_asset.js mark elephant.basic --status rejected --notes "bad side texture wrap"
```

Inspect a downloaded model before Roblox import:

```sh
open tools/model_viewer.html
```

Use the file picker or drag/drop a `.glb`, `.gltf`, or `.fbx` file. The viewer runs from a double-clicked HTML file and does not upload assets anywhere.

## Preferred Pet Creation Loop

For pets, the strongest workflow discovered so far is reference-image first:

1. Generate or draw a clean, front-facing, white-background style reference image.
2. Use Meshy image-to-3D or multi-image-to-3D in low-poly mode.
3. Texture the generated mesh with the same reference image when the shape is acceptable.
4. Download the `.glb` or `.fbx` source export into `assets/source/pets/`.
5. Upload the model to Roblox, then wire the resulting asset ID into the manifest and `configs/pets.lua`.

This is a developer workflow helper only. Meshy generation, API keys, source exports, and Roblox Open Cloud upload credentials must never be part of runtime game code.

## Manual Meshy To Roblox Loop

1. Pick a pet from `assets/manifest/pets.json` with `status = "needs_source"`.
2. Generate it in Meshy using either the stored prompt or a stored/source reference image.
3. Use Meshy's recommended order for the chosen workflow: generate the mesh, remesh/low-poly it, then texture it.
4. Download the `.glb` or `.fbx` to `~/Downloads`.
5. Copy the source export into `assets/source/pets/` with the manifest name, such as `bear_basic.glb`.
6. Import/upload the model through Roblox Studio.
7. Copy the resulting Roblox model asset ID.
8. Update the pet entry in `assets/manifest/pets.json`.
9. Update the matching `asset_id` in `configs/pets.lua`.
10. Run `mise run asset-check`.
11. Run `mise run build`, then verify in Studio through Rojo.

## Automation Direction

The repo-owned helper should automate the developer workflow, not the live game:

1. Read one entry from `assets/manifest/pets.json`.
2. Use `MESHY_API_KEY` from the local environment.
3. Submit either:
   - text-to-3D for prompt-only exploration, or
   - image-to-3D / multi-image-to-3D for approved style-reference images.
4. Poll or stream task status until the Meshy task succeeds.
5. Download the returned `glb`/`fbx` URLs into `assets/source/pets/`.
6. Mark the manifest entry as `generated` and store Meshy task metadata.
7. Pause for visual approval before Roblox upload.
8. Use Roblox Open Cloud credentials to upload/update the model asset.
9. Update `assets/manifest/pets.json` and `configs/pets.lua` with the Roblox asset ID.
10. Run `mise run asset-check` and `mise run build`.

Meshy's MCP server can be useful for interactive Codex-driven generation, but a checked-in script should remain the canonical portable path for this template. Other developers should only need repo scripts plus local environment variables.

Start with polling or task streaming from the local helper script. Meshy webhooks are useful later for a deployed asset service or high-volume batch pipeline, but they require an HTTPS receiver, are awkward behind local NAT without a tunnel, and add state-handling overhead that is not worth it for the first local developer workflow.

The first checked-in helper is `scripts/meshy_asset.js`. It reads `MESHY_API_KEY` from `.env.local` or the shell environment, copies local reference images into `assets/source/references/pets/`, sends them to Meshy as data URIs, and downloads generated GLB/FBX files into `assets/source/pets/`.

Always inspect the Meshy preview contact sheet before Roblox upload. A common failure mode is front-view reference detail wrapping around the sides of the model, such as eyes appearing on the body side. Mark those attempts `rejected` in the manifest and keep the preview/source files for comparison.

For stronger control, store six orthographic reference views: front, right, back, left, top, and bottom. Meshy's multi-image-to-3D API currently accepts 1 to 4 images, so the helper submits front/right/back/left and keeps top/bottom as approval references for later local or Roblox inspection.

Use `tools/model_viewer.html` for local spin-around inspection of downloaded GLB/GLTF/FBX source files before Roblox import. It is intentionally a static HTML tool with drag/drop and file picker input so it works without a dev server.

Inventory/source icons can start from the same front reference image. Use `make-icon` to remove only near-white background pixels connected to the image edges and save a transparent PNG under `assets/exports/pets/`. Do not globally delete all white pixels: pets such as Zebra, Bunny, or shiny variants may contain white body parts that must stay visible.

## Pet Asset Manager Direction

The full tool should become a local developer-only Pet Asset Manager:

1. Read `assets/manifest/pets.json` as the asset database.
2. Show a browser review gallery with reference images, transparent icons, Meshy preview sheets, local model viewer links, status, notes, and duplicate warnings.
3. Let the developer mark candidates `approved`, `rejected`, `needs_revision`, or `uploaded`.
4. Check duplicates before publishing:
   - duplicate pet keys or display names,
   - duplicate Roblox model/image asset IDs,
   - duplicate local file hashes,
   - intentional shared models such as runtime recolor variants.
5. Upload approved transparent images and GLB/FBX models to Roblox as creator assets using local Open Cloud credentials.
6. Save returned Roblox asset IDs back into the manifest.
7. Generate or update runtime pet config from approved/uploaded manifest rows.
8. Run `asset-check`, `build`, and Studio verification.

The review UI can be static for read-only inspection, but anything that writes files or uploads to Roblox needs a local script/server boundary because browsers cannot safely write repo files from `file://`, and API credentials must stay local. Treat `assets/manifest/pets.json` as the portable asset database unless we outgrow JSON; SQLite is optional later, but JSON keeps the template easy to fork and review in git.

## Runtime Insertion

`configs/pets.lua` is the runtime source of truth for pet and egg model IDs. On server startup, `AssetPreloadService` inserts configured models into `ReplicatedStorage.Assets.Models`, then generates viewport previews under `ReplicatedStorage.Assets.Images`.

Eggs placed in the world should clone the preloaded models from `ReplicatedStorage.Assets.Models.Eggs`. Direct `InsertService` loading is only a fallback if preload did not finish or the preloaded model is missing.

## Authored Landmark Repair

Large Meshy landmarks follow the same source-first rule even though their placement remains
Studio-owned. Never import a raw high-poly landmark directly from Downloads and leave its
`RBX_ReimportId` as the only recovery path. Split vertices and degenerate faces can survive the
first import but later shatter when Roblox reprocesses the private mesh assets.

The Heaven cathedral and mission portal are the reference implementation:

1. Canonical GLBs live in `assets/source/landmarks/`.
2. `scripts/decimate_mesh.sh --scene-parts 4 --targets 10000` welds/cleans the whole scene,
   budgets 40k triangles globally, and spatially partitions every face into four <=10k MeshParts.
   The FBX assembly and texture live under `assets/exports/landmarks/`.
3. The group-owned Model/PBR-map IDs and target Workspace paths live in
   `src/Shared/Assets/LandmarkAssets.lua`. It intentionally stays outside the runtime ConfigLoader;
   it is Edit-tool configuration, not gameplay configuration.
4. `scripts/studio/repair_landmarks.luau` is the single application/audit path. It loads the
   configured Model asset, preserves authored placement, effects, doors, and interaction hosts,
   and swaps the imported root for a plain Model so the protected reimport link cannot recur.

The repair script is idempotent. A second run reports healthy four-part landmarks and changes
nothing.

## Static Prop Rebake Pipeline (decimate-first, bake-second)

THE RULE (2026-07-13, mission-decor post-mortem): for any Meshy static prop,
the texture must be baked AGAINST THE MESH THAT SHIPS. Meshy's atlas is
authored for the hi-poly's UVs; welding + decimation rewrites the vertex/UV
layout, so shipping the original atlas on a decimated mesh renders as UV
kaleidoscope ("shattered glass"). Two historical failure modes, one cause:

- Gen-1 raw-mesh uploads (un-welded): looked fine at first, then Roblox's
  server-side re-encode scrambled them — split-vert/degenerate geometry rots
  on re-fetch ("shatter incident", diamond altar, 2026-07-08; batch-wide rot
  discovered 2026-07-13).
- Batch-2 decimated uploads: clean geometry, but the ORIGINAL atlas shipped —
  UVs could never match (infernal throne/fountain kaleidoscope).

Pipeline (scripts/blender/rebake_for_roblox.py, one prop; driver
scripts/rebake_mission_decor.sh, whole set):

1. Import source GLB (`assets/source/props/meshy_mission_decor/<name>.glb`).
2. Duplicate: the hi-poly stays untouched as the bake SOURCE.
3. Target: weld split verts (remove_doubles 0.0004) -> Decimate to 10k tris
   -> dissolve degenerate / delete loose / validate (the shatter guard).
4. Smart-UV-project FRESH UVs on the decimated target.
5. Cycles selected-to-active bake, DIFFUSE pass COLOR only, 2048px: the
   hi-poly's albedo lands on the target's new UVs.
6. Export FBX (mesh DATA renamed to <name> — the importer names MeshParts by
   data name) + save the baked PNG + render `<name>_preview.png`.
7. EYEBALL EVERY PREVIEW before uploading — verify-by-render is part of the
   pipeline, not optional.
8. Upload group-owned: `upload_models.js --fbx ... --name <name>` (Model) and
   `upload_icons.js --dir ... --creator-group 15872767` (texture; uploads as
   Decal — resolve to the wrapped Image id before setting TextureID, via
   InsertService:LoadAsset(decalId) -> Decal.Texture).
9. Update `scripts/mission_decor_model_ids.json` + `_texture_ids.json`.
10. TRANSPLANT THE PLACE PREFABS (ReplicatedStorage.MissionProps +
    Workspace._PropReview.MeshyDecor): registries alone change nothing the
    game renders. Swap each prefab's MeshPart for the new Model's (preserve
    Name/Size/CFrame/attributes/children/welds), set TextureID to the
    resolved image id, Color WHITE (Color multiplies the atlas), Material
    Plastic. Then File -> Save/Publish — prefabs live in the place file.

### Escape hatch: Studio 3D Import (processing-roulette survivors)

Cloud processing of an uploaded FBX is a ROULETTE: an upload can shatter even
when the Blender preview and the FBX are clean, and an IDENTICAL re-upload can
fix it (4/7 of batch 17) or fail repeatedly (diamond altar x4). When re-uploads
keep losing, ingest through Studio instead: Avatar/3D Import -> the same rebaked
FBX -> import WITH textures (the baked atlas embeds; the importer sets
TextureID itself, no Decal->Image resolution step). The pre-upload preview
window shows the processed result BEFORE it becomes an asset, which is the
whole point. Caveats: the resulting registry entry is a raw MESH asset id
(assignable to MeshId but NOT loadable via InsertService:LoadAsset like the
upload_models.js Model wrappers — transplant by cloning the imported MeshPart),
and imports land at raw Meshy scale (copy the old prefab's Size). Used
2026-07-14 for heaven_diamond_altar / heaven_flamecrest_shield /
heaven_ivory_throne after their v3 re-uploads all shattered.

### MissionProps solidification (rbxm, Rojo-served)

`ReplicatedStorage.MissionProps` is SOURCE-CONTROLLED: served by Rojo from
`assets/place/MissionProps.rbxm` (same pattern as `Assets.Models`), wired in
`default.project.json`. The place file can no longer drift — a forgotten
Edit-window transplant can't resurrect dead asset generations.

After any prefab change in Studio (new prop, transplant, retexture):
right-click ReplicatedStorage.MissionProps -> Save to File... ->
`assets/place/MissionProps.rbxm`, commit it WITH the registry update.
NOTE: current Studio saves the native `Tags` property; Rojo >= 7.7.0 required
to parse it (pinned in .mise.toml — 7.6.1 and lune 0.10.4 both reject it).

## Status Values

- `concept`: A reference/prompt is tracked for developer asset generation, but it is not wired into runtime config.
- `needs_source`: Roblox config has an ID, but the source mesh file is not present locally.
- `generated`: Meshy generated the asset, but it has not been uploaded or wired into config.
- `uploaded`: Roblox asset ID is known and config has been updated.
- `verified`: The asset has been checked in Studio.
- `rejected`: The generated asset should not be used.

## Notes

Keep API keys out of the repo. If we later automate Meshy or Roblox Open Cloud uploads, use local environment variables such as `MESHY_API_KEY` and Roblox Open Cloud credentials.
