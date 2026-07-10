# Architecture Principles Used by This Audit

## 1. Configuration first

Content and tuning belong in `configs/*.lua`. Runtime code should consume validated declarations instead of embedding game-specific IDs, names, icons, content tables, prices, odds, or adaptation choices.

Configuration may refer to a registered behavior key such as `heal`, `grant_pet`, or `open_panel`. The behavior implementation remains code. If a declaration would otherwise require repetitive plumbing, a repository-owned generator should produce the plumbing and CI should verify that generated output is current.

Adding a normal content entry should generally require:

1. a config or asset-manifest edit;
2. optional Studio marker/art placement;
3. no new feature-specific service branch.

## 2. One authoritative path

Each operation type needs a single public boundary. Examples:

- network packets are declared once and generated/routed consistently;
- gameplay events are published through one event bus;
- new pets are minted through one pet-mint boundary;
- existing pets move through one transfer/transaction boundary;
- rewards are granted through one reward terminal;
- currency mutation passes through one economy transaction service;
- UI actions and icons resolve through shared registries and components.

Lower-level persistence helpers may exist, but feature services should not call them directly. A boundary is not authoritative if bypassing it is normal or untested.

## 3. Event-driven sequencing

When operation B depends on operation A, B waits on A's actual completion signal or latched ready state. It does not sleep for an estimated duration and then assume A finished.

Preferred completion sources include:

- `BootReadiness` or another one-shot latch;
- `Tween.Completed`;
- `Sound.Ended`;
- completion of `ContentProvider:PreloadAsync`;
- `ChildAdded`, `AncestryChanged`, or attribute/property signals;
- a promise or sequence step resolved by the operation that owns the work.

## Legitimate time-based behavior

Time remains part of game state. These uses are allowed when modeled explicitly:

- cooldown or buff state represented by `startedAt`/`endsAt`;
- scheduled global events with explicit start and finish transitions;
- watchdog deadlines that produce a timeout event;
- periodic persistence, telemetry, or reconciliation;
- animation duration supplied as an input to an operation;
- frame-budget yielding that is not being used as a readiness signal.

The important distinction is that a duration defines state or policy; it does not secretly coordinate unrelated subsystems.

## Enforcement principle

Architecture rules must be executable. CI should reject new bypasses and maintain a shrinking allowlist for legacy debt. Documentation alone has not been sufficient to keep the repository on the intended paths.
