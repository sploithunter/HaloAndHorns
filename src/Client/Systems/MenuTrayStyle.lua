--[[
    MenuTrayStyle (client) — skin the lower-left tray buttons (Trade/Admin/Daily/Quest/Shop/Items/
    Effects/Settings/Rewards) with Jason's pill art: a glossy pill_panel background +
    a neon pill_frame border behind the existing icon + label, matching
    assets/ui/reference/quest_button_reference.jpg.

    Done as a scoped post-process (named buttons only) so BaseUI's button-building logic is untouched.
    The tray takes the home-area pill color (via UITheme, sapphire default) and re-tints on area change;
    Rewards is a NORMAL menu_button since 2026-06-10 (the standalone pane + transplant were
    artifacts); Admin is adopted OUT of the grid to float just above the tray. (was: moved next to
    the Pets paw. Idempotent per button.

    Icon-ready: the restyle lifts whatever icon child BaseUI made (TextLabel emoji OR ImageLabel asset)
    above the pills and only outlines TEXT — so swapping in real icon image ids later needs no change.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PILL = require(ReplicatedStorage.Configs:WaitForChild("pill_ui"))

local MenuTrayStyle = {}
local started = false

local TRAY_BUTTONS = {
    "PetsButton",
    "PowersButton",
    "AdminButton",
    "RewardsButton",
    "DailyButton",
    "QuestButton",
    "ShopButton",
    "EffectsButton",
    "SettingsButton",
    "AchievementsButton",
}

local function pillKey(theme)
    local key = theme and theme.color
    if key == nil or key == "neutral" or not PILL.panels[key] then
        key = "sapphire"
    end
    return key
end

-- Skin one button with a pill_panel + pill_frame of `key`, lifting its icon/label above. If rebind is
-- given, the panel/frame are recorded so they can be re-tinted when the area changes.
local function styleButton(btn, key, rebind)
    if btn:GetAttribute("Pillified") then
        return
    end
    btn:SetAttribute("Pillified", true)

    if btn:IsA("ImageButton") then
        btn.Image = ""
    end
    btn.BackgroundTransparency = 1
    for _, c in ipairs(btn:GetChildren()) do
        if c:IsA("UIGradient") or c:IsA("UIStroke") or c:IsA("UICorner") then
            c:Destroy()
        end
    end

    local panel = Instance.new("ImageLabel")
    panel.Name = "PillPanel"
    panel.BackgroundTransparency = 1
    panel.ScaleType = Enum.ScaleType.Fit
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromScale(0.84, 0.84)
    panel.Image = PILL.panels[key]
    panel.ZIndex = 13
    panel.Parent = btn
    local frame = Instance.new("ImageLabel")
    frame.Name = "PillFrame"
    frame.BackgroundTransparency = 1
    frame.ScaleType = Enum.ScaleType.Fit
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Size = UDim2.fromScale(1.0, 1.0)
    frame.Image = PILL.frames[key]
    frame.ZIndex = 14
    frame.Parent = btn

    for _, c in ipairs(btn:GetChildren()) do
        if c ~= panel and c ~= frame and c:IsA("GuiObject") then
            c.ZIndex = 16
            if c:IsA("TextLabel") then
                c.TextColor3 = Color3.fromRGB(245, 248, 255)
                if not c:FindFirstChildOfClass("UIStroke") then
                    local s = Instance.new("UIStroke")
                    s.Color = Color3.fromRGB(10, 30, 60)
                    s.Thickness = 2
                    s.Parent = c
                end
            end
        end
    end

    if rebind then
        table.insert(rebind, { panel = panel, frame = frame })
    end
end

function MenuTrayStyle.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")
    local Theme = require(script.Parent.Parent.UI.UITheme)

    task.spawn(function()
        -- No give-up timeout: BaseUI boots LATE (behind panel construction + asset prewarm), and on
        -- a non-owner account that boot stalls on failing asset loads past any short window. A fixed
        -- 20s timeout here meant the styler gave up and left the raw, unstyled tray ("old HUD" on
        -- non-owner Studio sessions). ProfessionalBaseUI is guaranteed to appear — wait for it.
        local base = pg:WaitForChild("ProfessionalBaseUI")
        local mc = base and base:WaitForChild("MainContainer", 10)
        if not mc then
            return
        end

        local styled = {} -- tray panels/frames that re-tint with the area
        local theme = Theme.palette(player)

        -- 8 tray buttons (area color)
        local pane = mc:WaitForChild("menu_buttons_pane", 15)
        task.spawn(function()
            for _ = 1, 10 do
                if pane then
                    for _, name in ipairs(TRAY_BUTTONS) do
                        local btn = pane:FindFirstChild(name)
                        if btn then
                            styleButton(btn, pillKey(theme), styled)
                        end
                    end
                end
                task.wait(0.5)
            end
        end)

        -- ADMIN now stays IN the grid as the last cell (Jason: "just make the admin button last in
        -- the grid"). The grid fills bottom-to-top / left-to-right, so its high LayoutOrder lands it
        -- in the final slot — no floating/docking (that overlapped the new Events button) and it
        -- inherits the pane's pill skin + UIViewportScale like every other tray button.

        -- re-tint the tray on area change
        Theme.bind(player, function(p)
            theme = p
            local key = pillKey(p)
            for _, s in ipairs(styled) do
                s.panel.Image = PILL.panels[key]
                s.frame.Image = PILL.frames[key]
            end
        end)
    end)
end

return MenuTrayStyle
