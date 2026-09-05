local Policy = loadModule("src/Shared/Game/MergeAutoplayPolicy.lua")
local Config = loadModule("configs/merge_autoplay.lua")
local Catalog = loadModule("src/Shared/Game/MonetizationCatalog.lua")
local Monetization = loadModule("configs/monetization.lua")
local Towers = loadModule("src/Shared/Game/MergeTowerProgression.lua")
local Bulwarks = loadModule("src/Shared/Game/MergeBulwarkProgression.lua")
local TierArt = loadModule("configs/merge_egg_prototype.lua").tier_art

local function action(kind, category, amount)
    return {
        key = kind,
        kind = kind,
        category = category,
        currency = Config.currency,
        amount = amount or 0,
    }
end

return function()
    describe("Coin-only Merge autoplay", function()
        it("requires a deployed income source before saving for a base upgrade", function()
            local service = readFile("src/Server/Services/MergeAutoplayService.lua")
            expect(service:find("merge:_initializedHatcherCount(record) > 0", 1, true)).to.be.ok()
        end)
        it("validates config and maps the purchase card to the live pass", function()
            expect(Policy.validate(Config)).to.equal(true)
            local pass
            for _, entry in ipairs(Catalog.livePasses(Monetization)) do
                if entry.id == Config.pass_id then
                    pass = entry
                end
            end
            expect(pass.robloxId).to.equal(1963628754)
            expect(pass.config.benefits.features[Config.entitlement_feature]).to.equal(true)
        end)
        it("never permits Gems, unlocks, rebirth, ascension or arbitrary commands", function()
            for _, kind in ipairs({
                "rebirth",
                "ascend",
                "level_up",
                "purchase_upgrade",
                "quartermaster",
                "grant",
                "unknown",
            }) do
                expect(Policy.allowed(action(kind, "eggs"), Config, true)).to.equal(false)
            end
            local a = action("cannon", "cannon", 1)
            a.currency = "gems"
            expect(Policy.allowed(a, Config, true)).to.equal(false)
            a.currency = Config.currency
            a.operation = "unlock"
            expect(Policy.allowed(a, Config, true)).to.equal(false)
            a.operation = "select"
            a.replacing = true
            expect(Policy.allowed(a, Config, false)).to.equal(false)
            expect(Policy.allowed(a, Config, true)).to.equal(true)
        end)
        it("rejects corrupt prices and currency configuration", function()
            for _, amount in ipairs({ -1, math.huge, -math.huge, 0 / 0 }) do
                local a = action("create", "eggs", amount)
                expect(Policy.allowed(a, Config)).to.equal(false)
            end
            local bad = table.clone(Config)
            bad.currency = "gems"
            expect(Policy.validate(bad)).to.equal(false)
            bad = table.clone(Config)
            bad.tick_seconds = 0
            expect(Policy.validate(bad)).to.equal(false)
        end)
        it("supplies the line before combining board eggs before paid purchases", function()
            local place, merge, buy =
                action("place", "eggs"), action("merge", "eggs"), action("create", "eggs", 1)
            place.freePriority, merge.freePriority = 1, 2
            local state = { blocked = {}, cursor = 1 }
            expect(Policy.choose({ buy, merge, place }, state, Config, 0).kind).to.equal("place")
            expect(Policy.choose({ buy, merge }, state, Config, 0).kind).to.equal("merge")
        end)
        it(
            "reserves the turn for expensive defenses instead of endlessly buying cheap eggs",
            function()
                local buy, cannon =
                    action("create", "eggs", 1), action("cannon", "cannon", 10000000)
                local state = { blocked = {}, cursor = 2 }
                expect(Policy.choose({ buy, cannon }, state, Config, 0).kind).to.equal("cannon")
                state.cursor = 3
                expect(Policy.choose({ buy, cannon }, state, Config, 0).kind).to.equal("create")
            end
        )
        it("keeps blocked actions and strategy cursors isolated by player", function()
            local buy = action("create", "eggs", 1)
            local first, second =
                { blocked = { create = 10 }, cursor = 1 }, { blocked = {}, cursor = 1 }
            expect(Policy.choose({ buy }, first, Config, 0)).to.equal(nil)
            expect(Policy.choose({ buy }, second, Config, 0).kind).to.equal("create")
            expect(Policy.choose({ buy }, first, Config, 11).kind).to.equal("create")
        end)
        it("all configured strategy families exist in the production catalogs", function()
            local cannons, bulwarks = {}, {}
            for _, family in ipairs(Towers.families(TierArt)) do
                cannons[family.id] = true
            end
            for _, family in ipairs(Bulwarks.families(TierArt)) do
                bulwarks[family.id] = true
            end
            for _, strategy in pairs(Config.strategies) do
                for _, family in ipairs(strategy.cannons) do
                    expect(cannons[family]).to.equal(true)
                end
                for _, family in ipairs(strategy.bulwarks) do
                    expect(bulwarks[family]).to.equal(true)
                end
            end
        end)
    end)
end
