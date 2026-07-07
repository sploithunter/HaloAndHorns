# Support & Control Pet Ladder — Expansion Proposal

*(Jason, 2026-07-07: "we 100% have support pets… we can quickly expand those with the current
pets we have, making progressively stronger pets through Layer 2." This is that proposal —
no new art required; every pet named below already exists in pets.lua with a role in
configs/pet_roles.lua.)*

## What exists today

- **Support is broad**: ~25 pets carry `by_type = "support"` with configured auras
  (heal / defense / offense / luck / yield / haste / drain / curse / shred kinds in
  `pet_roles.support_auras`).
- **Control is thin**: 3 controllers — `meerkat` (Desert, full 10s hold), `prism_fox`,
  `dread_fox`.
- **Both roles now matter TWICE**: pets fight for you AND appear as enemy invaders with
  role-faithful kits (bc9a0a7) — every support/control pet built enriches both sides.

## The two gaps

1. **No progression ladder.** Aura strength is FLAT across layers: every healer heals
   `fraction = 0.08`, every defense buffer grants `53.3`, every offense buffer ×1.1667 —
   a Layer-2 hatch is a cosmetic upgrade, not a power one. Layers should make support
   *stronger*, the same way damage pets climb base_power.
2. **9 hell auras are "pending build."** The config rows exist (drain / curse / shred /
   regen-denial kinds, lines ~218-228 of pet_roles.lua) but their combat mechanics aren't
   all wired — frostblight_lamb, wraith_dove, rime_scarab, rimewither_sprite,
   frostbrand_salamander, gloom_jackal, frostdust_camel, dread_couatl, rimewraith_dragon.

## Proposal

### A. Tier the aura strength by LAYER (config-only, one afternoon)

Add a `layer_mult` ladder to pet_roles (or fold per-pet): base world = 1.0, Layer 1 = 1.35,
Layer 2 = 1.8 (tunable). Applied to the aura's magnitude axis only (fraction / amount /
mult-bonus-above-1), never duration/interval — stronger, not spammier. Example ladder:

| Kind    | Base (world)        | Layer 1              | Layer 2              |
|---------|---------------------|----------------------|----------------------|
| heal    | 0.08/tick (cherub)  | 0.11 (aurora_dove)   | 0.14 (L2 healers)    |
| defense | 53 (penguin)        | 72 (prism_scarab)    | 96 (L2 shields)      |
| offense | ×1.17 (emberimp)    | ×1.23 (lumen_salam.) | ×1.30 (couatl ×1.25 today — becomes the L2 anchor) |
| curse   | —                   | ×0.85 light          | ×0.70 (dread_couatl, already configured strongest) |

Rarity within a layer stays the existing knob (apex couatls > commons).

### B. Wire the pending hell kinds (the real build work, ~2 sessions)

Priority order by gameplay value:
1. **drain** (leech-heal — hell's answer to heaven's heal; damages the enemy AND heals the
   squad; frostblight_lamb + wraith_dove) — hell farms by fighting, so this IS hell's healer.
2. **shred** (armor-shred, rime_scarab) — consumes the existing Armor/OnHitEffects seam.
3. **curse** family (rimewither/frostbrand/gloom/frostdust/dread_couatl) — one executor,
   five pets: enemy deals ×mult; reuse the EnemyExposeMult pattern in reverse
   (EnemyDamageDealtMult consumed in _hitPet).
4. rimewraith_dragon freeze-AoE (secret-tier showpiece — reuses the root/hold executor).

### C. Fill the CONTROL ladder (config + role flips, cheap)

One controller per origin per layer is the CoH-shaped goal. Candidates from the existing
roster (flip `by_type` + add a control aura — root first, hold at apex):
- Base: meerkat (hold, exists) → add a GRASS rooter (bunny stays luck; use a mid-rarity
  grass pet, e.g. tortoise-line if present) and an ICE rooter (penguin stays defense).
- Layer 1: prism_fox (exists — wire its control aura if pending).
- Layer 2: dread_fox (exists) + one heaven counterpart.
Control auras ride the SAME PetRootedUntil/PetHeldUntil attributes the enemy executors use —
badges and mez semantics come for free.

### D. Enemy-side dividend (free)

Every pet above invades the opposing realm with its role kit: hell bands gain drain-healers
worth focusing; heaven bands gain controllers that pin. No extra work — the invader synth
already reads by_type + support_auras.

## Suggested order

1. A (ladder) — immediate felt progression for Layer-2 hatching.
2. B1 drain + B3 curse — hell identity.
3. C controllers — one per origin.
4. B2 shred + B4 dragon freeze — polish.
