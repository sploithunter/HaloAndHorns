# Current Status

Status: current

## Summary

This is a Rojo Roblox project: a config-as-code template that **is becoming the game "Pet Realm" (Halo & Horns)** — a heaven/hell directional pet game. Template Phases 0–11 are complete (data spine, map integration, economy depth, stats/achievements/leaderboards, progression, the full Halo & Horns feature build P0–P10: data spine, pets & power, layer slice, party core, combat & focus, archetypes/powers/augment/hotbar/rosters, social/trade/fusion/rifts, reward spine, quest/daily/shop UI, escrow trade — plus P11 the SSOT pet-inventory model). On top of that baseline the **Pet Realm game layer** is the active lane: per-biome zone economy, mining/combat balance, the PetPower mining/combat split, an XP-everywhere level-50 system with a claimed-vs-earned split + Ascension Altar, a level-diff accuracy curve, and a bounded "pets-are-stars" power model with a Creator ceiling — all bound to the pinned progression/power/teaming design spec. See the **"Pet Realm" section below** for the current game state; the older phase sections remain as template-baseline history. The playable loop: mine biome ore → earn biome coins → hatch eggs → grow/equip a pet squad → claim levels (powers/slots/egg-hatch) → unlock zones toward the (planned) heaven/hell realm axis.

## Working Systems

- Rojo project builds and lints.
- Roblox Studio sync workflow is active.
- Data saving works after enabling Studio API access and saving the experience to Roblox.
- Breakable crystal spawners are present and visually tuned on the baseplate.
- Coin generator exists so testing can fund egg hatching.
- Eggs can hatch pets from configured asset ids.
- Original reference bear asset was restored for style consistency.
- Rainbow pet visual effect exists and applies to models such as Rainbow Bear.
- Admin control panel opens and includes event/effects testing commands.
- Global event support has started, including scheduled event concepts and a UTC event clock.
- `ConfigLoader` now validates all loaded configs at startup and has focused validators for core gameplay configs.
- Phase 0 foundation services are in place for profile schema versioning, stat counters, modifier resolution, currency ledger aggregation, deterministic UTC day/seed behavior, and feature flags.
- Studio Play boots successfully through the validated config loader; current remaining Output noise is warning-level placeholder/test data such as monetization ids and unknown legacy saved effects.
- **Boot is event-driven and gated** (`docs/BOOT_ORCHESTRATION.md`): `BootReadiness` milestone latches + a `configs/boot.lua` dependency graph + a `BootOrchestrator` that validates the graph, logs `[BOOT] milestone ready`, and mirrors readiness to `ReplicatedStorage.BootStatus`. Producers signal (`world_structure`/`models_ready`/`crystals_ready`/`eggs_placed`/`icons_ready`); consumers (pets, crystals, eggs) `await` instead of polling/aborting/fire-once-waiting — the class of fast-boot races (pets not deploying, crystals only filling on the 30s safety-net) is closed. The loading screen renders those real milestones as informative phases.
- Roblox Studio MCP is enabled and connected to Codex. Agents can now read Output, capture Studio screenshots, start/stop play, inspect the game tree, execute Luau, and read/edit Studio scripts through the official Studio MCP bridge.
- Phase 1 now has `configs/areas.lua`, `configs/markers.lua`, `WorldBindingService`, `ZoneService`, synthetic multi-area baseplate hooks, server-authoritative `TeleportPad`/`Portal` travel, and `BreakableSpawner` binding through `SpawnZone` when available.
- Synthetic `Spawn` and `Meadow` areas are configured. Spawn stays live for the starter loop; Meadow breakable spawning stays dormant until a player travels/enters it.
- Authored reference-map readiness exists: `scripts/studio/create_reference_map.luau` creates a tiny Studio-owned `Spawn`/`Meadow` marker map, and `tests/studio/MapContractSmoke.lua` verifies the live marker contract.
- `default.project.json` now keeps unknown Workspace instances, so Rojo sync does not delete designer-authored map geometry.
- Studio-only automated smoke testing has started with `StudioSmokeTestService` and `tests/studio/EggProximitySmoke.lua`.
- Spawn placement is now map-derived: `ZoneService` places characters at the active area's authored floor/`SpawnZone` through `WorldBindingService`, so the player does not fall when the Studio-owned map is offset from config defaults.
- `configs/upgrades.lua` and `UpgradeService` now provide permanent upgrades for pet equip slots, pet storage, and crystal reward value. Upgrade levels persist under `DataService.Upgrades`; inventory slot limits read the upgrade effects server-side.
- `Meadow` now has a paid unlock cost of `100 crystals`, and its breakable table includes stronger medium/big crystals. This is the first area-gated Phase 2 progression step.
- Phase 2 network bridges exist for UI/admin work: `PurchaseUpgrade`/`UpgradeResult`, `UnlockZoneRequest`/`ZoneUnlockResult`, and `ZoneTravelResult`. Locked-zone results include the configured unlock requirement payload.
- Pet inventory storage is already mixed: normal pets stack under `Inventory.pets.items["petId:variant"]` with a quantity, while special pets are individual records. Equipping a stacked pet creates an ephemeral equipped id and temporarily decrements the stack quantity.
- Clicking an inventory stack card now equips another copy from that stack when quantity remains. Clicking the equipped ghost card unequips that specific equipped instance.
- Phase 3 configs are live: `configs/pet_index.lua`, `configs/achievements.lua`, and `configs/leaderboards.lua`.
- `PetIndexService` records first-time pet/variant acquisition under `DataService.PetIndex`, increments/syncs `distinct_pets`, and grants index milestones once.
- `AchievementsService` listens to `StatsService.CounterChanged`, evaluates config tiers over K1 counters, stores completed tiers under `DataService.Achievements.Completed`, and grants rewards once.
- `LeaderboardService` builds in-server live boards from K1 counters and has a throttled OrderedDataStore path for global boards when config enables it.
- Inventory now allows adding to an existing pet stack even when storage slots are full, because existing stacks do not consume new slots.
- Admin tools now include zone lock testing controls. Developers can toggle, lock, paid-unlock, or bypass-unlock `Meadow` from the admin panel, and custom zone lock input supports future `zoneId:toggle|lock|unlock|bypass` testing.
- Locked portal/pad travel now shows a player-facing notice with the target area's unlock cost instead of only logging `ZoneTravelResult`. Travel hooks also have `ZoneTravelPrompt` proximity prompts for paid locked gates, and the client hides those prompts once the local player owns the destination so unlocked travel stays touch-only.
- Pet config now supports imported asset transform metadata. `asset_transform.scale` normalizes a model's default size, `asset_transform.orientation` fixes imported facing in degrees, and `asset_transform.huge_scale` controls the runtime size multiplier for pets stored with the `huge` trait.
- The Colorado Plays creator pet is configured from two Roblox model assets: normal/rainbow use `100466492312776`, golden uses `121192248833075`. Admin tools can grant basic, golden, rainbow, or huge Colorado for scale/orientation testing.
- `PetGrantService` now centralizes pet grants for hatching, admin tools, and Studio scripts. `PetSerialService` allocates global huge serial numbers before the pet is inserted into inventory, so future trading can preserve the entire unique pet record.
- Colorado Plays is currently an eternal pet family. Equip rebuilds cache team-relative `EffectivePower` from the configured eternal percent and top-team-average baseline, while preserving the pet's configured power as the minimum. Huge pets clamp to at least `100%` of that baseline. Inventory pet hover details now show power, base power when different, eternal percent, baseline, huge serials, enchant capacity, and stack count.
- Enchant capacity is now controlled by pet rarity config: Mythic pets get `1` slot, Secret/Exclusive pets get `2`, and Huge pets get `3`. Rarities with enchant slots are granted as unique pet records going forward; normal stacked pets stay stack-only and are not planned for generic stack-to-unique promotion.
- Phase 4 pet progression has a first foundation slice: `configs/pet_progression.lua` and `PetProgressionService` define unique-pet XP curves, max levels by rarity, capped power growth, and enchant slot unlock milestones. New unique pets keep their full potential `max_enchantments` but start with configured `unlocked_enchant_slots` (currently one slot) and gain the rest through levels.
- `configs/enchants.lua` is the single source of truth for enchant chance and behavior. It defines rarity roll profiles, roll counts, weighted chance entries, strength low/high/scale ranges, duplicate policy, reroll cost, and modifier mappings. The initial template ports the useful ColorfulClickers concepts (`HomeWorld`, `Luck`, `SecretLuck`, `Tactics`, `Leadership`, `Efficiency`) into config-first effects and adds this-game examples for crystal rewards, coin rewards, and pet XP.
- `EnchantService` rolls hatch-time enchants for eligible unique pets through `PetGrantService`, exposes server-authoritative manual rerolls through `EnchantPetRequest`/`EnchantPetResult`, and registers equipped unique pet enchants as `enchants` modifier providers. Live enchant consumers now include `breakable_reward`, `pet_xp`, `hatch_luck`, `secret_hatch_luck`, `pet_damage`, `team_power`, and `pet_efficiency`.
- Map-authored enchanter stations now bind through `EnchanterStation` hooks. The current Studio `Workspace.Enchanter` model is tagged as `basic_enchanter`, uses its `EnchantTouchPart` child as the touch/prompt volume, keeps its floating cosmetic scripts, and opens a dedicated pet enchant panel for server-authoritative rerolls.
- Equipped unique pets now receive configurable breakable-destroy XP through `PetProgressionService:AwardBreakableDestroyed`. `BreakableSpawner` calls this after contribution rewards, and pet XP can itself be modified by enchant effects such as `scholar`.
- `configs/player_progression.lua` and `PlayerProgressionService` now make player level affect team power through the modifier pipeline and grant extra equipped pet slots at configured level milestones. The initial default is +1% team power per level after level 1, capped at +100%, and +1 equipped pet slot every 10 levels capped at +3 bonus slots.
- `scripts/balance_team_power.py` is available for offline balance passes. It reads current pet/progression/player-progression configs and estimates team power across team size, pet level, eternal/huge rules, and the configured player-level power curve.
- Pet mining still uses a stabilized legacy `Follow` script cloned onto pet models. Phase 4 routes pet damage and efficiency modifiers through it, but a future service-owned PetWork/Combat loop should replace this bridge for cleaner tests and configuration. **Tracked: template issue #4** (do during Phase 4 Combat).
- Huge-and-above provenance is now captured as separate hatcher metadata. Future grants stamp `hatcher_name`/`hatcher_user_id` for pets meeting the configured provenance threshold; `grant_source` remains non-displayed audit data. `tests/studio/BackfillPetHatcherProvenance.lua` can backfill existing qualifying pets for the current Studio player.
- Pet tooltip metadata visibility is driven by `configs/inventory.lua` `tooltip_fields`, so fields can be hidden, labeled, or ordered without editing `InventoryPanel`.
- Pet inventory cards now distinguish rarity/specialness and variant separately. Rarity rings are config-driven and can animate around the card using a `UIGradient`; the default rarity ladder currently includes Common, Uncommon, Rare, Epic, Legendary, Mythical, Secret, Exclusive, and Huge. Variant backgrounds are also config-driven, including darker gold and rainbow fills. Inventory display reads rarity names/colors from `configs/pets.lua`.
- Generated pet/egg thumbnails are cached as ViewportFrames, not uploaded image assets. `AssetPreloadService` publishes `PetThumbnailsReady`, `PetThumbnailCount`, and `PetThumbnailFailures` on `ReplicatedStorage.Assets`; the Studio client prewarms those ViewportFrames offscreen before showing the menu UI, and inventory cards still retry fallback icons if a thumbnail arrives late.
- Pet power is now config-only durable data. `configs/pets.lua` defines family base power plus global Basic/Golden/Rainbow multipliers, while grant/progression/inventory save paths avoid writing per-copy power or stats power. `tests/studio/BackfillPetPowerSourceOfTruth.lua` can strip legacy saved power fields for the current Studio player.
- `configs/auto_systems.lua` and `AutoTargetService` now provide the first Phase 5 auto-system slice. Target mode choices persist under `Settings.AutoSystems.auto_target`; clients request auto-target work and the server selects the breakable. The configured default modes are nearest, highest value, weakest, strongest, and selected currency.
- Hatch auto-delete filters persist under `Settings.AutoSystems.auto_delete` and are enforced in `EggService` before `PetGrantService` writes inventory. Filters can match rarity, pet family, or variant, and Secret/Exclusive/Huge are protected by default.
- Hatch auto-delete filter state now replicates through `Player.Settings.AutoSystems.AutoDelete`, including `Enabled`, `Rarities`, `PetTypes`, and `Variants` folders. `EggInteractionService` reads and live-binds those folders so the hatch drawer reflects saved filters even if the earlier `AutoTarget_Status` packet was missed during startup.
- The hatch drawer now summarizes saved auto-delete filter count in its header, using config-owned summary strings such as `summary_empty`, `summary_enabled_format`, and `summary_disabled_format`. The summary exposes count attributes for smoke tests and helps players understand when filters are saved but auto-delete is off.
- Egg hatching is treated as two-stage: first roll chooses the pet species, second hidden roll chooses basic/golden/rainbow. Egg previews stay species-only and show basic-form pets, while `egg_sources.<id>.variant_rolls` controls allowed variants and optional cost multipliers such as the starter `20x` no-basic/golden mode.
- Egg preview percentages now use the same relative `pet_weights` denominator as the server hatch roll. Large weights are no longer treated as an implicit out-of-100000 table, so preview odds sum to the real hatch distribution.
- Near-egg hatch controls are now settings-driven instead of always-visible. `Settings.AutoSystems.hatch.action_mode` persists what the E key does (`single`, `max`, or `auto`), the Settings menu exposes this choice plus Show Hatch/Silent Hatch toggles, and the original `EggCurrentTarget` proximity UI is the single egg-side surface. It shows the selected action prompt plus total cost, per-egg cost, max entitlement, and affordability; the separate lower `EggHatchPanel` surface was removed.
- Egg prompt discoverability is developer-configured through `egg_system.ui.interaction_prompt.mode`. The default `clean` mode follows the configured E-key action, while `advertised_hotkeys` can show the legacy `E Hatch | R Max | T Auto` prompt for games that want that onboarding surface.
- Hatch filter UX direction: avoid permanent on-screen filter panels near eggs. Auto-delete filters still exist in the engine and drawer for testing, but the preferred player-facing path is contextual selection through settings, egg preview interactions, or inventory actions such as “do not hatch this pet anymore.”
- Special hatch reveal metadata is driven by `egg_system.hatching.animation`: configured rarities mark per-result special outcomes, aggregate reveal metadata is returned to the client, and Skip Hatch remains a hard animation-suppression preference instead of being overridden by rare outcomes.
- Hatch mode stubs now include Golden and Charged. Golden removes basic variants and uses its configured multiplier; Charged uses its configured multiplier plus hatch-luck and secret-luck bonuses. Both are server-entitlement checked and surfaced through the hatch settings drawer.
- Normal players default to `3` max hatch count. The engine still supports dynamic `1..99` hatching, but higher counts are granted through the `MaxEggHatchCount` entitlement/admin stub rather than given to everyone by config.
- Admin hatch entitlement tools now expose the egg shop stubs before the shop UI exists. Developers can view, lock, unlock, reset, or directly set Auto, Golden, Charged, Fast, Skip, and max hatch count attributes from the admin panel; snapshots include effective hatch entitlement status.
- `HatchEntitlementService` now centralizes server-side hatch shop/unlock stubs. `EggService` and `AdminToolsService` read the same effective entitlements for Auto, Golden, Charged, Fast, Skip, max hatch count, hatch-luck bonus, and secret-luck bonus, so future shop code has one resolver to call.
- Hatch settings education is now config-driven. `configs/egg_system.lua` owns help copy for core hatch controls, mode toggles, and auto-delete filters; the hatch drawer renders a `HelpText` line and the interactive controls carry `HelpText` attributes for hover/focus updates.
- Hatch auto-delete protection is visible in the hatch settings drawer. The client reads `configs/auto_systems.lua` through `Locations.getConfig("auto_systems")`, renders the protected rarity list from `auto_delete.protected_rarities`, and exposes the list as `ProtectedRarities` UI metadata for Studio smokes.
- Auto-hatch failure feedback now explicitly stops with a reason for no-currency and no-storage sessions, and the client loop also reports when the player moves too far away, e.g. `Auto hatch stopped: out of currency`, `Auto hatch stopped: storage full`, or `Auto hatch stopped: too far away`.
- Hatch reveal markers are now config-driven. `egg_system.hatching.animation.reveal_badges` controls rarity, variant, special, and auto-delete badges, and `EggHatchingService:GetActiveAnimationDebugState()` lets Studio smokes inspect the live client animation contract without relying on screenshots.
- Hatch mode education now reads player entitlement state. The settings drawer grays locked modes, stores `ModeState`/`ModeOwned` attributes on each mode toggle, shows a `ModeStatus` summary, and uses config-driven locked/available/active help text.
- Server hatch debugging now has a bounded recent-history path. `EggService` records successful and rejected hatches with request count, actual count, cost, stop reason, options, entitlements, sampled results, auto-delete counts, special counts, and authored animation metadata. Admin tools expose this through `Admin_RequestHatchHistory`, and the admin panel has a Recent Hatch History action.
- Egg source unlock requirements are now server-authoritative for both real hatches and no-mutation hatch simulations. `egg_sources.<id>.unlock_requirement` can point at a stat/counter threshold, rejected hatches return `egg_locked` with current/required progress, and auto-hatch feedback maps that code to `locked egg`.
- Studio hatch forcing now uses player `ForcePet`/`ForceVariant` attributes directly before the roll, avoiding the earlier copied-config gotcha where mutating `Locations.getConfig("pets")` did not reliably affect `simulateHatch`.
- `ConfigLoader` now validates the expanded egg-system hatch contract, including hatch count relationships, debug/history limits, animation capacity, reveal badge field types, shop max-count defaults, and hatch-panel button labels.
- Egg hatching has a no-mutation simulation path for admin/testing. `EggService:SimulateHatchBatch` rolls the same server pet/variant/luck pipeline and reports costs, counts, auto-delete matches, special reveal counts, and animation metadata without spending currency, granting pets, incrementing stats, or playing client animation. Admin tools expose this through `Admin_RequestHatchSimulation`.
- The near-egg hatch panel now reads the same effective Max Hatch and Auto Hatch entitlement state that the server uses. Selected hatch count clamps to player/config max entitlement, controls expose `MaxEntitledHatchCount`, and locked Auto is grayed/blocked client-side before the server-authoritative rejection path.
- Hatch animation presentation has another config-first slice. `egg_system.hatching.animation.layout` controls grid padding and min/max egg sizes, `special_glow` controls the special hatch rarity stroke/pulse, and the client animation debug state exposes layout/glow metadata for Studio smokes.
- Fast Hatch presentation speed is no longer hardcoded in `EggHatchingService`. `egg_system.hatching.animation.fast_hatch_speed_scale` owns the duration multiplier, `ConfigLoader` validates it, and the animation debug state exposes resolved Fast/Silent timing metadata.
- Hatch selected count is now a persisted player setting. The near-egg panel writes changes through `HatchSettings_SetCount`, `SettingsService` stores them under `Settings.AutoSystems.hatch.selected_count`, and clients restore the replicated `Player.Settings.AutoSystems.Hatch.SelectedCount` value when the hatch panel is rebuilt.
- Hatch mode toggles are now persisted player preferences too. `SettingsService` sanitizes the configured hatch mode keys, stores them under `Settings.AutoSystems.hatch.modes`, replicates `Player.Settings.AutoSystems.Hatch.Modes`, and `EggInteractionService` restores/persists Show, Golden, Charged, Fast, Skip, and Silent toggles while the server still enforces entitlement on hatch requests.
- The near-egg hatch panel now listens to replicated hatch setting changes after startup. Live `SelectedCount`/mode value changes update the visible panel, and the panel exposes cost metadata (`BaseCostEach`, `CostMultiplier`, `EstimatedCostEach`, `EstimatedTotalCost`, `EstimatedAffordableCount`) plus a compact per-egg affordability detail line.
- The selected hatch count control is now editable in addition to +/-/Max buttons. Players can type a numeric count directly into the near-egg panel, and the client clamps/persists it through the same server-backed selected-count setting.
- The near-egg hatch panel now has config-driven responsive scaling. `configs/egg_system.lua` owns `ui.hatch_panel.responsive`, `ConfigLoader` validates its scale bounds, `EggInteractionService` applies a `UIScale` against the current viewport, and tests cover desktop/mobile fit math.
- Skip Hatch is enforced as an animation-suppression preference in both hatch presentation layers. The interaction service does not start hatch animation when resolved options include `skipHatch`, and `EggHatchingService` also returns an immediate completed/skipped result without enabling the animation GUI if called directly with `skipHatch`.
- Show Hatch is a free, default-on hatch presentation preference. Players can turn it off to hide hatch animations without owning Skip Hatch; the setting persists under `Settings.AutoSystems.hatch.modes.showHatch`, flows through the server hatch options, and makes `EggHatchingService` return the same immediate skipped presentation result.
- Hatch animation now has max-count Studio coverage. `EggHatchingService` falls back to a resolved `1280x720` animation viewport if Studio reports an uninitialized tiny camera size, exposes container/frame geometry in its debug state, and `EggAnimationMaxBatchSmoke` verifies all `99` authored egg frames fit in the compact `10x10` layout.
- Hatch mode education now surfaces configured economics. Golden/Charged mode UI reads cost and luck values from `egg_system.hatching.shop_stubs`, exposes `CostMultiplier`/`LuckBonus`/`SecretLuckBonus` attributes for tests, and includes those details in help/status text.
- Expanded hatch drawer layout is now covered without relying on screenshots. `EggProximitySmoke` opens the real `PlayerGui` drawer, verifies responsive desktop/mobile fit math, and asserts visible drawer controls stay inside the configured drawer bounds.
- Special hatch reveal now includes a config-driven backdrop layer. `egg_system.hatching.animation.special_backdrop` controls a rarity-colored backdrop behind special pet reveals, `ConfigLoader` validates it, and animation debug state exposes the backdrop contract for Studio smokes.
- Egg-system config validation now cross-references hatch special rarity ids and hatch auto-delete drawer filter ids against pet config. `hatching.animation.special_rarities` must reference `pets.rarities`, while hatch drawer `rarity_filters`, `pet_type_filters`, and `variant_filters` must reference configured rarities, pet families, and variants.
- Hatch result stacking is now config-driven. `egg_system.hatching.animation.result_stack` controls whether duplicate hatch results collapse, whether name/count labels show, the minimum count label threshold, tween timing, and hold duration. The animation debug state exposes stack group/count/name metadata for Studio smokes.
- Egg authoring and hatch-admin testing now have a dedicated project doc at `docs/EGG_AUTHORING_AND_ADMIN_TESTING.md`. It records the current authored `EggStand` stamping contract, two-stage hatch model, hatch entitlement stubs, Show Hatch vs Skip Hatch behavior, and Studio smoke commands.

## Phase 0 Verification

Last checked: 2026-05-26

- `python3 scripts/wiki_status.py`: passes.
- Rojo 7.6.1 build: passes with `rojo build --output /tmp/rbx-template-phase0.rbxl`.
- Selene 0.25.0: passes with `selene --allow-warnings src configs tests`; current result is 0 errors, 646 warnings.
- StyLua 0.18.2 check: fails because the existing codebase has broad formatting drift. Treat formatting cleanup as a separate cleanup lane, not a Phase 0 blocker.
- Studio MCP smoke test: passes. `RBX-Template` is the active Studio instance, play mode starts/stops through MCP, screen capture works, and console output is readable.

## Phase 1 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `rojo build --output /tmp/rbx-template-phase1-full.rbxl`.
- Targeted Selene for Phase 1 touched files: 0 errors, existing warnings only in legacy/bootstrap files.
- Full Selene: passes with warnings from the existing codebase.
- StyLua check for Phase 1 touched files: passes.
- ConfigLoader unit specs pass in Studio (`30` passed, `0` failed) and cover valid area/marker schemas plus missing-parent, cycle, and unsupported marker-attribute failures.
- Studio MCP smoke test: latest expected generated hook counts are `Zone=5`, `AreaZone=2`, `SpawnZone=2`, `EggStand=1`, `PODPodium=2`, `TeleportPad=2`, `Portal=2`. Earlier Phase 1 verification used two egg stands before golden hatching moved into `basic_egg` variant-roll config.
- Active-zone dormancy smoke check passes: after boot, Spawn had spawned breakables and Meadow had `0`; after `TravelSmoke` unlocked/traveled to Meadow, Meadow filled to its configured `8` breakables.
- Travel smoke test passes through MCP with `TravelSmoke`. It verifies locked travel rejection, unlock, server-authoritative movement to Meadow, active-area update, and state restoration.
- Egg proximity smoke test: passes through MCP with `EggProximitySmoke`. It verifies far hatch rejection, near hatch success, UI target state, currency deduction, pet inventory increase, and state restoration.
- Authored reference map smoke should now expect one authored `EggStand` for `basic_egg`; rerun `MapContractSmoke` after regenerating the reference map.
- Spawn safety smoke passes through MCP with `SpawnSafetySmoke` for `Spawn`: the player is placed above a real floor, vertical velocity is cleared, and active area state is synchronized.

## Phase 2 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `rojo build --output /tmp/rbx-template-phase2-slice.rbxl`.
- Targeted StyLua check/format for touched Phase 2 files: passes.
- Targeted Selene for touched Phase 2 files: 0 errors, existing warnings only in older bootstrap/inventory/data/config files.
- `ConfigLoader.spec` passes in Studio with `33` passed and `0` failed, including upgrade config validation.
- `Phase2ProgressionSmoke` passes through MCP: locked Meadow rejects without crystals, paid Meadow unlock succeeds, pet equip-slot upgrade increases max pet slots from `3` to `4`, pet storage increases from `50` to `75`, and profile state is restored.
- The same Phase 2 smoke verifies `crystal_value` as a real modifier path: a base `100` crystal breakable reward resolves to `110` after level 1, proving player-specific upgrades are included in breakable reward resolution.
- Locked-zone responses include config-driven unlock requirements, so future UI can show cost/currency/prerequisite without hardcoding Meadow.
- `MeadowBreakableSmoke` verifies the first full area-gated mining loop: it unlocks/travels to Meadow, spawns a deterministic `BigBlueCrystal` through `BreakableSpawner`, breaks it through the normal contribution/death handler, pays `110 crystals` through the upgrade-aware economy path, increments `breakables_broken`, and restores the profile.
- `SyntheticExpansionSmoke` verifies the Phase 2 expansion contract without permanently changing the authored map: it temporarily injects a second synthetic world (`crystal_world -> CrystalCavern`), rebuilds bindings in synthetic mode, asserts a cross-world portal and spawn zone, travels through the portal, restores profile/map state, and leaves the authored-only marker contract at `synthetic=0`.
- Regression smokes still pass: `SpawnSafetySmoke`, authored-only `MapContractSmoke`, `TravelSmoke`, and `EggProximitySmoke`.

## Phase 3 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `mise exec -- rojo build --output /tmp/rbx-template-phase3.rbxl`.
- Targeted StyLua check/format for touched Phase 3 files: passes.
- Targeted Selene for touched Phase 3 files/configs/tests: 0 errors, existing warnings only in older bootstrap/config/inventory/data files.
- `ConfigLoader.spec` passes in Studio with `36` passed and `0` failed, including pet index, achievements, and leaderboard config validation.
- `Phase3StatsSmoke` passes through MCP: adding bear/basic twice and bunny/basic records only `2` distinct pet entries, syncs `distinct_pets=2`, grants the first pet-index milestone once, grants the first egg achievement over `eggs_hatched`, updates the live eggs leaderboard, and restores the profile.
- Phase 2 regression smoke still passes after Phase 3 profile/inventory changes: `Phase2ProgressionSmoke`.
- `EternalPowerSmoke` exists as a Studio runner for verifying cached eternal pet power after Rojo sync/restart.

## Phase 4 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `mise exec -- rojo build --output /tmp/rbx-template-phase4-enchants.rbxl`.
- Targeted Selene for touched Phase 4 files/configs/tests: 0 errors, existing warnings only in older bootstrap/inventory/breakable/config files.
- `python3 scripts/wiki_status.py`: passes.
- `git diff --check`: passes.
- `Phase4PetProgressionSmoke` passes through Studio MCP after Rojo sync/restart. It granted a Huge Rainbow Colorado, verified a hatch-time enchant, awarded `25` pet XP from a `BigBlueCrystal` breakable context, rerolled enchant slot `1`, verified player-level slot bonus `1`, verified live hatch luck `0.1`, secret luck `0.05`, pet damage about `115`, team power `131.1`, pet efficiency `1.1`, and restored profile state.

## Phase 5 Verification

Last checked: 2026-05-29

- Rojo 7.6.1 build: passes with `mise exec -- rojo build --output /tmp/rbx-template-phase5-auto.rbxl`.
- Targeted Selene for touched Phase 5 files/configs/tests: 0 errors, existing warnings only in older bootstrap/data/settings/breakable files.
- Targeted StyLua check for the new/clean Phase 5 files passes.
- `git diff --check`: passes.
- `Phase5AutoSystemsSmoke` passes through Studio MCP after Rojo edit-mode sync. It creates a temporary `Phase5Smoke` breakable world, verifies nearest/highest value/weakest/strongest/selected-currency server target selection, verifies auto-delete rarity/type/variant matches, verifies protected Exclusive Colorado is not auto-deleted, and restores profile/map state.
- `HatchEntitlementAdminSmoke` passes through Studio MCP after stopping Play to let Rojo sync the new module, then restarting Play. It verifies status, lock-all, unlock-all, reset-all, and max hatch count changes for hatch entitlement attributes, then restores the player's original state.
- `EggProximitySmoke` passes through Studio MCP with the hatch drawer help-text contract. It verifies the near-egg panel, expected Hatch/Max/Auto/count controls, mode/filter controls, and config-driven help metadata.
- `EggProximitySmoke` also verifies locked hatch-mode education: mode controls expose locked state/help attributes and the drawer renders a locked-mode status summary.
- `EggAutoHatchSmoke` passes through Studio MCP. It initializes isolated client egg targeting/hatch panel services, verifies auto-hatch stop feedback for zero currency, zero pet storage, and moving out of range, then restores the profile.
- `StudioSmokeTestService` now supports `setupPetInventoryEmpty` for egg smokes so storage-limit tests can avoid accidental success through existing pet stacks.
- `EggAnimationContractSmoke` passes through Studio MCP. It creates a synthetic special Exclusive Rainbow Colorado and an auto-deleted Common Bear hatch, then verifies frame metadata, rarity/variant/special/auto-delete badges, and visible reveal-state updates.
- `EggHatchHistorySmoke` passes through Studio MCP. It verifies a deterministic auto-deleted batch hatch is recorded in server history with cost, count, sampled pet result, and auto-delete metadata.
- `ConfigLoader.spec` passes through Studio MCP in Play mode with `52` passed, `0` failed, and `0` skipped, including the egg-system validator coverage.
- `EggHatchSimulationSmoke` passes through Studio MCP. It forces a deterministic `7`-egg basic hatch simulation and verifies result counts plus no currency, inventory, or `eggs_hatched` counter mutation.
- `EggProximitySmoke` passes through Studio MCP with the effective hatch entitlement UI contract. It now asserts a configured `MaxEntitledHatchCount` and locked Auto control state in addition to the near-egg hatch transaction.
- `EggProximitySmoke` also verifies replicated auto-delete settings reach the hatch drawer from `Player.Settings.AutoSystems.AutoDelete`, covering enabled state plus saved rarity, pet-family, and variant filters.
- `EggProximitySmoke` also verifies the auto-delete drawer summary counts selected saved filters. A direct Studio screenshot capture attempt timed out locally, so automated geometry/debug-state coverage remains the reliable hatch drawer QA path for now.
- `EggAutoHatchSmoke` still passes after the entitlement UI change, covering no-currency, no-storage, and too-far stop feedback.
- `EggAnimationContractSmoke` passes through Studio MCP after the hatch animation config polish. It verifies reveal badges plus configured grid layout metadata and special glow pulse metadata.
- Direct Studio validation of the new `egg_system` config rules passes: current config validates, invalid layout min/max fails, and invalid special glow transparency fails.
- `EggAnimationContractSmoke` also verifies configured Fast/Silent hatch timing metadata, and direct Studio validation rejects `fast_hatch_speed_scale` values above normal speed.
- `EggProximitySmoke` also verifies selected hatch count persistence by saving a count through the client interaction service, reading the replicated player setting/debug state, and resetting to one before the hatch transaction.
- `EggProximitySmoke` also verifies hatch mode persistence by toggling Silent Hatch through the client interaction service, reading the replicated hatch mode setting/debug state, and restoring the original value before the hatch transaction.
- `EggProximitySmoke` also verifies the responsive hatch panel layout contract: full scale on a desktop-sized viewport, scaled down and width-safe on a mobile-sized viewport.
- `EggAnimationMaxBatchSmoke` passes through Studio MCP. It starts a `99`-egg authored hatch animation, verifies the compact `10x10` layout, checks every frame stays inside the resolved animation viewport, and confirms all frames use the authored egg visual.
- `EggProximitySmoke` also verifies the hatch settings drawer exposes Golden/Charged cost and luck details from config.
- `EggProximitySmoke` also verifies the expanded hatch settings drawer renders with nonzero dimensions and no clipped visible controls.
- `EggAnimationContractSmoke` now verifies special hatch backdrop metadata, reveal visibility, and Skip Hatch suppression at the animation-service boundary; `ConfigLoader.spec` covers invalid backdrop transparency.
- `EggAnimationContractSmoke` also verifies configured stacked hatch result labels by hatching duplicate Bear results and checking the `Bear x2` stack metadata.
- `EggUnlockSmoke` passes through Studio MCP. It verifies `golden_egg` rejects at `9/10` configured hatch progress with `egg_locked`, succeeds at `10/10`, deducts the effective golden egg cost, grants one pet, and restores the profile/map state. `ConfigLoader.spec` now passes with `58` passed, `0` failed, and `0` skipped after adding unlock-requirement shape validation.
- `EggHatchSimulationSmoke` and `EggBatchHatchSmoke` still pass after the unlock gate change, covering the basic simulation and broader batch hatch regression paths.
- Final egg-system audit on 2026-05-29 passed local Rojo/Selene/StyLua/wiki/diff checks plus Studio MCP smokes for `EggAutoHatchSmoke`, `EggProximitySmoke`, `EggAnimationContractSmoke`, `EggHatchSimulationSmoke`, `HatchEntitlementAdminSmoke`, `EggBatchHatchSmoke`, `EggAnimationMaxBatchSmoke`, and `EggUnlockSmoke`.

## Admin/Map Test Verification

Last checked: 2026-05-27

- Studio MCP admin zone-lock smoke passes: it verifies Meadow travel rejects while locked, admin bypass unlock succeeds, portal/pad travel reaches Meadow, admin lock re-locks Meadow, and profile/travel state restores.
- Studio MCP prompt state smoke passes: locked Meadow shows the `Unlock 100 crystals` prompt, unlocking Meadow hides it for that player, and touch/server travel still moves to Meadow.

## Automation API & Remote Dev Pipeline

Last checked: 2026-05-29

- The template now has a GUI-bypassing **command boundary** so tests and tools can drive the game below the UI. `src/Shared/API/CommandBus.lua` is a pure dispatcher (register/execute, uniform `{ok, code, result}` envelope, arg validation via `src/Shared/API/Validators.lua`, test-only gating, origin tracking). `GameAPIService` owns the bus, exposes a single `GameAPICommand` RemoteFunction (untrusted clients, `isTest=false`) plus a server-side `:Execute`, and registers adapter commands that delegate to existing services via the `_G.RBXTemplateServices` locator (economy, zone, egg, inventory) — services are not rewritten.
- `AutomationService` (Studio-only) is the runtime test driver: pathfinding `NavigateTo` (with a client `AutomationControlBridge` that disables player controls during automated movement), `SnapshotState`/`RestoreState`, `TeleportForSetup`, and `GetPlayerState`, exposed as test-only `automation.*` commands. A Studio-only `RunAutomationSuite` RemoteFunction lets an MCP-driven client trigger the server-side suite.
- A **headless test loop** runs pure-logic specs with no Studio: `mise run test-headless` (lune) over `tests/headless/specs/*.spec.luau`, currently 35/35 across CommandBus, Navigation, Validators, TestReport, and the runner self-test.
- A **fast gate** `mise run ci` (selene + StyLua on owned paths + `rojo build` + headless) runs locally and in GitHub Actions (`.github/workflows/ci.yml`) on every push.
- A **release path** exists: `scripts/release.sh` / `mise run release` wraps `rojo upload` (Open Cloud), reading `ROBLOX_OPEN_CLOUD_KEY`/`ROBLOX_UNIVERSE_ID`/`ROBLOX_PLACE_ID` from env, refusing if unset (`DRY_RUN=1` validates).
- **Testing methodology** is documented in `REMOTE_DEV_PIPELINE.md`: (1) headless pure logic, (2) primary = server-side command-bus integration asserting authoritative state, (3) thin UI sanity via the MCP (`character_navigation` + `user_mouse_input`/`user_keyboard_input`) with 1–2 decisive screenshots. State proves; pixels confirm.

### Automation Pipeline Verification

Last checked: 2026-05-29

- `mise run ci` green: selene 0 errors, StyLua clean on owned paths, `rojo build` passes, headless 35/35.
- GitHub Actions fast gate green on `template/automation-api`.
- Live in Studio (Place1, Rojo on this branch): production network path verified — `system.listCommands` returns 13 network-visible commands (test-only hidden), economy/zone/egg/inventory adapters dispatch against live services, validation rejects bad args, and `test.*`/`automation.*` are forbidden over the network.
- Server-side `AutomationSuite` passed 11/11 incl. `snapshot → grant → coins increased → teleport → restore → coins restored` against `DataService`.
- Full UI-driven E2E verified live: `character_navigation` to the egg (proximity UI triggered) and a `user_keyboard_input` `E` hatch → server granted a pet (`inventory.slots{pets}` used 0→1, coins 100→0).
- Two bugs found live and fixed: `_service` now pcalls the locator (Get raises on unregistered names); `EggService` (direct-required at boot) is reached via a dedicated `_eggService()`.
- Observed (unresolved): HUD vs Pet Shop currency displays disagree for the same player — possible UI sync bug, separate from this work.
- **Release stage verified live**: `mise run release` published the build to the Rojo-owned staging experience (universe `10242349813`) via Open Cloud `rojo upload` (exit 0). The full develop → test → build → release pipeline is proven end-to-end. Gotchas (key needs `universe-places:write`; Universe ID ≠ Place ID; close the place in Studio before publishing) are documented in `REMOTE_DEV_PIPELINE.md`.

## Halo & Horns — Phase 0 (Data Spine)

Last checked: 2026-05-30

The config-driven world model + alignment + themed currencies, built test-first
(pure cores headless-tested, then wired to a service and verified live). All pure
logic is Roblox-API-free and consumes injected config (config-as-code).

- **0.1 Ring topology** (Feature 1): `configs/biomes.lua` (clockwise order
  earth→ice→lava→desert→beach, theme, dichotomy earth↔desert/ice↔lava, themed
  currency) + pure `src/Shared/Game/RingTopology.lua` (neighbors w/ wrap, theme,
  dichotomy, currency, adjacency). Adding a biome is config-only.
- **0.2 Soul stat** (Feature 2): `configs/soul.lua` (delta 5, range ±100,
  Halo/Horns bands) + pure `src/Shared/Game/SoulMath.lua` (`applyConquest`:
  clockwise +delta / ccw −delta / non-adjacent 0 / first-conquest / re-conquest
  no-op / clamp; `alignment` label). `AlignmentService` persists
  Soul/LastConqueredBiome/ConqueredBiomes via DataService (lazy-init, no schema
  migration).
- **0.3 Themed currencies** (Feature 4): `configs/layers.lua` (reward multipliers
  base 1.0 / Heaven·Hell 1.5–2.0; Light/Shadow tokens) + pure
  `src/Shared/Game/RewardResolver.lua`. Themed currencies registered (non-tradeable)
  in `configs/currencies.lua`.
- **Bus commands**: `world.ringInfo`, `soul.get` (reads); test-only `game.conquer`
  / `game.resetAlignment`.

Verification:
- Headless `mise run test-headless`: 69/69 across 9 specs (ring/soul/reward unit
  scenarios + an interconnected conquest-flow integration test). `mise run ci` green.
- Live in Halo & Horns (Rojo connected): `AutomationSuite` 18/18 incl. the
  alignment chain (ring info, reset→conquer→soul 5→halo, persisted via DataService).

Deferred (with reasons, per the implementation plan):
- Soul HUD + real-time meter/notification ([studio]) — no UI yet (UI phase).
- Live themed-currency breakable drops + Light/Shadow token drops ([integration])
  — need biomes/layers present in the world (Phase 2).
- Currency non-tradeable enforcement — needs trade (Phase 6).
- Formal ProfileStore schema entry + migration for Soul fields — currently
  lazy-initialized; can be formalized when convenient.

## Halo & Horns — Phase 1 (Pets & Power)

Last checked: 2026-05-30

Pet element identity + runtime power, built test-first (pure cores headless, then
wired live). Power is always computed, never persisted.

- **Element resonance** (Feature 6): `configs/elements.lua` + pure
  `src/Shared/Game/ElementResonance.lua` (light/shadow opposing-dominant 1.5,
  home 1.2; chaotic flat 1.3; neutral 1.0).
- **Theme utility** (Feature 6): `configs/theme_utility.lua` + pure `ThemeUtility`
  (passive active only in the theme's dichotomy biome). Module tested; live
  wiring waits on pets gaining a biome `theme` (they currently have `category`).
- **Power formula** (Feature 6): pure `PowerFormula` — multiplicative base ×
  variant × level × enchant × element × theme_utility × stack × buff (rounded).
- **Element at hatch** (Feature 5): `configs/layers.lua` `hatch_element` +
  `realm_alignment` maps + pure `PetElement` (elementForLayer, realm alignment,
  element-in-stack-key). `PetGrantService` stamps `petData.element` from the hatch
  layer (base → neutral now; Heaven/Hell activate with LayerService in Phase 2);
  additive field, no schema migration.
- **Bus command** `pet.power`: base × variant × element-resonance for a context
  (never persisted); test-only `game.grantPet` returns the granted record.

Verification:
- Headless `mise run test-headless`: 94/94 across 13 specs (all Feature 5/6 [unit]
  scenarios). `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 25/25 incl. element neutral at grant,
  power-not-persisted, and resonance arithmetic (bear: neutral 10 / Hell 15 /
  Heaven 12; golden 15).

Deferred (with reasons):
- Element-in-stack-key — intentionally **not** used in the realized content model.
  Realm eggs hatch separate pet IDs/species (base/Heaven/Hell catalog entries), so
  stacks split naturally by pet id; element remains record metadata and power context.
- Theme-utility on live pets — needs pets to carry a biome `theme` (content/Phase 2).
- Power recalc on live biome/layer travel ([studio]) — needs the world (Phase 2);
  dynamic recalc is already shown via `pet.power` varying by realm with no save.
- Element via fusion (chaotic) — Phase 6 fusion.

## Halo & Horns — Phase 2 (Heaven Vertical Slice — logic)

Last checked: 2026-05-30

Layer access & portals (Feature 3) as server-authoritative logic; Heaven farming
reward scaling (Feature 11) is already covered by RewardResolver (Phase 0.3). The
**logic half of the vertical slice is done and live-verified**; the **visual half
(authored stacked geometry + portals + actual teleport) is deferred to map work.**

- **Layer access** (Feature 3): `configs/layers.lua` gains per-layer `access`
  (y_offset, requires_soul, token_cost) for base + heaven_1/2/3 + hell_1/2/3. Pure
  `src/Shared/Game/LayerAccess.lua` (canAccess: Heaven soul>=req, Hell soul<=req,
  cross-path visit ignores Soul, token cost; accessibleLayers).
- **LayerService** (server): AccessibleLayers + UseLayer — re-validates cost from
  config (never trusts client), deducts the token currency via DataService, sets
  `profile.CurrentLayer` (lazy-init/persist). GameAPI commands: `layer.current`,
  `layer.accessible` (reads), `layer.use` (mutate, server-authoritative).
- **Cross-cutting activations**: with `CurrentLayer` set, Heaven hatches now stamp
  `light` element (Feature 5) and `pet.power` defaults its realm to the current
  layer (Feature 6 dynamic recalculation — power follows where you are).

Verification:
- Headless `mise run test-headless`: 104/104 across 14 specs (Feature 3 [unit]
  access scenarios). `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 36/36 incl. base default, ring-tour →
  soul 20, ascend to heaven_1 (100 light tokens deducted, server-validated),
  reject-without-tokens / reject-Hell-with-positive-soul, Heaven-hatch → light
  element, and pet.power realm following the current layer.

Deferred — needs authored map work (your hands in Studio):
- Stacked Y-offset geometry (base 0, heaven +2000/4000/6000, hell −2000/…) and the
  **visual portals + actual character teleport** ([studio]). `LayerService` sets
  the logical layer + cost now; the teleport binds when the geometry exists.
- StreamingEnabled radius tuning for the stacked world.
- Heaven farming live drops + Light-token drops ([integration]) — need breakables
  placed in the biomes/layers (world content). Reward math (RewardResolver) is done.
- Cross-path "visit" portals — pure logic supports it; wiring waits on authored
  visit portals (it's intentionally not a client-settable flag).

## Halo & Horns — Phase 3 (Pet Party Core)

Last checked: 2026-05-30

Spirit Form, the stacked-pet token-bucket pool, and the active-squad hierarchy —
pure cores test-first, then wired live.

- **Spirit Form** (Feature 7): `configs/spirit_form.lua` (cooldown tiers; Heaven 2×
  recharge) + pure `SpiritForm` (effectiveCooldown, status, down, instantRecharge).
  `SpiritFormService` persists lastDownedAt/cooldown_seconds on unique pet records
  (by uid) and auto-returns a downed pet from the squad.
- **Stack Pool** (Feature 8): `configs/stack_pool.lua` + pure `StackPool`
  (token-bucket: newStack, lazy refresh, down, linear & sqrt_diminishing
  contribution, add/remove). `StackPoolService.Simulate` runs the model live.
- **Active Squad** (Feature 9): `configs/squad.lua` (limits; 5s in-combat swap
  cooldown) + pure `ActiveSquad` (canDeploy max, canSwap cooldown).
  `ActiveSquadService` owns `profile.ActiveSquad` (deploy/remove/swap; ownership +
  Spirit-Form gating; stacked pet = 1 slot; swap cooldown session-only).
- **Bus commands**: `squad.get/deploy/remove/swap`, `spirit.status`,
  `stack.simulate`; test-only `game.downPet/rechargePet`; `game.grantPet` gained
  `huge` (unique-record) support.

Verification:
- Headless `mise run test-headless`: 129/129 across 17 specs (Feature 7/8/9 [unit]
  incl. token-bucket 29/cap/80/~89.4, cooldown/Heaven-halving, squad limits/swap).
  `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 49/49 incl. deploy → down → auto-return
  + Spirit Form → redeploy blocked → instant recharge → redeployable, and the
  stack-pool model.

Deferred (with reasons):
- Staged degradation visuals (Strained/Critical auras), the real combat **down**
  trigger, the Recall command, and "all-squad-downed → graceful end" — [studio] /
  combat (Phase 4). Downing is exposed as a test command now.
- StackPool bound to real inventory stacks (ready_count decremented by combat
  downs) — Phase 4; the pool math is live-verified via `stack.simulate`.
- In-combat swap cooldown live verification ([studio]) — logic tested headless +
  in the service; live combat-swap arrives with combat.

## Halo & Horns — Phase 4 (Combat & Focus)

Last checked: 2026-05-30

Combat (Feature 10) + the player Focus/Spirit-Presence model (Feature 12) +
the legacy pet-damage refactor (issue #4) — pure cores test-first, then services,
then live through the bus.

- **Focus** (Feature 12): `configs/focus.lua` (focus_max 100, regen 5/s,
  `regen_pauses_at_zero=false`) + pure `FocusMath` (cast/canCast, regen clamp,
  sunder clamp-to-0). `FocusService` owns `profile.Focus` (lazy-init to max) and a
  CharacterAdded **invulnerability** hook (MaxHealth=∞, Dead state disabled — no HP,
  can't die). Open design Q resolved (always regenerate; DECISIONS.md).
- **Combat** (Feature 10): `configs/enemies.lua` (hp, attack {damage,cadence,
  sundering}, drop_table) + `configs/combat.lua` (spawners, auto_target nearest,
  group_scaling, pet-down threshold). Pure `Targeting` (nearestEnemy) +
  `CombatMath` (damage/defeat/encounter-end/group-scaling/sunder/deterministic
  loot) + `CombatSim` (dependency-injected deterministic full fight).
  `CombatService` exposes read-only `Simulate` plus the real interconnections:
  `AwardLoot` → currency, `SunderPlayer` → FocusService, `DownPetInCombat` →
  SpiritFormService (the **combat down trigger** deferred from Phase 3; auto-returns
  the pet from the squad).
- **Legacy refactor** (issue #4): pure `PetCombat` (damagePerHit floor+min1,
  applyDamage clamp+contribution, attackInterval clamp) + `CombatService:ResolvePetDamage`
  / `ResolvePetAttackInterval` route pet power through the ModifierService pipeline
  (pet_damage / pet_efficiency) then PetCombat — one tested source of truth. The
  cloned `PetScripts/Follow.server.lua` now prefers the service path with a
  behavior-identical inline fallback (no mining-loop regression). `Targeting`
  covers the pure movement-targeting side.
- **Bus**: `focus.get`, `combat.simulate` (read); test-only `focus.cast/regenTick`,
  `combat.sunder/awardLoot/downPet`. `Validators` gained a `table` type.

Verification:
- Headless `mise run test-headless`: 166/166 across 21 specs (Feature 10/12 +
  issue #4 cores; incl. CombatSim full-fight loot 62/8, 4p group-scale 2500,
  pet-down threshold, focus cast/regen/sunder clamps). `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 64/64 incl. focus cast→80 / over-cast
  rejected / Sundering brute −20, combat.simulate clears hell_1_lava (5 defeated,
  62 lava_coins + 8 shadow_tokens), and combat.downPet → Spirit Form (trash_mob)
  → squad auto-return. Also fixed a latent light_tokens state-pollution flake in
  the suite.

Deferred — needs the user's hands (authored map) or a decision:
- **Authored Hell combat zone + enemy spawner markers** ([studio]): live enemy
  *spawning*, pet auto-attack *traversal*, the 0-damage *player-invuln visual*,
  and the ethereal alignment aura. The resolution math + economy/Spirit-Form/Focus
  interconnections are done + live-verified through the bus; what remains is
  in-world geometry/models.
- ~~Full removal of the cloned `PetScripts/*`~~ — **DONE** (issue #4 closed, see
  the PetFollowService section below).

## Pet movement (issue #4) — service movement restored (anchored + client-driven)

Last checked: 2026-05-30

**Current approach (working, pending user confirmation).** After an earlier
service-movement attempt let pets fall off the map (it dropped the legacy
teleport-watchdog), the retry sidesteps the whole physics-fall class: the server
**anchors** each pet (anchored parts can't fall/drift), and the client
`PetFollowController` sets each pet's CFrame every RenderStepped (smooth,
frame-rate-independent lerp). Follow = config formation; **attack = surround the
target in an animated ring** (orbit / static_ring / lunge — `PetFormation.attackOffset`,
headless-tested; live style switch via `localPlayer:SetAttribute("PetAttackStyle", …)`).
Server keeps damage (`CombatService:ResolvePetDamage`) + target leash. Verified
live: pets stable + upright + on-map across 35s, following in formation; mining
works (AutomationSuite 69/69). **Open follow-up:** multiplayer position replication
(other clients seeing a player's pets move) — currently drives the local view only;
the planned approach is sending pet id+position to shared state. Issue #4 stays open
until the user confirms in-session + replication lands.

----

### (history) The earlier service-movement attempt fell off the map

Both the server-positioning and an earlier client-RenderStepped variant dropped the
legacy Follow script's teleport-watchdog + tuned forces, so pets drifted/fell off
the map and were destroyed (the known ~10-months-ago bug). Early (~6s-after-spawn)
verification missed the *delayed* fall. Lesson: verify physics/visual changes over
time (30s+), not just at spawn.

Current working state:
- Legacy `PetScripts/Follow.server.lua` + `FollowBox.server.lua` restored and own
  movement (`configs/pet_follow.lua` `service_owned=false`). Pets are stable,
  upright, don't fall (verified ~28s live), and mine. The watchdog is the fix.
- **Damage stays service-owned** (Phase 4.d holds): the legacy Follow routes mining
  damage through `CombatService:ResolvePetDamage` (PowerFormula + modifier
  pipeline) with an inline fallback.
- `PetFollowService` + pure `PetFormation` remain in-tree but **inert** (flag off).
- GitHub issue #4 reopened. A future service-owned movement loop must port the
  drift/teleport watchdog + correct network-ownership for the massless pet
  assemblies, and be verified watching pets 30s+ (not just at spawn). Desired but
  still-open polish: attack pets should SURROUND the target in an animated ring
  (orbit/lunge) rather than stack on one point; smooth client-side movement.

----

## (superseded) PetFollowService — service-owned pet movement

Last checked: 2026-05-30

Replaced the legacy cloned per-pet movement scripts with a single server-owned,
config-driven follow/work loop (GitHub issue #4 closed). Flag-gated incremental
rollout, live-verified, then the dead code was removed.

- **Config + pure core**: `configs/pet_follow.lua` (formation/float/align/attack
  tuning + the `service_owned` rollout flag) + pure `src/Shared/Game/PetFormation.lua`
  (slotOffset rows/circle, targetPosition into the player frame, float bob) —
  headless-tested.
- **Service**: `src/Server/Services/PetFollowService.lua` — a throttled Heartbeat
  loop that drives one `AlignPosition` per pet to its formation slot (follow) or
  its target (attack), and runs the position-independent mining tick via
  `CombatService:ResolvePetDamage` + `PetCombat.applyDamage` (Contrib ledger
  preserved). Pets are auto-targeted by the existing `BreakableService`.
- **Cleaner formation** (user's choice): pets hold config-driven slots behind the
  player rather than the old control-box chain.
- **Legacy removed**: `PetScripts/Follow.server.lua` (1114→18 lines) and
  `FollowBox.server.lua` (101→14) gutted to inert stubs (~1180 lines of legacy
  constraint/BodyMover/damage code deleted). They remain only because `PetHandler`
  still clones them; movement is wholly service-owned.

Verification: headless 175/175 (incl. PetFormation specs); live AutomationSuite
**70/70** in Halo & Horns — service registered + owns movement, pets spawned +
unanchored + driven by `_FollowAlign`, and pets mine their auto-assigned targets
(HP drops / mining income rises). Screenshot confirmed pets holding formation.

Follow-up (low-priority, flagged): `PetHandler` still creates the now-vestigial
control boxes + clones the stub scripts each spawn (harmless dead weight) — fully
removing that box machinery + deleting the stub files is a separate cleanup with
spawn-path risk, deferred from this pass.

## Halo & Horns — Phase 5 (Build depth: Archetypes / Powers / Augmentation / Hotbar / Rosters)

Last checked: 2026-05-30

Five build-depth systems (Features 13–17), each config-driven with a pure
headless-tested core, a server service, and bus commands.

- **Archetypes (13)**: `configs/archetypes.lua` (4 archetypes + power pools) +
  pure `ArchetypeLogic`. `ArchetypeService` owns `profile.Archetype` (one-time
  select; respec resets powers + slots + hotbar). Bus `archetype.get/list/select`.
- **Power Selection (14)**: `configs/powers.lua` (12 powers + `selection_levels`)
  + pure `PowerSelection` (pending-by-level, one-per-level, archetype-gated, no
  dup). `PowerService` owns `profile.Powers` (level via PlayerProgressionService).
  Bus `power.get/select`.
- **Augmentation (15)**: `configs/augmentation.lua` (grant levels, 6 slot types,
  max 6/power, set-bonus tiers) + pure `Augmentation` (grant-by-level, placement
  rules, stacking set bonuses). `AugmentationService` owns `profile.Slots`. Bus
  `augment.get/place`.
- **Hotbar (16)**: `configs/hotbar.lua` (20 slots, 4 bind types, defaults) + pure
  `HotbarLogic` (archetype defaults, rebind validation, empty-slot no-op).
  `HotbarService` owns `profile.Hotbar`. Bus `hotbar.get/rebind`.
- **Rosters (17)**: `configs/rosters.lua` (injury rules) + pure `RosterLogic`
  (clampMaxToDeploy, removeRef, resolveDeploy for ready_only/best_available/
  deploy_anyway). `RosterService` owns `profile.Rosters` (create clamps to squad
  cap; invoke pulls Spirit-Form readiness → replaces active squad; remove-ref on
  delete/trade). Bus `roster.list/create/invoke` + test `roster.removePetRef`.

Test-only level overrides on power/augment commands are gated to `isTest`.

Verification: headless `mise run test-headless` **232/232 across 28 specs**;
`mise run ci` green; live `AutomationSuite` **86/86** in Halo & Horns (archetype
select+gate+pool, power level/archetype gating + accumulation, augment grant/lock/
set-bonus, hotbar defaults+rebind, roster max-clamp+invoke+remove-ref).

Deferred (with reasons):
- The [studio]/UI halves: archetype-selection UI, level-up power-selection prompt,
  slot-allocation UI, hotbar key-press firing + cooldown overlays, mobile layout —
  logic + bus are done; the GUI is the next layer.
- Augmentation effective-cooldown application through the live ModifierPipeline (the
  pure set-bonus/per-slot math is done; wiring to the cooldown system arrives with
  the power-cast/cooldown runtime).
- Respec ritual cost/flow ([studio]); archetype-change ritual question (open in spec).

## Halo & Horns — Phase 6 (Social / endgame: Party / Trade / Fusion / Chaos Rifts)

Last checked: 2026-05-30

Four social/endgame systems (Features 18–21), each config-driven with a pure
headless-tested core. The cross-player handshakes + UIs are [studio]; the math,
rules, and server contracts are bus-testable solo.

- **Party / Group Play (18)**: `configs/party.lua` (max 4, loot rule, MVP bonus) +
  pure `PartyMath` (canJoin, scaledHp, splitLoot, attribution). `PartyService` owns
  session membership + group math (difficulty scaling pulls
  `combat.group_scaling.per_extra_player`). Bus `party.get/simulate`.
- **Trade (19)**: `configs/trade.lua` (pets yes-unless-locked, currencies no,
  cosmetics yes) + pure `TradeLogic` (canAddItem, both-confirm canExecute,
  auditRecord). `TradeService` owns sessions (Open/Add/Confirm/Cancel), the atomic
  validate-then-apply swap (no partial-completion window → anti-dup), and a capped
  queryable trade-history audit log. Bus `trade.canAdd` + test `trade.simulate/auditLog`.
- **Chaotic Fusion (20)**: `configs/fusion.lua` (output Chaotic, Light+Shadow recipe)
  + pure `FusionLogic` (validateInputs with exact spec rejection messages,
  outputElement, resolveTheme, fusionRecord). `FusionService` validates → consumes
  both inputs → produces a Chaotic pet → logs fusion history. Bus `fusion.canFuse` +
  test `fusion.simulate/log`.
- **Chaos Rifts (21) [deferred]**: `configs/rifts.lua` (per-element multipliers:
  Chaotic 2.0×, others 0.5×) + pure `RiftMultiplier` (multiplierFor, applyToPower).
  Only the power math is implemented + tested; the event scheduler, rift spawn,
  notifications, and Aether drops remain [deferred].

Verification: headless `mise run test-headless` **261/261 across 32 specs**;
`mise run ci` green; live `AutomationSuite` **100/100** in Halo & Horns (party
scaling 1000→2500 + 100/4 loot split + MVP attribution, trade allow-pet/reject-
currency/reject-locked + both-confirm audit, fusion Light+Shadow→Chaotic with
same-element/Chaotic/Neutral rejections).

Deferred (with reasons):
- Cross-player [studio] halves: party invite/accept UI + cross-player support
  powers; trade two-player invite/confirm handshake + offer UI; fusion altar +
  confirmation modal. All server rules + contracts are done.
- Chaos Rift live event system (scheduler, spawn, notifications, Aether drops) —
  marked [deferred] in the spec; the multiplier math is ready for PowerFormula to
  call once rifts go live.
- Combat animations + a hand-authored live enemy zone (Phase 4 deferral): combat
  resolution + spirit-form-on-down are verified through the bus, but a player has
  not yet fought an authored enemy in-world. Needs Studio-authored enemy models.

## Halo & Horns — Phase 7 (Reward spine: Quests / Daily / Shop / Rewards)

Last checked: 2026-05-30

A single backbone that collapses four menu features into one machine: **Triggers
bump Counters → Conditions decide what's Claimable → a Claim grants a Reward Bundle
(once, audited) → Shop is a Claim whose gate is a cost instead of a condition.**

Pure cores (headless-tested, `src/Shared/Game/`):
- **RewardBundle** — the universal "what you get" (currencies/pets/items/effects/
  slots): `normalize`, `merge`, `isEmpty`. Everything terminates here.
- **Condition** — the universal gate: `isMet` / `progress` over a snapshot
  (counters/level/currency). Types: counter_at_least, level_at_least,
  currency_at_least, all_of, any_of. `progress()` feeds UI bars.
- **ClaimLogic** — anti-replay: `canClaim(met, count, def)` → not_met /
  already_claimed / out_of_stock (claim-once | repeatable | limit).
- **DailyStreak** — `resolve(lastDay, today, streak, cfg)` (clockless; day indices
  passed in) → claimable / newStreak / claimDay (calendar wraps) / reset.
- **ShopLogic** — `affordable` / `canPurchase(offer, balances, count)` (cost is an
  inverse bundle) → insufficient_funds / out_of_stock.

Services:
- **RewardService** — `Grant(player, bundle, source)` is the one place a bundle
  becomes real: fans out to DataService (currencies), InventoryService (items),
  PetGrantService (pets), PlayerEffectsService (timed effects), Upgrades (capacity),
  and writes a capped, source-keyed grant-history audit log (`reward.log`).
- **QuestService** — condition-gated claims; ledger `profile.QuestClaims`; `List`
  (progress + claimable), `Claim`, `Pending` (the badge count).
- **DailyService** — cadence-gated claims; state `profile.Daily`; `Status` / `Claim`.
- **ShopService** — cost-gated claims; counts `profile.ShopPurchases`; `List` /
  `Purchase` (spend cost → grant reward).

Bus: `quest.list/claim`, `daily.status/claim`, `shop.list/purchase`,
`rewards.summary` (the menu-badge aggregator) + test `reward.grant/simulate/log`,
`test.setCounter/setLevel`, `claim.reset`. Configs: `rewards/quests/daily/shop.lua`.

Verification: headless `mise run test-headless` **282/282 across 33 specs**;
`mise run ci` green; live `AutomationSuite` **113/113** in Halo & Horns (reward
grant +25 crystals + audit entry; quest not_met→claim→already_claimed; daily
day1→2 streak + same-day block; shop purchase + limit-1 out_of_stock; summary).

Deferred (with reasons):
- The [studio]/UI halves behind the existing menu buttons: Quest list + progress
  bars, Daily streak calendar, Shop grid + confirm, the Rewards badge wiring. All
  server logic + bus + the badge aggregator are done; the panels are the next layer.
- Effect-reward application reads back through PlayerEffectsService folders (the
  grant call is wired; live effect-stat assertions are [studio]).
- Achievements already carry `reward_type`/`reward` in config — routing them through
  RewardService is a small follow-up (the spine is built to absorb them).

## Halo & Horns — Phase 8 (Achievements → spine + Quest UI panel)

Last checked: 2026-05-30

- **Achievements routed through RewardService.** `AchievementsService._grantReward`
  now translates a tier reward into a RewardBundle (legacy `{type=currency,...}` +
  forward-looking `{bundle=...}`) and grants via `RewardService:Grant` — one audited
  terminal that also handles items/pets/effects/slots — with a legacy currency
  fallback if RewardService is unavailable. `test.resetAchievements` re-arms grants
  for testing.
- **Quest UI panel** (`src/Client/UI/Menus/QuestPanel.lua`): mirrors the ShopPanel
  contract (.new/Show/Hide/GetFrame/IsVisible/Destroy), registered in
  `init.client.lua` so the existing "Quest" side-menu button opens it. Teal card
  rows (name + reward + progress bar + Claim/Locked/Claimed), sorted claimable-first.
  Data is live through the `GameAPICommand` bus bridge (`quest.list`/`quest.claim`);
  claiming refreshes the list. No bespoke remotes — reuses the generic bus transport.

Verification: `mise run ci` green; headless **282/282**; selene 0 warnings; rojo
build OK; live `AutomationSuite` **114/114** (incl. "achievement reward granted
through RewardService (audited)"); Quest panel screenshot-verified rendering 4 live
quest rows with correct claimable/locked/claimed states.

Known follow-up (pre-existing, surfaced by the panel): the quest level condition
reads `PlayerProgressionService:GetLevel` (profile.Stats.Level) which can disagree
with the XP-derived HUD level (HUD showed Level 15 while "Reach level 10" read 1/10).
The level data source needs unifying; the panel faithfully shows the bus value.

## Halo & Horns — Phase 9 (Level unification + Daily & Shop panels)

Last checked: 2026-05-30

- **Player level unified on an XP source of truth.** Total XP
  (profile.Stats.Experience) is now the single source; level is derived via a pure
  curve (`src/Shared/Game/LevelCurve.lua`, config `player_progression.xp`,
  headless-tested, xpForLevel<->levelForXp inverse). `PlayerProgressionService:GetLevel`
  derives from XP; `AddExperience`/`SetLevel`/`GetProgress` added; `Start()` publishes
  Level/XP/XPForNext player attributes. `RewardBundle` gained an `experience` field so
  quests/daily/achievements/shop can award XP through the spine; `test.setLevel` now
  writes the curve's XP threshold. The HUD (BaseUI) reads the real Level/XP attributes
  (seed + live refresh), replacing the hardcoded "Level 15 / 750-1000 XP" mock. This
  fixes quests AND the Phase 5 power/augment level gates consistently.
- **Daily panel** (`DailyPanel.lua`): 7-day streak calendar (claimed/today/upcoming
  cards with per-day reward), streak count, Claim button. `daily.status` now returns
  the calendar + cycle length so the UI is config-free.
- **Shop panel** (`RewardShopPanel.lua`): offer-card grid (name, reward, cost, -% sale
  tag, Buy/Owned/Can't-afford), replacing the old mock ShopPanel. `shop.list` returns
  each offer's reward.

Both panels use the `GameAPICommand` bus bridge (no bespoke remotes) and are wired so
the existing Daily/Shop side-menu buttons open them.

Verification: `mise run ci` green; headless **291/291 across 34 specs**; selene 0
errors; rojo build OK; live `AutomationSuite` **117/117** (incl. setLevel(10)->level
quest claimable, +900xp->level 10). Screenshot-verified: Quest/Daily/Shop panels
render live data; HUD reads "Level 10 · 0/1000 XP" live after the XP grant.

Follow-up: per-breakable XP gain isn't wired yet (XP currently comes from the spine —
quests/daily/achievements/shop). Add a per-mine XP grant + curve tuning when balancing.

## Halo & Horns — Phase 10 (Escrow two-player trade + Trade UI)

Last checked: 2026-05-30

Roblox has **no native in-experience trading/escrow API** (the platform Trading
System is for avatar catalog Limiteds + Robux between accounts; the old web Trade
API was deprecated). So the escrow *pattern* is implemented server-authoritatively.

- **TradeService (escrow model)** rebuilt from the Feature 19 engine:
  `Request`/`Respond` invite handshake, `ListPlayers` (online targets). **`Add`
  MOVES the pet out of inventory into a server-held escrow** the moment it's
  offered — so it can't be sold, deleted, or offered in a second trade (anti-dup at
  the source). `Remove` returns it; both-`Confirm` **delivers each side's escrow to
  the other (all-or-nothing)**; `Cancel`/decline/**disconnect refunds** escrow to
  its owner (PlayerRemoving hook). Live state pushed to both clients via the
  **TradeUpdate RemoteEvent**. `GetState`/`ListMyPets` for the UI. Pure rules
  (tradeable / both-confirm / audit) still in the shared TradeLogic core; capped
  audit log retained. Bus: `trade.players/request/respond/add/remove/confirm/
  cancel/state/myPets` (+ original `trade.canAdd` and test `trade.simulate/auditLog`).
- **TradePanel**: the "Trade" side-menu button opens the **online-player list**
  (click → request). A self-managed ScreenGui live layer shows the **incoming-request
  popup** (Accept/Decline) and the **two-player window** (your removable offer +
  pet picker, the partner's offer, per-side confirm indicators, Confirm/Cancel),
  driven by TradeUpdate so it works even when the menu is closed. No bespoke
  remotes — all via the GameAPICommand bridge.

Verification: `mise run ci` green; headless **291/291 across 34 specs**; selene 0
errors on new files; rojo build OK; live `AutomationSuite` **122/122** (trade
command surface + guards: players/myPets dispatch, no-session-by-default,
self-request rejected, add-without-session rejected). Screenshot-verified: the
two-player window (You: golden bear/cat + Add Pet; partner confirmed ✓ with HUGE
dragon; Confirm/Cancel) and the Accept/Decline request popup render correctly.

Deferred (true two-client only): the full escrow swap end-to-end (request → accept →
both add+confirm → delivery) needs a 2-player session — solo Studio can't run two
real players, so it's verified by the headless rules + the solo command-surface
guards and flagged for a multiplayer test. Optional polish: a poll fallback if a
TradeUpdate push is missed (the bus `trade.state` exists for it).

## Pet Realm (Halo & Horns) — progression, power, economy & balance (CURRENT game lane)

The active game layer on top of the template baseline. Design SoT:
`docs/PET_REALM_PROGRESSION_POWER_TEAMING.md` (§1–15) + `docs/PET_REALM_DESIGN_DOCUMENT.md`.

**Zone economy (per-biome coins).** Four biome currencies — `grass_coins` / `ice_coins` /
`lava_coins` / `desert_coins` (non-tradeable; gems-only trading). Each biome's ore family pays its
own coin; HUD shows the four with a live `+N` gain indicator (legacy `coins`/`crystals` removed).
`ZoneTrackerService` resolves the current area from config bounds by raycasting biome baseplates;
farming is scoped to that area. Per-biome egg stands (Earth/Ember/Ice/Sand) place real hatch-target
eggs. **Mining income identity: `coins/sec = DPS × (value/HP)`, ratio = 0.2** (`configs/breakables.lua`
ORE_TIERS) — every crystal tier pays the same rate; bigger ones just take longer. Outer zones spawn
`max=100` with 5–60s distributed respawn; the local depletion sag is a **designed throttle**
(active>passive). Active-mining boost: clicking a node amplifies pet damage on it.

**Targeting / farm modes (`configs/auto_systems.lua`).** Free = `nearest` (min travel — the best
DPS the flat ~26 studs/s pets allow); paid gamepass = `highest_value` (camp big nodes). Hotbar cycle
Off→Near→High.

**Zone unlocks (`configs/areas.lua`).** Ring grass→Ice→Lava→Desert, each paid in the *prior* zone's
coins (no skipping). Costs tuned to a "real chapter per zone": Ice 8k / Lava 18k / Desert 35k /
Meadow 2k (Meadow = permanent +10% coins). **Open design (§12):** the ring's terminal zone should be
an on-ramp into the heaven/hell realm axis, not a dead-end.

**PetPower (mining/combat split + bounded ceiling).** `PetPower`/`PetPowerView` give every pet a
two-number profile — ⛏ mining vs ⚔ combat (role aptitude × element × variant), shown on the card.
Power S2: a bounded geometric tier curve + a code-enforced `max_pet_power` ceiling (the Creator apex;
nothing out-powers Huge Rainbow Colorado) + a shiny axis (neutral 1.0). **Eternal pets** (Huge,
Secret, Exclusive) scale dynamically: power = `power_percent` × the average of the player's top-N
non-eternal pets (Huge=120%), so they stay relevant forever without breaking the ceiling
(`PetHandler.resolveEffectivePetPower`, `configs/pets.lua`).

**Accuracy curve (combat substrate).** Pure `Accuracy` to-hit = `clamp(base + step·(atk−def),
floor, cap)` reading a single `EffectiveLevel` seam (teaming will override it); mining is flat 100%
(fixed the old 8% crystal whiff). The three identity numbers: **EffectiveLevel** (combat scaling),
**ClaimedLevel** (entitlements), **Soul** (heaven/hell alignment).

**XP + level-up (cap 50).** Mining AND combat grant XP. **Claimed-vs-earned split:** XP earns
levels; powers/slots/egg-hatch are *claimed* via a level-up sequence UI. Hybrid **Ascension Altar:**
filler levels auto-claim in the field; power/slot/milestone levels train at the altar. Caps: **10
equipped pets + 10 power picks**; +1 egg-hatch per claimed level. Dev XP reads a monotonic `XPTotal`
attribute (keeps accruing past the cap).

**Dev tooling.** Studio-only metrics overlay (rolling-1-min DPS / Coins-s / Pet-speed / XP-min bars).
Admin panel "Add 100k Area Coins" funds all biome currencies. Audio Effects/Music/UI volume controls
work (SoundGroups).

**Verified balance (grass/ice/lava, farming Near):** fresh dogs ≈46 DPS→~10 cps; fresh bears ≈25
DPS→~6 cps (tanks mine slow by design); graduated variant squads ≈85–150 DPS→~17–30 cps. The
"~200-egg arc" (~20k coins) ≈ graduate a starter squad ≈ ~20–33 min.

**Next (tracked tasks #149–156):** World S3 (realm axis as a non-terminal endgame — token earning
loop + traversal-sink knob + depth=desirability via Eternal pets), Teaming S4, Creator S5,
earning-rate enemy pressure (#155), support-pet targeted buff/debuff (#156), PetPower S3
(display=dealt), Power S2b balance rebase, overnight memory-leak investigation.

## Balance follow-up (config-only)
- Huge pets' base-power floor scales with pet level (huge_base_power × level mult →
  e.g. 152% at lvl 27). Flagged by the user as too high; tune later (config /
  decide whether the floor should ignore level). Logic is correct; purely balance.

## Recent Planning State

The project now has two high-level source documents:

- `docs/FOUNDATION_AND_REQUIREMENTS.md`
- `docs/IMPLEMENTATION_PLAN.md`

Those documents define the planned foundation work: stats, modifier pipeline, save migrations, config validation, feature flags, economy ledger, and the map integration contract.

## Next Likely Work

The active lane is the **Pet Realm game layer** (see the Pet Realm section above); the
template-baseline polish below is parked behind it.

Pet Realm next (tracked tasks #149–156):
1. **World S3** — heaven/hell realm axis as a non-terminal endgame (retention, not gates): expand
   layers 3→5/side + `requires_level` gate (substrate S3.1), then the token earning loop, the
   traversal-sink knob (`charge_on`), and depth=desirability via Eternal pets.
2. **Teaming S4** — guest pass + lead-anchored sidekick/exemplar (power axis only).
3. **Creator S5** — Creator class (dev-only, untradeable apex) + Meet-the-Creator + shiny pets.
4. **Earning-rate enemy pressure** (#155) — anti-cheat tool #3 (high income → enemies; seed the
   baseline off the DataStore-loaded total to skip the join spike).
5. **Support-pet targeted buff/debuff** (#156, experimental); **PetPower S3** (display=dealt, #132);
   **Power S2b** balance rebase (#153); **overnight memory-leak** investigation (#152).

**Shipped (2026-06-05): "The Watcher" (RealmHellFaces)** — a giant demon head that haunts **Hell 5
only**, kite-following the player (anchored + capped `PivotTo`, no physics fling), glowing in the
pitch-black realm via an internal face light, with a lightning pulse and stowed-but-ready Neon
pupils. Pure ambience/horror (no mechanics yet); all knobs in `configs/layers.lua → hell_faces`.
See LOG 2026-06-05 for the anchoring bug + the Rojo-sync lesson.

Template-baseline polish (parked): richer auto-target UI controls; replace the legacy pet
follow/mining clone with a service-owned loop (template issue #4); enchanter UI polish; authored-map
gate art on the `TeleportPad`/`Portal` hooks; clean up warning-level placeholder/test data.

## Pet Realm — Combat & Power (shipped 2026-06-17 → 06-26)

- **Pet combat orthogonal axes** — targeting (single / targeted_aoe / aura / contagion) × effects
  (DoT burn, on-hit Control, on-hit Shred), all config-declared; aura targeting drives buff scope
  (team / top-1 carry / top-K carries). S-tier kits (Control/Shred/Bonfire) + the Trinity kill-box.
  Pure `OnHitEffects.lua`.
- **Realm resonance live** — light/shadow species multiplier (own 0.8 / opposite 1.5 / neutral 1.0)
  wired into real mining & combat; inventory card shows the true dealt power. Squad diversity bonus
  (distinct archetypes + origins).
- **Layer-2 realms (Heaven 2 / Hell 2)** — playable: 8 zones (±4000 Y), 40 pets on a 6-tier ladder
  (new LEGENDARY tier), 8 egg pools, layer-aware egg-stand resolution gated on `Assets.ModelsReady`.
  Hell support auras are give→take (`drain`/`shred`/`curse`); L2 ice dragons have a freeze-AoE root.
- **Allegiance aggression** — heaven farms (no aggro vs heaven/neutral squads), hell fights; fielding
  a hell pet flips heaven enemies hostile. Realm patrol bands are the opposing faction invading
  (flag-gated, ships dark).
- **Mountain-time weekday event calendar** — seven daily events via `Shared/Game/MountainTime`,
  surfaced on a live HUD label + Effects panel cards.
- **Potions (BrewMeter)** — runtime per-axis draining meters (anti-runaway), drink from an assignable
  power-bar slot, LOCK=auto-maintain, stack additively with powers; first-class inventory tab.
- **Multi-bucket trade escrow** — pets + gems + enhancements (potions pending) through a
  category-dispatched escrow; three-column Trade UI.
- **Enhancement store** — buy/sell for gems; static rarity-scaled pricing (`EnhancementPricing` SSOT),
  naturals-only buying + single/dual grades, sell/salvage as the gem sink; buy-to-fill in the slotting
  UI. Enhancements affect player powers end-to-end (damage/healing fold to magnitude; range/accuracy/
  spark gated). New `speed`/`focus` axes; summon duration+potency.
- **Focus resource + CoH toggle economy** — runtime-only Focus pool, per-second toggle upkeep, toggles
  crash on empty; HUD Focus bar + top-left toggle badge. Hasten is a timed perma-click (recharge-only)
  that self-bootstraps and cascades cooldown reduction. Admin tabbed power bar with MIN/MAX potency.
- **Three defensive pillars** — absorb-shields, armor-curve mitigation, and **true evasion** (Mirage
  Step avoidance roll, yellow DODGE float). Sandwalker is the pet-protection origin (dodge + Quicksand
  root + Sandstorm blind + at-feet Healing Field zone); blinded enemies whiff with orange MISS floats.
- **Realm breakable presence-gating** — realm crystals spawn only where a player is present (gated on
  presence, not unlock): ~32k→~9.5k workspace instances at Spawn. (Resolves the "memory leak" — it was
  instance count, not a Lua leak.) Power range bounded to enemies near the caster; overhead HP bars
  distance-culled at 150 studs.
- **Aggro Phase 1** — farm-lock / despawn-churn fixed and live-verified; downed pets no longer latch
  the owner InCombat.
- **Currency-key normalization on load** — dedupes legacy duplicate currency keys (merge by MAX),
  killing the stale-key "CHANGED EXTERNALLY" watchdog false alarm. Per-color gem-drop rendering +
  size-invariant inventory card framing.

## Links

- [Decisions](DECISIONS.md)
- [Architecture](ARCHITECTURE.md)
- [Studio Workflow](STUDIO_WORKFLOW.md)
- [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md)
- [Map Marker Reference](../MAP_MARKER_REFERENCE.md)
- [Implementation Plan](../IMPLEMENTATION_PLAN.md)
