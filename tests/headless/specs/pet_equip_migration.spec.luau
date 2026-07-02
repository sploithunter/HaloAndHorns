--[[
    Phase 11 Release A.3: PetEquipMigration — lift inline record equip (v6) into a separate
    Equipped table (v7). Run: mise run test-headless
]]

local Extract = loadModule("src/Shared/Inventory/PetEquipMigration.lua")

return function()
    describe("PetEquipMigration.extractToEquipped", function()
        it("lifts a special's equipped_slot into Equipped.pets as a bare uid", function()
            local items = {
                bear_h = {
                    uid = "bear_h",
                    id = "bear",
                    variant = "basic",
                    huge = true,
                    equipped_slot = 2,
                },
            }
            local equipped, report = Extract.extractToEquipped(items)
            expect(equipped["slot_2"]).to.equal("bear_h")
            expect(report.refsExtracted).to.equal(1)
        end)

        it("lifts a common stack's equipped_slots into stack| refs", function()
            local items = {
                ["bunny:basic"] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 5,
                    equipped_slots = { 1, 4 },
                },
            }
            local equipped = Extract.extractToEquipped(items)
            expect(equipped["slot_1"]).to.equal("stack|bunny:basic")
            expect(equipped["slot_4"]).to.equal("stack|bunny:basic")
        end)

        it("keeps the first claimant on a slot collision (ownership untouched)", function()
            local items = {
                bear_h = {
                    uid = "bear_h",
                    id = "bear",
                    variant = "basic",
                    huge = true,
                    equipped_slot = 1,
                },
                ["bunny:basic"] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 2,
                    equipped_slots = { 1 },
                },
            }
            local equipped, report = Extract.extractToEquipped(items)
            -- "bear_h" sorts before "bunny:basic", so the special wins slot_1
            expect(equipped["slot_1"]).to.equal("bear_h")
            expect(report.refsOnRecords).to.equal(2)
            expect(report.refsExtracted).to.equal(1)
        end)

        it("real-data shape: 4 equipped commons + 0 here -> 4 refs lifted", function()
            local items = {
                ["bear:basic"] = {
                    id = "bear",
                    variant = "basic",
                    quantity = 80,
                    equipped_slots = { 1 },
                },
                ["bear:golden"] = {
                    id = "bear",
                    variant = "golden",
                    quantity = 2,
                    equipped_slots = { 2 },
                },
                ["doggy:basic"] = {
                    id = "doggy",
                    variant = "basic",
                    quantity = 31,
                    equipped_slots = { 3 },
                },
                ["bunny:basic"] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 29,
                    equipped_slots = { 4 },
                },
            }
            local equipped, report = Extract.extractToEquipped(items)
            expect(report.refsExtracted).to.equal(4)
            expect(equipped["slot_1"]).to.equal("stack|bear:basic")
            expect(equipped["slot_4"]).to.equal("stack|bunny:basic")
        end)
    end)
end
