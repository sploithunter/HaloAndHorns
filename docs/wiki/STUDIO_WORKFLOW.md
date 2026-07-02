# Studio Workflow

Status: current

## Summary

The project uses Rojo for file sync and Roblox Studio for live playtesting. Codex is connected to Studio through the official Roblox Studio MCP server, which is now the preferred way for agents to inspect and verify the live game.

## MCP Setup

In Roblox Studio:

1. Open the Assistant panel from the top-right Assistant/sparkle icon.
2. Open the Assistant panel menu.
3. Choose `Manage MCP Servers`.
4. Turn on `Enable Studio as MCP server`.
5. Ensure `Codex` is enabled under Quick connect.

Codex-side MCP command:

```sh
codex mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```

The current working Studio instance is `RBX-Template`.

## Rojo Sync Gotchas

Rojo can occasionally enter an unsynced-looking state even while the server and Studio plugin appear connected. This is a common Studio/Rojo failure mode on this project, so do not over-debug gameplay before checking sync state. If new scripts/config do not appear in Studio, stop Play, disconnect Rojo in the Studio plugin, reconnect to the running Rojo server, and then restart Play. Agents should use Computer Use for this when the Rojo plugin UI must be operated directly.

The Studio edit-command VM can also keep stale `require` results after Rojo updates a ModuleScript. If a module's `Source` is current but `require(module)` returns an old table, run the check in Play mode or restart the Studio session so Roblox creates a fresh Luau VM.

Recovery checklist:

1. Stop Play before judging sync.
2. Use Studio MCP to inspect source, for example with `script_grep`, if available.
3. If Studio source is stale, disconnect and reconnect the Rojo plugin to the current server.
4. If source is current but behavior is stale, restart Play to clear the Luau VM/module cache.
5. Only debug gameplay after the source and runtime agree.

## Studio MCP Reset Gotchas

Studio MCP can also get into a half-connected state after reboots or Codex restarts: `StudioMCP` may still be listening on `127.0.0.1:13469`, but Codex may not expose the `mcp__Roblox_Studio__` tools or tool calls may fail with `Not connected to the WS host`.

Useful checks:

```sh
codex mcp list
lsof -nP -iTCP -sTCP:LISTEN | rg "13469|34872|StudioMCP|rojo"
curl --max-time 2 http://127.0.0.1:13469/health
```

Healthy Studio MCP reports `OK`, `Studios: 1`, and cached tools. If the bridge is stale, kill only the `StudioMCP` processes and let a fresh MCP client start `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`; Studio should reconnect to the new host after a few seconds. On 2026-05-29 this reset restored access to `NewWorld Map Cleanup Copy`, and a harmless Luau ping returned `MCP ping ok: game-template`.

## Available Agent Checks

Agents can use Studio MCP to:

- list and select Studio instances;
- capture the edit/play screen;
- read Studio Output through `get_console_output`;
- start and stop play mode;
- inspect the game tree and instances;
- execute Luau for diagnostics;
- read and edit Studio scripts when needed.

Before modifying a live Studio session, always list Studio instances and confirm the active instance is `RBX-Template`.

## Authored Reference Map

The fastest way to start testing the engine against a real Studio-owned map is:

```lua
-- Run in Studio edit mode:
-- paste scripts/studio/create_reference_map.luau into the command bar
```

This creates `Workspace.AuthoredReferenceMap` plus required `Workspace.Game` marker folders for `Spawn` and `Meadow`. Save the place in Studio if the generated markers should persist.

Contract verification runner:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.MapContractSmoke).runText({
    requireAuthored = true,
    allowSynthetic = false,
})
```

Last verified on 2026-05-27:

```text
MapContractSmoke expected after the BasicEarth egg change: `AreaZone=2`, `EggStand=1`, `PODPodium=2`, `Portal=2`, `SpawnZone=2`, `TeleportPad=2`, `Zone=5`.
```

See [Authored Map Workflow](../AUTHORED_MAP_WORKFLOW.md) for the checklist and promotion path.

## Automated Spawn Safety Tests

Initial character placement should be verified against the live authored floor, not only against config coordinates.

Implemented runner:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.SpawnSafetySmoke).runText({
    zoneId = "Spawn",
    timeoutSeconds = 25,
})
```

This uses `ZoneService:PlacePlayerAtZoneSpawn`, which asks `WorldBindingService` for a map-derived spawn CFrame. The service raycasts down through the area's authored `AreaZone`/floor while excluding marker parts, falls back to `SpawnZone` when needed, and clears the character's velocity after placement.

Last verified on 2026-05-27:

```text
SpawnSafetySmoke passed: player=coloradoplays zone=Spawn area=Spawn floorDistance=10.47
```

Do not use a direct `SpawnSafetySmoke` call on locked zones as an unlock test. For example, `Meadow` correctly redirects the player back to `Spawn` until travel/unlock logic grants access; use `TravelSmoke` for that path.

## Automated Travel Tests

For teleport/gate tests, prefer server-created invisible `TeleportPad` / `Portal` markers as the behavioral source of truth. Visual gate models should be optional fixtures attached to the same markers, not the thing gameplay logic depends on.

Implemented runner:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.TravelSmoke).runText({
    sourceAreaId = "Spawn",
    targetZoneId = "Meadow",
    timeoutSeconds = 25,
})
```

This uses the Studio-only `StudioSmokeTestService` bridge. It temporarily removes the target area from the player's unlock list, asserts travel is rejected while locked, unlocks the area, travels through the configured hook, verifies the active area changed, and restores the original unlock state.

Last verified on 2026-05-27:

```text
TravelSmoke passed: player=coloradoplays source=Spawn target=Meadow area=Meadow locked=locked restored=true meadowItemsAfter=8
```

Manual/useful test flow:

1. Synthesize or load a two-area map from `configs/areas.lua`.
2. Ensure a tagged `TeleportPad` has `AreaId` and `TargetZoneId`.
3. Use Studio MCP `character_navigation` or Luau to move the test character near/on the pad.
4. Assert the server-authoritative travel result: character position, active area, unlock validation, and Output diagnostics.

Creator Store assets can help screenshots and builder workflows, but keep their asset IDs in config and validate loadability before a test relies on them. Roblox asset loading is permission-sensitive, so the core automated test should still pass with a simple generated placeholder gate.

## Automated Egg Proximity Tests

Egg hatching should have a required Studio MCP smoke test because it crosses map hooks, client proximity UI, server validation, currency, and inventory persistence.

Current behavior to preserve:

- `EggCurrentTargetService` scans spawned egg models and only sets the current target when the character is within `configs/egg_system.lua` `proximity.max_distance`.
- `EggInteractionService` performs a client distance precheck before invoking `ReplicatedStorage.EggOpened`.
- `EggService:IsPlayerNearEgg` repeats the distance check on the server before currency is spent or a pet is granted.
- Egg spawn anchors come from the model's `SpawnPoint` ObjectValue, which points back to the `EggSpawnPoint` / `EggStand` marker.

Required smoke-test flow:

1. Start play mode and wait for egg spawn points to populate.
2. Move the test character far outside `proximity.max_distance`.
3. Try invoking hatch behavior and assert the result is rejected with no currency loss and no new pet.
4. Move the character to a tagged egg stand or spawned egg anchor.
5. Assert the egg UI target appears, invoke hatch, and verify currency decreases and inventory/pet count increases.
6. Move away again and assert the current target returns to `None`.

For UI-level coverage, prefer `character_navigation` plus keyboard input for the E key. For server-authoritative coverage, directly invoke `EggOpened` from Studio Luau at near/far positions and assert the returned result plus currency/inventory state.

Implemented runner:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggProximitySmoke).runText({
    eggType = "basic_egg",
    timeoutSeconds = 25,
})
```

This uses the Studio-only `StudioSmokeTestService` bridge. The client test coordinates current-target UI assertions, while the server bridge moves the character, sets temporary test currency, performs near/far hatch attempts, verifies currency/pet counts, and restores the player's original currency and pet bucket.

Last verified on 2026-05-27:

```text
EggProximitySmoke passed: player=coloradoplays egg=basic_egg cost=100 coins hatched=bunny/basic restored=true
```

## Automated Phase 2 Progression Tests

Phase 2 economy-depth changes should be verified through the Studio smoke bridge because they cross config validation, profile fields, currencies, area unlocks, inventory limits, and profile restoration.

Implemented runner:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.Phase2ProgressionSmoke).runText({
    targetZoneId = "Meadow",
    timeoutSeconds = 25,
})
```

Last verified on 2026-05-27:

```text
Phase2ProgressionSmoke passed: zone=Meadow unlock=100 crystals equipLevel=1 maxPetSlots=4 storage=50->75 crystalReward=100->110 restored=true
```

Full Meadow breakable loop coverage:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.MeadowBreakableSmoke).runText({
    timeoutSeconds = 25,
})
```

This smoke uses the Studio-only `BreakableSpawner:SpawnBreakableForStudioSmoke` helper to spawn a deterministic `BigBlueCrystal` in Meadow, but the break itself still goes through the normal contribution folder, HP death handler, economy reward resolver, stat counter, and profile restore path.

Last verified on 2026-05-27:

```text
MeadowBreakableSmoke passed: area=Meadow breakable=BigBlueCrystal reward=110 crystals counter=1->2 restored=true
```

Synthetic expansion coverage:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.SyntheticExpansionSmoke).runText({
    timeoutSeconds = 25,
})
```

This smoke temporarily extends the live service config with a second world and area, forces a synthetic rebuild, verifies a cross-world `Portal` to `crystal_world`, travels to `CrystalCavern`, then restores the original authored map state. Always follow it with authored-only `MapContractSmoke` to prove no synthetic marker attributes leaked.

Last verified on 2026-05-27:

```text
SyntheticExpansionSmoke passed: spawn_world->crystal_world area=CrystalCavern spawnZones=1 restored=true
MapContractSmoke expected after the BasicEarth egg change: `AreaZone=2`, `EggStand=1`, `PODPodium=2`, `Portal=2`, `SpawnZone=2`, `TeleportPad=2`, `Zone=5`.
```

## Current Verification Commands

CLI checks use mise shims if the tools are not on the shell PATH:

```sh
/Users/jason/.local/share/mise/shims/rojo build --output /tmp/rbx-template-phase0.rbxl
/Users/jason/.local/share/mise/shims/selene --allow-warnings src configs tests
/Users/jason/.local/share/mise/shims/stylua --check src configs tests
python3 scripts/wiki_status.py
```

Current status as of 2026-05-27:

- Rojo build passes.
- Targeted Selene for Phase 1 touched files passes with existing warnings only.
- StyLua check for Phase 1 touched files passes; full-repo formatting remains a separate cleanup lane.
- Studio MCP marker, spawn safety, travel, dormancy, egg, Phase 2 progression, Meadow breakable, and synthetic expansion smoke tests pass.

## Studio Assistant Model Note

Roblox Studio Assistant can use `Roblox Default` or user-supplied provider API keys for Anthropic, OpenAI, and Google API. It does not currently expose a ChatGPT/Claude/Gemini consumer subscription login in Studio's API key panel. For subscription-backed OpenAI development, use Codex through MCP instead.
