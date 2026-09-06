local ConfigSchemas = loadModule("src/Shared/ConfigSchemas.lua")

return function()
    describe("ConfigSchemas", function()
        it("registers the host monitor JSON that Rojo exposes as a runtime config", function()
            local cfg = {
                sample_seconds = 0.5,
                maximum_seconds = 180,
                maximum_footprint_gib = 8,
                maximum_growth_gib = 2,
                maximum_start_footprint_gib = 6,
                maximum_pressure_level = 1,
                studio_executable = "/test/Studio",
            }
            expect(ConfigSchemas.validate("merge_stress_host", cfg)).to.equal(true)
            cfg.sample_seconds = "invalid"
            expect(ConfigSchemas.validate("merge_stress_host", cfg)).to.equal(false)
        end)
        it("accepts a config matching its declared required shape", function()
            local ok = ConfigSchemas.validate("soul", {
                delta_per_conquest = 5,
                range = { min = -100, max = 100 },
                bands = {},
            })
            expect(ok).to.equal(true)
        end)

        it("reports the config path and expected type", function()
            local ok, err = ConfigSchemas.validate("soul", {
                delta_per_conquest = "five",
                range = {},
                bands = {},
            })
            expect(ok).to.equal(false)
            expect(string.find(err, "configs/soul.lua:delta_per_conquest", 1, true) ~= nil).to.equal(
                true
            )
            expect(string.find(err, "expected number, got string", 1, true) ~= nil).to.equal(true)
        end)

        it("fails closed for an unregistered config", function()
            local ok, err = ConfigSchemas.validate("future_config", {})
            expect(ok).to.equal(false)
            expect(string.find(err, "has no explicit schema", 1, true) ~= nil).to.equal(true)
        end)

        it("validates the Builder's Cut overlay contract", function()
            local ok, err = ConfigSchemas.validate("showcase", loadModule("configs/showcase.lua"))
            if not ok then
                error(err)
            end
            expect(ok).to.equal(true)
        end)

        it("validates the internal-accounts identity list", function()
            local ok, err = ConfigSchemas.validate(
                "internal_accounts",
                loadModule("configs/internal_accounts.lua")
            )
            if not ok then
                error(err)
            end
            expect(ok).to.equal(true)
        end)
    end)
end
