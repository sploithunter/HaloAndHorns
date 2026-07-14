--[[
    PetProjectionPolicy

    Classifies a replicated pet-record transaction by whether it can change the
    visible inventory card/grid. XP progress alone is data-only: tooltips read
    the stable replicated record when opened, so rebuilding every card is waste.
]]

local PetProjectionPolicy = {
    DATA_ONLY = "data_only",
    VISUAL = "visual",
}

function PetProjectionPolicy.forProgression(levelChanged, enchantChanged)
    if levelChanged == true or enchantChanged == true then
        return PetProjectionPolicy.VISUAL
    end
    return PetProjectionPolicy.DATA_ONLY
end

function PetProjectionPolicy.forMutationResults(results)
    for _, result in pairs(results or {}) do
        -- Unknown mutation results fail safe: render rather than leave a card stale.
        if type(result) ~= "table" or result.visualChanged ~= false then
            return PetProjectionPolicy.VISUAL
        end
    end
    return PetProjectionPolicy.DATA_ONLY
end

return PetProjectionPolicy
