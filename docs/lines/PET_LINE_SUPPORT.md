# Archetype Line — Support (heal / shield / buff / yield ⟷ drain / curse / shred)

Status: design (Jason + Claude, 2026-06). Line doc — see
[blaster](PET_LINE_BLASTER.md) · [melee](PET_LINE_MELEE.md) · [tank](PET_LINE_TANK.md) ·
[support](PET_LINE_SUPPORT.md) · [controller](PET_LINE_CONTROLLER.md) · [dragon](PET_LINE_DRAGON.md).
Cross-refs: [roster](../PET_REALM_HEAVEN_HELL_ROSTER.md) ·
[mechanic progression](../PET_REALM_MECHANIC_PROGRESSION.md) · [overlap matrix](PET_LINE_OVERLAP_MATRIX.md).

## Definition

**Team multipliers, not personal DPS.** The **give→take** axis is the realm signature: Heaven supports
by **giving** (heal / shield / +damage / +yield / regen); Hell supports by **taking** (life-drain /
curse / armor-shred / regen-denial). **This is the line that is ALREADY least reskinned** — every
support carries a *designated power by nature*, so two power-30 supports with different auras play
completely differently from Common up.

## Realm orientation — heaven farms, hell fights (the deeper lean)

Beneath give→take is a **purpose lean** that colors the whole realm, not just supports:

- **🕊️ Heaven pets lean FARMING** — their designated powers point at the economy: **coins, drops/
  Windfall, luck, yield**, plus the survival glue (heal/shield) that *keeps you farming*. Heaven is
  the place you go to *earn*.
- **🔥 Hell pets lean COMBAT** — their designated powers point at killing: **team damage, target
  debuffs (shred/curse), drain**. Hell is the place you go to *fight*.

This is **loose, not a straitjacket** — the same "lean ≠ law" rule as the origin roles. And there's a
hard reason it can't be fully aligned: **there is combat in BOTH realms.** Hell is combat-heavy;
heaven has *some* (it's invaded by the opposing faction — heaven-vs-hell cross-attack), **less of it,
and avoidable to near-zero if you pick your team well.** So:

- **The roster needs a deliberate MIX, especially combat reaching into heaven.** A player farming
  heaven still has to handle invaders, so heaven pets/squads must be *able* to fight — don't make
  heaven a pure-economy dead end with no teeth. Keep at least some combat-capable bodies (the Fire
  blaster, the melee, the offense-buff) viable in a heaven squad, and let a few heaven supports carry
  a light combat tool.
- **Some farming reaches into hell too** (a hell squad still wants *some* yield), but the asymmetry is
  fine: hell is mostly combat, heaven is mostly farming.

### How this maps to the powers (the graft library, by lean)

This lean is exactly the **designated-power escape hatch** sorted by realm — when we graft a power to
differentiate a pet (or build a support's native aura), default to the realm's lean:

| | Heaven lean (farming) | Hell lean (combat) |
|---|---|---|
| **Economy** | +coins · +yield · +luck · Windfall/drop-rate · magnet | (some yield, lighter) |
| **Survival** | heal · shield · regen | drain-heal (life-leech) |
| **Offense** | *(the needed mix — a few combat tools)* | team +damage · armor-shred · curse · regen-denial |

So Heaven's "+coins on a plain melee" keeper (the melee-line escape hatch) is *on-theme*; Hell's
equivalent keeper is "a debuff or +team-damage on a plain melee." The differentiation lever and the
realm identity are the same knob pointed two directions.

## Where support lives (Desert owns it; Fire & Grass each lend one)

- **🏜️ Desert** — the origin's lean; **the whole egg is support** from L2 up (heal / shield / yield /
  regen / apex). At **L4 the Desert apex is the Alabaster/Glass DRAGON** (the buffer-dragon).
- **🔥 Fire** — the **Uncommon offense-buff** Salamander (heaven: +damage light · hell: burn-curse).
- **🌿 Grass** — the **Common heal** Lamb (heaven: heal · hell: life-drain heal) *and* the **Uncommon
  yield** Sprite. Plus the Grass tank-apex Ent is a tank/**heal** hybrid (see Tank line).

## Roster — support, by layer (heaven ／ hell mirror)

| Layer | 🔥 Offense-buff (Salamander) | 🌿 Heal (Lamb) | 🌿 Yield (Sprite) | 🏜️ Desert support pool |
|---|---|---|---|---|
| **L1** | Radiant ／ Brimstone | Bloomlamb ／ Blightlamb | Verdant ／ Wither | Scarab(yield)·Camel(regen)·Roc(ranged)·Sphinx(tank)·Jackal(melee) — *mixed, not yet pure* |
| **L2** | Lumen ／ Frostbrand | Bloomspirit ／ Frostblight | Radiant ／ Rimewither | Dove(heal)·Scarab(shield)·Meerkat(yield)·Camel(regen)·**Couatl apex** |
| **L3** | Gloryscale ／ Rotbrand | Gloryleaf ／ Blightleaf | Bloomlight ／ Plaguebloom | Ibis(heal)·Totem(shield)·Mongoose(buff)·Tortoise(regen)·**Sphinx apex** |
| **L4** | Sunscale ／ Scorchbrand | Sunbloom ／ Scorchleaf | Sunmote ／ Scorchbloom | Lark·Idol·Vulture·Camel·**Alabaster/Glass DRAGON** |
| **L5** | Glory ／ Null | Eden ／ Umbral | *(none — Grass L5 fields a Badger)* | Dove·Idol·Mongoose·Camel·**Lammasu/Anubis apex** |

## Designated-power progression

Support is **already mechanic-rich** — the work is *scaling magnitude* and *adding axes*, not debuting
new behavior. The auras exist today (heal/defense/offense/yield support pets).

| Slot | Designated power | Status | Escalation |
|---|---|---|---|
| Desert heal (Dove/Ibis/Lark) | team heal pulse | aura now | scale; L4+ cleanse a debuff |
| Desert shield/buff (Idol/Totem/Scarab) | team barrier / +stat | aura now | scale magnitude |
| Desert yield (Meerkat/Mongoose) | +coins aura | **live (CoinYieldBuff)** | scale; the proven graftable power |
| Desert regen (Camel) | team heal-over-time | aura now | L5 + small overheal shield |
| Fire offense-buff (Salamander) | +damage (heaven) / burn-curse (hell) | aura now | scale; L4+ on-cast burst |
| Grass heal (Lamb) | heal / life-drain heal | aura now | scale; L4+ cleanse |
| **Desert support DRAGON** (Alabaster/Glass, L4) | **whole-team multi-axis aura** (heal+shield+buff / curse+shred+drain) | design | the buffer-dragon showcase |

## Overlaps with other lines

- **↔ Tank:** the **Grass tank-apex Ent** is tank/**heal** — it's in both lines. The Grass tank
  **dragon** (Verdant/Blight, L3) carries a heal/drain aura too.
- **↔ Dragon:** the **Desert dragons (L4, Alabaster/Glass) are support** — the dragon line's support
  entry, and the purest "aura dragon."
- **↔ Controller:** give→take blurs into control in hell — armor-**shred** and regen-**denial** are
  support powers that behave like debuffs (the CoH defender/controller blur). Hell desert ≈ a
  debuffer.
- **↔ everything (the escape hatch):** the **+coins / +luck / +yield** powers this line owns are the
  exact ones we graft onto *other* lines (melee, etc.) to fight reskinning. Support is the donor
  library for the whole roster's economy variety.

## Build state

The richest line today: support auras (heal/defense/offense/yield) are **live and wired**
(`EnemyService:_supportPass`, `CoinYieldBuff`, etc.). Remaining work is per-pet authoring of *which*
aura each support carries + scaling, and the L4 support-dragon's multi-axis aura.
