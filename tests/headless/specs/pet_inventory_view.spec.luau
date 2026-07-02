--[[
    Phase 11: PetInventoryView — pure projection authority (separated model):
      OWNERSHIP in items:  common stack { id, variant, quantity }  (key = id:variant)
                           special      { uid, id, variant, ... }   (key = uid)
      EQUIP in a separate Equipped table: slot -> ref ("<uid>" | "stack|id:variant").
    Live equipped = Equipped ∩ inventory (resolveEquipped), validated + capped by quantity.
    Run: mise run test-headless
]]

local View = loadModule("src/Shared/Inventory/PetInventoryView.lua")

local CONFIG = { stack_key_fields = { "id", "variant" }, count_stacks_as_single = true }
local CAP = { specialRarities = { huge = true, secret = true } }

local function map(t)
    return t
end

return function()
    describe("PetInventoryView.isStackEntry", function()
        it("true for an entry keyed by id:variant, false for a uid record", function()
            local items = {
                ["bear:basic"] = { id = "bear", variant = "basic", quantity = 5 },
                u1 = { uid = "u1", id = "bear" },
            }
            expect(View.isStackEntry(items["bear:basic"], "bear:basic")).to.equal(true)
            expect(View.isStackEntry(items.u1, "u1")).to.equal(false)
        end)
    end)

    describe("PetInventoryView.parseRef", function()
        it("decodes special (bare uid / special|uid) and common (stack|key)", function()
            expect(View.parseRef("bear_1_a").kind).to.equal("special")
            expect(View.parseRef("bear_1_a").uid).to.equal("bear_1_a")
            expect(View.parseRef("special|h9").uid).to.equal("h9")
            local s = View.parseRef("stack|bear:basic")
            expect(s.kind).to.equal("stack")
            expect(s.stackKey).to.equal("bear:basic")
        end)
    end)

    describe("PetInventoryView.normalize (records are pure ownership)", function()
        it("strips equip fields off records", function()
            local m = map({
                ["bear:basic"] = {
                    id = "bear",
                    variant = "basic",
                    quantity = 3,
                    equipped_slots = { 1 },
                    uid = "x",
                    _kind = "stack",
                },
                u1 = {
                    id = "bear",
                    variant = "basic",
                    huge = true,
                    equipped_slot = 2,
                    quantity = 1,
                },
            })
            View.normalize(m)
            expect(m["bear:basic"].quantity).to.equal(3)
            expect(m["bear:basic"].equipped_slots).to.equal(nil)
            expect(m["bear:basic"].uid).to.equal(nil)
            expect(m.u1.uid).to.equal("u1")
            expect(m.u1.equipped_slot).to.equal(nil)
            expect(m.u1.quantity).to.equal(nil)
        end)
    end)

    describe("PetInventoryView.resolveEquipped (validated Equipped ∩ inventory)", function()
        local items = map({
            ["bunny:basic"] = { id = "bunny", variant = "basic", quantity = 2 },
            h1 = { uid = "h1", id = "bear", variant = "basic", huge = true },
        })
        it("maps valid special + common slots", function()
            local equipped = { slot_1 = "h1", slot_2 = "stack|bunny:basic" }
            local slotMap, byKey = View.resolveEquipped(items, equipped, 6)
            expect(slotMap[1].kind).to.equal("special")
            expect(slotMap[1].uid).to.equal("h1")
            expect(slotMap[2].kind).to.equal("stack")
            expect(byKey["uid:h1"]).to.equal(1)
            expect(byKey["bunny:basic"]).to.equal(1)
        end)
        it("caps a common kind at its quantity (extra slot ignored)", function()
            local equipped = {
                slot_1 = "stack|bunny:basic",
                slot_2 = "stack|bunny:basic",
                slot_3 = "stack|bunny:basic",
            }
            local slotMap, byKey = View.resolveEquipped(items, equipped, 6)
            expect(byKey["bunny:basic"]).to.equal(2) -- only 2 owned
            expect(slotMap[1]).never.to.equal(nil)
            expect(slotMap[2]).never.to.equal(nil)
            expect(slotMap[3]).to.equal(nil) -- over cap, ignored (no phantom)
        end)
        it("ignores a dangling special ref (pet no longer owned)", function()
            local equipped = { slot_1 = "ghost_gone", slot_2 = "h1" }
            local slotMap = View.resolveEquipped(items, equipped, 6)
            expect(slotMap[1]).to.equal(nil) -- dangling -> ignored
            expect(slotMap[2].uid).to.equal("h1")
        end)
        it("ignores slots beyond maxSlots", function()
            local slotMap = View.resolveEquipped(items, { slot_9 = "h1" }, 6)
            expect(slotMap[9]).to.equal(nil)
        end)
    end)

    describe("PetInventoryView.groups (ownership + equipped overlay)", function()
        local items = map({
            ["bear:basic"] = { id = "bear", variant = "basic", quantity = 80, obtained_at = 5 },
            ["bunny:basic"] = { id = "bunny", variant = "basic", quantity = 29, obtained_at = 1 },
            h1 = { uid = "h1", id = "bear", variant = "basic", huge = true, obtained_at = 1000 },
            h2 = { uid = "h2", id = "bear", variant = "basic", huge = true, obtained_at = 1001 },
        })
        it("huge specials never merge into the common stack of same id:variant", function()
            local g = View.groups(items, CONFIG, CAP)
            expect(#g).to.equal(4) -- bear:basic + bunny:basic + h1 + h2
            local common
            for _, grp in ipairs(g) do
                if grp.key == "bear:basic" then
                    common = grp
                end
            end
            expect(common.total).to.equal(80)
            expect(common.isSpecial).to.equal(false)
        end)
        it("overlays equipped/unequipped from equippedByKey", function()
            local _, byKey =
                View.resolveEquipped(items, { slot_1 = "h1", slot_2 = "stack|bunny:basic" }, 6)
            local g = View.groups(items, CONFIG, CAP, byKey)
            local bunny, hugeH1
            for _, grp in ipairs(g) do
                if grp.key == "bunny:basic" then
                    bunny = grp
                elseif grp.key == "uid:h1" then
                    hugeH1 = grp
                end
            end
            expect(bunny.total).to.equal(29)
            expect(bunny.equippedCount).to.equal(1)
            expect(bunny.unequippedCount).to.equal(28)
            expect(hugeH1.equippedCount).to.equal(1)
        end)
    end)

    describe("PetInventoryView.usedSlots / categoryCounts", function()
        local items = map({
            ["bear:basic"] = { id = "bear", variant = "basic", quantity = 80 },
            ["bunny:basic"] = { id = "bunny", variant = "basic", quantity = 29 },
            h1 = { uid = "h1", id = "bear", variant = "basic", huge = true },
        })
        it("usedSlots = #stack kinds + #specials", function()
            expect(View.usedSlots(items, CONFIG, CAP)).to.equal(3)
        end)
        it("categoryCounts: display groups vs total instances", function()
            local c = View.categoryCounts(items, CONFIG, CAP)
            expect(c.display).to.equal(3)
            expect(c.total).to.equal(110) -- 80 + 29 + 1
        end)
    end)

    describe("PetInventoryView capability gating", function()
        it("huge / special-rarity levelable+enchantable; plain commons not", function()
            expect(View.isLevelable({ id = "bear", variant = "basic", huge = true }, CAP)).to.equal(
                true
            )
            expect(
                View.isEnchantable({ id = "bear", variant = "basic", rarity_id = "secret" }, CAP)
            ).to.equal(true)
            expect(View.isLevelable({ id = "bear", variant = "basic", rarity_id = "common" }, CAP)).to.equal(
                false
            )
            expect(View.isEnchantable({ id = "bear", variant = "basic" }, { allowAll = true })).to.equal(
                true
            )
        end)
    end)
end
