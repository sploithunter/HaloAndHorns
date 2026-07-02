--[[
    LevelCurve — pure XP <-> level math (Phase 9). No Roblox APIs.

    Total XP is the single source of truth; the player's level is derived from it.
    The curve is config-driven (configs/player_progression.lua `xp`):
      mode = "linear" -> step (n -> n+1) costs per_level * n
      mode = "flat"   -> step costs per_level, always

      stepCost(n, cfg)        -> XP to advance FROM level n TO n+1
      xpForLevel(level, cfg)  -> total XP required to REACH `level` (invertible w/ levelForXp)
      levelForXp(totalXp,cfg) -> level for a given total XP (>= 1)
      progress(totalXp, cfg)  -> { level, totalXp, xpIntoLevel, xpForNext, fraction }
]]

local LevelCurve = {}

local DEFAULT_PER_LEVEL = 100
local SAFETY_CAP = 100000

local function stepCost(n, cfg)
    cfg = cfg or {}
    local per = cfg.per_level or DEFAULT_PER_LEVEL
    if cfg.mode == "flat" then
        return per
    end
    return per * n -- "linear" default
end

LevelCurve.stepCost = stepCost

-- Total XP required to reach `level` (level 1 needs 0).
function LevelCurve.xpForLevel(level, cfg)
    level = math.max(1, math.floor(tonumber(level) or 1))
    local total = 0
    for n = 1, level - 1 do
        total += stepCost(n, cfg)
    end
    return total
end

function LevelCurve.levelForXp(totalXp, cfg)
    totalXp = math.max(0, math.floor(tonumber(totalXp) or 0))
    local cap = (cfg and cfg.max_level and cfg.max_level > 0) and cfg.max_level or SAFETY_CAP
    local level = 1
    local cumulative = 0
    while level < cap do
        local need = cumulative + stepCost(level, cfg)
        if need > totalXp then
            break
        end
        cumulative = need
        level += 1
    end
    return level
end

function LevelCurve.progress(totalXp, cfg)
    totalXp = math.max(0, math.floor(tonumber(totalXp) or 0))
    local level = LevelCurve.levelForXp(totalXp, cfg)
    local base = LevelCurve.xpForLevel(level, cfg)
    local forNext = stepCost(level, cfg)
    local into = totalXp - base
    return {
        level = level,
        totalXp = totalXp,
        xpIntoLevel = into,
        xpForNext = forNext,
        fraction = forNext > 0 and math.min(1, into / forNext) or 1,
    }
end

return LevelCurve
