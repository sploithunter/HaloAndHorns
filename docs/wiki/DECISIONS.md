# Decisions

Status: current

## Robux Purchases Are Permanent (2026-09-01)

Never wipe something a player bought with Robux. Rebirth, chassis
upgrade, family switch, wave reset, and checkpoint rewind may clear
*placements* and other run progress. They must not clear a Robux
entitlement, game pass, or any unlock flag that a pass will set.

The only spendable exception is an authored **developer consumable**
(potions and other explicit one-use items). Those are meant to be
used up. Game passes, Robux unlocks, and paid permanent benefits
are not consumables.

Admin Reset to Beginning is an operator tool, not a player rebirth.
It may still wipe Merge run state. It must not be used as the
pattern for a live rebirth.

## Merge Actions Are Async And Independent (2026-09-01)

Eggs, bulwarks, and cannons do not share a state machine with waves
or with each other. A system may *read* another system's live
position for targeting (pets, marchers, hatcher eggs). It may not
ask that system for permission to apply its own action.

- **Eggs:** create / merge / place mutate the board. They do not
  compare-and-swap `MergeDefense` and do not read `waveIndex`.
- **Bulwarks:** `MergeBulwarkPersist` owns wall keys only. Install
  writes the live profile table. No signature compare. No live wave.
- **Cannons:** `MergeCannonPersist` owns pad keys the same way. Fire
  still hands off to `PowerService`. Pads do not share chassis tier.
- **Waves:** start → result (auto or manual) → start. The only
  wave hook other systems need is an optional pause between two
  waves (`gap_after`, checkpoint intermission, later a tutorial
  insert between 10 and 11 or 1 and 2). Shops and the board are
  not unlock-gated on the live wave.

## Cannon Persist Is Independent Of The Wave Machine (2026-09-01)

Pad install/upgrade does not compare the encounter record to
`GameData.MergeDefense`, does not read `waveIndex`, and does not
rebuild the onboarding blob. `MergeCannonPersist` owns the tower
keys (`tower_owned`, `tower_slots`, left/right family+tier). Apply
uses the authored unlock wave only. A click writes that slice onto
the live profile table, then the pad respawns. Fire still lives on
the bay heartbeat and hands off to `PowerService`.

## Unlock, Place, And Upgrade Are Per Slot (2026-09-01)

Cannons and bulwarks use the same three-step tower-defense loop.

- **Unlock** is one-time and global. It grants the right to place
  Tier 1 of that family. The workshop shows LOCKED until that flag
  is set — do not grant the catalog for free. Playtest charges one
  Waycoin so testing does not need gems. Final unlocks will almost
  certainly be gems or a Robux game pass. Those flags are
  entitlements: rebirth and upgrade never wipe them. See
  **Robux Purchases Are Permanent**.
- **Rebirth** keeps every unlock flag and empties every pad and
  wall. Placement and upgrade are bought again. Players do not
  keep T2+ chassis across a rebirth.
- **Place** is paid per physical slot. Install always drops Tier 1
  on *that* pad or wall. A second pad or wall does not inherit the
  first slot's tier.
- **Workshop:** the right list is the picker only (LOCKED /
  UNLOCKED / TIER N). Unlock and Upgrade live on the left action
  card. Install is the bottom slot commitment and shows its coin
  price. Layout is unchanged.
- **Switch** is allowed but is not free and is not a refund.
  Replacing the family on a slot costs a new placement and drops
  that slot to Tier 1. Unlock stays. Do not free-swap every wave,
  and do not buy back spent upgrade coins. Revisit only if live
  play wants lock-until-rebirth instead.
- **Upgrade** is paid per slot and only advances the chassis
  installed on the commander/engineer you talked to.
- Cannon pads today: left and right. Bulwark slots today: lane
  (gold) and egg (red). Mid/front stay cataloged the same way.
- `owned[family]` is the unlock flag, not live chassis tier.
  Persist already stores `tower_slots` / `bulwark_slots` with
  `{ family, tier }`. Old saves that only have a global owned
  tier copy that number onto each installed slot once.

## Cannon Workshop Previews Are Live Side Views (2026-09-01)

The two artillery-workshop windows (Currently Owned and Next Upgrade)
clone `ReplicatedStorage.Assets.Models.MergeCannons` into a
per-window ViewportFrame that fills the existing preview pane.
Each window frames its own chassis: eye-level (camera Y equals bbox
center), 90° to the long silhouette, filled to
`team.edge_towers.workshop_preview.fill` with the rest as padding.
The two windows scale independently. Do not inset a smaller
aspect-locked frame inside the card.
Do not use Roblox `rbxthumb` of the Model asset — those cameras
are arbitrary and often top-down. Bulwark workshop cards stay
flat authored `previewDecalId` art; do not put ViewportFrames
in `MergeBulwarkMenu`.

## Game Identity

The game is **Halo & Horns** (working codename "Pet Realm"). Core fantasy: hatch soul-bound pets, conquer the elemental ring, and tip your **Soul** toward Heaven (Halo) or Hell (Horns) — no neutral ending. The published store description (kept ≤1000 chars) is in `docs/STORE_DESCRIPTION.md`. The Roblox experience is "Halo and Horns" (see Roblox Places below for IDs). Internal branch/codename slugs may still use `pet-realm`/`game`.

## Config As Code

This is a configuration-as-code game. **Everything** that is content,
art, or tuning lives in `configs/*.lua` (or a file those configs
already name). Services consume config. They do not own a second copy.

Adding areas, breakables, eggs, pets, achievements, events, rewards,
cannon/bulwark art, and similar content is a config edit plus Studio
markers, not a new script and not a hardcoded id in `src/`.

**Hard rule (restated 2026-09-01):** Model IDs, Mesh IDs, Texture IDs,
Animation IDs, Sound IDs, and workshop `previewAssetIds` never live in
Lua services or `*Progression.lua` tables. Swapping the configuration
for new models must change what the game loads. It did not, because
those numbers were hardcoded in code. That is a defect. If a value is
missing from config, add the config key; do not paste `rbxassetid://…`
into the caller. See `.cursor/rules/configuration-as-code.mdc`.

## Merge Workshop Previews Are Flat Assets (2026-09-01)

Cannon and bulwark workshop cards use uploaded transparent PNGs, not live
`ViewportFrame` models or Roblox model thumbnails. A card is a selection surface,
not a second 3D scene: live models add render work, inherit unstable import pivots,
and let larger ornate tiers crowd the surrounding UI.

Cannon preview sources are the accepted Meshy retexture alpha renders. The build
step normalizes all 24 variants onto a 256×256 RGBA canvas with a maximum 78%
silhouette footprint. Decal and underlying Image IDs live in the generated tier-art
configuration. `ImageLabel` consumes the Decal through `rbxthumb`: Studio verification
loaded all 24 wrapper URLs while direct `rbxassetid` delivery of their underlying Image
IDs failed. Model/Mesh/Texture IDs remain independently authoritative for world spawning.

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

Early-player XP pacing is source-tuned without changing the global level curve. Every award still mutates XP through `PlayerProgressionService:AddExperience`; callers may attach a stable activity key, and `configs/leveling.lua onramp.xp_mult_by_source` selects the below-threshold multiplier with `onramp.xp_mult` as the compatibility fallback. The level 1–4 mining and combat multipliers are both 2.5×; with current base values, on-level Small/Medium/Large ore pays 3/13/50 XP and an even-level trash minion pays 2.5 XP per enemy level. Level 5 resumes normal rates. This keeps mining/combat balance configurable and avoids making the whole 1–50 curve easier to repair one slow onboarding band.

## Auto Systems

Auto-target choice and hatch auto-delete filters are profile settings, but valid modes, default choices, protected rarities, and filter dimensions live in `configs/auto_systems.lua`. Auto-target selection should be server-authoritative: the client can request work, but the server chooses the breakable. Hatch auto-delete happens before `PetGrantService` so filtered pets never enter inventory, and protected special rarities are not deleted by default.

## Pet Provenance

Valuable pet provenance and internal grant audit tags are separate. `grant_source` records the system reason a pet was created and should not be displayed as player-facing tooltip content. `hatcher_name` and `hatcher_user_id` record the player who created a valuable copy and may be displayed, traded, and preserved with the unique pet record.

## Stats-Derived Features

Pet index, achievements, and leaderboards should stay thin views over profile state and K1 stat counters. Pet index may persist compact first-discovery records because it is ownership history, but progress counters such as `distinct_pets`, `eggs_hatched`, and `breakables_broken` remain the shared source for achievements and leaderboards.

Global leaderboards must scale by publishing one logged-in player's authoritative score, never by
scanning `PlayerData`. Each server recalculates at join, coalesces relevant live changes, and forces a
final replacement at leave/shutdown. OrderedDataStore retains/ranks the population; servers request
only the top 100 and boards show 10. Derived current-state scores (owned dragon count and strongest
legal squad) are allowed to fall after inventory changes, while lifetime crystal/enemy counters only
rise. Dragonlord counts hatchable world/Hall dragons (Abyssal Wyrm, Portal Drake, the 11-realm
secrets) — not boss exclusives such as Wyrmling. Immutable creator/test user IDs still publish; `hide_internal_accounts` hides them on the public page only. Do not RemoveAsync those keys.

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
- `mise run serve` watches `HEAD`, branch, and working-tree changes and refreshes
  the stamp continuously. The build/release/publish-studio tasks also stamp
  internally; Studio publish requires an active Rojo connection and pauses for sync.
- `src/ReplicatedFirst/BootLoader.client.lua` reads `configs/build_info.lua` and shows
  `v<version> · <sha>[*] · place v<Roblox version> · updated <Mountain Time>` at the
  bottom of the load screen. `game.PlaceVersion` is the authoritative publish boundary:
  Roblox increments it on every publish even if a local git stamp failed to sync.
- `configs/build_info.lua` is COMMITTED (with the last stamp) so dev/CI/fresh-clone have
  a valid value; publishes overwrite it. Shape pinned by tests/headless/specs/build_info.spec.luau.

**Publish workflow:** keep Rojo running through `mise run serve`. A publish task
(`mise run publish-studio` / `release`) stamps automatically; an ordinary manual
Studio File → Publish receives continuously refreshed source while PlaceVersion
still supplies a server-authoritative build boundary.

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
  `PetFormation.resolveStyle`). COMBAT and MINING both run "individual" mode so pets attack
  crystals with the same readable role language used against enemies: tank=static_ring/planted,
  melee=planted lunge plus post-hit sidestep, ranged=firing_line/recoil, support=orbit/cast,
  control=pincer/cast. The old saved `PetAttackStyle` remains readable in existing profile data
  for compatibility but is no longer exposed or used by the live controller. (Revised 2026-08-13.)
- **Ring orientation = a herding pole** (`attack.combat_ring_zero`). The attack wheel's
  angle-0 points either `toward_player` (default — pets interpose and PEEL/SHOVE enemies
  away from you) or `away_from_player` (pets take the far side and DRAW enemies toward
  you → the fight concentrates on your position). This makes the PLAYER'S OWN POSITION a
  tactic (funnel into a corner / choke). Default is `toward_player`; the spread it causes
  with multiple tanks is intentional friction (a full tank team is too chaotic to centre,
  so composition is a real choice). See EMERGENT_BEHAVIORS.md. Open: split the pole by
  role (tanks peel-away, dps draw-toward).
- **Direct close-to-target + exact scene clamp.** Every pet independently closes on the
  target selected by its own aggro table; grouping pets by target only computes formation
  slots and never suppresses an individual pursuit. Pets are anchored/non-colliding, so
  combat uses direct movement rather than navmesh pathfinding. The only veto is an elevated
  exact-collision `Blockcast` against authored scene geometry. Broad bounding-box overlap is
  forbidden here: one hollow LavaLair MeshPart enclosed the whole cave in its AABB and falsely
  pushed two of three foxes outside melee range. Pets hold only at a real wall/rock surface.
  Enemies are NOT given the same self-clamp (they must traverse to reach you; a hard stop would
  strand them).
- **Engaged-flyer combat floor.** Patrol/flee keeps each flyer's authored hover, but an
  aggroed flyer resolves combat altitude from the aggro owner's actual support floor: a short
  downward ray begins at `HumanoidRootPart.Y + engagement.flyer_combat_floor_probe_above_owner`
  at the owner's X/Z, then adds body half-height plus `flyer_combat_hover`. Never use the
  highest surface under the flyer for this lane; tall spikes/roofs otherwise become a false
  "floor" and create a vertical melee stalemate.
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

## Home World Enchant Is a Tier-Scaled Resonance Floor (2026-08-06)

`Home World` belongs to the individual pet that rolled it; it is not a global coin/crystal or squad
modifier. In the four Home biomes, resolve the pet's zone multiplier as
`max(normal biome RPS, 1 + rolled/type-scaled enchant magnitude)`. This preserves the ordinary
strong/neutral/weak matchup whenever it is better while making every metal tier meaningful. An
Exclusive pet therefore floors at +5/+10/+15/+20/+25% from Copper through Onyx. Heaven, Hell, and
special zones do not receive this floor, so the cross-realm trade game remains unchanged. Server
damage, inventory cards/sorting/tooltips, and the Studio stats HUD must use the shared resolver.

## Magnet Enchant Scales the Complete Player Pickup Radius (2026-08-06; revised 2026-08-27)

The historical saved effect id `crystal_finder` remains stable, but its player-facing and runtime
identity is **Magnet**, not a crystal-payout bonus. Resolve flat collection sources first
(`base + Magnet power`), take any larger absolute pet-ability reach, then multiply
that useful radius by the configured combined equipped Magnet-enchant factor. `DropService` publishes the
result as `CollectRadius`; clients display that server value verbatim. This makes metal/type scaling
meaningful without introducing a second collection formula or migrating existing pet records.

Auto Collector is deliberately orthogonal to Magnet. Its entitlement creates a passive,
inventory-free collector pet outside `PlayerPets`; that actor travels to physical currency using the
player’s published pet-speed axis and collects through its own configured 11-stud reach. It never
adds radius, consumes an equip slot, attacks, or enters enemy aggro enumeration. While waiting at
its follow position, its client presentation reuses the ordinary pet idle-meander behavior without
moving the server-authoritative pickup position.

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

**Trials are the explicit exception.** A mission publishes the config-selected `universal` aggression
policy for its duration, so every valid pet/enemy pairing can initiate. The mission's realm still drives
resonance independently: own-realm pets fight at 0.8x, opposite-realm pets at 1.5x, and base pets at 1.0x.
Leaving the mission restores the ordinary Heaven/Hell overworld aggression contract.

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

## Enhancement Effectiveness Window Is ±5 (2026-08-16)

Enhancements contribute within five levels of the player and become dead only at six levels behind or
ahead. Placement permits up to +5, and drops may reach L55 for a capped L50 player. The Power Choice
**Upgrade All** quote is outgrown-aware: an enhancement exactly five levels behind is still useful and
is not replaced or charged; at six behind it is upgraded to the current five-level shop band. Bulk junk
selling uses the same five-level boundary.

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

Enemy-target meters use the same model on the target rather than inventing a second consumable
system. Every caller invokes `PotionService:Use`; `meters[*].target` selects drink versus throw,
while each potion's config owns throw range and FX. Throws resolve the squad's canonical focus
through `EnemyService:GetFocusEnemy` (explicit assist → most pets attacking → nearest engaged) and
write through the additive `VulnMark` source path. The target owns and drains the charge, so a vial
cannot overwrite power vulnerability and powers/potions cannot disagree about which enemy is meant.

## Event Scheduling Is Mountain Time (2026-06-21)

Live-ops events schedule in Mountain time (America/Denver, DST-aware) via the pure
`Shared/Game/MountainTime`, not UTC. The seven-day weekday calendar (Mineral Monday … Secret Sunday)
gives each day one distinct economy axis; new event modifiers fold in at the same additive choke points
the Windfall/XP-Surge powers already use (`weekdays_utc` kept as a fallback).

## Exclusive Egg Origin Is 'creator' (2026-06-25)

Exclusive eggs (e.g. Colorado) use the matchup-neutral `creator` origin so an exclusive pet doesn't bias
the Heaven/Hell realm matchup. (A pet's area/origin SSOT remains its egg pool, not the static
`pets.lua` origin field; CI `pet_origin_integrity` enforces it.)

## Origin Choice Uses Config-Owned Progressive Disclosure (2026-07-13)

The four permanent origin choices name their combat role at first glance: Geomancer = Tank,
Sandwalker = Support, Cryomancer = Control, and Pyromancer = Damage. Their player-facing tagline,
description, strengths, and tradeoff live beside the origin definitions in `configs/archetypes.lua`,
not in a second UI-owned copy table.

Hover or gamepad focus gives a concise explanation. A click/tap only stages a full review with the
role, playstyle, strengths, tradeoff, and an explicit permanent-choice warning; it never writes the
selection. Only `LOCK IN <ORIGIN>` calls `archetype.select`, and the ordinary level-up commit remains
disabled until that decision is confirmed.

## Trial Group Size Is A Persistent Player Setting (2026-07-13)

Trial enemy density is an accessibility/difficulty preference, not an admin-only tuning command.
Settings exposes one percentage whose default, limits, and step are owned by
`configs/missions.lua`; the server clamps and persists it, and the mission opener's value controls
the whole party instance. It is independent of the enemy-level setting and composes with automatic
team-size scaling through the shared `PackScale` path. Pack selection stays seeded, every scalable
authored role keeps at least one representative, and objective bosses/titans remain singular and
mandatory. The initial 25%–200% range is intentionally a playtest range: establish the baseline
from live level-14 runs, then narrow the config limits without adding a second UI or service path.

Persistent Trial enemies are objective population, not replaceable patrols. Every static spawn is
bound to the containing generated room rectangle from the same `LayoutSolver.mapData` consumed by
the minimap. Chase, flee, loiter, and knockback use the shared movement-leash path and cannot cross
that room boundary. The combat event loop also treats an authoritative position outside the room as
an invariant failure: it clears the failed engagement and recovers the enemy to its immutable safe
`MissionSpawn` anchor. Persistent population otherwise leaves only through defeat or mission
teardown.

## Trial Bosses Are One Objective Anchor With A Level Curve (2026-07-13)

Boss-marked Trial packs belong only at the generated objective room. Ordinary MissionSpawn anchors
exclude them through the explicit `missions.population.boss_only_at_objective` policy, while the
objective anchor guarantees exactly one. This replaces accidental weighted boss density: a live
Heaven Grass run produced four Worldbloom Ents even though the intended interaction was one boss
guarding the objective.

Pet-model boss stats resolve through the pure `MissionRankScale` path using the opener's level,
captured once when the instance is created. The rank's ordinary values remain the level-50 endpoint;
its config-owned `level_scaling.at_min` block defines the level-14 endpoint for HP, basic damage,
armor, and ability damage, with a clamped linear interpolation between them. This keeps current
level-50 tuning intact while making the first reachable Trial tier independently balanceable without
service-code constants or a second boss-synthesis path.

## Visible Combat State Has One Application Boundary (2026-07-17)

Runtime combat mutations and their feedback are one authoritative operation. `CombatApplication`
owns `ApplyHit`, `ApplyDamage`, and `ApplyPowerHeal`: resolved misses/avoids publish without a health
change, while damage and active healing publish only after the real HP or pet-endurance change.
Contribution credit is part of damage application rather than a caller-owned follow-up.

`Combat_Result` is the one player-visible result stream and the independent
`CombatTextController` is its sole floating-text presenter. Feature remotes may still drive attack,
impact, and area animation, but they must not carry a second damage/heal/miss number. Passive
out-of-combat regeneration remains a direct, silent state-maintenance write; spawn/scaling, admin
reset, revive restoration, and test setup are likewise not combat applications.

## Crowd Control Separates Movement From Action (2026-07-17)

Root, disarm, and hold are three distinct control states. Root prevents movement but permits attacks
and powers. Disarm permits movement but prevents every active action, including basic attacks,
abilities, support casts, and active self-healing. Hold combines both restrictions. Blind remains the
accuracy-debuff family; disarm must not duplicate it or act as a vulnerability/damage-taken debuff.

All actor action gates should use the shared `CrowdControl` semantics so delayed attacks also fizzle
when disarm or hold lands during their windup. Movement gates deliberately exclude disarm.

## Downtime Recovery Is Passive, Not A Rest Power (2026-07-17)

Every living, non-downed pet recovers without a button. Five seconds after its last hit it keeps the
ordinary flat regeneration; once the squad has been out of combat for 15 seconds, recovery accelerates
to at least 12.5% of that pet's maximum endurance per second. This makes the remaining recovery window
at most eight seconds regardless of pet strength and permits movement between pulls.

This is silent state maintenance, not a power heal: it does not publish floating healing text, revive a
downed pet, bypass resurrection sickness, or run while the squad is still marked in combat.

## Area Controls Declare Their Center And Candidate Scope (2026-07-17)

An AoE's target mode is not enough to define its geometry. Each area control owns both a real radius and
an explicit center/scope contract. Frost Field is a 20-stud player-centered root; Shatter is a 20-stud
target-centered vulnerability burst. Permafrost and Eternal Winter select the focused enemy's authored
encounter group and then clip it by radius, while Absolute Zero is target-centered.

The same enhanced radius and resolved center drive target membership, the gameplay circumference, trace
output, descriptions, and Range-enhancement eligibility.

## Control Counters Telegraph Before They Remove Holds (2026-07-17)

Support-role enemies are hold-immune and may cleanse nearby held allies after a visible 1.5-second
windup. Disarm interrupts that cleanse and forces a short retry delay, preserving player counterplay.
Bosses and archvillains are not blanket hold-immune: a successful hold always locks them for the
2.5-second breakout windup, after which they clear it, gain four seconds of hold resistance, and put
breakout on a 24-second cooldown.

These counters are special actions, not ordinary enemy powers. A boss can therefore complete a
breakout while held, but a support cleanse still obeys the action gate so Disarm can stop it.

## Defensive Powers Are Compared By Prevented And Restored Damage (2026-07-17)

Balance decisions use the opt-in `[DefenseTrace]` decomposition rather than badge magnitude alone. It
records raw damage, native and power defense, armor prevention, shield absorption, Mirage restoration,
damage applied, and remaining shield.

The first controlled Infernal Boss pass showed a standard 201.3-raw blow landing for 100.6 after a
tank's native defense. Ice Armor at 80 prevented only 28.8; its magnitude is now 160, preventing 44.7
from that same blow across its 12-second window. Dune Shield remains a front-loaded 400-point pool.
Mirage Veil remains a 450-point team-signature pool whose heal consumes that same pool; live traces
showed 30.2 absorbed plus 120 restored, followed by 150.9 absorbed plus 104.2 restored, without
creating a second durability budget.

## Focus Fire Is Accuracy Setup, Not Another Vulnerability (2026-07-17)

Focus Fire marks one enemy for eight seconds. Only the caster's pets and hostile powers receive its
flat +15-percentage-point to-hit bonus, so simultaneous players own independent mark channels. The mark
itself remains a hostile accuracy roll; Accuracy helps it land, Potency raises the to-hit bonus,
Duration extends it, and Recharge shortens its cooldown. Damage enhancements do not fit it.

A landed hold against an innately `HoldImmune` enemy has a fixed 25% chance to penetrate while that
caster's mark is active. This exception does not penetrate `HoldResistUntil`: the temporary resistance
earned by a boss breakout remains absolute. Ordinary accuracy resolves before immunity penetration, so
combat feedback distinguishes `Miss` from `Immune`.

## Phone Power Bar Keeper (2026-08-20)

The keepable compact phone layout is **horizontal, bottom-center**. Do not lose it:
2×10 slots, `mobile_width_scale = 0.81`, matching 48px columns (Pets above Menu on the
left, Powers above Board on the right), ADMIN in the far lower-left corner, Jump keeps
the far-right slot, PlayerBar 390×68 with scale-inset XP/Focus tracks. Game-pass +
toggle badges live as columns on the far left (`vertical_left`). Restore badges under
the Roblox chrome with `power_badges.placement = "top_chrome"`. While the battle
list has engaged foes, the badge column hides (Settings → Hide Toggles in Battle,
default on). EnemyHud stays above the badges (DisplayOrder 40 vs 26).

## Mobile HUD Uses Independent Persisted Presentations (2026-08-10)

HUD density and squad presentation are separate persisted preferences. HUD layout retains its
device-aware `Auto`/`Compact`/`Classic` choice, while squad presentation is explicitly
`Classic` (the default), `Bar`, or `Circle`. Experimental squad layouts therefore never replace the
established player experience until selected in Settings.

Quest presentation is independently persisted as `Full Bar` (the default), `Compact Pill`, or
`Progress Ring`. Pill and Ring are resting states, not separate trackers: both reuse the live quest
description, count, and tweened FillBar. Pressing either compact presentation expands the readable
full bar and pressing again collapses it. A new objective opens it for four seconds and real progress
opens it for 2.5 seconds, so compact mode does not hide context when the objective changes.

Compact currency rests on gems plus the current origin; pressing it reveals every origin balance.
The squad handle is also press-to-toggle rather than hold-to-peek, because an open roster must remain
interactive for pet targeting. Combat or pet damage may open a compact roster automatically. In Bar
mode, pressing the player portrait beside `MY TEAM` collapses it again; the Circle presentation uses
the central handle. Every presentation renders explicit empty positions through the player's current
pet capacity, without a plus glyph that would falsely imply an action. Pet rows reuse canonical
thumbnails and archetype/status information, and all presentations consume the same live pet state.

## Console Input and Ten-Foot Layout Are Independent Axes (2026-08-13)

Controller support is routed through semantic game actions, not duplicated controller-only gameplay
code. Buttons use Roblox `Activated`; world interactions use `ProximityPrompt`; the controller router
only selects and invokes the existing authoritative seams. Modal selection is contained by the
active custom menu and returns to the opening control on close.

The current input method and the physical display class are separate state. Connecting a controller
to a desktop changes glyphs and navigation but not HUD scale; a console television keeps ten-foot
safe margins even if another input device becomes most recent. This prevents the common failure where
input switching causes the entire layout to jump between desktop and couch presentations.

## Challenge Field Is The Hall_2 Range (2026-08-20)

The Challenge Field is the Hall_2 Tile04_corner Range / Training Ground gauntlet, not a Worlds
Plaza spoke. Room 1–99 is a difficulty index **and** a fixed layout sequence (`gauntlet_room`
/ Range `room#N` / Training Ground `train#N`) so ranking is fair: everyone's Room N is the
same map. Early rooms teach (one chamber, two lava imps). Late rooms cap at entry + 3.
Settings **Enemy Level** and **Trial Enemy Group Size** do not apply — everyone enters at
the mode's authored level and pack count. Persist `GameData.ChallengeRuns.<mode>.best_room` only when a run exists — do not
put `ChallengeRuns` on the ProfileStore template (same Reconcile trap as Tutorial). No pet
revives; a downed slot stays down for the run (no HUD timer) and cannot be filled
by a new pet. Roster swaps stay legal on the stamped entry tile for white slots
only. Overworld red slots stay reserved for 60s — unequip/re-equip does not free
them. Leaving a gauntlet converts a run-long slot lock to that 60s lock. Squad wipe ends the run and records the last cleared room. Range entry reuses
InventoryPanel cards and Best Pets plus the existing PowerChoice menu (origin + tooltips);
it does not ship a second card or power renderer. A shared client draft lets the two menus
flip without writing the live squad or power loadout until Enter. Catalog Range is exclusive:
only the picked loaned powers work (server allowlist; owned passives are cleared). Loaned
powers auto-slot — Hasten 6 recharge, all others 3 recharge + 3 focus — so ranking stays
fair and players do not slot by hand. Auto-cast locks clear on Range enter and exit because
the lock is on the slot, not the power. Range is solo-only (a party cannot share the ranked
instance). Catalog Range pins combat to level 50 (`effective_level` on the
mode, stamped as `ChallengeLevel`) so ranking is fair — same
`EffectiveLevel` seam as sidekick, no sidekick offset, no ProfileStore
field, claimed/earned Level unchanged. Kill XP still pays from earned
Level (`xp_from = "earned_level"`, optional `xp_mult`) so Range is not a
leveling machine. Training Ground does not pin and skips the overworld
`min_engage_level` onramp (`skip_engage_gate`) so a reachable door fights.
Current Range / Training Ground boards are fixed, clock-aligned award rounds of
best cleared room, published through the existing one-player OrderedDataStore
pipeline. An entrant remains visible for the complete round even when offline.
At the boundary every server drops the old cache and reads a new round-suffixed
logical OrderedDataStore, so the board clears atomically without enumerating
profiles or relying on each attempt's age. The board header counts down from the
same configured boundary. Persist `recent` attempts only when a run exists — not
on the ProfileStore template. Release cadence is one America/Denver calendar day,
midnight to midnight. Resolve each boundary through `MountainTime` rather than assuming
86,400 seconds, because DST transition rounds are 23 or 25 hours. Immutable creator/test
IDs still write; release `hide_internal_accounts` removes the canonical internal-account
set from both the public page and placement awards. Studio global reads/writes are disabled.
Each player's award state uses that same round start and retains the lowest numeric
rank (best placement) reached in the round. Expiry creates a stable-id outbox award;
a generic ProfileStore message delivers it on the active session or next return
through RewardService, with the claim ledger and message acknowledgement saved
atomically. Every new durable message keeps a fixed claim deadline 30 days after
the award was created; queue retries do not renew it, and an expired message is
acknowledged without a grant on the player's next return. Durable deliveries open queued click-through receipts; the Gauntlet
receipt names and pictures the Champion Egg. Hidden IDs are never observed or paid
while `hide_internal_accounts` is enabled for release.
Each of the four origins keeps its own saved power kit plus a shared last
catalog squad under `GameData.RangeDefaults`; do not put that field on the ProfileStore
template (same Reconcile trap as ChallengeRuns / Tutorial).

## Disable Hall Routing; Preserve the Hall and Move Challenges Home (2026-08-22)

Hall of Worlds remains authored for repair but is not a legal player destination for this release.
Every join and character respawn goes to Homeworld Spawn regardless of saved Hall state. The schema
migration changes only resume/unlock routing: it removes Hall route ids, preserves every other
unlock and all player-owned/profile data, and leaves the Hall progress ledger intact.

The original Homeworld tutorial is restored as version 4. Range and Training Ground keep their
existing mission behavior but their complete authored fixture Instances move into Homeworld Lava
and Desert respectively. Map geometry and bindings move in Studio; runtime discovers the same tags
and attributes. Historical Hall tooling must never create replacement copies once
`Home.ChallengeBindings` exists.

## Split onboarding from optional activation (2026-08-24)

The Roblox onboarding funnel ends at tutorial complete (Rally, including
the combat-training beats). First quest, First Steps, and first area are
optional, so they must not sit after Rally in the same sequential chart —
that reports "tutorial finishers who skipped an optional quest" as a
cliff. Those goals use a separate named Activation funnel that starts at
join, so conversion is of all players.

## Merge Defense Is Endless; Its First Catalog Recycles as Prototype Huge (2026-08-27)

Preserve Waves 1–20 as a deterministic opening, then generate ten-wave checkpoint cycles without
exceeding 32 enemy bodies. Difficulty grows through rank replacement and additive stat/reward
multipliers rather than unbounded model counts.

The current 28 Home/Heaven/Hell origins through Layer 3 run once normally and once as forced
prototype-Huge NPC tiers, producing 56 merge tiers. Forced Huge state is ephemeral combat
presentation only and must never become a durable player Huge, index entry, or registry record.

Treat approximately Wave 140 as a balance horizon, not an endpoint. Merge-only rebirth grants an
additive +100% of base allied Merge damage per rank without discounting eggs or multiplying drops.
The first two authored ranks cost 50,000 and 200,000 Waycoins; no third rank exists until its price
and progression gate are deliberately authored. Rebirth resets the active wave/checkpoint, board,
deployed eggs, and Merge wallet, but never pets, player level, world unlocks, or Gem upgrades.

## Rage Cannon Is A One-Time Berserk Circle (2026-09-01)

Do not use the tank Rage power and do not invent a tick loop. Landing
is the Healing Field MagicCircle, tinted ruddy red, as a one-shot
telegraph. Each unit inside the circle gets one no-consume Berserk
Brew sip on that model (`PotionService:SipBrewOn` → existing
`BrewMeter.sip`). Do not sip the owner: player `PetDamageBuffPotion`
broadcasts to every pet and makes the radius a visual only.
Stacking is the brew's diminishing sip; it will not climb far. Tier
knobs are fire `interval` and circle `radius` only. Sip size stays
the brew's `sip_fraction`. No Focus, no flask consume, no player
cooldown. Rage fires at one ally already in combat
(`rage_target = "combat_pets"`: `TargetType == Enemy` on a live
wave enemy, or that enemy's `AggroTargetRef`). That pet gets the
sip; any other ally inside the landing circle gets it too. Idle
pets and empty-lane shots are not aims. Heal still aims injured
pets. Aim does not sip the owner.

## Heal Cannon Tiers Are Magnitude And Fire Rate (2026-09-01)

Do not change Healing Field ticks (`hot_tick` stays 2s). A heal tier
only edits two numbers: the existing per-tick `magnitude`, and that
pad's shot `interval`. Overlapping fields still stack. Tuning is
config (`shot.landing.heal.magnitude` / `interval`); T1 starts at the
authored field (110) and the shared 2.4s cadence.

## Reuse Existing Powers — Do Not Rebuild Them (2026-09-01)

If a power already exists, cast that power. Do not pull its
visualization out, restamp a decoy rune, and rebuild ticks beside it.
Healing Field was the exception to "visuals first": it already had a
look and a combat loop, so the heal cannon lands by placing that same
`_healZone` at impact. New cannon roles may still wait on missing
telegraphs. This does not spend Focus or start the player cooldown.

## Cannon Gameplay Tier Selects Distinct Art At Uniform Scale (2026-09-01)

Supersedes the temporary scale-only decision. Heal, Rage, Debuff, Gravity,
Repulsor, and Nullifier each ship four distinct tier meshes. Runtime must request
the gameplay tier directly and must not substitute `current_art_tier`, apply a
`tier_scales` table, or derive one tier by resizing another. Templates keep scale
1 and normalize to the shared 7.953594-stud reference width. Presentation size
is per-tier `worldScale` on `configs/merge_tier_art.lua` (every Tier 1 is
0.375, matching the tuned Rage T1; Tiers 2–4 stay 0.5).
Barrel facing is per-tier `barrelYawDegrees` (Rage T1 is 270; others 0).
Pad sit is per-tier `seatOffsetY`, scaled with `worldScale` (0.55 at
0.375, 0.733 at 0.5). Do not
hardcode those numbers in the spawn/aim path. The proof manifest
must retain 24 distinct concept hashes, Model IDs, Mesh IDs, and Texture IDs.

## Ability Cannons Land On The Floor (2026-09-01)

Heal, Rage, and other power-laying shots place the projectile on the
ground under the target (`land_at = "ground"`), matching the ring.
The ball blooms out (`ability_impact = "bloom"`) instead of lingering
at chest height. Keep it quiet; do not add a second explosion.

## Cannon Fire Recoil Never Owns Cadence (2026-09-01)

A shot freezes aim and plays a short vertical lurch from
`team.edge_towers.shot.recoil`. That window must stay shorter than the
fire interval and must not write `MergeTowerNextFireAt`. If a later
interval is shorter than the kick, the next shot wins and starts a new
kick from the fresh aim pose.

## Cannons Never Fire Behind the Breach (2026-09-01)

A pad cannon may not aim at a target on the egg/hatcher side of
`BreachLine`. That plane stays the unique overrun line; this is only a
shot filter. Heal aims injured pets via `CombatDamageTaken` and uses
the same breach floor until a tighter `heal_fire_line` is proven.
Mid is the computed halfway between the two existing planes — do not
author a third combat part for it.

## Land Sharks Hunt One Marcher and Drag It Under (2026-09-01)

Land Shark combat is a pet-like chase, not a lane DoT. Territory is the full
strip width plus hunt range toward the gate. Count is 4/5/6/7 by tier. One
shark claims one live target, leaves the wander, bites on cadence, holds the
marcher, and pulls it down into the water. T3 venom is one proximity cloud per
marcher. T4 prefers an unclaimed boss but will not drop a drag. Death prefers
the `sink` style. Shark kills do not stamp `MergeEggPlayerPetKillUserId`.

## Impaler Palisade Stops, Then Breaches (2026-08-31)

The Stop wall shove deals no damage. Each marcher is shoved toward the gate with
the same displacement as tank Seismic, pinned briefly, and must leave the line
before the next bounce. Tier is bounce count (1/2/3/4), per marcher, not wall HP.
T3 stamps a permanent venom DoT on the bounce. T4 adds a permanent contagion
plague that hops to nearby marchers. Wave fights end, so the burn dies with them.
Combat opens on the crossing after charges are spent.

## Merge Combat IDs Establish Fronts but Do Not Strand Idle Teams (2026-08-27)

Keep per-team `CombatTargetGroup` values for readable opening assignments. Once the complete wave has
been out for a short grace period, a defender with no live target may opt into open combat and
duplicate the hardest engaged enemy. Rank wins before durability: boss, lieutenant, tank, then
ordinary units. Preserve at most one idle reserve while enemy-group pressure is below defender-team
capacity; commit every team when pressure reaches capacity. Any Bulwark crossing releases the
reserve immediately for the rest of that wave. This is ordinary threat seeding, not a forced focus,
so tanks and existing aggro tables remain authoritative.

## One Atomic Merge Bay Expands into a Portable Ten-Bay Realm (2026-08-27)

Keep `Workspace.Maps.MergeEggPrototype` as the only authored combat-lane source. Build five Heaven
and five Hell bays by transforming complete clones around a shared open-rift hall; never split the
lane into tiles or reintroduce chunk streaming. Decorations belong outside the playable lane seams
and reuse the prebaked Flora/MissionProps registries.

Random bay allocation and explicit empty-bay claims are server-owned and transient. The Home
prototype retains one active combat session until the dedicated-place migration replaces its
singleton runner with per-bay state; physical layout readiness is not permission to duplicate one
`_active` table across ten owners.

Persist only reconstructable checkpoint state at completed ten-wave boundaries. Save the isolated
wallet, board inventory, base generator, deployed egg tiers, and objective count immediately;
reroll ephemeral NPC rosters at full health on resume. Rebirth/Admin Reset clear this checkpoint,
while Gem upgrades and Rebirth rank remain durable.
