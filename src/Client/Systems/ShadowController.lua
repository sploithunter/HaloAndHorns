--!strict
-- Per-observer shadows only. Never remove models, stop animations, or affect combat.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
local Policy = require(ReplicatedStorage.Shared.Game.ShadowPolicy)
local config = ConfigLoader:LoadConfig("client_graphics").shadows
local player = Players.LocalPlayer
local ShadowController = {}
local started = false
local mode = config.default_mode
local state = Policy.new(config)
local focused = true
local menuOpen = false
local userChanged = false
local loaded = false
local pendingSave = false
local saving = false
local elapsed = 0
local sampleSeconds = 0
local sampleFrames = 0
local entries = {}

local function callBus(name, args)
    local remote = ReplicatedStorage:WaitForChild("GameAPICommand")
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if ok and type(envelope) == "table" then
        return envelope.result or envelope.data or envelope
    end
    return nil
end

local function save()
    if not loaded or saving or not pendingSave then
        return
    end
    saving = true
    task.spawn(function()
        -- Serialize writes so a slower earlier choice cannot overwrite the last click.
        while pendingSave do
            pendingSave = false
            local result = callBus("settings.set", { shadowMode = mode })
            if not result or result.ok == false then
                warn("Shadow preference could not be saved")
            end
        end
        saving = false
    end)
end

local function applyGlobal()
    local enabled = Policy.enabled(mode, state)
    if Lighting.GlobalShadows ~= enabled then
        Lighting.GlobalShadows = enabled
    end
    player:SetAttribute("ShadowMode", mode)
    player:SetAttribute("ShadowsActive", enabled)
end

local function remember(instance)
    if entries[instance] then
        return
    end
    local property
    if instance:IsA("BasePart") and not instance:IsA("Terrain") then
        property = "CastShadow"
    elseif instance:IsA("Light") then
        property = "Shadows"
    end
    -- Authored non-casters remain non-casters. Only take ownership of enabled ones.
    if property and instance[property] then
        entries[instance] = { property = property, original = true, near = false }
    end
end

local function forget(instance)
    local entry = entries[instance]
    if entry then
        entries[instance] = nil
        -- Streaming out/reparenting must not bake our local culling into a reused object.
        instance[entry.property] = entry.original
    end
end

local function observerPosition()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root.Position
    end
    local camera = Workspace.CurrentCamera
    return camera and camera.CFrame.Position or nil
end

local function updateNearby()
    local here = observerPosition()
    if not here then
        return
    end
    for instance, entry in pairs(entries) do
        local distanceSquared = math.huge
        if instance:IsA("BasePart") then
            local point = instance.CFrame:PointToObjectSpace(here)
            local half = instance.Size * 0.5
            distanceSquared =
                Policy.distanceSquared(point.X, point.Y, point.Z, half.X, half.Y, half.Z)
        else
            local parent = instance.Parent
            local position = if parent and parent:IsA("Attachment")
                then parent.WorldPosition
                elseif parent and parent:IsA("BasePart") then parent.Position
                else nil
            if position then
                local delta = position - here
                distanceSquared = delta:Dot(delta)
            end
        end
        entry.near = Policy.nearby(distanceSquared, entry.near, config)
        if instance[entry.property] ~= entry.near then
            instance[entry.property] = entry.near
        end
    end
end

local function resetObservation()
    sampleSeconds = 0
    sampleFrames = 0
    Policy.resetObservation(state, config)
end

function ShadowController.getPreference()
    return mode
end

function ShadowController.setPreference(value)
    mode = Policy.normalize(value, config)
    userChanged = true
    pendingSave = true
    state = Policy.new(config)
    resetObservation()
    applyGlobal()
    save()
end

function ShadowController.start()
    if started then
        return
    end
    started = true
    Workspace.DescendantAdded:Connect(remember)
    Workspace.DescendantRemoving:Connect(forget)
    -- One inventory, then incremental registration; no recurring full-world scans.
    for _, instance in ipairs(Workspace:GetDescendants()) do
        remember(instance)
    end
    updateNearby()
    applyGlobal()
    Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(applyGlobal)

    UserInputService.WindowFocusReleased:Connect(function()
        focused = false
        resetObservation()
    end)
    UserInputService.WindowFocused:Connect(function()
        focused = true
        resetObservation()
    end)
    local GuiService = game:GetService("GuiService")
    GuiService.MenuOpened:Connect(function()
        menuOpen = true
        resetObservation()
    end)
    GuiService.MenuClosed:Connect(function()
        menuOpen = false
        resetObservation()
    end)
    player.CharacterAdded:Connect(resetObservation)

    RunService.RenderStepped:Connect(function(dt)
        if mode ~= "auto" or not focused or menuOpen or not loaded then
            return
        end
        local observedSeconds = Policy.frameSeconds(dt, config)
        if observedSeconds <= 0 then
            return
        end
        sampleSeconds += observedSeconds
        sampleFrames += 1
        if sampleSeconds >= config.sample_seconds then
            Policy.sample(state, sampleFrames / sampleSeconds, sampleSeconds, config)
            sampleSeconds = 0
            sampleFrames = 0
            applyGlobal()
        end
    end)
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= config.update_seconds then
            elapsed = 0
            updateNearby()
        end
    end)

    task.spawn(function()
        -- Subscribe and recheck the durable latch; no timing guesses or profile polling.
        if player:GetAttribute("DataLoaded") ~= true then
            repeat
                player:GetAttributeChangedSignal("DataLoaded"):Wait()
            until player:GetAttribute("DataLoaded") == true
        end
        local result = callBus("settings.get")
        if not userChanged and result and result.ok then
            mode = Policy.normalize(result.shadowMode, config)
        end
        loaded = true
        resetObservation()
        applyGlobal()
        save()
    end)
end

return ShadowController
