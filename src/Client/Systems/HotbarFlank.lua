--[[
    HotbarFlank (client) — dock Pets + Powers on either side of the power bar (Jason):

        [pets] [ ----------powerbar---------- ] [powers]

    Post-process in the MenuTrayStyle/CurrencyStack mold: BaseUI still BUILDS the buttons
    in the tray pane (click wiring untouched), MenuTrayStyle pill-styles them, and THIS
    module adopts the two into HotbarBar's root frame — full bar height, square (aspect
    constraint, Jason's relative-sizing convention), inheriting the bar's ViewportScale.
    The tutorial's PetsButton pulse finds the button by name recursively, so the move is
    transparent to it.
]]

local Players = game:GetService("Players")

local HotbarFlank = {}
local started = false

local SIDE = { PetsButton = "left", PowersButton = "right" }
-- tray-pill size + a gap that clears the bar's PillFrame OVERHANG (it extends ~23px
-- beyond the root each side — 14px overlapped; Jason: "their pill boxes are kind of
-- overlapping"). 62/34 live-tuned with him.
local SIZE = 62
local GAP = 26 -- just clear of the bar pill's ~23px overhang (Jason: closer)

function HotbarFlank.start()
    if started then
        return
    end
    started = true
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

    task.spawn(function()
        -- No give-up timeouts (see MenuTrayStyle): BaseUI + HotbarBar boot LATE, and on a non-owner
        -- account that boot stalls on failing asset loads past the old 20/30s windows. When this
        -- task gave up, Pets/Powers were never adopted out to flank the bar — they stayed in the raw
        -- vertical tray ("old HUD" on non-owner Studio sessions). Both guis are guaranteed to appear.
        local hotbarGui = pg:WaitForChild("HotbarBar")
        local bar = hotbarGui and hotbarGui:WaitForChild("Bar", 10)
        local base = pg:WaitForChild("ProfessionalBaseUI")
        local mc = base and base:WaitForChild("MainContainer", 10)
        local pane = mc and mc:WaitForChild("menu_buttons_pane", 15)
        if not (bar and pane) then
            return
        end

        for name, side in pairs(SIDE) do
            task.spawn(function()
                local btn = pane:WaitForChild(name, 15)
                if not btn then
                    return
                end
                -- let MenuTrayStyle pill it first (the adopt would hide it from that pass)
                local deadline = os.clock() + 8
                while not btn:GetAttribute("Pillified") and os.clock() < deadline do
                    task.wait(0.25)
                end
                btn.AnchorPoint = side == "left" and Vector2.new(1, 0.5) or Vector2.new(0, 0.5)
                btn.Position = side == "left" and UDim2.new(0, -GAP, 0.5, 0)
                    or UDim2.new(1, GAP, 0.5, 0)
                -- offset square (the bar's ViewportScale scales it with the bar). NOT an
                -- aspect constraint: its default FitWithinMaxSize treats a 0 width as a
                -- MAX and collapses to 0x0 — live-debugged ("little tiny dots").
                btn.Size = UDim2.fromOffset(SIZE, SIZE)
                local aspect = btn:FindFirstChildOfClass("UIAspectRatioConstraint")
                if aspect then
                    aspect:Destroy()
                end
                btn.Parent = bar -- inherits the bar's ViewportScale
            end)
        end
    end)
end

return HotbarFlank
