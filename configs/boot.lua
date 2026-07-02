--[[
    configs/boot.lua — the boot dependency graph + loading-screen SSOT.

    See docs/BOOT_ORCHESTRATION.md. This is the single source of truth for:
      - which boot milestones exist, who produces each, and what each depends on
        (`milestones` — the dependency graph the BootOrchestrator validates at boot),
      - which per-player attributes gate a joining player (`player_gates`),
      - what the loading screen shows and in what order (`phases`).

    Adding a milestone: declare it here with its `produced_by` + `requires`, have the
    producing service call BootReadiness.signal(name), and have every consumer
    BootReadiness.await(name). Never reintroduce :Wait()-on-fire-once / FindFirstChild-abort
    / poll loops — if you need something at boot, it is a milestone with an edge here.
]]

return {
    -- Global, server-wide milestones (fire once per server). The orchestrator mirrors each to
    -- ReplicatedStorage.BootStatus so every client reads real server readiness.
    -- `background = true` => off the critical path: shown on the loading screen but does NOT gate play.
    milestones = {
        world_structure = { produced_by = "GameStructureService", requires = {} },
        models_ready = { produced_by = "AssetPreloadService", requires = {} },
        eggs_placed = { produced_by = "EggStandPlacement", requires = { "models_ready" } },
        crystals_ready = {
            produced_by = "BreakableSpawner",
            requires = { "world_structure", "models_ready" },
            -- Background: the initial fill of every active world is time-budgeted (anti-hitch) and
            -- can take ~20s for 4 unlocked worlds. Crystals grow in-world progressively and aren't
            -- needed to START playing, so this is shown but never gates play. (Was the boot stall.)
            background = true,
        },
        icons_ready = {
            produced_by = "AssetPreloadService",
            requires = { "models_ready" },
            background = true,
        },
    },

    -- Per-player gates: a joining player's own readiness, carried on LocalPlayer attributes
    -- (set server-side as each player's data/pets/UI come up). Not global server milestones.
    player_gates = {
        data_loaded = { attribute = "DataLoaded" },
        pets_spawned = { attribute = "PetsSpawned" },
        client_ui = { attribute = "ClientUIReady" },
    },

    -- Ordered loading-screen phases. `source` = where the client reads this phase's readiness:
    --   "engine"  -> game:IsLoaded() (asset replication; client-only, no milestone)
    --   "server"  -> ReplicatedStorage.BootStatus:GetAttribute(<milestone>) mirror
    --   "player"  -> LocalPlayer:GetAttribute(player_gates[<key>].attribute)
    -- `blocking = false` is shown but does not hold the gate (background milestones).
    phases = {
        { key = "engine", source = "engine", blocking = true, text = "Loading world" },
        {
            key = "world_structure",
            source = "server",
            blocking = true,
            text = "Building the realm",
        },
        { key = "models_ready", source = "server", blocking = true, text = "Loading creatures" },
        { key = "crystals_ready", source = "server", blocking = false, text = "Growing crystals" },
        { key = "eggs_placed", source = "server", blocking = true, text = "Placing the eggs" },
        { key = "data_loaded", source = "player", blocking = true, text = "Syncing your data" },
        { key = "pets_spawned", source = "player", blocking = true, text = "Walking your pets" },
        { key = "client_ui", source = "player", blocking = true, text = "Preparing the HUD" },
        { key = "icons_ready", source = "server", blocking = false, text = "Baking the icons" },
    },

    -- Hard ceiling: reveal the game even if a signal hangs (matches the old BootLoader timeout).
    reveal_timeout_seconds = 25,
    -- Minimum time the final "Ready!" state shows before the screen fades (polish).
    min_display_seconds = 1.5,
}
