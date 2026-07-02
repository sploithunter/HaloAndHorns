# Egg System Plan

Status: current baseline complete; polish in progress

Implemented so far:

- `configs/egg_system.lua` now declares `hatching.max_count = 99`, partial-hatch policy, transaction lock timing, compatibility purchase counts, animation policy, and shop/entitlement stubs.
- `EggService` accepts both legacy `eggType, purchaseType` calls and new table requests with `requestedCount`; the server resolves actual hatch count from entitlement, currency, auto-delete, and mixed pet storage before charging.
- Per-player hatch locks now cover the server transaction, blocking rapid repeat requests that previously created invisible hatches.
- Batch responses include legacy `Pet`/`Type`/`Power` fields plus `requestedCount`, `hatchCount`, `results`, `stopReason`, `entitlements`, and authored egg animation metadata.
- Client hatch controls now support `E` single hatch, `R` max hatch, and `T` auto hatch through the same server-authoritative endpoint.
- Auto hatch now uses a config-driven loop delay, server-validated auto hatch entitlement, and session ids so stale stopped sessions do not drive client presentation.
- `EggInteractionService` now owns a config-driven hatch panel with selected-count controls, Hatch/Max/Auto buttons, stop/status messaging, and a compact auto-delete filter drawer for rarity, pet-family, and variant filters backed by the existing server filter event.
- Hatch mode toggles now flow through the same request contract: Golden mode is server-entitlement checked, gives locked-mode feedback, applies the configured cost multiplier, and excludes basic variants; Fast/Silent/Skip are returned as presentation options for hatch animation.
- Charged mode now uses the same config-first hatch mode path: it is server-entitlement checked, has a configured cost multiplier, and applies configured hatch-luck and secret-luck bonuses before the pet/variant roll.
- Admin hatch entitlement controls now expose the current shop stubs for testing: Auto, Golden, Charged, Fast, Skip, and max hatch count can be locked/unlocked/reset from the admin panel without changing code or waiting for the shop UI.
- The hatch settings drawer now has config-driven help copy for auto-delete filters, hatch mode toggles, and core hatch controls. Hover/focus text is stored on the controls as `HelpText` attributes so player education stays data-driven.
- `EggBatchHatchSmoke` covers multi-hatch cost/count behavior, rapid-repeat rejection, partial hatching when funds or storage only cover a smaller count, hatch-time auto-delete inventory/stat behavior, locked Auto/Golden/Charged mode rejection, auto session id echo on errors, Golden mode cost/no-basic behavior, and Charged mode cost behavior.
- `EggAutoHatchSmoke` covers client auto-hatch stop feedback for no currency, no storage, and moving too far away.
- `EggProximitySmoke` also verifies the hatch panel appears near eggs with its expected controls and hatch drawer help text.
- `HatchEntitlementAdminSmoke` covers the admin-managed hatch entitlement path and restores player attributes after testing.
- Authored egg animation ViewportFrames use config-driven scale: a global default in `egg_system.hatching.animation.authored_visual_scale` plus per-egg overrides such as `pets.egg_sources.basic_egg.animation.authored_visual_scale`.
- Hatch reveal polish is now partly config-driven. `egg_system.hatching.animation.reveal_badges` controls rarity, variant, special, and auto-delete badges, while `EggHatchingService:GetActiveAnimationDebugState()` exposes the active animation metadata for Studio smokes. `EggAnimationContractSmoke` verifies special and auto-deleted reveal markers on the client animation layer.
- The hatch settings drawer now exposes mode entitlement state before the server rejects a hatch. Mode controls carry `ModeState`, `ModeOwned`, and dynamic help text attributes, and a `ModeStatus` line summarizes active and locked modes from config/player attributes.
- `EggService` now keeps a bounded, config-sized recent hatch history for each player. The history records successes and rejected hatch requests with requested count, actual hatch count, cost, stop reason, options, entitlements, sampled results, auto-delete counts, special counts, and authored animation metadata. Admin tools can request this snapshot, and `EggHatchHistorySmoke` verifies the server debug contract.
- Studio forced hatch setup is now deterministic. `EggService` reads `ForcePet`/`ForceVariant` player attributes before rolling instead of relying only on mutating a copied config table, so storage/history smokes can force unique or auto-deleted outcomes reliably.
- `ConfigLoader` now validates the egg-system hatch contract more deeply: requested/default counts must fit inside `hatching.max_count`, animation capacity cannot exceed hatch capacity, debug history limits are positive, reveal badges have valid field types, shop max-count defaults stay within the configured hatch cap, and hatch-panel button labels must exist. `ConfigLoader.spec` covers the valid path plus count, animation, and UI-button failures.
- `EggService:SimulateHatchBatch` now provides a no-mutation server hatch simulation path for admin/testing. It rolls the same pet/variant/luck pipeline and returns costs, entitlements, option resolution, result samples, pet/variant/rarity counts, special counts, auto-delete matches, and animation metadata without spending currency, granting pets, incrementing stats, or playing client animation. Admin tools expose it and `EggHatchSimulationSmoke` verifies the non-mutation contract.
- The near-egg hatch panel now reflects effective hatch entitlements before a request is sent. It clamps the selected count to the same max-count source the server resolves from config/player attributes, exposes `MaxEntitledHatchCount` for testing/UI, and grays/blocks Auto when `AutoHatchUnlocked` is false.
- Hatch animation layout and special-result glow are now config-driven. `egg_system.hatching.animation.layout` controls grid padding and min/max egg sizes, `special_glow` controls the special rarity stroke/pulse, `EggHatchingService:GetActiveAnimationDebugState()` exposes the chosen layout/glow metadata, and `EggAnimationContractSmoke` verifies the client contract.
- Fast Hatch animation speed is now config-driven through `egg_system.hatching.animation.fast_hatch_speed_scale`. The animation debug state exposes resolved timing/options, and `EggAnimationContractSmoke` verifies that Fast/Silent hatch options use the configured scale.
- The near-egg hatch panel now persists the player's selected hatch count under `Settings.AutoSystems.hatch.selected_count`. `SettingsService` replicates it to `Player.Settings.AutoSystems.Hatch.SelectedCount`, the client restores it when the panel is created, and `EggProximitySmoke` verifies the replicated client/server round trip.
- Hatch mode preferences now persist under `Settings.AutoSystems.hatch.modes`. `SettingsService` sanitizes mode keys from `egg_system.ui.hatch_panel.modes`, replicates them under `Player.Settings.AutoSystems.Hatch.Modes`, and `EggInteractionService` restores/persists Golden, Charged, Fast, Skip, and Silent mode toggles without making the server trust those preferences for entitlement.
- The near-egg hatch panel now keeps replicated hatch settings live after creation. Changes to replicated selected count or mode values update the visible panel, and the panel exposes per-egg, multiplier, total, and affordable-count cost metadata for multi-hatch UI/debugging.
- The selected hatch count is now a direct editable input as well as a button-driven selector. Typed values are parsed, clamped to effective entitlement, persisted through the same settings path, and covered by `EggProximitySmoke`.
- The near-egg hatch panel now has config-driven responsive scaling. `egg_system.ui.hatch_panel.responsive` controls margin/min/max scale, `EggInteractionService:ComputeHatchPanelLayout()` exposes desktop/mobile fit math, and `EggProximitySmoke` verifies the panel remains full scale on desktop while fitting a mobile-width viewport.
- Hatch animation now has explicit max-batch coverage. `EggHatchingService` resolves a sane fallback viewport when Studio reports an uninitialized `1x1` camera size, exposes resolved container/frame geometry through `GetActiveAnimationDebugState()`, and `EggAnimationMaxBatchSmoke` verifies `99` authored egg frames fit in the compact `10x10` layout.
- Hatch mode education now includes config-derived economics. The hatch drawer reads mode cost/luck details from `egg_system.hatching.shop_stubs`, exposes them as UI attributes, and shows details such as Golden `20x` cost and Charged luck bonuses in help/status text.
- The expanded hatch drawer now has automated layout coverage. `EggProximitySmoke` opens the real `PlayerGui` drawer, verifies desktop/mobile fit math, and checks that visible drawer controls are not clipped inside the configured drawer bounds.
- Special hatch animation polish now has a config-driven backdrop layer. `egg_system.hatching.animation.special_backdrop` controls a rarity-colored reveal backdrop behind special pets, `ConfigLoader` validates its fields, and `EggAnimationContractSmoke` verifies the visual contract.
- Hatch result stacking/readout polish is now config-driven. `egg_system.hatching.animation.result_stack` controls duplicate-result stacking, name/count labels, count threshold, tween timing, and hold duration; `EggAnimationContractSmoke` verifies duplicate Bear hatches stack into a `Bear x2` readout.
- `docs/EGG_AUTHORING_AND_ADMIN_TESTING.md` now documents the current authored egg stand workflow, two-stage hatch rules, admin hatch entitlement stubs, and Studio smoke commands for egg testing.
- Egg source unlock requirements now run through the server hatch pipeline. `EggService` checks `egg_sources.<id>.unlock_requirement` for real and simulated hatches, returns `egg_locked` with current/required progress, `ConfigLoader` validates the requirement shape, and `EggUnlockSmoke` verifies locked/unlocked golden egg behavior in Studio.
- Skip Hatch is now guarded at the animation service boundary too. `EggInteractionService` already avoids calling hatch animation when `skipHatch` is active, and `EggHatchingService` now immediately returns a completed skipped result without enabling the animation GUI or creating frames if a future caller passes `skipHatch`; `EggAnimationContractSmoke` verifies this contract.
- Show Hatch is now a free, persisted, default-on presentation preference. `egg_system.ui.hatch_panel.modes.show.default_enabled` seeds/migrates `Settings.AutoSystems.hatch.modes.showHatch`; turning it off suppresses hatch animations without needing the paid Skip Hatch entitlement, while Skip Hatch remains a separate hard animation suppressor.
- `HatchEntitlementService` now centralizes the server hatch shop/unlock stubs. `EggService` resolves Auto/Golden/Charged/Fast/Skip, max hatch count, hatch-luck bonus, and secret-luck bonus through the same service that admin tools use for snapshots and overrides.
- The hatch settings drawer now surfaces server-protected auto-delete tiers directly from `configs/auto_systems.lua`. Secret/Exclusive/Huge protection remains a single source of truth in `auto_delete.protected_rarities`, while the UI renders the current protected list and `EggProximitySmoke` verifies it.
- `ConfigLoader` now cross-validates egg-system rarity/filter references against pet config. Special hatch rarity ids must exist in `pets.rarities`, and hatch drawer auto-delete filter lists must reference configured rarity, pet family, and variant ids.
- Hatch auto-delete filters now have a durable replicated UI contract. `SettingsService`/`AutoTargetService` publish `Player.Settings.AutoSystems.AutoDelete.Enabled`, `Rarities`, `PetTypes`, and `Variants`; `EggInteractionService` live-binds those folders so saved filter choices survive missed status packets and drawer rebuilds.
- Hatch auto-delete education now includes a config-owned header summary for saved filter counts, including the important off-but-filters-saved state.
- The near-egg hatch surface is now compact by default and uses only the original `EggCurrentTarget` proximity UI. A persisted `Settings.AutoSystems.hatch.action_mode` setting controls whether pressing E performs single hatch, max hatch, or auto hatch; the billboard displays the matching prompt plus total cost/per-egg/max/affordability detail. The separate lower `EggHatchPanel` screen was removed to avoid duplicate proximity UI, and the Settings menu owns the first player-facing controls for action mode plus Show/Silent hatch presentation preferences.
- Egg billboard prompt style is developer-configured through `egg_system.ui.interaction_prompt.mode`: `clean` follows the selected E-key action, while `advertised_hotkeys` shows the legacy E/R/T shortcut hint for games that want the noisier onboarding surface.

Still to build:

- Richer compact near-egg hatch UI polish beyond the current cost/action/status pass, plus direct Studio screenshot QA across desktop/mobile layouts when screenshot capture is available.
- Move auto-delete/filter editing out of the always-visible egg-adjacent flow. Candidate player-facing paths are Settings menu controls, interactions on the pet preview billboard, or inventory card actions after the player has discovered a pet.
- Further hatch setting UI polish beyond the current Settings-menu action mode, Show/Silent toggles, config-derived mode cost/luck education, protected auto-delete tier list, saved-filter summary, Max/Auto entitlement state, and dynamic hover/focus help text.
- Richer authored egg animation visual polish beyond the current ViewportFrame clone/scale/reveal-badge/glow/backdrop/result-stack pass.
- Direct Studio screenshot QA across desktop/mobile layouts for the expanded hatch drawer when screenshot capture is reliable; current automated geometry/debug-state coverage exists, and a local screenshot attempt timed out.

## Goal

Build eggs into a complete, config-first pet-simulator subsystem while keeping the server authoritative. Egg stands are authored map fixtures; egg behavior, costs, hatch modes, odds, variants, auto-delete, animation policy, and unlock rules live in config.

The designed hatch ceiling is `99` eggs. The hatch request should allow a desired count from `1` to `99`, but the server resolves the actual count from player entitlement, available currency, storage capacity, and egg settings. If the player asks for `99` and can afford/store `37`, hatch `37`; if the player can afford/store none, return a clear stop/error reason.

## Reference Findings

Pet Simulator X / 99 patterns worth adapting:

- Eggs are area/progression objects with cost, unlock requirement, and pet table.
- Multi-hatch is a first-class capability. This project should support any count `1..99`, not only fixed 3/9 progression steps.
- Auto-hatch is a loop state, not repeated manual clicking.
- Premium hatch modifiers include faster hatch, skip hatch, luck, huge/secret luck, Magic Eggs-style golden/rainbow chance, golden-only/charged modes, and additional egg slots.
- High-volume hatching depends on auto-delete/filtering so inventory and saves remain manageable.
- Special hatches need stronger reveal treatment when hatch animations are enabled. Skip Hatch is a hard player preference that hides the animation while auto-hatching; it should not be bypassed by special rarity outcomes.

ColorfulClickers patterns worth preserving conceptually:

- Single, triple, and nine hatch modes.
- Auto hatch loop near the current egg.
- Hatch speed scaling from Fast Egg-style ownership.
- Player settings for show/silence hatches and server hatch messages.
- Auto-delete by rarity.
- Special reveal fanfare for Secret/Exclusive/Huge/Colossal.
- The egg animation clones the actual world egg model, so authored eggs such as rocks can hatch as themselves.

## Core Architecture

Create one hatch pipeline:

1. Client requests `{ eggId, requestedCount, options, autoSessionId? }`.
2. Server validates target, distance, unlock, cooldown/lock, requested count, feature entitlement, currency, and storage.
3. Server resolves actual count, total cost, and stop reason. Counts above `99` are rejected or clamped by config; counts below affordable/storable capacity hatch partially only when the request allows partial hatches.
4. Server deducts once, rolls each pet, applies variant rolls, applies hatch enchants/auto-delete, grants pets through `PetGrantService`, increments stats, and returns a batch result.
5. Client plays one animation for the whole batch using the returned egg visual contract and result list.

The current spam bug should be fixed by a server-side per-player hatch lock. Cooldown should begin when the request is accepted, and the player should not be able to start another hatch until the server has finished validation/grants and the configured lock window has elapsed.

## Feature Buckets

Necessary:

- Server batch hatching for dynamic `1..99` counts.
- Server-side hatch lock and cooldown race fix.
- Config-driven hatch limits with max count, partial-hatch policy, required unlocks, and hotkey/button labels.
- Batch currency/storage validation before rolling.
- Batch result payload for animation, stats, auto-delete, and errors.
- Egg animation uses the authored egg model/anchor, not a generic icon.
- Tests for too-far, insufficient funds, insufficient storage, rapid repeat, single hatch, and multi-hatch.

High priority:

- Auto-hatch as a server-authorized client loop with stop reasons.
- Auto-delete UI for rarity/family/variant using the existing server filter foundation.
- Hatch UI near eggs: requested count selector/input, Hatch, Auto, Golden/Charged toggles where unlocked.
- Fast/skip/silent hatch settings.
- Special hatch fanfare rules by rarity/trait.
- Hatch history/debug panel for admin testing. First server/admin snapshot exists; future polish can make it a richer visual panel instead of a text result.

Config and balancing:

- `configs/egg_system.lua` should define max hatch count (`99`), partial hatch policy, lock/cooldown windows, animation policy, auto-hatch loop interval, and default UI/hotkeys.
- `configs/pets.lua` egg source entries should define base cost, currency, unlock/area, pet table, variant rolls, golden/charged modifiers, and visual model policy.
- `configs/upgrades.lua` / future monetization config can grant max requested hatch count, auto-hatch, fast hatch, skip hatch, luck, golden/rainbow chance, and huge/secret luck modifiers.

## Comprehensive Implementation Checklist

Server pipeline:

- Add a canonical `EggHatchService` or refactor `EggService` into clearly separated helpers: validate request, resolve count, charge currency, roll pets, grant pets, build response.
- Replace legacy `purchaseType` strings with `{ requestedCount, options }` while preserving a temporary compatibility adapter for current UI/tests.
- Add per-player hatch lock state with accepted-at time, active request id, and release timing.
- Make hatch lock cover the whole server transaction so rapid `E` presses cannot create invisible hatches.
- Add consistent result envelopes: `{ ok = true, eggId, requestedCount, hatchCount, totalCost, currency, results, animation, autoDeleted, stopReason }` and `{ ok = false, code, message, details }`.
- Support partial hatching: requested `99`, affordable/storable `N`, hatch `N` when `allow_partial = true`; otherwise reject.
- Validate distance using `EggWorldQuery` and authored `EggStand` anchors.
- Validate area/zone unlocks for eggs if configured. First-pass counter/stat unlock requirements are enforced through `egg_sources.<id>.unlock_requirement`; richer area/zone prerequisite checks can build on the same server gate.
- Validate storage against stackable vs unique pet storage rules.
- Deduct total currency once per batch with economy source metadata such as `egg_hatch_batch`.
- Roll each hatch independently using current pet + variant + luck/enchant logic.
- Apply hatch-time enchants only through `PetGrantService`.
- Apply auto-delete before inventory write, preserving protected rarity rules.
- Increment `eggs_hatched` by actual hatch count.
- Return per-result metadata for rarity, variant, unique id, serial, auto-delete status, and display names.
- Add admin/server utility to simulate hatch batches without client animation. First-pass `EggService:SimulateHatchBatch`, admin panel button, and Studio smoke now exist.

Config:

- Add `egg_system.hatching.max_count = 99`.
- Add `egg_system.hatching.allow_partial = true`.
- Add `egg_system.hatching.default_requested_count = 1`; per-player selected-count persistence now lives under `Settings.AutoSystems.hatch.selected_count`.
- Add `egg_system.hatching.cooldown_seconds`, `lock_release_policy`, and `auto_loop_delay`.
- Add `egg_system.hatching.compat_purchase_types` for temporary `"Single"`, `"Triple"`, and `"Auto"` mapping during migration.
- Add `egg_system.ui.hatch_controls` for button visibility, labels, count selector, and hotkeys.
- Add `egg_system.animation` for show/skip/silent/special-reveal rules, speed multipliers, and max supported count.
- Extend config validation for max count, partial policy, animation max, and hatch-control fields.
- Cross-reference hatch special rarity and auto-delete filter ids against `configs/pets.lua` so typoed config fails at startup instead of silently hiding UI/filter options.
- Add shop/entitlement stub config for max hatch count, auto hatch, fast hatch, skip hatch, golden mode, charged mode, and luck sources.

Client UI:

- Replace single `E` behavior with a hatch controller that tracks selected/requested count. First-pass count persistence, typed input, and direct button controls are in place.
- Add near-egg controls for Hatch, Auto, selected count, and future mode toggles.
- Add keyboard support that remains simple: `E` hatch selected count; optional key for auto hatch.
- Disable/gray controls while the server hatch lock is active.
- Show exact stop reasons: no funds, no storage, too far, locked area, on cooldown, feature locked.
- Add auto-hatch state UI with visible running/stopped reason.
- Add auto-delete filter UI backed by existing server settings: rarity, pet family, variant, protected tiers. First-pass protected tier display and replicated saved-filter state are in place; future polish can improve layout/education.
- Add settings for show hatch, skip hatch, silence hatch, and fast hatch once entitlement stubs exist. First-pass persistent mode settings and help text exist, and Show Hatch now works as a default-on free presentation preference. Future polish should make locked/unlocked ownership more explicit.

Animation:

- Feed `EggHatchingService` a list of `1..99` result entries.
- Use the authored egg visual from the current `EggStand`/world model when available, including rock-style placeholder eggs.
- Keep fallback generated egg visuals for synthetic maps.
- Support dynamic count layouts up to `99`.
- Add stronger reveal metadata/effects for protected/special tiers when hatch animation is shown. Skip Hatch suppresses the hatch animation entirely at both interaction and animation-service boundaries; Silent Hatch suppresses audio while config can decide whether special visual-only world FX still plays.
- Include per-result rarity/variant colors and special effects.
- Ensure animation completion/reentry does not control server correctness; it only controls client presentation.
- Keep animation presentation choices configurable: grid layout sizes/padding, authored egg scale, reveal badges, special glow/backdrop, result stacking, and future special effects should live in config rather than hardcoded UI constants.
- Fast Hatch speed should remain a config value, not a hardcoded client multiplier; current validation requires it to be positive and no slower than normal speed.

Auto hatch:

- Implement auto hatch as a client loop that repeatedly asks the server while the same egg remains valid.
- Give each auto session a token/session id so stale responses do not restart a stopped loop.
- Stop on no funds, no storage, too far, egg changed, area locked, server error, or manual cancel.
- Use the selected requested count; default can be max allowed/requested count.
- Respect hatch lock and server cooldown instead of trying to time it only on the client.

Shop and entitlement stubs:

- Add a server-side entitlement resolver that initially reads dev/test config and player attributes/profile settings. First-pass `HatchEntitlementService` now exists.
- Stub entitlements for `max_hatch_count`, `auto_hatch`, `fast_hatch`, `skip_hatch`, `golden_mode`, `charged_mode`, `luck_bonus`, `secret_luck_bonus`. These now resolve through `HatchEntitlementService`; future work can add player-facing shop purchase flows on top of the same resolver.
- Do not require the shop UI to exist yet; expose admin/dev commands or config flags to toggle entitlements for testing. The first admin panel controls now exist, and future shop code should call `HatchEntitlementService` instead of hardcoding egg behavior.
- Later shop/monetization should call the same entitlement resolver, not change egg code.

Testing:

- Unit/config tests for hatch max count relationships, animation capacity, UI button config, partial count, cost math, and invalid config. First-pass `ConfigLoader.spec` coverage exists for the config-shape pieces; service smokes cover partial count and cost math.
- Studio smoke: far hatch rejects.
- Studio smoke: single hatch succeeds and saves.
- Studio smoke: rapid `E` returns cooldown/locked and never creates invisible hatches.
- Studio smoke: requested `99` with limited funds hatches affordable count.
- Studio smoke: requested `99` with limited storage hatches storable count.
- Studio smoke: auto-delete prevents inventory writes but increments hatch stats.
- Studio smoke: auto hatch stops on no funds/storage/too far.
- Studio smoke: authored egg animation payload names/uses the current rock egg.
- Studio smoke: configured egg unlock requirements reject below the threshold and hatch once the counter/stat requirement is met. `EggUnlockSmoke` covers the first counter-backed path.
- Studio smoke: admin hatch entitlement controls can lock/unlock/reset shop stubs and max hatch count.
- Studio smoke: no-mutation hatch simulation returns costs/counts/results without changing currency, inventory, or hatch stats.
- Studio smoke: near-egg panel reports effective max hatch entitlement and locked Auto state before the server request. `EggProximitySmoke` covers this first Max/Auto entitlement UI contract.
- Studio smoke: hatch animation debug state exposes configured grid layout and special glow pulse metadata. `EggAnimationContractSmoke` covers the current client-side contract.
- Studio smoke: Fast/Silent hatch timing metadata matches config. `EggAnimationContractSmoke` covers the current client-side timing contract.
- Studio smoke: maximum `99`-egg authored animation fits on the resolved animation viewport. `EggAnimationMaxBatchSmoke` covers the compact `10x10` contract and authored visual use.
- Regression: existing egg proximity, pet grant, pet index, achievements, and leaderboards still pass.

Documentation:

- Update current status after each major slice.
- Keep `EGG_SYSTEM_PLAN.md` current as decisions firm up.
- Keep `docs/EGG_AUTHORING_AND_ADMIN_TESTING.md` current when egg authoring, hatch entitlement, or smoke-test workflows change.

Later polish:

- Area-specific currencies/materials for eggs.
- Egg mastery or hatch milestones.
- Pity/mercy counters if desired for event/secret balancing.
- Public hatch announcements for rare tiers.
- Party/shared hatch visibility.
- Premium/event eggs with stricter odds disclosure and no hidden client-side luck drift.

## Implementation Order

1. Harden current single hatch: server lock, consistent error response, current authored egg visual payload.
2. Replace `purchaseType` strings with dynamic requested counts and server batch result.
3. Add selected-count UI and batch animation for `1..99`.
4. Add auto-hatch loop with stop reasons and server/session guard.
5. Add full auto-delete/filter UI and hatch settings.
6. Add golden/charged mode toggles and balance hooks.
7. Add smoke tests and admin tools for every mode. First-pass admin hatch entitlement controls are in place; keep expanding coverage as future hatch settings become real shop/upgrades.

## Open Questions

- Should the default selected count be `1`, player preference, or max affordable/storable up to max allowed?
- Should multi-hatch count entitlement default to `99` during template development, then be tuned later by game-specific config/shop?
- Resolved: Golden and Charged mode have first-pass config/server/client/test paths. Balance values remain template defaults.
- Resolved: Skip Hatch is specifically an animation-suppression preference for auto-hatching and should not be overridden by special hatch outcomes. Special hatches can still carry reveal metadata and stronger effects when animations are enabled.
- Should area currencies replace coins/crystals entirely per area, or should core currency stay global with area materials as side currencies?
