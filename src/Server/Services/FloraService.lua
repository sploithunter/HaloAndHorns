--[[
    FloraService — flora as SPAWNABLE items on floor anchors (Jason
    2026-07-16: "find a tree, project down to the floor, set an invisible
    anchored part there and label it — treat the trees, cactuses etc. as
    spawnable items — easy to reskin").

    The map carries only invisible FloraAnchor PARTS (tagged, at true floor
    level, attrs Kind/Variant/Scale, yaw in the part CFrame) — the 280
    authored flora models were harvested into
    ReplicatedStorage.Assets.Models.Flora (one exemplar per Variant = the
    DEFAULT skin) and then replaced by anchors (2026-07-16 migration).

    At boot every anchor spawns a model:
      1. configs/flora.lua override (FloraTheme precedence: layer-variant >
         layer-kind > realm-variant > realm-kind), else
      2. the Variant's default from Assets.Models.Flora.

    Spawns match the authored height (Scale attribute) and yaw, bottom on
    the anchor's floor point. Missing models WARN loudly. The world looks
    identical with an empty config — restyles are pure config changes.
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

function FloraService:_spawnAt(anchor, floraFolder)
    local kind = anchor:GetAttribute("Kind")
    local variant = anchor:GetAttribute("Variant")
    if not (kind and variant) then
        self:_log("Warn", "anchor missing Kind/Variant attributes", { anchor = anchor:GetFullName() })
        return false
    end
    local layerId = layerOf(anchor)
    local modelName = FloraTheme.resolve(self._config, layerId, kind, variant) or variant
    local template = floraFolder and floraFolder:FindFirstChild(modelName)
    if not template then
        self:_log("Warn", "flora model MISSING in Assets.Models.Flora", {
            model = modelName,
            variant = variant,
            anchor = anchor:GetFullName(),
        })
        return false
    end
    local clone = template:Clone()
    -- harvested exemplars carry UNRELIABLE pivots (some offset a full ±2000/
    -- ±4000-stud layer height from their geometry — the 2026-07-16 floating
    -- ice pines). ScaleTo scales ABOUT the pivot and PivotTo places the
    -- pivot, so both compound that garbage. Explicit pivot at the bounding-
    -- box center first; never trust a stored pivot here.
    local bboxCf, size = clone:GetBoundingBox()
    clone.WorldPivot = CFrame.new(bboxCf.Position)
    local targetH = tonumber(anchor:GetAttribute("Scale"))
    if targetH and size.Y > 0.001 then
        local scale = targetH / size.Y
        if math.abs(scale - 1) > 0.05 then
            pcall(function()
                clone:ScaleTo(math.clamp(scale, 0.2, 5))
            end)
            local newCf, newSize = clone:GetBoundingBox()
            clone.WorldPivot = CFrame.new(newCf.Position)
            size = newSize
        end
    end
    -- anchor sits 0.2 above the raycast floor; plant the model's bottom there
    local floorPos = anchor.Position - Vector3.new(0, 0.2, 0)
    local yaw = select(2, anchor.CFrame:ToEulerAnglesYXZ())
    -- variety kinds get a DETERMINISTIC random yaw (position-seeded: stable
    -- across boots); trees etc. keep the authored anchor rotation
    local randomKinds = self._config.random_yaw_kinds
    if type(randomKinds) == "table" and randomKinds[kind] then
        local seed = math.floor(anchor.Position.X * 73856093)
            + math.floor(anchor.Position.Z * 19349663)
        yaw = (seed % 6283) / 1000 -- 0 .. 2*pi
    end
    clone:PivotTo(CFrame.new(floorPos + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0))
    clone.Name = "Flora_" .. modelName
    clone.Parent = anchor.Parent
    return true
end

function FloraService:Start()
    local models = ReplicatedStorage:FindFirstChild("Assets")
    models = models and models:FindFirstChild("Models")
    local floraFolder = models and models:FindFirstChild("Flora")
    if not floraFolder then
        self:_log("Warn", "Assets.Models.Flora missing — no flora spawned")
        return
    end
    local spawned, failed = 0, 0
    for _, anchor in ipairs(CollectionService:GetTagged(TAG)) do
        if anchor:IsDescendantOf(workspace) and anchor:IsA("BasePart") then
            if self:_spawnAt(anchor, floraFolder) then
                spawned += 1
            else
                failed += 1
            end
        end
    end
    self:_log(failed > 0 and "Warn" or "Info", "flora spawned", {
        spawned = spawned,
        failed = failed,
    })
end

return FloraService
