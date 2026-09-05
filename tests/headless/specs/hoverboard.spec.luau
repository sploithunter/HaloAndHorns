local HoverboardLogic = loadModule("src/Shared/Game/HoverboardLogic.lua")
local BlockLetterSign = loadModule("src/Shared/Assets/BlockLetterSign.lua")
local hoverboard = loadModule("configs/hoverboard.lua")
local monetization = loadModule("configs/monetization.lua")

return function()
    describe("HoverboardLogic", function()
        it("unlocks only after tutorial completion and claimed Level 2", function()
            local unlock = hoverboard.unlock
            expect(HoverboardLogic.isEligible(1, true, unlock)).to.equal(false)
            expect(HoverboardLogic.isEligible(2, false, unlock)).to.equal(false)
            expect(HoverboardLogic.isEligible(2, true, unlock)).to.equal(true)
        end)

        it("unlocks at Merge wave six before Basic or level two", function()
            expect(HoverboardLogic.isEligible(1, false, hoverboard.unlock, 5)).to.equal(false)
            expect(HoverboardLogic.isEligible(1, false, hoverboard.unlock, 6)).to.equal(true)
            expect(HoverboardLogic.isEligible(1, false, hoverboard.unlock, 30)).to.equal(true)
        end)

        it("uses cruise speed as a floor under existing movement bonuses", function()
            expect(HoverboardLogic.mountedSpeed(16, 1, 64)).to.equal(64)
            expect(HoverboardLogic.mountedSpeed(16, 5, 64)).to.equal(80)
            expect(HoverboardLogic.skinCruiseSpeed(hoverboard.skins.black_gold, 64)).to.equal(64)
            expect(HoverboardLogic.skinCruiseSpeed(hoverboard.skins.rocket_blue, 64)).to.equal(
                64 * 2
            )
        end)

        it("keeps Board copy stable and remembers the first successful use", function()
            expect(hoverboard.button.text).to.equal("Board")
            expect(hoverboard.button.tutorial_text).to.equal(nil)
            expect(HoverboardLogic.needsMergeIntroduction(true, 6, false, false, hoverboard.unlock)).to.equal(
                true
            )
            expect(HoverboardLogic.needsMergeIntroduction(true, 6, true, false, hoverboard.unlock)).to.equal(
                false
            )
            expect(HoverboardLogic.needsMergeIntroduction(true, 6, false, true, hoverboard.unlock)).to.equal(
                false
            )
            expect(
                HoverboardLogic.needsMergeIntroduction(false, 5, false, false, hoverboard.unlock)
            ).to.equal(false)
            local save = HoverboardLogic.normalizeSave({ first_use_complete = true }, "black_gold")
            expect(HoverboardLogic.normalizeSave(save, "black_gold").first_use_complete).to.equal(
                true
            )
            expect(
                HoverboardLogic.normalizeSave(HoverboardLogic.emptySave(), "black_gold").first_use_complete
            ).to.equal(false)
        end)

        it("scales cruise from the Board slider without dropping below walk", function()
            local knobs = hoverboard.speed
            expect(knobs.min_scale).to.equal(0.2)
            expect(knobs.max_scale).to.equal(1)
            expect(HoverboardLogic.clampSpeedScale(0.05, knobs)).to.equal(0.2)
            expect(HoverboardLogic.clampSpeedScale(2, knobs)).to.equal(1)
            expect(HoverboardLogic.clampSpeedScale(nil, knobs)).to.equal(1)
            expect(HoverboardLogic.mountedSpeed(16, 1, 128, 0.25)).to.equal(32)
            expect(HoverboardLogic.mountedSpeed(16, 1, 64, 0.2)).to.equal(16)
            local saved = HoverboardLogic.normalizeSave({
                owned = { rocket_blue = true },
                equipped = "rocket_blue",
                speed_scale = 0.4,
            }, "black_gold")
            expect(saved.speed_scale).to.equal(0.4)
        end)

        it(
            "keeps raw camera input and world-space movement fallbacks in separate spaces",
            function()
                -- Camera faces -Z: raw W and A remain forward and left.
                local x, z = HoverboardLogic.planarMoveDirection(0, -1, 1, 0, 0, -1, 0, 0)
                expect(x).to.equal(0)
                expect(z).to.equal(-1)
                x, z = HoverboardLogic.planarMoveDirection(-1, 0, 1, 0, 0, -1, 0, 0)
                expect(x).to.equal(-1)
                expect(z).to.equal(0)

                -- Merge's control module can return a non-Vector3. Its Humanoid fallback is already
                -- world-space and must not be rotated by this +X-facing camera a second time.
                x, z = HoverboardLogic.planarMoveDirection(nil, nil, 0, 1, 1, 0, 1, 0)
                expect(x).to.equal(1)
                expect(z).to.equal(0)
                x, z = HoverboardLogic.planarMoveDirection(nil, nil, 0, 1, 1, 0, 0, -1)
                expect(x).to.equal(0)
                expect(z).to.equal(-1)
            end
        )

        it("allows combat riding but suppresses missions and precision interactions", function()
            expect(HoverboardLogic.shouldSuppress({ in_combat = true })).to.equal(false)
            expect(HoverboardLogic.shouldSuppress({ in_mission = true })).to.equal(true)
            expect(HoverboardLogic.shouldSuppress({ precision_interact = true })).to.equal(true)
            expect(HoverboardLogic.shouldSuppress({})).to.equal(false)
            expect(HoverboardLogic.canMount(true, true)).to.equal(false)
            expect(HoverboardLogic.canMount(true, false)).to.equal(true)
        end)

        it("authors a single shared board instead of mount inventory", function()
            expect(hoverboard.enabled).to.equal(true)
            expect(hoverboard.cruise_speed).to.equal(64)
            expect(hoverboard.hover_height).to.equal(3.6)
            expect(hoverboard.stance_yaw_degrees).to.equal(90)
            expect(hoverboard.mount.source).to.equal("animate")
            expect(hoverboard.mount.jump_height).to.equal(11)
            expect(hoverboard.mount.jump_seconds).to.equal(0.36)
            expect(hoverboard.mount.boot_below_box).to.equal(0)
            expect(hoverboard.mount.sole_drop).to.equal(-0.7)
            expect(hoverboard.keybind).to.equal("H")
            expect(hoverboard.button.name).to.equal("HoverboardButton")
            expect(hoverboard.flatten.pitch_degrees).to.equal(10.1)
            expect(hoverboard.flatten.roll_degrees).to.equal(-0.2)
            expect(hoverboard.default_skin).to.equal("black_gold")
            expect(hoverboard.skins.black_gold.mesh_asset).to.be.ok()
            expect(hoverboard.skins.black_gold.texture_asset).to.be.ok()
            expect(hoverboard.skins.green_white.mesh_asset).to.be.ok()
            expect(hoverboard.skins.green_white.mesh_asset).never.to.equal(
                hoverboard.skins.black_gold.mesh_asset
            )
            expect(hoverboard.skins.orange_black.texture_asset).to.be.ok()
            expect(hoverboard.skins.white_red.icon).to.be.ok()
            expect(hoverboard.skins.blue_gold.icon).to.be.ok()
            expect(hoverboard.skins.surf_blue.pitch_degrees).to.equal(90)
            expect(hoverboard.skins.surf_blue.deck_yaw_degrees).to.equal(180)
            expect(hoverboard.skins.surf_blue.roll_degrees).to.equal(0.5)
            expect(hoverboard.skins.surf_blue.length).to.equal(12.4)
            expect(hoverboard.skins.surf_blue.sole_drop).to.equal(-0.2)
            expect(hoverboard.skins.rocket_blue.mesh_asset).to.be.ok()
            expect(hoverboard.skins.rocket_blue.pitch_degrees).to.equal(0)
            expect(hoverboard.skins.rocket_blue.cruise_multiplier).to.equal(2)
            expect(hoverboard.skins.rocket_blue.cruise_speed).to.equal(128)
            expect(hoverboard.skins.rocket_blue.deck_yaw_degrees).to.equal(90)
            expect(hoverboard.skins.rocket_blue.length).to.equal(8.1)
            expect(hoverboard.skins.rocket_blue.sole_drop).to.equal(-0.2)
            expect(hoverboard.ride_fx.engines.along).to.equal(-0.80)
            expect(hoverboard.skins.rocket_blue.ride_fx).to.equal("engines")
            expect(hoverboard.skins.surf_blue.ride_fx).never.to.equal("engines")
            expect(hoverboard.skins.rocket_orange.accent_color[1]).to.equal(255)
            expect(hoverboard.skins.rocket_orange.accent_color[2]).to.equal(118)
            expect(hoverboard.skins.rocket_blue.accent_color[3]).to.equal(255)
            expect(hoverboard.shop.npc.user_id).to.equal(536245038)
            expect(hoverboard.shop.catalog.black_gold.kind).to.equal("free")
            expect(hoverboard.shop.catalog.green_white.kind).to.equal("free")
            expect(hoverboard.shop.catalog.orange_black.kind).to.equal("free")
            expect(hoverboard.shop.catalog.white_red.kind).to.equal("free")
            expect(hoverboard.shop.catalog.blue_gold.kind).to.equal("free")
            expect(hoverboard.shop.catalog.surf_blue.kind).to.equal("gems")
            expect(hoverboard.shop.catalog.surf_blue.price).to.equal(900)
            expect(hoverboard.shop.catalog.surf_orange.price).to.equal(1000)
            expect(hoverboard.shop.catalog.rocket_blue.price_robux).to.equal(19)
            expect(hoverboard.shop.catalog.rocket_blue.on_sale).to.equal(true)
            expect(hoverboard.shop.catalog.rocket_blue.pass).to.equal("hoverboard_rocket_blue")
            expect(monetization.product_id_mapping.hoverboard_rocket_blue).to.equal(1954662606)
            expect(monetization.product_id_mapping.hoverboard_rocket_lightblue).to.equal(1952355180)
            expect(monetization.product_id_mapping.hoverboard_rocket_green).to.equal(1955478550)
            expect(monetization.product_id_mapping.hoverboard_rocket_orange).to.equal(1954240779)
            expect(monetization.product_id_mapping.hoverboard_rocket_purple).to.equal(1951917369)
            expect(monetization.product_id_mapping.hoverboard_rocket_yellow).to.equal(1955796497)
            local rocketPass
            local legacyProduct
            for _, pass in ipairs(monetization.passes) do
                if pass.id == "hoverboard_rocket_blue" then
                    rocketPass = pass
                    break
                end
            end
            for _, product in ipairs(monetization.products) do
                if product.id == "hoverboard_rocket_blue" then
                    legacyProduct = product
                    break
                end
            end
            expect(rocketPass).to.be.ok()
            expect(rocketPass.benefits.hoverboard_skin).to.equal("rocket_blue")
            expect(rocketPass.pet_shop_visible).to.equal(false)
            expect(rocketPass.storefront).to.equal("kade_boards")
            expect(rocketPass.tradeable).to.equal(false)
            expect(rocketPass.test_mode_enabled).to.equal(false)
            expect(legacyProduct).to.equal(nil)
            expect(#hoverboard.shop.story.lines).to.equal(3)
            expect(hoverboard.shop.location.sign.lines[1]).to.equal("KADE'S")
            expect(hoverboard.shop.location.sign.lines[2]).to.equal("BOARDS")
        end)

        it("injects the monetization service into Kade's shop", function()
            local bootstrap = readFile("src/Server/init.server.lua")
            local registration = bootstrap:find('"HoverboardShopService"', 1, true)
            expect(registration).to.be.ok()
            local dependencyBlock = bootstrap:sub(registration, registration + 400)
            expect(dependencyBlock:find('"MonetizationService"', 1, true)).to.be.ok()

            local shopService = readFile("src/Server/Services/HoverboardShopService.lua")
            expect(
                shopService:find(
                    "self._monetizationService = self._modules and self._modules.MonetizationService",
                    1,
                    true
                )
            ).to.be.ok()
            expect(shopService:find('productType = "gamepass"', 1, true)).to.be.ok()
            expect(shopService:find("PromptProductPurchase", 1, true)).never.to.be.ok()

            local monetizationService = readFile("src/Server/Services/MonetizationService.lua")
            expect(monetizationService:find("_ownsDurablePassEntitlement", 1, true)).to.be.ok()
            expect(monetizationService:find('"You already own this board!"', 1, true)).to.be.ok()
            expect(
                monetizationService:find("hoverboardService:GrantOwned(player, skinId)", 1, true)
            ).to.be.ok()

            local panel = readFile("src/Client/UI/Menus/HoverboardShopPanel.lua")
            expect(panel:find("offer.roblox_pass_id", 1, true)).to.be.ok()
            expect(panel:find("Enum.InfoType.GamePass", 1, true)).to.be.ok()
        end)

        it("publishes every hoverboard as a non-tradable inventory entitlement", function()
            local service = readFile("src/Server/Services/HoverboardService.lua")
            expect(service:find('child:SetAttribute("Tradeable", false)', 1, true)).to.be.ok()
        end)

        it("uses the Pet Shop's shared glossy pill chrome", function()
            local panel = readFile("src/Client/UI/Menus/HoverboardShopPanel.lua")
            expect(panel:find("PanelChrome.pillPanel", 1, true)).to.be.ok()
            expect(panel:find("PanelChrome.pillBorder", 1, true)).to.be.ok()
            expect(panel:find('return "Robux", "emerald", true', 1, true)).to.be.ok()
            expect(panel:find('return "Equip", "amethyst", true', 1, true)).to.be.ok()
        end)

        it("can spell Kade's Boards with block-letter parts", function()
            local sign = hoverboard.shop.location.sign
            expect(#BlockLetterSign.missingGlyphs(sign.lines)).to.equal(0)
            local width, height =
                BlockLetterSign.measure(sign.lines, sign.cell, sign.letter_gap, sign.line_gap)
            expect(width > 20).to.equal(true)
            expect(height > 10).to.equal(true)
            expect(BlockLetterSign.glyph("K")).to.be.ok()
            expect(BlockLetterSign.glyph("'")).to.be.ok()
            expect(sign.color_mode).to.equal("rainbow")
            expect(BlockLetterSign.colorableCount(sign.lines)).to.equal(12)
            expect(BlockLetterSign.rainbowHue(1, 12)).to.equal(0)
            expect(BlockLetterSign.rainbowHue(7, 12)).to.equal(0.5)
            expect(BlockLetterSign.rainbowHue(1, 12, 0.5)).to.equal(0.5)
            -- One letter-step of phase moves red from K onto A (left to right).
            expect(BlockLetterSign.rainbowHue(2, 12, 1 / 12)).to.equal(0)
            expect(sign.rainbow_speed).to.equal(0.3)
        end)

        it("can wipe ownership without granting the default board", function()
            local empty = HoverboardLogic.emptySave()
            expect(empty.owned.black_gold).to.equal(nil)
            expect(empty.equipped).to.equal(nil)
            local raw = HoverboardLogic.normalizeSave({
                owned = { rocket_orange = true },
                equipped = "rocket_orange",
            }, nil)
            expect(raw.owned.rocket_orange).to.equal(true)
            expect(raw.owned.black_gold).to.equal(nil)
            expect(HoverboardLogic.normalizeSave(nil, nil).owned.black_gold).to.equal(nil)
        end)

        it("keeps only the starter when every free skate was auto-granted", function()
            local catalog = hoverboard.shop.catalog
            local owned = HoverboardLogic.stripCompleteFreeSet({
                black_gold = true,
                green_white = true,
                orange_black = true,
                white_red = true,
                blue_gold = true,
                rocket_blue = true,
            }, catalog, "black_gold")
            expect(owned.black_gold).to.equal(true)
            expect(owned.green_white).to.equal(nil)
            expect(owned.blue_gold).to.equal(nil)
            expect(owned.rocket_blue).to.equal(true)
            local partial = HoverboardLogic.stripCompleteFreeSet({
                black_gold = true,
                green_white = true,
            }, catalog, "black_gold")
            expect(partial.green_white).to.equal(true)
        end)

        it("treats the default board as owned and prices the rest", function()
            local save = HoverboardLogic.normalizeSave(nil, "black_gold")
            expect(save.owned.black_gold).to.equal(true)
            expect(save.equipped).to.equal("black_gold")
            expect(HoverboardLogic.canEquip(save.owned, "green_white")).to.equal(false)
            local ok, reason = HoverboardLogic.canBuy(save.owned, "green_white", {
                kind = "free",
            }, { gems = 0 })
            expect(ok).to.equal(true)
            expect(reason).to.equal(0)
            ok, reason = HoverboardLogic.canBuy(save.owned, "orange_black", {
                kind = "gems",
                price = 80,
            }, { gems = 20 })
            expect(ok).to.equal(false)
            expect(reason).to.equal("insufficient_gems")
            ok, reason = HoverboardLogic.canBuy(save.owned, "orange_black", {
                kind = "gems",
                price = 80,
            }, { gems = 80 })
            expect(ok).to.equal(true)
            expect(reason).to.equal(80)
            ok, reason = HoverboardLogic.canBuy(save.owned, "blue_gold", {
                kind = "robux",
                product = "hoverboard_blue_gold",
            }, { gems = 0 })
            expect(ok).to.equal(true)
            expect(reason).to.equal("robux")
            ok, reason = HoverboardLogic.canBuy(save.owned, "black_gold", {
                kind = "free",
            }, { gems = 0 })
            expect(ok).to.equal(false)
            expect(reason).to.equal("already_owned")
            save.owned.green_white = true
            expect(HoverboardLogic.canEquip(save.owned, "green_white")).to.equal(true)
            ok, reason = HoverboardLogic.canBuy(save.owned, "green_white", {
                kind = "free",
            }, { gems = 0 })
            expect(ok).to.equal(false)
            expect(reason).to.equal("already_owned")
            local entries =
                HoverboardLogic.catalogEntries(hoverboard.skins, hoverboard.shop.catalog)
            expect(#entries).to.equal(16)
            expect(entries[1].id).to.equal("black_gold")
            expect(entries[2].kind).to.equal("free")
            expect(entries[5].kind).to.equal("free")
            expect(entries[6].id).to.equal("surf_blue")
            expect(entries[6].kind).to.equal("gems")
            expect(entries[11].id).to.equal("rocket_blue")
            expect(entries[11].kind).to.equal("robux")
            expect(entries[11].on_sale).to.equal(true)
            expect(entries[11].pass).to.equal("hoverboard_rocket_blue")
            expect(entries[11].product).to.equal(nil)
            expect(hoverboard.shop.catalog.rocket_blue.kind).to.equal("robux")
        end)

        it("confirms gem spends, then says insufficient funds when broke", function()
            local messages = hoverboard.shop.messages
            expect(messages.insufficient_funds).to.equal("insufficient funds")
            expect(messages.confirm_spend).to.equal("Spend %d gems on %s?")
            local step, price = HoverboardLogic.gemBuyStep({ kind = "gems", price = 900 }, 16)
            expect(step).to.equal("confirm")
            expect(price).to.equal(900)
            step = HoverboardLogic.gemBuyStep({ kind = "gems", price = 900 }, 16, true)
            expect(step).to.equal("insufficient_funds")
            step, price = HoverboardLogic.gemBuyStep({ kind = "gems", price = 900 }, 900, true)
            expect(step).to.equal("buy")
            expect(price).to.equal(900)
            expect(HoverboardLogic.gemBuyStep({ kind = "free" }, 0)).to.equal("take")
            expect(HoverboardLogic.gemBuyStep({ kind = "robux" }, 0)).to.equal("robux")
        end)
    end)
end
