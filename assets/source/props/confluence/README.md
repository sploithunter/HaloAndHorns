# The Confluence — standalone fountain review candidate

ImageGen → Meshy → Blender → Assets → Roblox upload, completed 2026-09-08. No map placement or publishing was performed.

## Use this model

- `assets/place/Confluence.rbxm`: native editable assembly, correctly oriented, anchored, with nine scrolling water/lava Beam effects. Import this for the first placement review.
- Roblox group-owned raw geometry Model **138190114448131** (creator group **15872767**). This upload contains the 24 textured mesh components; the native companion adds effects and corrects the raw FBX importer’s 180-degree horizontal orientation.
- `configs/confluence_fountain.json`: authoritative asset IDs, placement contract and effect tuning.
- `assets/manifest/confluence_fountain.json`: library entry. The existing shared Models.rbxm and MissionProps.rbxm libraries were deliberately not rewritten during standalone creation.

## Dimensions and placement

Measured native bounds: **21.99677 × 7.799863 × 22.000002 studs** (X/Y/Z). Ground contact / model pivot is local (0,0,0), Y up. Heaven is negative X; Hell is positive X. Proposed courtyard placement is (0,4,-88), using the existing 22-stud footprint. No placement is baked into the delivered model. The review mannequin is a segmented 5.2-stud height reference and is excluded from exported assets.

## Contents and editing

24 MeshParts, 20,716 triangles total; largest part 3,690 triangles. Separate Heaven/Hell foundations, basin shells, terrace spillways and rim ornaments; one crown; six pool meshes; nine thin falling sheets. Five embedded 1024-pixel material textures. UV seam vertices are split and imported corner normals preserved. All source carvings derive from the selected Meshy geometry. Blender adds the functional pools and falling sheets rather than baking those effects into the carved body.

Native `.rbxm` also includes nine Beams with water texture speed 0.65 and lava speed 0.12, all configured in the JSON. The Beams scroll automatically without a runtime script; no lights, particle spam, scripts, live data or gameplay dependencies are installed. Pool surfaces remain static. Beam connections/settings have been structurally checked; visual motion and collision behavior in the intended map remain placement-review work. Preview images use Blender lighting and emissive materials, not a claim of a completed Roblox lighting pass.

## Reproduce

Run from repository root:

```
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/source/props/confluence/refine.py
```

The companion reads config and the canonical `textured/model.glb`, writes the FBX/GLB/textures and four review renders, and saves a packed Blender file. `render_review.py` rerenders the saved Blender scene. Both keep preview ground, dimension guides and mannequin out of the mesh exports.

For native assembly, load the configured raw Model without parenting it into any map, then call the function returned by `assemble_native.luau` with `(model, config, geometryManifest)`. Save/serialize the returned model. This is an offline authored asset companion, not runtime geometry generation.

## Provenance and checks

- Built-in ImageGen prompt: `prompt.md`; concept: `assets/concepts/confluence/confluence-v1.png`.
- Meshy T2 first 9,000-target pass failed topology; retained under `meshy_9000` for provenance.
- Selected 14,000-target task: `01a0831a-7165-7132-b0fb-75790f85e721`.
- Blender repair closed the selected mesh using a 0.002 diagonal voxel ratio and a 17,000-triangle ceiling. `closed/integrity.json` passes zero boundary/non-manifold/degenerate geometry.
- Retextured the exact repaired model with task `01a0831b-f137-74e0-a57e-297651f7b726`; `textured/integrity.json` also strict-passes. Meshy’s uniformly pale texture was corrected in Blender into the final realm palette. The generated interpretation uses radial scalloped terraces, rather than matching every contour of the concept image.
- Four repaired geometry angles and final pedestrian/oblique/plan/rear renders were inspected; fluid masks, shading, orientation, file size and diagram framing were iterated.
- Upload loaded successfully in an unparented Studio model; all 24 mesh and texture IDs resolved, dimensions and corrected realm orientation verified. The transient model and export buffer were destroyed afterward. No Workspace changes or duplicate Studio windows.
- Native file round-trip: one model, 24 anchored MeshParts, nine connected scrolling Beams. Lua companion: Selene 0 errors/warnings; Python companions compile. Repository CI: 2,842 tests pass.

Existing catalogs checked before generation: Heaven star fountain, Hell infernal fountain, horned animal skull, Hell skull lantern and Heaven flora. The user explicitly requested a new ImageGen → Meshy → Blender asset; no external paid source models are redistributed here.

## In-map pool animation refinement

The Crossroads placement uses `surface_tiles.py` to extract conservative rectangular masks from the original pool geometry into `configs/confluence_surface_tiles.json`. `apply_surface_flow.luau(model, config, tiles)` hides only the original flat pool meshes and adds colored Texture surfaces. Install `surface_flow_client.luau` as a LocalScript under StarterPlayerScripts for nearby client-only scrolling. Tuning lives in `configs/confluence_fountain.json.surface_flow`. Water and lava offsets were measured moving at their configured distinct rates in Studio Play. The original raw Roblox upload remains unchanged; pool motion is an authored placement companion.
