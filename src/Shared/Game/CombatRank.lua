--[[
    CombatRank — current combat-training title (pure).

    Ladder and grant steps live in configs/combat_ranks.lua. Persist
    GameData.CombatRank = { current, earned }. First earn is a ceremony;
    already-earned ids stay silent. Veterans who finished the cave are
    backfilled to Skilled without a replay.
]]

local CombatRank = {}

function CombatRank.empty()
    return {
        current = nil,
        earned = {},
    }
end

function CombatRank.normalize(state)
    if type(state) ~= "table" then
        return CombatRank.empty()
    end
    local earned = {}
    if type(state.earned) == "table" then
        for id, flag in pairs(state.earned) do
            if type(id) == "string" and id ~= "" and flag == true then
                earned[id] = true
            end
        end
    end
    local current = type(state.current) == "string" and state.current or nil
    if current and not earned[current] then
        earned[current] = true
    end
    if current == "" then
        current = nil
    end
    return {
        current = current,
        earned = earned,
    }
end

function CombatRank.ranks(config)
    local list = config and config.ranks
    return type(list) == "table" and list or {}
end

function CombatRank.rankById(config, id)
    if type(id) ~= "string" or id == "" then
        return nil
    end
    for _, rank in ipairs(CombatRank.ranks(config)) do
        if rank.id == id then
            return rank
        end
    end
    return nil
end

function CombatRank.iconAsset(rank)
    local icon = rank and rank.icon
    if type(icon) == "string" and icon ~= "" then
        return icon
    end
    return nil
end

function CombatRank.rankForStep(config, stepId)
    if type(stepId) ~= "string" or stepId == "" then
        return nil
    end
    for _, rank in ipairs(CombatRank.ranks(config)) do
        if rank.grant_step == stepId then
            return rank
        end
    end
    return nil
end

function CombatRank.grant(state, config, rankId)
    state = CombatRank.normalize(state)
    if not CombatRank.rankById(config, rankId) then
        return state, false
    end
    if state.earned[rankId] == true then
        return state, false
    end
    local earned = table.clone(state.earned)
    earned[rankId] = true
    return {
        current = rankId,
        earned = earned,
    }, true
end

function CombatRank.completedStepIds(tutorialConfig, progress)
    local ids = {}
    local steps = tutorialConfig and tutorialConfig.steps
    if type(steps) ~= "table" then
        return ids
    end
    if type(progress) == "table" and progress.done == true then
        for _, step in ipairs(steps) do
            if type(step.id) == "string" then
                ids[step.id] = true
            end
        end
        return ids
    end
    local index = math.floor(tonumber(progress and progress.step) or 1)
    for i = 1, index - 1 do
        local step = steps[i]
        if step and type(step.id) == "string" then
            ids[step.id] = true
        end
    end
    return ids
end

function CombatRank.syncFromTutorial(state, ranksConfig, tutorialConfig, progress)
    state = CombatRank.normalize(state)
    local completed = CombatRank.completedStepIds(tutorialConfig, progress)
    local changed = false
    for _, rank in ipairs(CombatRank.ranks(ranksConfig)) do
        if completed[rank.grant_step] == true then
            local nextState, isNew = CombatRank.grant(state, ranksConfig, rank.id)
            if isNew then
                state = nextState
                changed = true
            end
        end
    end
    return state, changed
end

return CombatRank
