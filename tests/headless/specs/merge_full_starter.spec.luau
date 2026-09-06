local Runtime = loadModule("src/Server/Services/MergeFullStarterRuntime.lua")
local Config = loadModule("configs/merge_egg_prototype.lua")

local function fixture()
    local player = { Name = "isolated" }
    local record = { player = player, playerCombatMode = "full" }
    local data = { GameData = {} }
    local observed = { added = {}, rolls = {}, fills = 0, flushes = 0, events = {} }
    local service = {
        _config = Config,
        _dataService = {
            GetData = function()
                return data
            end,
        },
        _isRecordActive = function(_, r)
            return r == record and not r.ended
        end,
        _buildHatchSource = function(_, _, egg)
            return { eggId = egg, hatchPlayerData = { firstHatchLuck = 2 } }
        end,
        _petsConfig = {
            simulateHatch = function(egg, snapshot)
                table.insert(observed.rolls, { egg = egg, luck = snapshot.firstHatchLuck })
                snapshot.firstHatchLuck = nil
                return { pet = "bunny", variant = "golden" }
            end,
        },
        _petGrantService = {
            BuildPetData = function(_, request)
                if observed.beforeBuild then
                    observed.beforeBuild()
                end
                return { id = request.petType, variant = request.variant }
            end,
        },
        _inventoryService = {
            AddItem = function(_, _, bucket, pet, opts)
                assert(bucket == "pets" and opts.deferFlush)
                if observed.failAt == #observed.added + 1 then
                    return nil
                end
                table.insert(observed.added, pet)
                return "pet-" .. #observed.added
            end,
            FlushBucket = function()
                observed.flushes += 1
            end,
            FillEmptyPetSlots = function(_, _, refs)
                observed.fills += 1
                observed.filled = table.clone(refs)
            end,
        },
        _analytics = function(_, _, event)
            table.insert(observed.events, event)
        end,
        _log = function() end,
    }
    return service, record, data, observed
end

return function()
    describe("Full mode welcome pets", function()
        it("gives all four Earth rolls a fresh 50x starter boost", function()
            local s, r, d, o = fixture()
            expect(Runtime.grant(s, r)).to.equal(true)
            expect(#o.added).to.equal(4)
            expect(#d.GameData.MergeFullStarterPets.refs).to.equal(4)
            for _, roll in ipairs(o.rolls) do
                expect(roll.egg).to.equal("grass_egg")
                expect(roll.luck).to.equal(50)
            end
            expect(o.flushes).to.equal(1)
            expect(o.fills).to.equal(1)
            expect(#o.filled).to.equal(4)
        end)
        it("never repeats across mode switches, rebirth or replacement bay", function()
            local s, r, d, o = fixture()
            Runtime.grant(s, r)
            r.playerCombatMode = "simple"
            Runtime.grant(s, r)
            r.playerCombatMode = "full"
            d.GameData.MergeDefense = { rebirths = 1 }
            Runtime.grant(s, r)
            expect(#o.added).to.equal(4)
            expect(o.fills).to.equal(1)
        end)
        it("commits partial progress and retries only the missing pets", function()
            local s, r, d, o = fixture()
            o.failAt = 3
            expect(Runtime.grant(s, r)).to.equal(false)
            expect(#d.GameData.MergeFullStarterPets.refs).to.equal(2)
            expect(o.flushes).to.equal(1)
            o.failAt = nil
            expect(Runtime.grant(s, r)).to.equal(true)
            expect(#o.added).to.equal(4)
            expect(#o.events).to.equal(1)
        end)
        it("never grants for Simple mode, offline actors or ended bays", function()
            local s, r, d, o = fixture()
            r.player.OfflineActor = true
            expect(Runtime.grant(s, r)).to.equal(false)
            r.player.OfflineActor = nil
            r.playerCombatMode = "simple"
            expect(Runtime.grant(s, r)).to.equal(false)
            r.playerCombatMode, r.ended = "full", true
            expect(Runtime.grant(s, r)).to.equal(false)
            expect(#o.added).to.equal(0)
            expect(d.GameData.MergeFullStarterPets).to.equal(nil)
        end)
        it("rejects a reset while serial building yields and releases the busy guard", function()
            local s, r, d, o = fixture()
            o.beforeBuild = function()
                d.GameData.MergeFullStarterPets = nil
            end
            expect(Runtime.grant(s, r)).to.equal(false)
            expect(#o.added).to.equal(0)
            o.beforeBuild = nil
            expect(Runtime.grant(s, r)).to.equal(true)
            expect(#o.added).to.equal(4)
        end)
        it("blocks reentrant grant callbacks", function()
            local s, r, _, o = fixture()
            o.beforeBuild = function()
                expect(Runtime.grant(s, r)).to.equal(false)
            end
            expect(Runtime.grant(s, r)).to.equal(true)
            expect(#o.added).to.equal(4)
        end)
    end)
end
