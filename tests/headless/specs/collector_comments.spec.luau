local Policy = loadModule("src/Shared/Game/CollectorCommentPolicy.lua")
local config = loadModule("configs/collector_voice.lua")
return function()
    describe("Collector comments", function()
        it("requires confirmed non-ownership and no effective or previous entitlement", function()
            expect(Policy.eligible(false, false, false)).to.equal(true)
            expect(Policy.eligible(nil, false, false)).to.equal(false)
            expect(Policy.eligible(true, false, false)).to.equal(false)
            expect(Policy.eligible(false, true, false)).to.equal(false)
            expect(Policy.eligible(false, false, true)).to.equal(false)
        end)
        it("counts only eligible manual coins and bounds notifications", function()
            local s = {}
            for _ = 1, 100 do
                expect(Policy.pickup(s, 1, false, true, "coins", config)).to.equal(false)
                expect(Policy.pickup(s, 1, true, false, "coins", config)).to.equal(false)
                expect(Policy.pickup(s, 1, true, true, "gems", config)).to.equal(false)
            end
            expect(s.pickups).to.equal(nil)
            for n = 1, config.max_notifications do
                local t = n * config.notification_interval_seconds
                for _ = 1, config.manual_pickups - 1 do
                    expect(Policy.pickup(s, t, true, true, "coins", config)).to.equal(false)
                end
                expect(Policy.pickup(s, t, true, true, "coins", config)).to.equal(true)
            end
            for _ = 1, 100 do
                expect(Policy.pickup(s, 99999, true, true, "coins", config)).to.equal(false)
            end
            expect(s.notifications).to.equal(config.max_notifications)
            local throttled = { pickups = config.manual_pickups, nextAt = 100 }
            expect(Policy.pickup(throttled, 99, true, true, "coins", config)).to.equal(false)
            expect(Policy.pickup(throttled, 100, true, true, "coins", config)).to.equal(true)
        end)
        it("binds both characters in all three languages", function()
            local catalog = loadModule("src/Shared/Game/TutorialVoiceDirector.lua").catalog(config)
            for speaker, cue in pairs(config.cues) do
                expect(catalog[cue].speaker).to.equal(speaker)
                for _, assets in { config.clips, config.locales.es, config.locales["pt-br"] } do
                    expect(assets[cue].asset_id > 0).to.equal(true)
                    expect(assets[cue].seconds > 0).to.equal(true)
                end
            end
        end)
    end)
end
