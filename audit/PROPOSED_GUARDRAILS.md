# Proposed Architecture Guardrails

## Purpose

The repository already documents the intended architecture, but documentation has not prevented alternate paths. These guardrails turn the rules into CI-enforced fitness functions.

The first implementation should use a checked-in allowlist for existing debt. CI rejects new violations immediately, and migration PRs remove allowlist entries until the target rule becomes absolute.

## Guard A — remote construction ownership

### Target rule

Only the generated network registry may construct `RemoteEvent` or `RemoteFunction` instances or call `Net:RemoteEvent`/`Net:RemoteFunction`.

### Check

Scan runtime source for:

- `Instance.new("RemoteEvent")`;
- `Instance.new("RemoteFunction")`;
- `Net:RemoteEvent(`;
- `Net:RemoteFunction(`.

Reject matches outside generated network files. Studio/test channels must still be declared in the manifest with an environment policy.

## Guard B — network manifest completeness

### Target rule

Every packet declares direction, schema, rate limit where mutating, authorization policy, environment, and handler/topic.

### Check

Load the manifest headlessly and validate:

- unique stable names;
- valid direction;
- resolvable handler identifiers;
- nonzero rate limits on client-origin mutations;
- known schema types and bounds;
- no production exposure for Studio/test packets;
- generated output matches the manifest.

## Guard C — gameplay-event publication

### Target rule

Only `GameEventBus` may send the gameplay event network packet or invoke global event reactions.

### Check

Reject direct `Signals.GameEvent:FireClient`, `FireAllClients`, or local dispatcher calls outside bus adapters and tests.

## Guard D — pet record creation

### Target rule

Only `PetMintService`/`PetGrantService` may add a newly created pet record. `PetTransferService` may move an existing record through the transaction API.

### Check

Reject feature-service calls matching pet-bucket `AddItem` or direct `Inventory.pets.items` assignment outside:

- pet mint;
- pet transfer;
- migrations/backfills;
- narrowly scoped tests.

Add an integration assertion that every minted pet contains all required config-derived metadata for its rarity and traits.

## Guard E — currency mutation ownership

### Target rule

Feature services call `EconomyService:Transact`; only the economy/persistence implementation, migrations, and explicit test restore adapters call lower-level currency primitives.

### Check

Reject `DataService:AddCurrency`, `RemoveCurrency`, or `SetCurrency` calls outside the approved owners. Validate that every transaction supplies a nonempty source/sink reason.

## Guard F — reward boundary

### Target rule

Configured reward bundles become real through `RewardService` only.

### Check

For services named as reward sources in config, require use of `RewardService:Grant`. Add failure-injection tests proving a failed grant does not consume a claim or leave an unreverted cost.

## Guard G — config registration and schemas

### Target rule

Every required `configs/*.lua` module is registered with a schema and version policy.

### Check

- Discover config files.
- Compare them with the schema registry.
- Fail on missing or duplicate registration.
- Load every config headlessly.
- Run the same pure schemas used at runtime.
- Run cross-reference validation after individual shape validation.

Generated configs may declare their generator and source manifest instead of handwritten ownership. CI runs generator check mode.

## Guard H — synchronization waits

### Target rule

Boot and readiness code cannot use time to infer dependency completion.

### Check

Initially scan high-risk paths:

- `src/Server/init.server.lua`;
- `src/Client/init.client.lua` boot sections;
- service `Init`/`Start` methods;
- pet compatibility/startup scripts;
- boot loader/orchestrator consumers.

Reject `task.wait`/`task.delay` unless the line is allowlisted with one of a small set of reviewed purposes such as `frame_budget`, `periodic_telemetry`, `deadline`, or `watchdog`.

Longer term, replace text comments with wrapper APIs so intent is structural:

- `Scheduler.every`;
- `Deadline.after`;
- `FrameBudget.yield`;
- `Sequence.timeout`.

## Guard I — hardcoded asset and content IDs

### Target rule

Consumed Roblox asset IDs and content identifiers are traceable to configs or asset manifests.

### Check

Extend the existing asset audit to client and server runtime source. Allowlist engine-provided textures and explicit test placeholders. Reject new unexplained numeric asset IDs in feature code.

## Guard J — service composition

### Target rule

Runtime services are registered through the composition root and receive dependencies through the loader or event subscriptions.

### Check

- Reject new `_G.RBXTemplateServices` references.
- Reject new `_G` callbacks used for service coordination.
- Discover `*Service.lua` modules and compare with registration or an explicit non-runtime/test list.
- Reject auto-initializing service modules outside approved entrypoints.

## Guard K — shared UI construction

### Target rule

Feature panels use shared chrome, icon, action, context-menu, and item-card primitives.

### Check

This guard should start as metrics rather than a hard ban:

- report direct common-control `Instance.new` calls by file;
- fail only when the count increases in migrated panels;
- ratchet panel-specific budgets downward as components are adopted;
- reject direct close-button asset IDs when `CloseButton` is available.

## Suggested implementation

Add a read-only repository script such as `scripts/architecture_guard.py` and a configuration file such as `scripts/architecture_allowlist.json`.

The script should:

1. run deterministic searches;
2. normalize paths and line-independent signatures where practical;
3. compare findings with the allowlist;
4. report new, removed, and stale entries;
5. fail on new or stale entries so allowlists shrink with code changes;
6. expose focused modes for local work (`--network`, `--mutations`, `--timing`, `--configs`, `--ui`);
7. avoid rewriting files.

Use AST-aware parsing later if text checks produce too many false positives. Simple checks are valuable immediately because the highest-risk patterns are explicit and rare.

## CI order

Recommended fast-gate order:

1. generated-artifact drift checks;
2. architecture guard;
3. Selene;
4. StyLua check;
5. Rojo build;
6. headless tests.

Running cheap structure checks first gives fast, actionable failures.

## Exception policy

An exception must state:

- exact path and pattern;
- owning subsystem;
- why the canonical path cannot be used;
- whether it is permanent or migration debt;
- linked issue/PR for removal when temporary.

“Legacy,” “working game pattern,” or “easier here” is not sufficient justification by itself.

## Target end state

The guardrail allowlist should eventually contain only platform-boundary exceptions and explicit test adapters. Normal game features should have no reason to bypass the generated network layer, event bus, transaction services, config schemas, or shared UI registries.
