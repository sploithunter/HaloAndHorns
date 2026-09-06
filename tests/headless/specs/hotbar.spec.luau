--[[
    Feature 16: Hotbar / Command Bar — [unit] scenarios.
    Run: mise run test-headless
]]

local HotbarLogic = loadModule("src/Shared/Game/HotbarLogic.lua")
local config = loadModule("configs/hotbar.lua")
local uiConfig = loadModule("configs/ui.lua")
local archetypes = loadModule("configs/archetypes.lua")
local ArchetypeLogic = loadModule("src/Shared/Game/ArchetypeLogic.lua")

local geoPowers = ArchetypeLogic.availablePowers("geomancer", archetypes)

return function()
    describe("compact menu HUD priority", function()
        it("layers the expanded menu above pets without hiding the pet HUD", function()
            local tray = readFile("src/Client/Systems/MenuTrayStyle.lua")
            local ui = readFile("configs/ui.lua")

            expect(ui:find("compact_menu_overlay = 105", 1, true)).to.be.ok()
            expect(tray:find('overlayGui.Name = "CompactMenuOverlayGui"', 1, true)).to.be.ok()
            expect(tray:find("overlayGui.DisplayOrder = COMPACT_MENU_DISPLAY_ORDER", 1, true)).to.be.ok()
            expect(tray:find("popup.Parent = overlayGui", 1, true)).to.be.ok()
            expect(tray:find('FindFirstChild("SquadHud"', 1, true)).never.to.be.ok()
        end)

        it("fits all utility buttons in complete touch-sized rows", function()
            local tray = readFile("src/Client/Systems/MenuTrayStyle.lua")
            local menu = uiConfig.hud.compact_menu
            local utilityButtonCount = 8
            local rows = math.ceil(utilityButtonCount / menu.columns)

            expect(rows).to.equal(4)
            expect(menu.cell.height * menu.minimum_scale >= uiConfig.mobile.touch_target_min_size).to.equal(
                true
            )
            expect(tray:find("popupRows = math.ceil", 1, true)).to.be.ok()
            expect(tray:find("COMPACT_MENU_CELL.height", 1, true)).to.be.ok()
            expect(tray:find("COMPACT_MENU_MINIMUM_SCALE", 1, true)).to.be.ok()
        end)
    end)

    describe("Merge tutorial hotbar coverage", function()
        it(
            "hides only the central slots, preserves flank controls, and blocks activation",
            function()
                local controller = readFile("src/Client/Systems/HotbarBar.lua")
                local flank = readFile("src/Client/Systems/HotbarFlank.lua")
                local observer = readFile("src/Client/Systems/MergeEggPrototypeObserver.lua")
                expect(controller:find('"MergeTutorialHotbarCovered"', 1, true)).to.be.ok()
                expect(
                    controller:find("centralContent.Visible = not tutorialCoversHotbar()", 1, true)
                ).to.be.ok()
                expect(controller:find("root.Visible = not tutorialCoversHotbar()", 1, true)).never.to.be.ok()
                expect(controller:find('greaterHotbar.Name = "GreaterHotbarFrame"', 1, true)).to.be.ok()
                expect(controller:find('leftControls.Name = "LeftControls"', 1, true)).to.be.ok()
                expect(controller:find('rightControls.Name = "RightControls"', 1, true)).to.be.ok()
                expect(controller:find("root.Parent = greaterHotbar", 1, true)).to.be.ok()
                expect(controller:find("UIViewportScale.attach(greaterHotbar)", 1, true)).to.be.ok()
                expect(controller:find("UIViewportScale.attach(root)", 1, true)).never.to.be.ok()
                expect(flank:find("placeRelativeClassicPets", 1, true)).never.to.be.ok()
                expect(flank:find('slot.side == "left" and leftControls or rightControls', 1, true)).to.be.ok()
                expect(flank:find("pane.AbsolutePosition.X + pane.AbsoluteSize.X", 1, true)).to.equal(
                    nil
                )
                expect(flank:find('pane:GetPropertyChangedSignal("AbsoluteSize")', 1, true)).to.equal(
                    nil
                )
                expect(observer:find('FindFirstChild("GreaterHotbarFrame")', 1, true)).to.be.ok()
                expect(observer:find("card.frame.Size = pillFrame.Size", 1, true)).to.be.ok()
                expect(config.size.flank.classic_pets).to.equal(nil)
                expect(controller:find("local function activateHotbarSlot", 1, true)).to.be.ok()

                local _, activationCount = controller:gsub("activateHotbarSlot%(", "")
                expect(activationCount).to.equal(5)
                local _, directFireCount = controller:gsub("Hotbar_Activate:FireServer", "")
                expect(directFireCount).to.equal(1)
            end
        )
    end)

    describe("hotbar auto-cast tell", function()
        it("authors a ring around the disc, not a corner glyph", function()
            local look = config.auto_cast
            expect(look.thickness > 2).to.equal(true)
            expect(look.scale > 1).to.equal(true)
            expect(#look.color).to.equal(3)
        end)
    end)

    describe("HotbarLogic.defaultBindings (archetype fill)", function()
        -- config-agnostic: define the slot layout locally so this tests the LOGIC and survives the
        -- live config emptying roster/tactical defaults (powers come from picks; commands via Edit).
        local cfg = table.clone(config)
        cfg.default_binds = nil
        cfg.defaults = {
            power_slots = { 1, 2, 3, 4, 5, 6 },
            roster_slots = { 7, 8, 9 },
            tactical_slots = { 10, 11 },
        }
        local b = HotbarLogic.defaultBindings(geoPowers, cfg)

        it("binds the leading power slots to the archetype's powers", function()
            expect(b[1].type).to.equal("power")
            expect(b[1].target).to.equal(geoPowers[1])
            expect(b[3].target).to.equal(geoPowers[3])
        end)

        it("binds roster + tactical slots from config", function()
            expect(b[cfg.defaults.roster_slots[1]].type).to.equal("roster")
            local tSlot = cfg.defaults.tactical_slots[1]
            expect(b[tSlot].type).to.equal("tactical")
            expect(b[tSlot].target).to.equal(config.tactical_commands[1])
        end)
    end)

    describe("HotbarLogic.defaultBindings (default_binds override)", function()
        -- when default_binds is set, it wins regardless of archetype (config-agnostic: use a local
        -- override so this survives the live config nulling default_binds for the level-up flow)
        local override = table.clone(config)
        override.default_binds = {
            { slot = 1, type = "power", target = "cataclysm" },
            { slot = 8, type = "tactical", target = "scatter" },
        }
        local b = HotbarLogic.defaultBindings(geoPowers, override)

        it("uses the explicit layout, ignoring the archetype pool", function()
            expect(b[1].type).to.equal("power")
            expect(b[1].target).to.equal("cataclysm")
            expect(b[8].type).to.equal("tactical")
            expect(b[8].target).to.equal("scatter")
        end)
    end)

    describe("HotbarLogic.beginningBindings", function()
        it("builds the authored new-player bar without an archetype", function()
            local bindings = HotbarLogic.beginningBindings(config)

            expect(bindings[11].type).to.equal("tactical")
            expect(bindings[11].target).to.equal("rally")
            expect(bindings[1]).to.equal(nil)
        end)

        it("ignores malformed beginning rows", function()
            local cfg = table.clone(config)
            cfg.beginning_binds = {
                { slot = 0, type = "tactical", target = "rally" },
                { slot = 2, type = "spell", target = "resonance" },
                { slot = 3, type = "power", target = "" },
                { slot = 4, type = "power", target = "resonance" },
            }
            local bindings = HotbarLogic.beginningBindings(cfg)

            expect(bindings[1]).to.equal(nil)
            expect(bindings[2]).to.equal(nil)
            expect(bindings[3]).to.equal(nil)
            expect(bindings[4].target).to.equal("resonance")
        end)
    end)

    describe("HotbarLogic.canRebind", function()
        it("allows rebinding to a valid power/roster bind", function()
            expect(HotbarLogic.canRebind(1, { type = "roster", target = "Healer Team" }, config).ok).to.equal(
                true
            )
        end)

        it("rejects an out-of-range slot (21)", function()
            expect(HotbarLogic.canRebind(21, { type = "power", target = "x" }, config).reason).to.equal(
                "invalid_slot"
            )
        end)

        it("rejects an invalid bind type", function()
            expect(HotbarLogic.canRebind(1, { type = "spell", target = "x" }, config).reason).to.equal(
                "invalid_bind_type"
            )
        end)

        it("allows clearing a slot (nil bind)", function()
            expect(HotbarLogic.canRebind(1, nil, config).ok).to.equal(true)
        end)
    end)

    describe("HotbarLogic.bindAt", function()
        it("returns nil for an empty slot (press does nothing)", function()
            expect(HotbarLogic.bindAt({}, 15)).to.equal(nil)
        end)

        it("returns the bind at a filled slot", function()
            local hotbar = { [1] = { type = "power", target = "stone_skin" } }
            expect(HotbarLogic.bindAt(hotbar, 1).target).to.equal("stone_skin")
        end)
    end)

    describe("HotbarLogic.ensureBindAt", function()
        it("repairs a missing tutorial bind at its authored slot", function()
            local hotbar = {
                ["20"] = { type = "potion", target = "berserk_brew" },
            }
            local result = HotbarLogic.ensureBindAt(
                hotbar,
                11,
                { type = "tactical", target = "rally" },
                config
            )

            expect(result.ok).to.equal(true)
            expect(result.changed).to.equal(true)
            expect(hotbar["11"].target).to.equal("rally")
            expect(hotbar["20"].target).to.equal("berserk_brew")
        end)

        it("moves an occupied authored slot instead of deleting its bind", function()
            local hotbar = {
                ["11"] = { type = "potion", target = "fortune_flask" },
                ["20"] = { type = "potion", target = "berserk_brew" },
            }
            local result = HotbarLogic.ensureBindAt(
                hotbar,
                11,
                { type = "tactical", target = "rally" },
                config
            )

            expect(result.ok).to.equal(true)
            expect(hotbar["11"].target).to.equal("rally")
            expect(result.movedTo).to.equal(12)
            expect(hotbar["12"].target).to.equal("fortune_flask")
        end)

        it("moves an existing copy to the tutorial's visible slot", function()
            local hotbar = {
                ["15"] = { type = "tactical", target = "rally" },
                ["11"] = { type = "tactical", target = "scatter" },
            }
            local result = HotbarLogic.ensureBindAt(
                hotbar,
                11,
                { type = "tactical", target = "rally" },
                config
            )

            expect(result.movedFrom).to.equal(15)
            expect(result.movedTo).to.equal(15)
            expect(hotbar["11"].target).to.equal("rally")
            expect(hotbar["15"].target).to.equal("scatter")
        end)

        it("is idempotent when the required bind is already correct", function()
            local hotbar = {
                ["11"] = { type = "tactical", target = "rally" },
            }
            local result = HotbarLogic.ensureBindAt(
                hotbar,
                11,
                { type = "tactical", target = "rally" },
                config
            )

            expect(result.ok).to.equal(true)
            expect(result.changed).to.equal(false)
        end)
    end)

    describe("HotbarLogic.potionAutoBindSlot", function()
        it(
            "repairs acquired potions without duplicates, displacement or forced edit reversal",
            function()
                local hotbar = { ["20"] = { type = "power", target = "swift" } }
                local seen = {}
                local potions =
                    { { id = "berserk_brew", count = 2 }, { id = "fortune_flask", count = 0 } }
                expect(HotbarLogic.reconcilePotions(hotbar, potions, seen, config)).to.equal(1)
                expect(hotbar["20"].target).to.equal("swift")
                expect(hotbar["19"].target).to.equal("berserk_brew")
                expect(HotbarLogic.reconcilePotions(hotbar, potions, seen, config)).to.equal(0)
                hotbar["19"] = nil
                expect(HotbarLogic.reconcilePotions(hotbar, potions, seen, config)).to.equal(0)
                table.insert(potions, { id = "new_potion", count = 1 })
                expect(HotbarLogic.reconcilePotions(hotbar, potions, seen, config)).to.equal(1)
                expect(hotbar["19"].target).to.equal("new_potion")
            end
        )
        it("retries a missing potion after space opens", function()
            local hotbar, seen = {}, {}
            for slot = 11, 20 do
                hotbar[tostring(slot)] = { type = "power", target = "owned" }
            end
            local potions = { { id = "berserk_brew", count = 1 } }
            expect(HotbarLogic.reconcilePotions(hotbar, potions, seen, config)).to.equal(0)
            hotbar["16"] = nil
            expect(HotbarLogic.reconcilePotions(hotbar, potions, seen, config)).to.equal(1)
            expect(hotbar["16"].target).to.equal("berserk_brew")
        end)
        it("fills the top row from the right", function()
            local hotbar = {
                ["11"] = { type = "tactical", target = "rally" },
                ["20"] = { type = "potion", target = "fortune_flask" },
            }
            expect(HotbarLogic.potionAutoBindSlot(hotbar, "berserk_brew", config)).to.equal(19)
        end)

        it("does not duplicate an existing potion binding", function()
            local hotbar = {
                ["20"] = { type = "potion", target = "berserk_brew" },
            }
            expect(HotbarLogic.potionAutoBindSlot(hotbar, "berserk_brew", config)).to.equal(nil)
        end)

        it("does not spill into the power row when the top row is full", function()
            local hotbar = {}
            for slot = 11, 20 do
                hotbar[tostring(slot)] = { type = "tactical", target = "filled_" .. slot }
            end
            expect(HotbarLogic.potionAutoBindSlot(hotbar, "berserk_brew", config)).to.equal(nil)
        end)
    end)

    describe("HotbarLogic.applyChallengeOverlay", function()
        it("blanks the saved bar and publishes only the loaned kit", function()
            local saved = {
                ["1"] = { type = "power", target = "genie_dunes" },
                ["8"] = { type = "power", target = "hasten" },
                ["11"] = { type = "tactical", target = "rally" },
            }
            local view = HotbarLogic.applyChallengeOverlay(saved, { "strike", "hasten" })
            expect(view["1"].target).to.equal("strike")
            expect(view["2"].target).to.equal("hasten")
            expect(view["8"]).to.equal(nil)
            expect(view["11"]).to.equal(nil)
            expect(saved["1"].target).to.equal("genie_dunes")
        end)

        it("restores nothing when the loaned kit is empty", function()
            local view = HotbarLogic.applyChallengeOverlay({
                ["1"] = { type = "power", target = "genie_dunes" },
            }, {})
            expect(view["1"]).to.equal(nil)
        end)

        it("returns a new table so a blank publish cannot alias the save", function()
            local saved = { ["1"] = { type = "power", target = "genie_dunes" } }
            local view = HotbarLogic.applyChallengeOverlay(saved, { "strike" })
            expect(view == saved).to.equal(false)
            view["1"] = nil
            expect(saved["1"].target).to.equal("genie_dunes")
        end)
    end)

    describe("HotbarLogic.tokenAutoBindSlot", function()
        it("fills the top row from the left without replacing Rally", function()
            local hotbar = {
                ["11"] = { type = "tactical", target = "rally" },
                ["20"] = { type = "potion", target = "fortune_flask" },
            }
            expect(HotbarLogic.tokenAutoBindSlot(hotbar, "future_call_token", config)).to.equal(12)
        end)

        it("does not duplicate an existing token binding", function()
            local hotbar = {
                ["12"] = { type = "token", target = "future_call_token" },
            }
            expect(HotbarLogic.tokenAutoBindSlot(hotbar, "future_call_token", config)).to.equal(nil)
        end)

        it("spills into the first empty bottom-row slot when the top row is full", function()
            local hotbar = {}
            for slot = 11, 20 do
                hotbar[tostring(slot)] = { type = "tactical", target = "filled_" .. slot }
            end
            expect(HotbarLogic.tokenAutoBindSlot(hotbar, "future_call_token", config)).to.equal(1)
        end)

        it("does not replace anything when all twenty slots are full", function()
            local hotbar = {}
            for slot = 1, 20 do
                hotbar[tostring(slot)] = { type = "tactical", target = "filled_" .. slot }
            end
            expect(HotbarLogic.tokenAutoBindSlot(hotbar, "future_call_token", config)).to.equal(nil)
        end)
    end)
end
