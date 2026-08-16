-- Every authored support aura must have one config-owned inventory badge. This catches the exact
-- failure where Ashwing/Lumen Dove powers worked but their newer aura kinds rendered no badge.

local rolesConfig = loadModule("configs/pet_roles.lua")
local petsConfig = loadModule("configs/pets.lua")
local iconsConfig = loadModule("configs/power_icons.lua")
local combatFxConfig = loadModule("configs/combat_fx.lua")
local PetAbility = loadModule("src/Shared/Game/PetAbility.lua")

describe("support badge coverage", function()
    it(
        "defines a label, tooltip, symbol, and renderable disc for every support aura kind",
        function()
            local missing = {}
            for petType in pairs(petsConfig.pets or {}) do
                for _, ability in ipairs(PetAbility.forPet(petType, rolesConfig, petsConfig)) do
                    local badge = (iconsConfig.support_badge or {})[ability.kind]
                    local origin = combatFxConfig.origin or {}
                    local badgeElement = (origin.badge_element or {})[petType]
                        or (origin.pettype_element or {})[petType]
                        or "neutral"
                    if
                        type(badge) ~= "table"
                        or type(badge.label) ~= "string"
                        or badge.label == ""
                        or type(badge.symbol) ~= "string"
                        or badge.symbol == ""
                        or type(badge.tooltip) ~= "string"
                        or badge.tooltip == ""
                        or iconsConfig.discFor(badgeElement, badge.symbol) == nil
                    then
                        table.insert(missing, petType .. ":" .. tostring(ability.kind))
                    end
                end
            end
            table.sort(missing)
            expect(table.concat(missing, ", ")).to.equal("")
        end
    )

    it("keeps the two boss-egg support identities explicit", function()
        local ashwing = iconsConfig.support_badge[rolesConfig.support_auras.ashwing.kind]
        local dove = iconsConfig.support_badge[rolesConfig.support_auras.lumen_dove.kind]
        expect(ashwing.label).to.equal("Recharge")
        expect(ashwing.symbol).to.equal("history")
        expect(dove.label).to.equal("Focus Regen")
        expect(dove.symbol).to.equal("focus_regen")
    end)
end)
