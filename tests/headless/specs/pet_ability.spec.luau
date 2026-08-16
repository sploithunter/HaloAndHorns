local PetAbility = loadModule("src/Shared/Game/PetAbility.lua")

describe("PetAbility", function()
    local roles = {
        support_auras = {
            healer = { kind = "heal", fraction = 0.1 },
            creator = {
                { kind = "heal" },
                { kind = "luck" },
            },
        },
    }
    local pets = {
        pets = {
            dragon = {
                attack_targeting = "targeted_aoe",
                attack_control = { kind = "root", duration = 2 },
            },
        },
    }

    it("returns support auras without mutating config", function()
        local abilities = PetAbility.forPet("healer", roles, pets)
        expect(#abilities).to.equal(1)
        expect(abilities[1].kind).to.equal("heal")
        expect(abilities[1].source).to.equal("aura")
        expect(roles.support_auras.healer.source).to.equal(nil)
    end)

    it("keeps every aura on a multi-power pet", function()
        local abilities = PetAbility.forPet("creator", roles, pets)
        expect(#abilities).to.equal(2)
        expect(abilities[1].kind).to.equal("heal")
        expect(abilities[2].kind).to.equal("luck")
    end)

    it("exposes real on-hit control using its attack geometry", function()
        local abilities = PetAbility.forPet("dragon", roles, pets)
        expect(#abilities).to.equal(1)
        expect(abilities[1].kind).to.equal("root")
        expect(abilities[1].source).to.equal("attack_control")
        expect(abilities[1].targeting).to.equal("targeted_aoe")
    end)

    it("accepts the effective Huge/proc attack scope for an on-hit control ring", function()
        local abilities = PetAbility.forPet("dragon", roles, pets, {
            attackScope = "aura",
        })
        expect(abilities[1].targeting).to.equal("aura")
    end)

    it("returns an empty list for unknown pets", function()
        expect(#PetAbility.forPet("unknown", roles, pets)).to.equal(0)
        expect(#PetAbility.forPet(nil, roles, pets)).to.equal(0)
    end)
end)
