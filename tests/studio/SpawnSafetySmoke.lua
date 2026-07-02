--[[
    Studio smoke test for safe player spawn placement on synthetic/authored maps.

    Run in play mode:

    return require(game:GetService("ReplicatedStorage").Tests.studio.SpawnSafetySmoke).runText()
]]

local SpawnSafetySmoke = {}

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
    return options.player
        or Players.LocalPlayer
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

function SpawnSafetySmoke.run(options)
    options = options or {}

    local zoneId = options.zoneId or "Spawn"
    local timeoutSeconds = options.timeoutSeconds or DEFAULT_TIMEOUT_SECONDS
    local player = getPlayer(options)
    local remote = waitFor(REMOTE_NAME .. " RemoteFunction", timeoutSeconds, function()
        local instance = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if instance and instance:IsA("RemoteFunction") then
            return instance
        end
        return nil
    end)

    local result = invoke(remote, "CheckSpawnSafetySmoke", { zoneId = zoneId })
    assert(result.activeArea == result.areaId, "Active area did not match spawn area")
    assert(result.floorDistance > 1, "Spawn was too close to or below the floor")
    assert(result.floorDistance < 20, "Spawn was too high above the floor")
    assert(math.abs(result.verticalVelocity) < 5, "Spawn left the player moving too quickly")

    return {
        player = player.Name,
        zoneId = zoneId,
        areaId = result.areaId,
        floorDistance = result.floorDistance,
    }
end

function SpawnSafetySmoke.runText(options)
    local result = SpawnSafetySmoke.run(options)
    return string.format(
        "SpawnSafetySmoke passed: player=%s zone=%s area=%s floorDistance=%.2f",
        result.player,
        result.zoneId,
        result.areaId,
        result.floorDistance
    )
end

return SpawnSafetySmoke
