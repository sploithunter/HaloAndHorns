-- Every authored support aura must have one config-owned inventory badge. This catches the exact
-- failure where Ashwing/Lumen Dove powers worked but their newer aura kinds rendered no badge.

local rolesConfig = loadModule("configs/pet_roles.lua")
local iconsConfig = loadModule("configs/power_icons.lua")

local function auraList(entry)
    if type(entry) ~= "table" then
        return {}
    end
    return entry.kind and { entry } or entry
end

describe("support badge coverage", function()
    it(
        "defines a label, tooltip, symbol, and renderable disc for every support aura kind",
        function()
            local missing = {}
            for petType, entry in pairs(rolesConfig.support_auras or {}) do
                for _, aura in ipairs(auraList(entry)) do
                    local badge = (iconsConfig.support_badge or {})[aura.kind]
                    if
                        type(badge) ~= "table"
                        or type(badge.label) ~= "string"
                        or badge.label == ""
                        or type(badge.symbol) ~= "string"
                        or badge.symbol == ""
                        or type(badge.tooltip) ~= "string"
                        or badge.tooltip == ""
                        or iconsConfig.discFor("exclusive", badge.symbol) == nil
                    then
                        table.insert(missing, petType .. ":" .. tostring(aura.kind))
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
