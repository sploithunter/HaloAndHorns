--[[
    CurrencyStack (client) — gather the five currency panes into ONE tight vertical stack.

    Each currency is its own BaseUI pane (own pill background/border — keep that), but as
    separate panes their POSITIONS are fixed pixel offsets while their SIZES shrink with
    UIViewportScale — so on small screens the pills drift apart (Jason: "they should be
    stacked"). Reparenting them into a single list container fixes it structurally: the
    UIListLayout owns the spacing and ONE UIScale on the container scales pills AND gaps
    together, so the stack reads identically at every viewport size.

    Post-process in the MenuTrayStyle/QuestTrackerStyle mold: BaseUI logic untouched.
    CurrencyStyle finds these panes recursively, so the reparent is transparent to it.
]]

local Players = game:GetService("Players")

local CurrencyStack = {}
local started = false

-- top-to-bottom pill order (gems first, then biome coins)
local PANES = {
    "gems_pane",
    "grass_coins_pane",
    "desert_coins_pane",
    "lava_coins_pane",
    "ice_coins_pane",
}

function CurrencyStack.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")

    task.spawn(function()
        -- No give-up timeout (see MenuTrayStyle): a non-owner's late/stalled BaseUI boot used to
        -- outlast the old 20s window, leaving the currency boxes un-stacked/unstyled.
        local base = pg:WaitForChild("ProfessionalBaseUI")
        local mc = base and base:WaitForChild("MainContainer", 10)
        if not mc then
            return
        end

        -- BOTTOM-LEFT (Jason's endgame HUD layout): money slides down to just above the lower-left
        -- menu buttons, out of the way — display-only, so it's safe there. Enemies own the TOP-left and
        -- grow DOWN into money's space (money collapses when they reach it). `stack` is the UNSCALED
        -- positioner (anchor bottom-left); the viewport scale lives on the inner `scaler` (a UIScale on
        -- the positioning frame would scale its position too). The scaler is TOP-anchored + AutomaticSize
        -- so it grows cleanly (a bottom-anchored auto-size frame nested in another reads height 0).
        -- `reflowAboveButtons` drops the stack's bottom just over the menu buttons — measured, so it's
        -- correct at any viewport / inset.
        local stack = Instance.new("Frame")
        stack.Name = "CurrencyStack"
        stack.AnchorPoint = Vector2.new(0, 1) -- bottom-left corner is the anchor; pills grow UP from it
        stack.Position = UDim2.new(0, 12, 0.62, 0) -- fallback; reflowed above the menu buttons below
        stack.Size = UDim2.fromOffset(140, 0)
        stack.AutomaticSize = Enum.AutomaticSize.Y
        stack.BackgroundTransparency = 1
        stack.ZIndex = 12
        stack.Parent = mc

        local scaler = Instance.new("Frame")
        scaler.Name = "Scaler"
        scaler.AnchorPoint = Vector2.new(0, 0) -- TOP-anchored: auto-sizes top-down without collapsing
        scaler.Position = UDim2.fromScale(0, 0)
        scaler.Size = UDim2.fromOffset(140, 0)
        scaler.AutomaticSize = Enum.AutomaticSize.Y
        scaler.BackgroundTransparency = 1
        scaler.Parent = stack
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.Padding = UDim.new(0, 5)
        layout.Parent = scaler
        -- ONE scale for the pills: pills + gaps shrink together (tight at any size)
        require(script.Parent.Parent.UI.UIViewportScale).attach(scaler)

        for order, name in ipairs(PANES) do
            task.spawn(function()
                local pane = mc:WaitForChild(name, 15)
                if not pane then
                    return
                end
                -- the pane's own per-pane scale would double-shrink inside the scaled stack
                local own = pane:FindFirstChild("ViewportScale")
                if own then
                    own:Destroy()
                end
                pane.LayoutOrder = order
                pane.Parent = scaler
            end)
        end

        -- Sit money's bottom just ABOVE the lower-left menu buttons. `stack` is unscaled and lives in
        -- MainContainer (which spans the whole screen, only inset-shifted), so a measured pixel offset
        -- lands device-correctly. Falls back to 63% of MainContainer when the buttons aren't found yet.
        local function reflowAboveButtons()
            local menu = mc:FindFirstChild("menu_buttons_pane")
                or mc:FindFirstChild("SettingsButton", true)
            local buttonsTop = menu and menu.AbsoluteSize.Y > 0 and menu.AbsolutePosition.Y
                or (mc.AbsolutePosition.Y + mc.AbsoluteSize.Y * 0.63)
            local posY = (buttonsTop - 8) - mc.AbsolutePosition.Y -- MainContainer maps 1:1 (only shifted)
            stack.Position = UDim2.new(0, 12, 0, math.floor(posY))
        end
        task.defer(reflowAboveButtons)
        local cam = workspace.CurrentCamera
        if cam then
            cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                task.defer(reflowAboveButtons)
            end)
        end
    end)
end

return CurrencyStack
