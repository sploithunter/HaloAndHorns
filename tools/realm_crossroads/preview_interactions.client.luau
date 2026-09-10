local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer
local container = game:GetService("ReplicatedStorage"):WaitForChild(script.Name)
local cfg = HttpService:JSONDecode(container:WaitForChild("Config").Value)
if cfg.studio_only and (not RunService:IsStudio() or game.PlaceId ~= 0) then
    return
end
local world = workspace:WaitForChild(cfg.root)
local settings = cfg.fishing
local fxRuntime = game:GetService("ReplicatedStorage"):WaitForChild(cfg.ripple_runtime)
local fxData = HttpService:JSONDecode(fxRuntime:WaitForChild("ConfigJSON").Value)
local ripple = require(fxRuntime:WaitForChild("WaterRipple")).create(workspace, fxData.ripple)
local function effectSettings()
    local runtime = workspace:FindFirstChild(fxData.integration.local_root)
    return runtime and runtime:GetAttribute("Quality") or "off",
        player:GetAttribute(fxData.integration.reduced_motion_attribute) == true
end
local active
local prompts = {}
local connections = {}
local visuals = Instance.new("Folder")
visuals.Name = "LocalFishingRehearsal"
visuals.Parent = workspace

local function clear()
    ripple:clear()
    if active then
        if active.prompt.Parent then
            active.prompt.ActionText = settings.action
        end
        active = nil
    end
    visuals:ClearAllChildren()
end

local function bind(prompt)
    if
        not prompt:IsA("ProximityPrompt")
        or prompt:GetAttribute("StubAction") ~= "fishing_preview"
    then
        return
    end
    if prompts[prompt] then
        return
    end
    prompts[prompt] = true
    prompt.Enabled = true
    prompt.ActionText = settings.action
    prompt.ObjectText = settings.object
        .. " "
        .. tostring(prompt.Parent.Parent:GetAttribute("StationIndex"))
    prompt.MaxActivationDistance = settings.distance
end

for _, item in ipairs(world:GetDescendants()) do
    bind(item)
end
table.insert(connections, world.DescendantAdded:Connect(bind))
table.insert(
    connections,
    ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
        if not prompts[prompt] or (triggeringPlayer and triggeringPlayer ~= player) then
            return
        end
        if active and active.prompt == prompt then
            clear()
            return
        end
        clear()
        local deck = prompt.Parent.Parent
        local cast, tip = deck:FindFirstChild("Cast"), deck:FindFirstChild("LineTip")
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if
            not cast
            or not tip
            or not root
            or (root.Position - deck.Position).Magnitude > settings.release_distance
        then
            return
        end
        local bobber = Instance.new("Part")
        bobber.Name = "PreviewBobber"
        bobber.Shape = Enum.PartType.Ball
        bobber.Size = Vector3.new(unpack(settings.bobber_size))
        bobber.Color = Color3.fromRGB(unpack(settings.bobber_color))
        bobber.Material = Enum.Material.SmoothPlastic
        bobber.Anchored = true
        bobber.CanCollide = false
        bobber.CanTouch = false
        bobber.CanQuery = false
        bobber.Position = tip.WorldPosition
        bobber.Parent = visuals
        local endAttachment = Instance.new("Attachment")
        endAttachment.Parent = bobber
        local line = Instance.new("Beam")
        line.Name = "PreviewFishingLine"
        line.Attachment0, line.Attachment1 = tip, endAttachment
        line.Width0, line.Width1 = settings.line_width, settings.line_width
        line.Color = ColorSequence.new(Color3.fromRGB(unpack(settings.line_color)))
        line.FaceCamera = true
        line.Parent = visuals
        active = {
            prompt = prompt,
            deck = deck,
            bobber = bobber,
            start = tip.WorldPosition,
            target = cast.WorldPosition,
            elapsed = 0,
        }
        prompt.ActionText = settings.reel_action
    end)
)
table.insert(
    connections,
    RunService.RenderStepped:Connect(function(dt)
        if not active then
            return
        end
        local state = active
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if
            not root
            or not state.deck.Parent
            or not state.prompt.Parent
            or (root.Position - state.deck.Position).Magnitude > settings.release_distance
        then
            clear()
            return
        end
        state.elapsed += dt
        if state.elapsed > settings.max_seconds then
            clear()
            return
        end
        local t = math.clamp(state.elapsed / settings.cast_seconds, 0, 1)
        local camera = workspace.CurrentCamera
        local quality, reducedMotion = effectSettings()
        if camera then
            ripple:update(dt, camera.CFrame.Position, quality, reducedMotion)
            if t == 1 and not state.landed then
                state.landed = true
                local surface = Vector3.new(
                    state.target.X,
                    state.deck:GetAttribute("PreviewWaterY"),
                    state.target.Z
                )
                ripple:trigger(surface, camera.CFrame.Position, quality, reducedMotion)
            end
        end
        local offset = t < 1 and math.sin(t * math.pi) * settings.arc_height
            or math.sin(
                    (state.elapsed - settings.cast_seconds) * math.pi * 2 / settings.bob_period
                )
                * settings.bob_amplitude
        state.bobber.Position = state.start:Lerp(state.target, t) + Vector3.new(0, offset, 0)
    end)
)
table.insert(connections, player.CharacterRemoving:Connect(clear))
script.Destroying:Connect(function()
    clear()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    for prompt in pairs(prompts) do
        if prompt.Parent then
            prompt.Enabled = false
        end
    end
    visuals:Destroy()
    ripple:destroy()
end)
