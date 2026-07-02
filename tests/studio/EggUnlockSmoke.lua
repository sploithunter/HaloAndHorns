--[[
    Studio smoke test for config-driven egg unlock requirements.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.EggUnlockSmoke).runText()
]]

local EggUnlockSmoke = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_TIMEOUT_SECONDS = 25
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

-- The unlock requirement comes from the egg's config (EggService:GetEggUnlockStatus).
-- golden_egg — the old hardcoded subject — was removed (premium eggs are gone), so the
-- smoke now derives its subject: any egg_sources entry with an unlock_requirement.
local function getUnlockRequirement(eggType)
    local Locations = require(ReplicatedStorage.Shared.Locations)
    local petConfig = Locations.getConfig("pets")
    local eggData = petConfig.egg_sources and petConfig.egg_sources[eggType]
    return eggData and eggData.unlock_requirement or nil
end

local function findGatedEggType()
    local Locations = require(ReplicatedStorage.Shared.Locations)
    local petConfig = Locations.getConfig("pets")
    for eggType, eggData in pairs(petConfig.egg_sources or {}) do
        local req = eggData.unlock_requirement
        if type(req) == "table" and (tonumber(req.amount) or 0) > 0 then
            return eggType
        end
    end
    return nil
end

local function beginLockedEgg(remote, eggType, counterId, counterValue)
    return invoke(remote, "BeginEggProximity", {
        eggType = eggType,
        setupTemporaryEggStand = true,
        setupCounters = {
            [counterId] = counterValue,
        },
        setupCurrencyAmount = 5000,
        setupPetInventoryEmpty = true,
        setupPetStorageAvailableSlots = 2,
        setupAutoHatchUnlocked = true,
        setupGoldenModeUnlocked = true,
        setupChargedModeUnlocked = true,
        setupFastHatchUnlocked = true,
        setupSkipHatchUnlocked = true,
        setupMaxHatchCount = 5,
    })
end

function EggUnlockSmoke.run(options)
    options = options or {}
    local eggType = options.eggType or findGatedEggType()
    if not eggType then
        error(
            "EggUnlockSmoke: no egg in configs/pets.lua egg_sources has an unlock_requirement"
                .. " — add one (or pass options.eggType) to exercise the locked-egg flow"
        )
    end
    local requirement = getUnlockRequirement(eggType)
    if type(requirement) ~= "table" or (tonumber(requirement.amount) or 0) <= 0 then
        error("EggUnlockSmoke: egg '" .. tostring(eggType) .. "' has no unlock_requirement")
    end
    -- same counter resolution as EggService:GetEggUnlockStatus
    local counterId = requirement.counter or requirement.stat or requirement.type
    local requiredAmount = tonumber(requirement.amount)
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local player = getPlayer(options)
    local remote = waitFor(REMOTE_NAME .. " RemoteFunction", timeoutSeconds, function()
        local instance = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if instance and instance:IsA("RemoteFunction") then
            return instance
        end
        return nil
    end)

    local restoreNeeded = false
    local result = {}
    local success, err = pcall(function()
        local lockedBegin = beginLockedEgg(remote, eggType, counterId, requiredAmount - 1)
        restoreNeeded = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.25)

        local locked = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = 1,
        })
        assert(type(locked.result) == "table", "Locked egg response was not a table")
        assert(locked.result.success == false, "Locked egg hatch unexpectedly succeeded")
        assert(locked.result.code == "egg_locked", "Locked egg returned wrong error code")
        assert(locked.afterCurrency == locked.beforeCurrency, "Locked egg changed currency")
        assert(locked.afterPetCount == locked.beforePetCount, "Locked egg changed pet inventory")
        assert(
            locked.result.details and locked.result.details.required == requiredAmount,
            "Locked egg response missed required unlock amount"
        )
        assert(
            locked.result.details and locked.result.details.current == requiredAmount - 1,
            "Locked egg response missed current unlock progress"
        )
        result.lockedCode = locked.result.code
        result.required = locked.result.details.required
        result.current = locked.result.details.current
        result.currency = lockedBegin.currency

        invoke(remote, "RestoreEggProximity", {})
        restoreNeeded = false
        task.wait(0.4)

        local unlockedBegin = beginLockedEgg(remote, eggType, counterId, requiredAmount)
        restoreNeeded = true
        invoke(remote, "MoveEggProximity", { placement = "near" })
        task.wait(0.25)

        local unlocked = invoke(remote, "HatchEggProximity", {
            batch = true,
            requestedCount = 1,
        })
        assert(type(unlocked.result) == "table", "Unlocked egg response was not a table")
        assert(unlocked.result.success == true, "Unlocked egg hatch did not succeed")
        assert(unlocked.result.hatchCount == 1, "Unlocked egg hatch count mismatch")
        assert(
            unlocked.afterCurrency == unlocked.beforeCurrency - unlocked.result.TotalCost,
            "Unlocked egg deducted wrong currency"
        )
        assert(
            unlocked.afterPetCount == unlocked.beforePetCount + 1,
            "Unlocked egg did not add pet"
        )
        result.hatchedPet = unlocked.result.Pet
        result.hatchedVariant = unlocked.result.Type
        result.unlockedCurrency = unlockedBegin.currency

        invoke(remote, "RestoreEggProximity", {})
        restoreNeeded = false
    end)

    local restoreResponse
    if restoreNeeded then
        restoreResponse = remote:InvokeServer("RestoreEggProximity", {})
    end

    if not success then
        error(err)
    end

    result.restored = restoreNeeded == false
        or (type(restoreResponse) == "table" and restoreResponse.restored == true)
    result.player = player.Name
    result.eggType = eggType
    return result
end

function EggUnlockSmoke.runText(options)
    local result = EggUnlockSmoke.run(options)
    return string.format(
        "EggUnlockSmoke passed: player=%s egg=%s locked=%s %d/%d hatched=%s/%s restored=%s",
        result.player,
        result.eggType,
        tostring(result.lockedCode),
        result.current,
        result.required,
        tostring(result.hatchedPet),
        tostring(result.hatchedVariant),
        tostring(result.restored)
    )
end

return EggUnlockSmoke
