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
local UI_CONFIG = require(ReplicatedStorage.Configs:WaitForChild("ui"))
local COMPACT_MENU_DISPLAY_ORDER = assert(
    tonumber(UI_CONFIG.display_order and UI_CONFIG.display_order.compact_menu_overlay),
    "configs/ui.lua display_order.compact_menu_overlay is required"
)
local COMPACT_MENU_LAYOUT = assert(
    UI_CONFIG.hud and UI_CONFIG.hud.compact_menu,
    "configs/ui.lua hud.compact_menu is required"
)
local COMPACT_MENU_COLUMNS = assert(
    tonumber(COMPACT_MENU_LAYOUT.columns),
    "configs/ui.lua hud.compact_menu.columns is required"
)
local COMPACT_MENU_CELL =
    assert(COMPACT_MENU_LAYOUT.cell, "configs/ui.lua hud.compact_menu.cell is required")
local COMPACT_MENU_GAP =
    assert(COMPACT_MENU_LAYOUT.gap, "configs/ui.lua hud.compact_menu.gap is required")
local COMPACT_MENU_MINIMUM_SCALE = assert(
    tonumber(COMPACT_MENU_LAYOUT.minimum_scale),
    "configs/ui.lua hud.compact_menu.minimum_scale is required"
)
local COMPACT_MENU_ANCHOR_GAP = assert(
    tonumber(COMPACT_MENU_LAYOUT.anchor_gap),
    "configs/ui.lua hud.compact_menu.anchor_gap is required"
)
local COMPACT_MENU_LEFT_FLOOR = assert(
    tonumber(COMPACT_MENU_LAYOUT.left_floor),
    "configs/ui.lua hud.compact_menu.left_floor is required"
)

local MenuTrayStyle = {}
local started = false

local TRAY_BUTTONS = {
    "PetsButton",
    "PowersButton",
    "HoverboardButton",
    "AdminButton",
    "RewardsButton",
    "DailyButton",
    "QuestButton",
    "ShopButton",
    "EffectsButton",
    "SettingsButton",
    "AchievementsButton",
}

-- Compact Menu contains only the occasional utility actions. Pets/Powers remain permanent hotbar
-- flank controls because the tutorial and the core play loop teach and use those exact locations.
local COMPACT_MENU_BUTTONS = {
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

        -- Mobile rests as ONE Menu pill. The original tray cannot be reused as the expanded view:
        -- BaseUI owns its visibility/layout and may turn it back on after this post-process runs.
        -- Instead, compact mode temporarily adopts the REAL buttons into a dedicated two-column
        -- popup. Actions/badges stay canonical, while the popup gets geometry that is safe on a
        -- short landscape phone. Classic mode restores every button to the original pane.
        if pane then
            local compactExpanded = false
            local adopting = false
            local adopted = {}

            -- ZIndex cannot order descendants across separate ScreenGuis. Keep only the expanded
            -- popup in a config-ordered overlay so SquadHud pets remain visible underneath without
            -- painting over the menu or intercepting its buttons.
            local overlayGui = Instance.new("ScreenGui")
            overlayGui.Name = "CompactMenuOverlayGui"
            overlayGui.DisplayOrder = COMPACT_MENU_DISPLAY_ORDER
            overlayGui.IgnoreGuiInset = base.IgnoreGuiInset
            overlayGui.ResetOnSpawn = base.ResetOnSpawn
            overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            overlayGui.Parent = pg

            local popup = Instance.new("Frame")
            popup.Name = "CompactMenuPopup"
            popup.AnchorPoint = Vector2.new(0, 1)
            popup.Position = UDim2.new(0, 15, 1, -88)
            local popupRows = math.ceil(#COMPACT_MENU_BUTTONS / COMPACT_MENU_COLUMNS)
            popup.Size = UDim2.fromOffset(
                COMPACT_MENU_COLUMNS * COMPACT_MENU_CELL.width
                    + (COMPACT_MENU_COLUMNS - 1) * COMPACT_MENU_GAP.x,
                popupRows * COMPACT_MENU_CELL.height + (popupRows - 1) * COMPACT_MENU_GAP.y
            )
            popup.BackgroundTransparency = 1
            popup.Visible = false
            popup.ZIndex = 19
            popup.Parent = overlayGui
            require(script.Parent.Parent.UI.UIViewportScale).attach(
                popup,
                { min = COMPACT_MENU_MINIMUM_SCALE }
            )
            local popupGrid = Instance.new("UIGridLayout")
            popupGrid.CellSize = UDim2.fromOffset(COMPACT_MENU_CELL.width, COMPACT_MENU_CELL.height)
            popupGrid.CellPadding = UDim2.fromOffset(COMPACT_MENU_GAP.x, COMPACT_MENU_GAP.y)
            popupGrid.FillDirection = Enum.FillDirection.Horizontal
            popupGrid.FillDirectionMaxCells = COMPACT_MENU_COLUMNS
            popupGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
            popupGrid.SortOrder = Enum.SortOrder.LayoutOrder
            popupGrid.VerticalAlignment = Enum.VerticalAlignment.Bottom
            popupGrid.Parent = popup

            local compactMenu = Instance.new("TextButton")
            compactMenu.Name = "CompactMenuButton"
            compactMenu.AnchorPoint = Vector2.new(0, 1)
            compactMenu.Position = UDim2.new(0, 15, 1, -15)
            compactMenu.Size = UDim2.fromOffset(68, 68)
            compactMenu.BackgroundTransparency = 1
            compactMenu.AutoButtonColor = false
            compactMenu.Text = ""
            compactMenu.Visible = false
            compactMenu.ZIndex = 20
            compactMenu.Parent = mc
            require(script.Parent.Parent.UI.UIViewportScale).attach(
                compactMenu,
                { min = COMPACT_MENU_MINIMUM_SCALE }
            )

            local menuIcon = Instance.new("TextLabel")
            menuIcon.Name = "Icon"
            menuIcon.BackgroundTransparency = 1
            menuIcon.Position = UDim2.new(0, 0, 0, 5)
            menuIcon.Size = UDim2.new(1, 0, 0.58, 0)
            menuIcon.Font = Enum.Font.GothamBold
            menuIcon.Text = "☰"
            menuIcon.TextSize = 25
            menuIcon.TextColor3 = Color3.fromRGB(245, 248, 255)
            menuIcon.ZIndex = 22
            menuIcon.Parent = compactMenu
            local menuLabel = Instance.new("TextLabel")
            menuLabel.Name = "Label"
            menuLabel.BackgroundTransparency = 1
            menuLabel.Position = UDim2.new(0, 0, 0.58, -2)
            menuLabel.Size = UDim2.new(1, 0, 0.36, 0)
            menuLabel.Font = Enum.Font.GothamBold
            menuLabel.Text = "Menu"
            menuLabel.TextSize = 13
            menuLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
            menuLabel.ZIndex = 22
            menuLabel.Parent = compactMenu
            styleButton(compactMenu, pillKey(theme), styled)

            local applyCompactTray

            compactMenu.Activated:Connect(function()
                compactExpanded = not compactExpanded
                applyCompactTray()
            end)

            local function rememberButton(btn)
                if adopted[btn] or not btn:IsA("GuiButton") then
                    return
                end
                styleButton(btn, pillKey(theme), styled)
                adopted[btn] = {
                    parent = pane,
                    position = btn.Position,
                    size = btn.Size,
                    anchorPoint = btn.AnchorPoint,
                    layoutOrder = btn.LayoutOrder,
                    visible = btn.Visible,
                }
                btn.Activated:Connect(function()
                    if player:GetAttribute("HudLayoutResolved") == "compact" then
                        compactExpanded = false
                        applyCompactTray()
                    end
                end)
            end

            local function collectButtons()
                for _, name in ipairs(COMPACT_MENU_BUTTONS) do
                    local btn = pane:FindFirstChild(name)
                    if btn then
                        rememberButton(btn)
                    end
                end
            end

            local function reflowPopup()
                if not (compactMenu.Parent and popup.Parent) then
                    return
                end
                -- Menu now flanks the hotbar. Open the grid just above that square.
                local menuPos = compactMenu.AbsolutePosition
                local menuSize = compactMenu.AbsoluteSize
                local origin = mc.AbsolutePosition
                local x = menuPos.X + menuSize.X * 0.5 - origin.X
                local y = menuPos.Y - COMPACT_MENU_ANCHOR_GAP - origin.Y
                popup.AnchorPoint = Vector2.new(0.5, 1)
                -- The config-owned floor keeps a left-of-bar Menu from clipping the popup.
                popup.Position = UDim2.fromOffset(
                    math.max(COMPACT_MENU_LEFT_FLOOR, math.floor(x)),
                    math.floor(y)
                )
            end

            applyCompactTray = function()
                if adopting then
                    return
                end
                adopting = true
                collectButtons()
                local compact = player:GetAttribute("HudLayoutResolved") == "compact"
                compactMenu.Visible = compact
                popup.Visible = compact and compactExpanded
                player:SetAttribute("CompactMenuExpanded", compact and compactExpanded)

                if compact then
                    reflowPopup()
                    -- The old container remains hidden even if BaseUI tries to re-open it later.
                    pane.Visible = false
                    for btn, saved in pairs(adopted) do
                        if btn.Parent ~= popup then
                            saved.visible = btn.Visible
                            btn.Parent = popup
                        end
                        btn.AnchorPoint = Vector2.zero
                        btn.Size =
                            UDim2.fromOffset(COMPACT_MENU_CELL.width, COMPACT_MENU_CELL.height)
                        btn.Visible = saved.visible
                    end
                else
                    compactExpanded = false
                    popup.Visible = false
                    player:SetAttribute("CompactMenuExpanded", false)
                    for btn, saved in pairs(adopted) do
                        btn.Parent = saved.parent
                        btn.Position = saved.position
                        btn.Size = saved.size
                        btn.AnchorPoint = saved.anchorPoint
                        btn.LayoutOrder = saved.layoutOrder
                        btn.Visible = saved.visible
                    end
                    pane.Visible = true
                end
                adopting = false
            end

            -- BaseUI can update the legacy pane after boot. Enforce the compact contract instead of
            -- allowing six old buttons to leak back behind the single Menu control.
            pane:GetPropertyChangedSignal("Visible"):Connect(function()
                if
                    not adopting
                    and player:GetAttribute("HudLayoutResolved") == "compact"
                    and pane.Visible
                then
                    applyCompactTray()
                end
            end)
            pane.ChildAdded:Connect(function(child)
                if table.find(COMPACT_MENU_BUTTONS, child.Name) then
                    task.defer(applyCompactTray)
                end
            end)
            player:GetAttributeChangedSignal("HudLayoutResolved"):Connect(applyCompactTray)
            compactMenu:GetPropertyChangedSignal("AbsolutePosition"):Connect(reflowPopup)
            compactMenu:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflowPopup)
            applyCompactTray()
        end

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
