--[[
    pet_role_coverage — every pets.lua species MUST have an explicit
    pet_roles.by_type row (Jason 2026-07-13: snowfox shipped unmapped, fell to
    the silent melee default with a nil PetRole attribute, and squad behavior
    went inconsistent live). Loud in CI, per the loud-validation rule.
]]

local petsConfig = loadModule("configs/pets.lua")
local rolesConfig = loadModule("configs/pet_roles.lua")

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
                local entry = (rolesConfig.support_auras or {})[petType]
                local auras = type(entry) == "table" and (entry.kind and { entry } or entry) or {}
                local hasControl = false
                for _, aura in ipairs(auras) do
                    if allowed[aura.kind] then
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
