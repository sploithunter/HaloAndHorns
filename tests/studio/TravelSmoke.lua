--[[
    Client-coordinated Studio smoke test for ZoneService travel behavior.

    Run in play mode through Studio MCP / command bar:

    return require(game:GetService("ReplicatedStorage").Tests.studio.TravelSmoke).runText()
]]

local TravelSmoke = {}

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

local function invokeRequired(remote, action, payload)
    local response = remote:InvokeServer(action, payload or {})
    if type(response) ~= "table" then
        error("Studio smoke bridge returned non-table response")
    end
    if response.ok ~= true then
        error(response.error or ("Studio smoke bridge action failed: " .. tostring(action)))
    end
    return response
end

local function invokeRaw(remote, action, payload)
    local response = remote:InvokeServer(action, payload or {})
    if type(response) ~= "table" then
        error("Studio smoke bridge returned non-table response")
    end
    return response
end

function TravelSmoke.run(options)
    options = options or {}

    local sourceAreaId = options.sourceAreaId or "Spawn"
    local targetZoneId = options.targetZoneId or "Meadow"
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
        local begin = invokeRequired(remote, "BeginTravelSmoke", {
            sourceAreaId = sourceAreaId,
            targetZoneId = targetZoneId,
        })
        started = true

        local locked = invokeRaw(remote, "UseTravelSmoke")
        assert(locked.ok == false, "Locked travel should be rejected")
        assert(locked.reason == "locked", "Locked travel failed for wrong reason")
        assert(
            locked.activeArea ~= begin.targetAreaId,
            "Locked travel still moved player to target area"
        )

        local unlock = invokeRequired(remote, "UnlockTravelSmoke")
        assert(unlock.areaId == begin.targetAreaId, "Unlock targeted the wrong area")

        local unlocked = invokeRequired(remote, "UseTravelSmoke")
        assert(unlocked.targetAreaId == begin.targetAreaId, "Unlocked travel reached wrong area")
        assert(unlocked.activeArea == begin.targetAreaId, "Active area did not update after travel")

        return {
            player = player.Name,
            sourceAreaId = begin.sourceAreaId,
            targetZoneId = begin.targetZoneId,
            targetAreaId = begin.targetAreaId,
            pad = begin.pad,
            lockedReason = locked.reason,
        }
    end)

    local restoreResponse
    if started then
        restoreResponse = remote:InvokeServer("RestoreTravelSmoke", {})
    end

    if not success then
        error(result)
    end

    result.restored = type(restoreResponse) == "table" and restoreResponse.restored == true
    return result
end

function TravelSmoke.runText(options)
    local result = TravelSmoke.run(options)
    return string.format(
        "TravelSmoke passed: player=%s source=%s target=%s area=%s locked=%s restored=%s",
        result.player,
        result.sourceAreaId,
        result.targetZoneId,
        result.targetAreaId,
        result.lockedReason,
        tostring(result.restored)
    )
end

return TravelSmoke
