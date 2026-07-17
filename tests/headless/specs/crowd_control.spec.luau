--[[
    CrowdControl — [unit] shared root/hold timing semantics.
    Run: mise run test-headless
]]

local CrowdControl = loadModule("src/Shared/Game/CrowdControl.lua")

return function()
    describe("CrowdControl full-hold semantics", function()
        it("blocks actions only while the hold is active", function()
            expect(CrowdControl.isHeld(101, 100)).to.equal(true)
            expect(CrowdControl.canAct(101, 100)).to.equal(false)
            expect(CrowdControl.isHeld(100, 100)).to.equal(false)
            expect(CrowdControl.canAct(100, 100)).to.equal(true)
        end)

        it("immobilizes on either a root or a hold", function()
            expect(CrowdControl.isImmobilized(101, 0, 100)).to.equal(true)
            expect(CrowdControl.isImmobilized(0, 101, 100)).to.equal(true)
            expect(CrowdControl.isImmobilized(100, 100, 100)).to.equal(false)
        end)

        it("makes disarm an action lock without making it a movement lock", function()
            expect(CrowdControl.isDisarmed(101, 100)).to.equal(true)
            expect(CrowdControl.canTakeAction(0, 101, 100)).to.equal(false)
            expect(CrowdControl.isImmobilized(0, 0, 100)).to.equal(false)
            expect(CrowdControl.canTakeAction(0, 100, 100)).to.equal(true)
        end)

        it("refreshes without shortening a stronger existing hold", function()
            expect(CrowdControl.extend(120, 100, 8)).to.equal(120)
            expect(CrowdControl.extend(0, 100, 8)).to.equal(108)
            expect(CrowdControl.extend(105, 100, 8)).to.equal(108)
        end)
    end)
end
