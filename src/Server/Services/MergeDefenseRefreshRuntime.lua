local Draft = require(game:GetService("ReplicatedStorage").Shared.Game.MergeEggDraft)
local Runtime = {}

function Runtime.schedule(service, team)
    local cfg = service._config.reinforcement.stronger_refresh
    if cfg and cfg.enabled then
        -- A fixed budget per paid egg upgrade, not an endless free reroll while healers stall.
        team.strongerRefreshRemaining = team.expectedPets * cfg.attempts_per_slot
        team.nextStrongerRefreshAt = os.clock() + service._config.reinforcement.hatch_seconds
    end
end

function Runtime.step(service, record, team, now)
    local cfg = service._config.reinforcement.stronger_refresh
    if
        not cfg
        or not cfg.enabled
        or (team.strongerRefreshRemaining or 0) <= 0
        or now < (team.nextStrongerRefreshAt or math.huge)
        or #(team.replacementQueue or {}) > 0
        or not service:_isRecordActive(record)
    then
        return
    end
    team.nextStrongerRefreshAt = now + service._config.reinforcement.hatch_seconds
    local roster, models = {}, {}
    for _, pet in ipairs(team.units or {}) do
        local position = pet:FindFirstChild("PositionNumber")
        local slot = position and position.Value
        if pet.Parent == team.folder and not pet:GetAttribute("CombatDowned") and slot then
            roster[slot] = team.config.squad[slot]
            models[slot] = pet
        end
    end
    local candidates = {}
    for _ = 1, service:_draftRollsForEggTier(team.eggTier, team) do
        local candidate = service:_rollPrototypePet(record, team, team.eggTier)
        if candidate then
            table.insert(candidates, candidate)
            service:_recordDraftCandidate(record, team, candidate)
        end
    end
    local candidate, slot = Draft.selectUpgrade(candidates, roster, cfg.minimum_power_ratio)
    team.strongerRefreshRemaining -= 1
    if candidate then
        service:_spawnReplacement(record, team, {
            slot = slot,
            definition = candidate,
            queuedAt = now,
            upgradeFrom = models[slot],
            upgradeDefinition = roster[slot],
            upgradeTier = team.eggTier,
        }, now)
        service:_syncTeamState(record, team)
    end
end

return Runtime
