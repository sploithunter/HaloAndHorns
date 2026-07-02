--[[
    Feature 14: Power Selection at Level-Up — [unit] scenarios.
    Run: mise run test-headless
]]

local PowerSelection = loadModule("src/Shared/Game/PowerSelection.lua")
local powersConfig = loadModule("configs/powers.lua")
local archetypes = loadModule("configs/archetypes.lua")
local ArchetypeLogic = loadModule("src/Shared/Game/ArchetypeLogic.lua")

-- Cadence-agnostic: index off the live selection_levels array so this survives re-tuning.
local levels = powersConfig.selection_levels
local L1, L2, L3 = levels[1], levels[2], levels[3]
local geoPowers = ArchetypeLogic.availablePowers("geomancer", archetypes)

return function()
    describe("PowerSelection.pendingSelections", function()
        it("is 0 below the first selection level", function()
            expect(PowerSelection.pendingSelections(L1 - 1, 0, levels)).to.equal(0)
        end)

        it("is 1 on reaching the first selection level with none selected", function()
            expect(PowerSelection.pendingSelections(L1, 0, levels)).to.equal(1)
        end)

        it(
            "grants at most one per selection level (first level, 1 selected -> 0 pending)",
            function()
                expect(PowerSelection.pendingSelections(L1, 1, levels)).to.equal(0)
            end
        )

        it("accumulates unspent selections across levels (3rd level, 1 selected -> 2)", function()
            -- the first 3 selection levels reached = 3; minus 1 selected = 2 pending
            expect(PowerSelection.pendingSelections(L3, 1, levels)).to.equal(2)
        end)
    end)

    describe("PowerSelection.canSelect", function()
        it("allows a valid in-pool selection when one is pending", function()
            local r = PowerSelection.canSelect("stone_skin", geoPowers, {}, L1, levels)
            expect(r.ok).to.equal(true)
        end)

        it("rejects a power from another archetype", function()
            local r = PowerSelection.canSelect("frost_bind", geoPowers, {}, L1, levels)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("not_in_archetype_pool")
        end)

        it("rejects a duplicate selection", function()
            -- at the 2nd level with 1 already selected, a pick is pending but the dupe check fires
            local r =
                PowerSelection.canSelect("stone_skin", geoPowers, { "stone_skin" }, L2, levels)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("already_selected")
        end)

        it("rejects when no selection is pending (below the first selection level)", function()
            local r = PowerSelection.canSelect("stone_skin", geoPowers, {}, L1 - 1, levels)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("no_pending_selection")
        end)

        it(
            "rejects a second pick at the same level (1 already selected at the first level)",
            function()
                local r =
                    PowerSelection.canSelect("ironclad", geoPowers, { "stone_skin" }, L1, levels)
                expect(r.ok).to.equal(false)
                expect(r.reason).to.equal("no_pending_selection")
            end
        )
    end)

    describe("PowerSelection.menuRows", function()
        -- fixture pool + powers so order/gating tests stay deterministic regardless of live tuning
        local pool = { "alpha", "beta", "gamma" }
        local powers = {
            alpha = { unlock_level = 2 },
            beta = { unlock_level = 6 },
            gamma = { unlock_level = 1 },
        }

        it("orders by unlock_level ascending, independent of pool order", function()
            local rows = PowerSelection.menuRows(pool, powers, 10, {})
            expect(rows[1].id).to.equal("gamma") -- unlock 1
            expect(rows[2].id).to.equal("alpha") -- unlock 2
            expect(rows[3].id).to.equal("beta") -- unlock 6
        end)

        it("breaks unlock-level ties alphabetically by id", function()
            local tied = { zeta = { unlock_level = 5 }, delta = { unlock_level = 5 } }
            local rows = PowerSelection.menuRows({ "zeta", "delta" }, tied, 10, {})
            expect(rows[1].id).to.equal("delta")
            expect(rows[2].id).to.equal("zeta")
        end)

        it("pins INNATE powers to the top regardless of pickLevel / alphabetical tie", function()
            -- innate "zeta" must beat the L1 "alpha" and the alphabetically-earlier "beta"
            local withInnate = {
                alpha = { unlock_level = 1 },
                beta = { unlock_level = 1 },
                zeta = { unlock_level = 2, innate = true },
            }
            local rows = PowerSelection.menuRows({ "alpha", "beta", "zeta" }, withInnate, 10, {})
            expect(rows[1].id).to.equal("zeta") -- innate first, above lower unlock + alpha tiebreak
            expect(rows[1].innate).to.equal(true)
            expect(rows[2].id).to.equal("alpha")
        end)

        it("gates each row by unlock_level vs level (sorted gamma,alpha,beta)", function()
            local rows = PowerSelection.menuRows(pool, powers, 4, {})
            expect(rows[1].state).to.equal("available") -- gamma unlock 1 <= 4
            expect(rows[2].state).to.equal("available") -- alpha unlock 2 <= 4
            expect(rows[3].state).to.equal("locked") -- beta unlock 6 > 4
        end)

        it("marks owned powers + passes unlockLevel through", function()
            local rows = PowerSelection.menuRows(pool, powers, 1, { alpha = true })
            local a
            for _, r in ipairs(rows) do
                if r.id == "alpha" then
                    a = r
                end
            end
            expect(a.state).to.equal("owned")
            expect(a.unlockLevel).to.equal(2)
        end)

        it("defaults a missing unlock_level to 1 (always available)", function()
            local rows = PowerSelection.menuRows({ "nogate" }, { nogate = {} }, 1, {})
            expect(rows[1].state).to.equal("available")
            expect(rows[1].unlockLevel).to.equal(1)
        end)
    end)

    describe("PowerSelection.pickLevel + honest menuRows schedule", function()
        local sched = { 2, 6, 10, 15 }

        it("rounds an unlock up to the first selection level >= it", function()
            expect(PowerSelection.pickLevel(9, sched)).to.equal(10) -- can't pick at 9, next is 10
            expect(PowerSelection.pickLevel(6, sched)).to.equal(6) -- on-grid stays
            expect(PowerSelection.pickLevel(3, sched)).to.equal(6)
        end)

        it("falls back to the raw unlock when no schedule is given", function()
            expect(PowerSelection.pickLevel(9, nil)).to.equal(9)
        end)

        it("gates by pickLevel, not raw unlock (L9 power isn't pickable until L10)", function()
            local pool = { "a" }
            local powers = { a = { unlock_level = 9 } }
            local atNine = PowerSelection.menuRows(pool, powers, 9, {}, sched)
            expect(atNine[1].pickLevel).to.equal(10)
            expect(atNine[1].state).to.equal("locked")
            local atTen = PowerSelection.menuRows(pool, powers, 10, {}, sched)
            expect(atTen[1].state).to.equal("available")
        end)
    end)
end
