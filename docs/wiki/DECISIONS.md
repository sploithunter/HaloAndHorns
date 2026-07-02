# Decisions

Status: current

## Game Identity

The game is **Halo & Horns** (working codename "Pet Realm"). Core fantasy: hatch soul-bound pets, conquer the elemental ring, and tip your **Soul** toward Heaven (Halo) or Hell (Horns) — no neutral ending. The published store description (kept ≤1000 chars) is in `docs/STORE_DESCRIPTION.md`. The Roblox experience is "Halo and Horns" (see Roblox Places below for IDs). Internal branch/codename slugs may still use `pet-realm`/`game`.

## Config As Code

Content and tuning should live in `configs/*.lua`. Services should consume config rather than hardcoding content. Adding areas, breakables, eggs, pets, achievements, events, rewards, and similar content should usually be a config edit plus Studio markers, not a new script.

## Rojo And Studio Boundary

Rojo owns scripts, configs, UI logic, networking, validation, and service behavior. Studio/world builders own the physical map, art direction, terrain, decorations, and invisible gameplay markers. Systems bind to the map through tags, attributes, and contracted child-marker names.

## Map Binding

The project should implement `WorldBindingService` as the seam between hand-built maps and config-driven systems. Code should not hardcode map coordinates or fragile Workspace paths.

## Synthetic Map

The game should be able to run on a baseplate by synthesizing valid map hooks from config. Synthetic and authored maps must use the same binding API so tested mechanics transfer cleanly.

## Reference Game Usage

`/Users/jason/Documents/ColorfulClickers_exchange-rojo` is the preferred newer reference game. It is useful for ideas, not implementation style. Port concepts into this project's config/service architecture instead of copying scattered scripts.

## Economy Shape

The project should support multiple currencies, but the template baseline should stay small until balancing is understandable. Currency mutations should be tagged with source/sink metadata so the economy can be audited.

## Pet Assets

Pet models should be referenced by asset id where possible. Meshy can be used for developer-side asset creation, but generation and upload helpers are tooling only and must not run in-game or expose API keys to Roblox runtime code.

Rojo should not own individual pet model instances under `ReplicatedStorage.Assets.Models.Pets` for normal gameplay pets. `ReplicatedStorage.Assets` is a runtime cache populated from `configs/pets.lua` by `AssetPreloadService` through Roblox asset ids. A Rojo-managed model is only acceptable as an explicit exception when a variant declares a source such as `asset_source = "rojo"` and the reason is documented; otherwise adding a pet should be a config/data change, not a Studio tree edit.

The preferred pet creation workflow is reference-image first: create a clean white-background style reference, use Meshy image-to-3D or multi-image-to-3D in low-poly mode, texture with the same reference image, then store the downloaded GLB/FBX under `assets/source/pets/`. Prompt-only text-to-3D remains useful for exploration, but the reference-image route has produced better art-style consistency.

Long-term automation should be a repo-owned script pipeline that reads `assets/manifest/pets.json`, calls Meshy with local `MESHY_API_KEY`, downloads source exports, pauses for human approval, then optionally uploads through Roblox Open Cloud and updates the manifest plus `configs/pets.lua`. Meshy's MCP server may help interactive Codex work, but scripts in the repo are the portable canonical workflow.

The asset manifest may contain concept/generated assets before runtime config is updated. Statuses such as `concept` and `generated` are allowed to be manifest-only so artists/developers can iterate in Meshy without exposing placeholder asset IDs to game runtime config. Runtime wiring should happen only after approval and Roblox upload.

The long-term Pet Asset Manager should use `assets/manifest/pets.json` as the portable asset database and present a browser review UI for selecting approved pets, inspecting previews/models, and seeing duplicate warnings. File writes, Roblox uploads, asset ID persistence, and config generation should run through local repo scripts or a local dev server, not static browser code, because credentials and filesystem writes must stay outside the runtime game and outside committed files.

## Pet Rarity And Variants

Pet rarity belongs to the pet family. Variants such as Basic, Golden, and Rainbow are visual/stat treatments and should not automatically promote a normal pet into Mythical/Secret/etc. For example, Rainbow Bear is still a Common Bear with the Rainbow variant treatment; Dragon is Secret because the Dragon family declares `rarity = "secret"`, and Colorado is Exclusive because the Colorado family declares `rarity = "exclusive"`. Startup config validation requires every pet family to declare a valid rarity so content typos fail early.

Inventory card visuals should communicate both rarity and variant without letting one erase the other. Rarity controls data, tooltip text, special/unique rules, and the outer card frame. Variant treatments such as Golden and Rainbow layer animated inset rings and background treatments inside that frame, so a Common Rainbow pet still looks Rainbow while remaining visibly Common.

## Pet Identity

Pet config table keys are durable save IDs and must be treated as migration-sensitive. Player inventory stores IDs such as `bear` plus variant IDs such as `rainbow`, not display labels. Pet families and variants use `display_name` for player-facing names so typo fixes and renames do not corrupt inventories. Startup validation rejects malformed pet/variant/rarity IDs and missing display names, but changing an existing pet key still requires an explicit migration/backfill plan.

Inventory and hatch-facing pet titles should prefer the pet family display name, not the variant display name. Variant identity remains visible through card effects and tooltip fields, while traits that materially change identity, such as Huge, may prefix the family name.

Pet power has a single durable source of truth: `configs/pets.lua`. Pet families declare base power, variants apply configured multipliers, and per-copy inventory records must not store power/base-power/effective-power values. Inventory may store identity and mutable per-copy state such as level, XP, enchants, serials, hatcher metadata, lock state, and Huge/Eternal flags. Runtime systems may cache computed power on spawned models or transient folders, but saved profile data should be backfilled when legacy power fields are found.

## Pet Storage And Enchants

Normal pets should remain stack-count records keyed by canonical pet id + variant. The project should not add a generic stack-to-unique promotion flow for normal pets; it is easy to create one-off edge cases and hard to reason about at scale. Per-copy state belongs only on pets that are unique from the moment they are granted, such as configured Mythic/Secret/Exclusive/Huge/future tiers, special rewards, or future explicitly unique craft outputs. Enchants should be stored on the unique pet instance and contribute through the `enchants` modifier pipeline stage; stack records must stay free of enchant/progression fields. Enchant capacity is declared by rarity in pet config so tiers such as Mythic, Exclusive, Huge, or future larger tiers can change slot counts without service edits.

Pet XP and levels are unique-pet progression state. Stack records do not gain XP or levels. Unique pets may scale power from a config-driven XP curve and capped per-level multiplier. Enchant capacity remains the pet's potential slot count, while `unlocked_enchant_slots` is progression-driven; unique enchantable pets start with one unlocked slot and unlock remaining slots at configured level milestones.

Player level must affect gameplay. It should not be cosmetic-only. Player-level team power and level milestone rewards live in `configs/player_progression.lua`; the service feeds the shared modifier path and inventory equip-limit path rather than special-case consumers. The first reward pattern is additional equipped-pet slots every configured number of levels.

## Auto Systems

Auto-target choice and hatch auto-delete filters are profile settings, but valid modes, default choices, protected rarities, and filter dimensions live in `configs/auto_systems.lua`. Auto-target selection should be server-authoritative: the client can request work, but the server chooses the breakable. Hatch auto-delete happens before `PetGrantService` so filtered pets never enter inventory, and protected special rarities are not deleted by default.

## Pet Provenance

Valuable pet provenance and internal grant audit tags are separate. `grant_source` records the system reason a pet was created and should not be displayed as player-facing tooltip content. `hatcher_name` and `hatcher_user_id` record the player who created a valuable copy and may be displayed, traded, and preserved with the unique pet record.

## Stats-Derived Features

Pet index, achievements, and leaderboards should stay thin views over profile state and K1 stat counters. Pet index may persist compact first-discovery records because it is ownership history, but progress counters such as `distinct_pets`, `eggs_hatched`, and `breakables_broken` remain the shared source for achievements and leaderboards.

## Studio AI Workflow

Use Codex connected to Roblox Studio through the official Studio MCP server as the primary automated development workflow. Roblox Studio Assistant's external OpenAI/Anthropic/Google model settings currently require provider API keys; they do not replace Codex subscription access. Studio MCP plus Codex gives this project Output access, screenshots, play control, tree inspection, Luau execution, and script reads/edits without adding provider API keys inside Studio.

## Studio Smoke Tests

Automated Studio tests should move the player through real gameplay hooks rather than only calling service functions. Gate/teleport and egg-hatching tests should use Studio MCP movement/keyboard input where possible, with server-authoritative Luau assertions for currency, inventory, active area, and rejection cases. Visual assets are optional; invisible tagged markers remain the behavior source of truth.

## Marketplace

The reference game's external database/webhook marketplace should not be copied. If marketplace/exchange is implemented, it should be Roblox-native with escrow and anti-duplication guarantees.

## Multi-Agent Collaboration

The template (reusable infrastructure) and the game (Pet Realm) live in **one open monorepo**, worked by multiple agents on multiple machines (game agent, template agent, and delegated agents such as Cursor for small tasks). Rationale for one repo over two: Roblox has no clean way to depend on a whole template *project* (Wally packages libraries, not scaffolds; submodules add friction); the template is only meaningfully validated against a real consuming game; and one repo means one CI, one wiki, one issue tracker, and one PR queue — the universal substrate every agent understands. The template can be extracted to its own repo later via `git filter-repo` if it becomes a reusable starter; that decision is deferred until there is a second game.

Coordination is by **process, not repo separation**: branch-by-domain (`template/*`, `game/*`/`pet-realm/*`, `agent/*`), everything lands on `main` via PR gated by `mise run ci`, and `.github/CODEOWNERS` documents the template-vs-game path boundary. Cross-domain fixes follow **hybrid-by-size**: small/obvious template improvements found during game work are made on a `template/*` branch + PR; larger ones become GitHub issues labeled `template`. The real conflict surfaces are shared files (`docs/wiki/LOG.md`, `CURRENT_STATUS.md`, `.mise.toml`, `default.project.json`), which are treated append-only / dedicated-PR. Operational rules live in `AGENTS.md`.

## Roblox Places (Multi-Agent)

Agents use **separate Roblox places**, one per domain — not a shared place. Rationale: DataStores are universe-scoped, so a shared place means shared, interfering save data during tests; publishing conflicts when a place is open in Studio (two agents would collide constantly); and the game needs an **authored map** while the template needs a **clean/synthetic baseplate**. Code is shared via git (the source of truth); places are just runtime targets that legitimately differ in authored Workspace content and save data.

Assignment:
- **Halo & Horns game place** (game agent): the authored ring map + game; Studio-published. Universe ID `10245881416`, Place ID `133323124203350`.
- **Template / staging place** = "Place1", universe `10242349813`, place `117209749436107` (template agent + CI): mapless/synthetic (the template synthesizes hooks on a blank map); also the Open Cloud publish/staging target (`.env.local`).

Caveat: authored maps live in the place, not git (per the Rojo/Studio boundary). The Pet Realm map exists only in the Pet Realm place; an agent needing it opens that place in its own Studio.

## Focus Regen At Zero (Feature 12)

Open GWT question (Feature 12 — "Focus regen pauses while at zero"): resolved to **always regenerate** — no stun-at-zero. Rationale: the player is a no-HP, invulnerable *supporter*; locking their only resource at 0 punishes the support fantasy and adds a state with no counterplay. Sundering already provides the disruption pressure (it drains Focus and may extend power cooldowns) without a hard lockout. The behavior is config-flagged (`configs/focus.lua` `regen_pauses_at_zero = false`) so a future game can opt into a stun without code changes (`FocusMath.regen` honors the flag).

## Combat / Legacy Pet Loop (Phase 4)

Phase 4 builds combat (Feature 10) + Focus (Feature 12) as **server-owned, config-driven, headless-testable** systems: pure cores (`FocusMath`, `Targeting`, `CombatMath`) + `FocusService`/`CombatService`, with damage flowing through `PowerFormula` + the modifier pipeline (not cloned per-model scripts). This is also the home of issue #4 (replace the legacy `PetScripts/*` follow/mining-damage loop). The pure cores and the modifier-routed damage path are template-generic (reusable by any game on the template); the enemies/combat/focus *configs* are game-specific. Live spawning, auto-attack traversal, player-invulnerability visuals, and full removal of the legacy cloned scripts depend on authored enemy spawners / a Hell combat zone in the place (map work, user's hands) and are sequenced accordingly.

## Links

- [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md)
- [Studio Workflow](STUDIO_WORKFLOW.md)
- [Reference Game Insights](REFERENCE_GAME_INSIGHTS.md)
- [Foundation & Requirements](../FOUNDATION_AND_REQUIREMENTS.md)

## Combat Down / Recover — Slot-Cooldown Model (2026-06-01)

How a downed pet recovers, resolving the "stacked pets are OP" problem. Two timers, different jobs:

- **Slot cooldown (player-managed):** an active-squad slot is a *crew position*. When its pet leaves, the SLOT recharges before it can be re-crewed — this paces *throughput* independent of stack depth, so owning 1000 pets can't be spammed indefinitely. **Recall (proactive pull of a Strained/Critical pet) = short cooldown** (rewards attention but still capped); **fully downed = long cooldown** (the real cost). Both in `configs/squad.lua slot_recovery` (`recall_cooldown_seconds`, `down_cooldown_seconds`) — pure balance knobs, tuned against enemy DPS.
- **Per-pet / stack token bucket (kept as-is):** a downed instance is in spirit form; its stack's `ready_count` drops and refills over time (`StackPool`), and uniques use `lastDownedAt` (`SpiritForm`). You can't re-summon something that *just* went down; deep stacks are a resilience reserve, not infinite bodies.

Common case: deep stack → slot frees → re-summon a ready instance of the slot's assigned loadout pet (manual click now; auto via game-pass later). The slot is the binding timer; the bucket only bites when you down a type faster than it refills. Difficulty = enemy down-rate vs slot recharge; all slots down → safe-zone teleport, no death (§16.4).

Pets never die (§11.1). Staged degradation (Healthy→Strained→Critical→Spirit Form, §11.3) gives the agency to recall before a forced down. No potion revives (player-initiated **Sacrifice** power is the no-potion restore path, §16.5). Built systems (`SpiritForm`/`StackPool`/`ActiveSquad`) already model this; live combat (`EnemyService`) must be wired into them (currently uses a throwaway model-level `CombatDowned` flag).

UI: a City-of-Heroes-style **right-side squad HUD** — per-slot portrait + state/health + cooldown, click a pet (world or HUD) to target, act on it (recall / summon / [heal / buff via powers, later]).

## Squad HUD — Layout + Assist Targeting (2026-06-01)

- **Persistent right-side strip** (City-of-Heroes team-window style): one card per squad slot, always visible, **stable player-chosen order** (slot order = equip order, so players keep a preferred arrangement). v1 fixed to the right edge.
- **Cards are selectable targets.** Selecting a pet card drives power targeting two ways (the CoH "assist" elegance):
  - **Ally/support powers** (heal, buff, recall, summon) act on the selected pet.
  - **Enemy/debuff powers** act on **the enemy that the selected pet is currently targeting** (target-through-ally). The server already carries each pet's `TargetID`, so the client resolves the assist target from the selected slot.
- **Click-to-select from either side:** click the world pet model OR its strip card → selects that slot (highlights both).
- **Stretch (deferred, may not be feasible in Roblox):** fully movable/dockable HUD like CoH (drag panels anywhere). v1 is fixed-right; revisit later.

## Hatch Luck: Curved Index Bonus + Paid-Luck Rules (2026-06-12)

Full system + numbers in [Hatch Luck & Pacing](HATCH_LUCK.md). The durable rules:

- **All luck sources are ADDITIVE into one earned multiplier** (level curve, curved index bonus, bunny auras, events). Nothing multiplies over the player's grind; the only multiplicative path is the dev-only `test_mode.super_luck`.
- **Index bonus is curved** (`completion^2.5`, fit from simulation): the free 40% of the index pays ~10% of the bonus; the 90%+ grind earns the rest. The exponent is a feel knob — pacing is owned by the coin economy and index size, not by luck.
- **Paid luck is additive and species-only.** A "2x luck" gamepass adds +1.0 to the species channel: a fresh player gets exactly the advertised 2x, the stacked endgame player gets the same flat +1.0, and golden/rainbow chances never move (tradeable variant supply stays earn-only). Golden/rainbow boosts are separate channels for separate products/events.
- **Luck auras live on support-role pets only** — the squad-slot opportunity cost is the balance. The bunny stays common; the RAINBOW variant is the rarity gate. Watch equip-slot growth (it dilutes the tax) and don't repeat the colorado ranged+luck combo on farmable pets.
- **Endgame baseline assumes bunnies equipped** (90% index → 3+ rainbow bunnies): price luck products against 3.81x/~12% golden (3 bunnies) and 5.56x/~16% (10-bunny loadout), not the no-bunny rows.

## Build Versioning + Load-Screen Stamp (2026-06-13)

Jason: "when I publish, I want to see on the load screen what version it is and
when it was updated, so if something's not working I can tell if it actually
updated." Implemented as a git-stamped build info shown on the BootLoader:

- `VERSION` (repo root) — hand-bumped semver.
- `scripts/stamp_build.sh` (`mise run stamp`) — regenerates `configs/build_info.lua`
  from git (short SHA, branch, committer date) + the current time, all in Mountain
  Time (`TZ=America/Denver`, DST-correct). Stamps a `dirty` flag for uncommitted changes.
- The build/release/publish-studio mise tasks run the stamp FIRST, so every publish
  path re-stamps; rojo syncs the file into Studio for the live-publish workflow.
- `src/ReplicatedFirst/BootLoader.client.lua` reads `configs/build_info.lua` and shows
  `v<version> · <sha>[*]  ·  updated <Mountain Time>` at the bottom of the load screen.
  Falls back to "dev build" when unstamped (a live rojo Studio session with no stamp).
- `configs/build_info.lua` is COMMITTED (with the last stamp) so dev/CI/fresh-clone have
  a valid value; publishes overwrite it. Shape pinned by tests/headless/specs/build_info.spec.luau.

**Publish workflow:** run a publish task (`mise run publish-studio` / `release`) which
stamps automatically; or if publishing manually from Studio, run `mise run stamp` first
so rojo-serve syncs the fresh stamp before File → Publish.

## Biome Naming: "Earth" is canonical (2026-06-13)

The starter/green biome is named **Earth** — full stop, everywhere player-facing.
geomancer is its origin (earth mage), the egg is earth_egg, the pets are "earth
pets", biomes.lua registers id="earth", and PetBadge.element_alias maps the
internal element to the "earth" badge. Use **Earth** in all new UI, copy, and
content. Do NOT introduce "grass", "meadow", or "spawn" as the biome's name.

**Frozen internal id — `grass`.** The combat/RPS element id stored on every pet
(`petData.element`), keyed in elements.lua's RPS ring (lava→grass→desert→ice),
and the `grass_coins` currency, all use the legacy id **`grass`**. This is a
PERSISTED key (pet records + currency balances) — treat it like an old database
column: never rename casually. Code that keys by the biome element (e.g.
enhancements `area_origins`, ElementResonance) correctly uses `grass`.

Renaming the internal id `grass` → `earth` is a deliberate DATA MIGRATION
(migrate every pet's stored element + the currency balance + the RPS/badge
sweep), deferred until intentionally scheduled — not a casual find/replace. Until
then: **player sees Earth, storage says grass, and that mapping is the
PetBadge.element_alias.** This entry exists so we stop re-litigating it.

## Combat positioning — pets herd the fight; player position is a lever (2026-06-14)

Pet *attack positioning* is a deliberate combat layer, not just visuals:

- **Per-role attack styles** (`configs/pet_follow.lua attack.role_styles`, resolved by
  `PetFormation.resolveStyle`). In COMBAT the squad runs "individual" mode — each pet
  fights in character (tank=static_ring/planted, melee=orbit/weaving, ranged=firing_line,
  support=orbit, control=pincer). While MINING it runs "team" mode (everyone shares the
  player's saved formation). **Combat overrides saved settings** (Jason: "during combat
  all saved settings get overridden and it goes into combat mode"); the player's
  `PetAttackStyle` is a MINING pref and is ignored in a fight. May revisit later.
- **Ring orientation = a herding pole** (`attack.combat_ring_zero`). The attack wheel's
  angle-0 points either `toward_player` (default — pets interpose and PEEL/SHOVE enemies
  away from you) or `away_from_player` (pets take the far side and DRAW enemies toward
  you → the fight concentrates on your position). This makes the PLAYER'S OWN POSITION a
  tactic (funnel into a corner / choke). Default is `toward_player`; the spread it causes
  with multiple tanks is intentional friction (a full tank team is too chaotic to centre,
  so composition is a real choice). See EMERGENT_BEHAVIORS.md. Open: split the pole by
  role (tanks peel-away, dps draw-toward).
- **Map clamp + corner-pinning.** Anchored, non-colliding pets are clamped out of walls/
  rocks (reusing the crystal-spawner blocker rule: a solid part in an elevated box; flat
  ground ignored, dynamic stuff excluded). Pets hold at the wall instead of marching off
  the map — and can pin an enemy against geometry. Enemies are NOT given the same self-
  clamp (they must traverse to reach you; a hard stop would strand them).
- **Enemy fan** (`RingSeparate`): co-attackers on one target spread tangentially on a
  fixed-radius ring instead of stacking — positional only (proximity/threat/damage
  unchanged).

**Deferred:** enemy role-motion (a tank enemy like the raging bear should PLANT, so
tank-vs-tank stalemates) — the symmetric counterpart, not yet built.

## Realm Rosters & the 11-Dragon Rebirth Gate

There are exactly **11 realms** (Base/Earth + Heaven 1–5 + Hell 1–5) and **one SECRET-tier
dragon per realm**, so the dragon roster is a fixed set of **11**. Rebirth (the class-N climb)
requires hatching **all 11 dragon species yourself, at your current class** — the complete set,
not "a full team" loosely. The `player_class` provenance stamp (progression counts only
matching-class, hatcher-stamped dragons) blocks trading/buying/stockpiling past it; every rebirth
is re-earned across the whole stack. Two pure apex dragons cap the ends (Seraph at Heaven 5, Void
at Hell 5).

Realms **transfigure the 4 origins** (Fire/Ice/Grass/Desert) rather than adding a 5th element:
Heaven = ascended (radiant), Hell = fallen (corrupted). A pet keeps its **origin** (element/stats)
and gains a **realm** tag (treatment) — resolved via `src/Shared/Game/WorldContext.lua`. Every
heaven pet has a 1:1 hell mirror, so the rig/skeleton re-skins across the pair (and across several
of the 11 dragons), keeping 2 realms ≈ 1 set of work. Full rosters + the 11-dragon ladder:
[PET_REALM_HEAVEN_HELL_ROSTER.md](../PET_REALM_HEAVEN_HELL_ROSTER.md) and the Design Document's
"Dragons, Secrets, and Player Class (Rebirth)" section.

## Pet Combat: Orthogonal Axes Toolbox (2026-06-17)

Pet attacks are built from independent, composable axes, not bespoke abilities: **targeting**
(`single` / `targeted_aoe` / `aura` / `contagion`) selects WHO a swing/buff touches, and orthogonal
**effect** axes (DoT burn, on-hit Control, on-hit Shred/vulnerable) ride on top. Every axis is inert
until a pet declares it, so combos emerge from config (`targeted_aoe` + Control = AoE lockdown; the
Control + Shred + contagion "Trinity" kill-box). Effects live in a pure core (`OnHitEffects.lua`)
with keep-stronger composition so team multipliers refresh, never compound. SoT:
`docs/PET_REALM_STIER_POWER_COMBOS.md`.

## The Card Is the Power — displayed == dealt (2026-06-17)

The inventory card must always show the TRUE in-realm number a pet deals. Realm light/shadow resonance
and biome RPS fold into the displayed power via ONE shared helper (`ElementResonance.petRealmMultiplier`)
that both the server damage path and the client card call, so displayed and dealt are equal by
construction. Resonance is **weak-at-home / strong-abroad** (own-realm 0.8, opposite 1.5, neutral 1.0),
deliberately pushing cross-realm trading; alignment is derived from the pet's SPECIES realm, no per-pet
storage.

## Designated Powers Are the Differentiation Unit (2026-06-17)

A pet stops being a reskin when it carries a designated power, not just different stats. Archetype lines
(Blaster/Melee/Tank/Support/Controller/Dragon — `docs/lines/`) define each line's mechanical identity.
Role resolution depends on `pet_roles.by_type` membership — a pet absent from that map silently defaults
to melee (tanks aren't tanky, controllers/supports mis-resolve), so every new pet must be role-tagged.

## Realm Orientation — Heaven Farms, Hell Fights (2026-06-20)

The realms are mechanically asymmetric, resolved through a pure `Allegiance` core: a **heaven** attacker
is hostile only to **hell**, **hell** is hostile to **all**, neutral takes the current realm's side,
off-realm preserves attack-all. So a heaven enemy never aggros a heaven/neutral squad (peaceful farming)
but combat starts the instant you field a hell pet. Hell's supports express this via **give→take
inversion**: a `drain` aura is mechanically a team heal, and `shred` (`VulnerableMult` on the enemy) /
`curse` (`WeakenMult`, enemy deals less) weaken the foe instead of buffing the squad. Heaven supports use
the direct buff kinds.

## Enchant Strength: Hard +5 Cap, Per-Effect Odds, Read-Time Magnitude (2026-06-18)

Enchant level is hard-capped at +5 (no opaque value clamps). The strength roll lives on each EFFECT
(`effects[id].roll = {low,high,scale}`), rarity-INDEPENDENT, so "+5 odds" is one transparent number per
effect. A rarity's edge is its `type_multiplier` (magnitude) + slot count, NOT better odds. Magnitude is
resolved at READ time (base × pet-type multiplier), never stored, so a traded pet re-resolves on its new
owner. (Lesson: `mise run ci` does not run runtime ConfigLoader validation — config-shape refactors need
a matching validator/CI guard or they crash only at Studio boot. See `feedback_config_schema_not_in_ci`.)

## Player-Power Potency Lives in `magnitude` — enhancement-fold rule (2026-06-22)

Because of the no-direct-damage firewall, player-power potency lives in the `magnitude` axis, not in
`damage`/`healing`. An enhancement is only meaningful on a power whose offered axis has a real base;
otherwise it's a "lying" no-op. The rule: fold the offered axis INTO `magnitude` when that's where the
potency lives (damage→magnitude for buffs/vulnerability, healing→magnitude for heals), and otherwise GATE
the family to only the powers that genuinely read that axis (range→radius families, accuracy→roll-to-hit
families, spark→damage-crediting families).

## Per-Layer Income Is One Monotonic Lever; Depth Rescales Content Level (2026-06-23)

Income per realm layer lives in a single SSOT — `layers.lua` multipliers, monotonic so deeper is always
richer (base 1 / L1 5 / L2 8 / … / L5 17). Income must not be split across a second lever (the per-world
crystal `value_mult` was removed). Node toughness is a *separate* additive-by-depth lever (`health_mult`)
that absorbs the rising pet-DPS curve as squads grow; coins/sec ≈ `layer_mult / health_mult`, tuned
together but never conflated. Separately, `layers.level_offsets` (+9/depth) lifts the effective TARGET
level in the LevelDiffYield diminishing for mining + combat, tiling six ~9-wide bands across L1→50 so XP
keeps flowing in realms; a fresh realm's content is all above the player, so "any direction" unlock is
preserved.

## Enhancement Store: Static Pricing, Naturals-Only Buying, Sell Is the Gem Sink (2026-06-24)

Enhancements are bought/sold for **gems** with STATIC pricing (`buy = base + per_level × level`, flat
across types) — no dynamic market (exploit-prone, deferred). Buying is **naturals-only** so drop-earned
single/dual origins keep value; selling accepts all grades and is the intended gem sink (selling
enhancements is the dominant gem faucet). `grade_mult` is rarity-derived (dual ×1.54, single ×2.86) and
drives both buy and sell; `EnhancementPricing` is the headless SSOT. Buy-to-fill is surfaced inside the
slotting flow (purchase deferred to APPLY, CANCEL free), not a standalone shop; sell/salvage is its own
MenuManager panel. North star: signature powers afford 6 enhancement types → drop-only SET enhancements
(CoH invention sets) on the `augmentation.lua` set_bonuses scaffold.

## Reductive Axes Use Division — soft-cap by construction (2026-06-26)

Reductive enhancement axes (Focus reduction, recharge) use `base / (1 + Σ)`, never additive-with-clamp.
Division asymptotes toward zero but never reaches it, so a slotted power always costs something / has a
cooldown, and the `1/(1+Σ)` diminishing returns are themselves an ED-style soft-cap: local slots can't
zero a stat out, forcing accumulation of *global* set-bonus reduction to push further. This preserves
slot demand and the endgame perma-build chase. (Productive axes are ADDITIVE — `mag × (1 + Σpotency)` —
so same-axis sources don't compound.)

## Focus Is a Runtime-Only Resource (2026-06-26)

Focus is a runtime-only pool powering cast costs and per-second toggle upkeep (the CoH toggle economy).
It is **never persisted** — it refills to max in ~20s, far shorter than any logout gap, so saving it is
pure datastore thrash; a returning player is always effectively full. The pool lives in weak-keyed
in-memory server state. Endurance stays the pet resource; Focus is the player's. The "Focus" enhancement
(the only type that wants passives, `families="*"`) reduces upkeep/cost, read in `PowerService` not
`PowerStats`.

## Hasten Is a Timed Perma-Click, Not a Toggle (2026-06-26)

Hasten is the keystone of the perma-build chase, so it must be a TIMED click reachable by the recharge
axis (a toggle can't be touched by recharge). It self-bootstraps (shortens its own cooldown while active)
and cascades (shortens every other timed power's), so perma-Hasten perma's the rest of your timed buffs.
It accepts **recharge only** — potency is removed from the recharge family because potency's
multiplicative `cd*(1-mag)` lever would out-perform recharge at perma-ing a recharge power (degenerate).
Perma threshold is tuned to the full 6-slot recharge investment.

## Potion Anti-Runaway Model — BrewMeter (2026-06-21)

Potions are consumables modeled as one draining meter per axis where a normalized charge `[0,1]` does
triple duty so no vector runs away: **magnitude tapers with charge** (cap shown), a **sip closes a
diminishing fraction of the gap to full** (stockpiling wasted), and **duration is the drain**. This
structurally prevents 1000× magnitude or 1000× duration. Potions write their own `<axis>Potion` BuffStack
source so they stack additively with powers; `LOCK` = auto-maintain (auto-drink below a threshold). Pure
core `Shared/Game/BrewMeter`.

## Event Scheduling Is Mountain Time (2026-06-21)

Live-ops events schedule in Mountain time (America/Denver, DST-aware) via the pure
`Shared/Game/MountainTime`, not UTC. The seven-day weekday calendar (Mineral Monday … Secret Sunday)
gives each day one distinct economy axis; new event modifiers fold in at the same additive choke points
the Windfall/XP-Surge powers already use (`weekdays_utc` kept as a fallback).

## Exclusive Egg Origin Is 'creator' (2026-06-25)

Exclusive eggs (e.g. Colorado) use the matchup-neutral `creator` origin so an exclusive pet doesn't bias
the Heaven/Hell realm matchup. (A pet's area/origin SSOT remains its egg pool, not the static
`pets.lua` origin field; CI `pet_origin_integrity` enforces it.)
