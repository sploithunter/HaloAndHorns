--[[
    AssetFetch — cache-first replacement for InsertService:LoadAsset.

    GROUP-MIGRATION SEAM (Jason, 2026-06-11): InsertService:LoadAsset only loads
    assets owned by the experience's owner. The game's 67 model assets (pets,
    crystals, eggs) are owned by Jason's USER account, so a group-owned experience
    could never load them at runtime. The models were pulled INTO the place under
    ReplicatedStorage.PlaceAssets/<assetId> (each child is the exact container
    LoadAsset would have returned); this helper clones from that cache first and
    falls back to live InsertService for anything not cached (dev/testing).

    Bonus: cache hits work on the CLIENT too (LoadAsset is server-flavored), and
    cost zero asset-fetch time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local AssetFetch = {}

function AssetFetch.load(assetId)
    local id = tonumber(assetId)
    if not id then
        error("AssetFetch.load: bad asset id " .. tostring(assetId))
    end
    local folder = ReplicatedStorage:FindFirstChild("PlaceAssets")
    local cached = folder and folder:FindFirstChild(tostring(id))
    if cached then
        return cached:Clone()
    end
    return InsertService:LoadAsset(id)
end

return AssetFetch
