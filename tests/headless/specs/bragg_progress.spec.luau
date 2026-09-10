local Progress = loadModule("src/Server/Services/BraggProgress.lua")
local cfg = loadModule("configs/leaderboards.lua").bragg_tracking
return function()
    describe("Bragg durable recognition", function()
        it("counts distinct clears, preserves highest, and ignores duplicate receipts", function()
            local data = {}
            Progress.apply(data, cfg, "wave", "attempt-a", 12, "online")
            Progress.apply(data, cfg, "wave", "attempt-a", 12, "online")
            Progress.apply(data, cfg, "wave", "attempt-b", 5, "offline")
            expect(data.Stats.Counters.siege_waves_cleared).to.equal(2)
            expect(data.Stats.Counters.siege_highest_wave_cleared).to.equal(12)
            expect(data.GameData.BraggProgress.offline.wave).to.equal(1)
        end)
        it("retains receipts with profile data across reloads and does not backfill", function()
            local data = { GameData = { MergeDefense = { highest_wave = 99 } } }
            Progress.apply(data, cfg, "boss", "defeat-a", nil, "online")
            Progress.apply(data, cfg, "boss", "defeat-a", nil, "offline")
            expect(data.Stats.Counters.bosses_defeated).to.equal(1)
            expect(data.Stats.Counters.siege_highest_wave_cleared).to.equal(nil)
        end)
        it("rejects failures, invalid waves, and bounds receipt storage", function()
            local data = {}
            expect(Progress.apply(data, cfg, "escaped", "x", 4)).to.equal(nil)
            expect(Progress.apply(data, cfg, "wave", "x", 0)).to.equal(nil)
            local small = table.clone(cfg)
            small.receipt_limit = 2
            for i = 1, 3 do
                Progress.apply(data, small, "boss", "boss-" .. i)
            end
            expect(#data.GameData.BraggProgress.receipts).to.equal(2)
            expect(data.Stats.Counters.bosses_defeated).to.equal(3)
        end)
    end)
end
