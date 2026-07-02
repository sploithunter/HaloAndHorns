--[[
    PetPowerView — assembles a PetPower profile from the game configs (NOT pure; reads config).

    The bridge between the pure resolver (PetPower.resolveProfile) and the actual config knobs:
    given a pet's resolved base power + its type/variant (and optional role/context), it gathers
    every multiplier from config — role aptitude (pet_roles), per-pet override (pets), element flat
    (combat_fx element_stats), variant bump (pet_power) — and returns the two-number profile.

    Used by BOTH the inventory card (client) and the damage path (server) so "displayed" and
    "dealt" are computed the same way. Resilient: any missing config falls back to 1.

      PetPowerView.profile({ base, petType, variant, role?, context? }) -> PetPower.resolveProfile result
      PetPowerView.displayRound(n) -> integer (per pet_power.display_round)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetPower = require(ReplicatedStorage.Shared.Game.PetPower)
local PetSurvivability = require(ReplicatedStorage.Shared.Game.PetSurvivability)

local function loadConfig(name)
    local configs = ReplicatedStorage:FindFirstChild("Configs")
    local mod = configs and configs:FindFirstChild(name)
    if not mod or not mod:IsA("ModuleScript") then
        return nil
    end
    local ok, cfg = pcall(require, mod)
    return ok and cfg or nil
end

local PetPowerView = {}

-- Lazily cached config tables (synced + immutable at runtime).
local _power, _roles, _fx, _pets, _combat
local function configs()
    _power = _power or loadConfig("pet_power") or {}
    _roles = _roles or loadConfig("pet_roles") or {}
    _fx = _fx or loadConfig("combat_fx") or {}
    _pets = _pets or loadConfig("pets") or {}
    _combat = _combat or loadConfig("combat") or {}
    return _power, _roles, _fx, _pets, _combat
end

-- Role id for a pet: explicit override -> pet_roles.by_type[petType] -> default.
local function roleId(roles, petType, explicit)
    if explicit and explicit ~= "" then
        return explicit
    end
    return (roles.by_type and roles.by_type[petType]) or roles.default
end

-- Element flat attack multiplier for a pet (intrinsic; archetype-unify is contextual and not
-- applied to the displayed/base number).
local function elementMult(fx, petType)
    local origin = fx.origin or {}
    local element = origin.pettype_element and origin.pettype_element[petType]
    local stats = origin.element_stats and element and origin.element_stats[element]
    return (stats and tonumber(stats.attack_mult)) or 1, element
end

-- Element DURABILITY (the survivability mirror of elementMult): combat_fx taken_mult for the pet's
-- element. <1 = takes less = tankier. Currently 1.0 for every element; folds into EHP if tuned.
local function elementTakenMult(fx, petType)
    local origin = fx.origin or {}
    local element = origin.pettype_element and origin.pettype_element[petType]
    local stats = origin.element_stats and element and origin.element_stats[element]
    return (stats and tonumber(stats.taken_mult)) or 1
end

-- input = { base, petType, variant, shiny?, role?, context? }
function PetPowerView.profile(input)
    input = input or {}
    local power, roles, fx, pets = configs()

    local rid = roleId(roles, input.petType, input.role)
    local roleDef = (roles.roles and roles.roles[rid]) or {}
    local petDef = (pets.pets and pets.pets[input.petType]) or {}

    -- Aptitude: per-pet override wins over the role's default (config-as-code, every number a knob).
    local miningMult = tonumber(petDef.mining_mult) or tonumber(roleDef.mining_mult) or 1
    local combatMult = tonumber(petDef.combat_mult) or tonumber(roleDef.combat_mult) or 1

    local elemMult = elementMult(fx, input.petType)
    local variantMult = (power.variant_mult and power.variant_mult[input.variant])
        or power.default_variant_mult
        or 1
    -- Shiny (5th axis): cosmetic, power-neutral at shiny_mult = 1.0. Only applies if the pet is shiny.
    local shinyMult = input.shiny and (tonumber(power.shiny_mult) or 1) or 1

    return PetPower.resolveProfile({
        creator = input.creator == true, -- apex pin: resolves straight to maxPower
        base = input.base,
        baseScale = tonumber(power.base_scale) or 1,
        elementMult = elemMult,
        variantMult = variantMult,
        shinyMult = shinyMult,
        miningMult = miningMult,
        combatMult = combatMult,
        maxPower = tonumber(power.max_pet_power) or math.huge,
        context = input.context,
    }),
        rid
end

function PetPowerView.displayRound(n)
    local power = configs()
    return PetPower.roundForDisplay(n, power.display_round)
end

-- Effective HP for the inventory card's ❤ number: the RAW enemy damage a pet absorbs before it is
-- downed, off the SAME endurance ceiling (power * pet_down_threshold_factor) and armor curve
-- (defense vs armor_curve_k) the server downs it with — so displayed survivability == real.
--   `power` is the pet's resolved power (use the BASE/realized power, not the resonance-adjusted
--   display number: cross-realm resonance scales OFFENSE only, never the endurance ceiling).
-- Returns (ehp, defense, rid). Resilient: missing config -> sensible fallbacks.
function PetPowerView.survivability(power, petType, explicit)
    local _, roles, fx, _, combat = configs()
    local rid = roleId(roles, petType, explicit)
    local roleDef = (roles.roles and roles.roles[rid]) or {}
    local defense = tonumber(roleDef.defense) or 0
    local factor = tonumber(combat.pet_down_threshold_factor) or 1
    local k = tonumber(combat.armor_curve_k) or 100
    local takenMult = elementTakenMult(fx, petType)
    return PetSurvivability.effectiveHp(power, defense, factor, k, takenMult), defense, rid
end

-- Archetype chip data for a pet card / squad tooltip: resolves the role (explicit override ->
-- by_type -> default) and returns its display label + colour from pet_roles. So the inventory
-- can show "Tank / Melee / Blaster / Buffer / Control" at a glance.
function PetPowerView.roleInfo(petType, explicit)
    local _, roles = configs()
    local rid = roleId(roles, petType, explicit)
    local def = (roles.roles and roles.roles[rid]) or {}
    local c = def.color
    return {
        id = rid,
        label = def.label or rid,
        glyph = def.glyph,
        color = (type(c) == "table" and c[1] and { r = c[1], g = c[2], b = c[3] }) or nil,
    }
end

return PetPowerView
