--[[
    PetSyncDiag (client) — an ADMIN overlay that makes pet client<->server position desync VISIBLE
    live, so a "my pets do nothing" bug is diagnosable in-game instead of by reading the server.

    Pets are client-moved (smooth locally) but server combat gates damage off the position the client
    REPORTS (PetFollowService.GetReportedPosition). When that report stalls, the server falls back to
    the owner and the squad can mis-engage. This panel shows, per equipped pet:
        Δ <studs>   — gap between where YOUR client renders the pet and the position SERVER combat is
                      using (pet.DiagGatePos, stamped by PetFollowService). Big Δ = the server is
                      acting on a stale/wrong position.
        rpt <secs>  — age of the last client->server position report. "FALLBACK" = no report; combat
                      is using the owner position (the safety net), not a real pet position.
    Green = healthy, red = desynced/stale. Gated behind AdminOverlaysOn (AdminController toggles it).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetSyncDiag = {}
local started = false

local GOOD = Color3.fromRGB(110, 215, 130)
local WARN = Color3.fromRGB(240, 200, 90)
local BAD = Color3.fromRGB(235, 90, 80)

function PetSyncDiag.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "PetSyncDiag"
    gui.ResetOnSpawn = false
    gui.Enabled = false -- AdminController flips this with the other dev overlays
    gui.DisplayOrder = 95
    gui.Parent = pg

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0, 1)
    panel.Position = UDim2.new(0, 8, 1, -150)
    panel.Size = UDim2.fromOffset(232, 96)
    panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    panel.BackgroundTransparency = 0.15
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = panel
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 1)
    list.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = panel

    local title = Instance.new("TextLabel")
    title.LayoutOrder = 0
    title.Size = UDim2.new(1, 0, 0, 14)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(180, 190, 210)
    title.Text = "PET SYNC (Δ client↔server · report age)"
    title.Parent = panel

    local rows = {} -- pet -> TextLabel

    local function rowFor(pet, order)
        local r = rows[pet]
        if not r then
            r = Instance.new("TextLabel")
            r.Size = UDim2.new(1, 0, 0, 13)
            r.BackgroundTransparency = 1
            r.Font = Enum.Font.Code
            r.TextSize = 11
            r.TextXAlignment = Enum.TextXAlignment.Left
            r.Parent = panel
            rows[pet] = r
        end
        r.LayoutOrder = order
        return r
    end

    local accum = 0
    RunService.RenderStepped:Connect(function(dt)
        if not gui.Enabled then
            return
        end
        accum += dt
        if accum < 0.15 then
            return
        end
        accum = 0

        local folder = Workspace:FindFirstChild("PlayerPets")
        folder = folder and folder:FindFirstChild(player.Name)
        local seen = {}
        local n = 0
        if folder then
            for _, pet in ipairs(folder:GetChildren()) do
                if pet:IsA("Model") and pet.PrimaryPart then
                    n += 1
                    seen[pet] = true
                    local clientPos = pet:GetPivot().Position
                    local gatePos = pet:GetAttribute("DiagGatePos")
                    local age = pet:GetAttribute("DiagReportAge")
                    local delta = (typeof(gatePos) == "Vector3") and (clientPos - gatePos).Magnitude
                        or -1
                    local r = rowFor(pet, n)
                    local ageStr = (age == nil) and "?"
                        or (age < 0 and "FALLBACK")
                        or string.format("%.1fs", age)
                    r.Text = string.format(
                        "%-10s Δ%s  rpt %s",
                        string.sub(pet.Name, 1, 10),
                        delta >= 0 and string.format("%4.0f", delta) or "  ?",
                        ageStr
                    )
                    -- red if the server is acting on a far/absent position; amber if mildly stale.
                    if age == nil or age < 0 or delta > 25 then
                        r.TextColor3 = BAD
                    elseif age > 0.6 or delta > 10 then
                        r.TextColor3 = WARN
                    else
                        r.TextColor3 = GOOD
                    end
                end
            end
        end
        -- drop rows for pets that left
        for pet, r in pairs(rows) do
            if not seen[pet] then
                r:Destroy()
                rows[pet] = nil
            end
        end
        panel.Size = UDim2.fromOffset(232, 22 + math.max(1, n) * 14)
    end)
end

return PetSyncDiag
