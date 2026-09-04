--!strict

-- Client-only rustle for nearby flora. The server plants stay put; this tilts
-- a local copy of each nearby model's pivot around its base and restores it
-- when the camera walks away.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Locations = require(ReplicatedStorage.Shared.Locations)
local ConfigLoader = require(Locations.ConfigLoader)
local FloraSwayMath = require(ReplicatedStorage.Shared.Game.FloraSway)

local FloraSway = {}

local TAG = "FloraSway"
local started = false
local prefEnabled = true
local userChanged = false

type Tracked = {
    model: Model,
    rest: CFrame,
    origin: Vector3,
    amplitude: number,
    phase: number,
    active: boolean,
}

local tracked: { [Model]: Tracked } = {}
local config = {}

local function requiredNumber(value, path): number
    local resolved = tonumber(value)
    assert(resolved ~= nil, path .. " must be numeric")
    return resolved
end

local function observerPosition(): Vector3?
    local camera = Workspace.CurrentCamera
    if camera then
        return camera.CFrame.Position
    end
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root.Position
    end
    return nil
end

local function modelPosition(model: Model): Vector3
    return model:GetPivot().Position
end

local function isSoftCandidate(inst: Instance): boolean
    if not inst:IsA("Model") or not inst.Parent then
        return false
    end
    if inst:GetAttribute("FloraSway") == false then
        return false
    end
    if inst:GetAttribute("FloraSway") == true or CollectionService:HasTag(inst, TAG) then
        return true
    end
    local name = inst.Name
    local kind = inst:GetAttribute("FloraKind") or inst:GetAttribute("Kind")
    if string.sub(name, 1, 6) == "Flora_" or string.sub(name, 1, 11) == "RealmDecor_" then
        return FloraSwayMath.shouldSway(name, kind)
    end
    return FloraSwayMath.shouldSway(name, kind)
end

local function remember(model: Model)
    if tracked[model] then
        return
    end
    local box, size = model:GetBoundingBox()
    local rest = model:GetPivot()
    tracked[model] = {
        model = model,
        rest = rest,
        origin = Vector3.new(box.Position.X, box.Position.Y - size.Y * 0.5, box.Position.Z),
        amplitude = FloraSwayMath.amplitude(
            model.Name,
            model:GetAttribute("FloraKind") or model:GetAttribute("Kind"),
            config
        ),
        phase = FloraSwayMath.phase(rest.Position.X, rest.Position.Z),
        active = false,
    }
end

local function forget(model: Model)
    local entry = tracked[model]
    if entry and entry.active and model.Parent then
        model:PivotTo(entry.rest)
    end
    tracked[model] = nil
end

local function gatherRoots(): { Instance }
    local roots = {
        Workspace:FindFirstChild("Maps"),
        Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel"),
    }
    local present = {}
    for _, root in ipairs(roots) do
        if root then
            table.insert(present, root)
        end
    end
    return present
end

local function rescan()
    local seen: { [Model]: boolean } = {}
    for _, model in ipairs(CollectionService:GetTagged(TAG)) do
        if model:IsA("Model") and isSoftCandidate(model) then
            remember(model)
            seen[model] = true
        end
    end
    for _, root in ipairs(gatherRoots()) do
        for _, inst in ipairs(root:GetDescendants()) do
            if inst:IsA("Model") and isSoftCandidate(inst) then
                remember(inst)
                seen[inst] = true
            end
        end
    end
    for model in pairs(tracked) do
        if not seen[model] or not model.Parent then
            forget(model)
        end
    end
end

local function apply(entry: Tracked, now: number)
    local sample =
        FloraSwayMath.sample(now, entry.phase, entry.amplitude, FloraSwayMath.speed(config))
    local rot = CFrame.Angles(sample.pitch, 0, sample.roll)
    local origin = CFrame.new(entry.origin)
    entry.model:PivotTo(origin * rot * origin:Inverse() * entry.rest)
    entry.active = true
end

local function restoreAll()
    for model, entry in pairs(tracked) do
        if entry.active and model.Parent then
            model:PivotTo(entry.rest)
        end
        entry.active = false
    end
end

local function callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result or envelope.data or envelope
end

function FloraSway.isEnabled()
    return prefEnabled
end

function FloraSway.setEnabled(value)
    userChanged = true
    prefEnabled = value ~= false
    if not prefEnabled then
        restoreAll()
    end
    task.spawn(function()
        callBus("settings.set", { propEffects = prefEnabled })
    end)
end

function FloraSway.start()
    if started then
        return
    end
    started = true
    local floraConfig = ConfigLoader:LoadConfig("flora")
    config = type(floraConfig) == "table" and floraConfig.sway or {}
    if config.enabled == false then
        return
    end

    CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
        if inst:IsA("Model") then
            forget(inst)
        end
    end)

    task.spawn(function()
        local result = callBus("settings.get")
        if type(result) == "table" and result.ok ~= false and not userChanged then
            prefEnabled = result.propEffects ~= false
            if not prefEnabled then
                restoreAll()
            end
        end
    end)

    local rescanSeconds =
        math.max(1, requiredNumber(config.rescan_seconds, "flora.sway.rescan_seconds"))
    local updateInterval = 1 / math.max(1, requiredNumber(config.update_hz, "flora.sway.update_hz"))
    local elapsed = rescanSeconds
    local motionElapsed = updateInterval
    rescan()
    RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        if elapsed >= rescanSeconds then
            elapsed = 0
            rescan()
        end
        if not prefEnabled then
            return
        end
        motionElapsed += dt
        if motionElapsed < updateInterval then
            return
        end
        motionElapsed = 0
        local here = observerPosition()
        if not here then
            return
        end
        local now = os.clock()
        local radius = FloraSwayMath.radius(config)
        local radiusSq = radius * radius
        for model, entry in pairs(tracked) do
            if not model.Parent then
                forget(model)
            else
                local delta = modelPosition(model) - here
                if delta:Dot(delta) <= radiusSq and entry.amplitude > 0 then
                    apply(entry, now)
                elseif entry.active then
                    model:PivotTo(entry.rest)
                    entry.active = false
                end
            end
        end
    end)
end

return FloraSway
