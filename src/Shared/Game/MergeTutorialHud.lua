local MergeTutorialHud = {}

function MergeTutorialHud.coversHotbar(
    observing,
    currentWave,
    finalTutorialWave,
    tutorialRequired,
    basicRequired
)
    if observing == true and basicRequired == true then
        return true
    end
    if basicRequired == false then
        return false
    end
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

return MergeTutorialHud
