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
    if eventName ~= cond.event then
        return progress, false
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
        count = progress.count,
        need = need,
    }
end

return TutorialFlow
