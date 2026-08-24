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

### Hell 3

- `building_dreadspire_watch_shrine.png`
- `building_obsidian_gatehouse.png`
- `flora_dreadthorn_tree.png`
- `flora_abyss_orchid.png`
- `flora_violet_bramble.png`
- `flora_blood_reed.png`
- `flora_ember_thorn_cluster.png`
- `flora_obsidian_spike_plant.png`

`layer_3_contact_card.png` is the derived review sheet. The independently generated originals are
the only inputs intended for Meshy.

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
