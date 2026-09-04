local Policy = loadModule("src/Shared/Game/MergeBayClaimPolicy.lua")
local function player(attributes)
    return {
        GetAttribute = function(_, key)
            return attributes[key]
        end,
    }
end

return function()
    describe("Bay claim prompt eligibility", function()
        it("offers empty bays only to an unclaimed player", function()
            expect(Policy.canOffer(player({}), true)).to.equal(true)
            expect(Policy.canOffer(player({}), false)).to.equal(false)
            expect(Policy.canOffer(player({}), nil)).to.equal(false)
        end)
        it(
            "hides claims throughout entry, play, and cleanup without hiding them from others",
            function()
                local attrs = { MergeEggBayId = "heaven_01" }
                local owner = player(attrs)
                expect(Policy.canOffer(owner, true)).to.equal(false)
                attrs.InMergeEggPrototype = true
                expect(Policy.canOffer(owner, true)).to.equal(false)
                attrs.InMergeEggPrototype = nil
                expect(Policy.canOffer(owner, true)).to.equal(false)
                expect(Policy.canOffer(player({}), true)).to.equal(true)
                attrs.MergeEggBayId = nil
                expect(Policy.canOffer(owner, true)).to.equal(true)
            end
        )
        it("also hides during temporary modes and active-flag replication edges", function()
            for _, key in ipairs({
                "InMission",
                "InPrologue",
                "InCombatTutorial",
                "GauntletMode",
                "InMergeEggPrototype",
            }) do
                expect(Policy.canOffer(player({ [key] = true }), true)).to.equal(false)
            end
        end)
    end)
end
