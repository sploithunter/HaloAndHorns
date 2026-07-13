--[[
    Config VALIDATION — [guardrail] runs the REAL shared schema rules in CI,
    not hand-ported copies (config_integrity Part 2's admitted drift problem).

    Born from the 2026-07-09 double boot-crash: mission pseudo-zones passed
    require-time integrity but died at ConfigLoader's areas validator, were
    fixed, then died AGAIN at WorldBindingService's separate kind allowlist.
    Rule extracted to src/Shared/Game/ZoneSchema.lua (pure); this spec runs
    it against the live config — the same code both boot gates now call.

    PATTERN for future validators: extract the pure shape rules into
    Shared/Game/<X>Schema.lua, delegate from ConfigLoader/services, sweep here.
]]

local ZoneSchema = loadModule("src/Shared/Game/ZoneSchema.lua")
local MissionSchema = loadModule("src/Shared/Game/MissionSchema.lua")

return function()
    describe("MissionSchema vs configs (cross-config contracts, in CI)", function()
        it("every mission's enemies/pets/ranks/zones/counters resolve", function()
            local ok, err = MissionSchema.validate(loadModule("configs/missions.lua"), {
                enemies = loadModule("configs/enemies.lua"),
                pets = loadModule("configs/pets.lua"),
                stats = loadModule("configs/stats.lua"),
                areas = loadModule("configs/areas.lua"),
                quests = loadModule("configs/quests.lua"),
            })
            if not ok then
                error("boot would CRASH: " .. tostring(err))
            end
            expect(ok).to.equal(true)
        end)

        it("rejects a pack unit with an unknown pet id (the silent-skip soft bug)", function()
            local ok = MissionSchema.validate({
                pet_ranks = {},
                missions = {
                    x_trial = {
                        kit = "gray_box",
                        packs = { { weight = 1, units = { { pet = "ghost_pet", count = 1 } } } },
                    },
                },
            }, { stats = { counters = { x_trials_completed = {} } } })
            expect(ok).to.equal(false)
        end)

        it("rejects a mission without its per-trial counter", function()
            local ok = MissionSchema.validate({
                missions = { y_trial = { kit = "gray_box", packs = {} } },
            }, { stats = { counters = {} } })
            expect(ok).to.equal(false)
        end)

        it("rejects an unknown mission aggression policy", function()
            local ok = MissionSchema.validate({
                combat = { default_aggression_policy = "sometimes" },
                missions = {},
            })
            expect(ok).to.equal(false)
        end)

        it("rejects a Trial group scale whose default falls outside its bounds", function()
            local ok = MissionSchema.validate({
                player_tuning = {
                    group_scale = { min = 0.5, max = 2, default = 3, step = 0.05 },
                },
                missions = {},
            })
            expect(ok).to.equal(false)
        end)

        it("rejects a negative mission-room movement inset", function()
            local ok = MissionSchema.validate({
                player_tuning = {
                    group_scale = { min = 0.5, max = 2, default = 1, step = 0.05 },
                },
                navigation = { room_inset = -1 },
                missions = {},
            })
            expect(ok).to.equal(false)
        end)

        it("rejects a malformed mission boss level curve", function()
            local ok = MissionSchema.validate({
                player_tuning = {
                    group_scale = { min = 0.5, max = 2, default = 1, step = 0.05 },
                },
                navigation = { room_inset = 2 },
                population = { boss_only_at_objective = true },
                pet_ranks = {
                    boss = {
                        hp_mult = 8,
                        level_scaling = {
                            min_level = 50,
                            max_level = 14,
                            curve = "linear",
                            at_min = { hp_mult = 2 },
                        },
                    },
                },
                missions = {},
            })
            expect(ok).to.equal(false)
        end)
    end)
    describe("ZoneSchema vs configs/areas.lua (the real boot rules, in CI)", function()
        local areas = loadModule("configs/areas.lua")

        it("every zone passes the shared schema (id/key/kind/parent)", function()
            local ok, err = ZoneSchema.validateZones(areas.zones)
            if not ok then
                error("boot would CRASH: " .. tostring(err))
            end
            expect(ok).to.equal(true)
        end)

        it("mission pseudo-zones carry elements (branding contract)", function()
            for zoneId, zone in pairs(areas.zones) do
                if zone.kind == "mission" then
                    expect(type(zone.element)).to.equal("string")
                    local _ = zoneId
                end
            end
        end)

        it("rejects a kind outside the ONE allowlist", function()
            local bad = { x = { id = "x", kind = "nonsense" } }
            local ok = ZoneSchema.validateZones(bad)
            expect(ok).to.equal(false)
        end)

        it("rejects id/key mismatch and missing parent", function()
            expect(ZoneSchema.validateZones({ x = { id = "y", kind = "area" } })).to.equal(false)
            expect(ZoneSchema.validateZones({ x = { id = "x", kind = "area", parent = "ghost" } })).to.equal(
                false
            )
        end)
    end)
end
