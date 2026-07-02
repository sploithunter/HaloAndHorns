# Template vs Game — Classification Manifest

This repo (`RBX-Template`) follows **Option A**: it *becomes* the game (Pet Realm /
Halo & Horns), while the reusable **template** stays a conceptual layer preserved via
config-as-code. There is no separate template fork — the clean pre-game baseline is the
`template-base` git tag, and `git diff template-base..main` is the full delta.

This manifest is the **ledger** that the `template-base..main` diff lacks: it says which work
should flow **back into the template** for reuse across future games, which is **Pet-Realm
content** that stays here, and which game-specific work is worth keeping as a **reference
example** in the template even though its values are game-specific.

> **Status:** first pass (2026-05-31). Buckets marked ⚠️ are judgment calls — correct them as
> the product direction firms up. Keep this file updated when you add a system (see the
> convention at the bottom).

## The three buckets

| Bucket | Meaning | Extraction intent |
|---|---|---|
| 🟦 **Template-Core** | Generic engine/system. Applies to many games; the *code* transfers, only config *values* change. | Flows back to the template as-is. |
| 🟨 **Template-Reference** | Pet-Realm-specific in purpose, but a strong worked example of the template's patterns (config + pure core + service + spec + bus). | Ship in the template as an example/sample feature, clearly labeled. |
| 🟥 **Game-Only** | Pure Pet Realm content/lore/tuning. No reuse value. | Stays in this repo. |

**The config-as-code seam:** almost every `configs/*.lua` file is the *game-values* layer —
the game's tuning of a template system. The template ships the **schema + sane defaults**; the
game ships the **values**. So a config file being "game-owned" does not make its *system*
game-only. Classify by the system, not the values file.

---

## 🟦 Template-Core — infrastructure & dev tooling

These predate or generalize beyond Pet Realm. Most are at/near `template-base`; the dev tooling
is the biggest *new* template-worthy addition.

- **Boot & framework** — `src/Server/init.server.lua`, `src/Client/init.client.lua`, the loader,
  `ConfigLoader.lua`, `Locations.lua`, `Constants/`, `State/`, `Utils/Logger.lua`, `Network/` (Signals).
- **Persistence** — `DataService.lua` (ProfileStore-style data, `SchemaMigrations` ladder,
  conservation-guarded migrations). The migration *framework* is core; specific pet migrations are Reference.
- **Automation API** (new, template-worthy) — `src/Shared/API/` (CommandBus, Validators, Navigation),
  `GameAPIService.lua`, `AutomationService.lua`, `StudioSmokeTestService.lua`,
  `tests/headless/` harness, `tests/studio/AutomationSuite.lua`, `mise run ci`, `.github` workflow,
  `release.sh`. See [Automation API Design](AUTOMATION_API_DESIGN.md).
- **Admin framework** (new, template-worthy) — `AdminService.lua` (capability gating),
  `AdminToolsService.lua`, `HatchEntitlementService.lua`, `src/Client/UI/Menus/AdminPanel.lua`.
  Generic admin shell; the specific actions are game-tuned.
- **Live-ops scaffolding** — `RewardService` + `RewardResolver`/`RewardBundle`,
  `QuestService`, `DailyService` + `DailyStreak`, `ShopService` + `ShopLogic`, `ClaimLogic`,
  `AchievementsService`, `StatsService`, `LeaderboardService`.
- **Economy** — `EconomyService`, `MonetizationService`, `UpgradeService`, `currencies`/`economy`/`monetization` configs (schema).
- **Server utilities** — `RateLimitService`, `ServerClockService`, `DiagnosticsService`,
  `SettingsService`, `EventService`, `GlobalEffectsService`, `ModifierService`, `PlayerEffectsService`,
  `AssetPreloadService`, `WorldBindingService`.

## 🟦 Template-Core — gameplay systems (reusable mechanics)

These are the "applies to multiple games" systems you called out (trading, hatching, …).

| System | Pure core(s) | Service / UI | Notes |
|---|---|---|---|
| **Trading** | `TradeLogic` | `TradeService`, trade UI | Atomic escrow + audit. Fully generic. |
| **Egg hatching** | `HatchTiming` | `EggService`, `EggHatchingService`, `EggWorldQuery` | Hatch lock + count-scaled server cooldown (the SSOT). Generic gacha/hatch engine. |
| **Inventory SSOT** | `PetInventoryView` (+ pet migrations ⚠️) | `InventoryService` | Ownership-vs-equip SSOT *pattern* is core; pet flavoring is Reference. See [PET_INVENTORY_SSOT](PET_INVENTORY_SSOT.md). |
| **Rewards/Quests/Daily/Shop** | `RewardResolver`, `RewardBundle`, `ShopLogic`, `DailyStreak`, `ClaimLogic` | `RewardService`, `QuestService`, `DailyService`, `ShopService` | Live-ops spine. |
| **Party / social** | `PartyMath` | `PartyService` | Group size/share math. |
| **Roster / loadout** | `RosterLogic`, `ActiveSquad`, `HotbarLogic` | `RosterService`, `ActiveSquadService`, `HotbarService` | Deployable-unit + hotbar mechanics. |
| **Progression** | `LevelCurve`, `PowerFormula`, `ArchetypeLogic`, `Augmentation`, `PowerSelection` | `PlayerProgressionService`, `ArchetypeService`, `AugmentationService`, `PowerService` | Generic XP/class/upgrade patterns. |
| **Fusion** | `FusionLogic` | `FusionService` | Combine-items mechanic. |
| **Resource pool** | `StackPool` | `StackPoolService` | Token-bucket (regenerating resource). |
| **Combat math** ⚠️ | `CombatMath`, `CombatSim`, `Targeting` | `CombatService`, `AutoTargetService` | Math/targeting are generic; the "invulnerable spirit, pets deal damage" *rule* is Reference. |
| **Follower / attack movement** | `PetFormation` | `PetFollowService`, `PetFollowController` | Config-driven, **size-aware** follow formations (conga/risers/arc) + attack formations (orbit/static_ring/lunge/spiral/pincer/firing_line/swarm), both player-selectable + persisted; per-player + per-pet **move speed**; teleport **catch-up snap**. Works for any follower game. |
| **Conditions** | `Condition` | — | Generic predicate evaluation. |

## 🟨 Template-Reference — Pet Realm features worth shipping as examples

Game-specific, but each is a clean demonstration of a template pattern (config-driven
matrix/topology/cooldown/tiered-access). Keep as labeled sample features.

| Feature | Pure core(s) | Service / config | Pattern it exemplifies |
|---|---|---|---|
| Soul alignment | `SoulMath` | `AlignmentService`, `soul` | Directional/bipolar stat with thresholds. |
| Ring map | `RingTopology` | `ZoneService` ⚠️, `areas`/`biomes` | Topology/zone graph from config. |
| Elements & themes | `ElementResonance`, `PetElement`, `ThemeUtility` | `elements`/`theme_utility`/`biomes` | Config-driven affinity/resonance matrix. |
| Layers (Heaven/Hell tiers) | `LayerAccess` | `LayerService`, `layers` | Gated progression tiers. |
| Spirit form | `SpiritForm` | `SpiritFormService`, `spirit_form` | Cooldown-gated transform ability. |
| Chaos rifts | `RiftMultiplier` | `rifts` | Time/condition-scaled multiplier. |
| Focus resource | `FocusMath` | `FocusService`, `focus` | Combat resource with regen/spend. |
| Pet power & combat | `PetPower`, `PetCombat` | `PetProgressionService`, `EnchantService` | Stat-at-acquire + damage pipeline wiring. |

## 🟥 Game-Only — Pet Realm content & lore

- **Content/data** — `configs/pets.lua` (the roster), `pet_index`, `pet_progression`, `enchants`,
  `enemies`, `breakables`, `areas`/`biomes` *values*, `egg_system`/`egg_hatching` *values*.
- **Pet plumbing tied to this game's pets** — `PetGrantService`, `PetIndexService`,
  `PetSerialService`, `PetHandler.server.lua`, `PetEquipmentBridge`, `PetCharacterAttachments`,
  `PetCompatibilityService`, `ImportedPetHandler`, `PetScripts/`.
- **World** — Studio-authored `Maps/` (ring map, Earth/Ice/Lava terrain), breakable spawns
  (`BreakableService`/`BreakableSpawner` are core engine; the *spawn content* is game).
- **Narrative** — the heaven/hell directional design, zone names, specific egg/area identities.

---

## Going-forward convention

So bucket-B stops accumulating unlabeled:

1. **Tag commits** with the dominant bucket in the subject: `[template]`, `[example]`, or
   `[game]` (use `[template]` when a change is reusable engine work even if done for the game).
2. **Update this manifest** when you add a system or move one between buckets — it is the index
   of record for a future template extraction. (The wiki maintenance rule already requires this.)
3. **Keep the seam clean**: new systems = generic service/pure-core + values in `configs/`. If a
   service hardcodes a Pet-Realm value, that's a bug against the template layer.
4. **Periodically** consider refreshing `template-base` or maintaining a `template` branch that
   only receives 🟦 changes, once the reusable set is worth extracting.

## Extraction checklist (when the time comes)

To harvest the template from this repo: take 🟦 as-is, take 🟨 as labeled samples, drop 🟥,
and replace each `configs/*.lua` with its schema + neutral defaults. The hard part is already
done — this manifest is the pick-list.
