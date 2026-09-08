local VoiceVolume = loadModule("src/Shared/Effects/VoiceVolume.lua")
local config = loadModule("configs/audio.lua")
local watcher = loadModule("configs/merge_egg_prototype.lua").watcher

return function()
    describe("Voices volume preference", function()
        it("maps off, default 50, and maximum 100 to the requested gains", function()
            expect(VoiceVolume.gain(0, config.voices)).to.equal(0)
            expect(VoiceVolume.gain(nil, config.voices)).to.equal(1)
            expect(VoiceVolume.gain(0.5, config.voices)).to.equal(1)
            expect(VoiceVolume.gain(1, config.voices)).to.equal(4)
            expect(VoiceVolume.gain(0.25, config.voices)).to.equal(0.25)
            expect(VoiceVolume.gain(0.75, config.voices)).to.equal(2.25)
        end)

        it("preserves mute and migrates missing or non-finite profile values to 50", function()
            expect(VoiceVolume.level(0, config.voices)).to.equal(0)
            for _, value in { "invalid", false, 0 / 0, math.huge, -math.huge } do
                expect(VoiceVolume.level(value, config.voices)).to.equal(0.5)
            end
            expect(VoiceVolume.level(nil, config.voices)).to.equal(0.5)
            expect(VoiceVolume.level(-10, config.voices)).to.equal(0)
            expect(VoiceVolume.level(10, config.voices)).to.equal(1)
        end)

        it("increases smoothly without exceeding the voice bus limit", function()
            local previous = -1
            for level = 0, 100 do
                local gain = VoiceVolume.gain(level / 100, config.voices)
                expect(gain >= previous).to.equal(true)
                expect(gain <= config.buses.voices.maximum_volume).to.equal(true)
                previous = gain
            end
            expect(config.buses.effects.maximum_volume).to.equal(1)
            expect(config.buses.music.maximum_volume).to.equal(1)
            expect(config.buses.ui.maximum_volume).to.equal(1)
        end)

        it(
            "routes existing voices to the new bus while retaining the approved character balance",
            function()
                expect(watcher.voice.bus).to.equal("voices")
                expect(watcher.voice.volume).to.equal(1.2)
                expect(watcher.themes.hell.voice.volume).to.equal(2.34)
                expect(watcher.voice.ducking.gains_db.voices).to.equal(nil)
            end
        )
    end)
end
