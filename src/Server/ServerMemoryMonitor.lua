local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Diagnostics = require(script.Parent.ServerMemoryDiagnostics)
local Monitor = {}

local function workload()
    local result = { players = #Players:GetPlayers(), petModels = 0, petFolders = 0, bays = {} }
    local pets = Workspace:FindFirstChild("PlayerPets")
    for _, folder in ipairs(pets and pets:GetChildren() or {}) do
        result.petFolders += 1
        for _, pet in ipairs(folder:GetChildren()) do
            if pet:IsA("Model") then
                result.petModels += 1
            end
        end
    end
    local maps = Workspace:FindFirstChild("Maps")
    local realm = maps and maps:FindFirstChild("MergeEggRealm")
    local bays = realm and realm:FindFirstChild("Bays")
    for _, bay in ipairs(bays and bays:GetChildren() or {}) do
        if (bay:GetAttribute("MergeEggBayOwnerUserId") or 0) ~= 0 then
            table.insert(result.bays, {
                id = bay:GetAttribute("MergeEggBayId"),
                wave = bay:GetAttribute("CurrentWave"),
                activeEnemies = bay:GetAttribute("ActiveEnemies"),
                replacements = bay:GetAttribute("ReplacementsHatched"),
            })
        end
    end
    return result
end

function Monitor.start(config)
    if not config or config.enabled ~= true then
        return nil
    end
    local diagnostics = Diagnostics.new(config, {
        clock = os.clock,
        utc = os.time,
        gcKb = gcinfo,
        age = function()
            return Workspace.DistributedGameTime
        end,
        stats = Stats,
        tags = Enum.DeveloperMemoryTag:GetEnumItems(),
        workload = workload,
        identity = {
            side = "Server",
            memoryScope = RunService:IsStudio() and "shared_studio_process" or "live_server",
            jobId = game.JobId,
            placeId = game.PlaceId,
            placeVersion = game.PlaceVersion,
        },
    })
    -- Server-only inspection; no client RemoteFunction, datastore or external telemetry sink.
    local control = Instance.new("BindableFunction")
    control.Name = "ServerMemoryDiagnostics"
    control.OnInvoke = function(action)
        return diagnostics:snapshot(action == "history")
    end
    control.Parent = ServerStorage
    local handle = {}
    function handle:sample()
        local row = diagnostics:sample()
        if row then
            print("[ServerMemory] " .. HttpService:JSONEncode(row))
        end
    end
    handle:sample()
    return handle
end

return Monitor
