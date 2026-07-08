--[[
    Missions config — CoH-style door missions with deterministic procedural
    interiors (docs/MISSION_WORLDGEN.md §6).

    `worldgen_version` is folded into every mission seed: bump it when the
    solver algorithm changes so old seeds are invalidated DELIBERATELY
    instead of silently producing different maps.

    `slots`: same-server instance slots on a far X-band. spacing must stay
    > 2× StreamingTargetRadius (1024) so instances never stream into each
    other; keep origin_x + count*spacing well under ~50k studs (float
    precision).

    `seed_policy` per mission:
      "team_stable" — the same party re-entering gets the same map
      "per_attempt" — fresh map each run (attempt counter in the context
                      key); the resolved seed is stored on the instance so
                      any map a player saw can be regenerated for debugging

    Solver knobs are LayoutSolver params (docs §4); `solver_defaults` apply
    to every mission, `solver_overrides` merge on top per mission.
]]

return {
    -- v2: 6x tile scale (2026-07-08 playtest — "vastly too small" at v1 scale)
    worldgen_version = 2,

    slots = {
        origin_x = 24000,
        spacing = 3072, -- wider berth for the 6x-scale maps (envelope below caps sprawl)
        count = 8, -- last slot at 24000 + 7*3072 = 45504, inside float comfort
        y = 0,
    },

    limits = {
        per_team = 1, -- live instances per team
        global = 6, -- live instances per server
        max_lifetime = 1800, -- seconds; TTL sweep abandons older instances
    },

    -- Camera clamp while inside a mission: paired with the 48-stud kit walls
    -- so you can't zoom above the maze and scout the glowy; restored on exit.
    camera = {
        max_zoom = 45,
    },

    solver_defaults = {
        tile_budget = 30,
        target_depth = { min = 4, max = 8 },
        class_weights_by_band = {
            { upto = 0.5, corridor = 3, room = 1, junction = 1 },
            { upto = 1.0, corridor = 1, room = 3, junction = 1 },
        },
        -- hard slot envelope: at 6x tile scale a map must stay within
        -- ±max_half_extent of its slot origin or it could reach the next slot
        max_half_extent = 1200,
    },

    missions = {
        -- REALM-SPLIT trials (Jason): hell = dark torch-lit (DOORS pole),
        -- heaven = bright low-poly (Dungeon Quest pole). Same gray-box kit —
        -- `theme` drives dressing palettes server-side and the client
        -- MissionAtmosphere lighting preset. Enemy rosters stay earth packs
        -- for now (realm-correct rosters come with allegiance work).
        hell_trial = {
            display = "Hell Trial",
            kit = "gray_box",
            theme = "hell",
            seed_policy = "per_attempt",
            -- CoH clear-gate: the glowy stays inert until every mission enemy
            -- is defeated — which also makes pets mandatory (players are
            -- invulnerable; only pets can clear). "reach_beacon" remains the
            -- ungated variant for future courier-style missions.
            objective = { kind = "clear_then_beacon" },
            -- static per-room packs (enemies.lua wave shape); one pack rolls
            -- per MissionSpawn point on the seeded "spawns" stream
            packs = {
                { weight = 10, units = { { enemy = "rabid_dog", count = 2 } } },
                { weight = 8, units = { { enemy = "raging_bear", count = 1 } } },
                { weight = 6, units = { { enemy = "murder_crow", count = 2 } } },
                {
                    weight = 4,
                    units = {
                        { enemy = "rabid_bunny", count = 1 },
                        { enemy = "rabid_dog", count = 1 },
                    },
                },
            },
            -- treasure chests (CoH glowie-lite): seeded placement in ~40% of
            -- room-class tiles (min 1); opening pays 1-2 guaranteed
            -- enhancement drops to the opener. Magnet is OFF in-mission.
            -- M5a dressing: per-room tint jitter + seeded clutter density
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.12,
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3, -- seconds standing at the chest to open it
            },
            solver_overrides = {},
        },
        heaven_trial = {
            display = "Heaven Trial",
            kit = "gray_box",
            theme = "heaven",
            seed_policy = "per_attempt",
            objective = { kind = "clear_then_beacon" },
            packs = {
                { weight = 10, units = { { enemy = "rabid_dog", count = 2 } } },
                { weight = 8, units = { { enemy = "raging_bear", count = 1 } } },
                { weight = 6, units = { { enemy = "murder_crow", count = 2 } } },
                {
                    weight = 4,
                    units = {
                        { enemy = "rabid_bunny", count = 1 },
                        { enemy = "rabid_dog", count = 1 },
                    },
                },
            },
            decor = {
                props_min = 2,
                props_max = 5,
                color_jitter = 0.08, -- heaven reads cleaner with less drift
            },
            treasure = {
                room_fraction = 0.4,
                min_chests = 1,
                rolls_min = 1,
                rolls_max = 2,
                open_hold = 3,
            },
            solver_overrides = {},
        },
    },
}
