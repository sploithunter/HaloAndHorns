# Pet Realm — Power Quick Reference

> Generated from `configs/powers.lua` (effects + costs), `configs/power_icons.lua` (badges) and the
> services that apply them. The badge = a **colored disc** (origin element) + a **white symbol**
> (effect) + a **ring** (targeting). Disc color by origin: **generic = white**, geomancer = **earth
> (green)**, sandwalker = **desert (yellow)**, cryomancer = **ice (blue)**, pyromancer = **lava (red)**.

## Legend — the three "where does it land" lanes

Every power lands in exactly one of these lanes (the firewall rule §16.5: player powers never deal
direct damage — offense is always routed *through the pets*):

| Lane | Meaning | Stored as | How you see it |
|---|---|---|---|
| **PLAYER** | a buff on you that colors your farming/economy/mobility | player attribute (`CoinYieldPower`, `MagnetBuff`, …) | self-power badge row **under your nameplate** + the dev **Buff-Stats** readout |
| **PET** | a defensive/offensive effect on your squad pets | pet attribute (`CombatShield`, `DefenseBuff`, `PetDamageBuff`) | **bubble** (shield) or **material reskin** (armor) on the pet + badge on its **squad card** |
| **TARGET (through a pet)** | a debuff on the enemy/crystal your pets are attacking | target attribute (`VulnerableMult`, `RootedUntil`) | **particle aura** around the target *(no icon above it yet — see note)* |

**Targeting ring** (the badge's outer ring): `self` = you/your squad · `single` = one target ·
`enemy_aoe` = all engaged enemies · `team_aoe` = squad-wide splash · `ally` = friendly.

**Debuff-on-target visual note:** target debuffs (Vulnerable / Root) currently render as a colored
particle **aura** on the enemy — there is **no symbol icon above the target's head yet**. (Easy add.)

---

## Generic pool — any archetype can slot these (white disc)

Farming / luck / utility / mechanic. All land on the **PLAYER** (or are instant mechanics). Magnitude
is an additive **fraction** that stacks via BuffStack (e.g. +0.5 = +50%, two of them = +100%).

| Power | Effect | Lane | AoE? | Multi-pet? | What it does | Badge (symbol·ring) | Focus / CD |
|---|---|---|---|---|---|---|---|
| **Prospector** | coin_yield | PLAYER | — | — | +50% coins for 30s | coins_up · self | 20 / 40s |
| **Windfall** | coin_yield | PLAYER | — | — | +200% coins for 10s (burst) | gift_up · self | 30 / 60s |
| **Mother Lode** | mining | PLAYER | — | all pets mine faster | +50% mining throughput 30s | capacitor · self | 25 / 45s |
| **Fortune** | luck | PLAYER | — | — | +50% luck (hatch/rare odds) 60s | clover_lucky · self | 20 / 45s |
| **Huge Fortune** | luck | PLAYER | — | — | +200% luck for 30s (marquee) | clover_huge · self | 50 / 120s |
| **Swift** | move_speed | PLAYER (+pets) | — | yes (pets keep up) | +40% move speed 20s | arrow_right · self | 15 / 25s |
| **Hasten** | recharge | PLAYER | — | — | −50% power cooldowns 20s | history · self | 20 / 60s |
| **XP Surge** | xp | PLAYER | — | — | +50% XP gain 30s | xp_up · self | 25 / 60s |
| **Magnet** | magnet | PLAYER | — | — | +30-stud drop collect radius 20s | magnet · self | 15 / 30s |
| **Revive** | revive | MECHANIC | — | one downed pet | instantly re-summon a downed pet (ignores cooldown) | revive · self | 25 / 30s |
| **Recall** | recall | PLAYER teleport | — | — | teleport to your last hatched egg / saved spot | pet_transfer · self | 10 / 30s |
| **World Travel** | world_travel | PLAYER teleport | — | — | teleport to the world hub (spawn) | portal · self | 10 / 30s |

---

## Defensive — on your PETS

Two distinct looks, never both from one power: **shield = absorb pool → element bubble**; **armor =
+Defense % → material reskin**. Armored pets also float a gold **armor badge** above them.

| Power | Archetype | Effect | Lane | Multi-pet? | What it does | Badge (symbol·ring) | Focus / CD |
|---|---|---|---|---|---|---|---|
| **Stone Skin** | geomancer | armor (+80 def) | PET (squad) | yes | hardened +Defense % reskin, 12s | armor_chest · self | 20 / 30s |
| **Ice Armor** | cryomancer | armor (+80 def) | PET (squad) | yes | ice-plating +Defense % reskin, 12s | armor_chest · self | 20 / 30s |
| **Bulwark** | geomancer | team_shield (+120 def) | PET (squad) | yes | squad damage-reduction 15s | armor_chest · self | 30 / 45s |
| **Dune Shield** | sandwalker | shield (absorb 40) | PET (squad) | yes | absorb bubble, 12s or until soaked | shield · self | 20 / 35s |
| **Ember Ward** | pyromancer | shield (absorb 40) | PET (squad) | yes | absorb bubble, 12s or until soaked | shield · self | 20 / 30s |
| **Mirage Step** | sandwalker | dodge (absorb 30) | PET (squad) | yes | evasion/absorb 8s | eye_hidden · self | 15 / 20s |
| **Aegis** | geomancer | shield (absorb 40) | **ONE selected pet** | no (single_pet) | focused bubble on your selected squad card | shield · self | 12 / 18s |
| **Ironclad** | geomancer | armor (+80 def) | **ONE selected pet** | no (single_pet) | focused armor reskin on the selected pet | armor_chest · self | 12 / 18s |

---

## Offensive buff — on the PLAYER, lifts every pet's damage

| Power | Archetype | Effect | Lane | Multi-pet? | What it does | Badge (symbol·ring) | Focus / CD |
|---|---|---|---|---|---|---|---|
| **Mountain's Strength** | geomancer | damage_buff (×1.5) | PLAYER → all pets | yes | every pet hits ×1.5 for 8s (PetDamageBuff, additive) | chevrons_up · self | 25 / 40s |

---

## Target debuffs — through a pet, onto the ENEMY (and now crystals)

Firewall-safe: the player doesn't damage the target; the debuff makes the *pets* hit it harder
(`VulnerableMult`) or locks it (`RootedUntil`). As of #174 the `vulnerable` family also applies to
**mined crystals** when the squad is farming. Magnitude = the damage-taken multiplier.

| Power | Archetype | Effect (family) | Lane | AoE? | What it does | Badge (symbol·ring) | Focus / CD |
|---|---|---|---|---|---|---|---|
| **Sunder** | geomancer | vulnerable ×1.6 | TARGET | **AoE** | armor-break: all engaged take ×1.6, 6s (+crystals) | shield_broken · enemy_aoe | 18 / 25s |
| **Expose** | sandwalker | vulnerable ×1.4 | TARGET | single | reveal/soften one target ×1.4, 8s | eye · single | 15 / 20s |
| **Disarm** | cryomancer | vulnerable ×1.3 | TARGET | single | weaken one target ×1.3, 6s | fist_broken · single | 18 / 25s |
| **Focus Fire** | cryomancer | vulnerable ×1.5 | TARGET | single | designate + soften priority target ×1.5, 6s | target · single | 12 / 15s |
| **Strike** | pyromancer | vulnerable ×1.5 | TARGET | single | quick single hit ×1.5, 4s | fist · single | 10 / 12s |
| **Mark of Flame** | pyromancer | damage_over_time ×1.5 | TARGET | single | burning mark ×1.5, 6s | contagion · single | 20 / 25s |
| **Sandstorm** | sandwalker | aoe_blind ×1.5 | TARGET | **AoE** | blind + ×1.5 to all engaged, 6s | eye_hidden · enemy_aoe | 35 / 50s |
| **Eruption** | pyromancer | aoe_damage ×2.0 | TARGET | **AoE** | ×2.0 to all engaged, 5s | fist_impact · enemy_aoe | 45 / 60s |

---

## Control — root/slow on the ENEMY

| Power | Archetype | Effect (family) | Lane | AoE? | What it does | Badge (symbol·ring) | Focus / CD |
|---|---|---|---|---|---|---|---|
| **Frost Bind** | cryomancer | root | TARGET | **AoE** | engaged enemies can't chase, 5s | hand_stop · enemy_aoe | 25 / 35s |
| **Blizzard** | cryomancer | aoe_slow (root) | TARGET | **AoE** | slow/lock all engaged, 6s | chevrons_down · enemy_aoe | 40 / 60s |
| **Cripple** | sandwalker | root | TARGET | single | slow/lock one target, 4s | target_down · single | 20 / 30s |

---

## Pyromancer signatures — exclusive, level-gated capstones (lava-red disc)

| Power | Lvl | Effect (family) | Lane | AoE? | What it does | Badge (symbol·ring) | Focus / CD |
|---|---|---|---|---|---|---|---|
| **Wildfire** | 15 | burn_spread ×1.6 | TARGET | single → **spreads** | vulnerability that contagions to nearby enemies every 1.5s within 14 studs, 8s | contagion · single | 25 / 25s |
| **Firestorm** | 20 | team_cleave ×0.5 | PLAYER → pets | **team AoE** | for 6s every pet swing splashes ×0.5 to other enemies within 8 studs | star_sparkle · team_aoe | 35 / 40s |
| **Cataclysm** | 30 | amplified_burst ×3.0 | TARGET | **targeted AoE** | meteor: each enemy in 16 studs takes squad-attack-total ×3.0 (credited to pets), then a molten pit lingers ×1.5 vuln for 4s | star_sparkle · targeted_aoe | 60 / 90s |

---

## How each lane is shown (visual handling)

- **PLAYER buffs** → a row of self-power badges **under your nameplate** (`PlayerPowerBadges`), each
  with a countdown that blinks near expiry; plus the Studio-only **Buff-Stats readout** (live
  effective ×attack/×coin/×luck/… multipliers).
- **PET shield** → an element-tinted **force-field bubble** on the pet (depletes as it soaks).
- **PET armor** → an element **material reskin** of the pet's body + a floating **gold armor badge**.
- **PET squad card** → the power's badge (disc+symbol+ring) appears on the right-side squad card.
- **Support-pet auras** (heal/defense/offense/yield) → a steady badge on every buffed squad card; they
  **stack** (N meerkats = N× coin yield).
- **TARGET debuffs** → a colored particle **aura** on the enemy/crystal (caster's element).
  **⚠ No symbol icon above the target yet** — candidate polish: a billboard badge over debuffed
  targets so "Sunder is on this one" reads instantly.

## Tuning knobs

All numbers above live in `configs/powers.lua` (`effect_kinds` magnitude/duration + per-power
`focus_cost`/`cooldown_seconds`/`archetype`/`target`). Badges map in `configs/power_icons.lua`
(`power_effect_badge`). Axis caps for the additive PLAYER buffs are in `configs/buffs.lua`.
