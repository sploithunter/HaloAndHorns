-- Pure mint-first fusion transaction orchestration. Runtime services provide the
-- inventory callbacks; this module owns ordering and rollback decisions.

local FusionTransaction = {}

local function invoke(callback, ...)
    local ok, first, second = pcall(callback, ...)
    if not ok then
        return false, first
    end
    return true, first, second
end

function FusionTransaction.execute(options)
    options = options or {}

    local mintCalled, mintResult = invoke(options.mint)
    if not mintCalled or type(mintResult) ~= "table" or mintResult.ok ~= true then
        return {
            ok = false,
            reason = (type(mintResult) == "table" and mintResult.reason) or "no_space",
            message = type(mintResult) == "table" and mintResult.message or nil,
        }
    end

    local outputUid = mintResult.uid
    if outputUid == nil then
        return { ok = false, reason = "mint_failed" }
    end

    local removeACalled, removedA = invoke(options.remove, options.uidA)
    removedA = removeACalled and removedA == true
    local removeBCalled, removedB = true, false
    if removedA then
        removeBCalled, removedB = invoke(options.remove, options.uidB)
        removedB = removeBCalled and removedB == true
    end

    if removedA and removedB then
        local flushCalled, flushed = invoke(options.flush, "fusion_complete")
        if not flushCalled or flushed == false then
            return { ok = false, reason = "flush_failed", outputUid = outputUid }
        end
        return {
            ok = true,
            outputUid = outputUid,
            output = mintResult.petData,
        }
    end

    local unmintCalled, unminted = invoke(options.remove, outputUid)
    local restored = true
    if removedA then
        local restoreCalled, restoreResult =
            invoke(options.restore, options.uidA, options.snapshotA)
        restored = restoreCalled and restoreResult == true
    end
    local flushCalled, flushed = invoke(options.flush, "fusion_rollback")

    if
        not unmintCalled
        or unminted ~= true
        or not restored
        or not flushCalled
        or flushed == false
    then
        return {
            ok = false,
            reason = "rollback_failed",
            removedA = removedA,
            removedB = removedB,
        }
    end

    return { ok = false, reason = "consume_failed" }
end

return FusionTransaction
