local Ladder = loadModule("src/Shared/Game/TrialEggRewardLadder.lua")

return function()
    local track = {
        award_id = "trial_egg:heaven_ice",
        egg_id = "celestial_egg",
        huge_egg_id = "huge_celestial_egg",
        milestones = {
            {
                clears = 10,
                quest_id = "heaven_ice_10",
                stage = "basic",
                forced_variant = "basic",
                huge_chance = 0.05,
            },
            {
                clears = 25,
                quest_id = "heaven_ice_25",
                stage = "golden",
                forced_variant = "golden",
                huge_chance = 0.05,
            },
            {
                clears = 50,
                quest_id = "heaven_ice_50",
                stage = "rainbow",
                forced_variant = "rainbow",
                huge_chance = 0.05,
            },
            {
                clears = 90,
                quest_id = "heaven_ice_90",
                stage = "charged",
                forced_variant = "rainbow",
                huge_chance = 0.10,
            },
            {
                clears = 100,
                quest_id = "heaven_ice_100",
                stage = "huge",
                huge_chance = 1,
                minimum_level = 50,
            },
        },
    }

    describe("TrialEggRewardLadder", function()
        it("uses one stable award-bound record key", function()
            expect(Ladder.recordKey(track.award_id, 42)).to.equal(
                "trial_reward|trial_egg:heaven_ice|42"
            )
            local record = Ladder.newRecord(track, track.milestones[1], 42, 1000, 1)
            expect(record.award_id).to.equal(track.award_id)
            expect(record.awarded_to_user_id).to.equal(42)
            expect(record.quantity).to.equal(1)
        end)

        it("rejects copied award metadata stored under any other inventory key", function()
            local record = Ladder.newRecord(track, track.milestones[1], 42, 1000, 1)
            local canonical = Ladder.recordKey(track.award_id, 42)
            expect(Ladder.isCanonicalRecordKey(canonical, record, track)).to.equal(true)
            expect(Ladder.isCanonicalRecordKey("egg|copied|1", record, track)).to.equal(false)

            record.awarded_to_user_id = nil
            expect(Ladder.isCanonicalRecordKey(canonical, record, track)).to.equal(false)
        end)

        it("advances only from claimed milestones, not a displayed trial number", function()
            expect(Ladder.earnedStage(track, {}, 50)).to.equal(nil)
            expect(Ladder.earnedStage(track, { heaven_ice_100 = 1 }, 49)).to.equal(nil)
            expect(Ladder.earnedStage(track, { heaven_ice_10 = 1 }, 50).stage).to.equal("basic")
            expect(Ladder.earnedStage(track, {
                heaven_ice_10 = 1,
                heaven_ice_25 = 1,
            }, 50).stage).to.equal("golden")
        end)

        it("freezes under another owner and catches up when returned", function()
            local record = Ladder.newRecord(track, track.milestones[1], 42, 1000, 1)
            local changed = Ladder.applyStage(record, 99, track, track.milestones[4])
            expect(changed).to.equal(false)
            expect(record.trial_reward_stage).to.equal("basic")

            changed = Ladder.applyStage(record, 42, track, track.milestones[4])
            expect(changed).to.equal(true)
            expect(record.trial_reward_stage).to.equal("charged")
            expect(record.variant).to.equal("rainbow")
            expect(record.trial_reward_huge_chance).to.equal(0.10)
        end)

        it("turns the held record into the guaranteed Huge Egg at 100", function()
            local record = Ladder.newRecord(track, track.milestones[4], 42, 1000, 1)
            local changed = Ladder.applyStage(record, 42, track, track.milestones[5])
            expect(changed).to.equal(true)
            expect(record.id).to.equal("huge_celestial_egg")
            expect(record.variant).to.equal("basic")
            expect(record.trial_reward_huge_chance).to.equal(1)
        end)

        it("ships all eight named tracks with validated egg and quest references", function()
            local config = loadModule("configs/trial_rewards.lua")
            local pets = loadModule("configs/pets.lua")
            local quests = loadModule("configs/quests.lua")
            local count = 0
            for _ in pairs(config.tracks) do
                count += 1
            end
            expect(count).to.equal(8)
            expect(Ladder.validate(config, pets, quests)).to.equal(true)
            expect(pets.egg_sources.huge_celestial_egg.huge.chance).to.equal(1)
            expect(pets.egg_sources.huge_obsidian_egg.huge.chance).to.equal(1)
        end)

        it("never reconciles hatched pets and requires permanent-hatch confirmation", function()
            local service = readFile("src/Server/Services/TrialEggRewardService.lua")
            local ui = readFile("src/Client/UI/Menus/InventoryPanel.lua")
            expect(service:find('GetItem(player, "eggs"', 1, true)).to.be.ok()
            expect(service:find("Inventory.pets", 1, true)).to.equal(nil)
            expect(service:find("progression_confirmation_required", 1, true)).to.be.ok()
            expect(service:find("invalid_award_record", 1, true)).to.be.ok()
            expect(service:find("_isCanonicalRecord", 1, true)).to.be.ok()
            expect(ui:find("Hatching Ends This Egg's Progression", 1, true)).to.be.ok()
            expect(ui:find("HOLD TO HATCH PERMANENTLY", 1, true)).to.be.ok()
        end)

        it("clears the ledger under authenticated admin reset", function()
            local admin = readFile("src/Server/Services/AdminToolsService.lua")
            expect(admin:find("GameData.TrialEggRewards = { tracks = {} }", 1, true)).to.be.ok()
        end)
    end)
end
