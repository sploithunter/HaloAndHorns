# Heaven & Hell Pet Rosters

Status: design (working names; structure locked, art TBD) — Jason, 2026-06

Per-realm pet pools for the stacked Heaven/Hell layers. See the
[Design Document](PET_REALM_DESIGN_DOCUMENT.md) §3 (Loop & Overlay / Stacked Layers) for the
realm geometry, and the **Dragons, Secrets, and Player Class (Rebirth)** section for the
11-dragon rebirth gate that this roster feeds.

## Framing: 4 origins, ascended or fallen — not a 5th element

There are **4 origins** (Fire/Lava, Ice, Grass/Earth, Desert). A realm does **not** add a new
element — it **transfigures each origin**: Heaven = the *ascended* form (radiant/celestial),
Hell = the *fallen* form (corrupted/infernal). A pet keeps its **origin** (drives element/stats)
and gains a **realm** tag (drives the heaven/hell treatment) — resolved through
`src/Shared/Game/WorldContext.lua` (`{ realm, depth }` from the world folder). Every heaven pet
has a 1:1 hell mirror, so you model the **pair**, not two unrelated sets.

Origins lean a playstyle (loosely, not strictly):

| Origin | Lean | Role |
|--------|------|------|
| Fire/Lava | **Damage** | melee + blaster DPS |
| Ice | **Control** | slow / hold / freeze |
| Grass/Earth | **Tank** | durable front-line + self-sustain |
| Desert | **Support** | team heal / shield / buff / yield (heaven) · drain / curse (hell) |

This is the canonical four-role quad — **every origin owns exactly one role**. But an origin
*leans* a role, it isn't a straitjacket: each 5-pet pool still spans roles for squad coverage.
Ice leans control yet fields a sturdy **polar-bear tank** as its durable body; Fire carries a
support offense-buffer; etc. The **lean + the dragon's archetype** define an origin's identity;
the supporting cast fills the gaps so a mono-origin squad still functions.

A **complete realm roster = 4–5 pets per origin** covering the role spread, plus that realm's
**one secret dragon** (the chase pet + rebirth token).

## Heaven 1 — full pool (5 per origin, 20 + the dragon)

### 🔥 Fire — leans damage
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Emberling Cherub | Melee | Common | winged coal-imp, dawn-touched |
| Sunmane Lion | Melee (bruiser) | Uncommon | golden solar lion, charges in |
| Solar Phoenix | Ranged | Rare | dawn-bolt volleys |
| Radiant Salamander | Support (offense buff) | Uncommon | bathes the squad in +damage light |
| **★ Empyrean Dragon** | **Damage (capstone)** | **SECRET** | radiant gold-white wyrm — Heaven 1's chase + rebirth dragon #2 of 11 |

### ❄️ Ice — leans control
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Frostlight Hare | Melee | Common | shimmering frost-rabbit |
| Aurora Fox | Control | Uncommon | auroral light that slows & binds |
| Seraph Owl | Ranged | Uncommon | starlight arrows from standoff |
| Glacial Seraph | Support (shield) | Rare | wreathes the squad in protective frost-light |
| Aurora Leviathan | Tank / Control | Epic | vast aurora-scaled serpent — holds + slows |

### 🌿 Grass — leans sustain/heal
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Bloomlamb | Support (heal) | Common | haloed lamb in flowering light |
| Halo Hare | Melee | Common | swift winged hare |
| Goldleaf Stag | Tank | Uncommon | gilded-antler stag, nature armor |
| Verdant Sprite | Support (yield/luck) | Uncommon | bloom-spirit, boosts harvest |
| Worldroot Ent | Tank / Heal | Rare | radiant tree-guardian, big HP + regen aura |

### 🏜️ Desert — leans durable/utility
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Sun Scarab | Support (coin/yield) | Common | golden beetle, boosts coins |
| Mirage Jackal | Melee (evasion) | Uncommon | shimmering jackal that dodges |
| Gilded Sphinx | Tank | Rare | gold-stone guardian, soaks hits |
| Dawn Camel | Support (regen) | Uncommon | sun-blessed, slow heal aura |
| Solar Roc | Ranged | Rare | great golden bird, light-talon dives |

**Role coverage:** Tank ×4 · Melee ×5 · Ranged ×3 · Support ×6 (heal/shield/buff/yield/regen) ·
Control ×1–2 (ice owns it) · + the secret dragon. A player can field a full squad several ways,
and each origin has an apex (Empyrean Dragon, Aurora Leviathan, Worldroot Ent, Solar Roc) — with
**fire's apex being the secret/rebirth dragon**.

## Hell 1 — "The Cinderreach" — full pool (5 per origin, 20 + the dragon)

The smoldering, ash-and-rot first descent. **Theme signature — give → take:** where Heaven
supports by GIVING (heal / shield / buff), Hell supports by TAKING (drain / shred / curse). Same
roles as Heaven, inverted morality — the City-of-Heroes debuffer/controller fantasy of the Hell
path. Origins keep their leans; only the flavor darkens. Every entry is a 1:1 mirror of the
Heaven 1 pet of the same slot (rig re-skins).

### 🔥 Fire — leans damage (infernal / brimstone)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Cinderling Imp | Melee | Common | charred imp, claws & cinders |
| Ashmane Lion | Melee (bruiser) | Uncommon | smoldering black lion, ember-maned |
| Ashfeather Phoenix | Ranged | Rare | cinder-bolts; rises from its own ash |
| Brimstone Salamander | Support (burn-curse) | Uncommon | brands foes — squad deals bonus burn (offense "buff" as an enemy debuff) |
| **★ Abyssal Wyrm** | **Damage (capstone)** | **SECRET** | void-black infernal wyrm — Hell 1's chase + rebirth dragon #7 of 11 |

### ❄️ Ice — leans control (black-ice / dread)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Rimelight Hare | Melee | Common | frostbitten dark hare |
| Rimewraith Fox | Control | Uncommon | spectral chill that freezes with dread (fear/root) |
| Dread Owl | Ranged | Uncommon | black owl, icy shards from the dark |
| Black Seraph | Support (armor-shred) | Rare | fallen frost-angel that strips enemy armor (shield inverted to anti-shield) |
| Black-Ice Leviathan | Tank / Control | Epic | vast black-ice serpent — holds + slows |

### 🌿 Grass — leans sustain (blight / rot / drain)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Blightlamb | Support (life-drain heal) | Common | rotted lamb that heals the squad by leeching enemy life |
| Dread Hare | Melee | Common | gaunt, fanged hare |
| Rotleaf Stag | Tank | Uncommon | thorned decaying stag — soaks + spreads rot |
| Wither Sprite | Support (wither-curse) | Uncommon | blight-spirit that saps foes' output |
| Gravewood Ent | Tank / Drain | Rare | dead-tree guardian, big HP + life-leech aura |

### 🏜️ Desert — leans durable/utility (ash / glass / carrion)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Carrion Scarab | Support (coin-from-kills) | Common | feeds on the fallen — yield on enemy death |
| Phantom Jackal | Melee (evasion) | Uncommon | ash-mirage jackal, dodges + flanks |
| Glass Sphinx | Tank | Rare | blackened-glass guardian, sharp + durable |
| Dust Camel | Support (regen-denial) | Uncommon | sand-wraith that stops enemy healing |
| Ash Roc | Ranged | Rare | great ash-feathered bird, glass-talon dives |

**Role coverage** mirrors Heaven 1 (Tank ×4 · Melee ×5 · Ranged ×3 · Support ×6 · Control ×1–2 ·
+ secret dragon) — same squad shapes, but the supports **debuff/drain** instead of heal/shield.
Apexes: Abyssal Wyrm (secret), Black-Ice Leviathan, Gravewood Ent, Ash Roc.

## Building economically

- **Model the dragon first** per realm — it's the chase + 1 of the 11 rebirth keys.
- **Rig reuse:** the dragon silhouette/animation rig re-skins across several of the 11
  (Empyrean ↔ Abyssal ↔ Aurora ↔ Rimewraith …) so 11 dragons isn't 11× the work.
- **Mirror reuse:** every heaven pet's rig re-skins to its hell mirror.
- New pets slot into a realm's egg/spawn pool by tagging **origin** (element/stats) + **realm**
  (`WorldContext`) — no new code per pet.

## Heaven 2 — "The Aurora Reaches" — full pool (5 per origin, 20 + the dragon)

The second ascent — **farther from base reality** (see the Design Document's *Realm aesthetic
gradient*). Heaven 1's gilded paradise **de-materializes** into prismatic, auroral light:
floating cloud-sea and refracting crystal, ground giving way to sky. **Palette: white / silver /
pearl / prismatic / aurora — NO gold** (gold & rainbow are reserved for the shiny variant tiers;
from Heaven 2 up the gradient deliberately moves off metal into pure light).

**The dragon rotates to Ice this time** → **Aurora Dragon** (rebirth dragon #3 of 11). And it is
the **first melee dragon** — Ice leans *control*, so the Aurora Dragon wades *in* and freezes
rather than firing from range. Dragons are always SECRET, but they are *not* always ranged.

**Rarity escalation — first Mythic apexes.** Heaven/Hell 1 topped out at Epic for the non-dragon
apexes; from layer 2 the three non-dragon apexes per realm (e.g. phoenix / ent / couatl) are **Mythic** —
one rung under the Secret dragon (`…epic → legendary → mythic → secret`). Note the storage
consequence (Storage v2): a Mythic apex is an **enchant-keyed stack** (its hatch-rolled effect
splits it into its own pile), whereas the **Secret dragon is a per-uid unique** carrying
`player_class`/`hatched_by` for the rebirth gate. So the dragon stays the only true one-of-a-kind
chase per realm; the Mythic apexes are grand but farmable/stackable.

### 🔥 Fire — leans damage (coronal / white-sun light)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Coronal Cherub | Melee | Common | cool white-flame cherub, dawn-bright halo |
| Prism Lion | Melee (bruiser) | Uncommon | crystal-maned lion, refracts a light-charge |
| Lance Seraph | Ranged | Rare | lances of white sunfire from standoff |
| Lumen Salamander | Support (offense buff) | Uncommon | bathes the squad in radiant light → +damage |
| Dawnfire Phoenix | Blaster (ranged apex) | Mythic | reborn in white flame — fire's non-dragon apex |

### ❄️ Ice — leans control (aurora / prismatic) — **the dragon origin**
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Frostlight Doe | Melee | Common | crystalline frost-deer |
| Prism Fox | Control | Uncommon | refracted light that slows & binds |
| Starlight Owl | Blaster | Uncommon | aurora-arrows from the dark |
| **Glacial Bear** | **Tank** | Rare | prismatic-furred polar bear — Ice's durable body (a control origin still wants a wall) |
| **★ Aurora Dragon** | **Melee / Control (capstone)** | **SECRET** | prism-scaled dragon that wades IN — frost-breath roots & slows, claws in melee. **The first non-ranged dragon.** Heaven 2's chase + rebirth dragon #3 of 11 |

### 🌿 Grass — leans sustain/heal (bloom-light)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Bloomspirit Lamb | Support (heal) | Common | lamb of living white light |
| Lightleaf Hare | Melee | Common | swift petal-winged hare |
| Crystalbark Stag | Tank | Uncommon | crystal-antlered stag, light-armor |
| Radiant Sprite | Support (yield/luck) | Uncommon | bloom-spirit, boosts harvest |
| Worldbloom Ent | Tank / Heal apex | Mythic | towering light-tree, big HP + regen aura (grander Worldroot) |

### 🏜️ Desert — leans support (oasis / radiant light)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Aurora Dove | Heal | Common | radiant dove, soft heal pulse on the squad |
| Prism Scarab | Shield / buff | Uncommon | refracts a protective light-barrier onto allies |
| Mirage Meerkat | Coin yield | Uncommon | lookout that boosts the squad's haul |
| Sunwell Camel | Regen | Rare | radiant oasis aura, slow team heal-over-time |
| Empyreal Couatl | Support apex | Mythic | feathered light-serpent that blesses the whole team |

**Role coverage** now reads as the clean quad — Fire damage, Ice control (with the Glacial Bear
as its wall), Grass tank, Desert support — plus the secret dragon. Apexes: Dawnfire Phoenix
(fire), **Aurora Dragon (ice = SECRET)**, Worldbloom Ent (grass), Empyreal Couatl (desert).

## Hell 2 — "The Frozen Dark" — full pool (5 per origin, 20 + the dragon)

The second descent — and per Dante's logic, **the deeper hell goes COLD**, not hotter. Hell 1's
ash & ember **de-materializes** into black-ice and frostbitten void: lightless, sinking, the
sky raining grey-frost. **Palette: black / obsidian / black-ice / ember-on-black / sickly-violet.**
Same give→take inversion as Hell 1 — supports **drain / shred / curse** instead of heal/shield —
and every entry is a 1:1 mirror of the Heaven 2 pet in the same slot (rig re-skins).

**The dragon (Ice) mirrors heaven** → **Rimewraith Dragon** (rebirth dragon #8 of 11), likewise
**melee / control** — the black-ice twin of the Aurora Dragon.

### 🔥 Fire — leans damage (cold-fire / black frost-ember)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Frostcinder Imp | Melee | Common | imp of black cold-fire |
| Rimemane Lion | Melee (bruiser) | Uncommon | frost-charred black lion |
| Hoarfrost Phoenix | Ranged | Rare | cold-bolt volleys; rises from black frost |
| Frostbrand Salamander | Support (frostbite curse) | Uncommon | brands foes → squad deals bonus frost-burn |
| Deadfire Phoenix | Blaster (ranged apex) | Mythic | ashen-cold non-dragon fire apex |

### ❄️ Ice — leans control (black-ice / dread) — **the dragon origin**
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Rimegloom Hare | Melee | Common | frostbitten dark hare |
| Dread Fox | Control | Uncommon | spectral chill — fear/root |
| Gravefrost Owl | Blaster | Uncommon | black shards from the dark |
| **Rimeguard Bear** | **Tank** | Rare | black-ice polar bear — Ice's frostbitten wall |
| **★ Rimewraith Dragon** | **Melee / Control (capstone)** | **SECRET** | black-ice revenant dragon — wades IN, frostbite-breath holds & freezes, claws in melee. Mirror of the Aurora Dragon (also non-ranged). Hell 2's chase + rebirth dragon #8 of 11 |

### 🌿 Grass — leans sustain (frostrot / drain)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Frostblight Lamb | Support (life-drain heal) | Common | frozen rotted lamb, leech-heals the squad |
| Gloom Hare | Melee | Common | gaunt frostbitten hare |
| Icerot Stag | Tank | Uncommon | frozen-thorned stag, spreads chill-rot |
| Rimewither Sprite | Support (wither-curse) | Uncommon | frost-blight saps foes' output |
| Frostgrave Ent | Tank / Drain apex | Mythic | frozen dead-tree, big HP + life-leech aura |

### 🏜️ Desert — leans support (frost-carrion / give→take)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Wraith Dove | Drain-heal | Common | black dove, heals the squad by leeching the fallen |
| Rime Scarab | Armor-shred | Uncommon | strips enemy armor for the team |
| Gloom Jackal | Coin-from-kills | Uncommon | scavenger, yield on enemy death |
| Frostdust Camel | Regen-denial | Rare | frost-wraith aura stops enemy healing |
| Dread Couatl | Support apex (curse) | Mythic | black frost-serpent that curses every foe for the team |

**Role coverage** mirrors Heaven 2, give→take inverted (support = drain/shred/curse). Apexes:
Deadfire Phoenix (fire), **Rimewraith Dragon (ice = SECRET)**, Frostgrave Ent (grass),
Dread Couatl (desert support).

## Layer-2 odds & base power

**`base_power` is a bounded, GLOBAL tier number — it does NOT inflate per realm.** Realm
progression comes from the **depth multiplier** (`WorldContext.difficultyFor`, ×~2 at layer 2)
applied at runtime, not from bigger base numbers. So a Heaven-2 common has the same `base_power`
as a Heaven-1 common; it just hits harder in-world. The ceiling is exclusive (50); the secret
dragon is only just above the mythic apex on paper — its real value is being the **unique
rebirth key** + depth, not raw stats.

| Tier | `base_power` | Egg weight | ≈ Odds (in pool) | Note |
|------|-----------|------------|------------------|------|
| Common | 12 | 40 | ~42% | same as Heaven 1 |
| Uncommon | 16 | 24 | ~25% each | |
| Rare | 22 | 6 | ~6% | tops the supporting cast |
| **Mythic apex** | **44** | **0.3** | **~1 in 320** | grand but farmable / enchant-stackable |
| **Secret dragon** | **46** | **0.05** | **~1 in 2,000** | per-uid unique; matches Empyrean's knob |

`huge_base_power` tracks the existing pattern (secret huge ≈ 180 like Empyrean; mythic huge ≈ 120).
Luck axis, charged hatch, and golden/rainbow gamepass multipliers all stack on top of these base
odds, same as every other egg.

**Two egg archetypes per layer** (only the dragon-origin egg carries a Secret):

- **Dragon egg — Ice (`heaven2_ice_egg` / `hell2_ice_egg`):** Common + Uncommon ×2 + Rare +
  **Secret dragon (0.05)** → the Aurora / Rimewraith chase sits at ~1 in 2,000 (same difficulty
  knob as Empyrean). Per-realm rarity is held constant across all 11 dragons on purpose — the
  **all-11 self-hatch collection** is the real wall, not making each dragon individually rarer.
- **The other three eggs — fire / grass / desert:** Common + Uncommon ×2 + Rare + **Mythic apex
  (0.3)** → top prize is the Mythic apex at ~1 in 320. No secret in these pools.

### Layer-2 egg keys (config)

Systematic keys (scale to all layers), themed display names. Each egg's pool = the 5 pets of
that origin (★ = also carries the Secret dragon). 2D icon → `assets/source/eggs/<key>.png`.

| Config key | Display name | Origin | Pool |
|---|---|---|---|
| `heaven2_fire_egg` | Coronal Egg | Fire | Heaven 2 Fire ×5 |
| `heaven2_ice_egg` ★ | Prism Egg | Ice | Heaven 2 Ice ×5 + Aurora Dragon |
| `heaven2_grass_egg` | Bloomlight Egg | Grass | Heaven 2 Grass ×5 |
| `heaven2_desert_egg` | Mirage Egg | Desert | Heaven 2 Desert ×5 |
| `hell2_fire_egg` | Frostcinder Egg | Fire | Hell 2 Fire ×5 |
| `hell2_ice_egg` ★ | Black-Ice Egg | Ice | Hell 2 Ice ×5 + Rimewraith Dragon |
| `hell2_grass_egg` | Frostblight Egg | Grass | Hell 2 Grass ×5 |
| `hell2_desert_egg` | Frostcarrion Egg | Desert | Hell 2 Desert ×5 |

## Dragon archetype spread

Every dragon takes its origin's lean, so the 11 cover the **full archetype set** — tank · damage
· control · support · hybrid (dragons are *not* always ranged — see the Design Document's dragon
rules):

| Realm origin | Dragon(s) | Archetype |
|--------------|-----------|-----------|
| Fire (H1 / Hell1) | Empyrean / Abyssal | **Blaster** — breath volleys at range |
| Ice (H2 / Hell2) | Aurora / Rimewraith | **Melee / control** — wades in, freezes |
| Grass (H3 / Hell3) | Verdant / Blight | **Tank** — colossal HP + heal (heaven) / drain (hell) aura |
| Desert (H4 / Hell4) | Alabaster / Glass | **Support** — heal/shield/buff aura (heaven) · curse/drain (hell): the buffer-dragon |
| Apex (H5 / Hell5) | Seraph / Void | **Hybrid** — the all-rounder grand finale |

Odds & base power for layers 3–5 follow the same table as layer 2 (Common 12 / Uncommon 16 /
Rare 22 / Mythic apex 44 @ 1-in-320 / Secret dragon 46 @ ~1-in-2000); only the depth multiplier
climbs (`WorldContext.difficultyFor`).

## Heaven 3 — "The Empyrean Bloom" — full pool (Grass dragon)

The cosmic garden — radiance deepens toward pure light; living emerald-light blooms float in a
white sky. **Palette: white / pearl / living emerald-light** (no gold). Dragon rotates to
**Grass → Verdant Dragon** (rebirth #4), a colossal living-light **tank** dragon (huge HP +
radiant regen aura).

### 🔥 Fire — damage
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Gloryspark Cherub | Melee | Common | mote of white flame |
| Seraph Lion | Bruiser | Uncommon | haloed light-lion |
| Radiant Lance | Blaster | Rare | white sunfire lances |
| Gloryscale Salamander | Offense buff | Uncommon | sheathes squad in glory-light |
| Empyrean Firehawk | Blaster apex | Mythic | great radiant fire-hawk, white-flame dives |

### ❄️ Ice — control
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Lumen Seal | Melee | Common | glowing light-seal pup |
| Halo Wisp | Control | Uncommon | ringing will-o-light slows & binds |
| Celestial Moth | Blaster | Uncommon | starfall wing-scales |
| **Halo Bear** | **Tank** | Rare | haloed polar bear — Ice's wall |
| Empyrean Mammoth | Tank / control apex | Mythic | vast radiant-tusked mammoth — stomps & slows |

### 🌿 Grass — sustain — **dragon origin**
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Gloryleaf Lamb | Heal | Common | lamb of green light |
| Halo Hart | Melee | Common | radiant stag-fawn |
| Lightbark Rhino | Tank | Uncommon | light-plated rhino, charges & holds |
| Bloomlight Sprite | Yield / luck | Uncommon | harvest-spirit |
| **★ Verdant Dragon** | **Tank / heal (capstone)** | **SECRET** | colossal living-light tree-dragon, huge HP + radiant regen aura. Rebirth #4 of 11 |

### 🏜️ Desert — support (oasis / radiant)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Bloom Ibis | Heal | Common | radiant ibis, gentle heal pulse |
| Radiant Totem | Shield / buff | Uncommon | living light-totem, team barrier |
| Glory Mongoose | Offense buff | Uncommon | desert scout that rallies squad damage |
| Light Tortoise | Regen | Rare | sun-spring shell, team heal-over-time |
| Empyrean Sphinx | Support apex | Mythic | benevolent oracle-sphinx, blesses the team |

## Hell 3 — "The Blightmire" — full pool (Grass dragon)

The rotting deep — decay, bile, bone, and drowned light. **Palette: rot-green / black / bruise-
violet.** Give→take inversion holds. Dragon rotates to **Grass → Blight Dragon** (rebirth #9), a
rotting bog **tank** dragon (huge HP + life-leech aura).

### 🔥 Fire — damage (plague-fire)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Blightcinder Imp | Melee | Common | sickly green-fire imp |
| Plaguemane Lion | Bruiser | Uncommon | boil-maned lion |
| Pyreblight Phoenix | Blaster | Rare | green pyre-bolts |
| Rotbrand Salamander | Curse | Uncommon | brands foes with rot |
| Pestilence Harpy | Blaster apex | Mythic | rot-winged harpy, plague-screech volleys |

### ❄️ Ice — control (rot-frost)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Murkfrost Seal | Melee | Common | bog-frost seal |
| Plague Wisp | Control | Uncommon | miasma slows & fears |
| Carrion Moth | Blaster | Uncommon | rot-spore wings |
| **Murk Bear** | **Tank** | Rare | bog-frost polar bear — Ice's rotted wall |
| Blight Mammoth | Tank / control apex | Mythic | drowned bog-mammoth — stomps & slows |

### 🌿 Grass — drain — **dragon origin**
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Blightleaf Lamb | Life-drain heal | Common | rotted lamb, leech-heals |
| Murk Hart | Melee | Common | gaunt bog-stag |
| Rothide Rhino | Tank | Uncommon | rotting armored rhino, charges & holds |
| Plaguebloom Sprite | Wither-curse | Uncommon | saps foes' output |
| **★ Blight Dragon** | **Tank / drain (capstone)** | **SECRET** | rotting bog-dragon, huge HP + life-leech aura. Rebirth #9 of 11 |

### 🏜️ Desert — support (rot-carrion / give→take)
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Carrion Ibis | Drain-heal | Common | rot-ibis, heals the squad off the fallen |
| Plague Totem | Curse | Uncommon | rotting totem that weakens nearby foes |
| Murk Mongoose | Debuff | Uncommon | saps enemy damage for the team |
| Plaguedust Camel | Regen-denial | Rare | stops enemy healing |
| Pestilent Sphinx | Support apex (curse) | Mythic | cursed oracle-sphinx, blights every foe |

## Heaven 4 — "The Sunspire Reaches" — full pool (Desert dragon)

Near-blinding radiant desert — salt-flat white, alabaster, sun-fused quartz. **Palette: white /
alabaster / sun-white / quartz** (no gold — the Heaven-4 dragon was renamed off "Gilded" for
exactly this reason). Dragon rotates to **Desert → Alabaster Dragon** (rebirth #5), the
**Support** dragon — a sun-disk-crowned buffer whose oasis-breath heals and shields the team.

### 🔥 Fire — damage
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Sunspark Cherub | Melee | Common | white sun-mote |
| Blaze Lion | Bruiser | Uncommon | sun-charged lion |
| Sunlance Seraph | Blaster | Rare | sun-white lances |
| Sunscale Salamander | Offense buff | Uncommon | sun-glare +damage |
| Solaris Ifrit | Blaster apex | Mythic | radiant sun-fire genie, hurls sun-bolts |

### ❄️ Ice — control
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Sunfrost Marten | Melee | Common | sun-glazed frost marten |
| Glare Jelly | Control | Uncommon | blinding glare-jelly that slows |
| Sunbeam Petrel | Blaster | Uncommon | sun-beam dives |
| **Quartz Bear** | **Tank** | Rare | quartz-furred polar bear — Ice's wall |
| Sunspire Yeti | Tank / control apex | Mythic | towering glass-furred yeti |

### 🌿 Grass — sustain
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Sunbloom Lamb | Heal | Common | sun-flower lamb |
| Sunleaf Hare | Melee | Common | bright desert hare |
| Quartzshell Beetle | Tank | Uncommon | crystal-shelled rhino-beetle, soaks hits |
| Sunmote Sprite | Yield / luck | Uncommon | sun-spirit |
| Sunroot Ent | Tank / heal apex | Mythic | sun-tree guardian |

### 🏜️ Desert — support — **dragon origin**
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Sun Lark | Heal | Common | radiant lark, gentle heal pulse |
| Quartz Idol | Shield / buff | Uncommon | living idol, team light-barrier |
| Sunmote Vulture | Offense buff | Uncommon | circles high, rallies squad damage |
| Sunspring Camel | Regen | Rare | oasis aura, team heal-over-time |
| **★ Alabaster Dragon** | **Support (capstone)** | **SECRET** | colossal radiant desert dragon crowned with a halo'd sun-disk — its oasis-breath **heals and shields the whole team** (the buffer-dragon, no gold). Rebirth #5 of 11 |

## Hell 4 — "The Scorchglass" — full pool (Desert dragon)

Blackened glass desert — obsidian shards, ember-on-black, ash dunes. **Palette: black-glass /
obsidian / ember.** Dragon rotates to **Desert → Glass Dragon** (rebirth #10), the **Support**
dragon — Alabaster's dark mirror: it curses and shreds every foe and drains life for the team.

### 🔥 Fire — damage
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Scorchcinder Imp | Melee | Common | obsidian ember-imp |
| Cindermane Lion | Bruiser | Uncommon | molten-cracked black lion |
| Magmaglass Phoenix | Blaster | Rare | molten-glass bolts |
| Scorchbrand Salamander | Curse | Uncommon | brands foes with scorch |
| Inferno Ifrit | Blaster apex | Mythic | dark fire-genie, hurls black-fire bolts |

### ❄️ Ice — control
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Blackfrost Marten | Melee | Common | obsidian-frost marten |
| Shatter Jelly | Control | Uncommon | shatter-glass jelly slows |
| Obsidian Petrel | Blaster | Uncommon | glass-shard dives |
| **Obsidian Bear** | **Tank** | Rare | black-glass polar bear — Ice's wall |
| Scorchglass Yeti | Tank / control apex | Mythic | molten-glass yeti |

### 🌿 Grass — drain
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Scorchleaf Lamb | Life-drain heal | Common | charred lamb, leech-heals |
| Cinder Hare | Melee | Common | ember-singed hare |
| Glassback Beetle | Tank | Uncommon | obsidian-shelled rhino-beetle, soaks hits |
| Scorchbloom Sprite | Wither-curse | Uncommon | scorches foes' output |
| Scorchroot Ent | Tank / drain apex | Mythic | burnt-glass tree |

### 🏜️ Desert — support — **dragon origin**
| Pet | Role | Rarity | Hook |
|-----|------|--------|------|
| Scorch Vulture | Drain-heal | Common | circles the fallen, heals the squad off them |
| Obsidian Idol | Curse | Uncommon | dark idol, weakens nearby foes |
| Cinder Jackal | Debuff | Uncommon | saps enemy damage for the team |
| Scorchdust Camel | Regen-denial | Rare | stops enemy healing |
| **★ Glass Dragon** | **Support (capstone)** | **SECRET** | fractured black-glass desert dragon — Alabaster's dark mirror: it **curses and shreds every foe** and drains life for the team. Rebirth #10 of 11 |

## Layer 5 — the apex ends

Heaven 5 and Hell 5 are the **pure-apex** ends of the stack — the grandest of the 11. Their
dragons are **origin-less hybrids** (all-rounders, high stats across damage/tank/control), so
layer 5 breaks the per-origin-dragon pattern in one way: **all four apex-realm eggs share the
same secret apex dragon** (it isn't anchored to one origin). That means each layer-5 egg tops
at its origin's **Mythic apex**, and the **Secret** slot in every egg is the *same* dragon —
Seraph (Heaven 5) or Void (Hell 5).

**Odds:** the Mythic apex is unchanged (weight 0.3 ≈ 1-in-320 per egg). The shared apex dragon
is made **4× harder per egg** to compensate for having four delivery eggs — weight **0.0125
(≈ 1-in-8,000 in any single egg)** — so the **aggregate** chance across the realm's four eggs
lands back at **~1-in-2,000**, matching the other ten single-source dragons. base power
unchanged; only the depth multiplier is highest here.

### Heaven 5 — "The Radiance" — full pool (apex)

The grandest ascended — the element has all but dissolved into **pure blinding white light**;
bodies are barely-there radiance with faint prismatic halos. **Palette: pure white / blinding
light / prismatic halo** (no gold).

| Origin | Common | Uncommon | Uncommon/Rare | Uncommon | Mythic apex |
|--------|--------|----------|---------------|----------|-------------|
| 🔥 Fire (damage) | Seraph Cherub (melee) | Sol Lion (bruiser) | Empyrean Lance (blaster, R) | Glory Salamander (offense) | **Sol Phoenix** (blaster) |
| ❄️ Ice (control) | Astral Ermine (melee) | Sol Wisp (control) | Astral Petrel (blaster) | **Astral Bear** (tank, R) | **Astral Leviathan** (tank/ctrl) |
| 🌿 Grass (tank) | Eden Lamb (self-heal) | Sol Hart (melee) | Edenshell Tortoise (tank) | Eden Badger (bruiser) | **Eden Colossus** (tank apex) |
| 🏜️ Desert (support) | Sol Dove (heal) | Astral Idol (shield) | Sol Mongoose (buff) | Sol Camel (regen, R) | **Astral Lammasu** (support apex) |

**★ Seraph Dragon** *(SECRET, shared across all four eggs)* — rebirth dragon **#6 of 11**. The
grandest ascended: a six-winged seraphic dragon of near-pure blinding white light, halo-crowned,
**hybrid** all-rounder (high across damage/tank/control). Pure radiance.

### Hell 5 — "The Void" — full pool (apex)

The grandest fallen — form collapses into **pure void-black**; light-devouring silhouettes edged
in faint violet-red, like walking event horizons. **Palette: pure black / void / violet-red edge.**

| Origin | Common | Uncommon | Uncommon/Rare | Uncommon | Mythic apex |
|--------|--------|----------|---------------|----------|-------------|
| 🔥 Fire (damage) | Umbral Imp (melee) | Void Lion (bruiser) | Abyss Phoenix (blaster, R) | Null Salamander (curse) | **Oblivion Phoenix** (blaster) |
| ❄️ Ice (control) | Umbral Ermine (melee) | Void Wisp (control) | Abyss Petrel (blaster) | **Void Bear** (tank, R) | **Abyss Leviathan** (tank/ctrl) |
| 🌿 Grass (tank) | Umbral Lamb (drain) | Void Hart (melee) | Nullshell Tortoise (tank) | Void Badger (bruiser) | **Oblivion Colossus** (tank apex) |
| 🏜️ Desert (support) | Void Dove (drain) | Null Idol (curse) | Umbral Jackal (debuff) | Null Camel (regen-denial, R) | **Void Anubis** (support/curse apex) |

**★ Void Dragon** *(SECRET, shared across all four eggs)* — rebirth dragon **#11 of 11**. The
grandest fallen: a dragon of pure void-black, an event-horizon silhouette edged in violet-red
that devours light; **hybrid** all-rounder. Pure void.

This completes the **11-dragon rebirth collection** (Base + Heaven 1–5 + Hell 1–5).
