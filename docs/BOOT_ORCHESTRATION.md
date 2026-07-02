# Boot Orchestration — event-driven, gated startup

## Why this exists

Every boot race we've hit (pets not deploying, crystals only filling on the 30s safety-net) had the
same shape: a service started, needed something that wasn't ready yet, and instead of **waiting for
that thing** it did one of:

- `:Wait()` on a fire-once `BindableEvent` that had **already fired** → hang forever (PetHandler).
- poll an attribute on a timer, or
- `FindFirstChild(...)` and **abort** if missing (BreakableSpawner `_spawnLoop`).

That's timing-driven. A video game's startup should be **event-driven and gated**: if A depends on
B, A *awaits* B's "done" signal. The fast boot from the asset pre-bake didn't introduce these races —
it **exposed** latent ones by changing the timing they were silently relying on.

## The model

Two pieces: a race-free **latch primitive**, and a declarative **milestone graph**.

### 1. `BootReadiness` — the latch (src/Shared/Boot/BootReadiness.lua)

Named one-shot latches. The whole point is the second property below, which makes it impossible to
miss a signal:

- `BootReadiness.signal(name)` — mark a milestone done (idempotent; second call is a no-op).
- `BootReadiness.await(name, timeout?)` — **returns instantly if already signalled**, otherwise
  yields the calling thread until it is. Late subscribers never miss the event.

Pure Lua (coroutine-based), so it's unit-tested headless. In Studio it resumes waiters via
`task.spawn`; under the headless runner (no `task`) it uses `coroutine.resume`.

**Usage rule:** never `await` directly in a service's `Init`/`Start` — that would block the
ModuleLoader's start loop. Await inside a `task.spawn`:

```lua
task.spawn(function()
    Boot.await("models_ready")
    -- ...do the work that needed models...
    Boot.signal("pets_spawned")
end)
```

### 2. The milestone graph (configs/boot.lua)

The SSOT for *what depends on what* and *what the player sees*. Each milestone declares its producer
and its `requires` (the dependency edges). The orchestrator validates the graph is acyclic and that
every required milestone has a declared producer **at boot** — so the next missing dependency is a
loud startup error, not a silent prod race.

| Milestone | Produced by | Requires |
|---|---|---|
| `world_structure` | GameStructureService | — |
| `models_ready` | AssetPreloadService (model pass) | — |
| `eggs_placed` | EggStandPlacement | `models_ready` |
| `crystals_ready` | BreakableSpawner | `world_structure`, `models_ready` |
| `icons_ready` | AssetPreloadService (thumbnail pass) | `models_ready` (background) |

Per-player gates (`data_loaded`, `pets_spawned`, `client_ui`) are player attributes, not global
server milestones — they fire once per joining player.

### 3. `BootOrchestrator` (server) + the client mirror

Owns `BootReadiness`, validates the graph, logs each milestone with timing as it completes (the
permanent replacement for the temporary `[PREBAKE]`/`[FILLPERF]` perf tags), and mirrors milestone
state to `ReplicatedStorage.BootStatus` so **clients read real server readiness**, not workspace
symptom-polls.

### 4. The loading screen (BootLoader.client.lua)

Reads the `configs/boot.lua` phase list and, per phase, watches either the `BootStatus` mirror
(server scope) or a `LocalPlayer` attribute (player scope). Fun + honest: "Building the realm",
"Loading creatures", "Growing crystals", "Walking your pets", "Baking icons". A blocking phase gates
play; a background phase (icons) is shown but not gated. A hard `reveal_timeout_seconds` ceiling
still reveals the game if any signal hangs.

## Migration order (see the Boot P0–P5 tasks)

1. **P0** — this doc, `configs/boot.lua`, `BootReadiness` + headless spec. No behavior change.
2. **P1** — `BootOrchestrator` service + graph validation + `BootStatus` mirror, wired into the loader.
3. **P2** — producers signal (`AssetPreloadService`, `GameStructureService`); delete the
   `_G.AssetsLoadingComplete` flag and the dead `_G.AssetsLoadedEvent`.
4. **P3** — consumers `await` instead of poll/abort (`PetHandler`, `BreakableSpawner`,
   `EggStandPlacement`).
5. **P4** — client loading screen reads the mirror; strip the temporary perf tags.
6. **P5** — live boot verification + wiki.

## Invariant

A service may depend on another subsystem's output **only** by `await`-ing its milestone. No new
`:Wait()`-on-fire-once, no `FindFirstChild`-then-abort, no "poll until it shows up" loops. If you
need something at boot, it's a milestone with an edge in `configs/boot.lua`.
