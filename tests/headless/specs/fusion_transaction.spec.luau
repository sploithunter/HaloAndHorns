local FusionTransaction = loadModule("src/Shared/Game/FusionTransaction.lua")

local function harness(options)
    options = options or {}
    local calls = {}
    local snapshot = { uid = "A", id = "bear", variant = "basic", quantity = 2 }
    local result = FusionTransaction.execute({
        uidA = "A",
        uidB = "B",
        snapshotA = snapshot,
        mint = function()
            calls[#calls + 1] = "mint"
            return options.mintResult
                or {
                    ok = true,
                    uid = "OUT",
                    petData = { id = "bear", variant = "basic", element = "chaotic", unique = true },
                }
        end,
        remove = function(uid)
            calls[#calls + 1] = "remove:" .. uid
            if options.removeFails == uid then
                return false
            end
            return true
        end,
        restore = function(uid, record)
            calls[#calls + 1] = "restore:" .. uid
            expect(record).to.equal(snapshot)
            return options.restoreFails ~= true
        end,
        flush = function(reason)
            calls[#calls + 1] = "flush:" .. reason
            return options.flushFails ~= true
        end,
    })
    return result, calls
end

return function()
    describe("FusionTransaction", function()
        it("mints first, consumes both inputs, and flushes once", function()
            local result, calls = harness()
            expect(result.ok).to.equal(true)
            expect(result.outputUid).to.equal("OUT")
            expect(result.output.unique).to.equal(true)
            expect(table.concat(calls, ",")).to.equal(
                "mint,remove:A,remove:B,flush:fusion_complete"
            )
        end)

        it("does not consume inputs when minting fails", function()
            local result, calls = harness({
                mintResult = { ok = false, reason = "no_space", message = "No room" },
            })
            expect(result.reason).to.equal("no_space")
            expect(table.concat(calls, ",")).to.equal("mint")
        end)

        it("unmints without restoring when the first consume fails", function()
            local result, calls = harness({ removeFails = "A" })
            expect(result.reason).to.equal("consume_failed")
            expect(table.concat(calls, ",")).to.equal(
                "mint,remove:A,remove:OUT,flush:fusion_rollback"
            )
        end)

        it("restores the exact first snapshot when the second consume fails", function()
            local result, calls = harness({ removeFails = "B" })
            expect(result.reason).to.equal("consume_failed")
            expect(table.concat(calls, ",")).to.equal(
                "mint,remove:A,remove:B,remove:OUT,restore:A,flush:fusion_rollback"
            )
        end)

        it("reports a failed rollback instead of claiming the player is whole", function()
            local result = harness({ removeFails = "B", restoreFails = true })
            expect(result.reason).to.equal("rollback_failed")
        end)
    end)
end
