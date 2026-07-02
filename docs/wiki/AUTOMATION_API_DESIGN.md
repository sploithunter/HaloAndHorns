# Automation API Design

Status: draft (scaffold landed; runtime layers deferred)

## Problem

GUI-driven automation (computer-use / screen clicking) is slow and flaky. We
want to test and drive the game **below the UI**, calling the same code paths a
button would trigger — robustly, from a CLI/MCP or headless runner.

## The idea: one command boundary

Every gameplay action ("purchase upgrade", "hatch egg", "travel to zone") is a
named command. The GUI, the network layer, and automated tests are just
different *callers* of the same command set:

```
   GUI button        ─┐
   Network remote     ─┼─►  CommandBus:execute(context, name, args)  ─►  handler ─► service
   Automation / tests ─┘
```

This is the **Humble Object** pattern: the UI becomes a thin view that builds a
command and dispatches it; it holds no game logic. Tests drive *intents*, not
pixels.

### Two levels of success

The bus separates **dispatch** success from **domain** success:

| Field | Meaning |
|-------|---------|
| `envelope.ok == false` | the dispatch failed — `unknown_command`, `validation_failed`, `forbidden` (test-only), or `handler_error`. See `envelope.code`. |
| `envelope.ok == true`  | the handler ran; its return value is in `envelope.result`, which may itself be a domain envelope like `{ ok = false, reason = "insufficient_currency" }`. |

A failed *purchase* (insufficient funds) is a successful *dispatch*. This split
lets existing services — which already return `{ ok = ..., reason = ... }` —
become handlers with **zero changes**.

## Why this fits the existing codebase

The template already has the seam half-built:

1. **Action/transport split exists.** Services expose pure public methods that
   return typed envelopes (e.g. `UpgradeService:PurchaseUpgrade(player, id)`),
   and `_setupNetworkSignals()` is a thin RemoteEvent wrapper over them. The
   method *is* the humble object; the bus just unifies the wrappers.
2. **A service locator exists.** `_G.RBXTemplateServices:Get(name)` (set up in
   `src/Server/init.server.lua`) reaches any loaded service — so command
   handlers are thin adapters, and the automation driver can reach the bus.
3. **A test-driver precedent exists.** `StudioSmokeTestService` already exposes
   one `RemoteFunction` with an `action → handler` dispatch, Studio-gated. The
   CommandBus generalizes that into a first-class, game-agnostic API.

## Security & gating model

The boundary is also a trust boundary. Every dispatch carries a `context`:

- `origin` — `gui` / `network` / `automation` / `internal` (informational; the
  Network transport stamps `network`).
- `isTest` — gates `testOnly` commands.

Rules enforced:

- The **Network** `RemoteFunction` always sets `isTest = false`. A real client
  can never reach a `testOnly` command, regardless of payload.
- `GameAPIService:Execute(...)` (automation) defaults `isTest` to
  `RunService:IsStudio()` — so test-only setup commands work under the MCP
  harness but are inert in a live server.
- `testOnly` commands are also only **registered** when `RunService:IsStudio()`,
  so they don't exist in production at all (defense in depth).

## Character movement: pathfinding, not CFrame

CFrame teleport jumps put characters in unrealistic/invalid spots and can't
faithfully test proximity logic (egg approach, portal walk-up).

- **Traversal under test** → `Humanoid:MoveTo` + `PathfindingService`, or the
  Studio MCP's built-in `character_navigation` (moves the character to a
  position or instance with a speed multiplier).
- **Gotcha — "it cancels out":** in play-solo the player's control module
  re-issues `MoveTo` every frame and fights programmatic movement, stopping the
  character. To drive the *player*, disable controls during automated movement
  (`PlayerModule:GetControls():Disable()`) then re-enable — or drive an NPC
  test-double, which has no control module. The automation movement helper will
  encapsulate this.
- **CFrame is still allowed for setup only** — instantly staging the world
  before the behavior-under-test, never for the traversal being asserted.

## Verification model

- **State is the source of truth.** Assert on authoritative server state read
  back through the bus (currency, inventory, position, zone).
- **Screenshots are a backstop.** Use the MCP `screen_capture` to confirm the UI
  rendered / the player is visibly where expected — not for logic correctness
  (pixel diffing is brittle).

## Two test tiers

| Tier | Runner | Scope | Speed |
|------|--------|-------|-------|
| Pure logic | `mise run test-headless` (lune) | Roblox-API-free modules: the bus, command validation, formulas | instant, no Studio |
| Runtime / integration | Studio MCP (`execute_luau`, `character_navigation`, `screen_capture`) | real services, movement, replication, UI render | needs a Studio session |

A "CLI that bypasses the GUI" is honest only for the pure tier. Runtime commands
need a running game, so the CLI/automation channel for live tests is the **MCP**
talking to Studio; the bus is what makes both tiers exercise identical logic.

## What's built now

- `src/Shared/API/CommandBus.lua` — pure dispatcher: `register` / `registerMany`
  / `execute` / `has` / `list`, uniform envelope, arg validation, test-only
  gating, handler error capture, origin tracking. Roblox-API-free.
- `tests/headless/specs/command_bus.spec.luau` — 10 specs covering every
  dispatch path. Green under `mise run test-headless`.
- `tests/headless/run.luau` — extended with `loadModule("src/.../Foo.lua")` so
  specs can unit-test pure repo modules headlessly.
- `src/Server/Services/GameAPIService.lua` — **scaffold**: owns a bus, registers
  illustrative adapter commands (`economy.getUpgradeCost`,
  `economy.purchaseUpgrade`, `system.listCommands`, test-only
  `test.grantCurrency`), exposes the `GameAPICommand` RemoteFunction (clients)
  and `:Execute()` (automation). Not yet wired into the boot loader.
- `src/Shared/API/Navigation.lua` — pure movement core (planar/3D distance,
  arrival threshold, waypoint advance, stall detection). Headless-tested by
  `tests/headless/specs/navigation.spec.luau`.
- `src/Server/Services/AutomationService.lua` — Studio-gated test driver:
  `NavigateTo` (PathfindingService + `Humanoid:MoveTo` over the pure Navigation
  core, with stall detection), `TeleportForSetup` (CFrame staging only),
  `SnapshotState`/`RestoreState` (currency + inventory + position), and
  `GetPlayerState`. `RegisterInto(bus)` exposes these as test-only `automation.*`
  commands, so the harness drives movement/state through the same boundary.
  Runtime paths await live Studio verification (see the control caveat).

## Roadmap (deferred)

1. **Register `GameAPIService` + `AutomationService`** in
   `src/Server/init.server.lua` (Studio-gated for the latter) and verify boot
   against a clean Studio instance.
2. **Verify the runtime paths live**: `NavigateTo` (and resolve the player
   control-fight — client-side control disable or NPC proxy), snapshot/restore,
   and a full command round-trip via the MCP `execute_luau`.
3. **Migrate the command set**: register one command per existing action and
   route the GUI + `Signals` through the bus (UI becomes a thin view).
4. **Automation test suite**: rewrite the `tests/studio/*` smokes as command
   sequences driven via the MCP, asserting on bus-read state + screenshots.
5. **Determinism**: seeded RNG + frozen time affordances on `AutomationService`.
