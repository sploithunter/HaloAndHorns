-- Loading may reveal the world before a throttled profile arrives. Keep the next action clear.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Configs.merge_egg_prototype).place_join
local places = require(ReplicatedStorage.Configs.places)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local Status = {}
local started = false
function Status.start()
    if started or not PlaceRuntime.isMerge(game.PlaceId, places) then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "MergeJoinStatus", false, config.display_order
    local text = Instance.new("TextLabel")
    text.AnchorPoint = Vector2.new(0.5, 0.5)
    text.Position = UDim2.fromScale(config.position[1], config.position[2])
    text.Size = UDim2.new(config.width_scale, 0, 0, config.height)
    text.TextColor3 = Color3.fromRGB(table.unpack(config.text_color))
    text.BackgroundColor3 = Color3.fromRGB(table.unpack(config.background))
    text.TextSize, text.TextWrapped, text.Font = config.text_size, true, Enum.Font.GothamBold
    text.Parent = gui
    local function refresh()
        local message = config.messages[player:GetAttribute("MergeJoinStatus")]
        gui.Enabled = message ~= nil and player:GetAttribute("InMergeEggPrototype") ~= true
        text.Text = message or ""
    end
    player:GetAttributeChangedSignal("MergeJoinStatus"):Connect(refresh)
    player:GetAttributeChangedSignal("InMergeEggPrototype"):Connect(refresh)
    refresh()
    gui.Parent = player:WaitForChild("PlayerGui")
end
return Status
