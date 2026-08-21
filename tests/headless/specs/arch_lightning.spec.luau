local ArchLightning = loadModule("src/Shared/Game/ArchLightning.lua")
local hall = loadModule("configs/hall_of_worlds.lua")
local sounds = loadModule("configs/sounds.lua")

return function()
    describe("arch lightning", function()
        it(
            "covers every authored Hall arch and uses the supplied quiet positional sound",
            function()
                local cfg = hall.arch_lightning
                expect(cfg.enabled).to.equal(true)
                expect(#cfg.host_names).to.equal(6)

                local expectedHosts = {
                    TrainingGroundPadGateVisual = true,
                    RangePadGateVisual = true,
                    CrystalWorldGateVisual = true,
                    CrystalWorldReturnGateVisual = true,
                    HallOfWorldsGateVisual = true,
                    HellFaceGateTest = true,
                }
                for _, hostName in ipairs(cfg.host_names) do
                    expect(expectedHosts[hostName]).to.equal(true)
                    expectedHosts[hostName] = nil
                end
                expect(next(expectedHosts)).never.to.be.ok()

                local sound = sounds[cfg.sound.name]
                expect(sound.id).to.equal("rbxassetid://80802960194213")
                expect(sound.duration_seconds).to.equal(0.48)
                expect(cfg.sound.volume <= 0.12).to.equal(true)
                expect(cfg.sound.interval_min >= sound.duration_seconds).to.equal(true)
                expect(cfg.sound.roll_off_max_distance).to.equal(60)
            end
        )

        it("recognizes numbered markers and chooses opposite arch jambs", function()
            expect(ArchLightning.isMarkerName("lightning18", "lightning")).to.equal(true)
            expect(ArchLightning.isMarkerName("lightning", "lightning")).to.equal(false)
            expect(ArchLightning.isMarkerName("lightningX", "lightning")).to.equal(false)

            local points = {
                { x = -10, y = 0, z = 0 },
                { x = -10, y = 10, z = 0 },
                { x = 10, y = 0, z = 0 },
                { x = 10, y = 10, z = 0 },
            }
            local i, j = ArchLightning.pickPair(points, true, nil, 8)
            expect(i).to.be.ok()
            expect(j).to.be.ok()
            expect(math.abs(points[i].x - points[j].x) >= 8).to.equal(true)

            local sampled = ArchLightning.sampleArchPoints(30, 36, 9)
            expect(#sampled).to.equal(18)
        end)

        it(
            "boots the client runtime and keeps rapid bolts separate from positional audio",
            function()
                local initSource = readFile("src/Client/init.client.lua")
                local clientSource = readFile("src/Client/Systems/ArchLightning.lua")
                expect(string.find(initSource, "Systems.ArchLightning", 1, true)).to.be.ok()
                expect(string.find(clientSource, 'boltCfg.sound_name = "_silent"', 1, true)).to.be.ok()
                expect(string.find(clientSource, "SoundGroups.assign", 1, true)).to.be.ok()
                expect(string.find(clientSource, "sound.Parent = parent", 1, true)).to.be.ok()
                expect(string.find(clientSource, "RollOffMaxDistance", 1, true)).to.be.ok()
            end
        )
    end)
end
