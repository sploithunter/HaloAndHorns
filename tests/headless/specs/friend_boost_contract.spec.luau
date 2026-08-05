local serviceSource = readFile("src/Server/Services/FriendBoostService.lua")
local progressionSource = readFile("src/Server/Services/PlayerProgressionService.lua")
local combatSource = readFile("src/Server/Services/CombatService.lua")
local configLoaderSource = readFile("src/Shared/ConfigLoader.lua")
local events = loadModule("configs/events.lua")
local gameEvents = loadModule("configs/game_events.lua")

return function()
    describe("Friend Boost runtime contract", function()
        it("uses server friendship checks and stamps one authoritative aggregate", function()
            expect(serviceSource:find(":IsFriendsWith", 1, true)).never.to.equal(nil)
            expect(serviceSource:find('SetAttribute("FriendBoostCount"', 1, true)).never.to.equal(
                nil
            )
        end)

        it("feeds hatch luck, all XP, mining coins, and combat coins", function()
            expect(serviceSource:find('context.kind == "hatch_luck"', 1, true)).never.to.equal(nil)
            expect(serviceSource:find('context.kind == "breakable_reward"', 1, true)).never.to.equal(
                nil
            )
            expect(progressionSource:find('GetAttribute("FriendXPBonus")', 1, true)).never.to.equal(
                nil
            )
            expect(combatSource:find('kind = "earned_currency"', 1, true)).never.to.equal(nil)
        end)

        it("surfaces the launch promotion without consuming Hatch Luck Hour", function()
            expect(events.global_events.friend_boost_launch).never.to.equal(nil)
            expect(events.scheduled_global_events.friend_boost_launch).never.to.equal(nil)
            expect(events.global_events.hatch_luck_hour).never.to.equal(nil)
            expect(gameEvents.friend_boost_active.banner.seconds).to.equal(8)
        end)

        it("accepts the weekday-free schedule as an every-day launch event", function()
            local schedule = events.scheduled_global_events.friend_boost_launch
            expect(schedule.weekdays).to.equal(nil)
            expect(schedule.weekdays_utc).to.equal(nil)
            expect(
                configLoaderSource:find(
                    "if weekdays ~= nil and not isArray(weekdays) then",
                    1,
                    true
                )
            ).never.to.equal(nil)
        end)

        it("celebrates level-earned pet slots through the same banner system", function()
            expect(gameEvents.pet_slot_awarded.banner.seconds).to.equal(8)
            expect(progressionSource:find('fireGameEvent(player, "pet_slot_awarded"', 1, true)).never.to.equal(
                nil
            )
        end)
    end)
end
