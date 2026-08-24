--[[
    TutorialUnlock — named AND-list checks for tutorial door / step gates.
]]

local TutorialUnlock = loadModule("src/Shared/Game/TutorialUnlock.lua")

local function snapshot(overrides)
    local base = {
        hotbar = {},
        hotbarEditing = false,
        equippedSlots = {},
        maxSlots = 3,
        rolesByType = { bear = "tank", bunny = "support" },
        defaultRole = "melee",
    }
    for key, value in pairs(overrides or {}) do
        base[key] = value
    end
    return base
end

return function()
    describe("TutorialUnlock named checks", function()
        it("registers the authored check blocks", function()
            expect(TutorialUnlock.hasCheck("hotbar_bound")).to.equal(true)
            expect(TutorialUnlock.hasCheck("hotbar_not_editing")).to.equal(true)
            expect(TutorialUnlock.hasCheck("pets_equipped")).to.equal(true)
            expect(TutorialUnlock.hasCheck("squad_full")).to.equal(true)
            expect(TutorialUnlock.hasCheck("squad_has_role")).to.equal(true)
            expect(TutorialUnlock.hasCheck("not_a_real_check")).to.equal(false)
        end)

        it("requires Heal on the bar and rejects edit mode", function()
            local heal = { check = "hotbar_bound", type = "power", target = "heal" }
            local done = { check = "hotbar_not_editing" }
            local withHeal = snapshot({
                hotbar = { ["1"] = { type = "power", target = "heal" } },
                hotbarEditing = true,
            })
            expect(TutorialUnlock.isMet(heal, withHeal)).to.equal(true)
            expect(TutorialUnlock.isMet(done, withHeal)).to.equal(false)
            withHeal.hotbarEditing = false
            expect(TutorialUnlock.allMet({ heal, done }, withHeal)).to.equal(true)
        end)

        it("returns the first failed row so the door can name the missing action", function()
            local list = {
                { check = "pets_equipped", count = 1, fail_nudge = "Go equip pets." },
                {
                    check = "hotbar_bound",
                    type = "power",
                    target = "heal",
                    fail_nudge = "Set Heal first!",
                },
                { check = "hotbar_not_editing", fail_nudge = "Press Done first!" },
            }
            local empty = snapshot()
            expect(TutorialUnlock.firstFailure(list, empty).fail_nudge).to.equal("Go equip pets.")
            local petsOnly = snapshot({
                equippedSlots = { [1] = { id = "bear" } },
            })
            expect(TutorialUnlock.firstFailure(list, petsOnly).fail_nudge).to.equal(
                "Set Heal first!"
            )
            local editing = snapshot({
                equippedSlots = { [1] = { id = "bear" } },
                hotbar = { ["2"] = { type = "power", target = "heal" } },
                hotbarEditing = true,
            })
            expect(TutorialUnlock.firstFailure(list, editing).fail_nudge).to.equal(
                "Press Done first!"
            )
            editing.hotbarEditing = false
            expect(TutorialUnlock.firstFailure(list, editing)).to.equal(nil)
        end)

        it("can require a full squad or a role for later lessons", function()
            local partial = snapshot({
                maxSlots = 3,
                equippedSlots = { [1] = { id = "bear" } },
            })
            expect(TutorialUnlock.isMet({ check = "pets_equipped" }, partial)).to.equal(true)
            expect(TutorialUnlock.isMet({ check = "squad_full" }, partial)).to.equal(false)
            expect(TutorialUnlock.isMet({ check = "squad_has_role", role = "tank" }, partial)).to.equal(
                true
            )
            expect(TutorialUnlock.isMet({ check = "squad_has_role", role = "support" }, partial)).to.equal(
                false
            )
            local full = snapshot({
                maxSlots = 3,
                equippedSlots = {
                    [1] = { id = "bear" },
                    [2] = { id = "bunny" },
                    [3] = { id = "doggy" },
                },
            })
            expect(TutorialUnlock.isMet({ check = "squad_full" }, full)).to.equal(true)
            expect(TutorialUnlock.isMet({ check = "squad_has_role", role = "support" }, full)).to.equal(
                true
            )
        end)

        it("fails closed on unknown checks", function()
            expect(TutorialUnlock.isMet({ check = "made_up" }, snapshot())).to.equal(false)
            expect(TutorialUnlock.allMet(nil, snapshot())).to.equal(true)
        end)
    end)
end
