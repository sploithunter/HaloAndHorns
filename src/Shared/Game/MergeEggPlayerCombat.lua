-- Pure policy for the Merge Egg player's Simple / Full combat modes.
--
-- Full mode uses the player's durable inventory squad and real hatches. Simple mode keeps the
-- prototype's temporary cast-off roster. The server remains authoritative for eligibility and for
-- resolving which authored egg a real defense hatch may use.

local MergeEggPlayerCombat = {}

local MergeEggCheckpoint = require(script.Parent.MergeEggCheckpoint)
local MergeBulwarkProgression = require(script.Parent.MergeBulwarkProgression)

local VALID_MODES = {
    simple = true,
    full = true,
}

function MergeEggPlayerCombat.normalizeMode(value, fallback)
    local mode = type(value) == "string" and string.lower(value) or nil
    if VALID_MODES[mode] then
        return mode
    end
    local defaultMode = type(fallback) == "string" and string.lower(fallback) or "full"
    return VALID_MODES[defaultMode] and defaultMode or "full"
end

function MergeEggPlayerCombat.isFullEligible(level, combatTutorialDone, minimumLevel)
    local required = math.max(1, math.floor(tonumber(minimumLevel) or 10))
    return combatTutorialDone == true or math.max(0, math.floor(tonumber(level) or 0)) >= required
end

function MergeEggPlayerCombat.resolveMode(preference, eligible, fallback, holdForChoice)
    local requested = MergeEggPlayerCombat.normalizeMode(preference, fallback)
    if requested == "full" and (eligible ~= true or holdForChoice == true) then
        return "simple"
    end
    return requested
end

function MergeEggPlayerCombat.normalizeOnboarding(raw)
    raw = type(raw) == "table" and raw or {}
    local managementUpgrades = {}
    for upgradeId, level in
        pairs(type(raw.management_upgrades) == "table" and raw.management_upgrades or {})
    do
        if type(upgradeId) == "string" and tonumber(level) then
            managementUpgrades[upgradeId] = math.max(0, math.floor(tonumber(level) or 0))
        end
    end
    local bulwark = MergeBulwarkProgression.normalize({
        family = raw.bulwark_family,
        tier = raw.bulwark_tier,
    })
    return {
        version = 5,
        visited = raw.visited == true,
        played_locked_simple = raw.played_locked_simple == true,
        full_intro_pending = raw.full_intro_pending == true,
        full_intro_acknowledged = raw.full_intro_acknowledged == true,
        unlock_choice_resolved = raw.unlock_choice_resolved == true,
        -- Merge-only prestige belongs beside onboarding so settings normalization cannot erase it.
        rebirths = math.max(0, math.floor(tonumber(raw.rebirths) or 0)),
        management_upgrades = managementUpgrades,
        management_gems_spent = math.max(0, math.floor(tonumber(raw.management_gems_spent) or 0)),
        bulwark_family = bulwark.family,
        bulwark_tier = bulwark.tier,
        tutorial_completed = raw.tutorial_completed == true,
        checkpoint = MergeEggCheckpoint.normalize(raw.checkpoint),
    }
end

function MergeEggPlayerCombat.isUnlockChoicePending(raw, eligible)
    local state = MergeEggPlayerCombat.normalizeOnboarding(raw)
    return eligible == true
        and state.played_locked_simple == true
        and state.unlock_choice_resolved ~= true
end

function MergeEggPlayerCombat.noticeFor(raw, eligible)
    local state = MergeEggPlayerCombat.normalizeOnboarding(raw)
    if MergeEggPlayerCombat.isUnlockChoicePending(state, eligible) then
        return "full_unlock_choice"
    end
    if
        eligible == true
        and state.full_intro_pending == true
        and state.full_intro_acknowledged ~= true
    then
        return "full_intro"
    end
    return nil
end

-- First-entry state is durable so an interrupted notice can be shown again without making every
-- visit noisy. Ineligible entrants silently establish the later unlock-choice requirement.
function MergeEggPlayerCombat.recordEntry(raw, eligible)
    local state = MergeEggPlayerCombat.normalizeOnboarding(raw)
    if not state.visited then
        state.visited = true
        if eligible == true then
            state.full_intro_pending = true
        else
            state.played_locked_simple = true
        end
    elseif eligible ~= true then
        state.played_locked_simple = true
    end
    return state, MergeEggPlayerCombat.noticeFor(state, eligible)
end

function MergeEggPlayerCombat.applyNoticeResponse(raw, action)
    local state = MergeEggPlayerCombat.normalizeOnboarding(raw)
    if action == "acknowledge_full_intro" and state.full_intro_pending then
        state.full_intro_acknowledged = true
        return state, nil, true
    end
    if
        (action == "stay_simple" or action == "switch_full")
        and state.played_locked_simple
        and not state.unlock_choice_resolved
    then
        state.unlock_choice_resolved = true
        return state, action == "switch_full" and "full" or "simple", true
    end
    return state, nil, false
end

local function unlockedSet(unlockedAreas)
    local set = {}
    if type(unlockedAreas) ~= "table" then
        return set
    end
    for key, value in pairs(unlockedAreas) do
        if type(key) == "number" and type(value) == "string" then
            set[value] = true
        elseif type(key) == "string" and value == true then
            set[key] = true
        end
    end
    return set
end

-- Progression order is the cap order. An egg without an authored unlock requirement is available;
-- this deliberately makes the Earth/Grass starting egg work for fresh profiles.
function MergeEggPlayerCombat.highestUnlockedTier(progression, unlockedAreas, unlockAreaByEgg)
    progression = type(progression) == "table" and progression or {}
    unlockAreaByEgg = type(unlockAreaByEgg) == "table" and unlockAreaByEgg or {}
    local areas = unlockedSet(unlockedAreas)
    local highest = 0
    for tier, eggId in ipairs(progression) do
        local requiredArea = unlockAreaByEgg[tostring(eggId)]
        if requiredArea == nil or requiredArea == "" or areas[tostring(requiredArea)] == true then
            highest = tier
        end
    end
    return highest
end

function MergeEggPlayerCombat.resolveHatchTier(
    progression,
    unlockedAreas,
    unlockAreaByEgg,
    deployedTier
)
    progression = type(progression) == "table" and progression or {}
    local highest =
        MergeEggPlayerCombat.highestUnlockedTier(progression, unlockedAreas, unlockAreaByEgg)
    local deployed =
        math.clamp(math.floor(tonumber(deployedTier) or 1), 1, math.max(1, #progression))
    local tier = math.min(math.max(1, highest), deployed)
    return tier, progression[tier]
end

return MergeEggPlayerCombat
