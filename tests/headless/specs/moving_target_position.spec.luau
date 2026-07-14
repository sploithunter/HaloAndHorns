local MovingTargetPosition = loadModule("src/Shared/Game/MovingTargetPosition.lua")

describe("MovingTargetPosition.resolve", function()
    it("uses the server-published position for a moving enemy", function()
        local moving = { x = 20, y = 4, z = -8 }
        local stalePrimary = { x = 0, y = 4, z = 0 }
        local stalePivot = { x = 0, y = 4, z = 0 }
        expect(MovingTargetPosition.resolve(moving, stalePrimary, stalePivot)).to.equal(moving)
    end)

    it("uses the primary part for a static breakable", function()
        local primary = { x = 12, y = 2, z = 9 }
        local pivot = { x = 11, y = 2, z = 9 }
        expect(MovingTargetPosition.resolve(nil, primary, pivot)).to.equal(primary)
    end)

    it("falls back to the model pivot when there is no primary part", function()
        local pivot = { x = -3, y = 1, z = 7 }
        expect(MovingTargetPosition.resolve(nil, nil, pivot)).to.equal(pivot)
    end)
end)
