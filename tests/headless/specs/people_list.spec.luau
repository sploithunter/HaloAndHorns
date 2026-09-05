--[[
    Custom People list presentation.
    Run: mise run test-headless
]]

local PeopleList = loadModule("src/Shared/Game/PeopleList.lua")
local PlayerListStatus = loadModule("src/Shared/Game/PlayerListStatus.lua")

local function cfg()
    return loadModule("configs/people_list.lua")
end

local function ranks()
    return loadModule("configs/combat_ranks.lua")
end

return function()
    describe("PeopleList watched roster", function()
        it("keeps offline workers below every online player regardless of names", function()
            local me = { UserId = 1, DisplayName = "Me" }
            local online = { UserId = 2, DisplayName = "Zebra" }
            local offline = { UserId = 3, DisplayName = "Alpha", OfflineWorker = true }
            local second = { UserId = 4, DisplayName = "Beta", OfflineWorker = true }
            local roster = PeopleList.orderedRoster(
                { [me] = {}, [online] = {}, [offline] = {}, [second] = {} },
                me
            )
            expect(roster[1]).to.equal(me)
            expect(roster[2]).to.equal(online)
            expect(roster[3]).to.equal(offline)
            expect(roster[4]).to.equal(second)
        end)
        it("suppresses a stale offline duplicate as soon as that account logs in", function()
            local online = { UserId = 2, DisplayName = "Online" }
            local offline = { UserId = 2, DisplayName = "Offline", OfflineWorker = true }
            local watched = { [online] = {}, [offline] = {} }
            local roster = PeopleList.orderedRoster(watched, online)
            expect(#roster).to.equal(1)
            expect(roster[1]).to.equal(online)
            watched[offline] = nil
            expect(#PeopleList.orderedRoster(watched, online)).to.equal(1)
        end)
        it("uses just the configured emoji on offline names with no text suffix", function()
            local config = cfg()
            local name = PeopleList.displayName(config, { offline = true, owner = true }, "AltName")
            expect(name).to.equal(config.offline.glyph .. " AltName")
            expect(PeopleList.prefix(config, { offline = true }).hover).to.equal(
                config.offline.hover
            )
        end)
        it("excludes departures immediately even while the engine list is stale", function()
            local me = { UserId = 1, DisplayName = "You" }
            local other = { UserId = 2, DisplayName = "Friend" }
            local enginePlayers = { me, other }
            local watched = { [me] = {}, [other] = {} }
            expect(#PeopleList.orderedRoster(watched, me)).to.equal(2)
            watched[other] = nil
            expect(#enginePlayers).to.equal(2)
            local roster = PeopleList.orderedRoster(watched, me)
            expect(#roster).to.equal(1)
            expect(roster[1]).to.equal(me)
        end)

        it(
            "retains live peers across repeated leave/rejoin cycles without old instances",
            function()
                local me = { UserId = 1, DisplayName = "You" }
                local stable = { UserId = 2, DisplayName = "Stable" }
                local watched = { [me] = {}, [stable] = {} }
                for _ = 1, 100 do
                    local old = { UserId = 3, DisplayName = "Returning" }
                    watched[old] = {}
                    expect(#PeopleList.orderedRoster(watched, me)).to.equal(3)
                    watched[old] = nil
                    local replacement = { UserId = 3, DisplayName = "Returning" }
                    watched[replacement] = {}
                    local roster = PeopleList.orderedRoster(watched, me)
                    expect(#roster).to.equal(3)
                    expect(roster[1]).to.equal(me)
                    expect(roster[2]).to.equal(replacement)
                    expect(roster[3]).to.equal(stable)
                    watched[replacement] = nil
                end
            end
        )

        it("sorts equal display names deterministically and tolerates an empty roster", function()
            local a = { UserId = 3, DisplayName = "SAME" }
            local b = { UserId = 2, DisplayName = "same" }
            local me = { UserId = 1, DisplayName = "You" }
            local roster = PeopleList.orderedRoster({ [a] = {}, [b] = {} }, me)
            expect(roster[1]).to.equal(b)
            expect(roster[2]).to.equal(a)
            expect(#PeopleList.orderedRoster({}, me)).to.equal(0)
        end)
    end)

    describe("Combat Training list default", function()
        it("collapses once, allows expansion, and restores the previous setting", function()
            local expanded, previous = PeopleList.trainingExpansion(true, nil, true, true)
            expect(expanded).to.equal(false)
            expect(previous).to.equal(true)
            expanded, previous = PeopleList.trainingExpansion(true, previous, true, true)
            expect(expanded).to.equal(true)
            expanded, previous = PeopleList.trainingExpansion(expanded, previous, false, true)
            expect(expanded).to.equal(true)
            expect(previous).to.equal(nil)
        end)
        it("preserves an already collapsed list outside training", function()
            local expanded, previous = PeopleList.trainingExpansion(false, nil, true, true)
            expect(previous).to.equal(false)
            expanded, previous = PeopleList.trainingExpansion(true, previous, false, true)
            expect(expanded).to.equal(false)
            expect(previous).to.equal(nil)
            expanded = PeopleList.trainingExpansion(true, nil, true, false)
            expect(expanded).to.equal(true)
        end)
    end)
    describe("people_list config", function()
        it("replaces CoreGui and keeps the measured column", function()
            local people = cfg()
            expect(people.enabled).to.equal(true)
            expect(people.disable_core_player_list).to.equal(true)
            expect(people.layout.modes.phone.width).to.equal(0.36)
            expect(people.layout.modes.tablet.width).to.equal(0.30)
            expect(people.layout.modes.desktop.width).to.equal(0.221)
            expect(people.layout.merge_wave_gap).to.equal(0.006)
            expect(people.layout.merge_wave_width_ratio).to.equal(1.0)
            expect(people.columns[1].width).to.equal(0.43)
            expect(people.columns[4].width).to.equal(0.20)
            expect(people.toggle.key).to.equal("Tab")
            expect(people.social.report).to.equal(false)
        end)

        it("wires resolved Image ids for adventure and Huge Hatcher crests", function()
            local people = cfg()
            expect(people.inspect.level_titles.Noob.icon).to.equal("rbxassetid://109253922126750")
            expect(people.inspect.level_titles.Legend.icon).to.equal("rbxassetid://98082259621432")
            expect(people.inspect.huge_hatcher_icon).to.equal("rbxassetid://105338046020621")
            expect(people.inspect.leaderboard).to.equal(
                "Current top-100 placement on that world board."
            )
        end)

        it("shows one name badge in owner → staff → founder → VIP order", function()
            local people = cfg()
            expect(people.one_badge).to.equal(true)
            expect(people.prefixes[1].id).to.equal("owner")
            expect(people.prefixes[1].icon.element).to.equal("creator")
            expect(people.prefixes[1].icon.symbol).to.equal("arrow_right")
            expect(people.prefixes[2].id).to.equal("developer")
            expect(people.prefixes[3].id).to.equal("content_creator")
            expect(people.prefixes[4].id).to.equal("tester")
            expect(people.prefixes[5].id).to.equal("founder")
            expect(people.prefixes[5].glyph).to.equal("⭐")
            expect(people.prefixes[6].id).to.equal("vip")
            expect(#people.prefixes).to.equal(6)
            expect(people.roles.owner_user_ids[1]).to.equal(3200870803)
            expect(#people.roles.tester_user_ids).to.equal(0)
        end)
    end)

    describe("PeopleList.displayName", function()
        it("shows the founder star instead of the VIP crown", function()
            expect(PeopleList.displayName(cfg(), { vip = true, founder = true }, "Alex")).to.equal(
                "⭐ Alex"
            )
        end)

        it("shows the VIP crown when they are not a founder", function()
            expect(PeopleList.displayName(cfg(), { vip = true }, "Alex")).to.equal("👑 Alex")
        end)

        it("lets the owner Colorado badge override every other mark", function()
            local people = cfg()
            local flags = {
                owner = true,
                developer = true,
                tester = true,
                content_creator = true,
                founder = true,
                vip = true,
            }
            expect(PeopleList.displayName(people, flags, "Jason")).to.equal("Jason")
            local badge = PeopleList.prefix(people, flags)
            expect(badge.id).to.equal("owner")
            expect(badge.icon.element).to.equal("creator")
            expect(badge.icon.symbol).to.equal("arrow_right")
        end)

        it("uses developer ahead of content creator, tester, and VIP", function()
            expect(PeopleList.displayName(cfg(), {
                developer = true,
                content_creator = true,
                tester = true,
                vip = true,
            }, "Dev")).to.equal("🔧 Dev")
        end)

        it("uses content creator ahead of tester and VIP", function()
            expect(PeopleList.displayName(cfg(), {
                content_creator = true,
                tester = true,
                vip = true,
            }, "Kade")).to.equal("🎬 Kade")
        end)
    end)

    describe("PeopleList.hover", function()
        it("shows Noob with the going-somewhere source", function()
            expect(PeopleList.hover(cfg(), ranks(), {
                displayName = "Alex",
                level = 1,
            })).to.equal("Alex, Noob (New but going somewhere!)")
        end)

        it("puts the winning role between the name and Status", function()
            expect(PeopleList.hover(cfg(), ranks(), {
                flags = { owner = true },
                displayName = "Colorado",
                combatRank = "Skilled",
                combatRankId = "skilled",
            })).to.equal("Colorado, Owner, Skilled (Combat Training 1)")
            expect(PeopleList.hover(cfg(), ranks(), {
                flags = { developer = true },
                displayName = "Sploithunter",
                leaderboardTitle = "Farmer",
                leaderboardRank = 16,
                leaderboardHoverTitle = "Farm",
                leaderboardHoverBoard = "Crystal LB",
            })).to.equal("Sploithunter, Dev, Farm #16 (#16 Crystal LB)")
        end)

        it("uses the live farm rank when the worn source is stale", function()
            expect(PeopleList.hover(cfg(), ranks(), {
                displayName = "Tricentennial State",
                chosenTitle = "Farmer",
                chosenKind = "leaderboard",
                chosenSource = "Farmer",
                leaderboardTitle = "Farmer",
                leaderboardRank = 7,
                leaderboardHoverTitle = "Farm",
                leaderboardHoverBoard = "Crystal LB",
                combatRank = "Spark",
                combatRankId = "spark",
            })).to.equal("Tricentennial State, Farm #7 (#7 Crystal LB)")
        end)
    end)

    describe("PeopleList.inspect", function()
        it("explains a combat-training title from the pillar", function()
            local card = PeopleList.inspect(ranks(), cfg(), "kindled", "Kindled")
            expect(card.title).to.equal("Kindled")
            expect(card.body:find("Combat Training", 1, true)).to.be.ok()
            expect(card.body:find("Berserk Brew", 1, true)).to.be.ok()
            expect(card.icon).to.equal("rbxassetid://119300402391304")
        end)

        it("prefers the worn adventure crest over a combat rank", function()
            local card = PeopleList.inspect(ranks(), cfg(), "skilled", "Hero")
            expect(card.title).to.equal("Hero")
            expect(card.icon).to.equal("rbxassetid://103517372435641")
            expect(card.body:find("regular", 1, true)).to.be.ok()
        end)

        it("explains Farmer placement instead of a Spark crest", function()
            local card = PeopleList.inspect(ranks(), cfg(), "spark", "Farmer", {
                chosenTitle = "Farmer",
                chosenKind = "leaderboard",
                chosenSource = "Farmer",
                leaderboardTitle = "Farmer",
                leaderboardRank = 7,
                leaderboardHoverTitle = "Farm",
                leaderboardHoverBoard = "Crystal LB",
                combatRankId = "spark",
            })
            expect(card.title).to.equal("Farmer")
            expect(card.body).to.equal("Farm #7 (#7 Crystal LB)")
            expect(card.icon).to.equal(nil)
        end)
    end)

    describe("PeopleList.topOffset", function()
        local desktop = {
            displayClass = "desktop",
            viewportWidth = 1800,
            viewportHeight = 900,
        }

        it("derives the quest dock from the viewport", function()
            expect(PeopleList.topOffset(cfg(), desktop)).to.equal(62)
        end)

        it("drops under the tutorial capsule while that card is up", function()
            local state = table.clone(desktop)
            state.tutorialOwnsCorner = true
            expect(PeopleList.topOffset(cfg(), state)).to.equal(151)
        end)

        it("drops under the Merge wave bar on the dedicated place", function()
            local merge = table.clone(desktop)
            merge.mergePlace = true
            expect(PeopleList.topOffset(cfg(), merge)).to.equal(102)
            merge.tutorialOwnsCorner = true
            expect(PeopleList.topOffset(cfg(), merge)).to.equal(151)
        end)

        it("docks beneath the live Merge wave meter instead of a guessed top", function()
            local merge = table.clone(desktop)
            merge.mergePlace = true
            merge.mergeWaveBottom = 92
            expect(PeopleList.topOffset(cfg(), merge)).to.equal(97)

            merge.viewportHeight = 361
            merge.mergeWaveBottom = -5
            expect(PeopleList.topOffset(cfg(), merge)).to.equal(0)
        end)

        it("removes the ScreenGui safe-area origin before docking the Merge list", function()
            local bounds = PeopleList.screenGuiLocalBounds({
                viewportWidth = 1835,
                viewportHeight = 869,
                absoluteLeft = 1434,
                absoluteTop = -44,
                width = 397,
                height = 78,
                anchorX = 1,
                anchorY = 0,
                xScale = 1,
                xOffset = -4,
                yScale = 0,
                yOffset = 14,
            })
            expect(bounds.left).to.equal(1434)
            expect(bounds.top).to.equal(14)
            expect(bounds.right).to.equal(1831)
            expect(bounds.bottom).to.equal(92)

            local merge = table.clone(desktop)
            merge.viewportWidth = 1835
            merge.viewportHeight = 869
            merge.mergePlace = true
            merge.mergeWaveBottom = bounds.bottom
            expect(PeopleList.topOffset(cfg(), merge)).to.equal(97)
        end)

        it("inherits the live Merge wave meter footprint on a phone", function()
            local dimensions = PeopleList.layout(cfg(), {
                displayClass = "phone",
                viewportWidth = 750,
                viewportHeight = 380,
                mergePlace = true,
                mergeWaveBottom = -5,
                mergeWaveWidth = 199,
                mergeWaveHeight = 39,
                mergeWaveRight = 746,
            })
            expect(dimensions.widthScale).to.equal(199 / 750)
            expect(dimensions.rightScale).to.equal(4 / 750)
            expect(dimensions.headerHeight).to.equal(12)
            expect(dimensions.columnHeaderHeight).to.equal(8)
            expect(dimensions.rowHeight).to.equal(12)
            expect(dimensions.top).to.equal(0)
        end)

        it("keeps phone and tablet rows proportional to their viewports", function()
            local phone = PeopleList.layout(cfg(), {
                displayClass = "phone",
                viewportWidth = 874,
                viewportHeight = 402,
                mergePlace = true,
            })
            expect(phone.widthScale).to.equal(0.36)
            expect(phone.headerHeight).to.equal(27)
            expect(phone.rowHeight).to.equal(25)
            expect(phone.top).to.equal(52)

            local tablet = PeopleList.layout(cfg(), {
                displayClass = "tablet",
                viewportWidth = 960,
                viewportHeight = 600,
                mergePlace = true,
            })
            expect(tablet.widthScale).to.equal(0.30)
            expect(tablet.headerHeight).to.equal(24)
            expect(tablet.rowHeight).to.equal(22)
            expect(tablet.top).to.equal(69)
        end)
    end)

    describe("PeopleList.shouldShow", function()
        it("stays visible during the tutorial and only hides under full menus", function()
            expect(PeopleList.shouldShow({ largeMenuOpen = true })).to.equal(false)
            expect(PeopleList.shouldShow({ tutorialOwnsCorner = true })).to.equal(true)
            expect(PeopleList.shouldShow({
                tutorialOwnsCorner = true,
                peek = true,
            })).to.equal(true)
            expect(PeopleList.shouldShow({})).to.equal(true)
        end)
    end)

    describe("PeopleList.profile", function()
        it("builds the slide-out copy for Status and Examine Avatar", function()
            local people = cfg()
            expect(people.card.examine_label).to.equal("Examine Avatar")
            expect(people.card.badge_heading).to.equal("How you get this")
            expect(people.card.roles_heading).to.equal("Roles")
            local profile = PeopleList.profile(people, ranks(), {
                displayName = "coloradoplays",
                username = "coloradoplays",
                combatRank = "Skilled",
                combatRankId = "skilled",
            })
            expect(profile.displayName).to.equal("coloradoplays")
            expect(profile.username).to.equal("@coloradoplays")
            expect(profile.examineLabel).to.equal("Examine Avatar")
            expect(profile.badgeHeading).to.equal("How you get this")
            expect(profile.rolesHeading).to.equal("Roles")
            expect(#profile.entitlements).to.equal(0)
            expect(profile.inspect.title).to.equal("Skilled")
            expect(profile.inspect.body:find("Combat Training", 1, true)).to.be.ok()
        end)

        it("explains the worn Legend title instead of Combat Training", function()
            local profile = PeopleList.profile(cfg(), ranks(), {
                displayName = "coloradoplays",
                chosenTitle = "Legend",
                combatRank = "Skilled",
                combatRankId = "skilled",
                level = 50,
            })
            expect(profile.status).to.equal("Legend")
            expect(profile.inspect.title).to.equal("Legend")
            expect(profile.inspect.body:find("Level cap", 1, true)).to.be.ok()
            expect(profile.inspect.body:find("Combat Training", 1, true)).to.equal(nil)
        end)

        it("puts Farm #N on the Farmer card instead of Spark", function()
            local profile = PeopleList.profile(cfg(), ranks(), {
                displayName = "Tricentennial State",
                chosenTitle = "Farmer",
                chosenKind = "leaderboard",
                chosenSource = "Farmer",
                leaderboardTitle = "Farmer",
                leaderboardRank = 7,
                leaderboardHoverTitle = "Farm",
                leaderboardHoverBoard = "Crystal LB",
                combatRank = "Spark",
                combatRankId = "spark",
            })
            expect(profile.status).to.equal("Farm #7")
            expect(profile.inspect.title).to.equal("Farmer")
            expect(profile.inspect.body).to.equal("Farm #7 (#7 Crystal LB)")
            expect(profile.inspect.body:find("first fight", 1, true)).to.equal(nil)
        end)
    end)

    describe("PeopleList.entitlements", function()
        it("lists every role on the card and keeps one mark on the row", function()
            local flags = {
                owner = true,
                developer = true,
                tester = true,
                founder = true,
                vip = true,
            }
            local roles = PeopleList.entitlements(cfg(), flags)
            local ids = {}
            for _, role in ipairs(roles) do
                ids[role.id] = role.label
            end
            expect(ids.owner).to.equal("Owner")
            expect(ids.developer).to.equal("Developer")
            expect(ids.tester).to.equal("Tester")
            expect(ids.founder).to.equal("Founder")
            expect(ids.vip).to.equal(nil)
            expect(PeopleList.displayName(cfg(), flags, "Jason")).to.equal("Jason")
        end)
    end)

    describe("PeopleList.cardPlacement", function()
        it("sits immediately left of the People list column", function()
            local place = PeopleList.cardPlacement(cfg(), {
                displayClass = "desktop",
                viewportWidth = 1800,
                viewportHeight = 900,
            })
            expect(place.top).to.equal(62)
            expect(place.rightScale).to.be.near(0.2277, 1e-6)
            expect(place.widthScale).to.equal(0.127)
        end)
    end)

    describe("PeopleList.hoverPlacement", function()
        it("docks left of the name column at the hovered row", function()
            local place = PeopleList.hoverPlacement(cfg(), {
                displayClass = "desktop",
                viewportWidth = 1800,
                viewportHeight = 900,
            }, 33)
            expect(place.rightScale).to.be.near(0.2277, 1e-6)
            expect(place.top).to.equal(95)
        end)
    end)

    describe("PeopleList.row", function()
        it("keeps Rank/Status/Location and clickable Status inspect", function()
            local row = PeopleList.row(cfg(), ranks(), {
                flags = { vip = true },
                displayName = "Alex",
                level = 1,
                combatRank = "Spark",
                combatRankId = "spark",
                layer = "base",
                area = "Spawn",
            })
            expect(row.name).to.equal("👑 Alex")
            expect(row.rank).to.equal("1")
            expect(row.status).to.equal("Spark")
            expect(row.location).to.equal("Home")
            expect(row.inspect.body:find("first fight", 1, true)).to.be.ok()
            expect(PlayerListStatus.status({ vip = true, combatRank = "Spark" })).to.equal("Spark")
        end)

        it("uses claimed rank and leaves it blank before ascension is introduced", function()
            local hidden = PeopleList.row(cfg(), ranks(), {
                displayName = "New Player",
                level = 1,
                ascensionUnlocked = false,
            })
            expect(hidden.rank).to.equal("")

            local unlocked = PeopleList.row(cfg(), ranks(), {
                displayName = "Trained Player",
                level = 3,
                ascensionUnlocked = true,
            })
            expect(unlocked.rank).to.equal("3")
        end)
    end)

    describe("wiring", function()
        it("starts the client list and publishes role attributes", function()
            local client = readFile("src/Client/init.client.lua")
            expect(client:find("PeopleListController", 1, true)).to.be.ok()
            local controller = readFile("src/Client/Systems/PeopleListController.lua")
            expect(controller:find("inst.TextScaled = true", 1, true)).to.be.ok()
            expect(controller:find("absoluteAnchorYOffset", 1, true)).to.be.ok()
            expect(controller:find("mergeWaveBottom", 1, true)).to.be.ok()
            expect(controller:find("mergeWaveWidth", 1, true)).to.be.ok()
            expect(controller:find("mergeWaveRight", 1, true)).to.be.ok()
            expect(controller:find("farmUpperSurfaceBottomScale", 1, true)).to.equal(nil)
            expect(controller:find("UpperRightHudStack.mount", 1, true)).to.be.ok()
            expect(controller:find("UpperRightHudStack.PEOPLE_LIST_ORDER", 1, true)).to.be.ok()
            expect(controller:find("UpperRightHudStack.setRightPadding", 1, true)).to.be.ok()
            expect(controller:find("root.Visible = allowed", 1, true)).to.be.ok()
            expect(controller:find('headerLabel.Text = "Players"', 1, true)).to.be.ok()
            expect(controller:find('("Players  %d"):format(count)', 1, true)).to.equal(nil)
            expect(controller:find('GetAttribute("ClaimedLevel")', 1, true)).to.be.ok()
            expect(controller:find('GetAttribute("AscensionUnlocked")', 1, true)).to.be.ok()
            expect(controller:find("PromptSendFriendRequest", 1, true)).to.be.ok()
            expect(controller:find("PromptBlockPlayer", 1, true)).to.be.ok()
            expect(controller:find("Examine Avatar", 1, true)).to.be.ok()
            expect(controller:find("How you get this", 1, true)).to.be.ok()
            expect(controller:find("RolesHeading", 1, true)).to.be.ok()
            expect(controller:find("profile.entitlements", 1, true)).to.be.ok()
            expect(controller:find('GetAttribute("StatusBadgeLabel")', 1, true)).to.be.ok()
            expect(controller:find('GetAttribute("LeaderboardStatusRank")', 1, true)).to.be.ok()
            expect(controller:find("character:Clone", 1, true)).to.be.ok()
            expect(controller:find("InspectPlayerFromUserId", 1, true)).to.equal(nil)
            expect(controller:find("PeopleListToggle", 1, true)).to.be.ok()
            expect(controller:find("PeopleList.layout", 1, true)).to.be.ok()
            expect(controller:find("mergePlace = isMergePlace()", 1, true)).to.be.ok()
            expect(controller:find("PeopleList.hoverPlacement", 1, true)).to.be.ok()
            expect(controller:find('GetPropertyChangedSignal("ViewportSize")', 1, true)).to.be.ok()
            expect(controller:find("dimensions.widthScale", 1, true)).to.be.ok()
            expect(controller:find("config.width", 1, true)).to.equal(nil)
            expect(controller:find("DisplayOrder = 92", 1, true)).to.be.ok()
            expect(controller:find("HoverTip", 1, true)).to.be.ok()
            local admin = readFile("src/Server/Services/AdminService.lua")
            expect(admin:find('SetAttribute("IsOwner"', 1, true)).to.be.ok()
            expect(admin:find('SetAttribute("IsBetaTester"', 1, true)).to.be.ok()
            expect(admin:find("tester_user_ids", 1, true)).to.be.ok()
            local creators = readFile("src/Server/Services/MeetCreatorService.lua")
            expect(creators:find('SetAttribute("IsCreator"', 1, true)).to.be.ok()
            local testers = readFile("src/Server/Services/TesterRewardService.lua")
            expect(testers:find('SetAttribute("IsBetaTester"', 1, true)).to.equal(nil)
        end)
    end)
end
