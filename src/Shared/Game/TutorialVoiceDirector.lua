-- Pure cue selection. State identity excludes count/localization/device refreshes.
local Director = {}
function Director.catalog(config)
    local cues = {}
    for _, section in ipairs(config.sections) do
        for _, line in ipairs(section.lines) do
            local copy = table.clone(line)
            copy.speaker = section.speaker
            cues[line.cue] = copy
        end
    end
    return cues
end
function Director.key(state)
    if type(state) ~= "table" or state.done or type(state.id) ~= "string" then
        return nil
    end
    return (state.courseId and "combat_tutorial." or "tutorial.") .. state.id
end
function Director.completion(previous, state)
    if not Director.key(previous) or type(state) ~= "table" or not state.done then
        return nil
    end
    if previous.courseId then
        if state.courseId ~= previous.courseId then
            return nil
        end
        if
            state.replay
            or (
                state.completion
                and state.completion.localization_key == "combat_courses.replay.completion"
            )
        then
            return "combat_courses.replay.completion"
        end
        return "combat_courses." .. previous.courseId .. ".completion"
    end
    return not state.courseId and "tutorial.completion" or nil
end
function Director.introduction(previous, state)
    if not Director.key(state) then
        return nil
    end
    local entering = not Director.key(previous) or previous.courseId ~= state.courseId
    if not entering then
        return nil
    end
    if state.courseId and state.replay then
        return "combat_courses.replay.start"
    end
    if (tonumber(state.index) or 1) > 1 then
        return state.courseId and "combat_tutorial.resume" or "tutorial.resume"
    end
    return nil
end
function Director.doorCue(config, failedKind, stepId, remaining)
    if failedKind and config.door_failures[failedKind] then
        return config.door_failures[failedKind]
    end
    if stepId == "stack_brew" and remaining and remaining >= 1 and remaining <= 4 then
        return "combat_tutorial.stack_brew.remaining_" .. tostring(remaining)
    end
    return config.door_steps[stepId]
end
return Director
