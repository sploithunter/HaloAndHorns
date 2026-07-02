--[[
    Studio smoke test for server-side egg hatch history/debug snapshots.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.EggHatchHistorySmoke).runText()
]]

local EggHatchHistorySmoke = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function EggHatchHistorySmoke.run(options)
    options = options or {}

    local eggType = options.eggType or "basic_egg"
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
            setupHatchCount = 2,
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

        local hatch = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = 2,
        })
        assert(type(hatch.result) == "table" and hatch.result.success == true, "Hatch failed")
        assert(hatch.result.hatchCount == 2, "History smoke hatch count mismatch")
        assert(hatch.afterPetCount == hatch.beforePetCount, "Auto-deleted hatch wrote pets")

        local historyResponse = invoke(remote, "GetEggHatchHistory", { limit = 3 })
        local history = historyResponse.history or {}
        assert(#history >= 1, "Hatch history missing entry")
        local latest = history[1]
        assert(latest.ok == true, "Latest hatch history entry was not successful")
        assert(latest.eggType == eggType, "History egg type mismatch")
        assert(latest.requestedCount == 2, "History requested count mismatch")
        assert(latest.hatchCount == 2, "History hatch count mismatch")
        assert(latest.totalCost == begin.cost * 2, "History total cost mismatch")
        assert(latest.currency == begin.currency, "History currency mismatch")
        assert(latest.autoDeletedCount == 2, "History auto-delete count mismatch")
        assert(
            type(latest.results) == "table" and #latest.results == 2,
            "History result sample missing"
        )
        assert(latest.results[1].pet == "bear", "History result pet mismatch")
        assert(latest.results[1].autoDeleted == true, "History result auto-delete flag missing")

        return {
            player = player.Name,
            eggType = eggType,
            historyId = latest.id,
            hatchCount = latest.hatchCount,
            autoDeletedCount = latest.autoDeletedCount,
            totalCost = latest.totalCost,
            currency = latest.currency,
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

function EggHatchHistorySmoke.runText(options)
    local result = EggHatchHistorySmoke.run(options)
    return string.format(
        "EggHatchHistorySmoke passed: player=%s egg=%s historyId=%s hatched=%d autoDeleted=%d totalCost=%d %s restored=%s",
        result.player,
        result.eggType,
        tostring(result.historyId),
        result.hatchCount,
        result.autoDeletedCount,
        result.totalCost,
        result.currency,
        tostring(result.restored)
    )
end

return EggHatchHistorySmoke
