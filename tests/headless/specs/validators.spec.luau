--[[
    Headless unit tests for Validators (pure arg validation).

    Run: mise run test-headless
]]

local Validators = loadModule("src/Shared/API/Validators.lua")

return function()
    describe("Validators.fields", function()
        it("accepts valid args", function()
            local ok = Validators.fields({ upgradeId = "speed" }, { upgradeId = "string" })
            expect(ok).to.equal(true)
        end)

        it("rejects non-table args", function()
            local ok, err = Validators.fields("nope", { a = "string" })
            expect(ok).to.equal(false)
            expect(err).to.equal("arguments must be a table")
        end)

        it("flags a missing required field", function()
            local ok, err = Validators.fields({}, { zoneId = "string" })
            expect(ok).to.equal(false)
            expect(err).to.equal('missing required field "zoneId"')
        end)

        it("allows an absent optional field", function()
            local ok = Validators.fields({}, { note = { type = "string", optional = true } })
            expect(ok).to.equal(true)
        end)

        it("enforces string type", function()
            local ok, err = Validators.fields({ zoneId = 5 }, { zoneId = "string" })
            expect(ok).to.equal(false)
            expect(err).to.equal('"zoneId" must be a string')
        end)

        it("enforces oneOf for strings", function()
            local rule = { type = "string", oneOf = { "single", "max", "auto" } }
            expect(Validators.fields({ mode = "max" }, { mode = rule })).to.equal(true)
            local ok, err = Validators.fields({ mode = "nope" }, { mode = rule })
            expect(ok).to.equal(false)
            expect(err).to.equal('"mode" must be one of: single, max, auto')
        end)

        it("enforces integer type and range", function()
            local rule = { type = "int", min = 1, max = 99 }
            expect(Validators.fields({ count = 3 }, { count = rule })).to.equal(true)

            local notInt = select(2, Validators.fields({ count = 2.5 }, { count = rule }))
            expect(notInt).to.equal('"count" must be an integer')

            local tooLow = select(2, Validators.fields({ count = 0 }, { count = rule }))
            expect(tooLow).to.equal('"count" must be >= 1')

            local tooHigh = select(2, Validators.fields({ count = 100 }, { count = rule }))
            expect(tooHigh).to.equal('"count" must be <= 99')
        end)

        it("enforces boolean type", function()
            expect(Validators.fields({ on = true }, { on = "boolean" })).to.equal(true)
            local ok = Validators.fields({ on = "yes" }, { on = "boolean" })
            expect(ok).to.equal(false)
        end)

        it("enforces table type", function()
            expect(Validators.fields({ list = { 1, 2 } }, { list = "table" })).to.equal(true)
            local ok = Validators.fields({ list = 5 }, { list = "table" })
            expect(ok).to.equal(false)
        end)
    end)

    describe("Validators single-value checks", function()
        it("isString / isInt", function()
            expect(Validators.isString("x")).to.equal(true)
            expect(Validators.isString(1)).to.equal(false)
            expect(Validators.isInt(4)).to.equal(true)
            expect(Validators.isInt(4.5)).to.equal(false)
            expect(Validators.isInt("4")).to.equal(false)
        end)
    end)
end
