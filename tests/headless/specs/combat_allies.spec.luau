--[[
    CombatAllies csv helpers — [unit]. Run: mise run test-headless
]]

local CombatAllies = loadModule("src/Shared/Game/CombatAllies.lua")

return function()
    describe("CombatAllies.csvHas", function()
        it("matches exact names only — never substrings", function()
            expect(CombatAllies.csvHas("Bobby,Alice", "Bob")).to.equal(false)
            expect(CombatAllies.csvHas("Bob,Alice", "Bob")).to.equal(true)
        end)

        it("handles empty/nil csvs", function()
            expect(CombatAllies.csvHas("", "Bob")).to.equal(false)
            expect(CombatAllies.csvHas(nil, "Bob")).to.equal(false)
        end)
    end)

    describe("CombatAllies.names", function()
        it("merges team + alliance, dedupes, excludes self", function()
            local names = CombatAllies.names("Me,Alice,Cara", "Alice,Dev", "Me")
            expect(#names).to.equal(3)
            expect(names[1]).to.equal("Alice")
            expect(names[2]).to.equal("Cara")
            expect(names[3]).to.equal("Dev")
        end)

        it("empty inputs -> empty list", function()
            expect(#CombatAllies.names(nil, "", "Me")).to.equal(0)
        end)
    end)
end
