# Layer 3 concept review

Independent low-poly reference renders for Meshy review. Approved assets may proceed through the
geometry-first Meshy trial documented below.

## Canonical visual split

- **Heaven 3 — The Empyrean Bloom:** organic celestial garden; living emerald, jade, cyan-white
  light, luminous petals, and roots. No gold or yellow metal, and no dominant prismatic/crystal
  treatment already owned by Heaven 2.
- **Hell 3 — The Dreadspire:** jagged demonic wastes and ruined infernal architecture; obsidian,
  charcoal, hard crimson, and bruise-violet. No rot, swamp, putrid, or decay treatment already
  owned by Hell 2.

## Review set

Every source image is generated independently as one centered asset on plain white, without a
ground plane, cast shadows, text, people, or surrounding props.

### Heaven 3

- `building_empyrean_bloom_shrine.png`
- `building_living_root_pavilion.png`
- `flora_empyrean_hibiscus.png`
- `flora_jade_lantern_bloom.png`
- `flora_halo_fern.png`
- `flora_luminous_canopy_tree.png`
- `flora_petal_spire.png`
- `flora_rootlight_vine.png`
- `flora_celestial_bellgrass.png`
- `flora_moonpetal_bush.png`
- `flora_lumen_moss_cushion.png`
- `flora_wingleaf_reed.png`
- `flora_pearlroot_anemone.png`
- `flora_emerald_ribbon_shrub.png`
- `fauna_bloomwing_butterfly.png`
- `fauna_pearlback_snail.png`

### Hell 3

- `building_dreadspire_watch_shrine.png`
- `building_obsidian_gatehouse.png`
- `flora_dreadthorn_tree.png`
- `flora_abyss_orchid.png`
- `flora_violet_bramble.png`
- `flora_blood_reed.png`
- `flora_ember_thorn_cluster.png`
- `flora_obsidian_spike_plant.png`
- `flora_razorleaf_fan.png`
- `flora_gloom_pitcher.png`
- `flora_crimson_watcher_bloom.png`
- `flora_dreadspire_ribbon_grass.png`
- `flora_violet_hook_bloom.png`
- `flora_ironroot_crawler.png`
- `fauna_dreadwing_beetle.png`
- `fauna_obsidian_hornback_lizard.png`

`layer_3_contact_card.png` is the derived review sheet. The independently generated originals are
the only inputs intended for Meshy.

`layer_3_flora_fauna_expansion_contact_card.png` covers assets 17–32: twelve additional flora
props and four ambient-fauna props. These fauna are environmental dressing, not collectible pets
or combat units. They must not receive health, targeting, damage, drops, or other combat hooks;
their eventual motion is lightweight ambient wandering/bobbing with optional simple wing or limb
movement. The expansion raises the non-building concept pool from 12 to 28 assets (2.3×).

See `PROMPTS.md` for the exact final prompt used for every selected image.

## Meshy production budgets

- Repeatable small flora: 4,000 triangles or fewer.
- Trees: start at 4,000 triangles; increase only when silhouette review justifies it.
- Buildings: approximately 9,000 triangles, keeping each asset below the 10,000-triangle direct
  import lane.

## Geometry trials

The first geometry-only trial uses `heaven/flora_halo_fern.png` with Meshy Smart Topology T2 at a
4,000-face target. It returned 4,098 triangles for five credits and passed the strict mesh-integrity
gate with no boundary, non-manifold, zero-length, or zero-area geometry. See
`meshy_trials/halo_fern_t2_4000_trial.json` and the accompanying four-view review image. No texture
was requested until that geometry received visual approval.

The approved geometry was then textured through Meshy's Retexture API using the original concept
as its 2K style image. The ten-credit texture task consumed the exact successful geometry task,
retained its 4,098 triangles, and passed the same integrity gate. See
`meshy_trials/halo_fern_t2_4000_texture_trial.json` and
`meshy_trials/halo_fern_t2_4000_texture_review.png`.

The first building trial used the Empyrean Bloom Shrine. Three untextured T2 attempts at changed
targets all contained large open boundaries; the 9,300-target version best preserved the doorway
and silhouette, so it was repaired locally rather than rerolled again. The repaired GLB is one
connected, watertight 9,980-triangle component below the direct-import ceiling. Meshy retextured
that exact uploaded GLB at 2K without changing its topology. See
`meshy_trials/empyrean_bloom_shrine_t2_9300_trial.json`,
`meshy_trials/empyrean_bloom_shrine_t2_9300_texture_trial.json`, and the accompanying four-view
review sheet.

## Flora and ambient-fauna production batch

Assets 17–32 were produced as 2K textured GLBs through the same geometry-first gate. Every selected
mesh is below 4,000 triangles and passes with zero boundary edges, non-manifold edges, zero-length
edges, or zero-area faces. Nine outputs passed directly from Meshy, three required conservative
local repair, and four thin/open forms required voxel closure before retexturing the exact repaired
GLB. The completed textured exports also pass the strict gate.

See `meshy_trials/layer_3_flora_fauna_production_batch.json` for task ids, hashes, selected local
GLB paths, triangle counts, repair provenance, and the 365-credit batch accounting. Review the
front/right sheets in `meshy_trials/layer_3_flora_fauna_geometry_review.png` and
`meshy_trials/layer_3_flora_fauna_texture_review.png`.

## Roblox publishing

The sixteen completed flora/ambient-fauna assets plus the Empyrean Bloom Shrine and Halo Fern were
published group-owned on 2026-08-25. `scripts/layer3_prop_assets.json` records each Model asset,
raw MeshId, texture Decal, and resolved ImageId. Eleven approved flora concepts and the remaining
three building concepts are still 2D-only production backlog and therefore have no Roblox asset
record yet.
