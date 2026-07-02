--[[
    VulnMark — ADDITIVE enemy-vulnerability marks (the glass cannon fix).

    THE PROBLEM (Jason's balance audit): every vulnerability power wrote ONE VulnerableMult
    attribute, last-write-wins. The pyromancer — whose entire damage identity is layering
    vulnerability marks (the firewall design: players never deal direct damage, they make the
    PETS hit harder) — was punished for casting its own kit: strike after eruption DOWNGRADED
    the mark x2.0 -> x1.5. Six "stacking" powers collapsed to whatever was cast last.

    THE FIX (Jason: "it should 100% be additive for a glass cannon"): per-SOURCE channels that
    ADD, each with its own expiry — the same additive model as every BuffStack axis. NO cap
    (Jason: no hidden caps — a well-balanced game bounds itself): the stack is bounded naturally
    by focus economy, cooldowns and durations, not a clamp.

    Attribute schema on the enemy/crystal model:
      VulnMark_<key>        = the mark's FRACTION (x2.0 mark -> 0.5... no: mult-1, so 1.0)
      VulnMark_<key>_Until  = absolute expiry (os.time)
      VulnerableUntil       = shared MAX-expiry channel, kept for the client aura/badge
                              (CombatAuraController reacts to it; it never reads the mult)

    Consumers total the LIVE fractions: multiplier = 1 + Σ live fractions. Keys are power ids
    (eruption, strike, wildfire, ...) plus fixed channels: "shred" (Amplifier on-hit + hell shred
    aura — keep-stronger WITHIN the channel so shreds never compound, but they ADD with power
    marks) and "pit" (Cataclysm's molten pool).

    Pure math over a GetAttributes() map (headless-tested); apply() is the one thin
    instance-writing helper so every writer shares a single code path.
]]

local VulnMark = {}

local PREFIX = "VulnMark_"
local UNTIL_SUFFIX = "_Until"

function VulnMark.attr(key)
    return PREFIX .. tostring(key)
end

function VulnMark.untilAttr(key)
    return PREFIX .. tostring(key) .. UNTIL_SUFFIX
end

-- One channel's live fraction: its stored fraction while unexpired, else 0. Negative marks are
-- floored (a vulnerability can't protect the enemy).
function VulnMark.liveFraction(fraction, untilTime, now)
    if (tonumber(untilTime) or 0) > (tonumber(now) or 0) then
        return math.max(0, tonumber(fraction) or 0)
    end
    return 0
end

-- Σ live fractions across every VulnMark_<key> channel in a GetAttributes() map. Pure.
function VulnMark.fraction(attrs, now)
    if type(attrs) ~= "table" then
        return 0
    end
    local total = 0
    for name, value in pairs(attrs) do
        if
            type(name) == "string"
            and string.sub(name, 1, #PREFIX) == PREFIX
            and string.sub(name, -#UNTIL_SUFFIX) ~= UNTIL_SUFFIX
        then
            total += VulnMark.liveFraction(value, attrs[name .. UNTIL_SUFFIX], now)
        end
    end
    return total
end

-- The damage multiplier pets apply against this target: 1 + the additive stack. UNCAPPED.
function VulnMark.multiplier(attrs, now)
    return 1 + VulnMark.fraction(attrs, now)
end

-- Stamp one mark channel on a model (impure — the ONE shared write path). `mult` is the
-- familiar x-multiplier from configs (x2.0); stored as its fraction (1.0). Also lifts the shared
-- VulnerableUntil (max-expiry) so the client vulnerability aura/badge covers the whole stack.
function VulnMark.apply(model, key, mult, untilTime)
    local frac = math.max(0, (tonumber(mult) or 1) - 1)
    model:SetAttribute(VulnMark.attr(key), frac)
    model:SetAttribute(VulnMark.untilAttr(key), untilTime)
    if (tonumber(untilTime) or 0) > (tonumber(model:GetAttribute("VulnerableUntil")) or 0) then
        model:SetAttribute("VulnerableUntil", untilTime)
    end
end

return VulnMark
