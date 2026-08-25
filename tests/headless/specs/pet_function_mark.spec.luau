--[[
    PetFunctionMark — heal / armor / debuff chips, config-owned colours.
    Run: mise run test-headless
]]

local rolesConfig = loadModule("configs/pet_roles.lua")
local petsConfig = loadModule("configs/pets.lua")
local iconsConfig = loadModule("configs/power_icons.lua")
local PetFunctionMark = loadModule("src/Shared/Game/PetFunctionMark.lua")

local ICONS = {
    function_mark = {
        groups = {
            heal = { symbol = "plus", element = "earth", color = { 70, 205, 95 }, label = "Heal" },
            antiheal = {
                symbol = "plus_down",
                element = "fire",
                color = { 255, 82, 89 },
                label = "Heal Block",
            },
            armor = {
                symbol = "armor_chest",
                element = "ice",
                color = { 81, 136, 255 },
                label = "Armor",
            },
            debuff = {
                symbol = "shield_broken",
                element = "fire",
                color = { 255, 82, 89 },
                label = "Debuff",
            },
        },
        by_kind = {
            heal = "heal",
            drain = "antiheal",
            antiheal = "antiheal",
            defense = "armor",
            shred = "debuff",
            curse = "debuff",
        },
        priority = { "antiheal", "heal", "armor", "debuff" },
    },
}

describe("PetFunctionMark", function()
    it("maps heal green and drain to the red heal-block group", function()
        local heal = PetFunctionMark.forKind("heal", ICONS)
        local drain = PetFunctionMark.forKind("drain", ICONS)
        expect(heal.group).to.equal("heal")
        expect(heal.element).to.equal("earth")
        expect(heal.symbol).to.equal("plus")
        expect(drain.group).to.equal("antiheal")
        expect(drain.element).to.equal("fire")
        expect(drain.symbol).to.equal("plus_down")
    end)

    it("maps defense to armor and shred/curse to one debuff chip", function()
        expect(PetFunctionMark.forKind("defense", ICONS).group).to.equal("armor")
        expect(PetFunctionMark.forKind("shred", ICONS).group).to.equal("debuff")
        expect(PetFunctionMark.forKind("curse", ICONS).group).to.equal("debuff")
        expect(PetFunctionMark.forKind("luck", ICONS)).to.equal(nil)
    end)

    it("prefers heal over armor when a pet carries both", function()
        local mark = PetFunctionMark.forAbilities({
            { kind = "luck" },
            { kind = "defense" },
            { kind = "heal" },
        }, ICONS)
        expect(mark.group).to.equal("heal")
    end)

    it("resolves live pets from pet_roles", function()
        expect(PetFunctionMark.forPet("guide_moth", rolesConfig, petsConfig, iconsConfig).group).to.equal(
            "heal"
        )
        expect(PetFunctionMark.forPet("penguin", rolesConfig, petsConfig, iconsConfig).group).to.equal(
            "armor"
        )
        expect(
            PetFunctionMark.forPet("brimstone_salamander", rolesConfig, petsConfig, iconsConfig).group
        ).to.equal("debuff")
        expect(PetFunctionMark.forPet("doggy", rolesConfig, petsConfig, iconsConfig)).to.equal(nil)
    end)

    it("treats enemy auto_heal as a healer", function()
        local mark =
            PetFunctionMark.forEnemyDef({ auto_heal = { interval = 2, amount = 80 } }, ICONS)
        expect(mark.group).to.equal("heal")
        expect(PetFunctionMark.forEnemyDef({ role = "support" }, ICONS)).to.equal(nil)
    end)

    it("uses the function element for mapped kinds and the fallback otherwise", function()
        expect(PetFunctionMark.badgeElement("heal", "exclusive", ICONS)).to.equal("earth")
        expect(PetFunctionMark.badgeElement("luck", "exclusive", ICONS)).to.equal("exclusive")
    end)
end)

describe("power_icons.function_mark", function()
    it("owns a renderable disc for every mapped group", function()
        local missing = {}
        for group, spec in pairs(iconsConfig.function_mark.groups) do
            if iconsConfig.discFor(spec.element, spec.symbol) == nil then
                table.insert(
                    missing,
                    group .. ":" .. tostring(spec.element) .. "/" .. tostring(spec.symbol)
                )
            end
        end
        table.sort(missing)
        expect(table.concat(missing, ", ")).to.equal("")
    end)

    it("maps every authored heal/armor/debuff aura kind", function()
        local missing = {}
        for petType in pairs(petsConfig.pets or {}) do
            local mark = PetFunctionMark.forPet(petType, rolesConfig, petsConfig, iconsConfig)
            local auras = rolesConfig.support_auras and rolesConfig.support_auras[petType]
            local list = type(auras) == "table" and (auras.kind and { auras } or auras) or {}
            for _, aura in ipairs(list) do
                local kind = aura.kind
                if
                    kind == "heal"
                    or kind == "drain"
                    or kind == "antiheal"
                    or kind == "defense"
                    or kind == "shred"
                    or kind == "curse"
                then
                    if not mark then
                        table.insert(missing, petType .. ":" .. tostring(kind))
                    end
                end
            end
        end
        table.sort(missing)
        expect(table.concat(missing, ", ")).to.equal("")
    end)
end)
