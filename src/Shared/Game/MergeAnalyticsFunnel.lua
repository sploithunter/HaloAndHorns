-- Pure bounded state. Never send a later native step before its real predecessors.
local Funnel = {}

function Funnel.realm(value)
    return (value == "heaven" or value == "hell") and value or "unassigned"
end

function Funnel.controlRealm(autoplay, realm)
    return (autoplay == true and "autoplay" or "manual") .. ":" .. Funnel.realm(realm)
end

function Funnel.new(config, cohort)
    local state = {
        cohort = cohort,
        funnels = {},
        milestones = {},
        failures = {},
        clears = 0,
        lastWave = 0,
        autoActions = 0,
    }
    for key, definition in pairs(config.funnels) do
        if definition.enabled ~= false and (not definition.fresh_only or cohort == "fresh") then
            state.funnels[key] = { observed = {}, reached = 0 }
        end
    end
    return state
end

function Funnel.observe(state, config, event)
    local output = {}
    for key, progress in pairs(state.funnels) do
        local steps = config.funnels[key].steps
        for index, step in ipairs(steps) do
            if step[1] == event then
                progress.observed[index] = true
            end
        end
        while progress.observed[progress.reached + 1] do
            progress.reached += 1
            table.insert(
                output,
                { funnel = key, step = progress.reached, name = steps[progress.reached][2] }
            )
        end
    end
    return output
end

function Funnel.wave(state, config, wave)
    if type(wave) ~= "number" or wave ~= wave or wave == math.huge or wave <= state.lastWave then
        return {}
    end
    state.lastWave = wave
    state.clears = math.min(state.clears + 1, config.wave_thresholds[#config.wave_thresholds])
    local events = { "wave_cleared" }
    for _, threshold in ipairs(config.wave_thresholds) do
        if state.clears >= threshold then
            table.insert(events, "clears_" .. threshold)
        end
    end
    return events
end

function Funnel.autoAction(state, config)
    state.autoActions =
        math.min(state.autoActions + 1, config.autoplay_thresholds[#config.autoplay_thresholds])
    local events = { "autoplay_action" }
    for _, threshold in ipairs(config.autoplay_thresholds) do
        if state.autoActions >= threshold then
            table.insert(events, "auto_actions_" .. threshold)
        end
    end
    return events
end

function Funnel.validate(config)
    if type(config) ~= "table" or type(config.funnels) ~= "table" then
        return false, "Missing Merge analytics funnels"
    end
    if type(config.enabled) ~= "boolean" then
        return false, "Missing analytics enable flag"
    end
    for _, key in ipairs({
        "custom",
        "milestones",
        "failure_reasons",
        "failure_actions",
        "exit_reasons",
        "tutorial_stages",
    }) do
        if type(config[key]) ~= "table" then
            return false, "Missing analytics catalog: " .. key
        end
    end
    for _, key in ipairs({ "milestone", "failure", "exit", "tutorial" }) do
        local name = config.custom[key]
        if type(name) ~= "string" or #name == 0 or #name > 50 then
            return false, "Invalid custom event name"
        end
    end
    for _, key in ipairs({
        "queue_limit",
        "send_interval",
        "retry_limit",
        "entry_timeout_seconds",
        "trace_limit",
        "leave_flush_limit",
    }) do
        local value = config[key]
        if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
            return false, "Invalid Merge analytics limit: " .. key
        end
    end
    local names, count = {}, 0
    for _, definition in pairs(config.funnels) do
        count += 1
        if type(definition.name) ~= "string" or #definition.name > 50 or names[definition.name] then
            return false, "Invalid or duplicate funnel name"
        end
        names[definition.name] = true
        if type(definition.steps) ~= "table" or #definition.steps == 0 then
            return false, "Empty funnel"
        end
        local events = {}
        for _, step in ipairs(definition.steps) do
            if type(step[1]) ~= "string" or type(step[2]) ~= "string" or events[step[1]] then
                return false, "Invalid or duplicate funnel step"
            end
            events[step[1]] = true
        end
    end
    if count > 7 then
        return false, "Seven Merge funnels plus three existing funnels use Roblox's ten tabs"
    end
    for _, key in ipairs({ "wave_thresholds", "autoplay_thresholds" }) do
        local previous = 0
        if type(config[key]) ~= "table" or #config[key] == 0 then
            return false, "Missing thresholds"
        end
        for _, threshold in ipairs(config[key]) do
            if type(threshold) ~= "number" or threshold % 1 ~= 0 or threshold <= previous then
                return false, "Thresholds must increase"
            end
            previous = threshold
        end
    end
    return true
end

return Funnel
