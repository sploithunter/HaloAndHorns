# Archetype Lines — Overlap Matrix (index + synthesis)

Status: design (Jason + Claude, 2026-06). Index for the six line docs:
[blaster](PET_LINE_BLASTER.md) · [melee](PET_LINE_MELEE.md) · [tank](PET_LINE_TANK.md) ·
[support](PET_LINE_SUPPORT.md) · [controller](PET_LINE_CONTROLLER.md) · [dragon](PET_LINE_DRAGON.md).
Cross-refs: [roster](../PET_REALM_HEAVEN_HELL_ROSTER.md) ·
[mechanic progression](../PET_REALM_MECHANIC_PROGRESSION.md).

This doc answers "**where do the lines overlap?**" — the reason we cut the roster by archetype.

## 1. Line × origin — who hosts what

Which origin's egg fields a body of each line (★ = the origin's *lean*/identity line):

| Line | 🔥 Fire | ❄️ Ice | 🌿 Grass | 🏜️ Desert |
|---|---|---|---|---|
| **Blaster** | ★ rare + apex | uncommon (owl) | — | — |
| **Melee** | common + bruiser | common | common (+L5 badger) | L1 only (jackal) |
| **Tank** | (bruiser blur) | rare (Bear) + apex | ★ uncommon + apex | L1 only (sphinx) |
| **Support** | uncommon (salamander) | — | common+uncommon (lamb/sprite) | ★ whole egg |
| **Controller** | — | ★ uncommon + apex hybrids | — | (hell shred ≈ debuff) |
| **Dragon** | L1 | L2 | L3 + base | L4 |

Reading the columns: **Fire = damage hub** (2 melee + blaster + buff). **Ice = control+tank** (it
hosts *two* lines — control lean + the wall). **Grass = tank+support** (tank lean + heal/yield).
**Desert = pure support** (from L2). The dragon row rotates across all four.

## 2. The dragon line is the overlap map

The dragon's origin rotates by layer, so the **dragon line intersects every other line exactly once**
— it's the "sampler" that shows each archetype's ceiling:

| Layer | Dragon archetype | Overlaps line |
|---|---|---|
| L1 (Fire) | breath splash | **Blaster** |
| L2 (Ice) | melee freeze-AoE | **Controller + Melee** |
| L3 (Grass) | HP wall + aura | **Tank (+ Support via the aura)** |
| L4 (Desert) | team aura | **Support** |
| L5 (apex) | hybrid | **all** |

## 3. Hybrid slots — where two lines genuinely merge (not a foul)

These pets legitimately belong to two lines; that's design, not redundancy:

| Pet(s) | Lines merged | Why |
|---|---|---|
| Ice tank apex (Leviathan/Mammoth/Yeti) | **Tank + Controller** | a wall that AoE-slows |
| Grass tank apex (Ent) | **Tank + Support** | HP wall + heal/drain aura |
| Fire bruiser (Lion), Grass badger (L5) | **Melee + Tank** | durable melee |
| Hell desert (shred / regen-denial) | **Support + Controller** | debuffs that read as control (give→take) |
| Ice dragon (L2) | **Controller + Melee + Blaster(AoE)** | freeze-AoE wade-in |

## 4. Within-line reskin risk (ranked)

The vertical (same slot, deeper layer) collapse risk, worst first:

1. **Melee — highest.** ~20 common-melee bodies, all vanilla by design. *Fix: graft economy powers
   (the cheap escape hatch), not new combat tech.*
2. **Blaster — medium.** Fire rare vs Fire apex both "fire ranged splash" — keep them apart by
   *splash magnitude* (apex bigger + rider).
3. **Tank — low-medium.** Already silhouette-varied (stag/rhino/beetle/tortoise); Bear vs Grass-tank
   differ by verb (pull+DR vs thorns+regen).
4. **Controller — low.** Native designated power (slow); narrow line; escalates to freeze.
5. **Support — lowest.** Every body has a distinct native aura; differentiated from Common up.
6. **Dragon — lowest (mechanically).** Rig is reused but each layer's designated power differs
   completely.

So the reskin problem is **concentrated in melee** (and secondarily the plain damage commons), which
is exactly where the graftable-economy-power lever applies — and conversely **support/control/dragon
barely need work** because their designated powers already do the differentiating.

## 5. Squad-synergy overlaps (cross-line, by origin egg)

A mono-origin squad naturally pairs lines — useful for the "lots of overlap between tiers" feel:

- **Fire egg** = Melee + Bruiser + **Blaster** + offense-**Support** (salamander) → self-buffing DPS.
- **Ice egg** = Melee + **Controller** + **Blaster** (owl) + **Tank** (bear) → "wall, slow, shoot."
- **Grass egg** = Heal-**Support** + Melee + **Tank** + yield-**Support** → durable sustain.
- **Desert egg** = pure **Support** stack → the buff/economy squad.

## 6. Realm-orientation overlay — heaven farms, hell fights

Cutting *across* all six lines is a realm lean (loose, not strict — see
[support doc](PET_LINE_SUPPORT.md)):

- **🕊️ Heaven pets lean FARMING** — designated powers point at the economy (coins / drops / luck /
  yield) + survival glue (heal/shield). Heaven is where you *earn*.
- **🔥 Hell pets lean COMBAT** — designated powers point at killing (team damage / debuff-shred-curse
  / drain). Hell is where you *fight*.

**The required mix:** there's combat in *both* realms (hell heavy; heaven light but real — the
cross-faction invasion, avoidable to ~zero with a good team). So the roster must keep **combat
reachable inside heaven** — don't let heaven become a teeth-less economy dead end. When grafting
differentiation powers (esp. onto the melee reskin-line), default to the realm's lean: heaven gets
"+coins/+luck", hell gets "+team-damage/debuff" — same knob, two directions. This overlay rides on
top of the origin×archetype grid above; e.g. a heaven Fire-blaster still fights (the heaven combat
mix), while a hell Desert-support curses (hell's combat-flavored support).

## 7. Takeaways for build order

- **Author where mechanics are scarce, skip where they're rich.** Priority = the L2 **Ice dragon**
  freeze-AoE (overlaps 3 lines, showcase), then Fire **blaster** splash. Support/control pets mostly
  need *aura assignment + scaling*, not new tech.
- **Melee is a graft problem, not a mechanics problem** — sprinkle economy powers from L3+.
- **Design L3-5 dragons + apexes with their signature in the spec** (per each line doc's progression
  table) so deep layers ship differentiated, not retrofitted.
