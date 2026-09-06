local Budget = loadModule("src/Shared/Game/PetPositionRelayBudget.lua")
local cfg = loadModule("configs/pet_follow.lua").replication.observer

return function()
    describe("Pet observer position relay budget", function()
        it("retains full rate nearby and delivers a distant first snapshot", function()
            expect(Budget.shouldSend(1, 1.1, true, cfg)).to.equal(true)
            expect(Budget.shouldSend(nil, 0, false, cfg)).to.equal(true)
        end)
        it("sends ten coarse snapshots versus 100 nearby reports in ten seconds", function()
            local previous, count = nil, 0
            for i = 0, 99 do
                if Budget.shouldSend(previous, i / 10, false, cfg) then
                    previous = i / 10
                    count += 1
                end
            end
            expect(count).to.equal(10)
        end)
        it("restores full rate immediately on entering the relevant area", function()
            expect(Budget.shouldSend(10, 10.1, false, cfg)).to.equal(false)
            expect(Budget.shouldSend(10, 10.1, true, cfg)).to.equal(true)
        end)
        it("preserves full-rate rollback and legacy configuration", function()
            expect(Budget.shouldSend(10, 10.1, false, nil)).to.equal(true)
            expect(Budget.shouldSend(10, 10.1, false, { enabled = false })).to.equal(true)
        end)
        it("has finite authored proximity and refresh settings", function()
            expect(cfg.nearby_radius > 0 and cfg.nearby_radius < math.huge).to.equal(true)
            expect(cfg.distant_interval > 0 and cfg.distant_interval < math.huge).to.equal(true)
        end)
        it("keeps accepted positions authoritative before observer filtering", function()
            local source = readFile("src/Server/Services/PetFollowService.lua")
            local first = assert(source:find("function PetFollowService:_onPetPositions(", 1, true))
            local store = assert(source:find("self._petPos[pet] =", first, true))
            local filter = assert(source:find("PetPositionRelayBudget.shouldSend", first, true))
            expect(store < filter).to.equal(true)
            expect(source:find("valid[#valid + 1] = { pet = pet, cf = cf }", first, true) ~= nil).to.equal(
                true
            )
            expect(source:find("self._relayLastSent[player] = nil", 1, true) ~= nil).to.equal(true)
            expect(source:find("recipients[player] = nil", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
