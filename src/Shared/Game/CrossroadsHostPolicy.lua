-- Shared assignment priority. Candidates are live player snapshots, never profile mutations.
local Policy = {}
function Policy.choose(candidates, current, config, hasEgg)
    local choices = {}
    for _, c in ipairs(candidates) do
        if c.alive and c.inCrossroads then
            local same = current and current.id == c.id
            local gateRadius = same and current.activity == "gate" and config.gate_exit_radius
                or config.gate_enter_radius
            local activityRadius = same
                    and current.activity ~= "gate"
                    and config.activity_exit_radius
                or config.activity_approach_radius
            local activity, priority, distance
            if c.gateDistance <= gateRadius then
                activity, priority, distance = "gate", c.served and 1 or 0, c.gateDistance
            elseif hasEgg and c.eggDistance <= config.egg_enter_radius then
                activity, priority, distance = "egg", 2, c.eggDistance
            elseif c.activityDistance <= activityRadius then
                activity, priority, distance = "activity", 3, c.activityDistance
            end
            if activity then
                table.insert(choices, {
                    id = c.id,
                    activity = activity,
                    priority = priority,
                    distance = distance,
                    sticky = same and current.activity == activity,
                    candidate = c,
                })
            end
        end
    end
    table.sort(choices, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        if a.sticky ~= b.sticky then
            return a.sticky
        end
        if a.distance ~= b.distance then
            return a.distance < b.distance
        end
        return a.id < b.id
    end)
    return choices[1]
end
return Policy
