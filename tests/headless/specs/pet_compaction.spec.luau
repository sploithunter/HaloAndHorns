--[[
    Phase 11 Release A.2: PetCompaction — collapse exploded per-uid commons into compact
    stacks (specials kept per-uid). Ownership conservation is the contract.
    Run: mise run test-headless
]]

local Compact = loadModule("src/Shared/Inventory/PetCompaction.lua")

-- Injected predicates (mirror PetInventoryView): huge => special; key = id:variant.
local OPTS = {
    isSpecial = function(rec)
        return rec.huge == true
    end,
    stackKey = function(rec)
        return tostring(rec.id) .. ":" .. tostring(rec.variant or "basic")
    end,
}

local function countStacks(items)
    local n = 0
    for key, e in pairs(items) do
        if type(e.quantity) == "number" and key == (e.id .. ":" .. (e.variant or "basic")) then
            n += 1
        end
    end
    return n
end

return function()
    describe("PetCompaction.collapse", function()
        it("folds N exploded per-uid commons into one stack with quantity=N", function()
            local items = {
                m5_b1 = { uid = "m5_b1", id = "bunny", variant = "basic", obtained_at = 5 },
                m5_b2 = { uid = "m5_b2", id = "bunny", variant = "basic", obtained_at = 3 },
                m5_b3 = { uid = "m5_b3", id = "bunny", variant = "basic", obtained_at = 9 },
            }
            local r = Compact.collapse(items, OPTS)
            expect(countStacks(r.items)).to.equal(1)
            local stack = r.items["bunny:basic"]
            expect(stack.quantity).to.equal(3)
            expect(stack.obtained_at).to.equal(3) -- earliest preserved
            expect(r.report.conserved).to.equal(true)
        end)

        it("carries per-uid equipped commons into the stack's equipped_slots", function()
            local items = {
                m5_b1 = {
                    uid = "m5_b1",
                    id = "bunny",
                    variant = "basic",
                    equipped_slot = 4,
                    obtained_at = 1,
                },
                m5_b2 = { uid = "m5_b2", id = "bunny", variant = "basic", obtained_at = 2 },
            }
            local r = Compact.collapse(items, OPTS)
            local stack = r.items["bunny:basic"]
            expect(stack.quantity).to.equal(2)
            expect(#stack.equipped_slots).to.equal(1)
            expect(stack.equipped_slots[1]).to.equal(4)
            expect(r.report.equippedBefore).to.equal(1)
            expect(r.report.equippedAfter).to.equal(1)
        end)

        it(
            "keeps specials per-uid and separate from the common stack of same id:variant",
            function()
                local items = {
                    m5_b1 = { uid = "m5_b1", id = "bear", variant = "basic", obtained_at = 1 },
                    bear_h = {
                        uid = "bear_h",
                        id = "bear",
                        variant = "basic",
                        huge = true,
                        level = 19,
                        equipped_slot = 1,
                        obtained_at = 100,
                    },
                }
                local r = Compact.collapse(items, OPTS)
                expect(r.items["bear:basic"].quantity).to.equal(1)
                expect(r.items["bear_h"]).never.to.equal(nil)
                expect(r.items["bear_h"].level).to.equal(19)
                expect(r.items["bear_h"].equipped_slot).to.equal(1)
                expect(r.items["bear_h"].quantity).to.equal(nil)
                expect(r.report.ownedBefore).to.equal(2)
                expect(r.report.ownedAfter).to.equal(2)
            end
        )

        it("is idempotent: collapsing already-compact data reproduces it", function()
            local items = {
                ["bunny:basic"] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 28,
                    equipped_slots = { 4 },
                    obtained_at = 1,
                },
                bear_h = {
                    uid = "bear_h",
                    id = "bear",
                    variant = "basic",
                    huge = true,
                    equipped_slot = 2,
                    obtained_at = 100,
                },
            }
            local r = Compact.collapse(items, OPTS)
            expect(r.items["bunny:basic"].quantity).to.equal(28)
            expect(#r.items["bunny:basic"].equipped_slots).to.equal(1)
            expect(r.items["bear_h"].equipped_slot).to.equal(2)
            expect(r.report.conserved).to.equal(true)
            -- second pass identical
            local r2 = Compact.collapse(r.items, OPTS)
            expect(r2.items["bunny:basic"].quantity).to.equal(28)
            expect(r2.report.ownedAfter).to.equal(r.report.ownedAfter)
        end)

        it("real-data shape: 145 commons + 13 specials + equipped bunny -> conserved", function()
            local items = {}
            -- exploded commons (mirroring coloradoplays counts)
            local function explode(id, variant, n)
                for i = 1, n do
                    local uid = "m5_" .. id .. "_" .. variant .. "_" .. i
                    items[uid] = { uid = uid, id = id, variant = variant, obtained_at = i }
                end
            end
            explode("bunny", "basic", 28)
            explode("doggy", "basic", 31)
            explode("bear", "golden", 2)
            explode("bunny", "golden", 4)
            explode("bear", "basic", 80)
            -- the equipped bunny (re-minted by v5), equipped at slot 4
            items["m5eq_bunny_basic_4"] = {
                uid = "m5eq_bunny_basic_4",
                id = "bunny",
                variant = "basic",
                equipped_slot = 4,
                obtained_at = 1,
            }
            -- 13 huge specials
            for i = 1, 13 do
                items["h" .. i] = {
                    uid = "h" .. i,
                    id = "bear",
                    variant = "basic",
                    huge = true,
                    level = i,
                    obtained_at = 1000 + i,
                }
            end
            -- equip 3 specials
            items.h1.equipped_slot = 1
            items.h2.equipped_slot = 2
            items.h3.equipped_slot = 3

            local r = Compact.collapse(items, OPTS)
            expect(r.report.ownedBefore).to.equal(159)
            expect(r.report.ownedAfter).to.equal(159)
            expect(r.report.conserved).to.equal(true)
            expect(countStacks(r.items)).to.equal(5) -- 5 common kinds
            expect(r.items["bunny:basic"].quantity).to.equal(29) -- 28 + 1 equipped
            expect(#r.items["bunny:basic"].equipped_slots).to.equal(1)
        end)
    end)
end
