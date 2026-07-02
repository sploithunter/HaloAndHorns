--[[
    PowerDescribe — [unit] every live power gets a derived description; spot-check the wording.
    Run: mise run test-headless
]]

local PowerDescribe = loadModule("src/Shared/Game/PowerDescribe.lua")
local powersCfg = loadModule("configs/powers.lua")

return function()
    describe("coverage (the reason this module exists)", function()
        it("EVERY power in the live config describes — summary + no raw fallback", function()
            local missing = {}
            for id in pairs(powersCfg.powers) do
                local d = PowerDescribe.describe(powersCfg, id)
                if not d or type(d.summary) ~= "string" or #d.summary < 8 then
                    missing[#missing + 1] = id
                elseif d.summary == "A mysterious power." then
                    -- subtitle fallback is fine; the LAST-resort string means a family went
                    -- untemplated AND the def has no subtitle — fix FAMILY_TEXT when this fires
                    missing[#missing + 1] = id .. " (last-resort fallback)"
                end
            end
            if #missing > 0 then
                error("undescribed powers: " .. table.concat(missing, ", "))
            end
        end)

        it("unknown power returns nil", function()
            expect(PowerDescribe.describe(powersCfg, "nope")).to.equal(nil)
        end)
    end)

    describe("wording spot-checks (numbers come from the live config)", function()
        it("armor power reads Defense + duration + costs", function()
            local d = PowerDescribe.describe(powersCfg, "stone_skin")
            expect(d.summary:find("Defense") ~= nil).to.equal(true)
            expect(d.summary:find("one pet") ~= nil).to.equal(true)
            local joined = table.concat(d.lines, " | ")
            expect(joined:find("Lasts") ~= nil).to.equal(true)
            expect(joined:find("Focus") ~= nil).to.equal(true)
            expect(joined:find("Recharge") ~= nil).to.equal(true)
        end)

        it("fraction magnitudes read as percents (Prospector +50% coins)", function()
            local d = PowerDescribe.describe(powersCfg, "prospector")
            expect(d.summary:find("50%%") ~= nil).to.equal(true)
            expect(d.summary:find("coins") ~= nil).to.equal(true)
        end)

        it("multiplier magnitudes read as the BONUS (x1.3 damage buff -> +30%)", function()
            -- find any damage_buff power in the live config (x1.3 since the balance-audit
            -- team-buff swap: geo's Mountain's Strength trimmed so the tank doesn't out-buff pyro)
            local id
            for pid, def in pairs(powersCfg.powers) do
                local kind = powersCfg.effect_kinds[def.effect]
                if kind and kind.family == "buff" then
                    id = pid
                    break
                end
            end
            if id then
                local d = PowerDescribe.describe(powersCfg, id)
                expect(d.summary:find("+30%%") ~= nil).to.equal(true)
            end
        end)

        it("passives say always-on and hide cast costs", function()
            -- any passive kind power (Swift/Hasten/Magnet/XP Surge)
            local id
            for pid, def in pairs(powersCfg.powers) do
                local kind = powersCfg.effect_kinds[def.effect]
                if kind and kind.passive then
                    id = pid
                    break
                end
            end
            expect(id ~= nil).to.equal(true)
            local d = PowerDescribe.describe(powersCfg, id)
            expect(d.lines[1]).to.equal("Always on while owned")
            expect(#d.lines).to.equal(1)
        end)

        it("hand-written def.description overrides the derived summary", function()
            local cfg = {
                powers = {
                    x = { effect = "shield", description = "My custom words.", focus_cost = 10 },
                },
                effect_kinds = { shield = { family = "absorb", magnitude = 40, duration = 12 } },
            }
            local d = PowerDescribe.describe(cfg, "x")
            expect(d.summary).to.equal("My custom words.")
            expect(d.lines[1]).to.equal("Lasts 12s") -- stat lines still derived
        end)

        it("long cooldowns read in minutes (Luck: 5m recharge)", function()
            local d = PowerDescribe.describe(powersCfg, "fortune")
            expect(table.concat(d.lines, " "):find("Recharge 5m") ~= nil).to.equal(true)
        end)
    end)
end
