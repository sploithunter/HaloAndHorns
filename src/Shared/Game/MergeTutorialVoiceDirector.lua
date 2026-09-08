-- Pure client cue selection. Replicated tutorial eligibility/progress remain authoritative.
local Director = {}
function Director.new()
    return { heard = {} }
end
function Director.cue(side, suffix)
    return suffix and ("merge_tutorial." .. side .. "." .. suffix) or nil
end
function Director.step(self, current, config)
    local previous = self.previous
    if not current.observing or current.blocked or not config.side_speakers[current.side] then
        self.previous, self.identity = nil, nil
        self.engaged, self.completionQueued = nil, nil
        table.clear(self.heard)
        return { cancel = true }
    end
    local context = tostring(current.bay) .. ":" .. tostring(current.run) .. ":" .. current.side
    local changedContext = self.identity ~= context
    if changedContext then
        previous = nil
        table.clear(self.heard)
        self.identity = context
        self.engaged, self.completionQueued = nil, nil
    end
    self.previous = current
    local function cue(suffix)
        return Director.cue(current.side, suffix)
    end
    if current.rebirths > 0 or current.completed then
        local completedNow = current.completed
            and self.engaged
            and not self.completionQueued
            and current.rebirths == 0
        if completedNow then
            self.completionQueued = true
            return { cue = cue(config.completion_cue), finishCurrent = true, remind = false }
        end
        return { cancel = not previous or not previous.completed or current.rebirths > 0 }
    end
    if not current.required then
        -- Required/completed replicate separately; preserve the timed farewell during that gap.
        return self.engaged and { quiet = true } or { cancel = true }
    end
    self.engaged = true
    if current.active then
        local suffix = config.steps[current.step]
        if current.autoCollector and config.auto_steps[current.step] then
            suffix = config.auto_steps[current.step]
        elseif
            current.step == "upgrade_eggs"
            and current.createNeed > 0
            and current.created >= current.createNeed
        then
            suffix = "upgrade_eggs.deploy"
        end
        if not suffix then
            return { cancel = true }
        end
        local key = cue(suffix)
        local action = {
            cue = key,
            progress = current.progress,
            remind = current.step ~= "talk_quartermaster",
            help = config.power_steps[current.step] and cue(config.power_help[current.powerHelp])
                or nil,
            reset = changedContext,
        }
        if not previous and current.step ~= "collect_setup" then
            action.intro = cue(config.resume_cue)
        end
        self.heard[key] = true
        return action
    end
    if previous and previous.active then
        local suffix = config.after_steps[previous.step]
        if suffix then
            local key = cue(suffix)
            if not self.heard[key] then
                self.heard[key] = true
                return { cue = key, remind = false }
            end
        end
    end
    -- Combat intervals do not invent new objectives or repeat earlier tutorial milestones.
    return { quiet = true, reset = changedContext }
end
return Director
