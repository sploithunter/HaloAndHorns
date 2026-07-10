# Ranked Architecture Findings

## Executive verdict

The repository has substantial configuration-driven and event-driven infrastructure, but those systems are not exclusive. Newer code generally follows the desired design while older imported or compatibility code remains live beside it. The biggest architectural risk is therefore **parallel paths**: a correct boundary exists, but a feature can bypass it without a failing test.

The recommended strategy is evolutionary:

1. add architecture fitness checks with a shrinking legacy allowlist;
2. make existing authoritative paths truly exclusive;
3. migrate the highest-risk bypasses in small PRs;
4. remove compatibility paths only after parity tests pass.

## Findings at a glance

| Rank | Severity | Deviation | Principles affected |
|---|---|---|---|
| 1 | Critical | Network configuration is not the runtime source of truth | Configuration, modular reuse |
| 2 | Critical | Service startup and pet runtime use parallel lifecycle systems | All three |
| 3 | High | Creation and mutation spines are documented but bypassable | Modular reuse, configuration |
| 4 | High | Fixed time is still used to synchronize readiness and completion | Event-driven sequencing |
| 5 | High | Config schemas and generated registries cover only part of the content surface | Configuration |
| 6 | Medium–High | UI, icon, action, and effect construction remains fragmented | Configuration, modular reuse |

## 1. Critical — networking has two sources of truth

### Intended contract

- `configs/network.lua` calls itself the single source of truth for client/server communication.
- `docs/FOUNDATION_AND_REQUIREMENTS.md` FR-X-NET-1 requires new packets to be declared in `network.lua` with direction, validation, rate limit, and handler metadata.
- `docs/IMPLEMENTATION_PLAN.md` repeats the same standard recipe and prohibits manually created remotes.

### Observed deviation

- `src/Client/init.client.lua` explicitly says the old `NetworkBridge` path was removed.
- `src/Shared/Network/Signals.lua` declares 98 `Net:RemoteEvent(...)` values in code.
- At least eight server remotes are created manually outside that registry, including trade, egg, potion, automation, Game API, and Studio smoke-test channels.
- Services connect their own handlers directly, so validation and rate limiting depend on each service implementation rather than one generated router.

### Impact

- Packet names, directions, schemas, handlers, and rates can drift independently.
- Security requirements cannot be proven from the manifest.
- Adding a network action requires multiple code edits instead of one declaration.
- Test-only and production channels do not share one permission model.
- The dead `NetworkBridge` and active `Signals` system make architectural documentation misleading.

### Recommended correction

Retain the current `sleitnick/Net` transport, but generate the signal registry, server router, payload validators, rate-limit registration, and client wrappers from one data-only network manifest. Migrate direct handlers domain by domain, then remove the unused bridge.

## 2. Critical — service lifecycle and pet runtime are split

### Intended contract

`ModuleLoader` is supposed to own service construction, dependency ordering, initialization, and startup. Boot dependencies are supposed to be declared in `configs/boot.lua` and awaited through latched milestones.

### Observed deviation

- `EggSpawner` is manually required and initialized after a one-second sleep.
- `EggService` is manually required and initialized after a 0.1-second sleep.
- Several `.server.lua` files auto-run outside `ModuleLoader`.
- Thirty-six service files reference the global `_G.RBXTemplateServices` locator; injected dependencies and runtime global discovery coexist.
- `PetHandler.server.lua` registers with `PetEquipmentBridge.server.lua` through `_G` callbacks and recursively sleeps until the bridge exists.
- The pet stack maintains profile data, replicated folder mirrors, temporary equip folders, model attributes, control boxes, and global Workspace/ServerScriptService values.
- `PetHandler.server.lua` contains four perpetual timing loops for float/rotation state. `PetCharacterAttachments.server.lua` adds another per-player 20 Hz attachment loop with hardcoded coordinates.

### Impact

- Startup order is implicit and timing-sensitive.
- The service dependency graph is incomplete, so boot validation cannot catch all races.
- Equipment and pet presentation have multiple competing representations.
- Global callbacks make ownership, cleanup, tests, and hot reload difficult.
- Hardcoded formation counts and attachment coordinates bypass `configs/pet_follow.lua`.
- Always-running loops consume server work even though the newer service-owned movement path exists.

### Recommended correction

Create one loader-managed `PetSpawnService` that subscribes to an authoritative `EquipmentChanged` event and owns spawn, despawn, and rebuild. Convert compatibility scripts into modules or delete them after parity testing. Add per-player latches for profile, character, equipment, and pet readiness. Eliminate `_G` callbacks and legacy position/float values.

## 3. High — creation and mutation spines are bypassable

### Intended contract

- `PetGrantService` is documented as the sole boundary that turns a selected pet outcome into durable inventory.
- `RewardService` describes itself as the single terminal that makes a reward bundle real.
- `EconomyService` is documented as the owner of currency mutation and ledger metadata.
- `FireGameEvent` is the shared event publication path that also drives server observers and configured world sound.

### Observed deviation

- `FusionService` mints its output through `InventoryService:AddItem(player, "pets", ...)` and reconstructs rollback pets the same way.
- The fused record supplies only a subset of normal pet metadata, bypassing configured rarity, progression, enchant, provenance, and serial initialization.
- There are 24 direct `DataService:AddCurrency`, `RemoveCurrency`, or `SetCurrency` calls outside `EconomyService`.
- `RewardService` itself writes currency through `DataService` rather than the economy boundary.
- Several services implement their own spend/grant/refund transactions.
- Three `DropService` paths fire `Signals.GameEvent` directly instead of calling `FireGameEvent`, bypassing server taps and world-sound behavior.

### Impact

- The shape and side effects of a pet depend on who created it.
- Economy notifications, ledgers, source metadata, rollback, and future modifier behavior vary by caller.
- A documented “single path” cannot be trusted as an invariant.
- Fixes at the intended boundary do not automatically fix bypass callers.

### Recommended correction

Separate creation from transfer:

- `PetMintService`/`PetGrantService` creates new configured pets.
- `PetTransferService` moves an existing exact record during trade or escrow.
- `InventoryTransactionService` atomically consumes and produces records for fusion/crafting.
- `EconomyService:Transact` owns debit, credit, refund, notification, and ledger behavior.
- `RewardService` calls the economy transaction API.
- The event bus becomes the only public gameplay-event publisher.

## 4. High — fixed time still synchronizes work

### Intended contract

`docs/BOOT_ORCHESTRATION.md` defines a strict invariant: a subsystem that needs another subsystem's output awaits a milestone, not a timer, symptom poll, or guessed delay.

### Observed deviation

Examples that clearly use time as synchronization rather than game state:

- server startup sleeps before initializing egg systems;
- client startup waits fixed intervals before building UI and initializing egg interaction services;
- `EggSpawner` polls for spawn points in 0.5-second increments;
- `PetHandler` recursively waits for a global bridge callback;
- egg hatching uses `shakeWaitDuration`, `staggerDelay`, reveal duration waits, and `completionWait` to infer that all child animations completed;
- an inventory context menu blocks three seconds before installing its outside-click listener, then starts a second three-second close timer;
- several admin/UI systems wait for signals or replicated state instead of observing the relevant attribute or child event.

The static audit found 232 runtime `task.wait`/`task.delay` calls after excluding obvious test files. That number is a search inventory, not a claim that all 232 are violations.

### Impact

- Faster or slower asset loading changes behavior.
- Animation or configuration changes silently invalidate guessed completion times.
- Races can reproduce only under particular server/client timing.
- Tests must sleep and hope instead of awaiting a deterministic completion.

### Recommended correction

Introduce a small sequence primitive whose steps resolve from actual completion signals. Use `Tween.Completed`, `Sound.Ended`, completed preload calls, child/attribute signals, and latched readiness. Model legitimate cooldowns, schedules, and watchdogs as explicit `startsAt`/`endsAt` state that emits expiry or timeout events.

## 5. High — configuration validation and generation are partial

### Observed deviation

- The repository contains 90 config modules, while `ConfigLoader:ValidateConfig` has focused branches for 28 names.
- Every other config reaches the default `return true` path unless it validates itself elsewhere.
- `ConfigLoader.lua` is roughly 5,000 lines of handwritten per-config validation and fallback behavior.
- If the `Configs` folder is absent, `ConfigLoader` substitutes a large hardcoded simulator configuration containing generic currencies, items, enemies, and UI.
- New saved fields still require editing the handwritten profile template and migration table.
- Runtime modules often require config modules directly, while others go through `ConfigLoader`, so caching, validation, and error behavior are inconsistent.

### Impact

- “Config as code” can mean unvalidated data rather than a safe extension surface.
- Adding a config type requires editing a central code switch.
- Config mistakes may pass CI but fail in Studio boot or a downstream service.
- Hardcoded fallbacks can boot the wrong game instead of failing loudly.

### Recommended correction

Create a schema registry covering every required config. Extract cross-config rules into pure schema modules shared by runtime and headless tests. Fail boot on missing/unregistered required configs. Generate stable IDs and typed accessors where repetition is otherwise unavoidable. Remove the generic runtime content fallback.

## 6. Medium–High — UI, icon, action, and effect construction is fragmented

### Observed deviation

- The client contains approximately 669 direct calls constructing common UI instances.
- `InventoryPanel.lua` is roughly 8,000 lines and constructs cards, actions, context menus, close controls, tooltips, dialogs, and timing behavior directly.
- A reusable `CloseButton` component exists, but major panels still build custom close buttons.
- Icon and color metadata exists partly in configs and partly as local tables or asset IDs inside controllers and services.
- `PowerService` uses a large effect-family `if/elseif` dispatcher; `EnemyService` has another aura-family dispatcher.
- Adding a new effect or action family can require changes to config validation, dispatch, FX mapping, UI description, and tests.

### Impact

- Visual and interaction fixes must be repeated across panels.
- Content additions are not consistently config-only.
- Large controllers mix state, domain rules, rendering, networking, and animation.
- Similar concepts can behave differently depending on their UI or service origin.

### Recommended correction

Create shared icon, action, item-card, panel, and context-menu registries/components. Split large panels into state/controller and renderer modules. Replace effect-family conditional chains with registered handler modules selected by validated config keys.

## Existing foundations worth preserving

The audit found several strong implementations that should be extended rather than replaced:

- `BootReadiness` and the boot dependency graph provide the correct latch model.
- `ConfigLoader` already fails loudly for the focused schemas it understands.
- `PetGrantService`, `RewardService`, `EconomyService`, and `FireGameEvent` already define most of the desired boundaries.
- `ModifierPipeline` supplies one ordered path for derived values.
- `WorldBindingService` and synthetic/authored map parity follow the configuration-first design.
- Pure shared game modules and headless tests make incremental migration practical.
- Generated power-icon and pet-thumbnail registries demonstrate that repository-owned code generation is already an accepted pattern.

## Root cause

The project evolved by layering improved infrastructure over imported and compatibility systems. New paths were added, but old paths were stabilized instead of retired, and CI did not enforce exclusivity. The architecture therefore exists as guidance rather than as a property of the build.
