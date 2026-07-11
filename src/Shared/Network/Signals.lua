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
return SignalRegistry.build(networkConfig, transport, { environment = environment })
