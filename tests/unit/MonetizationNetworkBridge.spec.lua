--[[
    MonetizationNetworkBridge.spec.lua
    Verifies that the legacy NetworkBridge implementation for the "Monetization" bridge
    behaves as expected.  This is a snapshot test that will pass on the existing
    implementation; after we migrate to sleitnick/Net Signals we will update the same
    expectations to use the new Signal wrappers.

    Expectations covered:
    1. CreateBridge returns the same singleton on repeated calls.
    2. DefinePacket registers the packet so that Fire succeeds.
    3. Fire with a defined packet returns true and does not raise an error.
    4. Fire with an undefined packet raises an error.
--]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- Ensure the Shared / Network hierarchy exists (Rojo provides this in Studio).
    -- In pure Lemur environments the folders may not exist, so create them if needed.
    local Shared = ReplicatedStorage:FindFirstChild("Shared") or Instance.new("Folder")
    Shared.Name = "Shared"
    Shared.Parent = ReplicatedStorage

    local NetworkFolder = Shared:FindFirstChild("Network") or Instance.new("Folder")
    NetworkFolder.Name = "Network"
    NetworkFolder.Parent = Shared

    -- Require the legacy bridge implementation directly from the expected Rojo path.
    local ok, NetworkBridge = pcall(function()
        local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
        if not sharedFolder then
            error("Shared folder not found in ReplicatedStorage")
        end
        return require(sharedFolder.Network.NetworkBridge)
    end)

    it("should be able to require NetworkBridge", function()
        expect(ok).to.equal(true)
        expect(typeof(NetworkBridge)).to.equal("table")
    end)

    -- Guard in case the module isn't found; remaining tests would fail anyway.
    if not ok then
        return
    end

    local bridgeName = "Monetization"
    local packetName = "PurchaseSuccess"

    it("CreateBridge should return a singleton", function()
        local a = NetworkBridge:CreateBridge(bridgeName)
        local b = NetworkBridge:CreateBridge(bridgeName)
        expect(a).to.equal(b)
    end)

    it("DefinePacket should register packet so Fire works", function()
        local bridge = NetworkBridge:CreateBridge(bridgeName)

        -- Define packet only once; subsequent calls should not error
        bridge:DefinePacket(packetName, { rateLimit = 10 })

        -- Call Fire for all players ("all" target); should return true and not error
        local success, result = pcall(function()
            return bridge:Fire("all", packetName, { foo = "bar" })
        end)

        expect(success).to.equal(true)
        expect(result).to.equal(true)
    end)

    it("Fire with undefined packet should error", function()
        local bridge = NetworkBridge:CreateBridge(bridgeName)
        local success, _ = pcall(function()
            bridge:Fire("all", "NonExistentPacket", {})
        end)
        expect(success).to.equal(false)
    end)
end
