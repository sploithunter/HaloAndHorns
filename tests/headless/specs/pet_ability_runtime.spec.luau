local PetAbilityRuntime = loadModule("src/Shared/Game/PetAbilityRuntime.lua")
local pets = loadModule("configs/pets.lua")
local roles = loadModule("configs/pet_roles.lua")
local combatFx = loadModule("configs/combat_fx.lua")

return function()
    describe("configured pet abilities are runtime behavior", function()
        it("has an executor field for every authored ability property", function()
            local supported = PetAbilityRuntime.supportedFields()
            local missing = {}
            for abilityId, effect in pairs(pets.abilities) do
                for field in pairs(effect) do
                    if not supported[field] and pets.abilities[field] == nil then
                        table.insert(missing, abilityId .. "." .. field)
                    end
                end
            end
            table.sort(missing)
            expect(table.concat(missing, ", ")).to.equal("")
        end)

        it("resolves every authored variant ability id", function()
            local unresolved = {}
            for petId, pet in pairs(pets.pets) do
                for variant, def in pairs(pet.variants or {}) do
                    local profile = PetAbilityRuntime.resolve(pets, petId, variant)
                    if #(profile.ids or {}) ~= #(def.abilities or {}) then
                        table.insert(unresolved, petId .. ":" .. variant)
                    end
                end
            end
            table.sort(unresolved)
            expect(table.concat(unresolved, ", ")).to.equal("")
        end)

        it("fires cooldown damage abilities and inherits named traits", function()
            local profile = PetAbilityRuntime.resolve(pets, "dragon", "rainbow")
            local proc, timers = PetAbilityRuntime.activate(profile, {}, 10)
            expect(proc.damage_multiplier).to.equal(5)
            expect(proc.area_damage).to.equal(true)
            expect(proc.damage_over_time).to.equal(true)
            expect(proc.armor_ignore).to.equal(0.5)
            expect(profile.passive.can_fly).to.equal(true)

            local blocked = PetAbilityRuntime.activate(profile, timers, 11)
            expect(blocked).to.equal(nil)
        end)

        it("reports whether a variant has a real area-damage proc", function()
            expect(PetAbilityRuntime.hasAreaDamage(pets, "dragon", "basic")).to.equal(true)
            expect(PetAbilityRuntime.hasAreaDamage(pets, "dragon", "golden")).to.equal(true)
            expect(PetAbilityRuntime.hasAreaDamage(pets, "dragon", "rainbow")).to.equal(true)
            expect(PetAbilityRuntime.hasAreaDamage(pets, "bunny", "basic")).to.equal(false)
        end)
    end)

    describe("Kade identity", function()
        it("is the Grass tank with heal and luck support", function()
            expect(pets.pets.kade.origin).to.equal("grass")
            expect(roles.by_type.kade).to.equal("tank")
            expect(combatFx.origin.pettype_element.kade).to.equal("grass")
            expect(roles.support_auras.kade[1].kind).to.equal("heal")
            expect(roles.support_auras.kade[2].kind).to.equal("luck")
        end)
    end)
end
