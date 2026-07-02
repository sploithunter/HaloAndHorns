--[[
    Headless unit tests for CommandBus (the GUI-bypassing dispatch seam).

    Run: mise run test-headless
]]

local CommandBus = loadModule("src/Shared/API/CommandBus.lua")

return function()
    describe("CommandBus", function()
        local bus

        beforeEach(function()
            bus = CommandBus.new()
        end)

        it("dispatches to a registered handler and wraps the result", function()
            bus:register("math.add", {
                handler = function(_, args)
                    return args.a + args.b
                end,
            })

            local envelope = bus:execute({}, "math.add", { a = 2, b = 3 })
            expect(envelope.ok).to.equal(true)
            expect(envelope.result).to.equal(5)
        end)

        it("passes the caller context through to the handler", function()
            local seenOrigin
            bus:register("ctx.echo", {
                handler = function(context)
                    seenOrigin = context.origin
                    return context.player
                end,
            })

            local envelope = bus:execute(
                { player = "tester", origin = CommandBus.Origin.Automation },
                "ctx.echo"
            )
            expect(envelope.ok).to.equal(true)
            expect(envelope.result).to.equal("tester")
            expect(seenOrigin).to.equal("automation")
        end)

        it("defaults origin to Internal and args to an empty table", function()
            local seenOrigin, seenArgsType
            bus:register("defaults.probe", {
                handler = function(context, args)
                    seenOrigin = context.origin
                    seenArgsType = type(args)
                    return true
                end,
            })

            bus:execute(nil, "defaults.probe")
            expect(seenOrigin).to.equal("internal")
            expect(seenArgsType).to.equal("table")
        end)

        it("fails dispatch with unknown_command for an unregistered name", function()
            local envelope = bus:execute({}, "nope.missing")
            expect(envelope.ok).to.equal(false)
            expect(envelope.code).to.equal("unknown_command")
        end)

        it("rejects invalid args via validate with validation_failed", function()
            bus:register("economy.purchaseUpgrade", {
                validate = function(args)
                    if type(args.upgradeId) ~= "string" then
                        return false, "upgradeId must be a string"
                    end
                    return true
                end,
                handler = function()
                    return { ok = true }
                end,
            })

            local bad = bus:execute({}, "economy.purchaseUpgrade", { upgradeId = 42 })
            expect(bad.ok).to.equal(false)
            expect(bad.code).to.equal("validation_failed")
            expect(bad.error).to.equal("upgradeId must be a string")

            local good = bus:execute({}, "economy.purchaseUpgrade", { upgradeId = "speed" })
            expect(good.ok).to.equal(true)
        end)

        it("gates test-only commands unless context.isTest is true", function()
            bus:register("test.grantCurrency", {
                testOnly = true,
                handler = function()
                    return "granted"
                end,
            })

            local blocked =
                bus:execute({ origin = CommandBus.Origin.Network }, "test.grantCurrency")
            expect(blocked.ok).to.equal(false)
            expect(blocked.code).to.equal("forbidden")

            local allowed = bus:execute({ isTest = true }, "test.grantCurrency")
            expect(allowed.ok).to.equal(true)
            expect(allowed.result).to.equal("granted")
        end)

        it("catches a throwing handler and returns handler_error", function()
            local logged
            local guarded = CommandBus.new({
                onError = function(err, name)
                    logged = { err = tostring(err), name = name }
                end,
            })
            guarded:register("boom.now", {
                handler = function()
                    error("kaboom")
                end,
            })

            local envelope = guarded:execute({}, "boom.now")
            expect(envelope.ok).to.equal(false)
            expect(envelope.code).to.equal("handler_error")
            -- onError hook fired with the command name
            expect(logged).to.be.ok()
            expect(logged.name).to.equal("boom.now")
        end)

        it("separates dispatch success from domain success", function()
            -- A handler returning its own { ok = false } envelope is a DOMAIN
            -- outcome, not a dispatch failure: envelope.ok stays true.
            bus:register("economy.purchase", {
                handler = function()
                    return { ok = false, reason = "insufficient_currency" }
                end,
            })

            local envelope = bus:execute({}, "economy.purchase")
            expect(envelope.ok).to.equal(true)
            expect(envelope.result.ok).to.equal(false)
            expect(envelope.result.reason).to.equal("insufficient_currency")
        end)

        it("supports registerMany, has, and list introspection", function()
            bus:registerMany({
                ["a.one"] = { handler = function() end, description = "first" },
                ["b.two"] = { handler = function() end, testOnly = true },
            })

            expect(bus:has("a.one")).to.equal(true)
            expect(bus:has("z.none")).to.equal(false)

            local listed = bus:list()
            expect(#listed).to.equal(2)
            -- sorted by name
            expect(listed[1].name).to.equal("a.one")
            expect(listed[1].description).to.equal("first")
            expect(listed[2].name).to.equal("b.two")
            expect(listed[2].testOnly).to.equal(true)
        end)

        it("refuses to register a duplicate command name", function()
            bus:register("dup.cmd", { handler = function() end })
            local okStatus = pcall(function()
                bus:register("dup.cmd", { handler = function() end })
            end)
            expect(okStatus).to.equal(false)
        end)
    end)
end
