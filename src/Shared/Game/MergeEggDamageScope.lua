-- Merge Defense owns a contextual damage multiplier for all allied pets.
--
-- The Gem damage upgrade and Rebirth both add percentages to the same base 1.0. They never
-- multiply each other: +45% Gems plus +100% Rebirth is 1 + .45 + 1 = 2.45x. Hatcher squads and
-- Simple-mode reserves receive this combined value on their ephemeral models; Full-mode durable
-- pets resolve it contextually here so the bonus cannot escape the Merge Defense world.

local MergeEggDamageScope = {}

function MergeEggDamageScope.additiveUpgradeMultiplier(
    managementDamageMultiplier,
    rebirthDamageMultiplier
)
    local managementBonus = math.max(0, (tonumber(managementDamageMultiplier) or 1) - 1)
    local rebirthBonus = math.max(0, (tonumber(rebirthDamageMultiplier) or 1) - 1)
    return 1 + managementBonus + rebirthBonus
end

function MergeEggDamageScope.playerPetMultiplier(context)
    context = type(context) == "table" and context or {}
    if context.inMergeDefense ~= true or tostring(context.mode or "") ~= "full" then
        return 1
    end
    if context.mergeNpcUnit == true or context.simpleReserveUnit == true then
        return 1
    end
    return MergeEggDamageScope.additiveUpgradeMultiplier(
        context.managementDamageMultiplier,
        context.rebirthDamageMultiplier
    )
end

return MergeEggDamageScope
