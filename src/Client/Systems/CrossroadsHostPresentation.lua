-- Each listener has a nearby guide; authored gate hosts remain shared world actors.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local config = require(ReplicatedStorage.Configs.crossroads_hosts)
local Hatch = require(ReplicatedStorage.Shared.Services.EggHatchingService)
local Presentation = {}
Presentation.__index = Presentation
function Presentation.new()
    local gui = Instance.new("ScreenGui")
    gui.Name = "CrossroadsHostVoice"
    gui.Enabled, gui.ResetOnSpawn = false, false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    local self = setmetatable({ gui = gui, faces = {} }, Presentation)
    self.connection = RunService.RenderStepped:Connect(function(dt)
        self:_follow(dt)
    end)
    return self
end
function Presentation:voiceParent(speaker)
    local face = self.faces[speaker]
    if face and face.Parent then
        return face
    end
    local templates = ReplicatedStorage:FindFirstChild(config.template_folder)
    local template = templates and templates:FindFirstChild(speaker)
    if not template then
        return nil
    end
    face = template:Clone()
    face.Name = "CrossroadsCompanion_" .. speaker
    face.Size *= config.companion.size / math.max(face.Size.X, face.Size.Y, face.Size.Z)
    face.Transparency = 1
    face.Parent = workspace
    self.faces[speaker] = face
    return face
end
function Presentation:show(speaker)
    self.speaker = speaker
    self.gui:SetAttribute("Speaker", speaker)
    self:_follow(0)
end
function Presentation:hide()
    self.speaker = nil
    self.gui.Enabled = false
end
function Presentation:step() end
function Presentation:_follow(dt)
    local player = Players.LocalPlayer
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local active = root
        and humanoid
        and humanoid.Health > 0
        and player:GetAttribute("InCrossroads") == true
    local speaker = active and (self.speaker or player:GetAttribute("CrossroadsGuide") or "angel")
    if
        speaker
        and not self.speaker
        and player:GetAttribute(config.hosts[speaker].visited_attribute) == true
    then
        speaker = nil
    end
    local face = speaker and self:voiceParent(speaker)
    local visible = active
        and player:GetAttribute("ClientUIReady") == true
        and player:GetAttribute("LargeMenuOpen") ~= true
        and not GuiService.MenuIsOpen
        and Hatch:IsHatchReady()
    for name, other in pairs(self.faces) do
        other.Transparency = visible and name == speaker and 0 or 1
    end
    if not (active and face and workspace.CurrentCamera) then
        self.following = nil
        return
    end
    local cfg = config.companion
    local changed = self.following ~= speaker
    if changed then
        local look = workspace.CurrentCamera.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)
        if forward.Magnitude == 0 then
            forward = root.CFrame.LookVector
        end
        forward = forward.Unit
        self.offset = forward * cfg.distance
            + Vector3.new(-forward.Z, 0, forward.X) * cfg.side_offset
            + Vector3.yAxis * cfg.height
        self.following = speaker
    end
    local target = root.Position + self.offset
    local delta = target - face.Position
    local position = face.Position
    if changed or delta.Magnitude > cfg.teleport_distance then
        position = target
    elseif delta.Magnitude > 0 then
        position += delta.Unit * math.min(
            delta.Magnitude * (1 - math.exp(-cfg.follow_rate * dt)),
            cfg.max_speed * dt
        )
    end
    local rotation = CFrame.lookAt(position, root.Position).Rotation
    if not changed then
        rotation = face.CFrame.Rotation:Lerp(rotation, 1 - math.exp(-cfg.turn_rate * dt))
    end
    face.CFrame = CFrame.new(position) * rotation
end
function Presentation:destroy()
    self.connection:Disconnect()
    for _, face in pairs(self.faces) do
        face:Destroy()
    end
    self.gui:Destroy()
end
return Presentation
