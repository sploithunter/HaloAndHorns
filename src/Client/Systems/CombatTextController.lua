--[[
    CombatTextController — the sole floating-combat-text presenter.

    Combat_Result is published only after ApplyHit / ApplyDamage / ApplyPowerHeal resolves the
    authoritative server transition. Keeping this listener independent from pet movement means
    combat feedback still starts if a movement controller is disabled or fails during startup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FloatingText = require(ReplicatedStorage.Shared.Effects.FloatingText)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local CombatTextController = {}
local started = false

local function rgb(value, red, green, blue)
    if type(value) == "table" and value[1] then
        return Color3.fromRGB(value[1], value[2] or 0, value[3] or 0)
    end
    return Color3.fromRGB(red, green, blue)
end

local function targetPosition(target, fallback)
    if typeof(target) ~= "Instance" or not target.Parent then
        return fallback, 4
    end

    local position = fallback
    local up = 4
    if target:IsA("Model") then
        position = target.PrimaryPart and target.PrimaryPart.Position or target:GetPivot().Position
        local ok, extents = pcall(function()
            return target:GetExtentsSize()
        end)
        if ok then
            up = extents.Y * 0.5 + 1
        end
    elseif target:IsA("BasePart") then
        position = target.Position
    end
    return position, up
end

function CombatTextController.start()
    if started then
        return
    end
    started = true

    local config = require(ReplicatedStorage.Configs:WaitForChild("pet_follow"))
    local combatText = (config.ranged_bolt and config.ranged_bolt.combat_text)
        or config.combat_text
        or {}

    Signals.Combat_Result.OnClientEvent:Connect(function(data)
        if combatText.enabled == false or type(data) ~= "table" then
            return
        end

        local position, up = targetPosition(data.target, data.position)
        if typeof(position) ~= "Vector3" then
            return
        end

        local outcome = tostring(data.outcome or "")
        local colors = combatText.colors or {}
        local amount = tonumber(data.amount) or 0
        local rounded = math.floor(amount + 0.5)
        local amountText = math.abs(amount - rounded) < 0.05 and tostring(rounded)
            or string.format("%.1f", amount)
        local text
        local color
        local size = combatText.size or 22
        local rise = combatText.rise
        local duration = combatText.duration

        if outcome == "damage" then
            local crit = data.crit == true
            text = amountText .. (crit and "!" or "")
            color = rgb(
                crit and colors.crit or colors.normal,
                255,
                crit and 200 or 255,
                crit and 60 or 255
            )
            if crit then
                size = combatText.crit_size or 32
                rise = (combatText.rise or 6) + 2
                duration = (combatText.duration or 0.9) + 0.2
            end
        elseif outcome == "heal" then
            text = "+" .. amountText
            color = rgb(colors.heal, 90, 230, 110)
        elseif outcome == "miss" then
            text = combatText.miss_text or "MISS"
            color = data.blind == true and rgb(colors.blind_miss, 255, 150, 40)
                or rgb(colors.miss, 175, 175, 175)
        elseif outcome == "dodge" then
            text = "DODGE"
            color = rgb(colors.dodge, 255, 221, 64)
        elseif outcome == "blocked" then
            text = "BLOCK"
            color = rgb(colors.blocked, 130, 190, 255)
        elseif outcome == "absorbed" then
            text = "ABSORB"
            color = rgb(colors.absorbed, 130, 210, 255)
        elseif outcome == "immune" then
            text = "IMMUNE"
            color = rgb(colors.immune, 190, 160, 255)
        else
            return
        end

        FloatingText.show(position + Vector3.new(0, up, 0), text, {
            color = color,
            size = size,
            rise = rise,
            duration = duration,
        })
    end)
end

return CombatTextController
