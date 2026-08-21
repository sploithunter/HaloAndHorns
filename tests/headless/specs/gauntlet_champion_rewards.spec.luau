local petsConfig = loadModule("configs/pets.lua")
local rolesConfig = loadModule("configs/pet_roles.lua")
local leaderboards = loadModule("configs/leaderboards.lua")
local thumbnails = loadModule("configs/pet_thumbnail_assets.lua")

local championPets = {
    ribbon_ram = "tank",
    medal_moth = "support",
    laurel_lynx = "melee",
    victory_gryphon = "ranged",
    crowned_chimera = "control",
}

local function board(id)
    for _, candidate in ipairs(leaderboards.boards or {}) do
        if candidate.id == id then
            return candidate
        end
    end
    return nil
end

return function()
    describe("Gauntlet Champion leaderboard rewards", function()
        it("uses the normal Exclusive strength tier rather than Secret or Huge", function()
            expect(petsConfig.eternal.default_percent_by_rarity.exclusive).to.equal(90)
            expect(petsConfig.eternal.default_percent_by_rarity.secret).to.equal(85)
            expect(petsConfig.eternal.huge_power_percent).to.equal(120)

            for petType in pairs(championPets) do
                local pet = petsConfig.pets[petType]
                expect(pet.rarity).to.equal("exclusive")
                expect(pet.category).to.equal("exclusive")
                expect(pet.origin).to.equal("creator")
                expect(pet.base_power).to.equal(50)
                expect(pet.base_health).to.equal(500)
            end
        end)

        it("covers all five archetypes with real support and control utility", function()
            for petType, role in pairs(championPets) do
                expect(rolesConfig.by_type[petType]).to.equal(role)
            end
            expect(rolesConfig.support_auras.medal_moth.kind).to.equal("defense")
            expect(rolesConfig.support_auras.crowned_chimera.kind).to.equal("hold")
        end)

        it("publishes fixed 42/28/18/10/2 odds with standard Exclusive variants", function()
            local egg = petsConfig.egg_sources.gauntlet_champion_egg
            expect(egg.purchasable).to.equal(false)
            expect(egg.fixed_odds).to.equal(true)
            expect(egg.pet_weights.ribbon_ram).to.equal(42)
            expect(egg.pet_weights.medal_moth).to.equal(28)
            expect(egg.pet_weights.laurel_lynx).to.equal(18)
            expect(egg.pet_weights.victory_gryphon).to.equal(10)
            expect(egg.pet_weights.crowned_chimera).to.equal(2)
            expect(egg.rarity_rates.golden_chance).to.equal(0.05)
            expect(egg.rarity_rates.rainbow_chance).to.equal(0.005)
            expect(egg.huge.chance).to.equal(0.01)
            expect(egg.huge.any_pet).to.equal(true)
            expect(egg.modifier_support.supports_luck_gamepass).to.equal(false)

            local boosted = { level = 50, luckBoost = 999, firstHatchLuck = 50 }
            local result = petsConfig.simulateHatch("gauntlet_champion_egg", boosted)
            expect(result.luckMultiplier).to.equal(1)
            expect(result.finalGoldenChance).to.equal(0.05)
            expect(result.finalRainbowChance).to.equal(0.005)
            expect(boosted.firstHatchLuck).to.equal(50)
        end)

        it("ships resolved basic, Golden, Rainbow, and egg thumbnails", function()
            for petType in pairs(championPets) do
                local petThumbs = thumbnails.pets[petType]
                expect(type(petThumbs.basic)).to.equal("string")
                expect(type(petThumbs.golden)).to.equal("string")
                expect(petThumbs.rainbow).to.equal(petThumbs.basic)
            end
            expect(type(thumbnails.eggs.gauntlet_champion_egg)).to.equal("string")
        end)

        it("gives each Top 10 place its accepted gem and held-egg bundle on both boards", function()
            local gems = { 1500, 1200, 1000, 800, 700, 600, 500, 450, 400, 350 }
            for _, boardId in ipairs({ "range_current", "training_ground_current" }) do
                local tiers = board(boardId).awards.tiers
                expect(#tiers).to.equal(10)
                for rank, tier in ipairs(tiers) do
                    expect(tier.max_rank).to.equal(rank)
                    expect(tier.reward.currencies.gems).to.equal(gems[rank])
                    local eggCount = 0
                    for _, item in ipairs(tier.reward.items or {}) do
                        if item.id == "gauntlet_champion_egg" then
                            expect(item.bucket).to.equal("eggs")
                            eggCount += item.qty
                        end
                    end
                    expect(eggCount > 0).to.equal(true)
                end
            end

            local first = board("range_current").awards.tiers[1].reward
            expect(first.pets[1].id).to.equal("crowned_chimera")
            expect(first.items[2].roll).to.equal("origin_single")
            expect(first.items[2].qty).to.equal(2)
        end)
    end)
end
