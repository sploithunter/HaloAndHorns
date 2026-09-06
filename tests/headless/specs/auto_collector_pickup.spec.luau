local Pickup = loadModule("src/Shared/Game/AutoCollectorPickup.lua")
local cfg = loadModule("configs/drops.lua").auto_collector

local function record(kind)
    return {
        kind = kind,
        owner = 42,
        currency = kind == nil and "gems" or nil,
        part = { Parent = {} },
    }
end

return function()
    describe("Auto Collector pickup eligibility", function()
        it("opts currency, enhancements and potions in through configuration", function()
            expect(Pickup.eligible(record(nil), 42, cfg.pickup_kinds)).to.equal(true)
            expect(Pickup.eligible(record("enhancement"), 42, cfg.pickup_kinds)).to.equal(true)
            expect(Pickup.eligible(record("potion"), 42, cfg.pickup_kinds)).to.equal(true)
        end)

        it("keeps boss egg and unknown drop kinds excluded", function()
            expect(Pickup.eligible(record("egg_item"), 42, cfg.pickup_kinds)).to.equal(false)
            expect(Pickup.eligible(record("future_drop"), 42, cfg.pickup_kinds)).to.equal(false)
            local rec = record(nil)
            rec.currency = nil
            expect(Pickup.eligible(rec, 42, cfg.pickup_kinds)).to.equal(false)
        end)

        for _, kind in ipairs({ "enhancement", "potion" }) do
            it("rejects other owners and stale " .. kind .. " targets", function()
                local rec = record(kind)
                expect(Pickup.eligible(rec, 99, cfg.pickup_kinds)).to.equal(false)
                rec.settling = true
                expect(Pickup.eligible(rec, 42, cfg.pickup_kinds)).to.equal(false)
                rec.settling = false
                rec._done = true
                expect(Pickup.eligible(rec, 42, cfg.pickup_kinds)).to.equal(false)
                rec._done = false
                rec.part.Parent = nil
                expect(Pickup.eligible(rec, 42, cfg.pickup_kinds)).to.equal(false)
                rec.part = nil
                expect(Pickup.eligible(rec, 42, cfg.pickup_kinds)).to.equal(false)
            end)
        end

        it("honors per-kind configuration and rejects absent targets", function()
            expect(Pickup.eligible(record("potion"), 42, { currency = true })).to.equal(false)
            expect(Pickup.eligible(nil, 42, cfg.pickup_kinds)).to.equal(false)
        end)

        it("uses the same policy for selection, cached validation and final pickup", function()
            local source = readFile("src/Server/Services/DropService.lua")
            local _, count = source:gsub("AutoCollectorPickup%.eligible%(", "")
            expect(count).to.equal(3)
            expect(source:find("self:_collect(target)", 1, true)).to.be.ok()
            expect(cfg.collect_radius).to.equal(11)
            expect(cfg.entitlement_attribute).to.equal("AutoCollectorEnabled")
        end)
    end)
end
