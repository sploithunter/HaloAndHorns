# Crossroads fishing rods — original Blender precision assets

Created 2026-09-08 without editing Studio or the map. Two 5.5-stud candidates:

| Realm | Display name | Group-owned Model asset | Triangles |
| --- | --- | --- | ---: |
| Heaven | Pearlwing Rod | 135506662342652 | 3,232 |
| Hell | Cinderbone Rod | 82970001257677 | 3,048 |

Both were uploaded by the existing `scripts/upload_models.js` FBX pipeline with creator group **15872767**. Open Cloud returned successful Model IDs. **Native loading and structural bounds were verified by the lead**: each model has five MeshParts, height5.5, and populated TextureIDs (Heaven115790875963202, Hell139430177813435). Native image QA and hand fit remain pending. Raw bounds establish the same180°Y import reversal as the fountain; the installer corrects it. No new Studio window, fallback primitive rod, production Tool or gameplay behavior was created.

## Art and source

Original precise Blender geometry: gently tapered/bent ivory or bone shaft, wrapped grip, spoked reel with crank and hub, five open line guides, restrained feather/horn shoulders. No fishing line is baked into geometry. Each model retains five semantic mesh groups: Grip, Reel, Guides, Shaft, Ornaments. These are rigid props; the reel is separately editable but not rigged or animated.

`recipe.json` controls the main shape and palette. `generate.py` builds original geometry, smart-projects padded UV islands into a shared 256×256 material atlas, writes an editable `.blend`, GLB and embedded-texture FBX, and produces a front-oblique preview. The FBX upload copy splits polygon corners and preserves normals/UVs to avoid the known Open Cloud UV-collapse issue; the editable Blender source remains welded. `render_reverse.py` produces rear-oblique review images from the editable source.

Artifacts are under `assets/exports/props/fishing_rods/heaven/` and `/hell/`:

- `<realm>.blend`: actual editable source with named Grip/LineTip empties.
- `<realm>.glb`: textured exchange model.
- `<realm>.fbx`: exact uploaded geometry, with embedded atlas.
- `<realm>_albedo.png`: atlas source; palette/material grain authored locally, no external image license.
- `geometry.json`, `integrity.json`: dimensional and strict topology results.
- `review.png`, `review-reverse.png`: both views inspected before delivery.

The source-first Blender route was chosen for exact thin shafts, line-guide holes, reel spokes and grip dimensions. Meshy was unnecessary for these mechanical shapes. No generated image, third-party mesh or borrowed fishing asset was used. Future organic fish/large sculpted heroes remain separate ImageGen → Meshy → Blender work.

## Coordinate and integration contract

Blender Z is longitudinal/up; minimum Z0, maximum Z5.5. Both approximately 0.64 wide × 0.63 deep. Intended Roblox mapping is `(Blender X, Blender Z, -Blender Y)`; expected height5.5. Raw FBX import can reverse facing or scale; verify using visible native bounds before setting a hand transform.

- Grip reference: Blender(0,0,0.6) → intended Roblox(0,0.6,0).
- LineTip: Blender(0.31,-0.21,5.488) → intended Roblox(0.31,5.488,0.21).
- Reel pivot: Blender(0,-0.225,1.21) → intended Roblox(0,1.21,0.225).
- These semantic references live in `configs/realm_crossroads_fishing_rods.json`, not in a runtime service. Source empties are excluded from the FBX mesh upload; create native Attachments only after import orientation is confirmed.

For preview, clone art only, anchor it, disable collision/touch/query and connect a temporary line to the real LineTip after fitting. Future equipped rod must be fitted to supported avatar grips and use its own native attachment. FishingConnected remains false. The rod asset itself contains no Tool, fishing scripts, catch logic, rewards or hidden prompts.

## Checks and regeneration

Both final FBXs pass `scripts/blender/check_mesh_integrity.py`: zero boundary edges, wire edges, 3+-face edges, zero-length edges or zero-area faces after the checker's tiny UV-seam weld. Five semantic groups each; largest component936triangles. The initial reel had coincident spoke-cap edges; spokes now begin outside the hub and strict checks pass. Final Blender dimensions measure exactly5.5high. Front/rear previews were inspected; shafts, open guides, crank and shoulders remain coherent from both sides.

Run from the worktree:

```
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/source/props/fishing_rods/generate.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/source/props/fishing_rods/render_reverse.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/blender/check_mesh_integrity.py -- --input assets/exports/props/fishing_rods/heaven/heaven.fbx --report assets/exports/props/fishing_rods/heaven/integrity.json
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/blender/check_mesh_integrity.py -- --input assets/exports/props/fishing_rods/hell/hell.fbx --report assets/exports/props/fishing_rods/hell/integrity.json
```

Regeneration creates a fresh **local candidate** manifest; it does not update uploaded Roblox assets. Preserve current upload records and revalidate before any later upload; the existing helper skips named assets already recorded in `roblox_assets.json` unless explicitly forced. The current exact uploaded FBX hashes are recorded in `assets/manifest/realm_crossroads_fishing_rods.json`.

Remaining native verification: compare front/rear colors with reviews, check corrected tip/Grip attachment references, test grip clearance against default and larger avatars, then serialize the native assembly for Assets. Neither a Blender render nor a successful HTTP upload certifies this final stage.

## Authored display installer

`tools/realm_crossroads/fishing_rods.luau` returns `(world,cfg)` and reads `configs/realm_crossroads_fishing_rods.json`. Apply in Edit **after** fishing polish and before binding visual preview prompts. It clones existing `ServerStorage.CrossroadsFishingRodAssets.heaven/hell` into a separately replaceable `FishingRodDisplaysR11` root. Eighteen rods mount their actual Grip beside the existing rod rests, at local(-4.1,deckTop+1.2,3.8), leaning20° toward water. No load/upload occurs.

It preserves imported geometry's raw local origin while applying180°Y correction, rather than accidentally placing the bounding-box center on the grip. Each prop carries RodGrip/RodLineTip attachments; original deck LineTip is updated to the displayed tip, so the lead's cosmetic line connects to the actual mesh. `deck.RodDisplay` references its model. Config owns all offsets/angles/raw-tip coordinates. Rerun replaces only displays, restores mount from cached raw source, and updates18LineTips; it does not alter Standing/Cast, prompts, fish or rewards. Root native QA must confirm the line begins at the upper eyelet and that leaning shafts clear dummies/cameras.
