# Pet Realm — Signature Powers (design)

> **Design goal:** each of the four origins gets **4 signatures** — one **role-defining anchor** that
> makes that origin near-irresistible if you want that role, two mid-tier signatures that deepen the
> fantasy, and one **near-endgame capstone**: crazy damage on a long recharge. Firewall rule §16.5
> still holds — player powers never deal direct damage; "damage" routes *through the pets* (the
> `amplified_burst` family scales a burst by the squad's attack total and credits it to the pets), so
> every capstone is a pet-amplified meteor, not a player nuke.

**Role identity per origin** (the anchor each origin should "own"):

| Origin | Element | Role identity | The anchor (must-pick) |
|---|---|---|---|
| Geomancer | earth (green) | **SHIELD / tank** | Bastion |
| Pyromancer | fire/lava (red) | **DAMAGE** | Wildfire + Firestorm |
| Cryomancer | ice (blue) | **CONTROL** | Permafrost |
| Sandwalker | desert (yellow) | **HEAL / sustain** | Oasis |

Legend: **family** = the effect_kind family it routes through (✅ exists today, 🆕 needs a new mechanic).
**target** = single · enemy_aoe · targeted_aoe · team_aoe · friendly. Costs are starting points to tune.

---

## 🟢 Earth — Geomancer (SHIELD / tank)

| # | Power | Lvl | Role | Mechanic (family) | What it does | Target | Focus / CD |
|---|---|---|---|---|---|---|---|
| 1 | **Bastion** ⭐anchor | 15 | shield | absorb ✅ (big magnitude) | the premier squad shield — every pet gets a huge stone barrier that soaks a ton before it cracks. If you want SHIELD, you take Geomancer for this. | team_aoe | 30 / 35s |
| 2 | **Seismic Hold** | 22 | control+def | root ✅ + defense_buff ✅ | stone spikes ROOT every engaged enemy *and* harden the squad (+Defense) for the duration — a tank lockdown. | enemy_aoe | 30 / 40s |
| 3 | **Living Mountain** | 30 | sustain | defense_buff ✅ + heal-over-time 🆕 | the squad becomes a moving mountain: massive +Defense and a heal-tick each second for a window — near-unkillable while it lasts. | team_aoe | 40 / 55s |
| 4 | **Gaia's Colossus** 🌟capstone | 44 | endgame **SUMMON / tank** | summon 🆕 + taunt | **call a pet:** a giant Stone Colossus joins your squad for ~20s — it taunts every enemy (pulls all aggro off your pets), soaks enormous damage, and slams for big AoE pet-damage. A wall *and* a fist. | summon | 70 / 120s |

---

## 🔴 Fire — Pyromancer (DAMAGE) — *3 exist, +1 new*

| # | Power | Lvl | Role | Mechanic (family) | What it does | Target | Focus / CD |
|---|---|---|---|---|---|---|---|
| 1 | **Wildfire** ⭐anchor | 15 | damage | burn_spread ✅ | a vulnerability mark that **contagions** to nearby enemies — turns a pack into a bonfire. *(exists)* | single_spread | 25 / 25s |
| 2 | **Firestorm** ⭐anchor | 20 | damage | team_cleave ✅ | for a window every pet swing **splashes** to nearby enemies — clears crowds. *(exists)* | team_aoe | 35 / 40s |
| 3 | **Inferno Brand** 🆕 | 28 | damage | vulnerable ✅ (ramping 🆕) | brand one target; its vulnerability **ramps up every second** it stays alive (execute pressure on tough targets/bosses). | single | 20 / 22s |
| 4 | **Cataclysm** 💥capstone | 40* | endgame dmg | amplified_burst ✅ (lava) | the meteor: **squad-attack-total ×3** to everything in 16 studs + a molten pit. The "huge long-recharge targeted AoE." *(exists — suggest re-leveling 30 → ~40 to make it true endgame.)* | targeted_aoe | 60 / 90s |

---

## 🔵 Ice — Cryomancer (CONTROL)

| # | Power | Lvl | Role | Mechanic (family) | What it does | Target | Focus / CD |
|---|---|---|---|---|---|---|---|
| 1 | **Permafrost** ⭐anchor | 15 | control | root ✅ (long/strong) | the premier lockdown — roots & slows every engaged enemy for the longest duration in the game. If you want CONTROL, you take Cryomancer for this. | enemy_aoe | 25 / 30s |
| 2 | **Shatter** | 22 | control→dmg | vulnerable ✅ (bonus vs rooted 🆕) | detonate the frozen: enemies currently rooted/slowed take a **massive vulnerability spike** — the payoff for your control. | enemy_aoe | 25 / 28s |
| 3 | **Absolute Zero** | 30 | hard CC | root ✅ (global) | flash-freeze **every enemy on screen** solid for a long window — mass hard crowd-control to reset a fight. | enemy_aoe | 45 / 60s |
| 4 | **Eternal Winter** 🌟capstone | 44 | endgame **HOLD** | root ✅ (global, very long) | a crazy *hold*, not a nuke: **the entire field freezes solid** — every enemy hard-frozen and unable to act for a long window, while frozen targets take bonus damage from your pets. Total board control to trivialize a wave/boss adds. Long recharge. | enemy_aoe | 70 / 120s |

---

## 🟡 Desert — Sandwalker (HEAL / sustain)

| # | Power | Lvl | Role | Mechanic (family) | What it does | Target | Focus / CD |
|---|---|---|---|---|---|---|---|
| 1 | **Oasis** ⭐anchor | 15 | heal | heal ✅ (+ HoT 🆕) | the premier heal — a burst that refills the squad *and* a strong heal-over-time. If you want HEAL, you take Sandwalker for this. | team_aoe | 25 / 30s |
| 2 | **Mirage Veil** | 22 | evasion+heal | dodge (absorb) ✅ + heal-on-evade 🆕 | the squad shimmers: big evasion/absorb, and each dodge **heals** the pet — sustain through a fight. | team_aoe | 20 / 25s |
| 3 | **Simoom** | 30 | heal+control | heal ✅ + aoe_blind ✅ | a swirling sandstorm: **heals the squad** inside it while **blinding/softening** every enemy caught in it. | team_aoe | 35 / 45s |
| 4 | **Genie of the Dunes** 🌟capstone | 44 | endgame **SUMMON / heal** | summon 🆕 + heal ✅ + revive ✅ | **call a pet:** a colossal Sand Djinn rises for ~20s — on arrival it **instantly revives every downed pet** and full-heals the squad, then showers a strong heal-over-time the whole time it floats above you. The "never wipe" button. | summon | 70 / 120s |

---

## Summary

- **4 anchors** (near-irresistible by role): **Bastion** (shield), **Wildfire/Firestorm** (damage),
  **Permafrost** (control), **Oasis** (heal). Pick your role → pick that origin.
- **4 endgame capstones — each a DIFFERENT kind of "crazy," matched to the origin's identity** (not all
  damage, ~L44, 90–120s recharge):
  - 🟢 **Gaia's Colossus** — *summon* a stone guardian pet (tank + smash)
  - 🔴 **Cataclysm** — *crazy damage* (the meteor — damage is fire's whole identity)
  - 🔵 **Eternal Winter** — *crazy hold* (freeze the entire field)
  - 🟡 **Genie of the Dunes** — *summon* a Djinn that mass-revives + heals (never-wipe)

### What's already there vs new
- **Reuse (✅):** absorb, defense_buff, root, vulnerable, heal, burn_spread, team_cleave,
  amplified_burst, revive — most of the 16 route through existing families, so they're badge-ready and
  firewall-safe out of the box.
- **New mechanics (🆕):**
  - **Summon-guardian** (Gaia's Colossus, Genie of the Dunes) — the meatiest add: a temporary
    server-owned pet model that joins the squad, taunts/tanks or heals, then despawns. New, but a huge
    marquee — and the "call a pet" idea you wanted. Reuses the pet-combat + heal/taunt seams.
  - Small variants of existing families: heal-over-time tick (Living Mountain, Oasis), ramping
    vulnerability (Inferno Brand), bonus-vs-rooted (Shatter), heal-on-evade (Mirage Veil), global root
    (Absolute Zero, Eternal Winter).

### Implementation order (suggested)
1. **Cataclysm** is already live; **Eternal Winter** is the cheapest new capstone (global root, no new
   system) — ship it next so two of the four marquees are in fast.
2. The **role anchors** (Bastion/Permafrost/Oasis) — these define each origin; all reuse existing families.
3. The **summon capstones** (Gaia's Colossus, Genie of the Dunes) — build the summon-guardian system
   once, both use it. This is the big creative payoff.
4. The **mid-tier 6** with their small new mechanics.

All slot into `configs/powers.lua` (`effect_kinds` + `powers` with the `signature`/`unlock_level`
schema), badges auto-resolve via `configs/power_icons.lua`, and they apply through the existing
PowerService families. Capstones reuse the Cataclysm VFX path tinted per element.

---

## Build status — SHIPPED ✅ (#178)

All 16 signatures are implemented and live-verified. Built in three stages:

- **Stage 1** (`da27e1d`) — config + families: 13 new effect_kinds + power defs (signature schema,
  unlock levels), archetype pools, badge glyphs, and PowerService combo branches (`root_guard`,
  `fortify`, `heal_blind`) + `_healPet`. Friendly casts verified (Bastion shields all 4 pets, etc.);
  enemy-targeted ones share the existing engagement gate (verified identical to Sunder/Eruption).
- **Stage 2** (`5389dc2`, `b515564`, `d385675`) — the summon-guardian system: `SummonService` spawns a
  temporary guardian that joins the squad, trails the player (auto-grounded + raised), buffs/heals,
  then despawns. **Gaia's Colossus** = squad +Defense ×220 (the wall) + ×1.6 pet damage (the fist);
  **Genie of the Dunes** = mass-revive + full-heal + heal-over-time. Real models wired
  (Colossus `95238379643484`, Djinn `88120936939949`); `configs/guardians.lua` `model_asset` swaps
  them, else a scaled+tinted squad-pet placeholder. Both verified live with screenshots.
- **Stage 3** (`a7bd88e`) — mid-tier depth (config knobs):
  - **Living Mountain / Oasis** — heal-over-time (`_healOverTime`): Mountain pulses 30/2s; Oasis adds
    a 20/2s tail after its big upfront heal.
  - **Inferno Brand** — ramping vulnerability (`_rampVulnerable`): the mark grows 1.9→2.6 over 8s.
  - **Shatter** — ×1.4 again on FROZEN (rooted) targets (2.2→3.08): the freeze→shatter payoff.
  - **Mirage Veil** — heal-on-evade: EnemyService heals the pet each time the veil turns a blow aside.

Config knobs: `hot`/`hot_tick`/`hot_seconds`, `ramp_to`, `frozen_bonus`, `evade_heal` (all in
`configs/powers.lua` effect_kinds); guardian tuning in `configs/guardians.lua`. CI 576/576.
