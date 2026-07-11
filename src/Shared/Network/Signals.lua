local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wally packages are placed in ReplicatedStorage.Packages by our Rojo project file
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Net = require(Packages:WaitForChild("Net"))
local NetworkManifest = require(script.Parent.NetworkManifest)
local SignalRegistry = require(script.Parent.SignalRegistry)
local networkConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("network"))

local manifestOk, manifestError = NetworkManifest.validate(networkConfig)
assert(manifestOk, "Invalid network manifest: " .. tostring(manifestError))

-- Central registry of RemoteEvents used by client/server.
return SignalRegistry.build(networkConfig, Net)
