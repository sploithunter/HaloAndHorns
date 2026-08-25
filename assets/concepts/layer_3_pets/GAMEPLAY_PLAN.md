# Layer 3 egg and pet gameplay plan

This is the import-ready gameplay selection for the existing 40-pet Layer 3 roster. It deliberately
does not add placeholder `rbxassetid://0` definitions to `configs/pets.lua`: the pet and egg records
should be added only when their Roblox mesh, Basic texture, Golden texture, and card IDs exist.
Role mappings and live support-aura behavior are already reserved in `configs/pet_roles.lua`.

## Egg configuration

Layer 1 eggs cost 500 and Layer 2 eggs cost 900. Layer 3's configured reward multiplier rises from
16 to 22 (×1.375); applying that to 900 and rounding to a clean price produces a proposed cost of
1,300 origin coins. Keep the established 1-in-50,000 Huge roll and hidden 5% Golden / 0.5% Rainbow
variant rolls.

| Egg id | Display name | Currency | Cost | Pet weights in display order |
| --- | --- | --- | ---: | --- |
| `heaven3_fire_egg` | Gloryfire Egg | `lava_coins` | 1,300 | Gloryspark Cherub 50; Seraph Lion 26; Radiant Lance Seraph 6; Gloryscale Salamander 1.5; Empyrean Firehawk 0.26 |
| `heaven3_ice_egg` | Halo Frost Egg | `ice_coins` | 1,300 | Lumen Seal 50; Halo Wisp 26; Celestial Moth 6; Halo Bear 1.5; Empyrean Mammoth 0.26 |
| `heaven3_grass_egg` | Empyrean Grove Egg | `grass_coins` | 1,300 | Gloryleaf Lamb 50; Halo Hart 26; Lightbark Rhino 6; Bloomlight Sprite 1.5; Empyrean Grovekeeper 0.26 |
| `heaven3_desert_egg` | Oasis Egg | `desert_coins` | 1,300 | Bloom Ibis 50; Radiant Totem 26; Glory Mongoose 6; Light Tortoise 1.5; Oasis Dragon 0.02 |
| `hell3_fire_egg` | Ruinfire Egg | `lava_coins` | 1,300 | Dreadcinder Imp 50; Ruinmane Lion 26; Dreadlance Seraph 6; Ruinscale Salamander 1.5; Dreadfire Hawk 0.26 |
| `hell3_ice_egg` | Dreadfrost Egg | `ice_coins` | 1,300 | Duskfrost Seal 50; Dread Wisp 26; Dreadveil Moth 6; Dreadguard Bear 1.5; Dreadspire Mammoth 0.26 |
| `hell3_grass_egg` | Dreadthorn Egg | `grass_coins` | 1,300 | Thornleaf Lamb 50; Dread Hart 26; Ironbark Rhino 6; Dreadbloom Sprite 1.5; Dreadthorn Grovekeeper 0.26 |
| `hell3_desert_egg` | Dreadglass Egg | `desert_coins` | 1,300 | Ash Ibis 50; Obsidian Totem 26; Dread Mongoose 6; Obsidian Tortoise 1.5; Dreadglass Dragon 0.02 |

The two 0.02 entries are the layer's only dragons: one Heaven Desert Secret and one Hell Desert
Secret. No other Layer 3 origin contains a dragon.

## Combat selection

`single` means ordinary attacks remain single-target. “Periodic splash” is a cooldown ability with
`area_damage = true`; it advertises an area capability on the card but does not turn every swing
into AoE. `targeted_aoe` and `aura` are continuous attack geometry. Only those continuous-area pets
gain contagion when Huge under the central `PetTargeting.hugeAttackDot` rule.

| Origin | Heaven 3 selection | Hell 3 selection |
| --- | --- | --- |
| Fire | Gloryspark Cherub — melee, single. Seraph Lion — bruiser/tank, single. Radiant Lance Seraph — ranged, 7s periodic splash. Gloryscale Salamander — offense aura, single. Empyrean Firehawk — ranged apex, `targeted_aoe` plus a plain 18%/4s burn. | Dreadcinder Imp — melee, single. Ruinmane Lion — bruiser/tank, single. Dreadlance Seraph — ranged, 7s periodic splash. Ruinscale Salamander — curse, single. Dreadfire Hawk — ranged apex, `targeted_aoe` plus a plain 18%/4s burn. |
| Ice | Lumen Seal — melee, single. Halo Wisp — control, 3.25s root every 11s. Celestial Moth — ranged, 8s periodic splash. Halo Bear — tank, single. Empyrean Mammoth — tank apex, `targeted_aoe` with a 2s slow on the splashed cluster. | Duskfrost Seal — melee, single. Dread Wisp — control, 3.25s root every 11s. Dreadveil Moth — ranged, 8s periodic splash. Dreadguard Bear — tank, single. Dreadspire Mammoth — tank apex, `targeted_aoe` with a 2s slow on the splashed cluster. |
| Grass | Gloryleaf Lamb — heal, single. Halo Hart — melee, single. Lightbark Rhino — tank, single. Bloomlight Sprite — luck, single. Empyrean Grovekeeper — tank apex with `aura` damage and a 10% heal pulse. | Thornleaf Lamb — drain-heal, single. Dread Hart — melee, single. Ironbark Rhino — tank, single. Dreadbloom Sprite — curse, single. Dreadthorn Grovekeeper — tank apex with `aura` damage, a plain burn, and a 10% drain-heal pulse. |
| Desert | Bloom Ibis — heal, single. Radiant Totem — defense, single. Glory Mongoose — offense, single. Light Tortoise — regeneration, single. Oasis Dragon — Secret support capstone, `targeted_aoe`, 10% heal plus defense auras. | Ash Ibis — drain-heal, single. Obsidian Totem — curse, single. Dread Mongoose — curse, single. Obsidian Tortoise — regeneration denial represented by the live light curse seam. Dreadglass Dragon — Secret support capstone, `targeted_aoe`, 10% drain-heal plus shred and strong curse auras. |

Suggested periodic ability definitions when the pet records land:

```lua
heaven3_lance_volley = { damage_multiplier = 1.6, area_damage = true, cooldown = 7 }
heaven3_starfall = { damage_multiplier = 1.45, area_damage = true, cooldown = 8 }
hell3_lance_volley = { damage_multiplier = 1.6, area_damage = true, cooldown = 7 }
hell3_black_sparks = { damage_multiplier = 1.45, area_damage = true, cooldown = 8 }
```

The two Firehawks should author `attack_dot = { fraction = 0.18, tick = 1, duration = 4 }`. The
Dreadthorn Grovekeeper can use the same plain burn. It must not include `spread` on the normal pet;
only its Huge form receives spread. The mammoths should use `attack_control = { kind = "slow",
duration = 2, factor = 0.65 }`, which applies to the primary and splash targets through the existing
on-hit control seam.

## Huge rule

Every Huge still has area geometry. A normally single-target species becomes `targeted_aoe` and
stops there. If the base species is already `targeted_aoe`, `aoe`, or `aura`, the Huge retains that
geometry and gains a spreading burn: 15% per tick, 1s ticks, 4s duration, 8-stud spread, 1.5s spread
interval, four hops. A pet may tune this with `huge_attack_dot`. The runtime pet, squad HUD marker,
and inventory-card marker now resolve from the same rule.
