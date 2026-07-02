# Archetype Line — Dragon (the 11 secret capstones)

Status: design (Jason + Claude, 2026-06). Line doc — see
[blaster](PET_LINE_BLASTER.md) · [melee](PET_LINE_MELEE.md) · [tank](PET_LINE_TANK.md) ·
[support](PET_LINE_SUPPORT.md) · [controller](PET_LINE_CONTROLLER.md) · [dragon](PET_LINE_DRAGON.md).
Cross-refs: [roster](../PET_REALM_HEAVEN_HELL_ROSTER.md) ·
[mechanic progression](../PET_REALM_MECHANIC_PROGRESSION.md) · [overlap matrix](PET_LINE_OVERLAP_MATRIX.md).

## Definition

The **Secret chase pet of each realm** and the **rebirth key** — one per layer, 11 total (Base +
Heaven 1-5 + Hell 1-5). Always **SECRET** rarity, always a **per-uid unique** (carries
`player_class`/`hatched_by` for the rebirth gate — *not* an enchant-stack like the Mythic apexes).
**Dragons are not always ranged** — each takes its **origin's archetype**, so the 11 cover the full
archetype set. That makes the dragon line the **"sampler"**: it touches every *other* line once.

## The rotation — origin (and therefore archetype) rotates by layer

| Layer | Origin | Heaven dragon | Hell dragon | Archetype (= the line it overlaps) |
|---|---|---|---|---|
| **Base** | Grass | Dragon (base) | — | Tank/sustain (origin set) |
| **L1** | Fire | Empyrean Wyrm (#2) | Abyssal Wyrm (#7) | **Blaster** — breath volleys |
| **L2** | Ice | Aurora Dragon (#3) | Rimewraith Dragon (#8) | **Melee / control** — wades in, freezes |
| **L3** | Grass | Verdant Dragon (#4) | Blight Dragon (#9) | **Tank** — colossal HP + heal/drain aura |
| **L4** | Desert | Alabaster Dragon (#5) | Glass Dragon (#10) | **Support** — team buff/curse aura (buffer-dragon) |
| **L5** | apex | Seraph Dragon (#6) | Void Dragon (#11) | **Hybrid** — all-rounder (shared across all 4 L5 eggs) |

(Numbering = the 11-dragon rebirth collection order.)

## Why the dragon line is the anti-reskin keystone

Every dragon is the **showcase** of its layer's mechanic. Because the origin rotates, **consecutive
dragons play completely differently** — a blaster (L1) → a melee freezer (L2) → a tank (L3) → a
buffer (L4) → a hybrid (L5). So even though all 11 share a re-skinnable *rig* (Empyrean ↔ Abyssal ↔
Aurora ↔ … silhouette reuse keeps the art cheap), they are the **least** reskin-prone line
*mechanically*. The rig is reused; the **designated power is not**.

## Designated-power per dragon (the showcase signatures)

| Dragon(s) | Signature designated power |
|---|---|
| Empyrean / Abyssal (Fire, L1) | **breath splash volley** (`targeted_aoe` ranged) — the apex blaster |
| Aurora / Rimewraith (Ice, L2) | **melee freeze-AoE** — frost-breath roots/slows a cluster, claws in melee |
| Verdant / Blight (Grass, L3) | **tank aura** — huge HP + radiant **regen** (heaven) / life-**leech** (hell) aura |
| Alabaster / Glass (Desert, L4) | **team support aura** — heal+shield+buff (heaven) / curse+shred+drain (hell): multi-axis |
| Seraph / Void (apex, L5) | **hybrid** — a lighter blend of all of the above; the grand finale |

## Overlaps with other lines (this is the whole point of the dragon line)

The dragon line **is** the overlap map — it intersects each other line exactly once:

- **↔ Blaster** at **Fire L1** — the Fire blaster apex *is* the dragon (splash volley = breath).
- **↔ Controller + Melee** at **Ice L2** — the only melee *and* control dragon (freeze-AoE wade-in).
- **↔ Tank** at **Grass L3** — the tank dragon (HP wall + heal/drain aura).
- **↔ Support** at **Desert L4** — the buffer-dragon (team aura).
- **↔ all** at **L5** — the hybrid samples every line at once.

So if you want to feel an archetype's *ceiling*, you look at the dragon that carries it. And the
dragon line tells the other five docs where their apex expression lives.

## Special structure

- **L5 dragons are origin-less and shared:** all four L5 eggs in a realm deliver the *same* Seraph
  (Heaven) / Void (Hell) dragon, made 4× rarer per egg so the aggregate stays ~1-in-2,000.
- **Rarity is held constant** across all 11 (~1-in-2,000 each) on purpose — the **all-11 self-hatch
  collection** is the wall, not making any single dragon rarer.
- Dragons are **per-uid uniques** (not stacks) — provenance *does* matter for them in one narrow way:
  `hatched_by` gates the rebirth class. (This is the one place the otherwise source-independent power
  model carries identity — and only for the rebirth gate, not for power.)

## Build state

- Empyrean/Abyssal exist but their AoE was **reverted to single-target** (test mule); they currently
  read as plain ranged, not splash-blaster dragons.
- Aurora/Rimewraith (L2) exist as pets but are **single-target** — authoring their **melee freeze-AoE
  is the highest-value anti-reskin task in the roster** (makes the current chase play like a dragon).
- L3-5 dragons are design-only; build them with their signature designated power from the start.
