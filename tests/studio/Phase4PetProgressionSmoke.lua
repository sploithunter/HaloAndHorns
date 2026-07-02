--[[
    Command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.Phase4PetProgressionSmoke).runText()

    Verifies Phase 4's first live loop: a unique pet grant rolls configured hatch
    enchants, equipped unique pets can receive breakable XP, and state restores.
]]

local Phase4PetProgressionSmoke = {}

local function getRemote()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remote = ReplicatedStorage:WaitForChild("StudioSmokeTest", 10)
    assert(remote, "StudioSmokeTest remote not found")
    return remote
end

function Phase4PetProgressionSmoke.run(options)
    local remote = getRemote()
    local result = remote:InvokeServer("RunPhase4PetProgressionSmoke", options or {})
    assert(result and result.ok, result and result.error or "Phase4PetProgressionSmoke failed")
    return result
end

function Phase4PetProgressionSmoke.runText(options)
    local result = Phase4PetProgressionSmoke.run(options)
    local data = result.result or {}
    local enchant = data.firstEnchant or {}
    local rerolled = data.rerolledEnchant or {}
    return string.format(
        "Phase4PetProgressionSmoke complete: enchant=%s strength=%s reroll=%s strength=%s xp=%s level=%s exp=%s slots=%s/%s slotBonus=%s hatchLuck=%s secretLuck=%s damage=%s team=%s efficiency=%s restored=%s",
        tostring(enchant.display_name or enchant.id or "-"),
        tostring(enchant.strength or "-"),
        tostring(rerolled.display_name or rerolled.id or "-"),
        tostring(rerolled.strength or "-"),
        tostring(data.xp or 0),
        tostring(data.level or 0),
        tostring(data.exp or 0),
        tostring(data.unlockedEnchantSlots or 0),
        tostring(data.maxEnchantments or 0),
        tostring(data.slotBonus or 0),
        tostring(data.hatchLuck or 0),
        tostring(data.secretLuck or 0),
        tostring(data.petDamage or 0),
        tostring(data.teamPower or 0),
        tostring(data.petEfficiency or 0),
        tostring(result.restored == true)
    )
end

return Phase4PetProgressionSmoke
