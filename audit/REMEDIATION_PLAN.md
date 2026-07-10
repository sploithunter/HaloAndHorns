# Architecture Remediation Roadmap

## Goal

Make the three architecture principles properties of the build:

- configuration declares content and extension choices;
- each operation type has one authoritative public boundary;
- readiness and completion are event-driven and testable.

This is not a rewrite. Existing good services become the migration destinations, compatibility aliases preserve behavior temporarily, and each phase lands through small PRs.

## Sequencing rules

1. Add guardrails before large migrations so new debt stops accumulating.
2. Preserve network names and save shapes while changing ownership behind them.
3. Separate “mint a new record” from “transfer an existing record.”
4. Replace synchronization waits with completion contracts before changing animation timing.
5. Delete legacy paths only after parity and live smoke tests pass.
6. Keep template infrastructure and game-specific migration PRs separate according to `CODEOWNERS`.

## Phase 0 — restore the gate and add ratcheting fitness checks

### Work

- Repair the current formatting baseline in a dedicated PR so `mise run ci` completes.
- Add an `architecture-check` task to CI.
- Seed explicit allowlists for existing manual remotes, mutation bypasses, boot waits, global locators, and unregistered configs.
- Make the check reject any new entry not already allowlisted.
- Reduce the allowlist with every subsequent migration PR.

### Exit criteria

- `mise run ci` reaches and passes lint, format, Rojo build, and headless tests.
- Adding a new manual remote, direct pet mint, direct feature-level currency mutation, or boot synchronization sleep fails locally and in GitHub Actions.

## Phase 1 — one generated network and event registry

### Design

Keep `sleitnick/Net` as the transport. Replace the hand-maintained registry with generated/runtime-built plumbing from a data-only manifest.

Each packet declaration should include:

- stable name;
- direction;
- payload schema and range/ownership validators;
- rate limit;
- handler or event topic;
- authentication/authorization policy;
- environment policy (`production`, `studio`, `test`);
- optional response packet.

Generate or build:

- the `Signals` registry;
- server handler routing;
- validation and rate-limit setup;
- typed/stable packet identifiers;
- client request and subscription wrappers;
- documentation/debug introspection.

### Migration order

1. Read-only/status packets.
2. Economy and inventory mutations.
3. Zones, settings, and progression.
4. Combat/pet replication packets.
5. Trade, monetization, admin, and test-only channels.
6. Egg legacy remote functions.

Use temporary aliases so existing clients continue to function during migration.

### Gameplay event bus

- Promote `FireGameEvent` into a typed `GameEventBus` with one `Publish` API.
- Generate/validate event names and payload expectations from the event config.
- Preserve server taps, world sound, local reactions, and network fan-out as adapters.
- Migrate direct `Signals.GameEvent` calls.

### Exit criteria

- Only the generated network module constructs remotes.
- Every mutating client packet has a declared rate and validator.
- Only `GameEventBus` publishes gameplay events.
- The legacy `NetworkBridge` and direct service remotes are removed.

## Phase 2 — one service and player lifecycle

### Work

- Convert auto-running service scripts into loader-managed modules.
- Register `EggService`, `EggSpawner`, world-structure creation, pet compatibility, pet spawn, and equipment integration through `ModuleLoader`.
- Replace runtime `_G.RBXTemplateServices` lookups with declared dependencies where acyclic.
- For cross-domain reactions that would create cycles, subscribe to the event bus instead of locating and calling a service globally.
- Introduce per-player latches/events for:
  - profile loaded;
  - character ready;
  - replicated inventory/equipment ready;
  - UI ready;
  - pets spawned.

### Pet runtime consolidation

- Create `PetSpawnService` with `SpawnEquipped`, `Despawn`, and `Rebuild` operations.
- Make `InventoryService` emit one `EquipmentChanged` event after an authoritative commit.
- Treat profile inventory/equipment as state; replicated folders and model attributes are projections.
- Move formation and animation inputs to `configs/pet_follow.lua` and shared pure modules.
- Remove temporary equip folders, control-box compatibility, global callbacks, global float values, and legacy attachment loops after parity tests.

### Exit criteria

- One composition root owns every service.
- Service readiness has a declared dependency or event.
- No pet service registers or calls a `_G` callback.
- Equipping once causes one authoritative rebuild.
- Legacy pet loops and attachment scripts are deleted.

## Phase 3 — exclusive mutation and transaction boundaries

### Economy

Add `EconomyService:Transact` with:

- one or more debits/credits;
- source/sink metadata;
- validation and caps;
- atomic precondition checking;
- rollback behavior;
- ledger entries;
- currency update events;
- an auditable result object.

`DataService` retains the private persistence primitive. Feature services stop calling it directly.

### Rewards

- Route reward currencies through the economy transaction API.
- Normalize item, pet, effect, XP, and capacity results before applying them.
- Fail the whole grant or return an explicit partial/failure result; do not silently record ungranted entries.
- Persist or centralize the grant audit according to the desired durability policy.

### Pets and items

- `PetMintService` creates a new configured pet, applying rarity, variant, serial, progression, enchants, provenance, and defaults.
- `PetTransferService` moves an existing exact record without rerolling or reminting it.
- `InventoryTransactionService` stages consume/produce operations and commits once.
- A config-backed `ItemFactory` normalizes non-pet item records by bucket schema.

### First migration target: fusion

Fusion should:

1. validate both source pets and the configured recipe;
2. build the output through `PetMintService` with the chaotic element override;
3. stage both removals and the output add;
4. commit atomically;
5. publish one success event after commit.

### Exit criteria

- Feature services do not call currency persistence primitives directly.
- New pets cannot enter inventory without the mint boundary.
- Trade transfers preserve the exact record.
- Fusion failure conserves both ownership and metadata.
- Reward and economy audits agree on every grant.

## Phase 4 — completion-driven sequences

### Sequence primitive

Add a small cancellable sequence/promise abstraction supporting:

- a step that resolves/rejects explicitly;
- parallel join/all;
- cancellation and generation ownership;
- timeout as a named failure event;
- cleanup through a maid/resource owner;
- deterministic test fakes.

### Migration order

1. Remaining boot and service-start sleeps.
2. Pet/equipment readiness polling.
3. Egg hatch shake, flash, reveal, stacking, restore, and cleanup.
4. Menu/UI initialization and context-menu cleanup.
5. Remaining attribute/folder polling that has an event source.

### Event sources

- `Tween.Completed` for tweens;
- `Sound.Ended` for playback;
- return/completion of `PreloadAsync` for assets;
- `ChildAdded` or attribute/property signals for replication;
- explicit `Finished` from composite effects;
- timestamps plus an expiry event for cooldowns and buffs.

### Exit criteria

- Boot paths contain no sleeps used for dependency ordering.
- Hatch completion occurs when every active reveal completes, independent of configured duration changes.
- Tests await named completion rather than sleeping.
- Watchdog timeouts are observable failure paths, not silent cleanup guesses.

## Phase 5 — complete config schemas and reusable registries

### Schema registry

- Register every required config and its version.
- Use reusable schema primitives for type, range, enum, array/map, ID pattern, and optional/default rules.
- Extract cross-config checks into pure modules used by both runtime boot and headless CI.
- Reject missing schema registrations and unknown required configs.
- Remove generic hardcoded game-content fallback behavior.

### Generated artifacts

Use Lune or another repository-owned generator to produce:

- network identifiers and wrappers;
- gameplay-event identifiers;
- icon and asset registries;
- stable content ID accessors where helpful;
- validation lookup tables or docs.

CI should regenerate into a temporary location or run a `--check` mode and fail on drift.

### UI and actions

Create shared building blocks:

- `Icon` resolver for image/emoji/fallback policy;
- `ActionButton` bound to a registered action key;
- `ItemCard` renderers selected by bucket/item kind;
- `Panel` and `CloseButton` chrome;
- `ContextMenu` with event-driven dismissal;
- common notice/confirmation/quantity flows.

Split `InventoryPanel` into:

- inventory view model and selectors;
- category/item renderers;
- pet-card renderer;
- item action registry;
- tooltip/detail renderer;
- delete/equip/consume controllers.

### Effect handlers

- Replace large family conditional chains with handler modules registered by stable keys.
- Validate every configured family against that registry.
- Reuse shared effect/status primitives where player powers, pet auras, and enemy abilities overlap.

### Exit criteria

- Every config has a runtime and headless schema path.
- A missing config stops boot rather than loading unrelated fallback content.
- New normal icons/actions/items are config or manifest additions.
- High-level panels no longer recreate shared chrome and interaction behavior.
- Adding an effect family requires one handler registration plus config, not edits across several conditional chains.

## Validation strategy

Every migration PR should include the narrowest applicable checks:

- headless pure-core tests;
- architecture fitness checks;
- before/after parity snapshots;
- Studio command-bus integration tests against authoritative state;
- one UI sanity path for visible interactions;
- save-shape conservation tests for pet/inventory changes;
- transaction failure injection for spend/grant/rollback paths;
- network tests for direction, validation, rate, ownership, and environment policy.

## Suggested PR slicing

1. Dedicated format-baseline cleanup.
2. Architecture fitness check with legacy allowlists.
3. Config schema registry foundation.
4. Network manifest generator and read-only packet migration.
5. Economy/inventory network packet migration.
6. Gameplay event bus and direct-send migration.
7. Player lifecycle latches and loader-owned egg startup.
8. Pet spawn service and equipment event.
9. Economy transaction API and reward integration.
10. Fusion transaction/pet-mint migration.
11. Hatch completion sequence.
12. UI component/action registry and inventory decomposition in several small PRs.

Shared infrastructure belongs on `template/*` branches; Pet Realm behavior/config migrations belong on `game/*` or `pet-realm/*` branches. Shared files such as `.mise.toml`, `docs/wiki/LOG.md`, and `CURRENT_STATUS.md` should be handled in small dedicated changes as required by the repository rules.

## Final acceptance criteria

- One generated remote-construction path.
- One gameplay-event publication API.
- One new-pet mint path and one existing-pet transfer path.
- One economy mutation/transaction path.
- No dependency-order sleeps in boot or player readiness.
- Every config registered and validated.
- Shared icon/action/item/UI factories are used by feature panels.
- Architecture allowlists are empty or contain documented platform-level exceptions only.
- `mise run ci` and the relevant Studio smoke suites pass.
