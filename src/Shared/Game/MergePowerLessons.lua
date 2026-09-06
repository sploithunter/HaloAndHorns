-- Pure rules for the wave-paced power introduction. Receipts live separately from
-- combat courses: learning a power here must never fabricate course completion/rewards.
local Lessons = {}

function Lessons.graduate(data)
    return data
            and ((data.Tutorial and data.Tutorial.done == true) or (data.CombatTutorial and data.CombatTutorial.done == true) or (data.GameData and data.GameData.TutorialCompleted == true))
        or false
end

function Lessons.allocated(slots)
    local count = 0
    for _, list in pairs(slots or {}) do
        for _, slot in ipairs(list) do
            if type(slot) == "table" and slot.inherent ~= true then
                count += 1
            end
        end
    end
    return count
end

function Lessons.recommended(cfg, hasDog)
    return hasDog and cfg.recommended_with_dog or cfg.recommended_without_dog
end

function Lessons.guide(
    cfg,
    stage,
    pendingPicks,
    pendingSlots,
    remainingPicks,
    remainingSlots,
    enhancing,
    target,
    staged
)
    local copy = cfg.guide
    if pendingPicks > 0 then
        return remainingPicks > 0 and copy.pick_power or copy.commit,
            remainingPicks > 0 and "power" or "commit"
    elseif pendingSlots > 0 then
        return remainingSlots > 0 and string.format(copy.pick_slots, remainingSlots) or copy.commit,
            remainingSlots > 0 and "slots" or "commit"
    elseif stage == "enhance" then
        if not enhancing then
            return copy.open_power, "owned"
        end
        if staged then
            return copy.apply, "apply"
        end
        if not target then
            return copy.choose_slot, "slot"
        end
        return copy.choose_enhancement, "enhancement"
    end
    return nil
end

return Lessons
