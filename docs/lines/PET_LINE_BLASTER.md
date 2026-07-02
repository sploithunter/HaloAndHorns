# Archetype Line — Blaster (ranged DPS)

Status: design (Jason + Claude, 2026-06). One of six line docs — see
[blaster](PET_LINE_BLASTER.md) · melee · tank · support · controller · dragon. Cross-refs:
[roster](../PET_REALM_HEAVEN_HELL_ROSTER.md) · [mechanic progression](../PET_REALM_MECHANIC_PROGRESSION.md).

> **Purpose of a line doc:** trace ONE archetype *across origins* and *down the layers* so we can see
> its progression, its designated-power escalation, and where it **overlaps** other lines. Heaven/hell
> mirrors are listed as a pair (reskin is fine); the vertical climb is the axis we differentiate.

## Definition

**Ranged single-/multi-target damage.** Fires from standoff (phoenix volleys, owl arrows, lances).
Distinct from **Melee** (in-the-thick DPS) and **Dragon** (the secret capstone, which at Fire layers
*is* a blaster). The blaster's natural **designated power = the splash volley** (`targeted_aoe`) — it's
the archetype that most wants AoE, so it's where AoE escalation lives.

## Where blasters live (the line spans 2 origins + the apex)

- **🔥 Fire** — the home of blasters: the **Rare** slot (Phoenix/Lance/Seraph) *and* the **Mythic apex**
  (Phoenix/Firehawk/Ifrit/Harpy). At **L1 the Fire apex is the Secret dragon** (Empyrean/Abyssal) —
  so the blaster line and the dragon line *are the same pet* at L1.
- **❄️ Ice** — the **Uncommon** slot (Owl/Moth/Petrel): a secondary blaster, aurora/shard arrows.
- (Grass/Desert have no native blaster — they field tank/support/melee.)

## Roster — every blaster, by layer (heaven ／ hell mirror)

| Layer | Fire · Rare blaster | Fire · Mythic apex blaster | Ice · Uncommon blaster |
|---|---|---|---|
| **Base** | *(orig. game set — ranged TBD)* | — | — |
| **L1** | Solar Phoenix ／ Ashfeather Phoenix | **= the dragon** (Empyrean ／ Abyssal Wyrm) | Seraph Owl ／ Dread Owl |
| **L2** | Lance Seraph ／ Hoarfrost Phoenix | Dawnfire ／ Deadfire Phoenix (M) | Starlight Owl ／ Gravefrost Owl |
| **L3** | Radiant Lance ／ Pyreblight Phoenix | Empyrean Firehawk ／ Pestilence Harpy (M) | Celestial Moth ／ Carrion Moth |
| **L4** | Sunlance Seraph ／ Magmaglass Phoenix | Solaris ／ Inferno Ifrit (M) | Sunbeam ／ Obsidian Petrel |
| **L5** | Empyrean Lance ／ Abyss Phoenix | Sol ／ Oblivion Phoenix (M) | Astral ／ Abyss Petrel |

Note the **L3/L4 de-phoenixing** of the Fire apex (Firehawk/Harpy, Ifrit) — silhouette variety so the
apex isn't five phoenixes. That's *art* variety; the table below is *mechanic* variety.

## Designated-power progression (the anti-reskin spine)

Signature verb = **splash volley**; it escalates with depth instead of just scaling damage:

| Layer | Rare blaster | Mythic apex blaster |
|---|---|---|
| **Base/L1** | vanilla single-target (teaching) | L1 apex = dragon (own design) |
| **L2** | vanilla | **small splash** (`targeted_aoe`, debut) |
| **L3** | small splash | splash **+ a chain/2nd target** |
| **L4** | splash | **bigger radius** |
| **L5** | splash + chain | radius **+ on-hit burn** rider |

Ice uncommon blaster stays lighter (it's an uncommon — filler-tier): vanilla until L4, then a small
**pierce/line** shot (hits 2 in a line) at L4→L5, so it reads distinct from the Fire splash blaster.

**Escape-hatch option (per the progression doc):** if any blaster slot still feels samey, graft an
**economy power** (e.g. +luck on the Ice owl, +coins on a mid Fire phoenix) — instant "keeper"
differentiation with zero new combat tech.

## Overlaps with other lines (what this doc is for)

- **↔ Dragon line:** total overlap at **Fire L1** — Empyrean/Abyssal Wyrm *are* the Fire blaster apex
  *and* the secret dragon. The Fire-blaster signature (splash volley) is literally the dragon's
  breath. Elsewhere the dragon rotates off Fire, so the lines separate.
- **↔ Melee line:** the Fire **Bruiser** (Lion) sits one slot below the blaster in the same egg — same
  origin, opposite range. Squad-coverage pairing, not a mechanic overlap.
- **↔ Support line:** the Fire **offense-buff** Salamander shares the Fire egg and *amplifies* blaster
  damage — designed to combo, so a Fire mono-squad pairs blaster + salamander.
- **↔ Controller line:** Ice fields *both* a blaster (owl) and a controller (fox) — same origin, so an
  Ice squad naturally gets "slow then shoot." The blaster owl is the Ice egg's damage outlet.
- **Within-line overlap (the reskin risk):** the **Fire Rare blaster** and the **Fire apex blaster**
  are both "fire ranged splash" — they must stay separated by *magnitude of the splash signature*
  (apex = bigger radius + rider; rare = plain → small splash), or they collapse into the same fantasy.

## Build state

- Authored today: **none** carry `targeted_aoe` yet (the one AoE pet in `pets.lua` is a grass/contagion
  test pet; empyrean_dragon's AoE was reverted to single-target).
- Highest-value first authoring: give the **L2 Fire apex (Dawnfire/Deadfire Phoenix)** its debut small
  splash, so the blaster line's signature actually appears at the layer the progression says it should.
