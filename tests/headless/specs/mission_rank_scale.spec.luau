local MissionRankScale = loadModule("src/Shared/Game/MissionRankScale.lua")

local function bossRank()
    return {
        hp_mult = 8,
        dmg_mult = 1.5,
        armor = 150,
        tier = "boss",
        abilities = {
            slam = { damage = 120, radius = 14 },
        },
        level_scaling = {
            min_level = 14,
            max_level = 50,
            curve = "linear",
            at_min = {
                hp_mult = 2,
                dmg_mult = 0.75,
                armor = 25,
                ability_damage_mult = 0.5,
            },
        },
    }
end

return function()
    describe("MissionRankScale", function()
        it("uses the configured low endpoint at the first Trial level", function()
            local resolved = MissionRankScale.resolve(bossRank(), 14)
            expect(resolved.hp_mult).to.equal(2)
            expect(resolved.dmg_mult).to.equal(0.75)
            expect(resolved.armor).to.equal(25)
            expect(resolved.abilities.slam.damage).to.equal(60)
            expect(resolved.level_scaling).to.equal(nil)
        end)

        it("interpolates linearly and preserves the existing level-50 tuning", function()
            local middle = MissionRankScale.resolve(bossRank(), 32)
            expect(middle.hp_mult).to.equal(5)
            expect(middle.dmg_mult).to.equal(1.125)
            expect(middle.armor).to.equal(87.5)
            expect(middle.abilities.slam.damage).to.equal(90)

            local high = MissionRankScale.resolve(bossRank(), 50)
            expect(high.hp_mult).to.equal(8)
            expect(high.dmg_mult).to.equal(1.5)
            expect(high.armor).to.equal(150)
            expect(high.abilities.slam.damage).to.equal(120)
        end)

        it("clamps beyond both endpoints without mutating config", function()
            local original = bossRank()
            local low = MissionRankScale.resolve(original, 1)
            local high = MissionRankScale.resolve(original, 999)
            expect(low.hp_mult).to.equal(2)
            expect(high.hp_mult).to.equal(8)
            expect(original.hp_mult).to.equal(8)
            expect(original.abilities.slam.damage).to.equal(120)
            expect(original.level_scaling.at_min.hp_mult).to.equal(2)
        end)

        it("deep-clones ranks that do not declare a level curve", function()
            local original = { hp_mult = 14, abilities = { slam = { damage = 160 } } }
            local resolved = MissionRankScale.resolve(original, 14)
            resolved.abilities.slam.damage = 1
            expect(original.abilities.slam.damage).to.equal(160)
        end)
    end)
end
