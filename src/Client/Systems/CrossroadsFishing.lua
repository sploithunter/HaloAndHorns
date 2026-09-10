-- Local cast/bite/luck/reel state machine. Network is used only after the player stops the bar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Prompts = game:GetService("ProximityPromptService")
local Actions = game:GetService("ContextActionService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local cfg = require(ReplicatedStorage.Configs.crossroads_fishing)
local Timing = require(ReplicatedStorage.Shared.Game.FishingTiming)
local Controller = {}
local started = false
function Controller.start()
    if started or not cfg.enabled then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local rng = Random.new()
    local active, gui, panel, status, fill, scoreLabel, hitButton, cancelButton
    local prompts, connections = {}, {}
    local visuals = Instance.new("Folder")
    visuals.Name = "CrossroadsLocalFishing"
    visuals.Parent = workspace
    local ripple, rippleCfg
    local fx = ReplicatedStorage:FindFirstChild("CrossroadsVisualFX")
    if fx and fx:FindFirstChild("WaterRipple") and fx:FindFirstChild("ConfigJSON") then
        local ok = pcall(function()
            rippleCfg = HttpService:JSONDecode(fx.ConfigJSON.Value)
            ripple = require(fx.WaterRipple).create(workspace, rippleCfg.ripple)
        end)
        if not ok then
            ripple = nil
        end
    end
    local function promptState(enabled)
        for prompt in pairs(prompts) do
            if prompt.Parent then
                prompt.Enabled = enabled
            else
                prompts[prompt] = nil
            end
        end
    end
    local function clear()
        active = nil
        visuals:ClearAllChildren()
        if ripple then
            ripple:clear()
        end
        if gui then
            gui.Enabled = false
        end
        Actions:UnbindAction("CrossroadsFishingHit")
        Actions:UnbindAction("CrossroadsFishingCancel")
        promptState(true)
    end
    local function corner(parent)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, cfg.ui.corner)
        c.Parent = parent
    end
    local function element(class, name, parent)
        local node = Instance.new(class)
        node.Name = name
        node.BorderSizePixel = 0
        local layout = cfg.ui.layout[name]
        node.Position, node.Size = layout.position, layout.size
        node.Parent = parent
        if node:IsA("TextLabel") or node:IsA("TextButton") then
            node.Font, node.TextScaled, node.TextWrapped = cfg.ui.font, true, true
            node.TextColor3 = cfg.ui.text
            node.BackgroundTransparency = node:IsA("TextLabel") and 1 or 0
            local textSize = Instance.new("UITextSizeConstraint")
            textSize.MaxTextSize = cfg.ui.text_max[name]
            textSize.Parent = node
        end
        return node
    end
    local function modalOpen()
        if
            GuiService.MenuIsOpen
            or player:GetAttribute("LargeMenuOpen") == true
            or Input:GetFocusedTextBox()
        then
            return true
        end
        local pg = player:FindFirstChild("PlayerGui")
        for _, name in ipairs(cfg.ui.blocking_guis) do
            local modal = pg and pg:FindFirstChild(name)
            if modal and modal:IsA("ScreenGui") and modal.Enabled then
                return true
            end
        end
        return false
    end
    local hook
    local function ensureGui()
        if gui then
            return
        end
        gui = Instance.new("ScreenGui")
        gui.Name = "CrossroadsFishingHUD"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = cfg.ui.display_order
        gui.Parent = player:WaitForChild("PlayerGui")
        panel = Instance.new("Frame")
        panel.Name = "FishingPanel"
        panel.AnchorPoint = Vector2.new(0.5, 0.5)
        panel.Position, panel.Size = cfg.ui.position, cfg.ui.size
        panel.BackgroundColor3, panel.BorderSizePixel = cfg.ui.panel, 0
        panel.Parent = gui
        corner(panel)
        local constraint = Instance.new("UISizeConstraint")
        constraint.MinSize, constraint.MaxSize = cfg.ui.minimum, cfg.ui.maximum
        constraint.Parent = panel
        local outline = Instance.new("UIStroke")
        outline.Color, outline.Thickness = cfg.ui.muted, cfg.ui.stroke
        outline.Parent = panel
        element("TextLabel", "title", panel).Text = cfg.ui.title
        status = element("TextLabel", "status", panel)
        local track = element("Frame", "bar", panel)
        track.BackgroundColor3, track.ClipsDescendants = cfg.ui.track, true
        corner(track)
        fill = Instance.new("Frame")
        fill.Name = "LuckFill"
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1)
        fill.Parent = track
        corner(fill)
        scoreLabel = element("TextLabel", "score", panel)
        scoreLabel.ZIndex = track.ZIndex + 1
        hitButton = element("TextButton", "hit", panel)
        hitButton.BackgroundColor3 = cfg.ui.button
        corner(hitButton)
        cancelButton = element("TextButton", "cancel", panel)
        cancelButton.BackgroundColor3 = cfg.ui.track
        corner(cancelButton)
        table.insert(
            connections,
            hitButton.Activated:Connect(function()
                hook()
            end)
        )
        table.insert(connections, cancelButton.Activated:Connect(clear))
    end
    local function inputLabels()
        local gamepad = Input:GetLastInputType().Name:find("Gamepad") ~= nil
        hitButton.Text = cfg.ui.hit
            .. (Input.TouchEnabled and "" or " [" .. (gamepad and "X" or cfg.input.hit.Name) .. "]")
        cancelButton.Text = cfg.ui.cancel
            .. (
                Input.TouchEnabled and ""
                or " [" .. (gamepad and "B" or cfg.input.cancel.Name) .. "]"
            )
    end
    hook = function()
        local state = active
        if not state or state.phase ~= "bite" then
            return
        end
        -- Freeze the actual last-rendered value, not a newly sampled position or server estimate.
        state.phase, state.reelAt = "reel", os.clock()
        state.reelFrom = state.bobber.Position
        state.caught = rng:NextNumber() >= Timing.escapeChance(cfg.timing, state.score)
        hitButton.Active = false
        status.Text = cfg.ui.reeling
        if not state.caught then
            return
        end
        local request =
            { station = state.key, attempt = state.attempt, score = state.score, caught = true }
        task.spawn(function()
            local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
            local ok, envelope = pcall(function()
                return remote and remote:InvokeServer(cfg.command, request)
            end)
            if not ok then
                -- Same receipt id makes a lost response retry safe; no new catch roll.
                ok, envelope = pcall(function()
                    return remote and remote:InvokeServer(cfg.command, request)
                end)
            end
            if active ~= state then
                return
            end
            state.reply = ok and type(envelope) == "table" and (envelope.result or envelope)
                or { ok = false }
        end)
    end
    local function cast(prompt)
        if active or modalOpen() then
            return
        end
        local deck = prompt.Parent and prompt.Parent.Parent
        local castPoint, tip =
            deck and deck:FindFirstChild("Cast"), deck and deck:FindFirstChild("LineTip")
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if
            not castPoint
            or not tip
            or not root
            or (root.Position - deck.Position).Magnitude > cfg.release_distance
        then
            return
        end
        ensureGui()
        visuals:ClearAllChildren()
        local bobber = Instance.new("Part")
        bobber.Name, bobber.Shape = "FishingBobber", Enum.PartType.Ball
        bobber.Size, bobber.Color = cfg.cast.bobber_size, cfg.cast.bobber_color
        bobber.Anchored, bobber.CanCollide, bobber.CanTouch, bobber.CanQuery =
            true, false, false, false
        bobber.Position, bobber.Material = tip.WorldPosition, Enum.Material.SmoothPlastic
        bobber.Parent = visuals
        local endpoint = Instance.new("Attachment")
        endpoint.Parent = bobber
        local line = Instance.new("Beam")
        line.Name = "FishingLine"
        line.Attachment0, line.Attachment1 = tip, endpoint
        line.Width0, line.Width1 = cfg.cast.line_width, cfg.cast.line_width
        line.Color, line.FaceCamera = ColorSequence.new(cfg.cast.line_color), true
        line.Parent = visuals
        active = {
            phase = "cast",
            started = os.clock(),
            deck = deck,
            tip = tip,
            prompt = prompt,
            key = deck:GetAttribute(cfg.station_attribute),
            attempt = HttpService:GenerateGUID(false),
            bobber = bobber,
            start = tip.WorldPosition,
            target = castPoint.WorldPosition,
            score = 0,
            biteAt = cfg.cast.seconds + rng:NextNumber(cfg.timing.wait_min, cfg.timing.wait_max),
            profile = Timing.newProfile(cfg.timing, rng),
        }
        gui.Enabled, hitButton.Active = true, false
        fill.Size, scoreLabel.Text, status.Text = UDim2.fromScale(0, 1), "", cfg.ui.casting
        promptState(false)
        inputLabels()
        Actions:BindActionAtPriority("CrossroadsFishingHit", function(_, inputState)
            if Input:GetFocusedTextBox() then
                return Enum.ContextActionResult.Pass
            end
            if inputState == Enum.UserInputState.Begin then
                hook()
            end
            return Enum.ContextActionResult.Sink
        end, false, cfg.input.priority, cfg.input.hit, cfg.input.gamepad_hit)
        Actions:BindActionAtPriority("CrossroadsFishingCancel", function(_, inputState)
            if Input:GetFocusedTextBox() then
                return Enum.ContextActionResult.Pass
            end
            if inputState == Enum.UserInputState.Begin then
                clear()
            end
            return Enum.ContextActionResult.Sink
        end, false, cfg.input.priority, cfg.input.cancel, cfg.input.gamepad_cancel)
    end
    local function bind(prompt)
        if
            not prompt:IsA("ProximityPrompt")
            or prompt:GetAttribute(cfg.prompt_attribute) ~= cfg.prompt_value
        then
            return
        end
        local deck = prompt.Parent and prompt.Parent.Parent
        if not deck or not deck:IsA("BasePart") or not deck:GetAttribute(cfg.station_attribute) then
            return
        end
        prompts[prompt] = true
        prompt.ActionText, prompt.ObjectText = cfg.ui.cast, cfg.ui.object
        prompt.MaxActivationDistance = cfg.distance
        prompt.KeyboardKeyCode, prompt.GamepadKeyCode = cfg.input.hit, cfg.input.gamepad_hit
        prompt.Enabled = active == nil
        deck:SetAttribute("FishingConnected", true)
    end
    local function mount(world)
        for _, item in ipairs(world:GetDescendants()) do
            bind(item)
        end
        table.insert(connections, world.DescendantAdded:Connect(bind))
    end
    local world = workspace:FindFirstChild(cfg.root_name)
    if world then
        mount(world)
    end
    table.insert(
        connections,
        workspace.ChildAdded:Connect(function(child)
            if child.Name == cfg.root_name then
                mount(child)
            end
        end)
    )
    table.insert(
        connections,
        Prompts.PromptTriggered:Connect(function(prompt, who)
            if prompts[prompt] and (not who or who == player) then
                cast(prompt)
            end
        end)
    )
    table.insert(connections, player.CharacterRemoving:Connect(clear))
    table.insert(
        connections,
        RunService.RenderStepped:Connect(function(dt)
            local state = active
            if not state then
                return
            end
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if
                not root
                or not hum
                or hum.Health <= 0
                or not state.deck:IsDescendantOf(workspace)
                or not state.tip.Parent
                or not state.prompt.Parent
                or (root.Position - state.deck.Position).Magnitude > cfg.release_distance
            then
                clear()
                return
            end
            if modalOpen() then
                clear()
                return
            end
            if workspace.CurrentCamera then
                panel.Position = workspace.CurrentCamera.ViewportSize.Y <= cfg.ui.short_height
                        and cfg.ui.short_position
                    or cfg.ui.position
            end
            local now = os.clock()
            local elapsed = now - state.started
            local camera = workspace.CurrentCamera
            if ripple and camera then
                local runtime = workspace:FindFirstChild(rippleCfg.integration.local_root)
                local quality = runtime and runtime:GetAttribute("Quality") or "off"
                local reduced = player:GetAttribute(rippleCfg.integration.reduced_motion_attribute)
                    == true
                ripple:update(dt, camera.CFrame.Position, quality, reduced)
                if elapsed >= cfg.cast.seconds and not state.landed then
                    state.landed = true
                    ripple:trigger(
                        Vector3.new(
                            state.target.X,
                            state.deck:GetAttribute("PreviewWaterY")
                                or state.target.Y - cfg.cast.water_offset,
                            state.target.Z
                        ),
                        camera.CFrame.Position,
                        quality,
                        reduced
                    )
                end
            end
            if state.phase == "reel" then
                local t = math.clamp((now - state.reelAt) / cfg.cast.reel_seconds, 0, 1)
                state.bobber.Position = state.reelFrom:Lerp(state.tip.WorldPosition, t)
                if t == 1 then
                    state.bobber.Transparency = 1
                    if
                        not state.caught
                        or state.reply
                        or now - state.reelAt >= cfg.timing.network_timeout
                    then
                        state.phase, state.resultAt = "result", now
                        if not state.caught then
                            status.Text = cfg.ui.lost
                        elseif state.reply and state.reply.ok then
                            status.Text = string.format(
                                cfg.ui.success,
                                cfg.ui.tiers[state.reply.tier],
                                state.reply.label
                            )
                        else
                            status.Text = cfg.ui.failed
                        end
                    else
                        status.Text = cfg.ui.pending
                    end
                end
                return
            elseif state.phase == "result" then
                if now - state.resultAt >= cfg.timing.result_seconds then
                    clear()
                end
                return
            end
            local t = math.clamp(elapsed / cfg.cast.seconds, 0, 1)
            local offset = t < 1 and math.sin(t * math.pi) * cfg.cast.arc_height
                or math.sin((elapsed - cfg.cast.seconds) * math.pi * 2 / cfg.cast.bob_period)
                    * cfg.cast.bob_amplitude
            state.bobber.Position = state.start:Lerp(state.target, t) + Vector3.new(0, offset, 0)
            if elapsed < cfg.cast.seconds then
                return
            end
            if elapsed < state.biteAt then
                state.phase, status.Text = "wait", cfg.ui.waiting
                return
            end
            local fishingTime = elapsed - state.biteAt
            if fishingTime >= cfg.timing.duration then
                state.phase, state.resultAt, status.Text = "result", now, cfg.ui.timeout
                hitButton.Active = false
                return
            end
            state.phase, status.Text, hitButton.Active =
                "bite",
                string.format(cfg.ui.bite, math.ceil(cfg.timing.duration - fishingTime)),
                true
            state.score = Timing.score(cfg.timing, state.profile, fishingTime)
            fill.Size = UDim2.fromScale(state.score / 100, 1)
            fill.BackgroundColor3 = state.score == 100 and cfg.ui.peak
                or cfg.ui.low:Lerp(cfg.ui.high, state.score / 100)
            scoreLabel.Text = string.format(cfg.ui.luck, state.score)
            inputLabels()
        end)
    )
    script.Destroying:Connect(function()
        clear()
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        if ripple then
            ripple:destroy()
        end
        visuals:Destroy()
        if gui then
            gui:Destroy()
        end
    end)
end
return Controller
