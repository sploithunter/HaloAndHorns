--[[
    The HUGE GUARD — Admin pet reset must NEVER wipe a huge/special. Pure PetInventoryView.keepProtected.
    Run: mise run test-headless
]]

local PetInventoryView = loadModule("src/Shared/Inventory/PetInventoryView.lua")

return function()
    local capability = { specialRarities = { secret = true, exclusive = true } }

    describe("PetInventoryView.keepProtected (huge guard)", function()
        it("keeps huges + exclusives + per-uid uniques, drops only common stacks", function()
            local items = {
                ["bear:basic"] = { id = "bear", variant = "basic", quantity = 15 }, -- common stack
                ["dragon:fire"] = { id = "dragon", variant = "fire", quantity = 3 }, -- common stack
                ["uid_huge_1"] = { uid = "uid_huge_1", id = "bear", huge = true, level = 50 }, -- HUGE
                ["uid_excl_1"] = { uid = "uid_excl_1", id = "cat", rarity_id = "exclusive" }, -- exclusive
                ["uid_plain_1"] = { uid = "uid_plain_1", id = "dog" }, -- per-uid unique (no quantity)
            }
            local kept, removed = PetInventoryView.keepProtected(items, capability)
            expect(removed).to.equal(2) -- the two common stacks
            expect(kept["uid_huge_1"]).never.to.equal(nil)
            expect(kept["uid_excl_1"]).never.to.equal(nil)
            expect(kept["uid_plain_1"]).never.to.equal(nil)
            expect(kept["bear:basic"]).to.equal(nil)
            expect(kept["dragon:fire"]).to.equal(nil)
        end)

        it(
            "a huge survives even if its rarity is NOT in the special set (huge flag wins)",
            function()
                local items = {
                    ["uid_h"] = { uid = "uid_h", id = "bear", variant = "basic", huge = true },
                }
                -- capability with NO special rarities at all
                local kept = PetInventoryView.keepProtected(items, { specialRarities = {} })
                expect(kept["uid_h"]).never.to.equal(nil)
            end
        )

        it("empty / nil items is safe", function()
            local kept, removed = PetInventoryView.keepProtected(nil, capability)
            expect(next(kept)).to.equal(nil)
            expect(removed).to.equal(0)
        end)
    end)
end
