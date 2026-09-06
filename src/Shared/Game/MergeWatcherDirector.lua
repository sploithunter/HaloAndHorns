-- Local encounter selection only: consumes replicated facts, never changes gameplay.
local Director = {}

function Director.new()
    return { seen = {}, count = 0, nextAt = 0, reminders = 0, reminderAt = 0 }
end

function Director.duration(config, clip, startedAt)
    if not clip then
        return config.duration_seconds
    end
    return math.clamp(
        startedAt + clip.seconds + config.voice.tail_seconds + config.fade_seconds,
        config.duration_seconds,
        config.voice.maximum_encounter_seconds
    )
end

-- `eligible and findWorld()` may produce false during startup, not just nil.
-- Keep all bay reads behind this boundary so unclaimed/other-side players are safe.
function Director.snapshot(bay)
    local function attribute(name)
        if not bay then
            return nil
        end
        return bay:GetAttribute(name)
    end
    return {
        eligible = bay ~= nil and bay ~= false,
        wave = tonumber(attribute("CurrentWave")) or 0,
        breaches = tonumber(attribute("EnemiesCrossedBreachLine")) or 0,
        bulwark = tonumber(attribute("EnemiesBreachedBulwark")) or 0,
        overrun = attribute("BreachOverrun") == true,
        tutorialStep = attribute("MergeEggTutorialStep"),
    }
end

function Director.step(state, snapshot, now, config)
    local previous = state.previous
    state.previous = snapshot
    if not snapshot.eligible then
        state.quartermasterSince = nil
        return nil
    end
    if snapshot.quartermaster then
        state.quartermasterSince = state.quartermasterSince or now
    else
        state.quartermasterSince = nil
    end
    if snapshot.blocked or now < state.nextAt or state.count >= config.max_encounters then
        return nil
    end

    local event
    -- Compare within one run only. Joining a battle with existing damage is not a fresh breach.
    if previous and previous.eligible and previous.run == snapshot.run then
        if (snapshot.overrun and not previous.overrun) or snapshot.breaches > previous.breaches then
            event = "gate"
        elseif snapshot.bulwark > previous.bulwark then
            event = "bulwark"
        end
    end
    if
        not event
        and state.quartermasterSince
        and now - state.quartermasterSince >= config.quartermaster_delay_seconds
        and now >= state.reminderAt
        and state.reminders < config.quartermaster_max_reminders
    then
        event = "quartermaster"
        state.reminders = state.reminders + 1
        state.reminderAt = now + config.quartermaster_reminder_seconds
    end
    if not event and snapshot.wave > 0 then
        for _, wave in ipairs(config.milestone_waves) do
            -- Exact current wave only: don't replay a backlog when joining a veteran's run.
            if snapshot.wave == wave and not state.seen[wave] then
                state.seen[wave] = true
                event = wave == config.milestone_waves[1] and "arrival" or "milestone"
                break
            end
        end
    end
    if event then
        state.count = state.count + 1
        state.nextAt = now + config.cooldown_seconds
    end
    return event
end

return Director
