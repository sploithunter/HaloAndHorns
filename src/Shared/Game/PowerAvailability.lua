--[[
    PowerAvailability — when an otherwise-innate power is hidden from bind/cast.

    Config on the power:
      hidden_while = { in_combat_tutorial = true }
      hidden_while = { until_combat_tutorial = true }

    Snapshot is a plain table so headless tests need no Instances.
]]

local PowerAvailability = {}

function PowerAvailability.isHidden(def, snapshot)
    if type(def) ~= "table" or type(def.hidden_while) ~= "table" then
        return false
    end
    snapshot = snapshot or {}
    if def.hidden_while.in_combat_tutorial == true and snapshot.inCombatTutorial == true then
        return true
    end
    -- Heal stays off the Homeworld Resonance bind so that lesson has one power.
    -- First combat-training enter unlocks it for good (attribute survives leave).
    if def.hidden_while.until_combat_tutorial == true then
        return snapshot.inCombatTutorial ~= true and snapshot.combatTutorialHealUnlocked ~= true
    end
    return false
end

function PowerAvailability.isAvailable(def, snapshot)
    return not PowerAvailability.isHidden(def, snapshot)
end

function PowerAvailability.snapshotForPlayer(player)
    return {
        inCombatTutorial = player ~= nil and player:GetAttribute("InCombatTutorial") == true,
        combatTutorialHealUnlocked = player ~= nil
            and player:GetAttribute("CombatTutorialHealUnlocked") == true,
    }
end

return PowerAvailability
