-- Canonical access to dormant 3D templates.
--
-- The server owns the complete catalog in ServerStorage so hundreds of unused textures are not
-- permanent client references. Clients intentionally see live Workspace clones, flat UI art, and
-- the bounded owner-only warm shelf assembled under PlayerGui for their current/next Merge eggs. A
-- legacy replicated Models folder remains a development fallback while old Studio places migrate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local farmConfig = require(ReplicatedStorage.Configs.farm_asset_warmup)

local ModelTemplateStore = {}

local function container()
    if RunService:IsServer() then
        local ServerStorage = game:GetService("ServerStorage")
        local serverAssets = ServerStorage:FindFirstChild("Assets")
        if serverAssets and serverAssets:FindFirstChild("Models") then
            return serverAssets
        end
    else
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        local farmCache = playerGui and playerGui:FindFirstChild(farmConfig.cache_folder)
        if farmCache and farmCache:FindFirstChild("Models") then
            return farmCache
        end
        local warmCache = playerGui and playerGui:FindFirstChild("MergeAssetWarmCache")
        if warmCache and warmCache:FindFirstChild("Models") then
            return warmCache
        end
    end
    return ReplicatedStorage:FindFirstChild("Assets")
end

function ModelTemplateStore.root()
    local assets = container()
    return assets and assets:FindFirstChild("Models") or nil
end

function ModelTemplateStore.waitRoot()
    assert(RunService:IsServer(), "ModelTemplateStore.waitRoot is server-only")
    local ServerStorage = game:GetService("ServerStorage")
    return ServerStorage:WaitForChild("Assets"):WaitForChild("Models")
end

function ModelTemplateStore.child(name)
    local root = ModelTemplateStore.root()
    return root and root:FindFirstChild(name) or nil
end

-- Called only by explicit 3D preview surfaces, not the virtualized flat inventory grid.
-- Missing owned previews are requested from prebuilt server templates, never InsertService.
function ModelTemplateStore.pet(id, variant)
    local function lookup()
        local pets = ModelTemplateStore.child("Pets")
        local family = pets and pets:FindFirstChild(id)
        return family and family:FindFirstChild(variant)
    end
    local existing = lookup()
    if existing or RunService:IsServer() then
        return existing
    end
    local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
    local places = require(ReplicatedStorage.Configs.places)
    if not farmConfig.enabled or not PlaceRuntime.isRole(game.PlaceId, places, "main") then
        return nil
    end
    local Signals = require(ReplicatedStorage.Shared.Network.Signals)
    local ok, accepted = pcall(function()
        return Signals.PetPreviewRequest:InvokeServer({ id = id, variant = variant })
    end)
    if not ok or not accepted then
        return nil
    end
    local deadline = os.clock() + farmConfig.template_wait_seconds
    repeat
        existing = lookup()
        if existing then
            return existing
        end
        RunService.Heartbeat:Wait()
    until os.clock() >= deadline
    return nil
end

return ModelTemplateStore
