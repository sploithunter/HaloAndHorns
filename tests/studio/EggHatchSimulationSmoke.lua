--[[
    Studio smoke test for no-mutation egg hatch simulation.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.EggHatchSimulationSmoke).runText()
]]

local EggHatchSimulationSmoke = {}

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

function EggHatchSimulationSmoke.run(options)
    options = options or {}
    local player = getPlayer(options)
    local eggType = options.eggType or "basic_egg"
    local requestedCount = options.requestedCount or 7
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local remote = waitFor(REMOTE_NAME .. " RemoteFunction", timeoutSeconds, function()
        local instance = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if instance and instance:IsA("RemoteFunction") then
            return instance
        end
        return nil
    end)

    local response = invoke(remote, "SimulateEggHatch", {
        eggType = eggType,
        requestedCount = requestedCount,
        forcePet = "bear",
        forceVariant = "basic",
        setupHatchLuckBonus = 2,
        setupSecretHatchLuckBonus = 0.5,
    })
    local simulation = response.simulation
    assert(type(simulation) == "table" and simulation.ok == true, "Simulation failed")
    assert(simulation.simulated == true, "Simulation missing simulated marker")
    assert(simulation.eggType == eggType, "Simulation egg type mismatch")
    assert(simulation.requestedCount == requestedCount, "Simulation requested count mismatch")
    assert(simulation.hatchCount == requestedCount, "Simulation hatch count mismatch")
    assert(type(simulation.results) == "table", "Simulation missing result list")
    assert(#simulation.results == requestedCount, "Simulation result count mismatch")
    assert(
        simulation.counts and simulation.counts.pets.bear == requestedCount,
        "Pet count mismatch"
    )
    assert(
        simulation.counts and simulation.counts.variants.basic == requestedCount,
        "Variant count mismatch"
    )
    assert(response.beforeCurrency == response.afterCurrency, "Simulation changed currency")
    assert(response.beforePetCount == response.afterPetCount, "Simulation changed inventory")
    assert(
        response.beforeEggsHatched == response.afterEggsHatched,
        "Simulation changed hatch counter"
    )
    assert(
        simulation.entitlements and simulation.entitlements.luckBonus == 2,
        "Simulation did not resolve hatch luck entitlement"
    )
    assert(
        simulation.entitlements and simulation.entitlements.secretLuckBonus == 0.5,
        "Simulation did not resolve secret hatch luck entitlement"
    )
    assert(
        simulation.options and simulation.options.luckBonus == 2,
        "Simulation options missing hatch luck bonus"
    )
    assert(
        simulation.options and simulation.options.secretLuckBonus == 0.5,
        "Simulation options missing secret hatch luck bonus"
    )

    return {
        player = player.Name,
        eggType = eggType,
        requestedCount = requestedCount,
        hatchCount = simulation.hatchCount,
        totalCost = simulation.totalCost,
        currency = simulation.currency,
        petCount = simulation.counts.pets.bear,
    }
end

function EggHatchSimulationSmoke.runText(options)
    local result = EggHatchSimulationSmoke.run(options)
    return string.format(
        "EggHatchSimulationSmoke passed: player=%s egg=%s requested=%d simulated=%d petCount=%d totalCost=%d %s",
        result.player,
        result.eggType,
        result.requestedCount,
        result.hatchCount,
        result.petCount,
        result.totalCost,
        result.currency
    )
end

return EggHatchSimulationSmoke
