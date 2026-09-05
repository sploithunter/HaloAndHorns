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
                kade_rocket = 303,
                future_boost = 0,
            },
            passes = {
                { id = "vip", name = "VIP" },
                { id = "speed", name = "Speed" },
                { id = "kade_rocket", name = "Rocket", pet_shop_visible = false },
            },
            products = {
                { id = "future_boost", name = "Future" },
                { id = "missing", name = "Missing" },
            },
        }

        it("projects configured passes with positive Marketplace IDs in authored order", function()
            local passes = MonetizationCatalog.livePasses(config)
            expect(#passes).to.equal(3)
            expect(passes[1].id).to.equal("vip")
            expect(passes[1].robloxId).to.equal(101)
            expect(passes[1].kind).to.equal("gamepass")
            expect(passes[2].order).to.equal(2)
        end)

        it("keeps dedicated-vendor passes out of the Pet Shop", function()
            local passes = MonetizationCatalog.petShopPasses(config)
            expect(#passes).to.equal(2)
            expect(passes[1].id).to.equal("vip")
            expect(passes[2].id).to.equal("speed")
        end)

        it("projects a configured vendor subset in requested order", function()
            local passes = MonetizationCatalog.selectedPetShopPasses(config, {
                "speed",
                "missing",
                "vip",
                "speed",
                "kade_rocket",
            })
            expect(#passes).to.equal(2)
            expect(passes[1].id).to.equal("speed")
            expect(passes[1].order).to.equal(1)
            expect(passes[2].id).to.equal("vip")
            expect(passes[2].order).to.equal(3)
        end)

        it("hides developer-product placeholders until their IDs are live", function()
            expect(#MonetizationCatalog.liveProducts(config)).to.equal(0)
        end)

        it("uses Roblox's prompt for live IDs and only simulates zero-ID stubs", function()
            expect(MonetizationCatalog.purchaseRoute(3709033036, true)).to.equal("marketplace")
            expect(MonetizationCatalog.purchaseRoute(3709033036, false)).to.equal("marketplace")
            expect(MonetizationCatalog.purchaseRoute(0, true)).to.equal("simulate")
            expect(MonetizationCatalog.purchaseRoute(nil, false)).to.equal("unavailable")
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

        it("ships all three live deterministic boost products as inventory tokens", function()
            local shipped = loadModule("configs/monetization.lua")
            local products = MonetizationCatalog.liveProducts(shipped)
            local byId = {}
            for _, product in ipairs(products) do
                byId[product.id] = product
            end

            expect(#products).to.equal(3)
            expect(byId.hoverboard_rocket_blue).to.equal(nil)

            local titan = byId.titan_team
            expect(titan).never.to.equal(nil)
            expect(titan.robloxId).to.equal(3708227956)
            expect(titan.config.price_robux).to.equal(19)
            expect(titan.config.rewards.token.item_id).to.equal("titan_team_token")

            expect(byId.xp_hour.robloxId).to.equal(3708216219)
            expect(byId.xp_hour.config.price_robux).to.equal(19)
            expect(byId.xp_hour.config.rewards.token.item_id).to.equal("double_xp_token")

            expect(byId.coin_hour.robloxId).to.equal(3708216387)
            expect(byId.coin_hour.config.price_robux).to.equal(19)
            expect(byId.coin_hour.config.rewards.token.item_id).to.equal("double_coins_token")
        end)

        it("ships rocketboards only as hidden permanent game passes", function()
            local shipped = loadModule("configs/monetization.lua")
            local rocketPass
            for _, pass in ipairs(shipped.passes) do
                if pass.id == "hoverboard_rocket_blue" then
                    rocketPass = pass
                    break
                end
            end
            expect(rocketPass).never.to.equal(nil)
            expect(rocketPass.benefits.hoverboard_skin).to.equal("rocket_blue")
            expect(rocketPass.pet_shop_visible).to.equal(false)
            expect(rocketPass.tradeable).to.equal(false)

            local shop = readFile("src/Client/UI/Menus/RewardShopPanel.lua")
            expect(shop:find("MonetizationCatalog.petShopPasses", 1, true)).to.be.ok()
        end)

        it("ships Auto Collector as a passive pet instead of a Magnet-radius bonus", function()
            local shipped = loadModule("configs/monetization.lua")
            local drops = loadModule("configs/drops.lua")
            local collectorPass
            for _, pass in ipairs(shipped.passes) do
                if pass.id == "auto_collect" then
                    collectorPass = pass
                    break
                end
            end
            expect(collectorPass).to.be.ok()
            expect(collectorPass.benefits.features.auto_collect_enabled).to.equal(true)
            expect(collectorPass.benefits.features.auto_collect_range).never.to.be.ok()
            expect(drops.auto_collector.pet).to.equal("trail_pup")
            -- The separate collector pet keeps its own touch radius, not the player's magnet.
            expect(drops.auto_collector.collect_radius).to.equal(11)
            expect(drops.auto_collector.base_travel_speed).to.equal(26)
            local dropService = readFile("src/Server/Services/DropService.lua")
            local controller = readFile("src/Client/Systems/AutoCollectorController.lua")
            local client = readFile("src/Client/init.client.lua")
            expect(dropService:find('Workspace:FindFirstChild("AutoCollectors")', 1, true)).to.be.ok()
            expect(dropService:find('model:SetAttribute("NoPetOffense", true)', 1, true)).to.be.ok()
            expect(dropService:find('model:SetAttribute("NoEnemyAggro", true)', 1, true)).to.be.ok()
            expect(controller:find('Workspace:WaitForChild("AutoCollectors", 30)', 1, true)).to.be.ok()
            expect(controller:find("Shared.Game.PetMeander", 1, true)).to.be.ok()
            expect(controller:find("PetMeander.step", 1, true)).to.be.ok()
            expect(controller:find('GetAttribute("AutoCollectorMode") == "follow"', 1, true)).to.be.ok()
            expect(client:find("AutoCollectorController", 1, true)).to.be.ok()
        end)

        it(
            "routes deterministic product receipts into inventory and an empty hotbar slot",
            function()
                local source = readFile("src/Server/Services/MonetizationService.lua")
                expect(source:find("if rewards.token then", 1, true)).to.be.ok()
                expect(source:find('self._inventoryService:AddItem(player, "consumables"', 1, true)).to.be.ok()
                expect(source:find("hotbar:AutoBindToken(player, itemId)", 1, true)).to.be.ok()
            end
        )

        it("renders and activates consumables from the shared item catalog", function()
            local items = loadModule("configs/items.lua")
            local byId = {}
            for _, item in ipairs(items) do
                byId[item.id] = item
            end
            for _, itemId in ipairs({
                "future_call_token",
                "double_xp_token",
                "double_coins_token",
                "titan_team_token",
            }) do
                expect(byId[itemId]).never.to.equal(nil)
                expect(byId[itemId].consumable).to.equal(true)
                expect(byId[itemId].hotbar_type).to.equal("token")
            end

            local inventory = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            expect(inventory:find('WaitForChild("items")', 1, true)).to.be.ok()
            expect(inventory:find("ITEM_BY_ID[itemData.id]", 1, true)).to.be.ok()
            expect(inventory:find("local itemIcons", 1, true)).never.to.be.ok()
        end)

        it("surfaces every paid timed boost in the player badge row", function()
            local badges = readFile("src/Client/Systems/PlayerPowerBadges.lua")
            expect(badges:find('attr = "CoinProductBuff"', 1, true)).to.be.ok()
            expect(badges:find('attr = "XpProductBuff"', 1, true)).to.be.ok()
            expect(badges:find('attr = "TitanTeamDamageBuff"', 1, true)).to.be.ok()
            expect(badges:find("Workspace:GetServerTimeNow()", 1, true)).to.be.ok()
            expect(badges:find("math.max(0, untilT - now)", 1, true)).to.be.ok()
            expect(badges:find('return ("%d:%02d"):format', 1, true)).to.be.ok()
            expect(badges:find("b.timer.Text = formatCountdown(remaining)", 1, true)).to.be.ok()
            expect(badges:find('tooltip.Name = "StatusTooltip"', 1, true)).to.be.ok()
            expect(badges:find('return legacy.name or "Founder\'s Legacy"', 1, true)).to.be.ok()
            expect(badges:find("local mult = (legacy.server_luck or {}).mult or 1.5", 1, true)).to.be.ok()
            expect(badges:find('effect.description or "A deployed pet', 1, true)).to.be.ok()

            local effects = readFile("src/Server/Services/PlayerEffectsService.lua")
            expect(effects:find('attributeName .. "Until"', 1, true)).to.be.ok()
            expect(effects:find("math.ceil(remaining)", 1, true)).to.be.ok()
        end)

        it("renders owned game passes in a separate permanent badge row", function()
            local badges = readFile("src/Client/Systems/PlayerPowerBadges.lua")
            expect(badges:find('activeRow.Name = "ActiveEffectsRow"', 1, true)).to.be.ok()
            expect(badges:find('passRow.Name = "OwnedPassesRow"', 1, true)).to.be.ok()
            expect(badges:find("MonetizationCatalog.livePasses", 1, true)).to.be.ok()
            expect(badges:find("MonetizationCatalog.ownedSet", 1, true)).to.be.ok()
            expect(badges:find("Signals.OwnedPasses.OnClientEvent", 1, true)).to.be.ok()
            expect(badges:find("Signals.GetOwnedPasses:FireServer()", 1, true)).to.be.ok()
            expect(badges:find('permanent.Text = "∞"', 1, true)).never.to.be.ok()
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
            expect(source:find('player:SetAttribute("AutoCollectorEnabled", false)', 1, true)).to.be.ok()
            expect(source:find('player:SetAttribute("AutoCollectorEnabled", true)', 1, true)).to.be.ok()
            expect(source:find("AutoCollectRange", 1, true)).never.to.be.ok()
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
