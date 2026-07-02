# Admin Control Panel audit — dead / broken / stub actions

**Scope:** `src/Client/UI/Menus/AdminPanel.lua` (~2154 lines) — every button → action string → executor → server handler.
**Method:** traced each action through `_executeTestAction` and sibling executors, then grepped the actual server handlers (`AdminToolsService`, `EconomyService`, `InventoryService`, `AssetPreloadService`, `DiagnosticsService`, `GameAPIService`) + configs (`items`, `enemies`, `currencies`, `events`, `pets`, `areas`, `admins`). Recent commit `5d2944f8` only restyled chrome — functionality unchanged.

**Headline:** the server side is in remarkably good shape — all 18 admin Signals have live `OnServerEvent` handlers, and every enemy/pet/currency/event/zone id a button references exists in config. The real rot is on the **client dispatcher**: a substring-based `if/elseif` routing chain in `_executeTestAction` silently drops **5 buttons** to "Unknown action", and one buy button uses a stale itemId. Plus a handful of genuine client-only stubs.

---

## 🔴 BROKEN — button fires but nothing happens

### Client routing dead-ends (5) — executor exists, dispatcher never calls it
`_executeTestAction` (AdminPanel.lua:746) routes by `action:find(...)` substring. Five actions match none of the branches and fall through to `else → "Unknown action"`, even though their executor maps (and server handlers) are fully present.

| Button | action | Why dead | Fix |
|---|---|---|---|
| **Show Active Global Events** | `show_global_events` | No branch matches — needs `effect`/`start_` substring; has neither. `_executeEffectAction` map *does* handle it (`command="snapshot"`) and server `_handleEventCommand` handles `"snapshot"`. | Add explicit route to `_executeEffectAction`. |
| **Clear Global Events** | `clear_global_events` | Same — falls through. Server handles `command="clear"`. | Same. |
| **Set All to INFO** | `set_all_info` | Logging branch only matches `log`/`console`/`performance`; `set_all_info` contains none. `_executeLoggingAction` *does* handle it. | Route `set_all_*` to `_executeLoggingAction`. |
| **Set All to DEBUG** | `set_all_debug` | Same. | Same. |
| **Set All to WARN** | `set_all_warn` | Same. | Same. |

> Note: `show_log_config`, `disable_console`/`enable_console`, `enable_performance`/`disable_performance` survive (they contain `log`/`console`/`performance`). Only the three `set_all_*` levels are dead. Likewise `test_effect_stacking` and all `start_*` events survive.

### Stale itemId (1)
| Button | action | Why broken | Fix |
|---|---|---|---|
| **Buy Premium XP Boost (10 gems)** | `buy_premium_xp_boost` → itemId `premium_xp_boost` | `ConfigLoader:GetItem` reads only `configs/items.lua` and the id there is **`premium_boost`** (line 99). Server replies "Item not found". The client-supplied cost/currency is ignored — only `itemId` matters. | Change client `itemId` to `premium_boost` (and the label/price to match the config). |

---

## 🟡 STUB — placeholder that intentionally does nothing

| Button | action | Behaviour |
|---|---|---|
| **Test Rate Limiting** | `test_rate_limiting` | `_testRateLimit` is explicitly disabled: only logs `"Rate-limit test disabled pending Net migration"`. Dead since the sleitnick/Net migration. |
| **🐾 Debug Pet ViewportFrames** | `debug_pet_viewports` | `_debugPetViewports` logs `"Coming Soon!"` and returns. Never implemented. |
| **🔍 View All Generated Images** | `view_all_assets` | `_viewAllAssets` → `_createComprehensiveAssetViewer`, which only logs `"placeholder implementation"` and returns `true`. No viewer ever opens. |

---

## 🟠 VESTIGIAL — runs, but pointless or misleading

| Button | action | Note |
|---|---|---|
| **Performance Test** | `performance_test` | Creates+destroys 1000 `Frame`s in workspace, logs elapsed time to console. A meaningless micro-benchmark; harmless but useless. |
| **Network Bridge Test** | `network_test` | Reports `economyBridge: CONNECTED` (always — it's a synthetic table) and checks `self.effectsBridge`, which is **never assigned** (only set to `nil` at line 373), so it *always* prints `Effects bridge: NOT CONNECTED`. Misleading. |
| **Debug: Print Current Data** | `debug_print_data` | Prints local `leaderstats` to the client console. Works, but console-only and trivial. |

Also adjacent (not buttons): `_refreshPlayerList()` calls `economyBridge:Fire("get_player_list", {})`, but that bridge ignores the verb and fires `Signals.PurchaseItem` with empty data → server returns a "No item specified" error toast. The player list never returns; the **Select Player** dropdown still works because it cycles `game.Players:GetPlayers()` locally. And the `_executeEffectAction` map has two unused entries (`start_xp_weekend`, `start_speed_hour`) with no buttons.

---

## ✅ WORKING — verified wired client→server→config

**💰 Economy** — 8/9 buy buttons (all but Premium XP Boost). `PurchaseItem` → `EconomyService:PurchaseItem` → `GetItem`; ids `test_item, health_potion, wooden_sword, iron_sword, basic_pickaxe, diamond_sword, speed_potion, trader_scroll` all present in `configs/items.lua`.

**💎 Currency** — `add_coins_1000`, `add_gems_100`, `add_crystals_50`, `add_area_coins` (grass/ice/lava/desert all in `configs/currencies.lua`), `reset_currencies`, `Adjust Coins/Gems` custom. `AdjustCurrency` → `EconomyService` with `AdminService:ValidateAdminAction(adjustCurrency/setCurrency)`.

**⚡ Effects** — `test_effect_stacking`, `start_hatch_luck_hour`, `start_double_rewards_hour`, `start_crystal_rush`, `start_coin_shower`. All eventIds in `configs/events.lua`; `Admin_EventCommand` → `_handleEventCommand` → `EventService`. *(snapshot/clear are the two dead ones above.)*

**🧰 Developer** — snapshot, force save, reset pets, reset-to-beginning (+ preview), all pet grants (`bear/dragon/colorado/colorado_creator` all in `configs/pets.lua`, validated via `getPet`), Meadow zone toggle/lock/unlock/bypass (`Meadow` is a valid id in `configs/areas.lua`), `grant_enhancements_100` (→ `GameAPICommand` RemoteFunction, `enh.grant` registered at `GameAPIService.lua:842`), all hatch-entitlement actions, hatch history, hatch simulation, + all custom inputs. All `AdminToolsService` handlers present and substantive (not stubs). Destructive ops (`resetData`, `setCurrency`) are Studio-gated by `requireStudioForSensitiveOps` — by design, not broken.

**⚔️ Combat** — all 19 enemy spawn buttons + custom. Every id (`rabid_dog … infernal_boss`) exists in `configs/enemies.lua`; `Admin_SpawnEnemy` → `EnemyService:SpawnEnemy`.

**📊 Logging** — `show_log_config`, `disable_console`/`enable_console`, `enable_performance`/`disable_performance`, `set_service_log_level` custom. Client-only via `Logger` (all 5 methods exist in `src/Shared/Utils/Logger.lua`). *(the three `set_all_*` are dead — above.)*

**🎒 Inventory** — `cleanup_inventory`, `fix_item_categories` → `CleanupInventory`/`FixItemCategories` handlers in `InventoryService` (lines 1496/1507).

**🖼️ Assets** — `debug_egg_viewports` (`EggHatchingService:DebugEggViewports` exists), `asset_stats` (client folder read), `force_regenerate_assets` (`ForceRegenerateAssets` → `AssetPreloadService:LoadAllModelsIntoAssets`, admin-gated). *(view_all_assets + debug_pet_viewports are stubs — above.)*

**🥚 Egg Hatching** — all `hatch_N_eggs` + custom count/specific-pet → `EggHatchingService:StartHatchingAnimation` (client-side visual sim).

**🔧 System** — `run_diagnostics` → `DiagnosticsService:_runDiagnostics` runs the TestEZ suite and fires a report back to `_showDiagnosticsPopup`.

---

## Proposed cleanup list (for approval — nothing changed yet)

**Fix (restore intended function):**
1. Route `show_global_events` / `clear_global_events` to `_executeEffectAction` (add explicit `elseif` or fold into the effects branch).
2. Route `set_all_info` / `set_all_debug` / `set_all_warn` to `_executeLoggingAction`.
3. `buy_premium_xp_boost`: change itemId to `premium_boost` (fix label/price to match `configs/items.lua`).

**Decide — remove or implement:**
4. **Test Rate Limiting** — remove the button (disabled since Net migration) or write a Net-based test.
5. **Debug Pet ViewportFrames** — remove or implement.
6. **View All Generated Images** — remove or implement `_createComprehensiveAssetViewer`.

**Optional trim (vestigial):**
7. **Performance Test** + **Network Bridge Test** — remove, or fix `network_test` to reflect the real (Signals-based) wiring and drop the never-assigned `effectsBridge`.
8. Dead `_executeEffectAction` map entries `start_xp_weekend` / `start_speed_hour`.
9. `_refreshPlayerList()` — drop the bogus `get_player_list` round-trip (the dropdown works locally without it).
