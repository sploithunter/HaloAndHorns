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
local Gait = require(ReplicatedStorage.Shared.Game.Gait)

local TAG = "AmbientFaunaAnchor"
local UPDATE_STEP = 1 / 30

type MotionSpec = {
    radius: number?,
    radius_x: number?,
    radius_z: number?,
    hover_height: number?,
    speed: number?,
    phase: number?,
}

type Actor = {
    model: Model,
    basePosition: Vector3,
    motion: string,
    motionSpec: MotionSpec,
    gait: any,
    gaitState: { phase: number, amp: number },
    facingYawRadians: number,
    lastPathPosition: Vector3?,
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
            radius_x = tonumber(anchor:GetAttribute("PathRadiusX")),
            radius_z = tonumber(anchor:GetAttribute("PathRadiusZ")),
            hover_height = tonumber(anchor:GetAttribute("HoverHeight")) or 0,
            speed = tonumber(anchor:GetAttribute("Speed")) or 0.25,
            phase = tonumber(anchor:GetAttribute("Phase")) or 0,
        },
        gait = Gait.resolve(if anchor:GetAttribute("Motion") == "hover"
            then {
                style = "flap",
                bob_height = tonumber(anchor:GetAttribute("BobHeight")) or 0.16,
                tilt_degrees = 8,
                stride_length = 2.2,
                ref_speed = 3,
                ease_rate = 10,
                hover = true,
                idle_amp = 0.65,
                flap_hz = 1.5,
            }
            else {
                style = "waddle",
                bob_height = tonumber(anchor:GetAttribute("BobHeight")) or 0.05,
                tilt_degrees = 5,
                stride_length = 1.8,
                ref_speed = 2,
                ease_rate = 10,
            }),
        gaitState = {
            phase = tonumber(anchor:GetAttribute("Phase")) or 0,
            amp = 0,
        },
        -- Some imported meshes face -Z in their authored space. Keep the route math shared and
        -- correct the visual once at the anchor instead of reversing its travel direction.
        facingYawRadians = math.rad(tonumber(anchor:GetAttribute("FacingYawDegrees")) or 0),
        lastPathPosition = nil,
    }
    model:SetAttribute("AmbientFauna", true)
    model:SetAttribute("SourceAnchor", anchor:GetFullName())
    model.Parent = anchor.Parent
    table.insert(self._actors, actor)
    return true
end

function AmbientFaunaService:_update(deltaTime: number)
    for _, actor in ipairs(self._actors) do
        if actor.model.Parent then
            local sample = AmbientFaunaMotion.sample(actor.motion, self._elapsed, actor.motionSpec)
            local position = actor.basePosition + Vector3.new(sample.x, sample.y, sample.z)
            local lastPosition = actor.lastPathPosition
            local stepDistance = if lastPosition
                then Vector3.new(position.X - lastPosition.X, 0, position.Z - lastPosition.Z).Magnitude
                else 0
            actor.lastPathPosition = position

            -- Share the exact procedural gait core used by PetFollowController. The clean path
            -- CFrame faces the route tangent; bounce and bank layer on top without feeding back
            -- into the next path sample.
            local facing = Vector3.new(sample.facing_x, 0, sample.facing_z)
            local clean = CFrame.lookAt(position, position + facing)
            local bob, roll, yaw =
                Gait.advance(actor.gaitState, actor.gait, stepDistance, deltaTime)
            actor.model:PivotTo(
                CFrame.new(0, bob, 0) * clean * CFrame.Angles(0, actor.facingYawRadians + yaw, roll)
            )
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
    self:_update(UPDATE_STEP)
    self:_log(failed > 0 and "Warn" or "Info", "fauna spawned", {
        spawned = spawned,
        failed = failed,
    })

    self._connection = RunService.Heartbeat:Connect(function(deltaTime)
        self._elapsed += deltaTime
        self._accumulator += deltaTime
        if self._accumulator >= UPDATE_STEP then
            local updateDelta = self._accumulator
            self._accumulator = 0
            self:_update(updateDelta)
        end
    end)
end

return AmbientFaunaService
