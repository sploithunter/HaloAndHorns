local TeamCast = loadModule("src/Shared/Game/TeamCast.lua")
local PackScale = loadModule("src/Shared/Game/PackScale.lua")

local CFG = {
    pack = {
        count_per_extra = 0.8,
        max_count_mult = 3.0,
        count_scales_tiers = { minion = true, elite = true },
    },
}

return function()
    describe("TeamCast.pick (cast-through-player pet resolution)", function()
        local squad = {
            { key = "tank", enduranceFrac = 0.9, isTank = true },
            { key = "hurt", enduranceFrac = 0.2 },
            { key = "down", enduranceFrac = 0, downed = true },
            { key = "aggro", enduranceFrac = 0.6, hasAggro = true },
        }

        it("heal picks the single most-hurt LIVE pet", function()
            local picked = TeamCast.pick("heal", squad)
            expect(#picked).to.equal(1)
            expect(picked[1].key).to.equal("hurt")
        end)

        it("revive picks all downed pets", function()
            local picked = TeamCast.pick("revive", squad)
            expect(#picked).to.equal(1)
            expect(picked[1].key).to.equal("down")
        end)

        it("absorb prefers the aggro holder over the tank", function()
            expect(TeamCast.pick("absorb", squad)[1].key).to.equal("aggro")
        end)

        it("absorb falls back to the tank, then lowest endurance", function()
            local noAggro = {
                { key = "tank", enduranceFrac = 0.9, isTank = true },
                { key = "hurt", enduranceFrac = 0.2 },
            }
            expect(TeamCast.pick("absorb", noAggro)[1].key).to.equal("tank")
            expect(TeamCast.pick("absorb", { { key = "a", enduranceFrac = 0.5 } })[1].key).to.equal(
                "a"
            )
        end)

        it("buffs cover the whole live squad", function()
            expect(#TeamCast.pick("defense_buff", squad)).to.equal(3)
        end)

        it("unsupported families and empty squads pick nothing", function()
            expect(#TeamCast.pick("fear", squad)).to.equal(0)
            expect(#TeamCast.pick("heal", {})).to.equal(0)
            expect(#TeamCast.pick("heal", nil)).to.equal(0)
        end)
    end)

    describe("PackScale.count (team-scaled enemy packs)", function()
        it("solo = base", function()
            expect(PackScale.count(4, 1, "minion", CFG)).to.equal(4)
        end)

        it("two engaged = 1.8x, ceiled", function()
            expect(PackScale.count(4, 2, "minion", CFG)).to.equal(8) -- 4*1.8=7.2 -> 8
            expect(PackScale.count(1, 2, "minion", CFG)).to.equal(2)
        end)

        it("caps at max_count_mult", function()
            expect(PackScale.count(4, 10, "minion", CFG)).to.equal(12) -- 4*3.0 cap
        end)

        it("boss tiers never multiply in count", function()
            expect(PackScale.count(1, 4, "boss", CFG)).to.equal(1)
        end)

        it("defaults safely with missing cfg", function()
            expect(PackScale.count(3, 4, nil, nil)).to.equal(3)
        end)
    end)
end
