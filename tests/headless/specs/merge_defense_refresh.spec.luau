local Draft = loadModule("src/Shared/Game/MergeEggDraft.lua")
local config = loadModule("configs/merge_egg_prototype.lua").reinforcement.stronger_refresh
local function pet(power, role, huge)
    return { combatPower = power, role = role or "melee", huge = huge }
end

return function()
    describe("stronger-only hatcher refresh", function()
        it("replaces the weak dog, not the lucky dragon", function()
            local dog, dragon, upgrade = pet(10), pet(1000), pet(100)
            local chosen, slot = Draft.selectUpgrade(
                { upgrade },
                { dog, dragon },
                config.minimum_power_ratio
            )
            expect(chosen).to.equal(upgrade)
            expect(slot).to.equal(1)
        end)
        it("keeps ties, weaker rolls, and trivial power bumps", function()
            local incumbent = pet(100)
            expect(
                Draft.selectUpgrade(
                    { pet(50), pet(100), pet(105) },
                    { incumbent },
                    config.minimum_power_ratio
                )
            ).to.equal(nil)
        end)
        it("preserves the last tank and support but can upgrade within each role", function()
            local tank, support, ranged = pet(10, "tank"), pet(5, "support"), pet(100, "ranged")
            expect(
                Draft.selectUpgrade(
                    { pet(50) },
                    { tank, support, ranged },
                    config.minimum_power_ratio
                )
            ).to.equal(nil)
            local better = pet(50, "support")
            local chosen, slot = Draft.selectUpgrade(
                { better },
                { tank, support, ranged },
                config.minimum_power_ratio
            )
            expect(chosen).to.equal(better)
            expect(slot).to.equal(2)
        end)
        it(
            "handles sparse slots and replaces surplus support before a stronger attacker",
            function()
                local roster = { [2] = pet(5, "support"), [4] = pet(10, "support"), [5] = pet(100) }
                local _, slot = Draft.selectUpgrade({ pet(50) }, roster, config.minimum_power_ratio)
                expect(slot).to.equal(2)
                roster[2] = nil
                expect(Draft.selectUpgrade({ pet(50) }, roster, config.minimum_power_ratio)).to.equal(
                    nil
                )
            end
        )
        it("never replaces a Huge with an ordinary pet", function()
            expect(
                Draft.selectUpgrade(
                    { pet(1000) },
                    { pet(10, "melee", true) },
                    config.minimum_power_ratio
                )
            ).to.equal(nil)
        end)
        it("has a finite upgrade budget and uses the normal reinforcement cadence", function()
            expect(config.enabled).to.equal(true)
            expect(config.attempts_per_slot).to.equal(1)
            local source = readFile("src/Server/Services/MergeDefenseRefreshRuntime.lua")
            expect(source:find("_rollDraftedPrototypePet", 1, true)).to.equal(nil)
            expect(source:find("GrantPet", 1, true)).to.equal(nil)
            expect(source:find("strongerRefreshRemaining -= 1", 1, true)).to.be.ok()
            expect(source:find("replacementQueue", 1, true)).to.be.ok()
        end)
    end)
end
