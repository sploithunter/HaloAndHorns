--[[
    Resonance (innate farming power) — config-wiring guard. Pins the power + effect_kind shape and
    that all four enhanceable knobs are wired (no axis no-ops): amount→potency(magnitude),
    cooldown→recharge("*"), focus→focus("*"), radius→range(real radiusBase, NOT the magnet
    magnitude-fold). See docs/INNATE_RESONANCE_POWER.md. Run: mise run ci
]]

local powers = loadModule("configs/powers.lua")
local enh = loadModule("configs/enhancements.lua")

return function()
    describe("Resonance innate power", function()
        local def = powers.powers and powers.powers.resonance
        local kind = powers.effect_kinds
            and powers.effect_kinds[(def and def.effect) or "resonance"]

        it("is an innate active farming cast", function()
            expect(def).to.be.ok()
            expect(def.innate).to.equal(true)
            expect(def.effect).to.equal("resonance")
            expect(type(def.focus_cost)).to.equal("number")
            expect(type(def.cooldown_seconds)).to.equal("number")
            -- innate must NOT be a pickable pool power (it's granted at spawn, not chosen)
            expect(def.generic).never.to.be.ok()
        end)

        it("is an AoE crystal-boost via the farm_boost family", function()
            expect(kind).to.be.ok()
            expect(kind.family).to.equal("farm_boost")
            expect((tonumber(kind.magnitude) or 0) > 0).to.equal(true)
            expect((tonumber(kind.radius) or 0) > 0).to.equal(true)
            expect(kind.target).to.equal("targeted_aoe")
        end)

        it("has all four knobs enhanceable (no axis no-ops)", function()
            local types = enh.types
            -- amount → potency (magnitude axis)
            expect(types.potency.families.farm_boost).to.equal(true)
            -- radius → range (radius axis); requires_aoe passes via the targeted_aoe target
            expect(types.range.families.farm_boost).to.equal(true)
            expect((enh.aoe_targets or {}).targeted_aoe).to.equal(true)
            -- cooldown → recharge and focus → focus cover every power ("*")
            expect(types.recharge.families).to.equal("*")
            expect(types.focus.families).to.equal("*")
            -- radius is a REAL field, NOT the magnet magnitude-fold (so range scales radiusBase)
            expect((enh.radius_families or {}).farm_boost).never.to.be.ok()
        end)
    end)
end
