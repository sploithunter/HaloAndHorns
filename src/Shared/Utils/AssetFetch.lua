--[[
    AssetFetch — cache-first replacement for InsertService:LoadAsset.

    GROUP-MIGRATION SEAM (Jason, 2026-06-11): InsertService:LoadAsset only loads
    assets owned by the experience's owner. The game's 67 model assets (pets,
    crystals, eggs) are owned by Jason's USER account, so a group-owned experience
    could never load them at runtime. The models were pulled INTO the place under
    ServerStorage.PlaceAssets/<assetId> (each child is the exact container
    LoadAsset would have returned); this helper clones from that server-only cache
    first and falls back to live InsertService for anything not cached (dev/testing).

    Client previews use the bounded owner warm cache instead. Their legacy calls
    are still allowed to fail into an image/emoji fallback without making all 76
    source containers resident on every client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local AssetFetch = {}

function AssetFetch.load(assetId)
    local id = tonumber(assetId)
    if not id then
        error("AssetFetch.load: bad asset id " .. tostring(assetId))
    end
    local folder = nil
    if RunService:IsServer() then
        folder = ServerStorage:FindFirstChild("PlaceAssets")
            or ReplicatedStorage:FindFirstChild("PlaceAssets") -- migration-safe fallback
    else
        folder = ReplicatedStorage:FindFirstChild("PlaceAssets") -- legacy Studio captures
    end
    local cached = folder and folder:FindFirstChild(tostring(id))
    if cached then
        return cached:Clone()
    end
    return InsertService:LoadAsset(id)
end

return AssetFetch
