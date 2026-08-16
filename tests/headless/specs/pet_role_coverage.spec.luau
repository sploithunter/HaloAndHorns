--[[
    pet_role_coverage — every pets.lua species MUST have an explicit
    pet_roles.by_type row (Jason 2026-07-13: snowfox shipped unmapped, fell to
    the silent melee default with a nil PetRole attribute, and squad behavior
    went inconsistent live). Loud in CI, per the loud-validation rule.
]]

local petsConfig = loadModule("configs/pets.lua")
local rolesConfig = loadModule("configs/pet_roles.lua")
local PetAbility = loadModule("src/Shared/Game/PetAbility.lua")

describe("pet role coverage", function()
    it("maps every species in pets.lua", function()
        local missing = {}
        for id in pairs(petsConfig.pets or {}) do
            if (rolesConfig.by_type or {})[id] == nil then
                table.insert(missing, id)
            end
        end
        table.sort(missing)
        expect(table.concat(missing, ", ")).to.equal("")
    end)

    it("gives every archetype readable badge copy", function()
        local missing = {}
        for roleId, role in pairs(rolesConfig.roles or {}) do
            if
                type(role.label) ~= "string"
                or role.label == ""
                or type(role.tooltip) ~= "string"
                or role.tooltip == ""
            then
                table.insert(missing, roleId)
            end
        end
        table.sort(missing)
        expect(table.concat(missing, ", ")).to.equal("")
    end)

    it("gives every controller a real designated control power", function()
        local missing = {}
        local allowed = { slow = true, root = true, hold = true }
        for petType, role in pairs(rolesConfig.by_type or {}) do
            if role == "control" then
                local hasControl = false
                for _, ability in ipairs(PetAbility.forPet(petType, rolesConfig, petsConfig)) do
                    if allowed[ability.kind] then
                        hasControl = true
                        break
                    end
                end
                if not hasControl then
                    table.insert(missing, petType)
                end
            end
        end
        table.sort(missing)
        expect(table.concat(missing, ", ")).to.equal("")
    end)

    it("gives every support pet at least one implemented aura", function()
        local missing = {}
        for petType, role in pairs(rolesConfig.by_type or {}) do
            if role == "support" and (rolesConfig.support_auras or {})[petType] == nil then
                table.insert(missing, petType)
            end
        end
        table.sort(missing)
        expect(table.concat(missing, ", ")).to.equal("")
    end)

    it("keeps the authored layer-one support line classified and powered", function()
        local expected = {
            radiant_salamander = "offense",
            brimstone_salamander = "curse",
            bloomlamb = "heal",
            blightlamb = "drain",
            verdant_sprite = "yield",
            wither_sprite = "curse",
        }
        for petType, abilityKind in pairs(expected) do
            expect(rolesConfig.by_type[petType]).to.equal("support")
            expect(rolesConfig.support_auras[petType].kind).to.equal(abilityKind)
        end
    end)

    it("keeps the Leviathan and ice-Dragon control hybrids mechanical and visible", function()
        for _, petType in ipairs({
            "aurora_leviathan",
            "black_ice_leviathan",
            "aurora_dragon",
            "rimewraith_dragon",
        }) do
            local abilities = PetAbility.forPet(petType, rolesConfig, petsConfig)
            expect(#abilities).to.equal(1)
            expect(abilities[1].source).to.equal("attack_control")
            expect(abilities[1].kind == "slow" or abilities[1].kind == "root").to.equal(true)
        end
        expect(rolesConfig.by_type.aurora_leviathan).to.equal("tank")
        expect(rolesConfig.by_type.black_ice_leviathan).to.equal("tank")
        expect(rolesConfig.by_type.aurora_dragon).to.equal("melee")
        expect(rolesConfig.by_type.rimewraith_dragon).to.equal("melee")
    end)

    it("keeps the authored Ice fox line in the controller archetype", function()
        for _, petType in ipairs({
            "snowfox",
            "aurora_fox",
            "rimewraith_fox",
            "prism_fox",
            "dread_fox",
        }) do
            expect(rolesConfig.by_type[petType]).to.equal("control")
        end
    end)
end)
