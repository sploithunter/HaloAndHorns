local PowerCastGate = loadModule("src/Shared/Game/PowerCastGate.lua")
local powers = loadModule("configs/powers.lua")

return function()
    describe("PowerCastGate target-dependent families", function()
        for _, family in ipairs({ "absorb", "defense_buff", "evade", "fortify" }) do
            it("refuses " .. family .. " with no living pet target", function()
                local ok, reason = PowerCastGate.validate({ family = family }, { livePetCount = 0 })
                expect(ok).to.equal(false)
                expect(reason).to.equal("no_target")
                expect(PowerCastGate.validate({ family = family }, { livePetCount = 1 })).to.equal(
                    true
                )
            end)
        end

        it("refuses an instant heal with no living pet but permits a persistent field", function()
            expect(PowerCastGate.validate({ family = "heal" }, { livePetCount = 0 })).to.equal(
                false
            )
            expect(PowerCastGate.validate({ family = "heal", field = true }, { livePetCount = 0 })).to.equal(
                true
            )
        end)

        it("casts Revive only when a downed target exists", function()
            expect(PowerCastGate.validate({ family = "revive" }, { hasDownedPet = false })).to.equal(
                false
            )
            expect(PowerCastGate.validate({ family = "revive" }, { hasDownedPet = true })).to.equal(
                true
            )
        end)

        it("casts Resonance only when a crystal is in range", function()
            expect(PowerCastGate.validate({ family = "farm_boost" }, { breakableCount = 0 })).to.equal(
                false
            )
            expect(PowerCastGate.validate({ family = "farm_boost" }, { breakableCount = 1 })).to.equal(
                true
            )
        end)

        it("allows Simoom when either its heal or blind half has a target", function()
            local kind = { family = "heal_blind" }
            expect(PowerCastGate.validate(kind, { livePetCount = 0, enemyCount = 0 })).to.equal(
                false
            )
            expect(PowerCastGate.validate(kind, { livePetCount = 1, enemyCount = 0 })).to.equal(
                true
            )
            expect(PowerCastGate.validate(kind, { livePetCount = 0, enemyCount = 1 })).to.equal(
                true
            )
        end)

        it("does not impose pet targeting on self buffs or summons", function()
            expect(PowerCastGate.validate({ family = "luck" }, { livePetCount = 0 })).to.equal(true)
            expect(PowerCastGate.validate({ family = "summon" }, { livePetCount = 0 })).to.equal(
                true
            )
        end)
    end)

    describe("live power catalog target honesty", function()
        it("gates Sandstorm's blind family as enemy-targeted", function()
            expect(powers.enemy_targeted_families.blind).to.equal(true)
            expect(powers.effect_kinds.aoe_blind.family).to.equal("blind")
        end)

        it("does not advertise timed Prospector and Windfall as Always-On", function()
            expect(powers.powers.prospector.subtitle).never.to.equal("Always-On")
            expect(powers.powers.windfall.subtitle).never.to.equal("Always-On")
            expect(powers.effect_kinds.coin_yield.duration > 0).to.equal(true)
            expect(powers.effect_kinds.windfall.duration > 0).to.equal(true)
        end)

        it("wires the pure gate into the authoritative cast path", function()
            local source = readFile("src/Server/Services/PowerService.lua")
            expect(source:find("PowerCastGate.validate(kind, gateState)", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                source:find("prepared.reviveTarget = self:_reviveTarget(player)", 1, true) ~= nil
            ).to.equal(true)
        end)
    end)
end
