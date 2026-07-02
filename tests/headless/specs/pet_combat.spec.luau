--[[
    Issue #4: service-owned pet work/damage rules (extracted from the legacy
    cloned Follow script) — [unit] scenarios.
    Run: mise run test-headless
]]

local PetCombat = loadModule("src/Shared/Game/PetCombat.lua")

return function()
    describe("PetCombat.damagePerHit", function()
        it("floors fractional pipeline output", function()
            expect(PetCombat.damagePerHit(5.9)).to.equal(5)
        end)

        it("always deals at least 1 (even from a tiny resolved value)", function()
            expect(PetCombat.damagePerHit(0.4)).to.equal(1)
            expect(PetCombat.damagePerHit(0)).to.equal(1)
        end)
    end)

    describe("PetCombat.applyDamage", function()
        it("subtracts and reports the contribution", function()
            local r = PetCombat.applyDamage(10, 3)
            expect(r.hp).to.equal(7)
            expect(r.contributed).to.equal(3)
        end)

        it("never goes below zero and contributes only the remainder", function()
            -- overkill: 2 hp, 5 dmg -> hp 0, contributed 2 (not 5)
            local r = PetCombat.applyDamage(2, 5)
            expect(r.hp).to.equal(0)
            expect(r.contributed).to.equal(2)
        end)
    end)

    describe("PetCombat.attackInterval", function()
        it("is 1s at efficiency 1", function()
            expect(PetCombat.attackInterval(1)).to.equal(1)
        end)

        it("clamps fast attacks to a 0.2s floor", function()
            -- efficiency 10 -> 1/10 = 0.1 -> clamped up to 0.2
            expect(PetCombat.attackInterval(10)).to.equal(0.2)
        end)

        it("clamps slow attacks to a 2s ceiling", function()
            -- efficiency 0.05 -> 1/0.05 = 20 -> clamped down to 2
            expect(PetCombat.attackInterval(0.05)).to.equal(2)
        end)

        it("guards against zero/negative efficiency (no divide-by-zero blowup)", function()
            expect(PetCombat.attackInterval(0)).to.equal(2)
        end)
    end)
end
