--!strict

-- AmbientFaunaService — lightweight, non-combat map life.
--
-- Studio owns tagged AmbientFaunaAnchor parts and their motion attributes.
-- This service clones only Assets.Models.AmbientFauna visuals, disables every
-- interaction/query surface, and applies tiny deterministic hover/ground loops.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AmbientFaunaMotion = require(ReplicatedStorage.Shared.Game.AmbientFaunaMotion)

local TAG = "AmbientFaunaAnchor"
local UPDATE_STEP = 1 / 20

type MotionSpec = {
    radius: number?,
    hover_height: number?,
    bob_height: number?,
    speed: number?,
    phase: number?,
}

type Actor = {
    model: Model,
    basePosition: Vector3,
    motion: string,
    motionSpec: MotionSpec,
}

local AmbientFaunaService = {}
AmbientFaunaService.__index = AmbientFaunaService

function AmbientFaunaService:Init()
    self._logger = self._modules and self._modules.Logger
    self._actors = {} :: { Actor }
    self._elapsed = 0
    self._accumulator = 0
end

function AmbientFaunaService:_log(level, message, data)
    if self._logger then
        self._logger[level](self._logger, "[AmbientFauna] " .. message, data)
    end
end

local function layer3Anchor(anchor: BasePart): boolean
    local node: Instance? = anchor
    while node and node ~= workspace do
        local parent = node.Parent
        if parent and parent.Name == "Maps" then
            return node.Name == "Heaven_3" or node.Name == "Hell_3"
        end
        node = parent
    end
    return false
end

local function visualModel(template: Instance): Model
    local clone = template:Clone()
    if clone:IsA("Model") then
        return clone
    end
    local model = Instance.new("Model")
    clone.Parent = model
    return model
end

function AmbientFaunaService:_spawn(anchor: BasePart, faunaFolder: Instance): boolean
    local modelName = anchor:GetAttribute("ModelName")
    if type(modelName) ~= "string" or modelName == "" then
        self:_log("Warn", "anchor missing ModelName", { anchor = anchor:GetFullName() })
        return false
    end
    local template = faunaFolder:FindFirstChild(modelName)
    if not template then
        self:_log("Warn", "model missing", { model = modelName, anchor = anchor:GetFullName() })
        return false
    end

    local model = visualModel(template)
    model.Name = "AmbientFauna_" .. modelName
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            if descendant:IsA("MeshPart") and descendant.TextureID ~= "" then
                descendant.Color = Color3.new(1, 1, 1)
            end
        end
    end

    local bbox, size = model:GetBoundingBox()
    model.WorldPivot = CFrame.new(bbox.Position)
    local visualSize = math.max(0.5, tonumber(anchor:GetAttribute("VisualSize")) or 2.5)
    local longest = math.max(size.X, size.Y, size.Z)
    if longest > 0.001 then
        model:ScaleTo(math.clamp(visualSize / longest, 0.2, 5))
        bbox, size = model:GetBoundingBox()
        model.WorldPivot = CFrame.new(bbox.Position)
    end

    local floor = anchor.Position - Vector3.new(0, 0.2, 0)
    local actor: Actor = {
        model = model,
        basePosition = floor + Vector3.new(0, size.Y / 2, 0),
        motion = tostring(anchor:GetAttribute("Motion") or "ground"),
        motionSpec = {
            radius = tonumber(anchor:GetAttribute("MoveRadius")) or 2,
            hover_height = tonumber(anchor:GetAttribute("HoverHeight")) or 0,
            bob_height = tonumber(anchor:GetAttribute("BobHeight")) or 0.08,
            speed = tonumber(anchor:GetAttribute("Speed")) or 0.25,
            phase = tonumber(anchor:GetAttribute("Phase")) or 0,
        },
    }
    model:SetAttribute("AmbientFauna", true)
    model:SetAttribute("SourceAnchor", anchor:GetFullName())
    model.Parent = anchor.Parent
    table.insert(self._actors, actor)
    return true
end

function AmbientFaunaService:_update()
    for _, actor in ipairs(self._actors) do
        if actor.model.Parent then
            local sample = AmbientFaunaMotion.sample(actor.motion, self._elapsed, actor.motionSpec)
            local position = actor.basePosition + Vector3.new(sample.x, sample.y, sample.z)
            actor.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, sample.yaw, 0))
        end
    end
end

function AmbientFaunaService:Start()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local models = assets and assets:FindFirstChild("Models")
    local faunaFolder = models and models:FindFirstChild("AmbientFauna")
    if not faunaFolder then
        self:_log("Warn", "Assets.Models.AmbientFauna missing", nil)
        return
    end

    local spawned, failed = 0, 0
    for _, anchor in ipairs(CollectionService:GetTagged(TAG)) do
        if anchor:IsA("BasePart") and anchor:IsDescendantOf(workspace) and layer3Anchor(anchor) then
            if self:_spawn(anchor, faunaFolder) then
                spawned += 1
            else
                failed += 1
            end
        end
    end
    self:_update()
    self:_log(failed > 0 and "Warn" or "Info", "fauna spawned", {
        spawned = spawned,
        failed = failed,
    })

    self._connection = RunService.Heartbeat:Connect(function(deltaTime)
        self._elapsed += deltaTime
        self._accumulator += deltaTime
        if self._accumulator >= UPDATE_STEP then
            self._accumulator %= UPDATE_STEP
            self:_update()
        end
    end)
end

return AmbientFaunaService
