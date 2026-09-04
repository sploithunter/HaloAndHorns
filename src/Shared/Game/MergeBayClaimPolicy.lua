-- Presentation only. Server _canBegin and RealmBuilder:Claim remain authoritative.
local Policy = {}

function Policy.canOffer(player, bayAvailable)
    return bayAvailable == true
        and player:GetAttribute("MergeEggBayId") == nil
        and player:GetAttribute("InMergeEggPrototype") ~= true
        and player:GetAttribute("InMission") == nil
        and player:GetAttribute("InPrologue") ~= true
        and player:GetAttribute("InCombatTutorial") ~= true
        and player:GetAttribute("GauntletMode") == nil
end

return Policy
