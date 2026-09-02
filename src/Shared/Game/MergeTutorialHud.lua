local MergeTutorialHud = {}

function MergeTutorialHud.coversHotbar(observing, currentWave, finalTutorialWave)
    if observing ~= true then
        return false
    end

    local wave = assert(tonumber(currentWave), "Merge tutorial HUD requires currentWave")
    local finalWave =
        assert(tonumber(finalTutorialWave), "Merge tutorial HUD requires finalTutorialWave")
    return wave >= 0 and wave <= finalWave
end

function MergeTutorialHud.stableScreenOffset(targetAbsolute, currentAbsolute, currentOffset)
    local target = assert(tonumber(targetAbsolute), "targetAbsolute is required")
    local rendered = assert(tonumber(currentAbsolute), "currentAbsolute is required")
    local assigned = assert(tonumber(currentOffset), "currentOffset is required")

    -- A ScreenGui's safe-area transform is the rendered coordinate minus the assigned offset.
    -- Subtract that stable origin once so repeated layout passes remain idempotent.
    return target - (rendered - assigned)
end

return MergeTutorialHud
