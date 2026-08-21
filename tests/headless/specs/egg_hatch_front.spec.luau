local EggHatchFront = loadModule("src/Shared/Game/EggHatchFront.lua")

return function()
    describe("EggHatchFront", function()
        it("aims the hatch camera at a +X egg front, not +Z", function()
            local pose = EggHatchFront.cameraPose(1, 0, 1, 10)
            expect(pose.x).to.be.near(10, 0.001)
            expect(math.abs(pose.z)).to.be.near(0, 0.001)
            expect(pose.lookX).to.be.near(-1, 0.001)
        end)

        it("keeps a default look when the egg has no XZ facing", function()
            local lx, lz = EggHatchFront.flatLook(0, 0)
            expect(lx).to.equal(0)
            expect(lz).to.equal(-1)
        end)
    end)
end
