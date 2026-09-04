local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wally packages are placed in ReplicatedStorage.Packages by our Rojo project file
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Net = require(Packages:WaitForChild("Net"))
local NetworkManifest = require(script.Parent.NetworkManifest)
local SignalRegistry = require(script.Parent.SignalRegistry)
local RuntimeTransport = require(script.Parent.RuntimeTransport)
local networkConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("network"))

local manifestOk, manifestError = NetworkManifest.validate(networkConfig)
assert(manifestOk, "Invalid network manifest: " .. tostring(manifestError))

local environment = RunService:IsStudio() and "studio" or "production"
local transport = RuntimeTransport.new(Net, ReplicatedStorage)

-- Central registry of RemoteEvents and RemoteFunctions used by client/server.
local signals = SignalRegistry.build(networkConfig, transport, { environment = environment })
local batchConfig = networkConfig.combat_presentation
if batchConfig and batchConfig.enabled then
    local batching = require(script.Parent.PresentationBatchTransport)
    if RunService:IsServer() then
        local players = game:GetService("Players")
        local audience = require(script.Parent.CombatPresentationAudience).new(batchConfig, players)
        batching.installServer(signals, batchConfig, players, RunService.Heartbeat, audience)
    else
        batching.installClient(signals, batchConfig)
    end
end
return signals
