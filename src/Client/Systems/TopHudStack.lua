--[[
    TopHudStack (client) — pull the top-center cluster into ONE tight stack under the player bar.

    The ASCEND nudge (LevelUpGui), the quest tracker capsule (BaseUI pane) and the buff-toggle
    row (PlayerPowerBadges) are separate guis with independent pixel positions, so on small
    screens they drift apart / overlap (Jason: "this also" — stack them). Same structural fix
    as CurrencyStack: adopt them into a vertical UIListLayout container parented INSIDE the
    PlayerBar capsule — they inherit the capsule's UIViewportScale (own scales removed, no
    double-shrink) and the list owns the spacing, so the cluster reads tight at every size.

    UIListLayout skips invisible children, so the ASCEND nudge popping in/out just compacts
    the stack. Post-process: PlayerBar/LevelUpController/BaseUI logic untouched.
]]

local Players = game:GetService("Players")

local TopHudStack = {}
local started = false

function TopHudStack.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")

    task.spawn(function()
        local barGui = pg:WaitForChild("PlayerBar", 20)
        local cap = barGui and barGui:WaitForChild("Capsule", 10)
        if not cap then
            return
        end

        local stack = Instance.new("Frame")
        stack.Name = "TopHudStack"
        stack.AnchorPoint = Vector2.new(0.5, 0)
        stack.Position = UDim2.new(0.5, 0, 1, 6) -- just under the capsule
        stack.Size = UDim2.fromOffset(0, 0)
        stack.AutomaticSize = Enum.AutomaticSize.XY
        stack.BackgroundTransparency = 1
        stack.ZIndex = 5
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, 6)
        layout.Parent = stack
        stack.Parent = cap -- inherits the capsule's ViewportScale

        -- adopt(name): strip the element's own viewport scale (the capsule's covers it now),
        -- assign its slot in the stack. Each runs independently — late guis still join.
        local function adopt(order, getInstance)
            task.spawn(function()
                local inst = getInstance()
                if not inst then
                    return
                end
                local own = inst:FindFirstChild("ViewportScale")
                if own then
                    own:Destroy()
                end
                inst.LayoutOrder = order
                inst.Parent = stack
            end)
        end

        -- PERSISTENT elements first; the TRANSIENT ascend nudge goes LAST so it pops in
        -- BELOW them — the quest bar and toggles never shift when it appears/disappears.

        -- 1. quest tracker capsule (BaseUI pane, restyled by QuestTrackerStyle)
        adopt(1, function()
            -- No give-up timeout (see MenuTrayStyle): a non-owner's late/stalled BaseUI boot used to
            -- outlast the old 20s window, so the top-HUD panes were never adopted into the stack.
            local base = pg:WaitForChild("ProfessionalBaseUI")
            local mc = base and base:WaitForChild("MainContainer", 10)
            return mc and mc:WaitForChild("quest_tracker_pane", 15)
        end)

        -- (the buff-toggle row straddles the player bar's lower edge — PlayerPowerBadges
        -- docks it onto the capsule itself, enhancement-slot style; not part of this stack)

        -- 2. ASCEND / LEVEL UP nudge (transient — visible only with pending levels)
        adopt(2, function()
            local gui = pg:WaitForChild("LevelUpGui", 20)
            return gui and gui:WaitForChild("LevelUpButton", 10)
        end)
    end)
end

return TopHudStack
