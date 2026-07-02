# Hatch Luck & Pacing

Status: current (locked 2026-06-12). Owner: configs/pets.lua `gamepass_modifiers` +
`simulateHatch`; specs in `tests/headless/specs/hatch_luck.spec.luau`; simulator in
`scripts/hatch_progression.luau`.

## The luck formula (staged channels)

`simulateHatch` computes one **earned** luck multiplier from additive terms, then routes
it through per-stage channels so any product/event can target one outcome without
touching the others:

```
earned  = 1.0 (base)
        + 0.3 x log2(1 + level/3)            -- level: diminishing-doubling curve
        + 2.0 x completion^2.5               -- index: CURVED collection bonus
        + luckBoost                          -- bunny auras, powers, events (additive fractions)

species roll   : earned (+1.0 if luck gamepass)      -- full potency, paid bonus lands HERE only
golden/rainbow : 1 + (earned - 1) x 0.5              -- variant damping (weight knob)
huge           : hugeLuckBoost only                  -- fractional attempts, separate jackpot
```

Every term is additive into `earned`; **nothing multiplies over the player's grind**
(the only multiplicative path left is the dev-only `test_mode.super_luck`).

The **lucky-server / creator-presence "devluck"** (`ServerLuckBuff`) is the exception that DOES
multiply: it's not folded into `earned` — `simulateHatch` rolls the whole hatch `devLuck` times
(fractional attempts: 2.5 = 2 rolls + a 50% chance of a 3rd) and keeps the rarest. Skips fixed-odds
eggs.

## Why the index bonus is curved (exponent 2.5)

Jason: "20% of an index is super easy... 90% is much more difficult than 80% — we need
to curve it." Fit empirically from a simulated 25k-hatch journey (real `simulateHatch`,
round-robin across the 5 world eggs, luck feedback live per hatch):

| Hatches | 50 | 250 | 1,000 | 5,000 | 25,000 |
|---|---|---|---|---|---|
| Index completion | 27% | 50% | 68% | 80% | 95% |

Completion is ~log-linear in effort, so `completion^2.5` makes the **bonus track
effort**: the free 40% (from leveling) pays ~10% of max_bonus; 80% pays ~57%; the grind
past 90% earns the rest. Exponent sweeps (1.0 / 2.5 / 3.5) showed the curve barely
changes time-to-complete — completion is roll-bound, not luck-bound — so this is a
**feel knob** (where luck sits along the journey), and pacing is owned by the economy.

## Pacing facts (very_fast preset, 8-egg batches)

- One max batch ≈ 3.45s → **~8,300 eggs/hour** if eggs were free.
- Pure-hatch wall clock: 5k eggs ≈ 36 min; 10k ≈ 1.2h; 25k ≈ 3h; 50k ≈ 6h.
- A level-7 player hits ~92% index in ~1.2h of free hatching → **coin cost vs mining
  income is the real weekly-hours lever**, plus index size (every added
  species/variant/huge stretches the same curve for free).

## Locked balance baselines (ice egg, 20k+ trials)

| State | Luck | Golden | Rainbow |
|---|---|---|---|
| L7, 20% index, no bunnies | 1.56x | 6.3% | 0.58% |
| L7, 20% index, 3 rainbow bunnies | 2.31x | 8.0% | 0.80% |
| **L7, 90% index, 3 rainbow bunnies (ENDGAME FLOOR)** | **3.81x** | **~12%** | **~1.2%** |
| L7, 90% index, 10 rainbow bunnies (full hatch loadout) | 5.56x | ~16% | ~1.5% |

The endgame floor **assumes the bunnies**: by 90% index a player has rainbow bunnies
(they are index entries themselves) and any index-chaser equips them. Price all future
luck products against the bunny rows, not the no-bunny ones.

## Locked design rules

1. **Paid luck is additive, species-only.** `luck_gamepass_bonus = 1.0` adds a flat
   +1.0 to the species channel: a fresh player gets exactly the advertised "2x"; the
   10-bunny endgame goes 5.56x → 6.56x (not 11x); golden/rainbow rates do not move at
   all (paid luck stays out of the tradeable variant supply). Spec-pinned.
2. **Variant damping** (`variant_luck_weight = 0.5`): golden/rainbow see half the
   earned multiplier — species luck (the index chase) stays steep, variant inflation
   is tamed.
3. **Luck auras live on support-role pets only** (0.45 aptitude). The tradeoff IS the
   design: slotting bunnies costs combat/mining power. The bunny stays easy to hatch —
   the **rainbow variant** is the rarity gate (x1.5 aura). Watch two erosion vectors:
   colorado (ranged + luck aura, acceptable as a limited meet-egg flex, not a
   precedent) and **equip-slot growth** (at 10 slots a 3-bunny tax is 30%, not 100% —
   slots, not bunny rarity, control the long-term tradeoff).
4. **Separate channels stay separate.** Golden/rainbow boosts (`goldenLuckBoost`,
   `rainbowLuckBoost`) are their own products/events ("2x golden weekend"); huge luck
   is fractional attempts on the jackpot stage only.

## The simulator

`mise exec -- lune run scripts/hatch_progression.luau` — runs the REAL
`configs/pets.lua simulateHatch` fresh from disk (no Studio, no edit-VM cache):
variant-rate spot checks (bunnies/gamepass on/off), full index journeys with live luck
feedback, gate checks to 50k eggs with wall-clock hours, and a curve-exponent sweep.
Rerun after any catalog or knob change; retune the numbers above if they drift.
