--[[
    PetTargeting — pure resolver for a pet's TARGETING SCOPE (Halo & Horns).

    The single source of truth for "how many targets does this hit", on two independent axes
    (Jason's model):

      • DAMAGE targeting — the pet's ATTACK. Drives the archetype/role badge ring AND (later) the
        attack hit-fanout. A melee bruiser is `single`; a damage-aura tank is `aura`.
      • POWER targeting — a support/control pet's ability/aura. Drives that ability's badge ring AND
        how the effect applies. The meerkat's hold is `single`; an emberimp's offense aura is `aura`.

    Scope vocabulary (maps 1:1 onto the uploaded ring art via power_icons.targeting_ring):
      single        -> one target            (inward ring, target_in)
      targeted_aoe  -> one target + splash   (target_aoe)
      aoe           -> untargeted area        (aoe)
      aura          -> persistent team/radius (aura)

    This module is the shared mechanical/display SSOT. `mechanicalAttackScope` applies the structural
    Huge rule used by runtime spawning; `displayAttackScope` additionally advertises a real periodic
    AoE proc so cards do not show a single-target ring for a pet that regularly splashes a cluster.
    Pure (no Roblox).

      PetTargeting.attackScope(explicit, roleId, rolesConfig) -> scope
      PetTargeting.mechanicalAttackScope(petDef, roleId, rolesConfig, options) -> scope
      PetTargeting.displayAttackScope(petDef, roleId, rolesConfig, options) -> scope
      PetTargeting.auraScope(aura, rolesConfig)               -> scope
      PetTargeting.isContagious(attackDot, explicitTargeting) -> boolean
]]

local PetTargeting = {}

PetTargeting.DEFAULT = "single"

function PetTargeting.isArea(scope)
    return scope == "targeted_aoe" or scope == "aoe" or scope == "aura"
end

-- CONTAGION is an orthogonal MODIFIER on the burn (attack_dot.spread), not a hit geometry — so it
-- composes with any attackScope (single+spread = the plague; targeted_aoe+spread = AoE-contagion).
-- This is the SSOT both surfaces use to decide whether to wear the spread marker over the geometry
-- ring. `attack_targeting == "contagion"` stays a back-compat shorthand (= single + default spread).
function PetTargeting.isContagious(attackDot, explicitTargeting)
    if explicitTargeting == "contagion" then
        return true
    end
    return type(attackDot) == "table" and type(attackDot.spread) == "table"
end

-- DAMAGE targeting: per-pet override (pets.lua `targeting` / a model attribute) -> role default
-- (pet_roles.roles[id].targeting) -> "single". Mirrors how defense/combat_mult resolve.
function PetTargeting.attackScope(explicit, roleId, rolesConfig)
    if type(explicit) == "string" and explicit ~= "" then
        return explicit
    end
    local roles = rolesConfig and rolesConfig.roles
    local def = roles and roleId and roles[roleId]
    local t = def and def.targeting
    if type(t) == "string" and t ~= "" then
        return t
    end
    return PetTargeting.DEFAULT
end

-- Runtime attack geometry, including the structural Huge contract: every Huge pet has an area
-- attack. A pet-authored huge_attack_targeting wins; otherwise a single-target Huge becomes the
-- standard targeted splash. `options.explicit` accepts a live model attribute when resolving HUDs.
function PetTargeting.mechanicalAttackScope(petDef, roleId, rolesConfig, options)
    petDef = type(petDef) == "table" and petDef or {}
    options = type(options) == "table" and options or {}

    local explicit = options.explicit
    if type(explicit) ~= "string" or explicit == "" then
        explicit = petDef.attack_targeting
    end
    local scope = PetTargeting.attackScope(explicit, roleId, rolesConfig)

    if options.huge == true then
        local hugeScope = petDef.huge_attack_targeting
        if type(hugeScope) == "string" and hugeScope ~= "" then
            return hugeScope
        end
        if not PetTargeting.isArea(scope) then
            return "targeted_aoe"
        end
    end

    return scope
end

-- Player-facing attack capability. A cooldown proc with real area damage receives the targeted-AoE
-- ring even when its ordinary swings remain single-target. This changes only the explanatory ring;
-- runtime fan-out continues to occur solely when that proc fires.
function PetTargeting.displayAttackScope(petDef, roleId, rolesConfig, options)
    options = type(options) == "table" and options or {}
    local scope = PetTargeting.mechanicalAttackScope(petDef, roleId, rolesConfig, options)
    if not PetTargeting.isArea(scope) and options.hasAreaProc == true then
        return "targeted_aoe"
    end
    return scope
end

-- POWER/aura targeting: the aura's own `targeting` -> the kind default (rolesConfig
-- .aura_targeting_by_kind[kind]) -> "single". So an `empower`/`hold` reads single and an
-- `offense`/`yield` reads aura without per-entry config, while any aura can override.
function PetTargeting.auraScope(aura, rolesConfig)
    if type(aura) ~= "table" then
        return PetTargeting.DEFAULT
    end
    if type(aura.targeting) == "string" and aura.targeting ~= "" then
        return aura.targeting
    end
    local byKind = rolesConfig and rolesConfig.aura_targeting_by_kind
    local t = byKind and aura.kind and byKind[aura.kind]
    if type(t) == "string" and t ~= "" then
        return t
    end
    return PetTargeting.DEFAULT
end

return PetTargeting
