--[[
    CombatOrigin: canonical-element resolution — pet origin by default, player archetype when
    unified, archetype->element mapping (earth=grass), valid-element + fallback handling.
    Run: mise run test-headless
]]

local CombatOrigin = loadModule("src/Shared/Game/CombatOrigin.lua")

local CFG = {
    unify_to_player = false,
    default_element = "grass",
    archetype_element = {
        geomancer = "grass",
        pyromancer = "lava",
        cryomancer = "ice",
        sandwalker = "desert",
    },
    element_stats = {
        grass = { attack_mult = 1.00, taken_mult = 1.00 },
        lava = { attack_mult = 1.15, taken_mult = 1.12 },
        ice = { attack_mult = 0.90, taken_mult = 0.88 },
        desert = { attack_mult = 0.97, taken_mult = 0.95 },
    },
}

local function withUnify(on)
    local c = table.clone(CFG)
    c.unify_to_player = on
    return c
end

return function()
    describe("CombatOrigin.archetypeElement", function()
        it("maps archetypes to canonical elements (earth -> grass)", function()
            expect(CombatOrigin.archetypeElement("geomancer", CFG)).to.equal("grass")
            expect(CombatOrigin.archetypeElement("pyromancer", CFG)).to.equal("lava")
            expect(CombatOrigin.archetypeElement("cryomancer", CFG)).to.equal("ice")
            expect(CombatOrigin.archetypeElement("sandwalker", CFG)).to.equal("desert")
        end)

        it("returns nil for an unknown archetype", function()
            expect(CombatOrigin.archetypeElement("wizard", CFG)).to.equal(nil)
        end)
    end)

    describe("CombatOrigin.resolve (hybrid, not unified)", function()
        it("uses the pet's own biome element", function()
            expect(CombatOrigin.resolve("lava", "cryomancer", withUnify(false))).to.equal("lava")
            expect(CombatOrigin.resolve("ice", "pyromancer", withUnify(false))).to.equal("ice")
        end)

        it("falls back to default for an invalid/missing pet element", function()
            expect(CombatOrigin.resolve(nil, "pyromancer", withUnify(false))).to.equal("grass")
            expect(CombatOrigin.resolve("plasma", nil, withUnify(false))).to.equal("grass")
        end)
    end)

    describe("CombatOrigin.resolve (unify to player)", function()
        it("uses the player's archetype element regardless of the pet", function()
            expect(CombatOrigin.resolve("ice", "pyromancer", withUnify(true))).to.equal("lava")
            expect(CombatOrigin.resolve("lava", "cryomancer", withUnify(true))).to.equal("ice")
            expect(CombatOrigin.resolve("desert", "geomancer", withUnify(true))).to.equal("grass")
        end)

        it("falls back to the pet element when the player has no/unknown archetype", function()
            expect(CombatOrigin.resolve("desert", nil, withUnify(true))).to.equal("desert")
            expect(CombatOrigin.resolve("lava", "wizard", withUnify(true))).to.equal("lava")
        end)
    end)

    describe("CombatOrigin.statMod", function()
        it("returns the configured attack/taken multipliers per element", function()
            local lava = CombatOrigin.statMod("lava", CFG)
            expect(lava.attack_mult).to.equal(1.15)
            expect(lava.taken_mult).to.equal(1.12)
            local ice = CombatOrigin.statMod("ice", CFG)
            expect(ice.attack_mult).to.equal(0.90)
            expect(ice.taken_mult).to.equal(0.88)
        end)

        it("defaults both multipliers to 1 for unknown/missing element or config", function()
            local unknown = CombatOrigin.statMod("plasma", CFG)
            expect(unknown.attack_mult).to.equal(1)
            expect(unknown.taken_mult).to.equal(1)
            local noCfg = CombatOrigin.statMod("lava", {})
            expect(noCfg.attack_mult).to.equal(1)
            expect(noCfg.taken_mult).to.equal(1)
        end)

        it("keeps the four elements in a balanced band (avg ~1.0, none dominant)", function()
            local sumAtk, sumTaken = 0, 0
            for _, el in ipairs({ "grass", "lava", "ice", "desert" }) do
                local s = CombatOrigin.statMod(el, CFG)
                sumAtk = sumAtk + s.attack_mult
                sumTaken = sumTaken + s.taken_mult
                -- no element more than 20% off neutral on either axis
                expect(s.attack_mult >= 0.8 and s.attack_mult <= 1.2).to.equal(true)
                expect(s.taken_mult >= 0.8 and s.taken_mult <= 1.2).to.equal(true)
            end
            expect(sumAtk / 4 >= 0.97 and sumAtk / 4 <= 1.03).to.equal(true)
            expect(sumTaken / 4 >= 0.95 and sumTaken / 4 <= 1.02).to.equal(true)
        end)
    end)
end
