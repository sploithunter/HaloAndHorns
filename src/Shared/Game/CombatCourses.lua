-- Pure course projection/migration. Completed Basic remains a permanent competency receipt,
-- even while replaying or taking an optional course. No shared config is mutated per player.
local CombatCourses = {}

function CombatCourses.project(catalog, definition)
    local config = table.clone(catalog)
    config.steps = {}
    config.completion = definition.completion
    config.courseId = definition.id
    local copying = false
    for _, step in ipairs(catalog.steps) do
        if step.id == definition.first then
            copying = true
        end
        if copying then
            table.insert(config.steps, table.clone(step))
        end
        if step.id == definition.last then
            break
        end
    end
    assert(
        #config.steps > 0 and config.steps[#config.steps].id == definition.last,
        "Invalid combat course boundaries"
    )
    config.steps[#config.steps].return_to_lobby = nil
    config.steps[#config.steps].return_to_exit = true
    return config
end

function CombatCourses.migrate(catalog, courses, data, flow)
    if data.CombatCoursesVersion == courses.version then
        local changed = false
        for _, definition in ipairs(courses.courses) do
            if type(data[definition.key]) ~= "table" then
                data[definition.key] = flow.fresh(CombatCourses.project(catalog, definition))
                changed = true
            end
        end
        return changed
    end
    local old = type(data.CombatTutorial) == "table"
            and flow.migrateProgress(catalog, data.CombatTutorial)
        or nil
    local cursor = 1
    for _, definition in ipairs(courses.courses) do
        local config = CombatCourses.project(catalog, definition)
        local progress = flow.fresh(config)
        if old then
            local finished = old.done == true or old.step >= cursor + #config.steps
            if finished then
                progress.step = #config.steps + 1
                progress.done = true
                -- Prior graduates keep credit, but historical advanced credit does not mint
                -- new levels/tokens. Basic's old deferred level-2 reward still retries.
                if definition.id ~= "basic" then
                    data[definition.key .. "RewardGranted"] = true
                    progress.completionLevelGranted = true
                else
                    progress.completionLevelTarget = old.completionLevelTarget or 2
                    progress.completionLevelGranted = old.completionLevelGranted
                end
            elseif old.step >= cursor then
                progress.step = old.step - cursor + 1
                progress.count = old.count
                progress.granted = old.granted
            end
        end
        data[definition.key] = progress
        cursor += #config.steps
    end
    data.CombatCoursesVersion = courses.version
    return true
end

function CombatCourses.allowed(data, definition)
    local prerequisite = definition.prerequisite
    return not prerequisite
        or (type(data[prerequisite]) == "table" and data[prerequisite].done == true)
end

function CombatCourses.levelTarget(completion, earned, cap)
    return math.min(
        cap,
        math.max(1, math.floor(tonumber(earned) or 1)) + (tonumber(completion.grant_levels) or 0)
    )
end

function CombatCourses.funnels(catalog, courses)
    local funnels = {}
    for _, definition in ipairs(courses.courses) do
        local prefix = "course_" .. definition.id .. "_"
        local funnel = {
            key = definition.id,
            name = definition.title .. courses.analytics.suffix,
            steps = {
                {
                    id = prefix .. "started",
                    name = courses.analytics.entry_name,
                    event = "combat_tutorial_started",
                    match = { courseId = definition.id },
                },
            },
        }
        for _, step in ipairs(CombatCourses.project(catalog, definition).steps) do
            table.insert(funnel.steps, {
                id = prefix .. step.id,
                name = step.id == definition.last and courses.analytics.finish_name or step.title,
                event = "tutorial_step_completed",
                match = { stepId = "combat_" .. step.id, courseId = definition.id },
            })
        end
        table.insert(funnels, funnel)
    end
    return courses.analytics.enabled and funnels or {}
end

return CombatCourses
