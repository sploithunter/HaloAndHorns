# Layer 3 pet production

This folder owns the source concepts and audit trail for the Heaven 3 / Hell 3 pet batch.
`roster.json` is the production roster: twenty pets per realm across Fire, Ice, Grass, and Desert.

## Dragon contract

- Exactly one dragon belongs to Heaven 3 and exactly one to Hell 3.
- Both dragons are Desert-origin Secret support pets.
- Heaven's Oasis Dragon visibly heals and shields.
- Hell's Dreadglass Dragon visibly curses, shreds, and drains.
- No other Layer 3 pet may use a dragon identity or silhouette.

## Variant contract

1. Generate one Basic concept per species, independently, full-body and centered on pure white.
2. Basic concepts must contain no gold, yellow metal, brass, bronze, or gilding.
3. Inspect the Basic before creating its Golden version.
4. Golden is a recolor-only edit of that exact accepted Basic. Pose, geometry, proportions,
   expression, framing, and background are locked.
5. Remove the edge-connected white background with `scripts/remove_image_background.py` for the
   transparent inventory-card art.
6. Generate one Meshy Smart Topology T2 geometry from the Basic concept and pass the strict mesh
   integrity gate before spending texture credits.
7. Texture that identical validated geometry twice: once from Basic and once from Golden.
8. Rainbow has no authored image or mesh; it remains the runtime script treatment.

## Geometry budgets

- Common and Uncommon: 5,000 target triangles.
- Rare: 6,500 target triangles.
- Mythical: 8,500 target triangles.
- Secret dragons: 9,000 target triangles.

Every final mesh must stay below Roblox's 10,000-triangle direct-import ceiling. Changed-target
retries or local Blender repair are allowed only after the first geometry result is checked.

## Theme palettes

- Heaven 3 — The Empyrean Bloom: pearl, white, jade, emerald, cyan light, and silver-gray accents.
- Hell 3 — The Dreadspire: obsidian, charcoal, hard crimson, and bruise-violet. Do not reuse the
  blight, rot, swamp, or decay treatment already owned by Hell 2.
