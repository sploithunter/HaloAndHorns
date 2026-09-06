local powers = loadModule("configs/powers.lua")
local focus = loadModule("configs/focus.lua")
local Upkeep = loadModule("src/Shared/Game/FocusUpkeep.lua")
local Focus = loadModule("src/Shared/Game/FocusMath.lua")
local ids = { "swift", "magnet", "xp_surge", "prospector", "windfall", "fortune" }

return function()
    describe("Early utility toggle focus budget", function()
        it("keeps all six unenhanced buffs just under base recovery", function()
            local rates = {}
            for _, id in ipairs(ids) do
                local def = powers.powers[id]
                expect(powers.effect_kinds[def.effect].passive).to.equal(true)
                expect(def.focus_upkeep > 0).to.equal(true)
                rates[#rates + 1] = Upkeep.effectiveRate(def.focus_upkeep, 0)
            end
            local rate = Upkeep.total(rates)
            expect(math.abs(rate - 2.4) < 0.00001).to.equal(true)
            expect(rate < focus.regen_per_second).to.equal(true)
            expect(focus.regen_per_second - rate < 0.11).to.equal(true)
            local pool = 50
            for _ = 1, 3600 do
                local step = Upkeep.step(pool, rate, 0.1)
                expect(step.crashed).to.equal(false)
                pool = Focus.regen(step.focus, 0.1, focus)
            end
            expect(pool > 50).to.equal(true)
        end)

        it("retains potency and leaves Huge Fortune a timed cast", function()
            expect(powers.effect_kinds.coin_yield.magnitude).to.equal(0.5)
            expect(powers.effect_kinds.windfall.magnitude).to.equal(2)
            expect(powers.effect_kinds.luck.magnitude).to.equal(0.5)
            expect(powers.effect_kinds.luck_huge.passive).never.to.be.ok()
            expect(powers.effect_kinds.luck_huge.duration > 0).to.equal(true)
        end)

        it("provides server toggles and clickable owned badges for the new channels", function()
            local server = readFile("src/Server/Services/PowerService.lua")
            local client = readFile("src/Client/Systems/PlayerPowerBadges.lua")
            for _, pair in ipairs({
                { "coin_yield", "CoinYieldPower" },
                { "drop_rate", "DropRateBuff" },
                { "luck", "LuckBuff" },
            }) do
                expect(server:find(pair[1] .. ' = "' .. pair[2] .. '"', 1, true)).to.be.ok()
                local row = client:match('attr = "' .. pair[2] .. '"[^\n]+')
                expect(row and row:find("toggleable = true", 1, true)).to.be.ok()
            end
        end)

        it("focus enhancements reduce drain without making a running power free", function()
            for _, id in ipairs(ids) do
                local base = powers.powers[id].focus_upkeep
                local enhanced = Upkeep.effectiveRate(base, 1)
                expect(enhanced > 0 and enhanced < base).to.equal(true)
            end
        end)
    end)
end
