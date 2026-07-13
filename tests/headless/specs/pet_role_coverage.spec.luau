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
end)
