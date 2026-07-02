--[[
    AutomationService  (Studio-only test driver)

    The "underneath the UI" harness. It does the runtime things an automated
    test needs that the pure CommandBus cannot:

      • NavigateTo   — realistic pathfinding movement (NOT CFrame jumps), so
                       proximity behavior (egg approach, portal walk-up) is
                       exercised faithfully.
      • Snapshot/Restore — capture and roll back a player's currency, inventory,
                       and position so tests are repeatable and leave no trace.
      • GetPlayerState — read authoritative state for assertions.
      • TeleportForSetup — CFrame placement for FAST STAGING ONLY (never the
                       traversal-under-test).

    These are exposed as test-only commands on the GameAPI bus via RegisterInto,
    so the automation harness drives everything through the single command
    boundary (see docs/wiki/AUTOMATION_API_DESIGN.md). The pure waypoint math
    lives in Shared/API/Navigation.lua and is headless-tested.

    GATING: this service no-ops outside Studio (RunService:IsStudio()), and its
    bus commands are testOnly, so there is no path to it from a live client.

    STATUS: the pure core (Navigation) is verified headlessly; the Roblox-runtime
    paths below (pathfinding, MoveTo, snapshot/restore) are written to the
    documented service APIs but still need live Studio verification — in
    particular the player-control caveat in NavigateTo.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Navigation = require(ReplicatedStorage.Shared.API.Navigation)

local AutomationService = {}
AutomationService.__index = AutomationService

local DEFAULT_ARRIVE_THRESHOLD = 4 -- studs
local DEFAULT_TIMEOUT = 15 -- seconds
local STUCK_EPSILON = 0.15 -- studs of progress per re-check to count as moving
local CONTROL_REMOTE_NAME = "AutomationControl" -- paired with the client bridge

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepCopy(child)
    end
    return copy
end

local function getRootPart(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local character = player and player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

function AutomationService:Init()
    self._logger = self._modules and self._modules.Logger
    self._dataService = self._modules and self._modules.DataService
    self._gameApi = self._modules and self._modules.GameAPIService
    self._snapshots = {}
    self._nextSnapshotId = 0
end

function AutomationService:Start()
    if not RunService:IsStudio() then
        return -- never active outside Studio
    end

    -- Control bridge: a RemoteEvent the client AutomationControlBridge listens to,
    -- so NavigateTo can disable the player's controls during automated movement.
    local existing = ReplicatedStorage:FindFirstChild(CONTROL_REMOTE_NAME)
    if existing then
        existing:Destroy()
    end
    local controlRemote = Instance.new("RemoteEvent")
    controlRemote.Name = CONTROL_REMOTE_NAME
    controlRemote.Parent = ReplicatedStorage
    self._controlRemote = controlRemote

    -- Studio-only: let an MCP-driven client trigger a SERVER-side run of the
    -- integration suite, where test-only commands are permitted. The remote only
    -- exists in Studio, so there is no production exposure.
    local existingSuite = ReplicatedStorage:FindFirstChild("RunAutomationSuite")
    if existingSuite then
        existingSuite:Destroy()
    end
    local suiteRemote = Instance.new("RemoteFunction")
    suiteRemote.Name = "RunAutomationSuite"
    suiteRemote.OnServerInvoke = function(invokingPlayer)
        local ok, suiteOrErr = pcall(function()
            return require(ReplicatedStorage.Tests.studio.AutomationSuite)
        end)
        if not ok then
            return game:GetService("HttpService"):JSONEncode({
                ok = false,
                error = "failed to load AutomationSuite: " .. tostring(suiteOrErr),
            })
        end
        return suiteOrErr.run({ player = invokingPlayer })
    end
    suiteRemote.Parent = ReplicatedStorage
    self._suiteRemote = suiteRemote

    -- Expose automation.* commands through the GameAPI bus (injected dependency,
    -- so it's available regardless of Start order) — one boundary for the harness.
    if self._gameApi and self._gameApi.GetBus then
        self:RegisterInto(self._gameApi:GetBus())
    end

    if self._logger then
        self._logger:Info("AutomationService ready (Studio test driver)")
    end
end

-- Toggle the local player's controls via the client bridge (best-effort).
function AutomationService:_setPlayerControls(player, enabled)
    if self._controlRemote then
        self._controlRemote:FireClient(player, enabled)
    end
end

-- Resolve a navigation/teleport target to a Vector3. Accepts a Vector3, a
-- BasePart, a Model (uses pivot), or a { x, y, z } table.
function AutomationService:_resolveTargetPosition(target)
    if typeof(target) == "Vector3" then
        return target
    end
    if typeof(target) == "Instance" then
        if target:IsA("BasePart") then
            return target.Position
        end
        if target:IsA("Model") then
            return target:GetPivot().Position
        end
    end
    if type(target) == "table" and target.x and target.y and target.z then
        return Vector3.new(target.x, target.y, target.z)
    end
    return nil
end

--[[
    Move a player's character to a target using PathfindingService, falling back
    to a direct MoveTo if a path can't be computed.

    opts: { threshold = studs, timeout = seconds, speedMultiplier = number }

    Controls are disabled for the duration (via the AutomationControl bridge) so
    the client control module doesn't fight MoveTo, then always re-enabled — even
    on error — by the pcall wrapper. As a second line of defense the follow loop
    re-issues MoveTo each sample and detects stalls (Navigation.madeProgress).
    Verify this path live in Studio (gap G6).
]]
function AutomationService:NavigateTo(player, target, opts)
    opts = opts or {}
    local threshold = opts.threshold or DEFAULT_ARRIVE_THRESHOLD
    local timeout = opts.timeout or DEFAULT_TIMEOUT

    local destination = self:_resolveTargetPosition(target)
    if not destination then
        return { ok = false, reason = "unresolved_target" }
    end

    local humanoid = getHumanoid(player)
    if not humanoid or not getRootPart(player) then
        return { ok = false, reason = "character_not_ready" }
    end

    if opts.speedMultiplier then
        humanoid.WalkSpeed = humanoid.WalkSpeed * opts.speedMultiplier
    end

    self:_setPlayerControls(player, false)
    local ok, result = pcall(function()
        return self:_followPath(player, humanoid, destination, threshold, timeout)
    end)
    self:_setPlayerControls(player, true)

    if not ok then
        return { ok = false, reason = "navigate_error", error = tostring(result) }
    end
    return result
end

-- Walk the character to `destination` along a computed path. Assumes the caller
-- has disabled controls. Returns a result envelope.
function AutomationService:_followPath(player, humanoid, destination, threshold, timeout)
    local root = getRootPart(player)
    if not root then
        return { ok = false, reason = "character_not_ready" }
    end

    -- Compute a path; fall back to a single direct waypoint on failure.
    local waypoints
    local path = PathfindingService:CreatePath()
    local computed = pcall(function()
        path:ComputeAsync(root.Position, destination)
    end)
    if computed and path.Status == Enum.PathStatus.Success then
        waypoints = path:GetWaypoints()
    else
        waypoints = { { Position = destination, Action = Enum.PathWaypointAction.Walk } }
    end
    local total = #waypoints
    if total == 0 then
        return { ok = false, reason = "empty_path" }
    end

    local index = 1
    local elapsed = 0
    local lastPos = root.Position
    while true do
        local waypoint = waypoints[index]
        humanoid:MoveTo(waypoint.Position) -- re-issued each loop to fight control cancel
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        local dt = task.wait(0.1)
        elapsed += dt
        if elapsed > timeout then
            return { ok = false, reason = "timeout", reached = index, total = total }
        end

        root = getRootPart(player)
        if not root then
            return { ok = false, reason = "character_lost" }
        end

        local distance = Navigation.planarDistance(
            root.Position.X,
            root.Position.Z,
            waypoint.Position.X,
            waypoint.Position.Z
        )
        local moved = Navigation.distance3(
            root.Position.X,
            root.Position.Y,
            root.Position.Z,
            lastPos.X,
            lastPos.Y,
            lastPos.Z
        )
        lastPos = root.Position

        local done
        index, done = Navigation.advanceWaypoint(index, distance, threshold, total)
        if done then
            break
        end

        -- Stall guard: if we've stopped progressing well short of the goal,
        -- surface it rather than hang.
        if not Navigation.madeProgress(moved, STUCK_EPSILON) and elapsed > 1 then
            return { ok = false, reason = "stalled", reached = index, total = total }
        end
    end

    return {
        ok = true,
        position = { x = root.Position.X, y = root.Position.Y, z = root.Position.Z },
        waypoints = total,
    }
end

-- CFrame placement for fast staging only. Not a substitute for NavigateTo when
-- the traversal itself is under test.
function AutomationService:TeleportForSetup(player, target)
    local position = self:_resolveTargetPosition(target)
    if not position then
        return { ok = false, reason = "unresolved_target" }
    end
    local root = getRootPart(player)
    if not root then
        return { ok = false, reason = "character_not_ready" }
    end
    root.CFrame = CFrame.new(position)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    return { ok = true, position = { x = position.X, y = position.Y, z = position.Z } }
end

-- Capture currency + inventory + position so a test can roll back afterwards.
function AutomationService:SnapshotState(player)
    if not self._dataService then
        return { ok = false, reason = "service_unavailable" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end

    local root = getRootPart(player)
    self._nextSnapshotId += 1
    local id = self._nextSnapshotId
    self._snapshots[id] = {
        userId = player.UserId,
        currencies = deepCopy(data.Currencies or {}),
        inventory = deepCopy(data.Inventory or {}),
        position = root and { x = root.Position.X, y = root.Position.Y, z = root.Position.Z },
    }
    return { ok = true, snapshotId = id }
end

-- Roll a player back to a prior snapshot.
function AutomationService:RestoreState(player, snapshotId)
    local snapshot = self._snapshots[snapshotId]
    if not snapshot then
        return { ok = false, reason = "unknown_snapshot" }
    end
    if not self._dataService then
        return { ok = false, reason = "service_unavailable" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end

    for currencyType, amount in pairs(snapshot.currencies) do
        self._dataService:SetCurrency(player, currencyType, amount, "automation_restore")
    end
    data.Inventory = deepCopy(snapshot.inventory)
    self._dataService:RequestSave(player, "automation_restore", { critical = true })

    if snapshot.position then
        local root = getRootPart(player)
        if root then
            root.CFrame = CFrame.new(snapshot.position.x, snapshot.position.y, snapshot.position.z)
        end
    end

    return { ok = true }
end

-- Read authoritative state for assertions.
function AutomationService:GetPlayerState(player)
    if not self._dataService then
        return { ok = false, reason = "service_unavailable" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    local root = getRootPart(player)
    return {
        ok = true,
        currencies = deepCopy(data.Currencies or {}),
        position = root and { x = root.Position.X, y = root.Position.Y, z = root.Position.Z },
    }
end

--[[
    Expose the automation methods as test-only commands on the GameAPI bus.
    Targets in args may be { x, y, z } coordinates or an instancePath string
    resolved from the data model.
]]
function AutomationService:RegisterInto(bus)
    if not bus or self._registered then
        return
    end
    self._registered = true

    local function resolveInstancePath(path)
        if type(path) ~= "string" then
            return nil
        end
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            if segment ~= "game" then
                node = node and node:FindFirstChild(segment)
            end
        end
        return node
    end

    local function resolveArgTarget(args)
        if args.instancePath then
            return resolveInstancePath(args.instancePath)
        end
        return { x = args.x, y = args.y, z = args.z }
    end

    bus:registerMany({
        ["automation.navigateTo"] = {
            description = "[test] Walk the player to a target via pathfinding.",
            testOnly = true,
            handler = function(context, args)
                return self:NavigateTo(context.player, resolveArgTarget(args), args.opts)
            end,
        },
        ["automation.teleportForSetup"] = {
            description = "[test] CFrame the player to a target (staging only).",
            testOnly = true,
            handler = function(context, args)
                return self:TeleportForSetup(context.player, resolveArgTarget(args))
            end,
        },
        ["automation.snapshotState"] = {
            description = "[test] Snapshot currency/inventory/position; returns snapshotId.",
            testOnly = true,
            handler = function(context)
                return self:SnapshotState(context.player)
            end,
        },
        ["automation.restoreState"] = {
            description = "[test] Restore a prior snapshot by snapshotId.",
            testOnly = true,
            handler = function(context, args)
                return self:RestoreState(context.player, args.snapshotId)
            end,
        },
        ["automation.getPlayerState"] = {
            description = "[test] Read authoritative currency/position for assertions.",
            testOnly = true,
            handler = function(context)
                return self:GetPlayerState(context.player)
            end,
        },
    })
end

-- Convenience for in-Studio scripts that hold a player reference directly.
function AutomationService:GetPlayerByName(name)
    return Players:FindFirstChild(name)
end

return AutomationService
