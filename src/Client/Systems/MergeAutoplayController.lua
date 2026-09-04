-- Real pathfinding/character movement only. Purchases are chosen and checked on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local Config = require(ReplicatedStorage.Configs.merge_autoplay)
local PurchasePrompt = require(script.Parent.Parent.UI.Components.GamePassPurchasePrompt)
local Controller = {}
local started = false

local function rgb(value)
    return Color3.fromRGB(value[1], value[2], value[3])
end

local function horizontalDistance(a, b)
    local offset = a - b
    return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

function Controller.start()
    if started or not Config.enabled then
        return
    end
    started = true
    local player = Players.LocalPlayer
    -- Some Studio/client builds don't install PlayerModule. Never stall the rest of client boot
    -- waiting for an optional Roblox implementation detail.
    local controls
    local playerModule = player.PlayerScripts:FindFirstChild("PlayerModule")
    if playerModule then
        local ok, value = pcall(function()
            return require(playerModule):GetControls()
        end)
        if ok then
            controls = value
        end
    end
    local generation, active = 0, false
    local walkingTarget
    local ui, nav = Config.ui, Config.navigation
    local gui = Instance.new("ScreenGui")
    gui.Name = "MergeAutoplayGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = ui.display_order
    gui.Parent = player:WaitForChild("PlayerGui")
    local button = Instance.new("TextButton")
    button.Name = "Toggle"
    button.AnchorPoint = Vector2.new(0.5, 1)
    button.Position = UDim2.fromScale(ui.position.x, ui.position.y)
    button.Size = UDim2.fromScale(ui.size.x, ui.size.y)
    button.TextColor3 = rgb(ui.text_color)
    button.Font = Enum.Font.GothamBold
    button.TextScaled = true
    button.Parent = gui
    local constraint = Instance.new("UISizeConstraint")
    constraint.MinSize = Vector2.new(ui.minimum_size.x, ui.minimum_size.y)
    constraint.MaxSize = Vector2.new(ui.maximum_size.x, ui.maximum_size.y)
    constraint.Parent = button
    local textConstraint = Instance.new("UITextSizeConstraint")
    textConstraint.MinTextSize, textConstraint.MaxTextSize = ui.text_min, ui.text_max
    textConstraint.Parent = button
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(ui.corner_scale, 0)
    corner.Parent = button
    local hint = Instance.new("TextLabel")
    hint.Name = "Status"
    hint.BackgroundTransparency = 1
    hint.Position = UDim2.fromScale(0, 1)
    hint.Size = UDim2.fromScale(1, 0.5)
    hint.TextColor3 = rgb(ui.text_color)
    hint.TextScaled = true
    hint.Font = Enum.Font.Gotham
    hint.Parent = button

    local function release()
        generation += 1
        active = false
        walkingTarget = nil
        RunService:UnbindFromRenderStep("MergeAutoplayMovement")
        if controls then
            controls:Enable()
        end
        local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid:Move(Vector3.zero)
            humanoid:MoveTo(humanoid.RootPart and humanoid.RootPart.Position or Vector3.zero)
        end
    end
    local function stop()
        release()
        Signals.MergeAutoplayToggle:FireServer({ enabled = false })
    end
    local function refresh()
        local enabled = player:GetAttribute("MergeAutoplayEnabled") == true
        gui.Enabled = player:GetAttribute("InMergeEggPrototype") == true
        button.Text = enabled and ui.on
            or (player:GetAttribute("MergeAutoplayOwned") and ui.off or ui.buy)
        button.BackgroundColor3 = rgb(enabled and ui.active_color or ui.idle_color)
        hint.Text = player:GetAttribute("MergeAutoplayStatus") or ui.off_hint
        if enabled and not active then
            active = true
            if controls then
                controls:Disable()
            end
            -- Apply normal humanoid input after default controls, including clients without
            -- PlayerModule. No CFrame changes, simulated keypresses, or speed changes.
            RunService:BindToRenderStep(
                "MergeAutoplayMovement",
                Enum.RenderPriority.Character.Value + 1,
                function()
                    local humanoid = player.Character
                        and player.Character:FindFirstChildWhichIsA("Humanoid")
                    local root = humanoid and humanoid.RootPart
                    if not root then
                        return
                    end
                    local offset = walkingTarget and walkingTarget - root.Position or Vector3.zero
                    local flat = Vector3.new(offset.X, 0, offset.Z)
                    humanoid:Move(
                        flat.Magnitude > nav.waypoint_distance and flat.Unit or Vector3.zero,
                        false
                    )
                end
            )
        elseif not enabled and active then
            release()
        end
    end
    for _, key in ipairs({
        "MergeAutoplayEnabled",
        "MergeAutoplayOwned",
        "MergeAutoplayStatus",
        "InMergeEggPrototype",
    }) do
        player:GetAttributeChangedSignal(key):Connect(refresh)
    end
    player:GetAttributeChangedSignal("MergeAutoplayTarget"):Connect(function()
        generation += 1
        walkingTarget = nil
        if player:GetAttribute("MergeAutoplayTarget") == nil then
            local humanoid = player.Character
                and player.Character:FindFirstChildWhichIsA("Humanoid")
            if humanoid and humanoid.RootPart then
                humanoid:MoveTo(humanoid.RootPart.Position)
            end
        end
    end)
    player.CharacterRemoving:Connect(stop)
    button.Activated:Connect(function()
        if active then
            stop()
            return
        end
        if player:GetAttribute("MergeAutoplayOwned") ~= true then
            PurchasePrompt.show(
                { passId = Config.pass_id, presentation = Config.purchase_menu },
                function(purchase, entry)
                    if purchase then
                        Signals.InitiatePurchase:FireServer({
                            productId = entry.id,
                            productType = entry.kind,
                        })
                    end
                end
            )
        else
            Signals.MergeAutoplayToggle:FireServer({ enabled = true })
        end
    end)
    UserInputService.InputBegan:Connect(function(input, processed)
        if not active or processed then
            return
        end
        local key = input.KeyCode
        if
            key == Enum.KeyCode.W
            or key == Enum.KeyCode.A
            or key == Enum.KeyCode.S
            or key == Enum.KeyCode.D
            or key == Enum.KeyCode.Up
            or key == Enum.KeyCode.Down
            or key == Enum.KeyCode.Left
            or key == Enum.KeyCode.Right
            or key == Enum.KeyCode.Space
        then
            stop()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if
            active
            and input.KeyCode == Enum.KeyCode.Thumbstick1
            and input.Position.Magnitude > 0
        then
            stop()
        end
    end)
    -- Never fight a ceremony/teleport camera for controls. The player may opt back in afterward.
    workspace.CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
        if active and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
            stop()
        end
    end)
    refresh()
    task.spawn(function()
        while gui.Parent do
            local token = generation
            local destination = player:GetAttribute("MergeAutoplayTarget")
            local humanoid = player.Character
                and player.Character:FindFirstChildWhichIsA("Humanoid")
            local root = humanoid and humanoid.RootPart
            if active and root and typeof(destination) == "Vector3" then
                local ok = pcall(function()
                    local path = PathfindingService:CreatePath({
                        AgentRadius = nav.agent_radius,
                        AgentHeight = nav.agent_height,
                        AgentCanJump = true,
                        WaypointSpacing = nav.waypoint_spacing,
                    })
                    path:ComputeAsync(root.Position, destination)
                    -- The management panel is mounted above the walkable floor; a path to its
                    -- text surface can be NoPath even though its purchase radius is reachable.
                    if
                        path.Status ~= Enum.PathStatus.Success
                        and nav.project_elevated_stations_to_current_floor
                    then
                        path:ComputeAsync(
                            root.Position,
                            Vector3.new(destination.X, root.Position.Y, destination.Z)
                        )
                    end
                    if token ~= generation or not active then
                        return
                    end
                    if path.Status ~= Enum.PathStatus.Success then
                        return
                    end
                    for _, waypoint in ipairs(path:GetWaypoints()) do
                        if token ~= generation or not active then
                            break
                        end
                        if waypoint.Action == Enum.PathWaypointAction.Jump then
                            humanoid.Jump = true
                        end
                        walkingTarget = waypoint.Position
                        humanoid:MoveTo(waypoint.Position)
                        local deadline = os.clock() + nav.waypoint_timeout_seconds
                        while
                            active
                            and token == generation
                            and humanoid.Parent
                            and root.Parent
                            and horizontalDistance(root.Position, waypoint.Position) > nav.waypoint_distance
                            and os.clock() < deadline
                        do
                            RunService.Heartbeat:Wait()
                        end
                        if os.clock() >= deadline then
                            break
                        end
                    end
                    walkingTarget = nil
                end)
                if not ok then
                    stop()
                end
            end
            local resumeAt = os.clock() + nav.replan_seconds
            repeat
                RunService.Heartbeat:Wait()
            until os.clock() >= resumeAt or not gui.Parent
        end
        release()
    end)
end

return Controller
