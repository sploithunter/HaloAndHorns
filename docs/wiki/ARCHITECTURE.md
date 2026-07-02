# Architecture

Status: draft

## Summary

The desired shape is a small set of authoritative services backed by validated config. Feature services should be thin; shared infrastructure should handle persistence, validation, stats, modifiers, networking, map binding, and economy auditing.

## Foundation Services

- `ConfigLoader` validates config shape and cross-references at boot. Current focused validators cover currencies, game, breakables, pets/egg sources, events, economy exchange, egg system, inventory, upgrades, areas, markers, pet index, achievements, leaderboards, UI, context menus, items, and monetization.
- `DataService` owns ProfileStore data, schema versioning, migrations, durable state, stat counter storage, pet index state, achievement completion state, and currency source/sink ledger aggregates.
- `StatsService` owns declared tracked counters and emits counter change signals.
- `ModifierService` plus shared `ModifierPipeline` resolve derived values from pets, enchants, upgrades, boosts, events, rebirths, and gamepasses. Breakable rewards now route through this path, with active global events registered as a provider.
- `EconomyService` owns currency mutation and passes source reasons into the ledger.
- `ServerClockService` owns deterministic UTC day/seed behavior.
- `WorldBindingService` discovers, validates, and serves Studio map hooks. In `auto`/`synthetic` map modes it fabricates missing baseplate hooks from `configs/areas.lua` and `configs/markers.lua`.
- `ZoneService` owns area unlocks and server-authoritative `TeleportPad`/`Portal` travel. It uses `WorldBindingService` for hook/spawn lookup and persists area unlock state through `DataService.GameData.UnlockedAreas`.
- `AdminToolsService` exposes developer-only test affordances through validated server actions. Zone lock/unlock controls call `ZoneService:SetZoneLocked` rather than mutating profile fields directly.
- `HatchEntitlementService` is the server source of truth for egg shop/unlock stubs. It resolves effective hatch permissions from `configs/egg_system.lua` plus player override attributes, including boolean modes, max hatch count, hatch-luck bonus, and secret-luck bonus. Egg hatching, admin tools, and future shop code should call this service rather than rebuilding entitlement defaults.
- `AssetPreloadService` owns imported model normalization for pets. Pet configs can declare `asset_transform.scale`, `asset_transform.huge_scale`, and degree-based `asset_transform.orientation`; normal scale/orientation are baked into `ReplicatedStorage.Assets`, while huge scale is applied only to owned pets marked with the `huge` trait.
- Imported pet model parts are normalized at asset preload and runtime spawn: non-colliding, non-touching, massless, and velocity-cleared. `CanQuery` is intentionally left alone for now; click/raycast blocking should be solved as its own targeting problem rather than by globally making pet art non-queryable.
- Eternal pets are config-driven. Pet config can declare `eternal = { enabled = true, power_percent = N, baseline = "top_team_average" }`. On equip rebuild, `PetHandler` caches `BasePower`, `EternalBaselinePower`, `EternalPercent`, and `EffectivePower` onto the replicated pet folder and spawned pet model; mining damage reads the cached model `Power`. Huge pets clamp their eternal percent to at least `100`, so huge eternal power is never below the configured top-team-average baseline.
- `PetSerialService` allocates global serial numbers for special pets through an atomic DataStore `UpdateAsync` counter keyed by serial family, pet id, and variant. Studio has a memory fallback only for local API-disabled testing.
- `PetGrantService` is the single boundary for converting a selected pet outcome into durable inventory. Hatching, admin grants, creator rewards, scripts, and future trade receipts should call this service so huge metadata, serials, locks, saves, and inventory shape stay consistent.
- Pet enchant capacity is config-driven by rarity in `configs/pets.lua` under `enchanting.max_enchantments_by_rarity`. Rarities with enchant slots are treated as unique pets going forward, because per-copy enchant state cannot live on compact stack records. Current defaults are Mythic `1`, Secret `2`, Exclusive `2`, and Huge `3`; future rarities can be added by config.
- `EnchantService` owns rolling, storing, rerolling, and resolving pet enchants. `configs/enchants.lua` is the single source of truth for both enchant chance and enchant behavior: rarity roll profiles, roll counts, weighted entries, strength ranges, duplicate policy, reroll cost, and modifier mappings all live there. Saved unique pets store only rolled identity/strength/provenance; pet configs and pet records must not define what an enchant does.
- Hatch-time enchant rolls happen through `PetGrantService` after progression slot defaults are stamped. Manual rerolls go through `EnchantService:RerollPetEnchant` and the `EnchantPetRequest`/`EnchantPetResult` remotes. If `configs/enchants.lua` `reroll.requires_station` is true, rerolls require recent activation of a bound `EnchanterStation` map hook.
- Enchanter stations are map-authored fixtures bound by `WorldBindingService` through the `EnchanterStation` tag. `configs/enchants.lua` `stations` owns the station display name, touch child name, prompt text/distance, and optional animation script toggling. Cosmetic scripts may stay inside the model; gameplay activation is service-owned.
- Equipped unique pet enchants register through the shared `enchants` modifier stage. `EnchantService` interprets the config generically: it reads each effect's `modifier.stage`, `kind`, optional `currency`, `combine`, and `amount_per_strength`, then contributes only when a gameplay system resolves the matching modifier context.
- `PlayerProgressionService` owns config-driven player-level effects. `configs/player_progression.lua` currently contributes a `team_power` modifier from player level and grants extra equipped pet slots at configured level milestones. Inventory slot calculation consumes this service next to permanent upgrades.
- `AutoTargetService` owns Phase 5 auto-system settings and server decisions. `configs/auto_systems.lua` declares target modes and hatch auto-delete rules; profiles store only player choices under `Settings.AutoSystems`. Clients request an auto-target attack, but the server selects the breakable and applies the existing breakable attack path.
- Hatch auto-delete is enforced after the egg outcome is selected and before `PetGrantService` creates inventory state. It can match configured rarity, pet family, or variant filters, while protected special rarities such as Secret/Exclusive/Huge are not auto-deleted by default.
- Phase 4 now wires the high-priority enchant modifier consumers: `hatch_luck`, `secret_hatch_luck`, `pet_damage`, `team_power`, and `pet_efficiency`. `EggService` resolves hatch-luck contexts before selecting the outcome, `PetHandler` resolves team power when spawning equipped pets, and the legacy pet follow script resolves damage/cadence modifiers while mining.
- The pet follow/mining script is a stabilized legacy bridge, not the desired long-term shape. Future work should replace it with a service-owned pet assignment/work loop so target selection, cadence, damage, and modifier contexts are testable without cloned scripts.
- Valuable pet provenance is separate from audit source. `grant_source` remains internal metadata such as `egg_hatch` or `admin_grant`; `hatcher_name`/`hatcher_user_id` record who created a valuable copy. `configs/pets.lua` currently stamps hatcher provenance for pets whose enchant capacity is at least `3`, which covers Huge and future above-Huge tiers by config.
- Inventory pet tooltips are config-filtered. Pet records may replicate primitive metadata, but `configs/inventory.lua` `tooltip_fields` controls labels, ordering, and hidden audit/internal fields so new pet metadata does not require client code edits just to show or hide it.
- Inventory pet cards use two config-driven visual channels. `configs/inventory.lua` `card_visuals.rarity_rings` controls border color, thickness, and optional animated `UIGradient` rotation by rarity id; `card_visuals.variant_backgrounds` controls card fill by variant. Rarity display names/colors come from `configs/pets.lua` `rarities`, so developers can rename tiers or add future tiers such as `colossal` without changing UI display code.
- `UpgradeService` owns config-driven permanent upgrade purchases. Levels persist under `DataService.Upgrades`; equip/storage effects feed inventory limits, and modifier effects register as `permanent_upgrades` providers.
- `PetIndexService` owns first-time pet/variant discovery. It writes compact `PetIndex.Discovered` records, syncs the K1 `distinct_pets` counter, and grants `configs/pet_index.lua` milestones once.
- `AchievementsService` owns config-tier completion over K1 counters. It listens to `StatsService.CounterChanged`, persists completed tiers under `Achievements.Completed`, and grants currency rewards once.
- `LeaderboardService` owns K1-backed live in-server leaderboard snapshots and optional throttled OrderedDataStore publication for global boards.
- Phase 2 player actions use central `Signals` remotes: `PurchaseUpgrade`, `UpgradeResult`, `UnlockZoneRequest`, `ZoneUnlockResult`, and `ZoneTravelResult`. Admin test actions include `Admin_SetZoneLock`. Service methods remain the authority; remotes are thin request/result bridges for future UI.
- `StudioSmokeTestService` is a Studio-only test bridge. It exposes controlled server-authoritative smoke-test actions to MCP/client runners and must remain disabled outside Studio.

## Gameplay Services

Planned services include rebirths, enchants, auto-delete, rewards, Pet of the Day, chaseables, stock, marketplace, and trading. Existing services already cover breakables, eggs, inventory, pet grants/serials, zones, upgrades, pet index, achievements, leaderboards, auto-targeting, admin tools, basic events, and core economy.

## Resolution Rule

Any derived gameplay number should flow through one ordered modifier pipeline. Feature services should not each invent their own multiplier math.

## State Rule

Workspace instances are presentation and map hooks, not state of record. Durable state belongs in profiles. Temporary authoritative state belongs in explicit server services.

## Phase 0 Notes

Feature flags exist in `configs/game.lua`, `ConfigLoader:IsFeatureEnabled`, and server boot registration for safe optional modules. Keep future feature services behind the same flag pattern. `features.map_binding` is enabled for Phase 1.

## Links

- [Implementation Plan](../IMPLEMENTATION_PLAN.md)
- [Current Status](CURRENT_STATUS.md)
- [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md)
