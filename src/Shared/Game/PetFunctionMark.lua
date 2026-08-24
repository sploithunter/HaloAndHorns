--[[
    PetFunctionMark — combat-function chip (heal / armor / debuff).

    Support is one role. This mark answers "what does this pet actually do?" so a
    healer is not just another purple S. Presentation lives in
    configs/power_icons.lua `function_mark`; this module is the Roblox-free lookup.

    PetFunctionMark.forKind(kind, iconsConfig) -> mark | nil
    PetFunctionMark.forAbilities(abilities, iconsConfig) -> best mark | nil
    PetFunctionMark.forPet(petType, rolesConfig, petsConfig, iconsConfig) -> mark | nil
    PetFunctionMark.forEnemyDef(def, iconsConfig) -> mark | nil
]]

local PetAbility = require(script.Parent.PetAbility)

local PetFunctionMark = {}

local function specForGroup(group, iconsConfig)
    local groups = iconsConfig and iconsConfig.function_mark and iconsConfig.function_mark.groups
    return groups and groups[group]
end

local function priorityIndex(group, iconsConfig)
    local order = iconsConfig and iconsConfig.function_mark and iconsConfig.function_mark.priority
    if type(order) == "table" then
        for i, id in ipairs(order) do
            if id == group then
                return i
            end
        end
    end
    return 99
end

function PetFunctionMark.groupForKind(kind, iconsConfig)
    local byKind = iconsConfig and iconsConfig.function_mark and iconsConfig.function_mark.by_kind
    return type(kind) == "string" and byKind and byKind[kind] or nil
end

function PetFunctionMark.forKind(kind, iconsConfig)
    local group = PetFunctionMark.groupForKind(kind, iconsConfig)
    if not group then
        return nil
    end
    local spec = specForGroup(group, iconsConfig)
    if type(spec) ~= "table" or type(spec.symbol) ~= "string" or spec.symbol == "" then
        return nil
    end
    return {
        group = group,
        kind = kind,
        symbol = spec.symbol,
        element = spec.element,
        color = spec.color,
        label = spec.label,
    }
end

function PetFunctionMark.forAbilities(abilities, iconsConfig)
    if type(abilities) ~= "table" then
        return nil
    end
    local best, bestPri
    for _, ability in ipairs(abilities) do
        local kind = type(ability) == "table" and ability.kind or ability
        local mark = PetFunctionMark.forKind(kind, iconsConfig)
        if mark then
            local pri = priorityIndex(mark.group, iconsConfig)
            if not best or pri < bestPri then
                best, bestPri = mark, pri
            end
        end
    end
    return best
end

function PetFunctionMark.forPet(petType, rolesConfig, petsConfig, iconsConfig)
    return PetFunctionMark.forAbilities(
        PetAbility.forPet(petType, rolesConfig, petsConfig),
        iconsConfig
    )
end

-- Enemy healers are authored as auto_heal (live, tutorial, and heal-support invaders).
function PetFunctionMark.forEnemyDef(def, iconsConfig)
    if type(def) ~= "table" then
        return nil
    end
    if type(def.auto_heal) == "table" then
        return PetFunctionMark.forKind("heal", iconsConfig)
    end
    return PetFunctionMark.forKind(def.FunctionKind or def.function_kind, iconsConfig)
end

function PetFunctionMark.badgeElement(kind, fallbackElement, iconsConfig)
    local mark = PetFunctionMark.forKind(kind, iconsConfig)
    return (mark and mark.element) or fallbackElement
end

return PetFunctionMark
