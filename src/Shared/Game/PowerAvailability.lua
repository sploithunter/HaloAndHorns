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

-- Preserve config order while removing powers hidden in the current player context. Keeping this
-- pure lets every catalog surface share the same rule instead of independently special-casing Heal
-- or Resonance in UI code.
function PowerAvailability.filterAvailableIds(ids, definitions, snapshot)
    local filtered = {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local def = type(definitions) == "table" and definitions[id] or nil
        if PowerAvailability.isAvailable(def, snapshot) then
            filtered[#filtered + 1] = id
        end
    end
    return filtered
end

function PowerAvailability.snapshotForPlayer(player)
    return {
        inCombatTutorial = player ~= nil and player:GetAttribute("InCombatTutorial") == true,
        combatTutorialHealUnlocked = player ~= nil
            and player:GetAttribute("CombatTutorialHealUnlocked") == true,
    }
end

return PowerAvailability
