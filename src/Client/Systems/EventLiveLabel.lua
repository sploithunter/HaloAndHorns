--[[
    EventLiveLabel — drives the THEMED tray "Events" button (the EffectsButton, skinned by
    MenuTrayStyle to match Settings/Daily/Quest) as a live indicator for the active global event.

    No new UI is built here — the button comes from BaseUI's menu_buttons_pane and is skinned by
    MenuTrayStyle. This controller just reflects live state onto it:
      • idle  → label "Events" (neutral color).
      • active→ label = the soonest-expiring event's name in gold (wraps, e.g. "Secret Sunday").
               The gold text alone signals it's live — no glow/outline (Jason).
    Data: Signals.ActiveEffects (EventService:BuildClientPayload → .globalEvents). The button's CLICK
    (open the Effects panel) is handled by BaseUI's config (name="Effects"), not here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventLiveLabel = {}

local IDLE_TEXT = "Events"
local IDLE_COLOR = Color3.fromRGB(235, 240, 245)
local LIVE_COLOR = Color3.fromRGB(255, 244, 200)

-- Soonest-to-expire active event (permanents sort last); returns (event, totalCount) or (nil, 0).
local function pickHeadline(events)
    if type(events) ~= "table" then
        return nil, 0
    end
    local best, bestKey, count = nil, nil, 0
    for _, e in ipairs(events) do
        if type(e) == "table" then
            count += 1
            local rem = tonumber(e.remaining or e.timeRemaining) or -1
            local key = rem < 0 and math.huge or rem
            if not best or key < bestKey then
                best, bestKey = e, key
            end
        end
    end
    return best, count
end

-- Find the tray button BaseUI created (named "<name>Button") anywhere under PlayerGui.
local function findButton(playerGui, timeout)
    local deadline = os.clock() + (timeout or 12)
    while os.clock() < deadline do
        local found
        for _, d in ipairs(playerGui:GetDescendants()) do
            if d.Name == "EffectsButton" and (d:IsA("GuiButton") or d:IsA("GuiObject")) then
                found = d
                break
            end
        end
        if found then
            return found
        end
        task.wait(0.25)
    end
    return nil
end

function EventLiveLabel.start()
    local player = Players.LocalPlayer
    if not player then
        return
    end
    local playerGui = player:WaitForChild("PlayerGui")

    task.spawn(function()
        local button = findButton(playerGui, 15)
        if not button then
            return -- the Events button isn't in the tray (e.g. config change) — nothing to drive
        end
        local label = button:FindFirstChild("Label", true)
        local topLabel = button:FindFirstChild("LabelTop", true) -- stacked layout (text_top in config)

        -- Split "Secret Sunday" -> ("Secret", "Sunday") so it reads top / icon / bottom. One word ->
        -- all on the bottom (top blank). Trailing "+N" (extra events) rides the bottom line.
        local function splitName(name)
            local words = {}
            for w in tostring(name):gmatch("%S+") do
                words[#words + 1] = w
            end
            if #words <= 1 then
                return "", tostring(name)
            end
            return words[1], table.concat(words, " ", 2)
        end

        local headline, count = nil, 0
        local function render()
            local top, bottom, color
            if headline then
                local name = tostring(headline.displayName or headline.name or "Event")
                top, bottom = splitName(name)
                if count > 1 then
                    bottom = bottom .. " +" .. (count - 1)
                end
                color = LIVE_COLOR
            else
                top, bottom, color = "", IDLE_TEXT, IDLE_COLOR
            end
            if topLabel and topLabel:IsA("TextLabel") then
                topLabel.Text = top
                topLabel.TextColor3 = color
            end
            if label and label:IsA("TextLabel") then
                label.Text = bottom
                label.TextColor3 = color
            end
        end

        local okS, Signals = pcall(function()
            return require(ReplicatedStorage.Shared.Network.Signals)
        end)
        if okS and Signals and Signals.ActiveEffects then
            Signals.ActiveEffects.OnClientEvent:Connect(function(payload)
                if type(payload) ~= "table" then
                    return
                end
                headline, count = pickHeadline(payload.globalEvents)
                render()
            end)
            pcall(function()
                Signals.ActiveEffects:FireServer({ request = true })
            end)
        end

        render()
    end)
end

return EventLiveLabel
