local Policy = loadModule("src/Shared/Game/CrossroadsHostPolicy.lua")
local config = loadModule("configs/crossroads_hosts.lua")
local function player(id, gate, activity, egg, alive)
    return {
        id = id,
        gateDistance = gate,
        activityDistance = activity,
        eggDistance = egg or math.huge,
        alive = alive ~= false,
        inCrossroads = true,
    }
end
return function()
    describe("Shared Crossroads hosts", function()
        it("leaves a fight for another player at the gate", function()
            local a = player(1, 120, 0)
            local b = player(2, 12, 100)
            local selected = Policy.choose(
                { a, b },
                { id = 1, activity = "activity" },
                config,
                false
            )
            expect(selected.id).to.equal(2)
            expect(selected.activity).to.equal("gate")
        end)
        it("returns to watching after the visitor leaves", function()
            local selected = Policy.choose(
                { player(1, 120, 0), player(2, 80, 120) },
                { id = 2, activity = "gate" },
                config,
                false
            )
            expect(selected.id).to.equal(1)
            expect(selected.activity).to.equal("activity")
        end)
        it("serves a new visitor before a lingering greeted player", function()
            local a, b = player(1, 5, 120), player(2, 20, 120)
            a.served = true
            local selected = Policy.choose({ a, b }, { id = 1, activity = "gate" }, config, false)
            expect(selected.id).to.equal(2)
        end)
        it("keeps an ongoing greeting steady inside the exit radius", function()
            local selected = Policy.choose(
                { player(1, 30, 100), player(2, 20, 100) },
                { id = 1, activity = "gate" },
                config,
                false
            )
            expect(selected.id).to.equal(1)
        end)
        it("prioritizes an egg visit over garden spectators, but gates come first", function()
            local a, b, c = player(1, 100, 0), player(2, 100, 20, 5), player(3, 10, 100)
            expect(Policy.choose({ a, b }, nil, config, true).activity).to.equal("egg")
            expect(Policy.choose({ a, b, c }, nil, config, true).id).to.equal(3)
        end)
        it("ignores dead, distant and departed players", function()
            local a, b, c = player(1, 2, 0, 0, false), player(2, 100, 100), player(3, 2, 0)
            c.inCrossroads = false
            expect(Policy.choose({ a, b, c }, nil, config, true)).to.equal(nil)
        end)
    end)
end
