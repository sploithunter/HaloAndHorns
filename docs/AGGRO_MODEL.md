# Aggro Model — one symmetric "aggro game" for pets and enemies

Status: **Phase 1 SHIPPED & live-verified** (the v2 threat-table model is permanent —
`configs/aggro.lua` `enabled = true`). Source of truth for the combat-targeting refactor.

The legacy split this replaced — enemy had a real pet-keyed threat table, but engagement + `InCombat`
ran off a coarse per-enemy **player flag** (`entry.aggroPlayerName`), which caused the farm-lock,
parking, and despawn-churn — **is fixed and tested:** `InCombat` is now DERIVED per-pet from real
threat (a parked, non-damaging invader decays off and farming resumes on its own), and the enemy-side
disengage/despawn rides the always-on decay — passive threat is gated to `passive_range`, so an
abandoned enemy bleeds below the floor → disengages → patrols → idle-despawns instead of hanging
"in combat" forever. Remaining for Phase 2: taunt / fear / rage and enemy movement polish (below).

## Premise
Combat is **one aggro game, played symmetrically by both sides.** Every combat unit — pet *or*
enemy — keeps a **decaying threat table** toward the units on the other side. Focus-fire, taunt,
fear, rage, peeling, and "should I farm or fight" all *fall out* of how threat is added and bled.
Nothing is special-cased that the table can already express.

## The threat table
Each unit `U` holds `threat[other] = value`, decaying over time. `U` **focuses** (chases/attacks)
the top entry. The same table type lives on pets and enemies.

## Threat events (symmetric — the whole ruleset)
| Event | Effect |
|---|---|
| **A damages B (direct)** | `B.threat[A] += big` (∝ damage) |
| **…splash to B's team** | each of B's allies within `splash_radius`: `threat[A] += small` (~25% of direct). Hit one, the group notices. |
| **AoE: A hits B, C, D** | just N direct hits + each one's splash — emergent, no special case |
| **B receives damage** | the *same* table update viewed from B's side — receiving damage **is** the aggro |
| **proximity seed** | an *approaching* hostile within `seed_radius` adds a small trickle, so a fight starts before first hit; a parked/unreachable foe that deals no damage decays off → farming resumes (the farm-lock fix) |
| **decay** | every entry bleeds toward 0 each tick (distance-scaled, as today) |

## Focus & stance rules (derived, not flagged)
- **Attack** the top-of-table entry while it's above `engage_floor`.
- **Negative top ⇒ flee** that unit (see Fear).
- **Empty / below `exit_floor` ⇒ disengage** → pet returns to farming, enemy returns to patrol.
  (`engage_floor` > `exit_floor` = hysteresis, so pets don't flap in/out of farming.)
- **`InCombat` is derived, per-pet**: a pet is "in combat" iff it currently has a hostile above
  `engage_floor`. **Squad cohesion is emergent**, not a separate mode — teammate-splash ups the
  whole team's aggro a little when any pet is hit (so they converge) and the hit pet a lot (so it
  focuses hardest). No squad flag; no global player `InCombat`.
- **Both sides are teams.** A "team" for splash is just a co-located group on the same side — your
  pet squad **and** an enemy patrol band, identically. Attack one band member and the whole band
  aggros a little while the struck one aggros a lot; the band reacts as a pack. The code never
  branches on pet-vs-enemy — `A` and `B` are roles, not types.

## Powers are just aggro
- **Taunt** — pin the taunter to the **top** of the target's table for a duration (reuse the
  existing `tauntCfg.lead ×` reinforce).
- **Fear** — the feared unit's entry toward the **source** goes **negative** for a duration → it
  flees that source, then decays back to 0. (Today fear is only flavor text in `PowerDescribe` —
  this wires it for real.)
- **Rage** — a **tipping point**, not a buff. Each unit has an **aggro heat** (how much threat is
  currently directed *at it* / how hot the fight is on it). Below the tip it does its role; once
  heat crosses `rage_tip`, it **snaps** — flips to attacking with a threat/damage amp, then calms
  back to its role when heat decays below `rage_calm` (hysteresis). *(confirm: heat = threat-on-me
  vs. my-own-accumulated threat — spec assumes threat-on-me: "cornered unit goes feral".)*

## Roles & phasing
- **Phase 1 — all pets attack** via the core table (uniform, no role-motion). Ships the symmetric
  model + derived `InCombat`; fixes the farm-lock, parking, and churn.
- **Phase 2 — support/control pets**: default to their support role (auras / heals / control)
  while calm, with the **rage tipping point** above. So a support pet buffs/heals/controls until
  the fight turns on it, then loses its mind and brawls — and a support *invader* is never a
  do-nothing punching bag.

## Configuration — symmetric base × per-side knobs (`configs/aggro.lua`)
Everything is configurable, and **per-side**: a symmetric `base` block plus `pet` / `enemy`
multipliers over it. We start fully symmetric (all mults `1.0`); `enemy.threat_mult` (etc.) is the
artificial difficulty dial — crank enemy aggro up or down without touching the pet side.

```lua
return {
  enabled = true,                 -- A/B flag: false = legacy aggroPlayerName path (byte-identical)
  base = {                        -- symmetric defaults, read by BOTH sides
    threat_per_damage = 1.0,
    splash_frac = 0.25, splash_radius = 40,   -- hit one, its team aggros 25% within radius
    seed_rate = 2, seed_radius = 60,          -- approaching hostile seeds a little threat
    engage_floor = 5, exit_floor = 1,         -- hysteresis (enter > exit, no flapping)
    decay = { per_second = 4, start_range = 90, chase_mult = 3, leave_area_mult = 6 }, -- reuse curve
    proximity = { floor = 6, range = 30 },    -- existing proximity floor
  },
  pet   = { threat_mult = 1.0, decay_mult = 1.0, splash_mult = 1.0, seed_mult = 1.0 },
  enemy = { threat_mult = 1.0, decay_mult = 1.0, splash_mult = 1.0, seed_mult = 1.0 },
  taunt = { lead = 3, interval = 3 },         -- reuse existing reinforce
  fear  = { duration = 3, magnitude = -50 },  -- Phase 2 wiring; knob staged here
  rage  = { tip = 200, calm = 80, amp = 1.5 },-- Phase 2 (heat = threat-on-me)
}
```
Effective value = `base[x] * side.<x>_mult`. ConfigLoader needs a matching `_validateAggroConfig`
**in the same commit** (config-schema isn't in CI — only Studio boot catches a mismatch).

## What this replaces in code
- `entry.aggroPlayerName` player flag + per-player `InCombat` boolean → **derived per-pet**.
- `_assignPetTargets` priority modes (assist > most-aggro'd > nearest) → **pet threat-table top**
  (assist/taunt still pin the top).
- Fear flavor text in `PowerDescribe` → real negative-aggro + flee.
- Keep & extend the enemy's `entry.aggro` (decay + passive Threat-stat + proximity + taunt) with
  the **damage event** and **splash** inputs.

## Integration points (verified in code)
- **pet → enemy damage** already flows through `EnemyService:AddAggro(model, key, amount)` (public,
  called from the pet mining/attack path) → credits `entry.aggro`. *Add splash to the band + the
  `enemy` side mult here.*
- **enemy → pet damage** flows through `EnemyService:_hitPet(...)` (pets use `PetEndurance`, not HP).
  *Credit the pet-side table + squad splash + `pet` side mult here.*
- **`InCombat` consumers**: `AutoTargetService:733` (`if player:GetAttribute("InCombat")` → farm
  no-ops) and `AreaMusicController` (combat music). Both fix at once when InCombat is derived
  honestly. InCombat is currently SET in the combat-stance block (~`EnemyService:3700`) from
  `aggroPlayerName`.
- **pet target** currently `_assignPetTargets` priority modes (assist > most-aggro'd > nearest) →
  replace with pet-table top (assist/taunt still pin; empty table falls back to nearest-in-seed).

## Phase 1 build plan (symmetric core, flag-gated, A/B in Hell-2 grass)
1. `configs/aggro.lua` (above) **+ `ConfigLoader:_validateAggroConfig`** same commit.
2. `src/Shared/Game/AggroModel.lua` — pure math: `creditDamage`, `splash`, `proximitySeed`,
   `decay` (reuse AggroLeash curve), `top`, `engaged` (hysteresis). **+ headless spec.**
3. Pet-side threat tables — server store keyed by pet model (`_petThreat[pet]`), cleared on
   down/despawn. (Enemies already have `entry.aggro`.)
4. Route damage both ways at the two sites above; add splash + proximity seed; apply side mults.
5. Derive focus + engagement from tables: enemy "engaged" = valid reachable top-threat pet (not a
   perception flag); pet target = its table top. Disengage at `exit_floor`.
6. Derive `InCombat` honestly in the stance block: a player is InCombat iff ≥1 pet holds a hostile
   above `engage_floor`. Parked non-damaging enemy → no threat → farming resumes (**the farm-lock fix**).
7. Gate all of it on `aggro.enabled` — off = exact current behavior (regression-safe A/B).
8. Despawn unchanged — now a pure safety net that should rarely fire on engaged enemies.

## Phase 2 (after Phase 1 proves out)
Support/control pets default to their role with the **rage tipping point**; wire **fear**
(negative + flee). Per-pet farm-while-others-fight if Phase-1's squad-level InCombat isn't granular
enough.

## Confirmed / assumed
1. Rage heat = **threat directed at the unit** ("cornered → feral"), not own accumulated threat.
2. **Phase 1 = uniform-attack for all pets**; support/control rage tipping point = Phase 2.
3. Numeric values defaulted above; calibrate against live fights.
