local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
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
        { config = config, gui = gui, view = view, card = card, label = label, scan = 0 },
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
    local portrait = forcePortrait or not root or not camera
    if not portrait then
        if not self.offset then
            local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
            if forward.Magnitude < 0.01 then
                forward = Vector3.new(0, 0, -1)
            end
            forward = forward.Unit
            self.offset = forward * cfg.world_distance
                + Vector3.new(forward.Z, 0, -forward.X) * cfg.world_side
        end
        local position = root.Position + self.offset + Vector3.yAxis * (cfg.world_height + bob)
        self.worldHead.CFrame = CFrame.lookAt(position, root.Position) * CFrame.Angles(0, yaw, 0)
        self.worldHead.Transparency = 1 - opacity
        self.scan -= dt
        if self.scan <= 0 then
            self.scan = cfg.occlusion_scan_seconds
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { player.Character, self.worldHead }
            local _, visible = camera:WorldToViewportPoint(position)
            self.occluded = not visible
                or Workspace:Raycast(
                        camera.CFrame.Position,
                        position - camera.CFrame.Position,
                        params
                    )
                    ~= nil
        end
        portrait = self.occluded == true
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
