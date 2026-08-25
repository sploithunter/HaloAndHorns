# Layer 3 eggs and stands

This set contains four Heaven 3 eggs, four Hell 3 eggs, and one reusable stand for each realm.
The eight card images followed the required two-generation workflow: a white-background source,
then a recolor-preserving edit onto a palette-safe chroma screen, followed by programmatic alpha
removal with `scripts/remove_image_background.py`. No image generator performed the cutout.

## Egg set

| Realm | Origin | Egg | White source | Chroma decision | Alpha card |
| --- | --- | --- | --- | --- | --- |
| Heaven 3 | Fire | Gloryfire Egg | `white/heaven3_fire_egg.png` | magenta | `cards/heaven3_fire_egg.png` |
| Heaven 3 | Ice | Halo Frost Egg | `white/heaven3_ice_egg.png` | magenta | `cards/heaven3_ice_egg.png` |
| Heaven 3 | Grass | Empyrean Grove Egg | `white/heaven3_grass_egg.png` | magenta | `cards/heaven3_grass_egg.png` |
| Heaven 3 | Desert | Oasis Egg | `white/heaven3_desert_egg.png` | magenta | `cards/heaven3_desert_egg.png` |
| Hell 3 | Fire | Ruinfire Egg | `white/hell3_fire_egg.png` | green | `cards/hell3_fire_egg.png` |
| Hell 3 | Ice | Dreadfrost Egg | `white/hell3_ice_egg.png` | green | `cards/hell3_ice_egg.png` |
| Hell 3 | Grass | Dreadthorn Egg | `white/hell3_grass_egg.png` | green | `cards/hell3_grass_egg.png` |
| Hell 3 | Desert | Dreadglass Egg | `white/hell3_desert_egg.png` | green | `cards/hell3_desert_egg.png` |

All card PNGs are 1254×1254 RGBA images. Their four corners are fully transparent and every image
contains both zero-alpha background pixels and fully opaque subject pixels.

## 3D production

The local, access-controlled GLBs live under `assets/source/eggs/layer_3/` and are intentionally
ignored by Git. Each egg was generated with Meshy Smart Topology T2 at 5,000 triangles, retried at
5,300 when needed, repaired locally, checked before texturing, and textured from the accepted source
image. Each stand used 4,000 and then 4,300 triangle targets. Voxel repair was capped below Roblox's
10,000-triangle direct-import limit.

The selected pre-texture geometry for every asset had zero boundary edges and zero non-manifold
edges. Seven textured outputs also pass that strict check. Three textured outputs repeatedly regain
a microscopic seam during Meshy's retexture export despite a clean input and a second identical
retexture attempt:

- `heaven3_grass_egg`: 9,954 triangles, 4 boundary edges, 0 non-manifold edges.
- `hell3_ice_egg`: 9,948 triangles, 4 boundary edges, 0 non-manifold edges.
- `hell3_desert_egg`: 9,956 triangles, 0 boundary edges, 1 non-manifold edge.

The front/back review shows no visible gaping hole in those three assets. Their exact selected GLBs
and reports are in each asset's `final/` directory for import review. Do not replace a selected GLB
with an earlier Meshy download without rerunning `scripts/check_model_integrity.py`.

## Review sheets

- `review/layer_3_egg_cards_contact_sheet.png` — final transparent inventory cards.
- `review/layer_3_geometry_contact_sheet.png` — front/back geometry before texturing.
- `review/layer_3_textured_models_contact_sheet.png` — front/back selected textured GLBs.

## Roblox publishing

All eight eggs and both realm stands were published group-owned on 2026-08-25. The resolved model,
raw MeshId, Decal, and ImageId records live in `scripts/egg_assets.json` and
`scripts/layer3_stand_assets.json`; neither registry contains a pending asset.

The reusable models are `heaven3_egg_stand` and `hell3_egg_stand`. In Studio, replace the visible
assembly inside each existing Layer 3 area stand (`Lava`, `Ice`, `Grass`, `Desert`) with the matching
realm model. Preserve each stand's name, transform, attributes, tags, and `UIanchor` so
`EggStandPlacement` resolves each fixture through the live Layer 3 `realm_area_eggs` matrix. The
Layer 3 fixtures now use their realm-specific stand visuals and published egg records; do not add a
second set of stands and do not modify the Layer 2 originals.
