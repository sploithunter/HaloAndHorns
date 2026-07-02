# Pet Realm — S-Tier Pet & Power Combinations

A menu of high-level pet kits built by **composing orthogonal combat axes**, not by stacking bigger
numbers. The whole point is **build diversity** and **team synergy**: individually-fine pets that
*combine* into something stronger. This doc is the design SoT for which combos exist, which are
built, and the config shape to assign each to a purpose-built pet.

## The orthogonal axes (the toolbox)

Every pet's attack is a point in this space. They **compose** — any geometry × any modifier works.

| Axis | Config | Values / knobs | Where it lives |
|---|---|---|---|
| **Hit geometry** | `attack_targeting` | `single` / `targeted_aoe` / `aura` | spawn → `AttackTargeting` |
| **AoE tuning** | `attack_aoe` | `splash_radius`, `splash_fraction`, `max_targets` | per-pet override of global `pet_aoe` |
| **Burn (DoT)** | `attack_dot` | `fraction`, `tick`, `duration` | the ticking damage; composes with any geometry |
| **Spread (contagion)** | `attack_dot.spread` | `radius`, `interval`, `max` | makes the burn jump enemy→enemy |
| **Control** | `attack_control` | `kind` (slow/root/hold), `factor`, `duration` | on-hit; reuses `RootedUntil`/`HeldUntil`/`SlowUntil` |
| **Shred (vulnerability)** | `attack_debuff` | `vulnerable`, `duration` | on-hit; reuses `VulnerableMult` (team amp) |
| **Element / origin** | `element` map | lava/grass/ice/… | resonance, VFX theming |
| **Target priority** | `target_priority` | closest/furthest/strongest/weakest/aggro/team-threat | per-pet override |

On-hit modifiers (`attack_control`, `attack_debuff`) apply to **every enemy the swing touches** — so
pairing them with `targeted_aoe` geometry gives **AoE control / AoE shred** for free.

---

## Built — the Trinity + Bonfire

These four are live in the codebase as opt-in, config-driven kits (inert until a pet declares them).
They reuse existing enemy-side consumers, so nothing needs special-casing downstream.

### 1. Contagion / AoE-Contagion — "the Plague" ✅
`targeted_aoe` (geometry) + `attack_dot.spread` (contagious burn). The swing splashes and ignites a
cluster; each ignited enemy then hops the burn onward. `single + spread` = a pure creeping plague.

```lua
attack_targeting = "targeted_aoe",
attack_dot = { fraction = 0.25, tick = 1.0, duration = 4, spread = { radius = 8, interval = 1.5, max = 4 } },
attack_aoe = { splash_radius = 14, splash_fraction = 0.6, max_targets = 5 }, -- optional
```

### 2. Control — "the Anvil" ✅
On-hit slow / root / hold. Holds the pack **in place** — inside the AoE, inside the plague. The
canonical partner to every DoT/AoE pet. On a `targeted_aoe` pet it locks the whole splash.

```lua
attack_control = { kind = "slow", factor = 0.5, duration = 3 }, -- slow|root|hold
```
- `slow` — graded speed cut (`factor` 0–1); pack still drifts but stays parked.
- `root` — speed 0, still attacks.
- `hold` — full mez (can't move OR attack).

### 3. Shred — "the Amplifier" ✅
On-hit vulnerability: the enemy takes **+X% from everyone** (a team multiplier, not this pet's
output). Doesn't kill — makes the *rest* of the squad melt the target. Keeps the stronger of any
active shred, so it composes with power shreds without compounding.

```lua
attack_debuff = { vulnerable = 0.30, duration = 4 }, -- enemy takes +30%
```

### 4. Bonfire — aura + DoT ✅
`aura` geometry + `attack_dot`: the damage field also **leaves a burn** on everything it ticks — a
persistent burning zone. A walking hazard tank.

```lua
attack_targeting = "aura",
attack_dot = { fraction = 0.3, tick = 1.0, duration = 3 },
```

> **The Trinity payoff:** an **Anvil** (hold) + an **Amplifier** (shred) + a **Plague** (contagion)
> are three S-tier pets that combine into a kill-box: the pack is held in the fire, taking +X% the
> whole time, while the plague spreads. That's diversity across four axes at once.

---

## Designed — ready to build (ideas)

Not yet wired; each is a small, well-scoped add on the same seams. Listed roughly by cost.

### 5. Execute / Reaper — threshold finisher
Below `threshold` of max HP, deal the rest (instant reap of the wounded). Pure math already exists
and tested (`OnHitEffects.executeBonus`); needs the on-hit hook to read enemy `HP`/`MaxHP` and apply
the bonus + a floating number. Cleans up what the aura/plague leaves behind.
```lua
attack_execute = { threshold = 0.15 }, -- reap enemies under 15% HP
```
**Cost:** one combat hook (math done). **Pairs with:** AoE, Bonfire.

### 6. Leech / Lifesteal — sustain
A fraction of damage dealt heals the squad (or chips downed pets' lockout). Lets a comp run with no
dedicated healer. **Cost:** route dealt → a pet-heal path (small new seam). **Pairs with:** aura.

### 7. Chain-lightning — bounce
Instant arcs to N nearby enemies with damage falloff — a *second* flavor of spread that reads
totally different from contagion (burst, not DoT). **Cost:** moderate (new fan-out + falloff + VFX).

### 8. Time-bomb plague — delayed nova
A mark that **spreads** (contagion) and **detonates** for an AoE burst when it expires. Combines
contagion + execute + nova. **Cost:** moderate (detonation on burn-expire). **Capstone-flavored.**

### 9. Summon — minions / turrets
A pet that spawns temporary add-pets or turrets. Summon capstones already exist for *powers*; making
it a *pet trait* is the big one. **Cost:** high (lifecycle, ownership, caps). **True capstone.**

---

## Implementation notes

- **Opt-in & inert:** a pet has none of these unless it declares the field; all default off. Assign
  by dropping the config block on a purpose-built pet — no other wiring.
- **Reuses existing consumers:** control → `RootedUntil`/`HeldUntil`/`SlowUntil`+`SlowFactor`;
  shred → `VulnerableMult`/`VulnerableUntil` (same seam the powers use). No parallel systems.
- **Pure math** lives in `src/Shared/Game/OnHitEffects.lua` (slow/shred/execute) + `DamageOverTime`
  + `PetTargeting`, all headless-tested.
- **Badge SSOT:** the inventory card + squad HUD ring derive from `attack_targeting` (+ a contagion
  spread-marker via `PetTargeting.isContagious`). New visible modifiers (control/shred markers) are a
  small follow-up if we want them to read on the card — flag when assigning the first pet that uses
  them.
- **Balance dials** are all per-pet, so "a better/longer/harder" version of any kit is a config edit.

## Critical files

- `src/Shared/Game/OnHitEffects.lua` (+ spec) — slow/shred/execute math.
- `src/Server/Services/AssetPreloadService.lua` — stamps `attack_*` config → model attributes at spawn.
- `src/Server/Services/PetFollowService.lua` — `stampBurn` / `burnProfile` / `applyOnHit` (primary + splash).
- `src/Server/Services/EnemyService.lua` — `_contagionPass`, `_auraDamagePass` (Bonfire), slow in movement.
- `configs/combat.lua` — global `pet_aoe` / `pet_contagion` / `pet_aura` defaults.
