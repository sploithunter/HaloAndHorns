local combat = loadModule("configs/combat.lua")

return function()
    describe("enemy control counter contract", function()
        it("makes support cleanse interruptible without making support immune to Disarm", function()
            local cfg = combat.control_counters.support_cleanse
            expect(cfg.enabled).to.equal(true)
            expect(cfg.role).to.equal("support")
            expect(cfg.hold_immune).to.equal(true)
            expect(cfg.windup_seconds > 0).to.equal(true)
            expect(cfg.cooldown_seconds > cfg.windup_seconds).to.equal(true)

            local source = readFile("src/Server/Services/EnemyService.lua")
            expect(source:find('model:GetAttribute("DisarmedUntil")', 1, true) ~= nil).to.equal(
                true
            )
            expect(source:find('model:SetAttribute("CleanseCastUntil"', 1, true) ~= nil).to.equal(
                true
            )
            expect(source:find("support_cleanse INTERRUPTED", 1, true) ~= nil).to.equal(true)
        end)

        it("lets bosses break a landed hold before entering temporary resistance", function()
            local cfg = combat.control_counters.boss_breakout
            expect(cfg.enabled).to.equal(true)
            expect(cfg.tiers.boss).to.equal(true)
            expect(cfg.tiers.archvillain).to.equal(true)
            expect(cfg.windup_seconds > 0).to.equal(true)
            expect(cfg.resistance_seconds > 0).to.equal(true)

            local enemySource = readFile("src/Server/Services/EnemyService.lua")
            expect(enemySource:find("self:_breakEnemyHold(model)", 1, true) ~= nil).to.equal(true)
            expect(enemySource:find('model:SetAttribute("HoldResistUntil"', 1, true) ~= nil).to.equal(
                true
            )

            local powerSource = readFile("src/Server/Services/PowerService.lua")
            expect(powerSource:find('enemy:GetAttribute("HoldImmune")', 1, true) ~= nil).to.equal(
                true
            )
            expect(powerSource:find('enemy:GetAttribute("HoldResistUntil")', 1, true) ~= nil).to.equal(
                true
            )
            expect(powerSource:find("innateImmune and not temporaryResist", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                powerSource:find("temporaryResist or (innateImmune and not pierced)", 1, true)
                    ~= nil
            ).to.equal(true)
            expect(powerSource:find("FocusFire.applyAccuracy", 1, true) ~= nil).to.equal(true)

            local petSource = readFile("src/Server/Services/PetFollowService.lua")
            expect(petSource:find("FocusFire.applyAccuracy", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
