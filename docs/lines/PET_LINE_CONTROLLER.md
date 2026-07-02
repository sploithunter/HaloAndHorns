# Archetype Line — Controller (slow / root / freeze / fear)

Status: design (Jason + Claude, 2026-06). Line doc — see
[blaster](PET_LINE_BLASTER.md) · [melee](PET_LINE_MELEE.md) · [tank](PET_LINE_TANK.md) ·
[support](PET_LINE_SUPPORT.md) · [controller](PET_LINE_CONTROLLER.md) · [dragon](PET_LINE_DRAGON.md).
Cross-refs: [roster](../PET_REALM_HEAVEN_HELL_ROSTER.md) ·
[mechanic progression](../PET_REALM_MECHANIC_PROGRESSION.md) · [overlap matrix](PET_LINE_OVERLAP_MATRIX.md).

## Definition

**Locks enemies down** — slow → root → freeze → fear. The **counter to flyers/kiters** (control is
their designed weakness, per the flyers-counter design note). Like support, controllers carry a
**designated power by nature**, so they're differentiated even at Common. **The narrowest line** —
**Ice owns control**, so almost the whole line is one origin (which is fine: Ice = control is the lean).

## Where control lives (Ice, plus its hybrids)

- **❄️ Ice** — the origin's lean. The **Uncommon controller** (Fox/Wisp/Jelly) is the pure control
  body. The **tank/control apexes** (Leviathan/Mammoth/Yeti) are control hybrids. And the **Ice
  DRAGONS (L2, Aurora/Rimewraith) are melee/control** — wade in and freeze.
- (No other origin fields a dedicated controller — control is Ice's identity. Hell *desert* shred /
  regen-denial behaves debuff-like but lives in the Support line.)

## Roster — every controller, by layer (heaven ／ hell mirror)

| Layer | ❄️ Pure controller (U) | ❄️ Tank/control apex (M) | ❄️ Control dragon |
|---|---|---|---|
| **L1** | Aurora ／ Rimewraith Fox | Aurora ／ Black-Ice Leviathan (Epic) | — |
| **L2** | Prism ／ Dread Fox | *(apex = the DRAGON)* | **Aurora ／ Rimewraith Dragon** (melee/control) |
| **L3** | Halo ／ Plague Wisp | Empyrean ／ Blight Mammoth | — |
| **L4** | Glare ／ Shatter Jelly | Sunspire ／ Scorchglass Yeti | — |
| **L5** | Sol ／ Void Wisp | Astral ／ Abyss Leviathan | — |

## Designated-power progression

Control already has a designated power (the slow); the spine is **escalating the lockdown** and
debuting it early (control is significant enough to appear at L2).

| Slot | Verb | Debut | Escalation |
|---|---|---|---|
| Pure controller (Fox/Wisp/Jelly) | **slow** → root → freeze | L2 (light slow) | L2 slow → L3 stronger slow → L4 brief root → L5 freeze |
| Tank/control apex (Leviathan/Mammoth/Yeti) | **AoE stomp-slow + DR** | L1 (light) | grows the slow radius + DR (see Tank line) |
| Ice dragon (Aurora/Rimewraith, L2) | **melee freeze-AoE** (wade in, frost-breath roots) | L2 | the line's showcase; **highest-value authoring task today** |

## Overlaps with other lines

- **↔ Tank:** **heavy** — every Ice tank apex is tank/**control**, and the Ice Bear wall lives in the
  control origin. Controller and Tank effectively *share the Ice egg* (slow-and-hold + a wall).
- **↔ Dragon:** the **Ice dragons (L2) are melee/control** — the dragon line's control entry, and the
  one pet where control + melee + AoE all converge.
- **↔ Blaster:** Ice also fields a blaster (owl) — so an Ice squad is "slow them, then shoot them";
  controller sets up the blaster.
- **↔ Support (hell):** hell desert shred / regen-denial are debuffs that *feel* like control but are
  classed support (give→take). Soft overlap — the "is it control or debuff-support?" line is blurry
  in hell on purpose (CoH controller/defender blend).
- **Within-line:** the pure controller (Fox) vs the tank/control apex must differ by *body* — Fox =
  squishy pure-lockdown, apex = a wall that *also* slows. Same verb, different durability.

## Build state

On-hit slow/root and the control toolbox are **built and tested** (OnHitEffects: slow/shred/execute;
control modifiers). Nothing authored onto control *pets* yet beyond the framework. The L2 Ice dragon
freeze-AoE is the single highest-value authoring task in the whole roster — it makes the current L2
chase actually *play* like a control dragon.
