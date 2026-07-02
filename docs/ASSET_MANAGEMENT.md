# Asset Management — the standard process

This repo is a TEMPLATE. The asset process must work for someone who forks it with
zero context, on any Roblox account or group. The rule set below is the contract;
everything else in `docs/ASSET_PIPELINE.md` (Meshy helpers, decimation, skyboxes)
plugs into it.

## The one rule

**Every Roblox asset id the game consumes must be traceable to this repo.**
Traceable means: the id appears in a `scripts/*.json` manifest written by an upload
pipeline, and the source file lives in `assets/`. `mise run assets-audit` enforces
this (CI-able); untracked Studio-side uploads are how a game silently welds itself
to one person's account — we cleaned up 104 of those during the 2026-06 group
migration and never want to again.

## Per-type policy (each asset type has different physics)

| Type | Where it lives | Why |
| --- | --- | --- |
| **3D models** (pets, crystals, eggs, props) | **In the repo**: `assets/place/PlaceAssets/<assetId>.rbxm`, Rojo-mapped to `ReplicatedStorage.PlaceAssets`, loaded via `Shared/Utils/AssetFetch.load(id)` | Models are git-versioned files synced by Rojo like code — `git clone` + `rojo build` = complete playable place. Ownership-proof, fork-proof, instant loads. `.rbxm` stores mesh/texture REFERENCES (KBs each). One-way sync: edit pipeline-generated models on the repo side, never in Studio. The hand-authored MAP stays Studio-owned (it is iterated in-editor). Extraction tool for adopting Studio-side models: `lune run scripts/migration/extract_place_assets.luau <place.rbxl> <out_dir>` (get the rbxl via File > Download a Copy). |
| **Images / decals** (UI icons, textures) | Source PNG in `assets/`, uploaded via `scripts/upload_icons.js` (or kin), ids recorded in `scripts/asset_manifest.json`, consumed ONLY through generated registries (`mise run gen-icons` → `configs/power_icons_assets.lua`) | UI needs real asset ids. The manifest + codegen chain means re-uploading under a different creator is one script run + one codegen — no hand-edited ids anywhere. |
| **Audio** | Source file in `assets/audio/`, uploaded via `scripts/upload_audio.js`, ids in `scripts/audio_ids.json`, consumed via `configs/sounds.lua` | Audio is PERMISSION-LOCKED to the owning creator — the one type that hard-breaks when ownership changes. Local source + scripted upload is the only sane path. |
| **Meshes** (MeshPart MeshIds) | Inside in-place models, or `assets/source/` + upload | Meshes load cross-owner; in-place models carry theirs implicitly. |

## The workflow for adding an asset

1. Put the source file in `assets/<domain>/` and commit it.
2. Upload with the domain's `scripts/upload_*.js` — pass `--creator-user <id>` or
   `--creator-group <id>` (the template never assumes whose account). The script
   writes the id into its manifest. Commit the manifest.
3. If a registry is generated from the manifest (icons), run the codegen task and
   commit the output. Configs reference generated registries, not raw ids.
4. For 3D models: skip 1–3 — build/import the model in Studio, parent it under
   `ReplicatedStorage.PlaceAssets` named however you like (ids only required for
   things `AssetFetch` resolves numerically), and load it via `AssetFetch`.
5. `mise run assets-audit` must stay green. A new orphan id in configs/src fails it.

## Changing owners (user → group, fork → your account)

Because of the rules above, re-homing all assets is mechanical:
- Models: already in the place — nothing to do.
- Images/audio: re-run the upload scripts with the new `--creator-*`, re-run codegen,
  done. The manifests give a complete old→new map for any config codemod.
- The full migration playbook + per-id ownership audit from the 2026-06 move lives in
  `scripts/migration/group_migration_audit.json`.

## Legacy allowlist

`scripts/migration/asset_orphans_allowlist.json` holds the pre-standard Studio-era
ids (104 at creation). It only shrinks: as migration moves remap them through proper
manifests, remove them here. Never add to it for new work.
