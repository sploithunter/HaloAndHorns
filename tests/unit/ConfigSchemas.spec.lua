return function()
    local ConfigSchemas = require(game.ReplicatedStorage.Shared.ConfigSchemas)

    describe("ConfigSchemas", function()
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
    end)
end
