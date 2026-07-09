--[[
    Config VALIDATION — [guardrail] runs the REAL shared schema rules in CI,
    not hand-ported copies (config_integrity Part 2's admitted drift problem).

    Born from the 2026-07-09 double boot-crash: mission pseudo-zones passed
    require-time integrity but died at ConfigLoader's areas validator, were
    fixed, then died AGAIN at WorldBindingService's separate kind allowlist.
    Rule extracted to src/Shared/Game/ZoneSchema.lua (pure); this spec runs
    it against the live config — the same code both boot gates now call.

    PATTERN for future validators: extract the pure shape rules into
    Shared/Game/<X>Schema.lua, delegate from ConfigLoader/services, sweep here.
]]

local ZoneSchema = loadModule("src/Shared/Game/ZoneSchema.lua")

return function()
    describe("ZoneSchema vs configs/areas.lua (the real boot rules, in CI)", function()
        local areas = loadModule("configs/areas.lua")

        it("every zone passes the shared schema (id/key/kind/parent)", function()
            local ok, err = ZoneSchema.validateZones(areas.zones)
            if not ok then
                error("boot would CRASH: " .. tostring(err))
            end
            expect(ok).to.equal(true)
        end)

        it("mission pseudo-zones carry elements (branding contract)", function()
            for zoneId, zone in pairs(areas.zones) do
                if zone.kind == "mission" then
                    expect(type(zone.element)).to.equal("string")
                    local _ = zoneId
                end
            end
        end)

        it("rejects a kind outside the ONE allowlist", function()
            local bad = { x = { id = "x", kind = "nonsense" } }
            local ok = ZoneSchema.validateZones(bad)
            expect(ok).to.equal(false)
        end)

        it("rejects id/key mismatch and missing parent", function()
            expect(ZoneSchema.validateZones({ x = { id = "y", kind = "area" } })).to.equal(false)
            expect(
                ZoneSchema.validateZones({ x = { id = "x", kind = "area", parent = "ghost" } })
            ).to.equal(false)
        end)
    end)
end
