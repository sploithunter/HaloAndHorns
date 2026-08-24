--[[
    Combat-training loaned squad: three of each starter common, mix-and-match.
]]

local TutorialSquad = loadModule("src/Shared/Game/TutorialSquad.lua")
local cfg = loadModule("configs/combat_tutorial.lua")

return function()
    describe("TutorialSquad loaned overlay", function()
        it("grants three of each starter common from combat_tutorial config", function()
            local rows = TutorialSquad.grantRows(cfg)
            expect(#rows).to.equal(4)
            local seen = {}
            for _, row in ipairs(rows) do
                seen[row.pet] = row
                expect(row.variant).to.equal("basic")
                expect(row.count).to.equal(3)
                expect(row.stackKey).to.equal(TutorialSquad.stackKey(row.pet, "basic"))
            end
            expect(seen.bunny).to.be.ok()
            expect(seen.doggy).to.be.ok()
            expect(seen.bear).to.be.ok()
            expect(seen.kitty).to.be.ok()
        end)

        it("defaults a 3-slot squad to one of each first species", function()
            local refs = TutorialSquad.defaultRefs(TutorialSquad.grantRows(cfg), 3)
            expect(#refs).to.equal(3)
            expect(refs[1]).to.equal("stack|" .. TutorialSquad.stackKey("bunny", "basic"))
            expect(refs[2]).to.equal("stack|" .. TutorialSquad.stackKey("doggy", "basic"))
            expect(refs[3]).to.equal("stack|" .. TutorialSquad.stackKey("bear", "basic"))
        end)

        it("starts combat training on three doggies from loaned_squad.equip", function()
            expect(cfg.loaned_squad.equip[1]).to.equal("doggy")
            expect(cfg.loaned_squad.equip[2]).to.equal("doggy")
            expect(cfg.loaned_squad.equip[3]).to.equal("doggy")
            local refs = TutorialSquad.equipRefs(cfg, 3)
            expect(#refs).to.equal(3)
            local doggy = "stack|" .. TutorialSquad.stackKey("doggy", "basic")
            expect(refs[1]).to.equal(doggy)
            expect(refs[2]).to.equal(doggy)
            expect(refs[3]).to.equal(doggy)
        end)

        it("adds and subtracts only the loaned quantities", function()
            local items = {
                [TutorialSquad.stackKey("bunny", "basic")] = {
                    id = "bunny",
                    variant = "basic",
                    quantity = 2,
                },
            }
            local ledger = TutorialSquad.addGrants(items, TutorialSquad.grantRows(cfg))
            expect(items[TutorialSquad.stackKey("bunny", "basic")].quantity).to.equal(5)
            expect(items[TutorialSquad.stackKey("kitty", "basic")].quantity).to.equal(3)
            expect(ledger[TutorialSquad.stackKey("bunny", "basic")]).to.equal(3)
            TutorialSquad.removeGrants(items, ledger)
            expect(items[TutorialSquad.stackKey("bunny", "basic")].quantity).to.equal(2)
            expect(items[TutorialSquad.stackKey("kitty", "basic")]).to.equal(nil)
        end)

        it("shows every bunny/doggy/bear/kitty and hides other species", function()
            local rows = TutorialSquad.grantRows(cfg)
            expect(TutorialSquad.isAllowedItem({
                folder_source = "pets",
                petType = "bunny",
                variant = "basic",
            }, rows)).to.equal(true)
            expect(TutorialSquad.isAllowedItem({
                folder_source = "pets",
                petType = "bunny",
                variant = "golden",
            }, rows)).to.equal(true)
            expect(TutorialSquad.isAllowedItem({
                folder_source = "pets",
                petType = "dragon",
                variant = "basic",
            }, rows)).to.equal(false)
            expect(
                TutorialSquad.refAllowed(
                    "stack|" .. TutorialSquad.stackKey("bunny", "basic") .. "|1",
                    rows
                )
            ).to.equal(true)
            expect(
                TutorialSquad.refAllowed(
                    "stack|" .. TutorialSquad.stackKey("kitty", "basic") .. "|2",
                    rows
                )
            ).to.equal(true)
            expect(TutorialSquad.refAllowed("stack|kitty:rainbow:", rows)).to.equal(true)
            expect(TutorialSquad.refAllowed("secret-uid", rows)).to.equal(false)
        end)

        it("copies Equipped.pets without sharing the table", function()
            local src = { slot_1 = "stack|bear:basic:", slot_2 = "uid-1" }
            local copy = TutorialSquad.copyEquipped(src)
            expect(copy.slot_1).to.equal("stack|bear:basic:")
            expect(copy.slot_2).to.equal("uid-1")
            copy.slot_1 = "stack|kitty:basic:"
            expect(src.slot_1).to.equal("stack|bear:basic:")
            expect(next(TutorialSquad.copyEquipped(nil))).to.equal(nil)
        end)
    end)
end
