--[[
    Feature 19: Trading — [unit] / [integration] scenarios.
    Run: mise run test-headless
]]

local TradeLogic = loadModule("src/Shared/Game/TradeLogic.lua")
local TradeReveal = loadModule("src/Shared/Game/TradeReveal.lua")
local TradePetSort = loadModule("src/Shared/Game/TradePetSort.lua")
local config = loadModule("configs/trade.lua")

return function()
    describe("trade pet sorting", function()
        it("puts Huges before stronger normal pets, then sorts each tier by power", function()
            local pets = {
                { id = "normal_strong", sortPower = 900 },
                { id = "huge_weak", huge = true, sortPower = 10 },
                { id = "huge_strong", record = { huge = true }, sortPower = 50 },
                { id = "normal_weak", sortPower = 20 },
            }

            TradePetSort.sort(pets)

            expect(pets[1].id).to.equal("huge_strong")
            expect(pets[2].id).to.equal("huge_weak")
            expect(pets[3].id).to.equal("normal_strong")
            expect(pets[4].id).to.equal("normal_weak")
        end)

        it("uses quantity and identity to make equal-power stacks deterministic", function()
            local pets = {
                { id = "bunny", variant = "rainbow", sortPower = 25, quantity = 2 },
                { id = "bear", variant = "basic", sortPower = 25, quantity = 4 },
                { id = "doggy", variant = "basic", sortPower = 25, quantity = 4 },
            }

            TradePetSort.sort(pets)

            expect(pets[1].id).to.equal("bear")
            expect(pets[2].id).to.equal("doggy")
            expect(pets[3].id).to.equal("bunny")
        end)

        it("wires the trade picker to the shared Huge-first comparator", function()
            local panel = readFile("src/Client/UI/Menus/TradePanel.lua")
            expect(string.find(panel, "TradePetSort.sort(sourceItems", 1, true) ~= nil).to.equal(
                true
            )
        end)
    end)

    describe("trade picker view stability", function()
        it("preserves each keyed column scroll position across authoritative updates", function()
            local panel = readFile("src/Client/UI/Menus/TradePanel.lua")
            expect(
                string.find(panel, "function TradePanel:_captureScrollPositions()", 1, true) ~= nil
            ).to.equal(true)
            expect(
                string.find(panel, "function TradePanel:_restoreScrollPositions", 1, true) ~= nil
            ).to.equal(true)
            expect(string.find(panel, 'scrollKey = "source:" .. self._sourceTab', 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(panel, 'scrollKey = "your-offer"', 1, true) ~= nil).to.equal(true)
            expect(string.find(panel, 'scrollKey = "their-offer"', 1, true) ~= nil).to.equal(true)
            expect(
                string.find(panel, "self:_restoreScrollPositions(win, scrollPositions)", 1, true)
                    ~= nil
            ).to.equal(true)
        end)

        it("numbers selected offer cards while preserving duplicate counts", function()
            local panel = readFile("src/Client/UI/Menus/TradePanel.lua")
            expect(string.find(panel, 'selected.Name = "OfferSelectionNumber"', 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(panel, 'selected.Text = "#" .. tostring(order)', 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(panel, "local badgeN = pet.count", 1, true) ~= nil).to.equal(true)
        end)
    end)

    describe("TradeLogic invitations", function()
        it("expires exactly at the configured deadline", function()
            local invite = TradeLogic.newInvite(123, 1_000, config.invite_timeout_seconds)
            expect(invite.from).to.equal(123)
            expect(invite.expiresAt).to.equal(1_030)
            expect(TradeLogic.inviteExpired(invite, 1_029)).to.equal(false)
            expect(TradeLogic.inviteExpired(invite, 1_030)).to.equal(true)
        end)

        it("defaults malformed invitation timing to expired", function()
            expect(TradeLogic.inviteExpired({}, 1)).to.equal(true)
            expect(TradeLogic.inviteExpired(nil, 1)).to.equal(true)
        end)

        it("keeps requester decline notices live after closing the player picker", function()
            local panel = readFile("src/Client/UI/Menus/TradePanel.lua")
            expect(string.find(panel, "self:_closeSelectionPanel()", 1, true) ~= nil).to.equal(true)
            expect(string.find(panel, "gui.DisplayOrder = 160", 1, true) ~= nil).to.equal(true)
            expect(
                string.find(
                    panel,
                    'self:_statusBanner("trade_request_declined", "🤝 Trade request declined.")',
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            expect(
                string.find(
                    panel,
                    'self:_statusBanner("trade_request_timed_out", "⌛ Trade request timed out.")',
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
            local events = readFile("configs/game_events.lua")
            expect(string.find(events, "trade_request_declined = {", 1, true) ~= nil).to.equal(true)
            expect(string.find(events, "trade_request_timed_out = {", 1, true) ~= nil).to.equal(
                true
            )
            expect(
                string.find(
                    panel,
                    "self._tradeUpdateConnection = remote.OnClientEvent:Connect",
                    1,
                    true
                ) ~= nil
            ).to.equal(true)
        end)
    end)

    describe("post-trade received pet reveal", function()
        it("filters the partner offer to pets and preserves reveal identity", function()
            local result = TradeReveal.receivedPets({
                { category = "currencies", id = "gems", quantity = 100 },
                {
                    category = "pets",
                    id = "radiant_sprite",
                    variant = "rainbow",
                    record = { rarity_id = "legendary", huge = true },
                },
                { category = "enhancements", id = "range_L1" },
            })

            expect(result.total).to.equal(1)
            expect(#result.pets).to.equal(1)
            expect(result.pets[1].petType).to.equal("radiant_sprite")
            expect(result.pets[1].variant).to.equal("rainbow")
            expect(result.pets[1].rarityId).to.equal("legendary")
            expect(result.pets[1].huge).to.equal(true)
            expect(result.truncated).to.equal(false)
        end)

        it("caps a completed trade reveal at 99 pets", function()
            local items = {}
            for i = 1, 100 do
                items[i] = { category = "pets", id = "pet_" .. tostring(i) }
            end

            local result = TradeReveal.receivedPets(items)
            expect(result.total).to.equal(100)
            expect(#result.pets).to.equal(99)
            expect(result.truncated).to.equal(true)
        end)

        it("wires completed trade packets to the reveal-only hatch presenter", function()
            local panel = readFile("src/Client/UI/Menus/TradePanel.lua")
            local hatch = readFile("src/Shared/Services/EggHatchingService.lua")
            expect(string.find(panel, "payload.state.them.items", 1, true) ~= nil).to.equal(true)
            expect(string.find(panel, "TradeReveal.receivedPets", 1, true) ~= nil).to.equal(true)
            expect(string.find(hatch, "StartPetRevealAnimation", 1, true) ~= nil).to.equal(true)
            expect(string.find(hatch, "revealOnly = true", 1, true) ~= nil).to.equal(true)
        end)
    end)

    describe("TradeLogic.canAddItem", function()
        it("allows offering an unlocked pet", function()
            local r = TradeLogic.canAddItem("pets", { id = "bear", locked = false }, config)
            expect(r.ok).to.equal(true)
        end)

        it("rejects a locked pet", function()
            local r = TradeLogic.canAddItem("pets", { id = "bear", locked = true }, config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("pet_locked")
        end)

        it("rejects soulbound biome coins (e.g. lava_coins)", function()
            local r = TradeLogic.canAddItem("currencies", { id = "lava_coins" }, config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("currencies_not_tradeable")
        end)

        it("allows gems (the only tradeable currency)", function()
            local r = TradeLogic.canAddItem("currencies", { id = "gems" }, config)
            expect(r.ok).to.equal(true)
        end)

        it("rejects a biome coin even when gems are allowlisted", function()
            local r = TradeLogic.canAddItem("currencies", { id = "grass_coins" }, config)
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("currencies_not_tradeable")
        end)

        it("allows cosmetics", function()
            local r = TradeLogic.canAddItem("cosmetics", { id = "halo_skin" }, config)
            expect(r.ok).to.equal(true)
        end)

        it("allows enhancements (all are tradeable)", function()
            local r = TradeLogic.canAddItem("enhancements", { id = "enh_anvil_fire_L1" }, config)
            expect(r.ok).to.equal(true)
        end)

        it("allows held eggs so complete tester provenance can move through escrow", function()
            local r = TradeLogic.canAddItem("eggs", { id = "beta_egg" }, config)
            expect(r.ok).to.equal(true)
        end)
    end)

    describe("TradeLogic.canExecute (both-confirm gate)", function()
        it("rejects when only one side confirmed", function()
            local r = TradeLogic.canExecute(
                { items = {}, confirmed = true },
                { items = {}, confirmed = false }
            )
            expect(r.ok).to.equal(false)
            expect(r.reason).to.equal("not_both_confirmed")
        end)

        it("executes when both sides confirmed", function()
            local r = TradeLogic.canExecute(
                { items = {}, confirmed = true },
                { items = {}, confirmed = true }
            )
            expect(r.ok).to.equal(true)
        end)
    end)

    describe("TradeLogic.auditRecord", function()
        it("captures both players, their items and a timestamp", function()
            local rec = TradeLogic.auditRecord(
                "alice",
                "bob",
                { items = { { id = "bear" } }, confirmed = true },
                { items = { { id = "wolf" } }, confirmed = true },
                12345
            )
            expect(rec.a).to.equal("alice")
            expect(rec.b).to.equal("bob")
            expect(rec.a_items[1].id).to.equal("bear")
            expect(rec.b_items[1].id).to.equal("wolf")
            expect(rec.timestamp).to.equal(12345)
        end)
    end)
end
