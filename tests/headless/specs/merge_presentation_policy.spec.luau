local Policy = loadModule("src/Shared/Game/MergePresentationPolicy.lua")
local bays = {}
for _, side in ipairs({ "heaven", "hell" }) do
    for col = 1, 5 do
        bays[#bays + 1] = {
            id = side .. col,
            side = side,
            column = col,
            x = side == "heaven" and 215 or -215,
            z = (col - 3) * 136,
        }
    end
end
return function()
    describe("Merge character-location presentation", function()
        it("follows the visited bay rather than any claimed bay", function()
            local focus = Policy.nearest(bays, -215, 0, "heaven1", 16)
            expect(focus.id).to.equal("hell3")
            expect(Policy.detailed(focus, bays[1], 1)).to.equal(false)
            expect(Policy.detailed(focus, bays[8], 1)).to.equal(true)
        end)
        it("shows only the current side's immediate neighbors", function()
            local focus = bays[3]
            for i, bay in ipairs(bays) do
                expect(Policy.detailed(focus, bay, 1)).to.equal(i >= 2 and i <= 4)
            end
        end)
        it("switches neighborhood as the character walks along the same side", function()
            local focus = Policy.nearest(bays, 215, 136, "heaven3", 16)
            expect(focus.id).to.equal("heaven4")
            expect(Policy.detailed(focus, bays[2], 1)).to.equal(false)
            expect(Policy.detailed(focus, bays[5], 1)).to.equal(true)
        end)
        it("uses hysteresis near the mall centerline and switches after crossing", function()
            expect(Policy.nearest(bays, -1, 0, "heaven3", 16).id).to.equal("heaven3")
            expect(Policy.nearest(bays, -20, 0, "heaven3", 16).id).to.equal("hell3")
        end)
        it("fails open for unavailable bay metadata", function()
            expect(Policy.nearest({}, 0, 0, nil, 16)).to.equal(nil)
            expect(Policy.detailed(nil, bays[1], 1)).to.equal(true)
            expect(Policy.detailed(bays[1], nil, 1)).to.equal(true)
        end)
        it("does not resolve client focus from player ownership attributes", function()
            local source = readFile("src/Client/Systems/MergeBayPresentation.lua")
            expect(source:find('player:GetAttribute("MergeEggBayId")', 1, true)).to.equal(nil)
            expect(source:find("local position = root.Position", 1, true) ~= nil).to.equal(true)
        end)
        it("never treats spawning, marching or healing as distant combat activity", function()
            expect(Policy.summaryActivity(false, nil, 100, false)).to.equal(false)
            expect(Policy.summaryActivity(false, nil, 80, false)).to.equal(false)
            expect(Policy.summaryActivity(false, 100, 100, false)).to.equal(false)
            expect(Policy.summaryActivity(false, 80, 100, false)).to.equal(false)
        end)
        it("requires observed damage and never summarizes a nearby detailed actor", function()
            expect(Policy.summaryActivity(false, 100, 80, false)).to.equal(true)
            expect(Policy.summaryActivity(true, 100, 80, false)).to.equal(false)
            expect(Policy.summaryActivity(false, 100, 80, true)).to.equal(false)
            expect(Policy.summaryActivity(false, 100, nil, false)).to.equal(false)
        end)
        it("replaces the health snapshot instead of retaining departed enemies", function()
            local source = readFile("src/Client/Systems/MergeBayPresentation.lua")
            expect(source:find("local currentHealth = {}", 1, true) ~= nil).to.equal(true)
            expect(source:find("previousHealth = currentHealth", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
