--[[
    RealmPortalSideGate — back-to-back realm portals (heaven on one face,
    hell on the other) both use E, and Roblox shows whichever prompt PART is
    closest. The hell prompt anchors near the ground while the heaven plane
    centers ~9 studs up, so the hell prompt wins even on heaven's side
    (Jason, 2026-07-09: "if I get too close on the heaven side the proximity
    for hell pops up").

    Fix: pair up co-located RealmPortalPrompts (discovered lazily on first
    PromptShown) and, while the player is near a pair, locally Enable only
    the prompt on the player's side of the dividing plane. Local Enabled
    also blocks triggering, so you can't accidentally travel the wrong way.
    Prompts with no nearby twin are left alone.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local PROMPT_NAME = "RealmPortalPrompt"
local PAIR_RADIUS = 12 -- studs: prompts closer than this are two faces of one portal
local ACTIVE_RADIUS = 30 -- studs: run the side test while the player is this close
local HYSTERESIS = 0.75 -- studs of deadband so the prompt doesn't flicker on the plane

local RealmPortalSideGate = {}

function RealmPortalSideGate.start()
    local player = Players.LocalPlayer
    local pairs_ = {} -- { a, b, mid, normal } ; normal points from b toward a
    local paired = {} -- prompt -> true (already in a pair)
    local loopRunning = false

    local function horizontal(v)
        return Vector3.new(v.X, 0, v.Z)
    end

    -- Find this prompt's twin: another RealmPortalPrompt within PAIR_RADIUS,
    -- searched among the portal Model's siblings (the Maps.<World> folder).
    local function tryPair(prompt)
        if paired[prompt] then
            return
        end
        local part = prompt.Parent
        local portalModel = part and part:FindFirstAncestorWhichIsA("Model")
        local mapFolder = portalModel and portalModel.Parent
        if not mapFolder then
            return
        end
        for _, sibling in ipairs(mapFolder:GetChildren()) do
            if sibling ~= portalModel and sibling:IsA("Model") then
                for _, d in ipairs(sibling:GetDescendants()) do
                    if d.Name == PROMPT_NAME and d:IsA("ProximityPrompt") and not paired[d] then
                        local otherPart = d.Parent
                        local gap = horizontal(otherPart.Position - part.Position)
                        if gap.Magnitude > 0.05 and gap.Magnitude <= PAIR_RADIUS then
                            paired[prompt] = true
                            paired[d] = true
                            table.insert(pairs_, {
                                a = prompt,
                                b = d,
                                mid = (part.Position + otherPart.Position) / 2,
                                normal = horizontal(part.Position - otherPart.Position).Unit,
                            })
                            return
                        end
                    end
                end
            end
        end
    end

    local function sideLoop()
        if loopRunning then
            return
        end
        loopRunning = true
        task.spawn(function()
            local idle = 0
            while idle < 40 do -- park the loop after ~10s with no pair in range
                task.wait(0.25)
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local anyNear = false
                for i = #pairs_, 1, -1 do
                    local p = pairs_[i]
                    if p.a.Parent == nil or p.b.Parent == nil then
                        -- streamed out / rebuilt: forget the pair, restore state
                        if p.a.Parent then
                            p.a.Enabled = true
                        end
                        if p.b.Parent then
                            p.b.Enabled = true
                        end
                        paired[p.a] = nil
                        paired[p.b] = nil
                        table.remove(pairs_, i)
                    elseif hrp then
                        local offset = horizontal(hrp.Position - p.mid)
                        if offset.Magnitude <= ACTIVE_RADIUS then
                            anyNear = true
                            local side = offset:Dot(p.normal)
                            if side > HYSTERESIS then
                                p.a.Enabled = true
                                p.b.Enabled = false
                            elseif side < -HYSTERESIS then
                                p.a.Enabled = false
                                p.b.Enabled = true
                            end
                        else
                            -- out of range: restore both (server default)
                            p.a.Enabled = true
                            p.b.Enabled = true
                        end
                    end
                end
                idle = anyNear and 0 or idle + 1
            end
            loopRunning = false
        end)
    end

    ProximityPromptService.PromptShown:Connect(function(prompt)
        if prompt.Name ~= PROMPT_NAME then
            return
        end
        tryPair(prompt)
        sideLoop()
    end)
end

return RealmPortalSideGate
