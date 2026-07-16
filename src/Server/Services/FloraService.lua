--[[
    FloraService — realm restyling via FloraAnchor markers (Jason 2026-07-16:
    "a part on the floor of every tree, every cactus... quickly replace
    things to change styles for heaven and hell").

    Authored flora models (Maps.<Layer>) are TAGGED `FloraAnchor` with
    Kind/Variant attributes — the authored place remains the layout SSOT.
    At boot, every tagged model whose (layer, kind, variant) resolves to a
    replacement in configs/flora.lua is swapped in place: clone the themed
    model from ReplicatedStorage.Assets.Models.Flora, ground it on the
    original's footprint (bottom-center + yaw preserved), destroy the
    original INSTANCE (place file untouched). No config entry = original
    stays. Missing replacement models WARN loudly (loud-validation).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FloraTheme = require(ReplicatedStorage.Shared.Game.FloraTheme)

local TAG = "FloraAnchor"

local FloraService = {}
FloraService.__index = FloraService

function FloraService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._config = self._configLoader and self._configLoader:LoadConfig("flora") or {}
end

function FloraService:_log(level, msg, data)
    if self._logger then
        self._logger[level](self._logger, "[Flora] " .. msg, data)
    end
end

-- layer id from Maps ancestry: Maps.Heaven_2 -> "heaven_2"; Maps.Home -> "base"
local function layerOf(inst)
    local node = inst
    while node and node ~= workspace do
        local parent = node.Parent
        if parent and parent.Name == "Maps" then
            local n = node.Name
            if n == "Home" then
                return "base"
            end
            return n:lower()
        end
        node = parent
    end
    return nil
end

-- bottom-center + yaw of a model/part footprint
local function footprintOf(inst)
    local cf, size
    if inst:IsA("Model") then
        cf, size = inst:GetBoundingBox()
    else
        cf, size = inst.CFrame, inst.Size
    end
    local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
    local look = cf.LookVector
    local yaw = math.atan2(-look.X, -look.Z)
    return bottom, yaw, size
end

function FloraService:_replace(anchor, modelName, floraFolder)
    local template = floraFolder and floraFolder:FindFirstChild(modelName)
    if not template then
        self:_log("Warn", "replacement model MISSING in Assets.Models.Flora", {
            model = modelName,
            anchor = anchor:GetFullName(),
        })
        return false
    end
    local bottom, yaw, oldSize = footprintOf(anchor)
    local clone = template:Clone()
    local _, size = clone:GetBoundingBox()
    -- scale the clone's footprint height to the authored one (style swaps
    -- shouldn't change the world's silhouette drastically)
    local scale = oldSize.Y / math.max(size.Y, 0.001)
    if math.abs(scale - 1) > 0.05 and clone.ScaleTo then
        pcall(function()
            clone:ScaleTo(math.clamp(scale, 0.2, 5))
        end)
        _, size = clone:GetBoundingBox()
    end
    clone:PivotTo(
        CFrame.new(bottom + Vector3.new(0, size.Y / 2, 0))
            * CFrame.Angles(0, yaw, 0)
            * (clone:GetPivot() - clone:GetPivot().Position):Inverse()
    )
    clone.Name = anchor.Name .. "_themed"
    clone.Parent = anchor.Parent
    anchor:Destroy()
    return true
end

function FloraService:Start()
    local models = ReplicatedStorage:FindFirstChild("Assets")
    models = models and models:FindFirstChild("Models")
    local floraFolder = models and models:FindFirstChild("Flora")
    local swapped, kept, missing = 0, 0, 0
    for _, anchor in ipairs(CollectionService:GetTagged(TAG)) do
        if anchor:IsDescendantOf(workspace) then
            local kind = anchor:GetAttribute("Kind")
            local variant = anchor:GetAttribute("Variant")
            local layerId = layerOf(anchor)
            local modelName = kind
                and FloraTheme.resolve(self._config, layerId, kind, variant)
            if modelName then
                if self:_replace(anchor, modelName, floraFolder) then
                    swapped += 1
                else
                    missing += 1
                end
            else
                kept += 1
            end
        end
    end
    self:_log("Info", "flora themed", { swapped = swapped, kept = kept, missing = missing })
end

return FloraService
