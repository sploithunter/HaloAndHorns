--[[
    Feature 13: Archetype System — [unit] scenarios.
    Run: mise run test-headless
]]

local ArchetypeLogic = loadModule("src/Shared/Game/ArchetypeLogic.lua")
local config = loadModule("configs/archetypes.lua")

return function()
    describe("ArchetypeLogic.isValid", function()
        it("accepts the configured archetypes", function()
            expect(ArchetypeLogic.isValid("geomancer", config)).to.equal(true)
            expect(ArchetypeLogic.isValid("pyromancer", config)).to.equal(true)
        end)

        it("rejects unknown / nil archetypes", function()
            expect(ArchetypeLogic.isValid("wizard", config)).to.equal(false)
            expect(ArchetypeLogic.isValid(nil, config)).to.equal(false)
        end)
    end)

    describe("ArchetypeLogic.availablePowers", function()
        it("returns the archetype's own pool PLUS the shared generic pool", function()
            local powers = ArchetypeLogic.availablePowers("geomancer", config)
            local ownCount = #(config.archetypes.geomancer.power_pool or {})
            local genericCount = #(config.generic_pool or {})
            expect(#powers).to.equal(ownCount + genericCount)
            expect(ArchetypeLogic.hasPower("geomancer", "stone_skin", config)).to.equal(true)
            -- generic powers are available to every archetype
            expect(ArchetypeLogic.hasPower("geomancer", "fortune", config)).to.equal(true)
        end)

        it("does NOT include other archetypes' powers", function()
            -- geomancer pool must exclude cryo/pyro powers (Feature 13 [unit])
            expect(ArchetypeLogic.hasPower("geomancer", "frost_bind", config)).to.equal(false)
            expect(ArchetypeLogic.hasPower("geomancer", "mark_of_flame", config)).to.equal(false)
        end)

        it("falls back to JUST the generic pool for a nil/invalid archetype", function()
            -- NATURAL powers are pickable before the L5 origin choice, so no origin = generic only
            local genericCount = #(config.generic_pool or {})
            expect(#ArchetypeLogic.availablePowers(nil, config)).to.equal(genericCount)
            expect(#ArchetypeLogic.availablePowers("wizard", config)).to.equal(genericCount)
            expect(ArchetypeLogic.hasPower(nil, "fortune", config)).to.equal(true) -- generic, no origin
            expect(ArchetypeLogic.hasPower(nil, "stone_skin", config)).to.equal(false) -- origin power
        end)
    end)

    describe("ArchetypeLogic.list", function()
        it("lists all four prototype archetypes", function()
            expect(#ArchetypeLogic.list(config)).to.equal(4)
        end)
    end)
end
