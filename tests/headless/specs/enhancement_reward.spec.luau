local EnhancementReward = loadModule("src/Shared/Game/EnhancementReward.lua")

local config = {
    origins = { "geo", "pyro", "cryo" },
    types = { damage = {}, recharge = {} },
    drops = {
        type_weights = { damage = 3, recharge = 1 },
        levels = { min = 5, max = 50 },
    },
}

local function sequence(values)
    local index = 0
    return function()
        index += 1
        return values[index] or 0
    end
end

return function()
    describe("EnhancementReward", function()
        it("rolls an immediately usable single-origin record at the player's band", function()
            local record = EnhancementReward.roll(config, "pyro", 22, "single", sequence({ 0 }))
            expect(record.type).to.equal("damage")
            expect(record.origins[1]).to.equal("pyro")
            expect(#record.origins).to.equal(1)
            expect(record.level).to.equal(22)
        end)

        it("rolls a dual with the player origin first and another origin second", function()
            local record =
                EnhancementReward.roll(config, "pyro", 99, "dual", sequence({ 0.99, 0.99 }))
            expect(record.type).to.equal("recharge")
            expect(record.origins[1]).to.equal("pyro")
            expect(record.origins[2]).to.equal("cryo")
            expect(record.level).to.equal(50)
        end)

        it("rejects absent and unknown player origins", function()
            local absent, absentReason = EnhancementReward.roll(config, nil, 1, "single")
            local unknown, unknownReason = EnhancementReward.roll(config, "sand", 1, "dual")
            expect(absent).to.equal(nil)
            expect(absentReason).to.equal("no_origin")
            expect(unknown).to.equal(nil)
            expect(unknownReason).to.equal("unknown_origin")
        end)
    end)
end
