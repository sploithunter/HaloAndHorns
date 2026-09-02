local MergeTutorialHud = {}

function MergeTutorialHud.coversHotbar(observing, currentWave, finalTutorialWave, tutorialRequired)
    if observing ~= true or tutorialRequired ~= true then
        return false
    end

    local wave = assert(tonumber(currentWave), "Merge tutorial HUD requires currentWave")
    local finalWave =
        assert(tonumber(finalTutorialWave), "Merge tutorial HUD requires finalTutorialWave")
    return wave >= 0 and wave <= finalWave
end

function MergeTutorialHud.combatCard(tutorial, currentWave)
    if type(tutorial) ~= "table" or type(tutorial.combat_cards) ~= "table" then
        return nil
    end
    local wave = tonumber(currentWave)
    if not wave or wave < 0 then
        return nil
    end

    local phase
    if wave <= assert(tonumber(tutorial.pause_after_wave), "pause_after_wave is required") then
        phase = "combat_waves"
    elseif
        wave
        <= assert(tonumber(tutorial.pause_after_cannon_wave), "pause_after_cannon_wave is required")
    then
        phase = "cannon_waves"
    elseif
        wave
        <= assert(
            tonumber(tutorial.pause_after_upgrade_wave),
            "pause_after_upgrade_wave is required"
        )
    then
        phase = "upgrade_waves"
    elseif
        wave
        <= assert(
            tonumber(tutorial.pause_after_quartermaster_wave),
            "pause_after_quartermaster_wave is required"
        )
    then
        phase = "quartermaster_waves"
    end
    return phase and tutorial.combat_cards[phase] or nil
end

function MergeTutorialHud.stableScreenOffset(targetAbsolute, currentAbsolute, currentOffset)
    local target = assert(tonumber(targetAbsolute), "targetAbsolute is required")
    local rendered = assert(tonumber(currentAbsolute), "currentAbsolute is required")
    local assigned = assert(tonumber(currentOffset), "currentOffset is required")

    -- A ScreenGui's safe-area transform is the rendered coordinate minus the assigned offset.
    -- Subtract that stable origin once so repeated layout passes remain idempotent.
    return target - (rendered - assigned)
end

function MergeTutorialHud.fitLeftBlocker(x, width, blockerRight, gap, minimumWidth)
    local left = assert(tonumber(x), "x is required")
    local requiredWidth = assert(tonumber(width), "width is required")
    local cardWidth = math.max(0, requiredWidth)
    local blockerEdge = tonumber(blockerRight)
    if not blockerEdge or cardWidth <= 0 then
        return left, cardWidth
    end

    local clearance = tonumber(gap)
    if clearance == nil then
        clearance = 0
    end
    clearance = math.max(0, clearance)
    local minimum = tonumber(minimumWidth)
    if minimum == nil then
        minimum = 0
    end
    minimum = math.clamp(minimum, 0, cardWidth)
    local right = left + cardWidth
    local desiredLeft = math.max(left, blockerEdge + clearance)
    local fittedLeft = math.min(desiredLeft, right - minimum)
    return fittedLeft, right - fittedLeft
end

return MergeTutorialHud
