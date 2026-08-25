local HealingSuppression = loadModule("src/Shared/Game/HealingSuppression.lua")

describe("HealingSuppression", function()
    it("is active only before its expiry", function()
        expect(HealingSuppression.isActive(103, 100)).to.equal(true)
        expect(HealingSuppression.isActive(100, 100)).to.equal(false)
        expect(HealingSuppression.isActive(nil, 100)).to.equal(false)
    end)

    it("extends without shortening a stronger live application", function()
        expect(HealingSuppression.extend(0, 100, 3)).to.equal(103)
        expect(HealingSuppression.extend(110, 100, 3)).to.equal(110)
        expect(HealingSuppression.extend(0, 100, -4)).to.equal(100)
    end)

    it("reports non-negative time remaining", function()
        expect(HealingSuppression.remaining(104, 100)).to.equal(4)
        expect(HealingSuppression.remaining(99, 100)).to.equal(0)
    end)

    it("owns the replicated status attribute name", function()
        expect(HealingSuppression.ATTRIBUTE).to.equal("HealSuppressedUntil")
    end)
end)
