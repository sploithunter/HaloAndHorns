local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wally packages are placed in ReplicatedStorage.Packages by our Rojo project file
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Net = require(Packages:WaitForChild("Net"))
local NetworkManifest = require(script.Parent.NetworkManifest)
local SignalRegistry = require(script.Parent.SignalRegistry)
local networkConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("network"))

local manifestOk, manifestError = NetworkManifest.validate(networkConfig)
assert(manifestOk, "Invalid network manifest: " .. tostring(manifestError))

-- Central registry of RemoteEvents used by client/server
local Signals = SignalRegistry.build(networkConfig, Net)

-- Legacy declarations migrate into configs/network.lua in small compatibility slices.
local legacySignals = {
    -- Inventory Management
    InventoryUpdate = Net:RemoteEvent("InventoryUpdate"), -- s->c inventory changed
    ConsumeItem = Net:RemoteEvent("ConsumeItem"), -- c->s consume consumable

    -- Zones / progression
    RealmTravelConfirm = Net:RemoteEvent("RealmTravelConfirm"), -- c->s (player chose Yes -> travel)

    -- Phase 3 stats-derived features
    LeaderboardSnapshotRequest = Net:RemoteEvent("LeaderboardSnapshotRequest"), -- c->s
}

for name, remote in pairs(legacySignals) do
    assert(Signals[name] == nil, "Duplicate network packet declaration: " .. name)
    Signals[name] = remote
end

return Signals
