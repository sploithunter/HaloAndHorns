# Heaven Watcher asset

Original image-to-Meshy floating face, commissioned 2026-09-05 as the reassuring
Heaven counterpart to the Hell Watcher. This directory records the source-first
pipeline; runtime encounter integration is separate.

## Art brief and provenance

Built-in image-generation reference: a single front-facing, symmetric celestial
face with a calm closed-mouth smile, ivory/opalescent faceted stone, restrained
gold seams and warm luminous almond eyes. Integrated sculptural crown; no body,
neck, wings, detached halo, text or tiny filigree. Opaque low-poly-friendly game
prop, white studio background. Original fictional design, not a real portrait.

Reference generated with the built-in imagegen tool, not the CLI fallback.
Target: one approximately 4,000-triangle mesh, centered pivot, local -Z front,
+Y up, no rig. The head will be imported group-owned after geometry integrity
and cardinal preview checks. No experience publishing is part of this asset task.

## Geometry and texture gates

- Smart Topology T2 geometry task `01a07418-4407-766a-8679-c41c010cf4b6`
  requested 4,000 triangles (5 credits); 4,017 exported, 175 open boundary edges.
- A meaningfully different 6,500 target (task `01a07419-7133-758d-bf93-a5dd88f74f64`,
  5 credits) still failed. Both raw results/reports remain for provenance.
- The 4K silhouette was strongest. Simple fill-only repair still failed; the
  canonical repair helper with `--voxel-remesh-ratio 0.003 --max-triangles 4500`
  produced one closed 4,468-triangle surface. Its strict report passes.
- Retexture task `01a0741c-dbfe-74d0-bd94-483d765ba005` (10 credits) used that
  **local repaired GLB**, not the invalid original task. The textured result also
  passes strict integrity. No triangle changes occurred during retexture.
- Asset-local `build.py` calls the canonical UV seam splitter and embedded-FBX
  exporter without welding/decimating the textured result. All export vertices
  have exactly one UV. A separate FBX round-trip strict check passes.
- Four cardinal Blender views were inspected: no side/back duplicate faces,
  no missing crown points or open silhouette tears. The atlas is a single 2K
  color map; no separate normal, metal or roughness texture residency.

Total Meshy use: 20 credits. No credits purchased.

## Rebuild (repository root)

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python assets/source/props/heaven_watcher/build.py -- \
  assets/source/props/heaven_watcher/textured/model.glb \
  assets/exports/props/heaven_watcher/final

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python scripts/blender/check_mesh_integrity.py -- \
  --input assets/exports/props/heaven_watcher/final/HeavenFace.fbx \
  --report assets/exports/props/heaven_watcher/final/integrity_fbx.json
```

The `.blend`, `.glb`, embedded `.fbx`, standalone atlas and four preview PNGs are
under `assets/exports/props/heaven_watcher/final/`. Pivot is bounds-centered.
Source front is Blender -Y; Roblox front must be verified on import as local -Z.

## Roblox handoff

The user approved the appearance ("the face looks awesome"). The exact embedded
FBX was uploaded using the canonical `upload_models.js` helper as group-owned
Model **90097153593365**, owner group **15872767**. Hashes and IDs live in
`assets/manifest/heaven_watcher.json`; no runtime asset literals were added.

The intended Heaven voice is female: serene, melodious and reassuring. No voice
audio was generated as part of the mesh pipeline.

Status: uploaded; coordinated Studio orientation/texture verification pending.
