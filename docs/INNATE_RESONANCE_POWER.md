# Innate Power — "Resonance" (working name)

**Status:** spec / design (not built). Working id `resonance`; rename freely.

## Concept

Every player owns ONE innate power from the moment they spawn — a **natural-origin, active-cast,
farming** power. Cast it and a **boost pulse radiates around the player**, slamming the `Boost`
attribute on every nearby crystal toward max so your pets shred the whole patch. It is the
new-player's first "press a button → something good happens," available **before combat unlocks at
level 5**, and it is the power the tutorial's "cast your power" step fires off.

### Why this design (decisions already made)
- **Active cast, not a toggle** — so the tutorial "cast" lesson can never soft-lock (toggles like
  Swift/Magnet don't fire `power_cast`). The "leave it running while farming / drop it for combat"
  feel comes from the **focus economy**, not a literal toggle (see Focus below).
- **Farming, not combat** — heal/rally powers are dead weight before level 5. A crystal-boost works
  in the level 1–4 phase where the cast lesson lives.
- **Reuses the existing Boost SSOT** — no new effect. `configs/breakables.lua` `M.boost` already
  defines a per-node `Boost` attribute (0→`max`=100): clicking a node you're mining builds Boost,
  it decays when you stop, and higher Boost amplifies YOUR pets' damage on that node (up to
  `max_damage_bonus` = +100% at full). Resonance is a **mass-click in an AoE** — it sets/adds Boost
  on every breakable in range; the existing pet-damage amplification + decay do the rest.

## Mechanic

On cast: find every alive breakable within `radius` of the player's character (filter
`PowerService.breakablesAlive()` by distance — this is a SPATIAL AoE, distinct from the
engaged-crystals path #174 uses) and bump each one's `Boost` attribute by `amount` (clamped to
MaxBoost). Pets already in the patch immediately hit harder; Boost decays normally afterward, so a
sustained farm = re-cast on cadence.

## Four knobs → enhancement axes (all enhanceable)

| Knob          | Power field      | Enhancement axis | Placeholder | Notes |
|---------------|------------------|------------------|-------------|-------|
| Boost amount  | `magnitudeBase`  | magnitude        | full (100)  | slam in-range nodes to max on cast |
| Radius        | `radiusBase`     | **range**        | ~25 studs   | spatial AoE; add the family to `range.families` so the `range` enhancement scales it (same machinery as Magnet/Cataclysm — confirmed in `configs/powers.lua`) |
| Cooldown      | `rechargeBase`   | recharge         | ~6 s        | deliberate press, not spam |
| Focus cost    | (focus cost)     | efficiency       | moderate    | sustainable while farming; competes with combat powers |

All values are **placeholders for live tuning** ("play around with what it looks like"). The "perma
while farming" target is achievable purely via enhancements (recharge↓ + efficiency↓) reaching a
cast-on-cooldown rhythm that focus regen sustains — never a literal always-on toggle.

## Focus economy (the "drop it for combat" dynamic)

Resonance draws the same Focus pool combat powers use. While farming, focus regens enough to re-cast
and keep the patch lit (effectively perma). Walking into combat, combat powers compete for that
focus — so you naturally stop boosting to bank focus. The "turn it off to go into combat or you
won't recover" behavior **emerges from the resource**, no toggle needed, and the cast stays active.

## Ownership — innate, outside the build pool

Resonance is **always owned**, granted at spawn, and does **NOT** consume one of the (up to 6)
level-granted power slots. It lives outside the archetype pick pool (`configs/archetypes.lua` power
pools) — it's a baseline everyone has, like a starting kit. Grant path: stamp it into the player's
owned-powers set at join (a `PowerService` grant-at-spawn, flagged `innate = true` so it's excluded
from slot accounting and from the level-up picker).

## Hotbar — auto-bound to slot 1 (power bar position 1)  ⟵ requested

Resonance **auto-binds to hotbar slot 1** for every player, so a brand-new player has it on the bar,
ready to press, with no setup. Implementation: `configs/hotbar.lua` `default_binds` is currently
`nil`; set the slot-1 default (or special-case the innate) to
`{ slot = 1, type = "power", target = "resonance" }`. It should re-assert if slot 1 is empty so a
fresh profile always has it; players may rebind other slots freely, but the innate defaults to 1.

## Tutorial integration

The expanded tutorial's **"cast your power"** step (farming phase, pre-combat) completes on
`power_cast` from Resonance — guaranteed to fire because it's an active cast we control and it's
already on the bar at slot 1. (The later level-up "pick a power" step is separate, completing on
`power_selected`, so toggle picks never block it.)

## Build seams (when we implement)

- **`configs/powers.lua`** — new `resonance` effect_kind: a new family (e.g. `farm_boost`) with
  `magnitudeBase` (boost amount), `radius`/`radiusBase` (AoE), recharge/focus; register its family in
  `accuracy`/`range` family gates as needed (`range.families += farm_boost`).
- **`PowerService`** — handle the `farm_boost` family in `_applyEffect`: `breakablesAlive()` filtered
  by distance-to-player ≤ `effective.radius`, bump each node's `Boost` attribute by
  `effective.magnitude` (clamped to its `MaxBoost`). Reuses the SSOT; no new attribute.
- **Grant-at-spawn** — owned + innate flag; excluded from slot accounting + the level picker.
- **`configs/hotbar.lua`** — slot-1 default bind to `resonance`.
- **`configs/powers.lua` icon/fx** — `power_icons`/`power_fx`/`power_descriptions` entries (natural
  origin disc + an AoE cast-burst tell + a one-line derived description).
- **Enhancement compat** — add `resonance`'s family to the magnitude/recharge/efficiency/range
  enhancement maps so slots aren't no-ops (the audit pattern in [[enhancement_axes]]).
- **Spec/headless** — a small spec pinning: cast bumps in-range nodes' Boost, ignores out-of-range,
  respects MaxBoost clamp, and the four axes resolve through `PowerStats`.

## Open / to confirm at build time
- Final name + natural-origin theming (disc colour, fx).
- Exact placeholder values once we feel it live (radius / amount / cooldown / focus).
- Whether the combat-side **Rest (heal + team-rally)** power becomes a second innate at level 5 (its
  own later spec) — out of scope here.
