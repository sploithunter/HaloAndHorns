# Mission Aesthetics Research (2026-07-08)

Web-research report: how Roblox builders take modular/procedural interiors
from greybox to polished, applied to the mission tile kit.
Companion to docs/MISSION_WORLDGEN.md (M5b planning input).

(report body appended below)
## Key findings

**Two aesthetic poles among shipped procedural games:**
- DOORS/Apeirophobia/The Mimic: darkness + fog + audio HIDE repetition;
  few materials, sparse warm lights, sound does the heavy lifting.
- Dungeon Quest: bright low-poly, flat colors, bold one-palette-per-dungeon
  theming, prop CLUSTERS at room edges. (Closer to Pet Realm's look.)
- Cross-cutting tricks: per-room light-hue variation, 1-3 grime decals per
  room at random rotations, corner prop clusters beat even scatter, one
  "hero" set-piece room per mission, fog shorter than the longest sightline.

**Platform facts that shape our approach:**
- SurfaceAppearance needs UV'd MeshParts — does NOTHING for primitive Parts.
  For a part-built kit the lever is MATERIALVARIANT (PBR on the built-in
  material slot, tiles by StudsPerTile, one variant serves every part with
  that material; negligible per-part cost).
- Material Generator (released Sept 2024) generates tiling MaterialVariants
  from prompts IN Studio; sweet spot = organic tiling surfaces (mossy stone
  brick, old oak planks, cracked flagstone) — exactly dungeon needs.
- Cube 3D generate_mesh: untextured ~10k-tri props; good for silhouette
  one-offs (brazier, statue, gargoyle), wrong for exact-dimension kit
  geometry or doors.
- Future lighting makes torch interiors read but taxes low-end mobile;
  pattern: few shadow-casting hero lights per room, Shadows=false fillers.
- Official modular-kit playbook (Roblox Environmental Art curriculum):
  consistent pivots, MaterialVariant swaps per room, grunge decals to break
  tiling, character props.

**Asset sources (safe/legal):**
- Roblox-published FREE Synty packs (no ownership risk, insertable):
  Dungeon Cave & Castle Interiors 6934021345 (walls/arches/DOORS),
  Weapons & Props 6933790012, Basement & Goblin Camp 6933905899,
  Skeletons & Bones 6934081776.
- CC0 kits for Blender→GROUP upload (--creator-group 15872767 or they break
  for alt accounts): KayKit Dungeon Remastered, Quaternius Modular Dungeon,
  Kenney Modular Dungeon Kit.
- CC0 PBR textures: ambientCG / Poly Haven → group images → MaterialVariant.
- Audio (group re-upload): dungeon ambience bed, torch crackle, door creak,
  lock rattle (Pixabay/Freesound).

**Doors (canonical patterns):**
- Primitive plank door reads instantly: 4-5 vertical WoodPlanks parts with
  ±0.05 depth/color jitter + 2 cross-braces + knob/ring + dark metal hinge
  strips. Better than decal doors (decals misbehave under Future lighting).
- Swing = invisible hinge part at jamb, door welded, TweenService on
  hinge.CFrame (±105°), ProximityPrompt or touch region trigger, creak sound.
- Locked language: darker door + padlock/chains or nailed boards, prompt
  hidden or red-tinted; keyhole glow when the player holds the key.

## Prioritized punch list for our kit

(a) Pure code, live-tunable:
 1. Mission lighting state on enter/exit (tween Lighting): near-black
    Ambient, Atmosphere density ~0.35, ColorCorrection (sat -0.25, warm
    tint, contrast +0.08). Killer of the flat-light greybox signal.
 2. Torch prefab upgrade: warm PointLight + Heartbeat flicker (±15%),
    ember/smoke ParticleEmitters, 3D crackle loop; ≤4 shadow-casting
    torches per room.
 3. Plank door prefab (primitives) + hinge tween + creak; locked variant =
    padlock/chains + no prompt. Fits the 14x16 apertures.
 4. Generator variation pass: per-room torch hue, grime decals, corner
    prop clusters, fog under sightline length.
 5. Dust-mote emitter per room + ambience bed per mission.
(b) MaterialVariants: 3-4 via Material Generator first (flagstone floor,
    stone-brick wall, wood planks, rusted metal), ambientCG fallback;
    different variant/tint combos per adjacent room types.
(c) Asset harvest: Synty dungeon packs → mine doors/arches/braziers/chains/
    bone piles into kit prefabs.
(d) Cube 3D: silhouette one-offs only (brazier, statue, banner stand).

Suggested live-tune order with Jason: a1 → a2 → b → a3 → c → a4.
Note the POLE DECISION is Jason's: bright low-poly (Dungeon Quest, matches
Pet Realm) vs dark torch-lit (DOORS). Realm-flavored split is on the table:
heaven missions bright/airy, hell missions dark/torch-lit.
