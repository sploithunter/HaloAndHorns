local MonetizationCatalog = loadModule("src/Shared/Game/MonetizationCatalog.lua")

return function()
    describe("MonetizationCatalog", function()
        local config = {
            creator_entitlements = {
                grant_all_passes = true,
                user_ids = { 101, "202" },
            },
            product_id_mapping = {
                vip = 101,
                speed = 202,
                future_boost = 0,
            },
            passes = {
                { id = "vip", name = "VIP" },
                { id = "speed", name = "Speed" },
            },
            products = {
                { id = "future_boost", name = "Future" },
                { id = "missing", name = "Missing" },
            },
        }

        it("projects configured passes with positive Marketplace IDs in authored order", function()
            local passes = MonetizationCatalog.livePasses(config)
            expect(#passes).to.equal(2)
            expect(passes[1].id).to.equal("vip")
            expect(passes[1].robloxId).to.equal(101)
            expect(passes[1].kind).to.equal("gamepass")
            expect(passes[2].order).to.equal(2)
        end)

        it("hides developer-product placeholders until their IDs are live", function()
            expect(#MonetizationCatalog.liveProducts(config)).to.equal(0)
        end)

        it("normalizes both compact and detailed owned-pass snapshots", function()
            local owned = MonetizationCatalog.ownedSet({
                passes = {
                    "vip",
                    { id = "speed", name = "Speed" },
                    { name = "invalid" },
                },
            })
            expect(owned.vip).to.equal(true)
            expect(owned.speed).to.equal(true)
            expect(owned.invalid).to.equal(nil)
        end)

        it("preserves honest entitlement sources for shop labels", function()
            local founders = MonetizationCatalog.sourceSet({
                passes = {
                    { id = "speed", sources = { founder = true, test = true } },
                    { id = "vip", sources = { marketplace = true } },
                },
            }, "founder")
            expect(founders.speed).to.equal(true)
            expect(founders.vip).to.equal(nil)
        end)

        it("grants the complete catalog only to configured creator accounts", function()
            expect(MonetizationCatalog.creatorOwnsAllPasses(config, 101)).to.equal(true)
            expect(MonetizationCatalog.creatorOwnsAllPasses(config, 202)).to.equal(true)
            expect(MonetizationCatalog.creatorOwnsAllPasses(config, 303)).to.equal(false)
            expect(MonetizationCatalog.creatorOwnsAllPasses({
                creator_entitlements = { grant_all_passes = false, user_ids = { 101 } },
            }, 101)).to.equal(false)
        end)

        it("ships creator pass entitlement for both production creator accounts", function()
            local shipped = loadModule("configs/monetization.lua")
            expect(MonetizationCatalog.creatorOwnsAllPasses(shipped, 3200870803)).to.equal(true)
            expect(MonetizationCatalog.creatorOwnsAllPasses(shipped, 864785140)).to.equal(true)
            expect(MonetizationCatalog.creatorOwnsAllPasses(shipped, -1)).to.equal(false)
        end)

        it("defaults creator benefits on and persists an explicit off gate", function()
            local defaultState = MonetizationCatalog.creatorPassGateState(config, 101, {})
            expect(defaultState.eligible).to.equal(true)
            expect(defaultState.enabled).to.equal(true)

            local disabled = MonetizationCatalog.creatorPassGateState(config, 101, {
                CreatorGamePassesEnabled = false,
            })
            expect(disabled.eligible).to.equal(true)
            expect(disabled.enabled).to.equal(false)

            local nonCreator = MonetizationCatalog.creatorPassGateState(config, 303, {
                CreatorGamePassesEnabled = false,
            })
            expect(nonCreator.eligible).to.equal(false)
            expect(nonCreator.enabled).to.equal(false)
        end)

        it("routes creator entitlement through the production pass check", function()
            local source = readFile("src/Server/Services/MonetizationService.lua")
            expect(source:find("self:GetCreatorPassGateState(player)", 1, true)).to.be.ok()
            expect(source:find("sourceSets.creator[passConfig.id] = true", 1, true)).to.be.ok()
            expect(source:find("sourceSets.test[passConfig.id] = true", 1, true)).to.be.ok()
            expect(source:find("if not forceNoPasses then", 1, true)).to.be.ok()
            expect(source:find("self:_clearPassBenefits(player, passes)", 1, true)).to.be.ok()
            expect(source:find('player:SetAttribute("MoveSpeedBuffPass", 0)', 1, true)).to.be.ok()
            expect(source:find('player:SetAttribute("AutoCollectRange", nil)', 1, true)).to.be.ok()
        end)

        it("wires the creator-only persisted admin gate", function()
            local dataSource = readFile("src/Server/Services/DataService.lua")
            local adminSource = readFile("src/Server/Services/AdminToolsService.lua")
            local panelSource = readFile("src/Client/UI/Menus/AdminPanel.lua")

            expect(dataSource:find("CreatorGamePassesEnabled = true", 1, true)).to.be.ok()
            expect(dataSource:find("SchemaMigrations[11]", 1, true)).to.be.ok()
            expect(adminSource:find("SetCreatorPassBenefitsEnabled(adminPlayer, enabled)", 1, true)).to.be.ok()
            expect(panelSource:find("Game Passes: ON (tap to disable)", 1, true)).to.be.ok()
            expect(panelSource:find("creatorOnly = true", 1, true)).to.be.ok()
        end)
    end)
end
