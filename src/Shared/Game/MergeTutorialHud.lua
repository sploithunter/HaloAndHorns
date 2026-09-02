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

return MergeTutorialHud
