-- Canonical access to dormant 3D templates.
--
-- The server owns the complete catalog in ServerStorage so hundreds of unused textures are not
-- permanent client references. Clients intentionally see live Workspace clones, flat UI art, and
-- the bounded owner-only warm shelf assembled under PlayerGui for their current/next Merge eggs. A
-- legacy replicated Models folder remains a development fallback while old Studio places migrate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

return ModelTemplateStore
