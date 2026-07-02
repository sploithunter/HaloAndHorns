--[[
    Studio smoke test for server-authoritative batch egg hatching.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.EggBatchHatchSmoke).runText()
]]

local EggBatchHatchSmoke = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locations = require(ReplicatedStorage.Shared.Locations)
local eggSystemConfig = Locations.getConfig("egg_system")

local DEFAULT_TIMEOUT_SECONDS = 20
local REMOTE_NAME = "StudioSmokeTest"

local function waitFor(description, timeoutSeconds, predicate)
    local deadline = os.clock() + (timeoutSeconds or DEFAULT_TIMEOUT_SECONDS)

    while os.clock() < deadline do
        local result = predicate()
        if result then
            return result
        end
        task.wait(0.1)
    end

    error("Timed out waiting for " .. description)
end

local function getPlayer(options)
    if options.player then
        return options.player
    end

    return Players.LocalPlayer
        or Players:GetPlayers()[1]
        or waitFor("a player", options.timeoutSeconds, function()
            return Players.LocalPlayer or Players:GetPlayers()[1]
        end)
end

local function invoke(remote, action, payload)
    local response = remote:InvokeServer(action, payload or {})
    if type(response) ~= "table" then
        error("Studio smoke bridge returned non-table response")
    end
    if response.ok ~= true then
        error(response.error or ("Studio smoke bridge action failed: " .. tostring(action)))
    end
    return response
end

function EggBatchHatchSmoke.run(options)
    options = options or {}

    local eggType = options.eggType or "basic_egg"
    local requestedCount = math.max(2, math.floor(tonumber(options.requestedCount) or 5))
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local player = getPlayer(options)
    local remote = waitFor(REMOTE_NAME .. " RemoteFunction", timeoutSeconds, function()
        local instance = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if instance and instance:IsA("RemoteFunction") then
            return instance
        end
        return nil
    end)

    local started = false
    local success, result = pcall(function()
        local begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = requestedCount,
        })
        started = true

        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.35)

        local batch = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = requestedCount,
        })
        assert(
            type(batch.result) == "table" and batch.result.success == true,
            tostring(batch.message)
        )
        assert(batch.result.requestedCount == requestedCount, "Batch response lost requested count")
        assert(batch.result.hatchCount == requestedCount, "Batch did not hatch requested count")
        assert(type(batch.result.results) == "table", "Batch response missing results")
        assert(#batch.result.results == requestedCount, "Batch result count mismatch")
        assert(
            batch.afterCurrency == batch.beforeCurrency - (batch.cost * requestedCount),
            "Batch did not deduct the combined configured cost"
        )
        assert(
            batch.afterPetCount == batch.beforePetCount + requestedCount,
            "Batch did not add the expected number of pets"
        )

        local rapid = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = 1,
        })
        assert(
            type(rapid.result) == "table" and rapid.result.success == false,
            "Rapid hatch was not rejected"
        )
        assert(rapid.result.code == "hatch_locked", "Rapid hatch rejected for wrong reason")
        assert(rapid.afterCurrency == rapid.beforeCurrency, "Rapid rejected hatch changed currency")
        assert(
            rapid.afterPetCount == rapid.beforePetCount,
            "Rapid rejected hatch changed pet count"
        )

        task.wait((batch.cooldown or 0) + 0.25)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = 1,
            setupAutoHatchUnlocked = false,
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local lockedAuto = invoke(remote, "HatchEggProximity", {
            requestedCount = 1,
            purchaseType = "Auto",
            autoSessionId = 1001,
        })
        assert(
            type(lockedAuto.result) == "table" and lockedAuto.result.success == false,
            "Locked auto hatch should fail"
        )
        assert(lockedAuto.result.code == "feature_locked", "Locked auto hatch code mismatch")
        assert(
            lockedAuto.result.details and lockedAuto.result.details.autoSessionId == 1001,
            "Locked auto hatch response lost session id"
        )
        assert(
            lockedAuto.afterCurrency == lockedAuto.beforeCurrency,
            "Locked auto changed currency"
        )
        assert(lockedAuto.afterPetCount == lockedAuto.beforePetCount, "Locked auto changed pets")

        task.wait((lockedAuto.cooldown or 0) + 0.25)
        local partialFundsCount = math.max(1, requestedCount - 2)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = requestedCount,
            setupCurrencyAmount = begin.cost * partialFundsCount,
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local partialFunds = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = requestedCount,
        })
        assert(
            type(partialFunds.result) == "table" and partialFunds.result.success == true,
            "Partial funds hatch failed"
        )
        assert(
            partialFunds.result.hatchCount == partialFundsCount,
            "Partial funds hatch count mismatch"
        )
        assert(partialFunds.result.stopReason == "currency", "Partial funds stop reason mismatch")
        assert(
            partialFunds.afterCurrency
                == partialFunds.beforeCurrency - (partialFunds.cost * partialFundsCount),
            "Partial funds deducted wrong amount"
        )

        task.wait((partialFunds.cooldown or 0) + 0.25)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = 1,
            setupCurrencyAmount = begin.cost,
            setupForceHatchPet = "bear",
            setupForceHatchVariant = "basic",
            setupAutoDeleteFilters = {
                enabled = true,
                rarities = {
                    common = true,
                },
            },
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local autoDeleteHatch = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = 1,
        })
        assert(
            type(autoDeleteHatch.result) == "table" and autoDeleteHatch.result.success == true,
            "Auto-delete hatch failed"
        )
        assert(autoDeleteHatch.result.AutoDeleted == true, "Auto-delete flag missing")
        assert(autoDeleteHatch.result.AutoDeleteReason == "rarity", "Auto-delete reason mismatch")
        assert(
            autoDeleteHatch.afterPetCount == autoDeleteHatch.beforePetCount,
            "Auto-delete hatch wrote to inventory"
        )
        assert(
            autoDeleteHatch.afterEggsHatched == autoDeleteHatch.beforeEggsHatched + 1,
            "Auto-delete hatch did not increment egg stats"
        )
        assert(
            autoDeleteHatch.afterCurrency == autoDeleteHatch.beforeCurrency - autoDeleteHatch.cost,
            "Auto-delete hatch deducted wrong amount"
        )

        task.wait((autoDeleteHatch.cooldown or 0) + 0.25)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        local goldenCount = math.min(2, requestedCount)
        local goldenMultiplier = math.max(
            1,
            tonumber(
                eggSystemConfig.hatching
                    and eggSystemConfig.hatching.shop_stubs
                    and eggSystemConfig.hatching.shop_stubs.golden_mode
                    and eggSystemConfig.hatching.shop_stubs.golden_mode.cost_multiplier
            ) or 20
        )
        local chargedMultiplier = math.max(
            1,
            tonumber(
                eggSystemConfig.hatching
                    and eggSystemConfig.hatching.shop_stubs
                    and eggSystemConfig.hatching.shop_stubs.charged_mode
                    and eggSystemConfig.hatching.shop_stubs.charged_mode.cost_multiplier
            ) or 5
        )
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = goldenCount,
            setupCurrencyAmount = begin.cost * goldenMultiplier * goldenCount,
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local lockedGolden = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = goldenCount,
            options = {
                goldenMode = true,
            },
        })
        assert(
            type(lockedGolden.result) == "table" and lockedGolden.result.success == false,
            "Locked Golden mode hatch should fail"
        )
        assert(
            lockedGolden.result.code == "feature_locked",
            "Locked Golden mode failed with wrong code"
        )
        assert(
            lockedGolden.afterCurrency == lockedGolden.beforeCurrency,
            "Locked Golden mode changed currency"
        )
        assert(
            lockedGolden.afterPetCount == lockedGolden.beforePetCount,
            "Locked Golden mode changed pet count"
        )

        task.wait((lockedGolden.cooldown or 0) + 0.25)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = goldenCount,
            setupCurrencyAmount = begin.cost * goldenMultiplier * goldenCount,
            setupGoldenModeUnlocked = true,
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local golden = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = goldenCount,
            options = {
                goldenMode = true,
            },
        })
        assert(
            type(golden.result) == "table" and golden.result.success == true,
            "Golden hatch failed"
        )
        assert(golden.result.hatchCount == goldenCount, "Golden hatch count mismatch")
        assert(
            golden.result.options and golden.result.options.goldenMode == true,
            "Golden mode not echoed"
        )
        assert(
            golden.afterCurrency
                == golden.beforeCurrency - (golden.cost * goldenMultiplier * goldenCount),
            "Golden hatch deducted wrong amount"
        )
        for _, entry in ipairs(golden.result.results or {}) do
            assert(entry.Type ~= "basic", "Golden mode hatched a basic variant")
        end

        task.wait((golden.cooldown or 0) + 0.25)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = 1,
            setupCurrencyAmount = begin.cost * chargedMultiplier,
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local lockedCharged = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = 1,
            options = {
                chargedMode = true,
            },
        })
        assert(
            type(lockedCharged.result) == "table" and lockedCharged.result.success == false,
            "Locked Charged mode hatch should fail"
        )
        assert(
            lockedCharged.result.code == "feature_locked",
            "Locked Charged mode failed with wrong code"
        )
        assert(
            lockedCharged.result.details and lockedCharged.result.details.mode == "chargedMode",
            "Locked Charged mode did not identify the locked mode"
        )
        assert(
            lockedCharged.afterCurrency == lockedCharged.beforeCurrency,
            "Locked Charged mode changed currency"
        )

        task.wait((lockedCharged.cooldown or 0) + 0.25)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = 1,
            setupCurrencyAmount = begin.cost * chargedMultiplier,
            setupChargedModeUnlocked = true,
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local charged = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = 1,
            options = {
                chargedMode = true,
            },
        })
        assert(
            type(charged.result) == "table" and charged.result.success == true,
            "Charged hatch failed"
        )
        assert(
            charged.result.options and charged.result.options.chargedMode == true,
            "Charged mode not echoed"
        )
        assert(
            charged.afterCurrency == charged.beforeCurrency - (charged.cost * chargedMultiplier),
            "Charged hatch deducted wrong amount"
        )

        task.wait((charged.cooldown or 0) + 0.25)
        invoke(remote, "RestoreEggProximity", {})
        started = false
        local storageLimitedCount = math.min(2, requestedCount)
        begin = invoke(remote, "BeginEggProximity", {
            eggType = eggType,
            setupHatchCount = requestedCount,
            setupCurrencyAmount = begin.cost * requestedCount,
            setupPetInventoryEmpty = true,
            setupPetStorageAvailableSlots = storageLimitedCount,
            setupForceHatchPet = "colorado",
            setupForceHatchVariant = "basic",
            setupAutoDeleteFilters = {
                enabled = false,
            },
        })
        started = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.2)

        local partialStorage = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = requestedCount,
        })
        assert(
            type(partialStorage.result) == "table" and partialStorage.result.success == true,
            "Partial storage hatch failed"
        )
        assert(
            partialStorage.result.hatchCount == storageLimitedCount,
            "Partial storage hatch count mismatch"
        )
        assert(
            partialStorage.result.stopReason == "storage",
            "Partial storage stop reason mismatch"
        )
        assert(
            partialStorage.afterCurrency
                == partialStorage.beforeCurrency - (partialStorage.cost * storageLimitedCount),
            "Partial storage deducted wrong amount"
        )
        assert(
            partialStorage.afterPetCount == partialStorage.beforePetCount + storageLimitedCount,
            "Partial storage added wrong pet count"
        )
        local specialEntry = partialStorage.result.results and partialStorage.result.results[1]
        assert(specialEntry and specialEntry.SpecialHatch == true, "Special hatch flag missing")
        assert(specialEntry.RarityId == "exclusive", "Special hatch rarity mismatch")
        assert(
            partialStorage.result.animation
                and partialStorage.result.animation.specialReveal == true,
            "Special hatch animation metadata missing"
        )
        assert(
            partialStorage.result.animation.specialRevealCount == storageLimitedCount,
            "Special hatch count mismatch"
        )

        return {
            player = player.Name,
            eggType = begin.eggType,
            currency = begin.currency,
            cost = begin.cost,
            requestedCount = requestedCount,
            hatchCount = batch.result.hatchCount,
            partialFundsCount = partialFunds.result.hatchCount,
            autoDeletedCount = autoDeleteHatch.result.hatchCount,
            goldenCount = golden.result.hatchCount,
            chargedCount = charged.result.hatchCount,
            partialStorageCount = partialStorage.result.hatchCount,
            stopReason = batch.result.stopReason,
        }
    end)

    local restoreResponse
    if started then
        restoreResponse = remote:InvokeServer("RestoreEggProximity", {})
    end

    if not success then
        error(result)
    end

    result.restored = type(restoreResponse) == "table" and restoreResponse.restored == true
    return result
end

function EggBatchHatchSmoke.runText(options)
    local result = EggBatchHatchSmoke.run(options)
    return string.format(
        "EggBatchHatchSmoke passed: player=%s egg=%s count=%d partialFunds=%d autoDeleted=%d partialStorage=%d golden=%d charged=%d cost=%d %s stop=%s restored=%s",
        result.player,
        result.eggType,
        result.hatchCount,
        result.partialFundsCount,
        result.autoDeletedCount,
        result.partialStorageCount,
        result.goldenCount,
        result.chargedCount,
        result.cost,
        result.currency,
        tostring(result.stopReason),
        tostring(result.restored)
    )
end

return EggBatchHatchSmoke
