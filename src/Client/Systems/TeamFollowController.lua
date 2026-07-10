--[[
    TeamFollowController — CoH-style /follow for TEAMMATES (Jason 2026-07-07: "any team member
    can follow another team member … F would work but not on mobile").

    Any member can auto-follow any teammate: the character walks after them (Humanoid:MoveTo,
    client-authoritative movement) and ANY manual movement input — WASD or the mobile joystick,
    read via the PlayerModule move vector — breaks the follow, so mouse+keyboard and touch get
    the same contract. Toggled from SquadHud (follow chip on the mate card = the mobile-first
    button; F with a teammate selected = the keyboard shortcut).

    REALM PORTALS (Jason: "account for follows to the portals two different realms"): realm
    worlds sit at ±Y offsets, so walking can't cross one. When the followed teammate's published
    CurrentLayer attribute stops matching ours, the client asks the server for team.follow_warp —
    PartyService re-runs the portal's own gates (geometry + level vs EffectiveLevel) and routes
    LayerService:UseLayer, landing us at the realm entry exactly as if we'd touched the portal.
    Never a same-layer teleport (teleport-to-teammate stays a future POWER, docs/TEAMING.md).

    Follow drops when: the target leaves the team/game, we take manual control, or the toggle
    is hit again. It survives our own death/respawn only by being cancelled (a corpse-drag
    follow reads as a bug), and a warp that keeps failing (level gate) cancels too.

    HYBRID PATHFINDING (Jason 2026-07-09: "I got stuck behind a wall"): the straight-line
    MoveTo stays the default — correct 90% of the time in the open. A progress WATCHDOG
    (closest-approach hasn't improved for stuck_window seconds — it observes "no progress",
    never elapsed-time-as-readiness) flips to a computed path: walk the waypoints, fire
    Humanoid.Jump on Jump labels (fences/crates), recompute if the target drifts from the
    path goal, and drop back to direct the moment line-of-sight to the target returns.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local REMOTE_NAME = "GameAPICommand" -- the bus remote (same path TeamPanel uses)

local TeamFollowController = {}

local followName = nil -- who we're following (nil = off)
local listeners = {} -- fired with (nameOrNil) whenever follow state changes
local lastWarpAt = 0

local cfg = { stop_distance = 7, refresh = 0.15, warp_cooldown = 5 }
pcall(function()
    local teaming = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("teaming"))
    for k, v in pairs(teaming.follow or {}) do
        cfg[k] = v
    end
end)

local function fire()
    for _, fn in ipairs(listeners) do
        pcall(fn, followName)
    end
end

function TeamFollowController.following()
    return followName
end

function TeamFollowController.onChanged(fn)
    listeners[#listeners + 1] = fn
end

function TeamFollowController.set(name)
    if followName == name then
        return
    end
    followName = name
    fire()
end

function TeamFollowController.toggle(name)
    TeamFollowController.set(followName == name and nil or name)
end

-- The PlayerModule move vector is USER input only (MoveTo doesn't touch it), so a nonzero
-- read means the player grabbed the controls — keyboard or joystick — and follow yields.
local function userMoveVector()
    local ok, vec = pcall(function()
        local playerScripts = player:FindFirstChild("PlayerScripts")
        local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
        local controls = playerModule and require(playerModule):GetControls()
        return controls and controls:GetMoveVector()
    end)
    return (ok and vec) and vec or Vector3.zero
end

local function isTeammate(name)
    local members = player:GetAttribute("TeamMembers")
    if type(members) ~= "string" or members == "" then
        return false
    end
    for member in members:gmatch("[^,]+") do
        if member == name then
            return true
        end
    end
    return false
end

local function requestWarp(name)
    if os.clock() - lastWarpAt < (cfg.warp_cooldown or 5) then
        return
    end
    lastWarpAt = os.clock()
    task.spawn(function()
        local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if not remote then
            return
        end
        local ok, envelope = pcall(function()
            return remote:InvokeServer("team.follow_warp", { target = name })
        end)
        local res = ok and type(envelope) == "table" and envelope.result
        -- a HARD refusal (level gate / no geometry) won't clear itself — stop pestering
        if type(res) == "table" and res.ok == false and res.reason == "level_too_low" then
            TeamFollowController.set(nil)
        end
    end)
end

-- Line-of-sight to the target: blocked by world geometry only (both characters and
-- the pet folders are ignored — a pet crowd must not read as a wall).
local function hasLineOfSight(hrp, tHrp)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if player.Character then
        table.insert(ignore, player.Character)
    end
    if tHrp.Parent then
        table.insert(ignore, tHrp.Parent)
    end
    local pets = workspace:FindFirstChild("PlayerPets")
    if pets then
        table.insert(ignore, pets)
    end
    params.FilterDescendantsInstances = ignore
    local delta = tHrp.Position - hrp.Position
    return workspace:Raycast(hrp.Position, delta, params) == nil
end

function TeamFollowController.start()
    task.spawn(function()
        local wasMoving = false
        -- watchdog + path state (all reset when follow target changes/clears)
        local watchName = nil
        local bestDist = math.huge
        local lastGainAt = os.clock()
        local waypoints = nil -- non-nil = path mode
        local waypointIndex = 1
        local pathGoal = nil -- target position the current path was computed to
        local noPathUntil = 0 -- direct-mode fallback window after a failed compute

        local function resetNav()
            bestDist = math.huge
            lastGainAt = os.clock()
            waypoints, pathGoal = nil, nil
            waypointIndex = 1
        end

        local function computePath(hrp, tHrp)
            local path = PathfindingService:CreatePath({
                AgentRadius = 2.5,
                AgentHeight = 6,
                AgentCanJump = true,
            })
            local ok = pcall(function()
                path:ComputeAsync(hrp.Position, tHrp.Position)
            end)
            if ok and path.Status == Enum.PathStatus.Success then
                waypoints = path:GetWaypoints()
                waypointIndex = 2 -- [1] is where we stand
                pathGoal = tHrp.Position
                lastGainAt = os.clock() -- fresh grace for the first leg
            else
                -- unreachable (gap/void): stay direct for a beat, don't spin computes
                resetNav()
                noPathUntil = os.clock() + (cfg.path_fail_cooldown or 2)
            end
        end

        while true do
            task.wait(cfg.refresh or 0.15)
            local name = followName
            if name ~= watchName then
                watchName = name
                resetNav()
            end
            if name then
                local target = Players:FindFirstChild(name)
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local tHrp = target
                    and target.Character
                    and target.Character:FindFirstChild("HumanoidRootPart")
                -- cancel: they left the team/game, we died (don't drag the respawn around),
                -- or the player took the wheel (any manual movement input)
                if
                    not target
                    or not isTeammate(name)
                    or not (hum and hrp and hum.Health > 0)
                    or userMoveVector().Magnitude > 0.05
                then
                    TeamFollowController.set(nil)
                elseif
                    player:GetAttribute("CurrentLayer") ~= target:GetAttribute("CurrentLayer")
                then
                    requestWarp(name) -- they took a realm portal — ask to take it too
                elseif tHrp then
                    local delta = tHrp.Position - hrp.Position
                    local flat = Vector3.new(delta.X, 0, delta.Z)
                    local stop = cfg.stop_distance or 7
                    if flat.Magnitude <= stop then
                        -- arrived: settle and clear any path/watchdog state
                        resetNav()
                        if wasMoving then
                            hum:MoveTo(hrp.Position) -- cancel the stale MoveTo so we stop clean
                            wasMoving = false
                        end
                    elseif waypoints then
                        -- PATH MODE: leave it the moment the straight line is open again
                        if hasLineOfSight(hrp, tHrp) then
                            resetNav()
                        else
                            local wp = waypoints[waypointIndex]
                            if
                                not wp
                                or (
                                    pathGoal
                                    and (tHrp.Position - pathGoal).Magnitude
                                        > (cfg.repath_distance or 12)
                                )
                            then
                                computePath(hrp, tHrp) -- walked it out / target drifted: recompute
                            else
                                local wflat = Vector3.new(
                                    wp.Position.X - hrp.Position.X,
                                    0,
                                    wp.Position.Z - hrp.Position.Z
                                )
                                if wflat.Magnitude <= (cfg.waypoint_reach or 4) then
                                    waypointIndex += 1
                                    lastGainAt = os.clock() -- reaching a waypoint IS progress
                                else
                                    if wp.Action == Enum.PathWaypointAction.Jump then
                                        hum.Jump = true
                                    end
                                    hum:MoveTo(wp.Position)
                                    wasMoving = true
                                    -- a stalled WAYPOINT (door closed, geometry changed) recomputes
                                    if os.clock() - lastGainAt > (cfg.stuck_window or 1.2) * 2 then
                                        computePath(hrp, tHrp)
                                    end
                                end
                            end
                        end
                    else
                        -- DIRECT MODE: straight line + the no-progress watchdog
                        -- aim a hair short of them so we settle beside, not inside
                        hum:MoveTo(tHrp.Position - flat.Unit * (stop * 0.7))
                        wasMoving = true
                        if flat.Magnitude < bestDist - (cfg.stuck_epsilon or 1) then
                            bestDist = flat.Magnitude
                            lastGainAt = os.clock()
                        elseif
                            os.clock() - lastGainAt > (cfg.stuck_window or 1.2)
                            and os.clock() >= noPathUntil
                            and not hasLineOfSight(hrp, tHrp)
                        then
                            computePath(hrp, tHrp) -- wedged behind geometry: walk a real path
                        end
                    end
                end
            elseif wasMoving then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hum and hrp then
                    hum:MoveTo(hrp.Position)
                end
                wasMoving = false
            end
        end
    end)
end

return TeamFollowController
