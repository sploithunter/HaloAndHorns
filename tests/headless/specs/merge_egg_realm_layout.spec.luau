local Layout = loadModule("src/Shared/Game/MergeEggRealmLayout.lua")

return function()
    describe("Merge Egg ten-bay realm layout", function()
        local config = {
            bays_per_side = 5,
            bay_pitch = 112,
            bay_depth = 300,
            corridor_gap = 220,
            center_x = -16000,
            center_z = -325,
        }

        it("places five Heaven bays opposite five Hell bays around a real center gap", function()
            local bays = Layout.bays(config)
            expect(#bays).to.equal(10)
            expect(bays[1].id).to.equal("heaven_01")
            expect(bays[5].id).to.equal("heaven_05")
            expect(bays[6].id).to.equal("hell_01")
            expect(bays[10].id).to.equal("hell_05")
            expect(bays[3].centerX).to.equal(-16000)
            expect(bays[3].centerZ).to.equal(-65)
            expect(bays[3].yawDegrees).to.equal(0)
            expect(bays[8].centerX).to.equal(-16000)
            expect(bays[8].centerZ).to.equal(-585)
            expect(bays[8].yawDegrees).to.equal(180)
        end)

        it("allocates only unclaimed bays and reports a full realm", function()
            local occupied = {
                heaven_01 = true,
                heaven_02 = true,
            }
            expect(Layout.pickAvailable(config, occupied, 0).id).to.equal("heaven_03")
            expect(Layout.pickAvailable(config, occupied, 0.999).id).to.equal("hell_05")
            for _, bay in ipairs(Layout.bays(config)) do
                occupied[bay.id] = true
            end
            expect(Layout.pickAvailable(config, occupied, 0.5)).to.equal(nil)
        end)
    end)
end
