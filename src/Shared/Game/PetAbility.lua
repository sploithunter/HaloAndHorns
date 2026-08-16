--[[
    PetAbility — pure, display-safe view of a pet's implemented inherent abilities.

    Support/control auras live in pet_roles.support_auras. Attack-bound control lives in
    pets.pets[id].attack_control and executes on every hit in PetFollowService. Card and egg-preview
    UIs use this resolver so both kinds receive the same lower-right ability badge without copying an
    on-hit control into the aura table (which would accidentally execute it twice).
]]

local PetAbility = {}

local function appendUnique(out, seen, ability, source, targeting)
    if type(ability) ~= "table" or type(ability.kind) ~= "string" or ability.kind == "" then
        return
    end
    local key = source .. ":" .. ability.kind
    if seen[key] then
        return
    end
    seen[key] = true
    local view = {}
    for field, value in pairs(ability) do
        view[field] = value
    end
    view.source = source
    if targeting and not view.targeting then
        view.targeting = targeting
    end
    table.insert(out, view)
end

function PetAbility.forPet(petType, rolesConfig, petsConfig)
    local out, seen = {}, {}
    if type(petType) ~= "string" or petType == "" then
        return out
    end

    local entry = rolesConfig and rolesConfig.support_auras and rolesConfig.support_auras[petType]
    local auras = type(entry) == "table" and (entry.kind and { entry } or entry) or {}
    for _, aura in ipairs(auras) do
        appendUnique(out, seen, aura, "aura")
    end

    local petDef = petsConfig and petsConfig.pets and petsConfig.pets[petType]
    local control = petDef and petDef.attack_control
    appendUnique(out, seen, control, "attack_control", petDef and petDef.attack_targeting)

    return out
end

return PetAbility
