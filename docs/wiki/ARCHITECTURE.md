# Architecture

Status: draft

## Summary

The desired shape is a small set of authoritative services backed by validated config. Feature services should be thin; shared infrastructure should handle persistence, validation, stats, modifiers, networking, map binding, and economy auditing.

## Foundation Services

All game-owned remotes are declared in `configs/network.lua` and constructed by
the generated `Signals` registry. Service modules bind handlers to those
objects; they do not create or replace remotes. Studio-only declarations are
filtered out of production registries.

- `ConfigLoader` validates config shape and cross-references at boot. Current focused validators cover currencies, game, breakables, pets/egg sources, events, economy exchange, egg system, inventory, upgrades, areas, markers, pet index, achievements, leaderboards, UI, context menus, items, and monetization.
- `DataService` owns ProfileStore data, schema versioning, migrations, durable state, stat counter storage, pet index state, achievement completion state, and currency source/sink ledger aggregates.
- `RetentionService` taps the server `FireGameEvent` stream and maps stable tutorial, quest, and
  area events through `configs/retention.lua`. It writes the native Roblox onboarding funnel and a
  low-cardinality custom milestone event, while persisting exact first-occurrence timestamps under
  `profile.Analytics.Retention` for admin/support inspection. See
  [Retention Analytics](RETENTION_ANALYTICS.md).
- The same observer archives every semantic bus event plus session boundary progression snapshots
  and whitelisted client context into the single `RetentionEvents_v1` store. Date/user/session/chunk
  keys support Open Cloud prefix export without a global hot key. Daily per-server `a<date>/j<job>`
  shards pre-aggregate additive session, tutorial, quest, area, and level counters without
  cross-server counter contention.
- `StatsService` owns declared tracked counters and emits counter change signals.
- `ModifierService` plus shared `ModifierPipeline` resolve derived values from pets, enchants, upgrades, boosts, events, rebirths, and gamepasses. Breakable rewards now route through this path, with active global events registered as a provider.
- `EconomyService` owns currency mutation and passes source reasons into the ledger. Reward bundle
  currencies route through it so ledger history, lifetime counters, service signals, and client
  balance notifications observe the same grant.
- `EconomyService:SetCurrency` owns absolute balance changes for admin and test setup.
  `EconomyService:Transact` preflights multi-currency debits, applies debits and credits in stable
  order, runs an optional domain commit, and compensates every applied mutation in reverse on
  failure. Its pure `CurrencyTransaction` core failure-injects each stage headlessly.
- Successful economy data mutations are terminal even if a downstream listener or client
  notification fails; post-commit observers are isolated so callers never compensate a credit that
  already landed.
- Enhancement sales use `InventoryService:BulkRemove` with an economy commit callback. Inventory
  snapshots restore exact stacks and slot counts when credit is rejected, before replication/save.
- `PotionShopService` binds the authored Home/Heaven/Hell potion tents without putting state or
  scripts in the map models. A prompt grants short-lived, distance-checked shop access; catalog,
  five-gem purchases, and two-gem sales remain server-authoritative. Buys debit through
  `EconomyService` and refund on failed delivery; sales use `InventoryService:BulkRemove` so a
  rejected credit restores the exact potion stack. Shop quantities are restricted server-side to
  `1`, `10`, or `100`; bulk purchases land as one stack mutation/save rather than N item grants.
- Trade gem escrow debits, owner refunds, and recipient delivery credits use `EconomyService`.
  Escrow descriptors retain complete source records and keys. `PetTransferService` inserts existing
  pet records without mint defaults or new UIDs, while `TradeDeliveryTransaction` stages inventory
  grants before currency effects and reverses prior grants if either leg rejects or throws. Escrow
  clears only after the whole delivery commits.
- `DataService:RegisterBeforeProfileRelease` synchronously settles loaded-profile ownership before
  ProfileStore release; trade uses it to atomically refund both owners on graceful disconnect.
  Hard-process crash recovery remains the write-ahead-journal work documented in
  `docs/TRADE_ESCROW_CRASH_SAFETY.md`.
- Combat drop-table currencies and def-less realm coin fallbacks also terminate at
  `EconomyService`; combat math and area-coin selection remain service-owned upstream.
- `CombatApplication` is the runtime combat-state boundary. `ApplyHit` publishes resolved
  hit/miss/dodge/block/absorb/immune outcomes, `ApplyDamage` mutates enemy HP or pet endurance and
  credits contribution, and `ApplyPowerHeal` mutates active/power healing. All three publish the
  resulting `Combat_Result` only after the authoritative transition; `CombatTextController` is its
  sole floating-text consumer. Passive regeneration, spawn/scaling initialization, admin resets,
  and revive restoration remain explicit silent state-maintenance paths outside this boundary.
- `ServerClockService` owns deterministic UTC day/seed behavior.
- `WorldBindingService` discovers, validates, and serves Studio map hooks. In `auto`/`synthetic` map modes it fabricates missing baseplate hooks from `configs/areas.lua` and `configs/markers.lua`.
- `ZoneService` owns area unlocks and server-authoritative `TeleportPad`/`Portal` travel. It uses
  `WorldBindingService` for hook/spawn lookup, commits configured unlock costs through
  `EconomyService`, and persists area unlock state only after a successful debit.
- `LayerService` resolves realm token earnings and traversal costs from layer config, then commits
  both through `EconomyService`. A failed traversal debit leaves the player's layer unchanged.
- `WorldTravelService` composes (rather than duplicates) `LayerService` realm access with
  `ZoneService` persisted area unlocks and `WorldBindingService` map/spawn availability. Activating
  the World Travel power opens a server-filtered realm → origin catalog without spending Focus;
  selecting a destination revalidates the same intersection before realm cost, Focus, cooldown,
  analytics, and teleport commit.
- `ShopService` uses injected economy and reward boundaries. Its pure purchase transaction debits
  configured currencies in stable order, rolls prior debits back if a later debit or the reward
  grant fails, and increments the purchase ledger only after success.
- `AdminToolsService` exposes developer-only test affordances through validated server actions. Zone lock/unlock controls call `ZoneService:SetZoneLocked` rather than mutating profile fields directly.
- `HatchEntitlementService` is the server source of truth for egg shop/unlock stubs. It resolves effective hatch permissions from `configs/egg_system.lua` plus player override attributes, including boolean modes, max hatch count, hatch-luck bonus, and secret-luck bonus. Egg hatching, admin tools, and future shop code should call this service rather than rebuilding entitlement defaults.
- `AssetPreloadService` owns imported model normalization for pets. Pet configs can declare `asset_transform.scale`, `asset_transform.huge_scale`, and degree-based `asset_transform.orientation`; normal scale/orientation are baked into `ReplicatedStorage.Assets`, while huge scale is applied only to owned pets marked with the `huge` trait.
- Imported pet model parts are normalized at asset preload and runtime spawn: non-colliding, non-touching, massless, and velocity-cleared. `CanQuery` is intentionally left alone for now; click/raycast blocking should be solved as its own targeting problem rather than by globally making pet art non-queryable.
- Eternal pets are config-driven. Pet config can declare `eternal = { enabled = true, power_percent = N, baseline = "top_team_average" }`. On equip rebuild, `PetHandler` caches `BasePower`, `EternalBaselinePower`, `EternalPercent`, and `EffectivePower` onto the replicated pet folder and spawned pet model; mining damage reads the cached model `Power`. Huge pets clamp their eternal percent to at least `100`, so huge eternal power is never below the configured top-team-average baseline.
- `PetSerialService` allocates global serial numbers for special pets through an atomic DataStore `UpdateAsync` counter keyed by serial family, pet id, and variant. Studio uses an isolated in-memory serial namespace by default, even when Studio API access is enabled, so local boot/census and test hatches cannot read or mutate production serial state. Live census reads use config-owned bounded retry and preserve `unavailable` separately from a confirmed zero count.
- `PetGrantService` is the single boundary for converting a selected pet outcome into durable inventory. Hatching, fusion, admin grants, creator rewards, scripts, and future trade receipts should call this service so huge metadata, serials, locks, saves, and inventory shape stay consistent. Fusion outputs are marked unique so their per-copy Chaotic element and theme cannot collapse into an ordinary stack.
- `InventoryService` owns exact pet-record snapshots and restoration for transactional rollback. Fusion mints first through `PetGrantService`, consumes both inputs without intermediate saves, and restores the original key and complete record if consumption fails.
- `InventoryService:InsertRecordSnapshot` and its opaque rollback receipt are the transfer-side
  equivalent: unique records preserve their original key and complete metadata; compact stacks
  merge quantity and restore the destination's exact prior record on rollback.
- Pet minting stores stable pet and variant identities; asset construction remains downstream and config-driven. The six original pets use packaged model assets, while Meshy families use mesh-plus-texture assembly in `AssetPreloadService`; fusion does not merge those presentation paths.
- Pet enchant capacity is config-driven by rarity in `configs/pets.lua` under `enchanting.max_enchantments_by_rarity`. Rarities with enchant slots are treated as unique pets going forward, because per-copy enchant state cannot live on compact stack records. Current defaults are Mythic `1`, Secret `2`, Exclusive `2`, and Huge `3`; future rarities can be added by config.
- `EnchantService` owns rolling, storing, rerolling, and resolving pet enchants. `configs/enchants.lua` is the single source of truth for both enchant chance and enchant behavior: rarity roll profiles, roll counts, weighted entries, strength ranges, duplicate policy, reroll cost, and modifier mappings all live there. Saved unique pets store only rolled identity/strength/provenance; pet configs and pet records must not define what an enchant does.
- Hatch-time enchant rolls happen through `PetGrantService` after progression slot defaults are stamped. Manual rerolls go through `EnchantService:RerollPetEnchant` and the `EnchantPetRequest`/`EnchantPetResult` remotes. If `configs/enchants.lua` `reroll.requires_station` is true, rerolls require recent activation of a bound `EnchanterStation` map hook.
- Manual reroll affordability and debit flow through `EconomyService`; a rejected debit returns
  before rolling or mutating the pet's existing enchant state.
- Enchanter stations are map-authored fixtures bound by `WorldBindingService` through the `EnchanterStation` tag. `configs/enchants.lua` `stations` owns the station display name, touch child name, prompt text/distance, and optional animation script toggling. Cosmetic scripts may stay inside the model; gameplay activation is service-owned.
- Equipped unique pet enchants register through the shared `enchants` modifier stage. `EnchantService` interprets the config generically: it reads each effect's `modifier.stage`, `kind`, optional `currency`, `combine`, and `amount_per_strength`, then contributes only when a gameplay system resolves the matching modifier context.
- `PlayerProgressionService` owns config-driven player-level effects. `configs/player_progression.lua` currently contributes a `team_power` modifier from player level and grants extra equipped pet slots at configured level milestones. Inventory slot calculation consumes this service next to permanent upgrades. The service also mirrors its authoritative XP-derived earned level into `player.leaderstats.Level` for Roblox's native player list; that `IntValue` is presentation-only and is never saved separately.
- `AutoTargetService` owns Phase 5 auto-system settings and server decisions. `configs/auto_systems.lua` declares target modes and hatch auto-delete rules; profiles store only player choices under `Settings.AutoSystems`. Clients request an auto-target attack, but the server selects the breakable and applies the existing breakable attack path.
- Hatch auto-delete is enforced after the egg outcome is selected and before `PetGrantService` creates inventory state. It can match configured rarity, pet family, or variant filters, while protected special rarities such as Secret/Exclusive/Huge are not auto-deleted by default.
- Egg hatch affordability, charges, partial refunds, and full refunds route through
  `EconomyService`; isolated no-loader test contexts retain the legacy attribute-only fallback.
- Phase 4 now wires the high-priority enchant modifier consumers: `hatch_luck`, `secret_hatch_luck`, `pet_damage`, `team_power`, and `pet_efficiency`. `EggService` resolves hatch-luck contexts before selecting the outcome, `PetHandler` resolves team power when spawning equipped pets, and the legacy pet follow script resolves damage/cadence modifiers while mining.
- The pet follow/mining script is a stabilized legacy bridge, not the desired long-term shape. Future work should replace it with a service-owned pet assignment/work loop so target selection, cadence, damage, and modifier contexts are testable without cloned scripts.
- Valuable pet provenance is separate from audit source. `grant_source` remains internal metadata such as `egg_hatch` or `admin_grant`; `hatcher_name`/`hatcher_user_id` record who created a valuable copy. `configs/pets.lua` currently stamps hatcher provenance for pets whose enchant capacity is at least `3`, which covers Huge and future above-Huge tiers by config.
- Inventory pet tooltips are config-filtered. Pet records may replicate primitive metadata, but `configs/inventory.lua` `tooltip_fields` controls labels, ordering, and hidden audit/internal fields so new pet metadata does not require client code edits just to show or hide it.
- Inventory pet cards use two config-driven visual channels. `configs/inventory.lua` `card_visuals.rarity_rings` controls border color, thickness, and optional animated `UIGradient` rotation by rarity id; `card_visuals.variant_backgrounds` controls card fill by variant. Rarity display names/colors come from `configs/pets.lua` `rarities`, so developers can rename tiers or add future tiers such as `colossal` without changing UI display code.
- `UpgradeService` owns config-driven permanent upgrade purchases. Levels persist under `DataService.Upgrades`; equip/storage effects feed inventory limits, and modifier effects register as `permanent_upgrades` providers.
- Upgrade purchases commit their level through `EconomyService:Transact`; failed affordability or
  commit leaves both balance and level unchanged. Economy's legacy item-shop inventory reference is
  installed by the composition root after loader construction, avoiding the former
  Economy-to-Inventory-to-Upgrade dependency cycle.
- `PetIndexService` owns first-time pet/variant discovery. It writes compact `PetIndex.Discovered` records, syncs the K1 `distinct_pets` counter, and grants `configs/pet_index.lua` milestones once.
- Pet-index milestones grant currency only through injected `EconomyService`; there is no direct
  persistence fallback.
- `AchievementsService` owns config-tier completion over K1 counters. It listens to `StatsService.CounterChanged`, persists completed tiers under `Achievements.Completed`, and grants rewards once through `RewardService` or the economy-only legacy fallback.
- `LeaderboardService` owns K1-backed live in-server leaderboard snapshots and optional throttled OrderedDataStore publication for global boards.
- `configs/network.lua.packets` is the incremental network manifest. `NetworkManifest` validates packet names, transport, direction, authorization, environments, delivery, schemas, and client-origin rate/handler metadata at boot and in headless CI. `SignalRegistry` is the sole manifest-to-transport constructor. Twenty-six exact-compatible notifications now use the manifest, including progression, economy, interaction, combat-presentation, player-status, gameplay-event, and debug packets; the legacy bridge table and remaining `Signals` declarations stay live until later compatibility slices remove them.
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

## Boot Orchestration (shipped + live-verified)

Boot is **event-driven milestones**, not polling (design: [BOOT_ORCHESTRATION.md](../BOOT_ORCHESTRATION.md)). `BootReadiness` is a latch — a milestone fires once and stays up, so late awaiters resolve immediately. `configs/boot.lua` declares the producer→consumer dependency graph; `BootOrchestrator` mirrors milestone state to `ReplicatedStorage.BootStatus` for the config-driven client loading screen. **The invariant for any boot-path code: await a milestone.** Never `:Wait()` on a fire-once event (you may have missed it), never `FindFirstChild`-and-abort, never poll-loop. Producers: AssetPreloadService, GameStructureService; migrated consumers: PetHandler, BreakableSpawner, EggStandPlacement. Live-verified: every published-game boot since 2026-07 runs this path — the loading screen gates on real milestones and play starts with data loaded.

## Architecture Fitness Gate

`scripts/architecture_guard.py` runs first in `mise run ci`. Its reviewed baseline in `scripts/architecture_allowlist.json` records existing architecture debt by rule, exact path, and occurrence count. A new path or count increase fails CI. A count decrease also fails until the allowlist is reduced in the same cleanup change, so the baseline can only ratchet downward deliberately.

The initial rules cover remote construction, direct gameplay-event publication, pet-record mutation, direct currency persistence calls, `_G.RBXTemplateServices`, runtime `task.wait`/`task.delay`, and configs without explicit `ConfigLoader` validation. Focused local modes are `--network`, `--mutations`, `--timing`, `--configs`, and `--services`. Debt removal is tracked in GitHub issue #3.

`FireGameEvent` is the exclusive gameplay-event publication boundary. It notifies server taps, resolves configured world sound, and then sends the client packet; direct service sends are no longer allowlisted.

## Links

- [Implementation Plan](../IMPLEMENTATION_PLAN.md)
- [Current Status](CURRENT_STATUS.md)
- [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md)
