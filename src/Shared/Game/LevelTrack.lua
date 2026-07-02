--[[
    LevelTrack — pure level-up claim math + per-level reward lookup (no Roblox APIs).

    Total XP -> earnedLevel (LevelCurve). The player CLAIMS one level at a time, capped at
    earnedLevel and at the track's max_level. This module answers "can I claim, how many are
    pending, what does the next level give" so the service (ClaimLevel) and the headless specs
    share one source of truth — mirroring LevelCurve / PowerSelection.

      LevelTrack.resolve(claimedLevel, earnedLevel, cfg)
        -> { canClaim, pendingLevels, nextLevel, atMax, maxLevel }
      LevelTrack.entryForLevel(level, cfg)
        -> { level, kind, eggHatchBonus, eggHatchTotal, powerPick, slots, milestone, rewards }

    cfg = configs/level_track.lua
]]

local LevelTrack = {}

local function toInt(n, default)
    return math.floor(tonumber(n) or default)
end

-- True if `level` appears in cfg[key] (a list of levels). Built fresh — entryForLevel is
-- called per-claim (rare), never per-frame, and we must not mutate the (possibly frozen) cfg.
local function hasLevel(cfg, key, level)
    local list = cfg[key]
    if type(list) ~= "table" then
        return false
    end
    for _, v in ipairs(list) do
        if toInt(v, 0) == level then
            return true
        end
    end
    return false
end

function LevelTrack.maxLevel(cfg)
    return math.max(1, toInt(cfg and cfg.max_level, 50))
end

-- Egg max-hatch total a player at `level` should have: base + (level - 1) * per_level.
function LevelTrack.eggHatchForLevel(level, cfg)
    local egg = (type(cfg) == "table" and cfg.egg_hatch) or {}
    local base = toInt(egg.base, 3)
    local per = toInt(egg.per_level, 1)
    level = math.max(1, toInt(level, 1))
    return base + (level - 1) * per
end

function LevelTrack.entryForLevel(level, cfg)
    cfg = type(cfg) == "table" and cfg or {}
    level = math.max(1, toInt(level, 1))

    local isPower = hasLevel(cfg, "power_levels", level)
    local isSlot = hasLevel(cfg, "slot_levels", level)
    local isMilestone = hasLevel(cfg, "milestones", level)
    local slots = isSlot and math.max(0, toInt(cfg.slots_per_grant, 1)) or 0

    -- Headline kind: power > milestone > slot > reward.
    local kind = "reward"
    if isPower then
        kind = "power"
    elseif isMilestone then
        kind = "milestone"
    elseif isSlot then
        kind = "slot"
    end

    local rewardsTable = (type(cfg.rewards) == "table" and cfg.rewards) or {}
    local milestoneRewards = (type(cfg.milestone_rewards) == "table" and cfg.milestone_rewards)
        or {}

    -- Hybrid gate: a level that demands a CHOICE/ceremony must be claimed at the Ascension
    -- Altar; pure-reward "filler" levels auto-claim in the field. `altar_kinds` is the dev knob
    -- (default: power + slot + milestone require the altar; reward does not). Set all false to
    -- make everything auto-claim (revert to the old claim-anywhere behaviour).
    local altarKinds = (type(cfg.altar_kinds) == "table" and cfg.altar_kinds) or {}
    local function gated(k, default)
        local v = altarKinds[k]
        if v == nil then
            return default
        end
        return v == true
    end
    local requiresAltar = (isPower and gated("power", true))
        or (isMilestone and gated("milestone", true))
        or (slots > 0 and gated("slot", true))
        or (kind == "reward" and gated("reward", false))

    return {
        level = level,
        kind = kind,
        eggHatchBonus = toInt((cfg.egg_hatch or {}).per_level, 1),
        eggHatchTotal = LevelTrack.eggHatchForLevel(level, cfg),
        powerPick = isPower,
        slots = slots,
        milestone = isMilestone,
        requiresAltar = requiresAltar,
        -- The per-level reward bundle (override -> default) and the milestone bundle (if any).
        rewards = rewardsTable[level] or rewardsTable.default,
        milestoneRewards = isMilestone and milestoneRewards[level] or nil,
    }
end

function LevelTrack.resolve(claimedLevel, earnedLevel, cfg)
    local maxLevel = LevelTrack.maxLevel(cfg)
    local claimed = math.clamp(toInt(claimedLevel, 1), 1, maxLevel)
    local earned = math.clamp(toInt(earnedLevel, 1), 1, maxLevel)
    local pending = math.max(0, earned - claimed)
    local canClaim = pending > 0 and claimed < maxLevel
    return {
        canClaim = canClaim,
        pendingLevels = pending,
        nextLevel = canClaim and (claimed + 1) or nil,
        atMax = claimed >= maxLevel,
        maxLevel = maxLevel,
    }
end

return LevelTrack
