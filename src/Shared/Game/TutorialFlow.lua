--[[
    TutorialFlow — pure step machine for the event-driven tutorial (configs/tutorial.lua).

    Progress record (persisted in profile.Tutorial): { version, step, count, done, ...ledgers }.
    advance() is the ONLY mutator: feed it every bus event; it returns a NEW progress record
    plus whether anything changed (so the service knows when to save/push). No services, no
    Instances — headless-testable.
]]

local TutorialFlow = {}

local function freshProgress(version)
    return {
        version = math.max(1, math.floor(tonumber(version) or 1)),
        step = 1,
        count = 0,
        done = false,
    }
end

-- Coerce whatever was persisted into a sane record (nil/partial/corrupt -> fresh).
function TutorialFlow.normalizeProgress(progress, version)
    if type(progress) ~= "table" then
        return freshProgress(version)
    end
    local step = math.max(1, math.floor(tonumber(progress.step) or 1))
    local normalized = {
        version = math.max(1, math.floor(tonumber(progress.version) or tonumber(version) or 1)),
        step = step,
        count = math.max(0, math.floor(tonumber(progress.count) or 0)),
        done = progress.done == true,
    }
    -- These ledgers make grants retryable/idempotent. Normalization must not silently discard
    -- them every time a step advances.
    if type(progress.granted) == "table" then
        normalized.granted = progress.granted
    end
    if tonumber(progress.completionLevelTarget) then
        normalized.completionLevelTarget = tonumber(progress.completionLevelTarget)
    end
    if progress.completionLevelGranted == true then
        normalized.completionLevelGranted = true
    end
    -- Hall-era cohort. Absence means a legacy save — never invent this during normalize.
    if tonumber(progress.track) then
        normalized.track = math.max(1, math.floor(tonumber(progress.track)))
    end
    -- v6 grandfather: they already scored the v3 first-enemy beat (old
    -- first_fight kills, brew, or Rally). Cave enter did not exist then.
    if progress.firstEnemy == true or progress.caveStarted == true then
        normalized.firstEnemy = true
    end
    return normalized
end

function TutorialFlow.fresh(config, opts)
    local progress = freshProgress(config and config.version)
    if opts and opts.hallTrack == true then
        local track = math.floor(tonumber(config and config.hall_track) or 2)
        if track > 0 then
            progress.track = track
        end
    end
    return progress
end

-- Numeric tutorial steps existed before stable version metadata. Translate those saves one version
-- at a time so multiple reorders cannot send active players backward or credit an unrelated event.
-- Returns progress, changed. Completed players remain completed. `legacy_step_migration` remains a
-- compatibility fallback for the original v1 -> v2 migration; newer configs should author
-- `step_migrations[sourceVersion]` for every supported transition.
function TutorialFlow.migrateProgress(config, progress)
    local targetVersion = math.max(1, math.floor(tonumber(config and config.version) or 1))
    local normalized = TutorialFlow.normalizeProgress(progress)
    if normalized.version >= targetVersion then
        return normalized, false
    end

    while normalized.version < targetVersion do
        if not normalized.done then
            -- Stamp the old first-enemy beat before remapping. Cave enter did
            -- not exist; first_fight was "defeat an enemy" (v3 step 8 / v2 step 5).
            if
                TutorialFlow.startedFirstEnemy(
                    normalized.version,
                    normalized.step,
                    normalized.count
                )
            then
                normalized.firstEnemy = true
            end
            local migrations = config and config.step_migrations
            local mapping = migrations and migrations[normalized.version]
            if not mapping and normalized.version == 1 then
                mapping = config and config.legacy_step_migration
            end
            local rule = mapping and mapping[normalized.step]
            normalized.step =
                math.max(1, math.floor(tonumber(rule and rule.step) or normalized.step))
            if not (rule and rule.preserve_count == true) then
                normalized.count = 0
            end
        end
        normalized.version += 1
    end
    return normalized, true
end

-- first_fight index on each Homeworld version. After that beat came brew / Rally.
-- v6 first_fight is the cave-training handoff, not a kill count.
local FIRST_FIGHT_INDEX = {
    [1] = 5,
    [2] = 5,
    [3] = 8,
    [4] = 5,
    [5] = 8,
}

function TutorialFlow.startedFirstEnemy(version, step, count)
    local fightAt = FIRST_FIGHT_INDEX[math.floor(tonumber(version) or 0)]
    if not fightAt then
        return false
    end
    step = math.floor(tonumber(step) or 0)
    if step > fightAt then
        return true
    end
    return step == fightAt and (tonumber(count) or 0) > 0
end

-- Old first-enemy beat (v1–v5 combat start). A live CombatTutorial save is the
-- new track — leave those players alone so they can finish or keep going.
function TutorialFlow.firstEnemyEvidence(config, progress, evidence)
    progress = TutorialFlow.normalizeProgress(progress, config and config.version)
    evidence = type(evidence) == "table" and evidence or {}
    if progress.done == true or evidence.tutorialCompleted == true then
        return true, "tutorial_done"
    end
    if progress.firstEnemy == true then
        return true, "first_enemy"
    end
    if type(evidence.combatTutorial) == "table" then
        return false, nil
    end
    local step = TutorialFlow.current(config, progress)
    if step and step.id == "rally_call" then
        return true, "old_rally"
    end
    if step and step.id == "first_fight" and (tonumber(progress.count) or 0) > 0 then
        return true, "first_fight_kills"
    end
    -- Do not use tutorial_first_fight here. Admin reset keeps that milestone
    -- and would mark a fresh first_fight done (Redo dialog on a reset / new run).
    -- Live enemies_defeated also must not count — stray Homeworld kills hid E.
    return false, nil
end

-- Give Heal to anyone who already finished or already scored the old first
-- enemy. Leave pre-fight players on the Homeworld path so they can enter the
-- new cave if they want. Never leave them waiting on combat_tutorial_complete.
function TutorialFlow.reconcileGrandfather(config, progress, evidence)
    progress = TutorialFlow.normalizeProgress(progress, config and config.version)
    evidence = type(evidence) == "table" and evidence or {}
    local started, reason = TutorialFlow.firstEnemyEvidence(config, progress, evidence)
    local alreadyDone = progress.done == true or evidence.tutorialCompleted == true
    local completeTutorial = started and not alreadyDone
    if completeTutorial then
        progress.done = true
        progress.firstEnemy = true
    end
    return progress,
        {
            completeTutorial = completeTutorial,
            unlockHeal = alreadyDone or started,
            bindHeal = alreadyDone or started,
            reason = alreadyDone and "already_done" or reason,
        }
end

-- Cave E is always on. Ask Redo only after they actually finished the cave.
-- Homeworld Tutorial.done / TutorialCompleted is not enough — grandfather,
-- veteran skip, and admin-reset leftovers all set those without a cave run.
function TutorialFlow.caveEnterNeedsConfirm(_homeProgress, combatProgress, _gameData)
    return type(combatProgress) == "table" and combatProgress.done == true
end

-- Lobby lessons (ready / brew / bind). Arena fights and the pillar stay
-- inside the room — Leave E is lobby-only, like Range.
function TutorialFlow.isCombatLobbyStep(step)
    if type(step) ~= "table" then
        return false
    end
    if type(step.spawn) == "table" and step.spawn.where == "arena" then
        return false
    end
    if step.return_to_lobby == true or step.activate_beacon == true then
        return false
    end
    return true
end

function TutorialFlow.total(config)
    return #(config.steps or {})
end

-- A save that predates the tutorial shouldn't get walked through hatching their 40th egg.
function TutorialFlow.isVeteran(config, claimedLevel, ownsPets)
    local skip = config.veteran_skip or {}
    if ownsPets then
        return true
    end
    return (tonumber(claimedLevel) or 0) >= (tonumber(skip.min_claimed_level) or math.huge)
end

-- Ascension stays hidden until the player finishes either independent introduction: the
-- crystal/Homeworld tutorial OR Combat Training. Persisted claimed levels above 1 prove that an
-- older player already ascended, while profiles with neither tutorial record retain the legacy
-- compatibility behavior rather than being relocked after an update.
function TutorialFlow.ascensionUnlocked(config, progress, combatProgress, gameData, claimedLevel)
    if not (config and config.hold_level_claim == true) then
        return true
    end
    if math.max(1, math.floor(tonumber(claimedLevel) or 1)) > 1 then
        return true
    end
    if type(gameData) == "table" and gameData.TutorialCompleted == true then
        return true
    end
    if type(progress) == "table" and progress.done == true then
        return true
    end
    if type(combatProgress) == "table" and combatProgress.done == true then
        return true
    end
    if type(progress) ~= "table" and type(combatProgress) ~= "table" then
        return true
    end
    return false
end

-- Hold CLAIM (Power Choice / altar), not ordinary game XP, behind the same visibility rule.
function TutorialFlow.allowsLevelClaim(config, progress, gameData, combatProgress, claimedLevel)
    return TutorialFlow.ascensionUnlocked(config, progress, combatProgress, gameData, claimedLevel)
end

function TutorialFlow.stepIndex(config, stepId)
    if type(stepId) ~= "string" or stepId == "" then
        return nil
    end
    for index, step in ipairs((config and config.steps) or {}) do
        if step.id == stepId then
            return index, step
        end
    end
    return nil
end

-- Mid-fight leave: rewind to that loop's lobby so prep (brew, tank, vials)
-- runs again. Never advances. Clears counts and grants from the resume
-- step through the abandoned step so those grants can re-fire.
function TutorialFlow.rewindTo(config, progress, stepId)
    progress = TutorialFlow.normalizeProgress(progress, config and config.version)
    if progress.done then
        return progress, false
    end
    local target = TutorialFlow.stepIndex(config, stepId)
    if not target or target >= progress.step then
        return progress, false
    end
    local granted = type(progress.granted) == "table" and progress.granted or nil
    if granted then
        for index = target, progress.step do
            local step = (config.steps or {})[index]
            if step and type(step.id) == "string" then
                granted[step.id] = nil
            end
        end
        progress.granted = granted
    end
    progress.step = target
    progress.count = 0
    return progress, true
end

-- The active step record (+ its index), or nil when the tutorial is finished.
function TutorialFlow.current(config, progress)
    progress = TutorialFlow.normalizeProgress(progress, config and config.version)
    if progress.done then
        return nil
    end
    local step = (config.steps or {})[progress.step]
    if not step then
        return nil -- step index past the end (config shrank) — treat as done
    end
    return step, progress.step
end

-- A step can name one `event` and/or an `events` list (any match completes).
function TutorialFlow.eventMatches(cond, eventName)
    if type(cond) ~= "table" or type(eventName) ~= "string" or eventName == "" then
        return false
    end
    if cond.event == eventName then
        return true
    end
    if type(cond.events) == "table" then
        for _, name in ipairs(cond.events) do
            if name == eventName then
                return true
            end
        end
    end
    return false
end

-- Feed one bus event. Returns (newProgress, changed).
function TutorialFlow.advance(config, progress, eventName, ctx)
    progress = TutorialFlow.normalizeProgress(progress, config and config.version)
    if progress.done then
        return progress, false
    end
    local step = (config.steps or {})[progress.step]
    if not step then
        progress.done = true
        return progress, true
    end
    local cond = step.complete_on or {}
    if not TutorialFlow.eventMatches(cond, eventName) then
        return progress, false
    end
    if type(cond.potion) == "string" then
        if type(ctx) ~= "table" or ctx.potion ~= cond.potion then
            return progress, false
        end
    end
    if type(cond.enemy) == "string" then
        if type(ctx) ~= "table" or ctx.enemy ~= cond.enemy then
            return progress, false
        end
    end
    -- Optional exact event-payload predicates keep progression authored in config.
    -- Example: an enhancement lesson can require { context = { powerId = "heal" } }
    -- instead of accepting an enhancement slotted into an unrelated power.
    if type(cond.context) == "table" then
        if type(ctx) ~= "table" then
            return progress, false
        end
        for key, expected in pairs(cond.context) do
            if ctx[key] ~= expected then
                return progress, false
            end
        end
    end
    -- sum_ctx: accumulate a NUMBER from the event ctx instead of counting events —
    -- the farm step sums coin_payout amounts so "count" reads as COINS EARNED and the
    -- player keeps mining until they can afford the next egg (Jason's coin gate).
    local increment = 1
    if cond.sum_ctx then
        increment = (type(ctx) == "table" and tonumber(ctx[cond.sum_ctx])) or 0
        if increment <= 0 then
            return progress, false -- payout event without a usable amount: no credit
        end
    end
    progress.count += increment
    if progress.count < (tonumber(cond.count) or 1) then
        return progress, true -- partial credit (the capsule can show 1/3)
    end
    progress.step += 1
    progress.count = 0
    if progress.step > #config.steps then
        progress.done = true
    end
    return progress, true
end

-- Door-plate copy for a counted lobby lesson (e.g. drink five Berserk Brews).
-- remaining_plates[left] / remaining_nudges[left] win while sips are still owed.
function TutorialFlow.doorButtonCopy(step, progress)
    local button = step and step.door_button
    if type(button) ~= "table" then
        return nil, nil
    end
    local need = tonumber(step.complete_on and step.complete_on.count) or 1
    local have = math.max(0, math.floor(tonumber(progress and progress.count) or 0))
    local left = math.max(0, need - have)
    if left <= 0 then
        return button.text, button.nudge
    end
    local plates = button.remaining_plates
    local nudges = button.remaining_nudges
    local text = type(plates) == "table" and plates[left] or button.text
    local nudge = type(nudges) == "table" and nudges[left] or button.nudge
    return text, nudge
end

-- The client-facing view the service pushes (no config tables leak to the wire).
function TutorialFlow.stateFor(config, progress, context)
    progress = TutorialFlow.normalizeProgress(progress, config and config.version)
    if progress.done then
        return { done = true }
    end
    local step, index = TutorialFlow.current(config, progress)
    if not step then
        return { done = true }
    end
    local need = tonumber((step.complete_on or {}).count) or 1
    local bodyField = if context
            and context.hasUnequippedPets
            and step.body_with_unequipped
        then "body_with_unequipped"
        else "body"
    local localizationKey = step.localization_key or ("tutorial." .. tostring(step.id))
    return {
        done = false,
        index = index,
        total = TutorialFlow.total(config),
        id = step.id,
        title = step.title,
        title_key = localizationKey .. ".title",
        body = step[bodyField],
        body_key = localizationKey .. "." .. bodyField,
        target = step.target or { kind = "none" },
        handoff = type(step.handoff) == "table" and step.handoff or nil,
        count = progress.count,
        need = need,
    }
end

return TutorialFlow
