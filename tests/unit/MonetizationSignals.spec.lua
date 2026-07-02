--[[
    MonetizationSignals.spec.lua
    Snapshot tests for the sleitnick/Net RemoteEvents used by MonetizationService after migration.

    We only assert that the expected RemoteEvents are created and of the correct class.
    Behavioural tests are handled in MonetizationService.spec; this file guarantees the
    networking surface.
--]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Signals = require(ReplicatedStorage.Shared.Network.Signals)

    local expectedRemoteNames = {
        "InitiatePurchase",
        "GetOwnedPasses",
        "GetProductInfo",
        "PurchaseError",
        "OwnedPasses",
        "ProductInfo",
        "FirstPurchaseBonus",
        "PurchaseSuccess", -- pre-existing
    }

    for _, name in ipairs(expectedRemoteNames) do
        it("should expose RemoteEvent " .. name, function()
            local remote = Signals[name]
            expect(remote).to.be.ok()
            expect(remote.FireClient).to.be.ok()
        end)
    end
end
