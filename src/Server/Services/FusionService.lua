--[[
    FusionService — Feature 20 (Chaotic Fusion).

    Sacrifice 1 Light + 1 Shadow pet to produce 1 Chaotic pet. Server-authoritative:
    validate inputs (pure FusionLogic), consume both inputs permanently, add the
    Chaotic output, and record a fusion-history audit entry.

    The altar + confirmation modal are [studio]; the rules, the consume→produce
    contract, and the fusion log are bus-testable solo via fusion.canFuse and the
    test-only fusion.simulate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionLogic = require(ReplicatedStorage.Shared.Game.FusionLogic)
local FusionTransaction = require(ReplicatedStorage.Shared.Game.FusionTransaction)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local FusionService = {}
FusionService.__index = FusionService

function FusionService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._config = self._configLoader:LoadConfig("fusion")
    self._inventoryService = self._modules and self._modules.InventoryService
    self._petGrantService = self._modules and self._modules.PetGrantService
    self._fusionLog = {} -- append-only, capped at config.fusion_log_limit
end

-- Rule check exposed to the UI/bus (fusion.canFuse).
function FusionService:CanFuse(elemA, elemB)
    return FusionLogic.validateInputs(elemA, elemB, self._config)
end

-- Execute a fusion of two unique pets the player owns (by inventory uid).
-- Atomic: validate ownership + elements first, mint the output, then consume the
-- inputs. Failed consumption un-mints the output and restores exact input state.
-- The audit record is written only on success.
function FusionService:Fuse(player, uidA, uidB)
    local inventory = self._inventoryService
    local petGrant = self._petGrantService
    if not inventory or not petGrant then
        return { ok = false, reason = "service_unavailable" }
    end
    if uidA == uidB then
        return { ok = false, reason = "same_pet", message = "Fusion requires two different pets" }
    end
    local recA = inventory:GetPetRecordSnapshot(player, uidA)
    local recB = inventory:GetPetRecordSnapshot(player, uidB)
    if not recA or not recB then
        return { ok = false, reason = "pet_not_found" }
    end

    local elemA = recA.element or "neutral"
    local elemB = recB.element or "neutral"
    local verdict = FusionLogic.validateInputs(elemA, elemB, self._config)
    if not verdict.ok then
        return verdict
    end

    local outputTheme = FusionLogic.resolveTheme(recA.theme, recB.theme, self._config)
    local outputElement = FusionLogic.outputElement(self._config)

    local transaction = FusionTransaction.execute({
        uidA = uidA,
        uidB = uidB,
        snapshotA = recA,
        mint = function()
            local result = petGrant:GrantPet(player, {
                petType = recA.id,
                variant = recA.variant or "basic",
                element = outputElement,
                theme = outputTheme,
                unique = true,
                source = "fusion",
                deferFlush = true,
            })
            if not result.ok then
                return {
                    ok = false,
                    reason = "no_space",
                    message = result.error or "No room for the fused pet",
                }
            end
            return result
        end,
        remove = function(uid)
            return inventory:RemoveItem(player, "pets", uid, 1, { deferFlush = true })
        end,
        restore = function(uid, snapshot)
            return inventory:RestorePetRecordSnapshot(player, uid, snapshot, { deferFlush = true })
        end,
        flush = function(saveTag)
            inventory:FlushBucket(player, "pets", saveTag)
            return true
        end,
    })
    if not transaction.ok then
        if transaction.reason == "rollback_failed" and self._logger then
            self._logger:Error("Fusion rollback failed", {
                player = player.Name,
                uidA = uidA,
                uidB = uidB,
            })
        end
        return transaction
    end

    local outputData = transaction.output
    local outUid = transaction.outputUid

    local rec = FusionLogic.fusionRecord(player.UserId, uidA, uidB, outUid, os.time())
    self:_appendLog(rec)
    fireGameEvent(player, "pet_fusion", { output = outputData.id, element = outputData.element })
    return { ok = true, output = outputData, outputUid = outUid, audit = rec }
end

function FusionService:_appendLog(rec)
    table.insert(self._fusionLog, rec)
    local limit = self._config.fusion_log_limit or 100
    while #self._fusionLog > limit do
        table.remove(self._fusionLog, 1)
    end
end

-- Queryable fusion-history audit log (optionally filtered to a userId).
function FusionService:GetFusionLog(userId)
    if not userId then
        return { ok = true, records = self._fusionLog }
    end
    local out = {}
    for _, rec in ipairs(self._fusionLog) do
        if rec.player == userId then
            table.insert(out, rec)
        end
    end
    return { ok = true, records = out }
end

-- Test/UI affordance: run the rule + output + record logic without live inventory.
function FusionService:Simulate(opts)
    opts = opts or {}
    local verdict = FusionLogic.validateInputs(opts.elemA, opts.elemB, self._config)
    if not verdict.ok then
        return { ok = true, canFuse = verdict }
    end
    local outputElement = FusionLogic.outputElement(self._config)
    local outputTheme = FusionLogic.resolveTheme(opts.themeA, opts.themeB, self._config)
    local record = FusionLogic.fusionRecord(
        opts.player or 0,
        opts.uidA or "A",
        opts.uidB or "B",
        "OUT",
        opts.timestamp or 0
    )
    return {
        ok = true,
        canFuse = verdict,
        outputElement = outputElement,
        outputTheme = outputTheme,
        audit = record,
    }
end

return FusionService
