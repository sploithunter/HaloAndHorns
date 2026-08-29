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

    it("accepts numeric strings without consulting map contents", function()
        expect(PlaceRuntime.roleFor("202", config)).to.equal("merge")
    end)

    it("falls back to the configured default for unpublished local places", function()
        expect(PlaceRuntime.roleFor(0, config)).to.equal("main")
        expect(PlaceRuntime.roleFor(nil, config)).to.equal("main")
    end)
end)
