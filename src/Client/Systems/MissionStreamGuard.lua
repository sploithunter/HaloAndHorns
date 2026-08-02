--[[
    MissionStreamGuard — client-confirmed floor readiness for procedural mission warps.

    RequestStreamAroundAsync has a timeout but no success result. A completed server call therefore
    cannot prove that a slow production client actually owns the destination floor. The server
    keeps the character at the source and sends a token here; this client acknowledges only after
    a collidable part from the expected mission has been observed below the landing point. There is
    deliberately no time-based "good enough" release.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local MissionStreamGuard = {}

local RAY_HEIGHT = 6
local RAY_DEPTH = 24

local localPlayer = Players.LocalPlayer
local activeRequest = nil

local function belongsToMission(instance, expectedInstanceId)
    if expectedInstanceId == nil then
        return true
    end

    local cursor = instance
    while cursor do
        if cursor:GetAttribute("InstanceId") == expectedInstanceId then
            return true
        end
        cursor = cursor.Parent
    end
    return false
end

local function destinationFloorIsReady(position, expectedInstanceId)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = if localPlayer.Character
        then { localPlayer.Character }
        else {}
    -- SpawnPad is an invisible, non-collidable marker directly above the real floor. Ordinary
    -- raycasts respect CanQuery, so that marker can be returned first and leave entry waiting
    -- forever even though safe collision geometry is already present beneath it. This readiness
    -- check is specifically about character-supporting geometry, so ray against CanCollide.
    params.RespectCanCollide = true

    local result = workspace:Raycast(
        position + Vector3.new(0, RAY_HEIGHT, 0),
        Vector3.new(0, -RAY_DEPTH, 0),
        params
    )
    return result ~= nil
        and result.Instance.CanCollide
        and belongsToMission(result.Instance, expectedInstanceId)
end

local function handleRequest(request)
    if type(request) ~= "table" or type(request.token) ~= "string" then
        return
    end
    if
        type(request.x) ~= "number"
        or type(request.y) ~= "number"
        or type(request.z) ~= "number"
    then
        return
    end

    if activeRequest then
        activeRequest.cancelled = true
        activeRequest.wake:Fire()
    end

    local token = request.token
    local position = Vector3.new(request.x, request.y, request.z)
    local expectedInstanceId = if type(request.instanceId) == "string"
        then request.instanceId
        else nil
    local state = {
        token = token,
        cancelled = false,
        wake = Instance.new("BindableEvent"),
    }
    activeRequest = state
    local descendantConnection = workspace.DescendantAdded:Connect(function()
        state.wake:Fire()
    end)

    task.spawn(function()
        while activeRequest == state and not state.cancelled and localPlayer.Parent do
            if destinationFloorIsReady(position, expectedInstanceId) then
                Signals.MissionStreamReady:FireServer({
                    token = token,
                    instanceId = expectedInstanceId,
                })
                break
            end
            -- Streaming a previously absent Atomic/PersistentPerPlayer model produces descendant
            -- events. Wait for that event rather than polling or treating elapsed time as proof.
            state.wake.Event:Wait()
        end

        descendantConnection:Disconnect()
        if activeRequest == state then
            activeRequest = nil
        end
        state.wake:Destroy()
    end)
end

function MissionStreamGuard.start()
    Signals.MissionStreamRequest.OnClientEvent:Connect(handleRequest)
end

return MissionStreamGuard
