local PlaceRuntime = loadModule("src/Shared/Game/PlaceRuntime.lua")

describe("PlaceRuntime", function()
    local config = {
        default_role = "main",
        roles = {
            main = { place_ids = { 101 } },
            merge = { place_ids = { 202 } },
        },
    }

    it("routes configured published places", function()
        expect(PlaceRuntime.roleFor(101, config)).to.equal("main")
        expect(PlaceRuntime.roleFor(202, config)).to.equal("merge")
        expect(PlaceRuntime.isMerge(202, config)).to.equal(true)
        expect(PlaceRuntime.placeIdForRole(config, "merge")).to.equal(202)
    end)

    it("raises only Merge base movement while preserving bonuses and board cruising", function()
        local places = loadModule("configs/places.lua")
        local gameConfig = loadModule("configs/game.lua")
        local board = loadModule("src/Shared/Game/HoverboardLogic.lua")
        local merge = PlaceRuntime.placeIdForRole(places, "merge")
        local main = PlaceRuntime.placeIdForRole(places, "main")
        local base = PlaceRuntime.walkSpeedFor(merge, places, gameConfig)
        expect(base).to.equal(24)
        expect(PlaceRuntime.walkSpeedFor(main, places, gameConfig)).to.equal(16)
        expect(PlaceRuntime.walkSpeedFor(0, places, gameConfig)).to.equal(16)
        expect(base * 2).to.equal(48)
        expect(PlaceRuntime.walkSpeedFor(merge, places, gameConfig, 2)).to.equal(48)
        expect(board.mountedSpeed(base, 1, 64, 1)).to.equal(64)
        expect(board.mountedSpeed(base, 2, 64, 0.2)).to.equal(48)
    end)

    it("accepts numeric strings without consulting map contents", function()
        expect(PlaceRuntime.roleFor("202", config)).to.equal("merge")
    end)

    it("falls back to the configured default for unpublished local places", function()
        expect(PlaceRuntime.roleFor(0, config)).to.equal("main")
        expect(PlaceRuntime.roleFor(nil, config)).to.equal("main")
    end)
end)
