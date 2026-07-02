# Pet Realm — Origin Powersets (working roster)

Status: **DRAFT for review** (not yet in `powers.lua`). Target: **11 powers per origin = 7 cores + 4
signatures**, symmetric cadence, role-balanced. Neutral pool (11) is already in config.

## Cadence (all origins identical)

| Tier | Levels |
|---|---|
| Cores | **L6 ×3 · L9 ×2 · L12 ×2** |
| Signatures | **L15 · L22 · L30** |
| Capstone | **L44** |

Order in the menu is by `unlock_level` then alphabetical (resolver already does this). Origins unlock
at L5 (`origin_choice_level`), so the first cores land at L6.

## New mechanics this roster introduces (5)

1. **Rage** — damage scales *inversely* with the pet's health (lower HP → higher damage). Late-game
   tank payoff.
2. **True Disarm** — suppresses the target's *attacks* (can move, can't act). A real control, not the
   current vulnerability-debuff mislabel. Control-glyph: hands/upper-body wrapped.
3. **Knockback-DoT** — knock the target back + damage-over-time while displaced (Geo "Seismic Event").
4. **`player_field`** — new TARGET type: AoE centered on the PLAYER; everything in radius gets the
   effect ("leap in and detonate"). Reuses the existing `pbaoe` FX pattern. 4 powers use it.
5. **Fear** — behavioral control: the target breaks and **flees** (can't attack). New "fleeing" state
   in the shared pet/enemy combat AI. Also enables *emergent retreat* (a unit that can't act backs
   off). The meatiest mechanic — own build slice.

Control taxonomy (glyphs): **Root** = feet wrapped · **Disarm** = hands wrapped · **Hold** = full-body
wrapped ("Capacitor" art) · **Fear** = flee.

---

## GEOMANCER — earth · tank / shield  *(no direct damage by design: augments the squad)*

| Lvl | Power | Type | Note |
|---|---|---|---|
| 6 | Targeted Armor | Pet Armor (single) | ↻ was Stone Skin |
| 6 | Taunt | Threat / aggro pull | ✚ new |
| 6 | Sunder | Targeted Debuff (armor−) | |
| 9 | Team Armor | Pet Armor (team) | ↻ was Ironclad |
| 9 | Mountain's Strength | Team Buff (dmg) | |
| 12 | Rage | Self Buff (HP-inverse dmg) | ✚ new mechanic |
| 12 | Armor Field | `player_field` (team armor AoE) | ✚ new |
| 15 | Bastion | Team Shield | sig |
| 22 | Seismic Event | Knockback-DoT | ↻ was Seismic Hold · new mechanic |
| 30 | Living Mountain | Pet Shield | sig |
| 44 | Gaia's Colossus | Summon | capstone |
| ✕ | ~~Aegis~~, ~~Bulwark~~ | (cut — shields covered by armors + Bastion/Living Mountain) | |

## SANDWALKER — desert · buffer / heal / illusion

| Lvl | Power | Type | Note |
|---|---|---|---|
| 6 | Restoring Sands | Heal (single, instant) | ✚ new |
| 6 | Dune Shield | Pet Shield (single) | ↻ single-target |
| 6 | Mirage Step | Self Buff (dodge) | |
| 9 | Expose | Targeted Debuff | |
| 9 | Sandstorm | AoE Debuff (blind) | |
| 12 | Fear | Control (flee) | ✚ **new mechanic — placed here** |
| 12 | Healing Field | `player_field` (heal AoE) | ✚ new |
| 15 | Oasis | Heal | sig |
| 22 | Mirage Veil | Team Shield | ↻ team (differentiates from Dune) |
| 30 | Simoom | Heal (AoE) | sig |
| 44 | Genie of the Dunes | Summon + revive | capstone |
| ✕ | ~~Cripple~~ | (cut — redundant debuff; Fear is the better control) | |

## CRYOMANCER — ice · controller  *(control trio: root / disarm / hold)*

| Lvl | Power | Type | Note |
|---|---|---|---|
| 6 | Frost Bind | Control — Root (feet) | |
| 6 | Ice Armor | Pet Armor | |
| 6 | Disarm | Control — Disarm (hands) | ↻ now a TRUE disarm · new mechanic |
| 9 | Focus Fire | Targeted Debuff (vuln) | |
| 9 | Ice Shard | Targeted Damage | ✚ new |
| 12 | Deep Freeze | Control — Hold (full / "Capacitor") | ✚ new |
| 12 | Frost Field | `player_field` (slow/freeze AoE) | ✚ new |
| 15 | Permafrost | AoE Control | sig |
| 22 | Shatter | Targeted Damage | sig |
| 30 | Absolute Zero | Targeted Control | sig |
| 44 | Eternal Winter | AoE Control (field) | capstone |
| ✕ | ~~Blizzard~~ | (cut — AoE slow covered by Frost Field) | |

## PYROMANCER — lava · damage  *(glass cannon: 1 shield, no heal/control)*

| Lvl | Power | Type | Note |
|---|---|---|---|
| 6 | Strike | Targeted Damage | |
| 6 | Mark of Flame | Targeted DoT | |
| 6 | Ember Ward | Pet Shield | |
| 9 | Eruption | AoE Damage | |
| 9 | Critical Strike | Team Buff (crit) | |
| 12 | Scorch | Targeted Debuff (−def) | ✚ new |
| 12 | Fire Nova | `player_field` (burn AoE) | ✚ new |
| 15 | Wildfire | AoE DoT (spreads) | sig |
| 22 | Firestorm | AoE Damage | ↻ was L20 |
| 30 | Inferno Brand | Targeted Damage | ↻ was L28 |
| 44 | Cataclysm | AoE Damage | ↻ was capstone@L30 |

---

## Balance read

Each origin **over-indexes on its identity** (symmetric specialization, like CoH primaries):

| Origin | Specialty (stacked) | Has | Lacks (by design) |
|---|---|---|---|
| Geomancer | Defense (5: 2 armor, 2 shield-sig, armor field) | buff, debuff, taunt, summon | direct damage |
| Sandwalker | Heal (4: 2 core, 2 sig) | shields, debuffs, dodge, **control (Fear)**, summon | damage |
| Cryomancer | Control (6: root/disarm/hold + 3 sig) | armor, debuff, 2× damage | heal |
| Pyromancer | Damage (7 across cores+sigs) | shield, buff, debuff, field | heal, control |

- **Fear → Sandwalker** is right on *both* axes: thematically (illusion/terror) **and** balance —
  Sand was the only origin with zero hard control, while Cryo is already control-saturated.
- **Capstones differ by type on purpose** (Colossus/Genie = summon · Eternal Winter = field · Cataclysm
  = nuke) — identity-appropriate, not an asymmetry to fix.
- Every origin has exactly **one `player_field`** (armor / heal / frost / fire) — clean symmetry.

## Still open / to build

- **`display_name`** on all cores (sigs already have them).
- Effects/mechanics for the 8 net-new powers + the 5 new mechanics.
- Cuts to confirm: Geo ✕ Aegis, Bulwark · Sand ✕ Cripple · Cryo ✕ Blizzard.
- Per-tier core level split (L6/9/12) is a first pass — tunable.
