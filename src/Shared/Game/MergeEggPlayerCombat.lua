-- Pure policy for the Merge Egg player's Simple / Full combat modes.
--
-- Full mode uses the player's durable inventory squad and real hatches. Simple mode keeps the
-- prototype's temporary cast-off roster. The server remains authoritative for eligibility and for
-- resolving which authored egg a real defense hatch may use.

local MergeEggPlayerCombat = {}

local MergeEggCheckpoint = require(script.Parent.MergeEggCheckpoint)
local MergeEggPlaystate = require(script.Parent.MergeEggPlaystate)
local MergeBulwarkProgression = require(script.Parent.MergeBulwarkProgression)
local MergeTowerProgression = require(script.Parent.MergeTowerProgression)

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
    local persisted = MergeBulwarkProgression.persistFields({
        family = raw.bulwark_family,
        tier = raw.bulwark_tier,
        eggFamily = raw.egg_bulwark_family,
        eggTier = raw.egg_bulwark_tier,
        slots = raw.bulwark_slots,
        owned = raw.bulwark_owned,
    })
    local towers = MergeTowerProgression.persistFields({
        leftFamily = raw.left_tower_family,
        leftTier = raw.left_tower_tier,
        rightFamily = raw.right_tower_family,
        rightTier = raw.right_tower_tier,
        rearLeftFamily = raw.rear_left_tower_family,
        rearLeftTier = raw.rear_left_tower_tier,
        rearRightFamily = raw.rear_right_tower_family,
        rearRightTier = raw.rear_right_tower_tier,
        slots = raw.tower_slots,
        owned = raw.tower_owned,
    })
    local baselineRaw = type(raw.upgrade_tutorial_baseline) == "table"
            and raw.upgrade_tutorial_baseline
        or nil
    local upgradeBaseline = nil
    if
        baselineRaw
        and (
            baselineRaw.eggs_merged ~= nil
            or baselineRaw.eggs_placed ~= nil
            or baselineRaw.base_egg_tier ~= nil
        )
    then
        upgradeBaseline = {
            eggs_merged = math.max(0, math.floor(tonumber(baselineRaw.eggs_merged) or 0)),
            eggs_placed = math.max(0, math.floor(tonumber(baselineRaw.eggs_placed) or 0)),
            base_egg_tier = math.max(1, math.floor(tonumber(baselineRaw.base_egg_tier) or 1)),
        }
    end
    return {
        version = 7,
        visited = raw.visited == true,
        played_locked_simple = raw.played_locked_simple == true,
        full_intro_pending = raw.full_intro_pending == true,
        full_intro_acknowledged = raw.full_intro_acknowledged == true,
        unlock_choice_resolved = raw.unlock_choice_resolved == true,
        -- Merge-only prestige belongs beside onboarding so settings normalization cannot erase it.
        rebirths = math.max(0, math.floor(tonumber(raw.rebirths) or 0)),
        management_upgrades = managementUpgrades,
        management_gems_spent = math.max(0, math.floor(tonumber(raw.management_gems_spent) or 0)),
        bulwark_family = persisted.bulwark_family,
        bulwark_tier = persisted.bulwark_tier,
        egg_bulwark_family = persisted.egg_bulwark_family,
        egg_bulwark_tier = persisted.egg_bulwark_tier,
        mid_bulwark_family = persisted.mid_bulwark_family,
        mid_bulwark_tier = persisted.mid_bulwark_tier,
        front_bulwark_family = persisted.front_bulwark_family,
        front_bulwark_tier = persisted.front_bulwark_tier,
        bulwark_slots = persisted.bulwark_slots,
        bulwark_owned = persisted.bulwark_owned,
        left_tower_family = towers.left_tower_family,
        left_tower_tier = towers.left_tower_tier,
        right_tower_family = towers.right_tower_family,
        right_tower_tier = towers.right_tower_tier,
        rear_left_tower_family = towers.rear_left_tower_family,
        rear_left_tower_tier = towers.rear_left_tower_tier,
        rear_right_tower_family = towers.rear_right_tower_family,
        rear_right_tower_tier = towers.rear_right_tower_tier,
        tower_slots = towers.tower_slots,
        tower_owned = towers.tower_owned,
        tower_waycoins_spent = math.max(0, math.floor(tonumber(raw.tower_waycoins_spent) or 0)),
        bulwark_waycoins_spent = math.max(0, math.floor(tonumber(raw.bulwark_waycoins_spent) or 0)),
        tutorial_completed = raw.tutorial_completed == true,
        tutorial_setup_completed = raw.tutorial_setup_completed == true
            or raw.tutorial_cannon_completed == true
            or raw.tutorial_upgrade_completed == true
            or raw.tutorial_completed == true,
        tutorial_workshop_completed = raw.tutorial_workshop_completed == true
            or raw.tutorial_cannon_completed == true
            or raw.tutorial_upgrade_completed == true
            or raw.tutorial_completed == true,
        tutorial_cannon_completed = raw.tutorial_cannon_completed == true
            or raw.tutorial_upgrade_completed == true
            or raw.tutorial_completed == true,
        tutorial_upgrade_completed = raw.tutorial_upgrade_completed == true
            or raw.tutorial_completed == true,
        upgrade_tutorial_baseline = upgradeBaseline,
        checkpoint = MergeEggCheckpoint.normalize(raw.checkpoint),
        -- Current possessions survive logout independently of the last ten-wave combat boundary.
        -- Unlike a checkpoint, Wave 0 is a valid saved playstate.
        playstate = MergeEggPlaystate.normalize(raw.playstate),
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

-- Personal hatch ownership is derived from Merge prestige only. Rank 1 is paid-rebirth count 0;
-- the default policy therefore owns Grass at count 0, Ice at count 1, Lava at count 2, and so on.
-- Keeping this arithmetic config-owned lets future rebirth prices extend the same ladder without a
-- profile migration.
function MergeEggPlayerCombat.highestPersonalHatchTier(progression, rebirthCount, rules)
    progression = type(progression) == "table" and progression or {}
    rules = type(rules) == "table" and rules or {}
    if #progression == 0 then
        return 0
    end
    local startingTier = math.max(1, math.floor(tonumber(rules.starting_tier) or 1))
    local tiersPerRebirth = math.max(1, math.floor(tonumber(rules.tiers_per_rebirth) or 1))
    local count = math.max(0, math.floor(tonumber(rebirthCount) or 0))
    return math.clamp(startingTier + count * tiersPerRebirth, 1, #progression)
end

function MergeEggPlayerCombat.resolveHatchTier(progression, rebirthCount, deployedTier, rules)
    progression = type(progression) == "table" and progression or {}
    local highest = MergeEggPlayerCombat.highestPersonalHatchTier(progression, rebirthCount, rules)
    local deployed =
        math.clamp(math.floor(tonumber(deployedTier) or 1), 1, math.max(1, #progression))
    local tier = math.min(math.max(1, highest), deployed)
    return tier, progression[tier]
end

-- Area grants are a derived entitlement. Returning the complete ordered set makes reconciliation
-- idempotent for existing profiles and heals any interrupted grant on the next Merge entry.
function MergeEggPlayerCombat.personalHatchAreas(progression, rebirthCount, rules)
    progression = type(progression) == "table" and progression or {}
    rules = type(rules) == "table" and rules or {}
    local areaByEgg = type(rules.unlock_area_by_egg) == "table" and rules.unlock_area_by_egg or {}
    local highest = MergeEggPlayerCombat.highestPersonalHatchTier(progression, rebirthCount, rules)
    local areas = {}
    local seen = {}
    for tier = 1, highest do
        local areaId = areaByEgg[tostring(progression[tier] or "")]
        if type(areaId) == "string" and areaId ~= "" and seen[areaId] ~= true then
            seen[areaId] = true
            areas[#areas + 1] = areaId
        end
    end
    return areas
end

function MergeEggPlayerCombat.canAwardPersonalHatch(combatTutorialDone, rules)
    rules = type(rules) == "table" and rules or {}
    return rules.inventory_requires_combat_tutorial == false or combatTutorialDone == true
end

return MergeEggPlayerCombat
