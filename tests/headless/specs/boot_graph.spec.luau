--[[
    BootGraph — validate + order the boot milestone dependency graph [unit].
    Run: mise run test-headless

    Also validates the REAL configs/boot.lua graph (it is a pure table) so a typo'd or cyclic
    dependency edge fails CI here instead of at Studio boot.
]]

local BootGraph = loadModule("src/Shared/Boot/BootGraph.lua")
local bootConfig = loadModule("configs/boot.lua")

return function()
    describe("BootGraph.validate", function()
        it("accepts a well-formed graph", function()
            local ok, errors = BootGraph.validate({
                a = { produced_by = "A", requires = {} },
                b = { produced_by = "B", requires = { "a" } },
            })
            expect(ok).to.equal(true)
            expect(#errors).to.equal(0)
        end)

        it("rejects a require edge to an unknown milestone", function()
            local ok, errors = BootGraph.validate({
                a = { produced_by = "A", requires = { "ghost" } },
            })
            expect(ok).to.equal(false)
            expect(#errors >= 1).to.equal(true)
        end)

        it("rejects a missing produced_by", function()
            local ok = BootGraph.validate({ a = { requires = {} } })
            expect(ok).to.equal(false)
        end)

        it("detects a dependency cycle", function()
            local ok = BootGraph.validate({
                a = { produced_by = "A", requires = { "b" } },
                b = { produced_by = "B", requires = { "a" } },
            })
            expect(ok).to.equal(false)
        end)

        it("the real configs/boot.lua graph is valid (acyclic, producers + edges sound)", function()
            local ok, errors = BootGraph.validate(bootConfig.milestones)
            if not ok then
                error("boot graph invalid: " .. table.concat(errors, "; "))
            end
            expect(ok).to.equal(true)
        end)
    end)

    describe("BootGraph.order", function()
        it("places dependencies before dependents", function()
            local order = BootGraph.order({
                crystals = { produced_by = "C", requires = { "world", "models" } },
                world = { produced_by = "W", requires = {} },
                models = { produced_by = "M", requires = {} },
            })
            local pos = {}
            for i, name in ipairs(order) do
                pos[name] = i
            end
            expect(pos.world < pos.crystals).to.equal(true)
            expect(pos.models < pos.crystals).to.equal(true)
        end)

        it("orders the real graph with models_ready before crystals_ready", function()
            local order = BootGraph.order(bootConfig.milestones)
            local pos = {}
            for i, name in ipairs(order) do
                pos[name] = i
            end
            expect(pos.models_ready < pos.crystals_ready).to.equal(true)
            expect(pos.world_structure < pos.crystals_ready).to.equal(true)
            expect(pos.models_ready < pos.eggs_placed).to.equal(true)
        end)
    end)
end
