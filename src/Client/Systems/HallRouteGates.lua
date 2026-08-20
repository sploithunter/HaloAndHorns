--[[
    HallRouteGates

    Hall progression remains server-authoritative in ZoneService. This client presentation only
    lowers an authored translucent wall after its target area appears in UnlockedAreasJson. The
    portal prompt performs the actual unlock/travel transaction, so a client edit cannot bypass
    progression.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local HallRouteGates = {}
local started = false

local function decodeUnlocked(player)
    local result = {}
    local raw = player:GetAttribute("UnlockedAreasJson")
    if type(raw) ~= "string" or raw == "" then
        return result
    end
    local ok, values = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok or type(values) ~= "table" then
        return result
    end
    for _, areaId in ipairs(values) do
        result[tostring(areaId)] = true
    end
    return result
end

local function setGateOpen(gate, open)
    if not gate:IsA("BasePart") then
        return
    end
    gate.LocalTransparencyModifier = open and 1 or 0
    gate.CanCollide = not open
    gate.CanTouch = not open

    local label = gate:FindFirstChild("HallGateLabel")
    if label and label:IsA("SurfaceGui") then
        label.Enabled = not open
    end

    local prompt = gate:FindFirstChild("ZoneTravelPrompt", true)
    if prompt and prompt:IsA("ProximityPrompt") then
        prompt.Enabled = not open
    end
end

function HallRouteGates.start()
    if started then
        return
    end
    started = true

    local player = Players.LocalPlayer

    local function refresh()
        local unlocked = decodeUnlocked(player)
        for _, gate in ipairs(CollectionService:GetTagged("HallGate")) do
            local target = gate:GetAttribute("TargetAreaId") or gate:GetAttribute("TargetZoneId")
            setGateOpen(gate, unlocked[tostring(target or "")] == true)
        end
    end

    player:GetAttributeChangedSignal("UnlockedAreasJson"):Connect(refresh)
    CollectionService:GetInstanceAddedSignal("HallGate"):Connect(function()
        task.defer(refresh)
    end)
    task.defer(refresh)
end

return HallRouteGates
