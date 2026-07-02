--[[
    DevSpawnPanel — Studio-only on-screen buttons to spawn test enemies + clear them.

    A quick combat-testing rig: a small button strip on the primary HUD (left edge, by the pets
    cluster) that fires the Studio-gated combat.spawnEnemy / combat.clearEnemies bus commands. Only
    runs in Studio (RunService:IsStudio()) so it never ships to players. Tune SPAWNS to taste.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevSpawnPanel = {}
local started = false

-- Each button: a label + a `pack` = one or more combat.spawnEnemy arg-sets fired together. spread =
-- ring radius so a group doesn't stack; forward = push further out (the "Far Dummy" is an
-- out-of-AoE-range control). A multi-entry pack spawns a MIXED-role wave in one click (e.g. the
-- Earth warband) — handy for eyeballing imported art + the role/surround systems side by side.
local SPAWNS = {
    {
        label = "🎯 Dummy ×3",
        pack = { { enemyId = "training_dummy", count = 3, spread = 7 } },
        color = { 90, 140, 200 },
    },
    {
        label = "🎯 Far Dummy",
        pack = { { enemyId = "training_dummy", count = 1, forward = 40 } },
        color = { 70, 110, 160 },
    },
    -- Earth faction — individual spawns to verify each imported mesh renders + moves right.
    {
        label = "🐕 Rabid Dog ×3",
        pack = { { enemyId = "rabid_dog", count = 3, spread = 7 } },
        color = { 150, 110, 80 },
    },
    {
        label = "🐦 Murder Crow ×3",
        pack = { { enemyId = "murder_crow", count = 3, spread = 7 } },
        color = { 80, 80, 110 },
    },
    {
        label = "🐈 Vicious Cat ×2",
        pack = { { enemyId = "vicious_cat", count = 2, spread = 6 } },
        color = { 150, 130, 90 },
    },
    {
        label = "🐰 Jackalope",
        pack = { { enemyId = "rabid_bunny", count = 1 } },
        color = { 180, 120, 150 },
    },
    {
        label = "🐻 Bear",
        pack = { { enemyId = "raging_bear", count = 1 } },
        color = { 170, 110, 60 },
    },
    -- Mixed packs (Jason: the old "Imp ×3" spawned bunnies — replaced by a real Earth pack).
    {
        label = "🐕 Pack: 2 Dog + Jackalope",
        pack = {
            { enemyId = "rabid_dog", count = 2, spread = 7 },
            { enemyId = "rabid_bunny", count = 1, forward = 8 },
        },
        color = { 160, 100, 90 },
    },
    {
        label = "💀 Scary Team",
        pack = {
            -- tank wall = raging_bear (modeled); ember_brute is Lava/unmodeled (a placeholder block).
            { enemyId = "raging_bear", count = 1 },
            { enemyId = "rabid_bunny", count = 1, forward = 10 },
            { enemyId = "rabid_dog", count = 3, spread = 9 },
            { enemyId = "murder_crow", count = 2, spread = 12, forward = 14 },
        },
        color = { 120, 60, 80 },
    },
}

local function rgb(t)
    return Color3.fromRGB(t[1], t[2], t[3])
end

function DevSpawnPanel.start()
    if started or not RunService:IsStudio() then
        return -- dev-only; never present for real players
    end
    started = true

    local player = Players.LocalPlayer
    local gui = Instance.new("ScreenGui")
    gui.Name = "DevSpawnPanel"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 50
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0, 0)
    -- Top-left, above the currency column (center-left) so the dev buttons don't cover the
    -- biome-coin HUD during testing. (Studio-only temporary menu.)
    frame.Position = UDim2.new(0, 258, 0, 64) -- right of the meters/buffs column
    frame.Size = UDim2.fromOffset(120, 10)
    frame.BackgroundTransparency = 1
    frame.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local title = Instance.new("TextLabel")
    title.LayoutOrder = 0
    title.Size = UDim2.fromOffset(120, 16)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextColor3 = Color3.fromRGB(255, 210, 130)
    title.TextStrokeTransparency = 0.4
    title.Text = "DEV · SPAWN"
    title.Parent = frame

    local remote = ReplicatedStorage:WaitForChild("GameAPICommand")
    local function fire(command, args)
        task.spawn(function()
            pcall(function()
                remote:InvokeServer(command, args or {})
            end)
        end)
    end

    local function button(order, text, color, onClick)
        local b = Instance.new("TextButton")
        b.LayoutOrder = order
        b.Size = UDim2.fromOffset(120, 28)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.AutoButtonColor = true
        b.Text = text
        b.Parent = frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = b
        b.Activated:Connect(onClick)
        return b
    end

    for i, s in ipairs(SPAWNS) do
        button(i, s.label, rgb(s.color), function()
            for _, unit in ipairs(s.pack) do
                fire("combat.spawnEnemy", unit)
            end
        end)
    end
    button(#SPAWNS + 1, "✖ Clear", Color3.fromRGB(80, 80, 100), function()
        fire("combat.clearEnemies", {})
    end)
end

return DevSpawnPanel
