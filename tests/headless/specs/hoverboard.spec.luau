local HoverboardLogic = loadModule("src/Shared/Game/HoverboardLogic.lua")
local BlockLetterSign = loadModule("src/Shared/Assets/BlockLetterSign.lua")
local hoverboard = loadModule("configs/hoverboard.lua")

return function()
    describe("HoverboardLogic", function()
        it("unlocks only after tutorial completion and claimed Level 2", function()
            local unlock = hoverboard.unlock
            expect(HoverboardLogic.isEligible(1, true, unlock)).to.equal(false)
            expect(HoverboardLogic.isEligible(2, false, unlock)).to.equal(false)
            expect(HoverboardLogic.isEligible(2, true, unlock)).to.equal(true)
        end)

        it("uses cruise speed as a floor under existing movement bonuses", function()
            expect(HoverboardLogic.mountedSpeed(16, 1, 64)).to.equal(64)
            expect(HoverboardLogic.mountedSpeed(16, 5, 64)).to.equal(80)
            expect(HoverboardLogic.skinCruiseSpeed(hoverboard.skins.black_gold, 64)).to.equal(64)
            expect(HoverboardLogic.skinCruiseSpeed(hoverboard.skins.rocket_blue, 64)).to.equal(
                64 * 2
            )
        end)

        it("suppresses the board in combat, missions, and precision interactions", function()
            expect(HoverboardLogic.shouldSuppress({ in_combat = true })).to.equal(true)
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
            expect(#hoverboard.shop.story.lines).to.equal(3)
            expect(hoverboard.shop.location.sign.lines[1]).to.equal("KADE'S")
            expect(hoverboard.shop.location.sign.lines[2]).to.equal("BOARDS")
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
            expect(hoverboard.shop.catalog.rocket_blue.kind).to.equal("robux")
        end)
    end)
end
