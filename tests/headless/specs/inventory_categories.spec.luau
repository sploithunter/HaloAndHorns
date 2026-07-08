--[[
    Inventory category tabs — [unit]. Written after the live 2026-07-08 regression where
    the Enhancements/Items/Eggs/Tools tabs vanished despite hundreds of owned items
    (visibility was computed once from pre-load all-zero counts, masked by a debug
    force-show). These pin the CONTRACT: a populated category always yields a tab.
    Run: mise run test-headless
]]

local InventoryCategories = loadModule("src/Shared/Game/InventoryCategories.lua")
local inventoryConfig = loadModule("configs/inventory.lua")

local HIDE_EMPTY = { hide_empty_categories = true }

local function names(visibleList)
    local out = {}
    for _, entry in ipairs(visibleList) do
        out[entry.config.name] = entry.count
    end
    return out
end

return function()
    describe("InventoryCategories.visible", function()
        it("a POPULATED category always produces a tab (the live regression)", function()
            local visible = InventoryCategories.visible(inventoryConfig.display_categories, {
                pets = 64,
                enhancements = 432,
            }, HIDE_EMPTY)
            local byName = names(visible)
            expect(byName["Enhancements"]).to.equal(432)
            expect(byName["Pets"]).to.equal(64)
        end)

        it("empty non-always categories hide when hide_empty_categories is on", function()
            local visible = InventoryCategories.visible(
                inventoryConfig.display_categories,
                { pets = 3 },
                HIDE_EMPTY
            )
            expect(names(visible)["Eggs"]).to.equal(nil)
        end)

        it("always_visible categories show even at zero items", function()
            local visible =
                InventoryCategories.visible(inventoryConfig.display_categories, {}, HIDE_EMPTY)
            local byName = names(visible)
            expect(byName["All"]).to.be.ok()
            expect(byName["Pets"]).to.be.ok()
        end)

        it("hiding disabled -> every configured category gets a tab", function()
            local visible = InventoryCategories.visible(
                inventoryConfig.display_categories,
                {},
                { hide_empty_categories = false }
            )
            expect(#visible).to.equal(#inventoryConfig.display_categories)
        end)

        it(
            "counts sum across a category's multiple folders (Items = consumables + potions)",
            function()
                local visible = InventoryCategories.visible(inventoryConfig.display_categories, {
                    consumables = 2,
                    potions = 5,
                }, HIDE_EMPTY)
                expect(names(visible)["Items"]).to.equal(7)
            end
        )
    end)
end
