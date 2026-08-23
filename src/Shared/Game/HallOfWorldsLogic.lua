local HallOfWorldsLogic = {}

local function unlockedSet(unlockedAreas)
    local unlocked = {}
    for key, value in pairs(type(unlockedAreas) == "table" and unlockedAreas or {}) do
        if type(key) == "number" then
            unlocked[tostring(value)] = true
        elseif value == true then
            unlocked[tostring(key)] = true
        end
    end
    return unlocked
end

-- Release rollback seam: Hall remains authored but is not a legal resume destination. Normalize
-- only the world-resume fields; inventories, pets, powers, rewards, and Hall progress are left
-- untouched so the route can be repaired/re-enabled without a player-data rollback.
function HallOfWorldsLogic.forceHomeResume(gameData, hallAreaIds, homeAreaId)
    gameData = type(gameData) == "table" and gameData or {}
    local home = tostring(homeAreaId or "Spawn")
    local unlocked = unlockedSet(gameData.UnlockedAreas)
    local changed = gameData.LastArea ~= home or unlocked[home] ~= true

    for areaId in pairs(type(hallAreaIds) == "table" and hallAreaIds or {}) do
        if unlocked[areaId] == true then
            unlocked[areaId] = nil
            changed = true
        end
    end
    unlocked[home] = true

    local values = {}
    for areaId in pairs(unlocked) do
        table.insert(values, areaId)
    end
    table.sort(values)
    gameData.UnlockedAreas = values
    gameData.LastArea = home
    return gameData, changed
end

-- Last world for join/respawn. Hall tiles resume in place. Crystal World biomes,
-- Heaven/Hell layers, and trial/mission_* ids all collapse to Crystal World Spawn.
-- Never persist ZoneTracker CurrentArea — that is the player-list location and
-- becomes mission_* inside a trial.
function HallOfWorldsLogic.normalizeResumeArea(areaId, hallAreaIds, crystalAreaId)
    if type(areaId) ~= "string" or areaId == "" then
        return nil
    end
    if hallAreaIds and hallAreaIds[areaId] == true then
        return areaId
    end
    return tostring(crystalAreaId or "Spawn")
end

function HallOfWorldsLogic.resolvedResumeArea(
    lastArea,
    enteredCrystalWorld,
    unlockedAreas,
    hallAreaIds,
    crystalAreaId,
    tutorial,
    gameData
)
    local resume = HallOfWorldsLogic.normalizeResumeArea(lastArea, hallAreaIds, crystalAreaId)
    if not resume then
        return nil
    end
    local unlocked = unlockedSet(unlockedAreas)
    if unlocked[resume] ~= true then
        return nil
    end
    -- Post-update Hall players who have not finished the tutorial stay on Hall tiles.
    if
        HallOfWorldsLogic.hasHallTutorialTrack(tutorial)
        and not HallOfWorldsLogic.isTutorialCompleted(gameData, tutorial)
        and not (hallAreaIds and hallAreaIds[resume] == true)
    then
        return nil
    end
    if hallAreaIds and hallAreaIds[resume] == true then
        return resume
    end
    if resume == tostring(crystalAreaId or "Spawn") and enteredCrystalWorld == true then
        return resume
    end
    return nil
end

function HallOfWorldsLogic.initialArea(
    enteredCrystalWorld,
    unlockedAreas,
    routeAreaIds,
    hallAreaId,
    crystalAreaId,
    lastArea,
    hallAreaIds,
    tutorial,
    gameData
)
    local resume = HallOfWorldsLogic.resolvedResumeArea(
        lastArea,
        enteredCrystalWorld,
        unlockedAreas,
        hallAreaIds,
        crystalAreaId,
        tutorial,
        gameData
    )
    if resume then
        return resume
    end

    if enteredCrystalWorld == true then
        return tostring(crystalAreaId or "Spawn")
    end

    local unlocked = unlockedSet(unlockedAreas)
    for index = #(routeAreaIds or {}), 1, -1 do
        local areaId = tostring(routeAreaIds[index])
        if unlocked[areaId] then
            return areaId
        end
    end
    return tostring(hallAreaId or "Hall_1")
end

-- Locked-area eject: the previous unlocked Hall tile, never a stale LastArea
-- (that is often still Hall_1 after walking the route).
function HallOfWorldsLogic.lockedEntryReturn(unlockedAreas, routeAreaIds, enteredAreaId, hallStart)
    local unlocked = unlockedSet(unlockedAreas)
    local entered = tostring(enteredAreaId or "")
    local route = type(routeAreaIds) == "table" and routeAreaIds or {}
    local enteredIndex
    for index, areaId in ipairs(route) do
        if tostring(areaId) == entered then
            enteredIndex = index
            break
        end
    end
    if enteredIndex then
        for index = enteredIndex - 1, 1, -1 do
            local areaId = tostring(route[index])
            if unlocked[areaId] then
                return areaId
            end
        end
    end
    for index = #route, 1, -1 do
        local areaId = tostring(route[index])
        if unlocked[areaId] then
            return areaId
        end
    end
    return tostring(hallStart or "Hall_1")
end

-- Session-only Crystal World visit for an unfinished-Hall teammate. Never stamps
-- entered_crystal_world and never persists LastArea as Spawn.
function HallOfWorldsLogic.sessionRespawnArea(
    enteredCrystalWorld,
    unlockedAreas,
    routeAreaIds,
    hallAreaId,
    crystalAreaId,
    lastArea,
    hallAreaIds,
    isGuestVisit,
    tutorial,
    gameData
)
    if enteredCrystalWorld ~= true and isGuestVisit == true then
        return tostring(crystalAreaId or "Spawn")
    end
    return HallOfWorldsLogic.initialArea(
        enteredCrystalWorld,
        unlockedAreas,
        routeAreaIds,
        hallAreaId,
        crystalAreaId,
        lastArea,
        hallAreaIds,
        tutorial,
        gameData
    )
end

function HallOfWorldsLogic.formatUnlockAmount(amount)
    local text = tostring(math.floor(tonumber(amount) or 0))
    local replaced
    repeat
        text, replaced = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until replaced == 0
    return text
end

function HallOfWorldsLogic.gateButtonText(unlock)
    unlock = type(unlock) == "table" and unlock or {}
    local cost = tonumber(unlock.cost) or 0
    if cost <= 0 then
        return "Open"
    end
    local name = unlock.currency == "hall_coins" and "Waycoins"
        or tostring(unlock.currency or "coins")
    return string.format("%s %s", HallOfWorldsLogic.formatUnlockAmount(cost), name)
end

function HallOfWorldsLogic.formatUnlockAmount(amount)
    local text = tostring(math.floor(tonumber(amount) or 0))
    local replaced
    repeat
        text, replaced = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until replaced == 0
    return text
end

function HallOfWorldsLogic.gateButtonText(unlock)
    unlock = type(unlock) == "table" and unlock or {}
    local cost = tonumber(unlock.cost) or 0
    if cost <= 0 then
        return "Open"
    end
    local name = unlock.currency == "hall_coins" and "Waycoins"
        or tostring(unlock.currency or "coins")
    return string.format("%s %s", HallOfWorldsLogic.formatUnlockAmount(cost), name)
end

function HallOfWorldsLogic.meetsUnlock(claimedLevel, tutorialCompleted, unlock, tutorial)
    unlock = type(unlock) == "table" and unlock or {}
    if unlock.tutorial_required == true then
        local met = if tutorial ~= nil
            then HallOfWorldsLogic.tutorialRequirementMet(
                { TutorialCompleted = tutorialCompleted == true },
                tutorial,
                unlock
            )
            else tutorialCompleted == true
        if met ~= true then
            return false, "tutorial_required"
        end
    end
    local requiredLevel = math.max(0, math.floor(tonumber(unlock.required_level) or 0))
    if math.floor(tonumber(claimedLevel) or 1) < requiredLevel then
        return false, "level_required"
    end
    return true
end

-- Hall-era new profiles carry Tutorial.track == 2. Legacy saves have no track.
function HallOfWorldsLogic.hasHallTutorialTrack(tutorial, expectedTrack)
    local expected = math.floor(tonumber(expectedTrack) or 2)
    return type(tutorial) == "table" and math.floor(tonumber(tutorial.track) or 0) == expected
end

-- Tutorial.done is the current tutorial SSOT. GameData.TutorialCompleted predates the
-- event-driven tutorial and remains a persisted compatibility field for older consumers.
-- Accept either representation so a completed player can never be stranded at a Hall gate.
function HallOfWorldsLogic.isTutorialCompleted(gameData, tutorial)
    return (type(gameData) == "table" and gameData.TutorialCompleted == true)
        or (type(tutorial) == "table" and tutorial.done == true)
end

-- Hall gates only check completion for post-update (track 2) players. Legacy
-- saves have no track and must not be locked behind the new tutorial.
function HallOfWorldsLogic.tutorialRequirementMet(gameData, tutorial, unlock)
    unlock = type(unlock) == "table" and unlock or {}
    if unlock.tutorial_required ~= true then
        return true
    end
    if not HallOfWorldsLogic.hasHallTutorialTrack(tutorial) then
        return true
    end
    return HallOfWorldsLogic.isTutorialCompleted(gameData, tutorial)
end

function HallOfWorldsLogic.canLeaveHall(enteredCrystalWorld, targetAreaId, hallAreaIds, isHallExit)
    if enteredCrystalWorld == true or isHallExit == true then
        return true
    end
    return hallAreaIds[tostring(targetAreaId or "")] == true
end

function HallOfWorldsLogic.normalizeState(gameData, version)
    gameData = type(gameData) == "table" and gameData or {}
    local state = type(gameData.HallOfWorlds) == "table" and gameData.HallOfWorlds or {}
    state.version = math.max(1, math.floor(tonumber(state.version) or tonumber(version) or 1))
    state.entered_crystal_world = state.entered_crystal_world == true
    state.highest_stage = math.max(0, math.floor(tonumber(state.highest_stage) or 0))
    state.completed = state.completed == true
    state.rewarded = type(state.rewarded) == "table" and state.rewarded or {}
    state.checkpoint = type(state.checkpoint) == "string" and state.checkpoint or ""
    gameData.HallOfWorlds = state
    return state
end

function HallOfWorldsLogic.canEnter(claimedLevel, minimumLevel)
    return math.floor(tonumber(claimedLevel) or 1) >= math.floor(tonumber(minimumLevel) or 2)
end

function HallOfWorldsLogic.nextStage(state, stageCount)
    state = type(state) == "table" and state or {}
    local nextIndex = math.max(1, math.floor(tonumber(state.highest_stage) or 0) + 1)
    if nextIndex > math.max(0, math.floor(tonumber(stageCount) or 0)) then
        return nil
    end
    return nextIndex
end

function HallOfWorldsLogic.isHallAreaId(areaId)
    if type(areaId) ~= "string" or areaId == "" then
        return false
    end
    return string.lower(areaId):sub(1, 5) == "hall_"
end

-- Hall route tiles and Hall-hosted gauntlets (Range / Training Ground).
-- Those runs publish mission_* for farming/music; the currency HUD stays
-- Gems + Waycoins so origin crystals never replace Waycoins in the Hall.
function HallOfWorldsLogic.usesHallCurrencyHud(areaId, gauntletMode, challengeModes)
    if type(gauntletMode) == "string" then
        local modeCfg = type(challengeModes) == "table" and challengeModes[gauntletMode]
        if type(modeCfg) == "table" and modeCfg.hall_currency_hud == true then
            return true
        end
    end
    return HallOfWorldsLogic.isHallAreaId(areaId)
end

function HallOfWorldsLogic.canStartStage(state, stageIndex, claimedLevel, targetLevel)
    local expected = HallOfWorldsLogic.nextStage(state, math.huge)
    if stageIndex ~= expected then
        return false, stageIndex < expected and "already_complete" or "previous_stage_required"
    end
    local prerequisite = math.max(2, math.floor(tonumber(targetLevel) or 3) - 1)
    if math.floor(tonumber(claimedLevel) or 1) < prerequisite then
        return false, "claim_previous_level"
    end
    return true
end

function HallOfWorldsLogic.markCompleted(state, stageIndex, stageId, checkpoint, stageCount)
    state.rewarded = type(state.rewarded) == "table" and state.rewarded or {}
    local firstCompletion = state.rewarded[stageId] ~= true
    state.rewarded[stageId] = true
    state.highest_stage = math.max(
        math.floor(tonumber(state.highest_stage) or 0),
        math.floor(tonumber(stageIndex) or 0)
    )
    state.checkpoint = tostring(checkpoint or "")
    state.completed = state.highest_stage >= math.floor(tonumber(stageCount) or math.huge)
    return firstCompletion
end

return HallOfWorldsLogic
