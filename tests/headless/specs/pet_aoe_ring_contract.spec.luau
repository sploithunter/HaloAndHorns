local pets = loadModule("configs/pets.lua")
local roles = loadModule("configs/pet_roles.lua")
local icons = loadModule("configs/power_icons.lua")
local PetAbility = loadModule("src/Shared/Game/PetAbility.lua")
local PetAbilityRuntime = loadModule("src/Shared/Game/PetAbilityRuntime.lua")
local PetTargeting = loadModule("src/Shared/Game/PetTargeting.lua")

local function roleFor(petId)
    return (roles.by_type and roles.by_type[petId]) or roles.default
end

local function displayScope(petId, variant, huge)
    local def = pets.pets[petId]
    return PetTargeting.displayAttackScope(def, roleFor(petId), roles, {
        huge = huge == true,
        hasAreaProc = PetAbilityRuntime.hasAreaDamage(pets, petId, variant),
    })
end

describe("pet AoE ring contract", function()
    it("gives every real periodic AoE variant an area ring", function()
        local mismatches = {}
        for petId, pet in pairs(pets.pets or {}) do
            for variant in pairs(pet.variants or {}) do
                if
                    PetAbilityRuntime.hasAreaDamage(pets, petId, variant)
                    and not PetTargeting.isArea(displayScope(petId, variant, false))
                then
                    table.insert(mismatches, petId .. ":" .. variant)
                end
            end
        end
        table.sort(mismatches)
        expect(table.concat(mismatches, ", ")).to.equal("")
    end)

    it("gives every Huge an area ring and a configured ring asset", function()
        local mismatches = {}
        for petId in pairs(pets.pets or {}) do
            local scope = displayScope(petId, "basic", true)
            if not PetTargeting.isArea(scope) or not icons.targeting_ring[scope] then
                table.insert(mismatches, petId .. ":" .. tostring(scope))
            end
        end
        table.sort(mismatches)
        expect(table.concat(mismatches, ", ")).to.equal("")
    end)

    it("makes every on-hit control ring match the attack capability that carries it", function()
        local mismatches = {}
        for petId, pet in pairs(pets.pets or {}) do
            if pet.attack_control then
                for variant in pairs(pet.variants or {}) do
                    local scope = displayScope(petId, variant, false)
                    local abilities = PetAbility.forPet(petId, roles, pets, {
                        attackScope = scope,
                    })
                    for _, ability in ipairs(abilities) do
                        if ability.source == "attack_control" then
                            local abilityScope = PetTargeting.auraScope(ability, roles)
                            if abilityScope ~= scope or not icons.targeting_ring[abilityScope] then
                                table.insert(
                                    mismatches,
                                    petId .. ":" .. variant .. ":" .. tostring(abilityScope)
                                )
                            end
                        end
                    end
                end
            end
        end
        table.sort(mismatches)
        expect(table.concat(mismatches, ", ")).to.equal("")
    end)

    it("keeps the authored showcase cases mechanically and visually explicit", function()
        expect(displayScope("aurora_dragon", "basic", false)).to.equal("targeted_aoe")
        expect(displayScope("rimewraith_dragon", "basic", false)).to.equal("targeted_aoe")
        expect(displayScope("colorado_creator", "basic", false)).to.equal("targeted_aoe")
        expect(displayScope("bear", "basic", false)).to.equal("single")
        expect(displayScope("bear", "basic", true)).to.equal("aura")
    end)
end)
