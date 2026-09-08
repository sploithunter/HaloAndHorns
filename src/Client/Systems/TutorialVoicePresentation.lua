local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local WATCHER = require(ReplicatedStorage.Configs.merge_egg_prototype).watcher
local WatcherDirector = require(ReplicatedStorage.Shared.Game.MergeWatcherDirector)
local Presentation = {}
Presentation.__index = Presentation
local function color(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
function Presentation.new(config)
    local cfg = config.presentation
    local gui = Instance.new("ScreenGui")
    gui.Name = "TutorialNarrator"
    gui.DisplayOrder = cfg.display_order
    gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    local card = Instance.new("Frame")
    card.Name = "Portrait"
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.fromScale(cfg.portrait_position.x, cfg.portrait_position.y)
    card.Size = UDim2.fromScale(cfg.portrait_size.x, cfg.portrait_size.y)
    card.BackgroundTransparency = 1
    card.Parent = gui
    local maximum = Instance.new("UISizeConstraint")
    maximum.MaxSize = Vector2.new(cfg.portrait_max.x, cfg.portrait_max.y)
    maximum.Parent = card
    local view = Instance.new("ViewportFrame")
    view.Name = "Face"
    view.Size = UDim2.fromScale(1, cfg.face_height)
    view.BackgroundTransparency = 1
    view.Ambient = color(cfg.viewport_ambient)
    view.LightColor = color(cfg.viewport_light)
    view.LightDirection = Vector3.new(table.unpack(cfg.viewport_light_direction))
    view.Parent = card
    local camera = Instance.new("Camera")
    camera.FieldOfView = cfg.camera_fov
    camera.CFrame =
        CFrame.lookAt(Vector3.new(0, 0, -cfg.face_size * cfg.camera_distance), Vector3.zero)
    camera.Parent = view
    view.CurrentCamera = camera
    local label = Instance.new("TextLabel")
    label.Name = "Speaker"
    label.Position = UDim2.fromScale(0, cfg.face_height)
    label.Size = UDim2.fromScale(1, cfg.label_height)
    label.BackgroundTransparency = 1
    label.TextColor3 = color(cfg.label_color)
    label.TextStrokeColor3 = color(cfg.stroke_color)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = cfg.label_font_size
    label.Parent = card
    return setmetatable(
        { config = config, gui = gui, view = view, card = card, label = label },
        Presentation
    )
end
function Presentation:hide()
    self.gui.Enabled = false
    if self.head then
        self.head:Destroy()
    end
    if self.worldHead then
        self.worldHead:Destroy()
    end
    self.head, self.worldHead, self.offset, self.speaker = nil, nil, nil, nil
    self.worldInitialized, self.scan, self.worldDistance = nil, 0, nil
    self.worldLight = nil
end
function Presentation:show(speaker)
    self:hide()
    self.speaker = speaker
    self.label.Text = self.config.faces[speaker].label
end
function Presentation:_loadFace()
    local folder = ReplicatedStorage:FindFirstChild(self.config.templates_folder)
    local template = folder and folder:FindFirstChild(self.speaker)
    if not (template and template:IsA("BasePart")) then
        return
    end
    local cfg = self.config.presentation
    self.head = template:Clone()
    self.head.Size *= cfg.face_size / math.max(template.Size.X, template.Size.Y, template.Size.Z)
    self.head.CFrame = CFrame.identity
    self.head.Parent = self.view
    self.worldHead = self.head:Clone()
    self.worldHead.Name = "TutorialVoiceApparition"
    self.worldHead.Size *= WATCHER.size / cfg.face_size
    self.theme = WatcherDirector.theme(WATCHER, self.config.faces[self.speaker].side)
    self.worldLight = Instance.new("PointLight")
    self.worldLight.Color = color(self.theme.light_color)
    self.worldLight.Range = self.theme.light_range
    self.worldLight.Brightness = 0
    self.worldLight.Shadows = false
    self.worldLight.Parent = self.worldHead
end
function Presentation:step(dt, age, loudness, forcePortrait)
    if not self.speaker then
        return
    end
    if not self.head then
        self:_loadFace()
    end
    local cfg = self.config.presentation
    local inMenu = Players.LocalPlayer:GetAttribute("StarterPetChoiceOpen") == true
        or Players.LocalPlayer:GetAttribute("LargeMenuOpen") == true
        or Players.LocalPlayer:GetAttribute("TutorialHandoffOpen") == true
        or Players.LocalPlayer:GetAttribute("CombatTutorialPromptOpen") == true
    local position = inMenu and cfg.menu_position or cfg.portrait_position
    local size = inMenu and cfg.menu_size or cfg.portrait_size
    self.card.Position = UDim2.fromScale(position.x, position.y)
    self.card.Size = UDim2.fromScale(size.x, size.y)
    self.view.Size = UDim2.fromScale(1, inMenu and 1 or cfg.face_height)
    self.label.Visible = not inMenu
    local opacity = math.clamp(age / cfg.fade_seconds, 0, 1)
    self.gui.Enabled = true
    if not self.head then
        return
    end
    local speech = math.clamp(loudness / cfg.loudness_scale, 0, 1)
    local bob = math.sin(age * cfg.bob_rate) * cfg.bob_height
    local yaw = math.rad(
        math.sin(age * cfg.bob_rate) * (cfg.turn_degrees + speech * cfg.speech_turn_degrees)
    )
    self.head.CFrame = CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0)
    self.head.Transparency = 1 - opacity
    local player = Players.LocalPlayer
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not root or not camera then
        self.gui.Enabled = false
        self.worldHead.Parent = nil
        return
    end
    local portrait = forcePortrait or inMenu
    if not portrait then
        local distance = math.sqrt(WATCHER.distance ^ 2 + WATCHER.side_offset ^ 2)
        local viewport = camera.ViewportSize
        local halfHorizontal = math.atan(
            math.tan(math.rad(camera.FieldOfView) / 2) * viewport.X / math.max(1, viewport.Y)
        )
        local halfFace = math.atan(WATCHER.size / (2 * distance))
        local angle = math.min(
            math.rad(cfg.world_angle_degrees),
            math.max(0, halfHorizontal - halfFace - math.rad(cfg.screen_edge_padding_degrees))
        )
        local direction = (
            camera.CFrame.LookVector * math.cos(angle)
            + camera.CFrame.RightVector * math.sin(angle)
            + camera.CFrame.UpVector * math.tan(math.rad(cfg.world_vertical_degrees))
        ).Unit
        self.scan = (self.scan or 0) - dt
        if self.scan <= 0 then
            self.scan = cfg.occlusion_scan_seconds
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.RespectCanCollide = true
            params.FilterDescendantsInstances = { player.Character, self.worldHead }
            local hit = Workspace:Raycast(camera.CFrame.Position, direction * distance, params)
            self.worldDistance = hit
                    and math.max(
                        cfg.minimum_world_distance,
                        hit.Distance / (1 + WATCHER.size / (2 * distance)) - cfg.wall_clearance
                    )
                or distance
        end
        local actualDistance = self.worldDistance or distance
        local targetSize = self.head.Size
            * (WATCHER.size / cfg.face_size)
            * (actualDistance / distance)
        self.worldHead.Size = self.worldInitialized
                and self.worldHead.Size:Lerp(targetSize, 1 - math.exp(-WATCHER.follow_rate * dt))
            or targetSize
        local position = camera.CFrame.Position
            + direction * actualDistance
            + camera.CFrame.UpVector * bob
        local target = position
        if self.worldInitialized then
            local delta = target - self.worldHead.Position
            position = self.worldHead.Position
            if delta.Magnitude > 0 then
                position += delta.Unit * math.min(
                    delta.Magnitude * (1 - math.exp(-WATCHER.follow_rate * dt)),
                    WATCHER.max_speed * dt
                )
            end
            local rotation = self.worldHead.CFrame.Rotation:Lerp(
                CFrame.lookAt(position, camera.CFrame.Position).Rotation,
                1 - math.exp(-WATCHER.turn_rate * dt)
            )
            self.worldHead.CFrame = CFrame.new(position) * rotation
        else
            self.worldHead.CFrame = CFrame.lookAt(position, camera.CFrame.Position)
        end
        self.worldHead.Transparency = 1 - opacity
        self.worldLight.Brightness = self.theme.light_brightness * opacity
        self.worldInitialized = true
    end
    self.worldHead.Parent = not portrait and Workspace or nil
    self.gui.Enabled = portrait
    self.gui:SetAttribute("Presentation", portrait and "portrait" or "world")
end
function Presentation:destroy()
    self:hide()
    self.gui:Destroy()
end
return Presentation
