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

        it("ships all three live deterministic boost products as inventory tokens", function()
            local shipped = loadModule("configs/monetization.lua")
            local products = MonetizationCatalog.liveProducts(shipped)
            local byId = {}
            for _, product in ipairs(products) do
                byId[product.id] = product
            end

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
