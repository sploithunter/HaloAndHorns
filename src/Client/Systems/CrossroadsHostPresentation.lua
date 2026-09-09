-- The authored, shared heads supply the world performance; no duplicate camera-follow face.
local Players = game:GetService("Players")
local Presentation = {}
Presentation.__index = Presentation
function Presentation.new()
    local gui = Instance.new("ScreenGui")
    gui.Name = "CrossroadsHostVoice"
    gui.Enabled, gui.ResetOnSpawn = false, false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    return setmetatable({ gui = gui }, Presentation)
end
function Presentation:show(speaker)
    self.gui:SetAttribute("Speaker", speaker)
end
function Presentation:hide()
    self.gui.Enabled = false
end
function Presentation:step()
    self.gui.Enabled = false
end
function Presentation:destroy()
    self.gui:Destroy()
end
return Presentation
