--[[
    AllianceBanner — the TEMPORARY ALLIANCE banner (Jason 2026-07-08, docs/TEAMING.md).

    Pure attribute renderer (UI = f(entity state)): BaddieSpawnerService stamps
    `AllianceWith` on BOTH sides of an alliance (the sidekicked player also carries
    `AllianceAnchor`), and this shows a top-center banner while the attribute is set —
    up when the alliance forms at a spawn trigger, gone when the server dissolves it
    after the fight. No remotes, no local timers: the server attribute IS the truth.

    Sidekicked player reads:  ⚔ TEMPORARY ALLIANCE — fighting beside <anchor> at Lv <N>
    Anchor reads:             ⚔ TEMPORARY ALLIANCE — <names> fight at your side
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local AllianceBanner = {}

local GOLD = Color3.fromRGB(255, 215, 90)

function AllianceBanner.start()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AllianceBanner"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.Parent = player:WaitForChild("PlayerGui")

    -- Top-center, just under the player bar. RELATIVE sizing (mobile-safe).
    local banner = Instance.new("Frame")
    banner.Name = "Banner"
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.Position = UDim2.new(0.5, 0, 0.115, 0)
    banner.Size = UDim2.new(0.34, 0, 0.042, 0)
    banner.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
    banner.BackgroundTransparency = 0.12
    banner.BorderSizePixel = 0
    banner.Visible = false
    banner.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = banner
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = GOLD
    stroke.Thickness = 2
    stroke.Transparency = 0.15
    stroke.Parent = banner

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -16, 0.52, 0)
    title.Position = UDim2.new(0, 8, 0.04, 0)
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextColor3 = GOLD
    title.Text = "⚔ TEMPORARY ALLIANCE"
    title.Parent = banner

    local sub = Instance.new("TextLabel")
    sub.Name = "Sub"
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1, -16, 0.4, 0)
    sub.Position = UDim2.new(0, 8, 0.56, 0)
    sub.Font = Enum.Font.Gotham
    sub.TextScaled = true
    sub.TextColor3 = Color3.fromRGB(230, 232, 245)
    sub.Text = ""
    sub.Parent = banner

    local function refresh()
        local with = player:GetAttribute("AllianceWith")
        if type(with) ~= "string" or with == "" then
            banner.Visible = false
            return
        end
        local anchorName = player:GetAttribute("AllianceAnchor")
        if type(anchorName) == "string" and anchorName ~= "" then
            -- I'm the sidekicked one: show who lifted me and my fighting level
            local eff = tonumber(player:GetAttribute("EffectiveLevel"))
                or tonumber(player:GetAttribute("Level"))
                or 1
            sub.Text = ("fighting beside %s at Lv %d"):format(anchorName, eff)
        else
            -- I'm the anchor: show who fights at my side (csv from the server)
            sub.Text = ("%s %s at your side"):format(
                (with:gsub(",", ", ")),
                with:find(",") and "fight" or "fights"
            )
        end
        if not banner.Visible then
            banner.Visible = true
            banner.BackgroundTransparency = 1
            stroke.Transparency = 1
            TweenService:Create(
                banner,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 0.12 }
            ):Play()
            TweenService:Create(
                stroke,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Transparency = 0.15 }
            ):Play()
        end
    end

    player:GetAttributeChangedSignal("AllianceWith"):Connect(refresh)
    player:GetAttributeChangedSignal("AllianceAnchor"):Connect(refresh)
    player:GetAttributeChangedSignal("EffectiveLevel"):Connect(refresh)
    refresh()
end

return AllianceBanner
