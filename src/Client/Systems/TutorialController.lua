--[[
    TutorialController (client) — renders the server-pushed tutorial state (Signals.TutorialState,
    TutorialFlow.stateFor shape). Three guidance surfaces, all torn down between steps:

      capsule  — the objective card. Docks INTO the TopHudStack (under the player bar, where
                 the quest tracker lives — Jason: the tutorial IS the new player's quest) and
                 HIDES the quest_tracker_pane while active; quests reappear there when done.
                 Falls back to a bottom-center ScreenGui if the stack never shows up.
      beacon   — target.kind == "egg": pulsing BillboardGui over the NEAREST world egg (egg models
                 carry an EggInfo child — same detection as the BootLoader gate), re-aimed every 2s
      pulse    — target.kind == "ui": breathing gold UIStroke around the named GuiObject, found
                 recursively in PlayerGui with retry (e.g. LevelUpButton only exists when pending)

    Progress is server-authoritative; this never advances anything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local TUTORIAL_CFG
pcall(function()
    TUTORIAL_CFG = require(ReplicatedStorage.Configs:WaitForChild("tutorial"))
end)

local GOLD = Color3.fromRGB(255, 205, 70)

local TutorialController = {}
local started = false

local gui -- ScreenGui (capsule lives here)
local capsule, stepLabel, titleLabel, bodyLabel
local beacon -- BillboardGui (parented to the current nearest egg)
local pulseStroke -- UIStroke on the current ui target
local pulseArrow -- blinking arrow floating above the current ui target (small buttons need a louder cue)
local stepToken = 0 -- bumps every state push; loops check it to die

local questPane -- quest_tracker_pane (hidden while the tutorial runs)
local docked = false
local tutorialActive = false

-- one rule: while the tutorial runs (and we're docked in the stack), quests yield the spot
local function syncQuestPane()
    if docked and questPane then
        questPane.Visible = not tutorialActive
    end
end

local function buildCapsule(pg)
    gui = Instance.new("ScreenGui")
    gui.Name = "TutorialGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 40
    gui.IgnoreGuiInset = true

    capsule = Instance.new("Frame")
    capsule.Name = "Objective"
    capsule.AnchorPoint = Vector2.new(0.5, 1)
    capsule.Position = UDim2.new(0.5, 0, 1, -140) -- fallback spot (above the hotbar)
    capsule.Size = UDim2.fromOffset(360, 88) -- room for 3-line bodies (farm step)
    capsule.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
    capsule.BackgroundTransparency = 0.12
    capsule.Visible = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = capsule
    local stroke = Instance.new("UIStroke")
    stroke.Color = GOLD
    stroke.Thickness = 2
    stroke.Parent = capsule

    stepLabel = Instance.new("TextLabel")
    stepLabel.BackgroundTransparency = 1
    stepLabel.Size = UDim2.new(1, -20, 0, 16)
    stepLabel.Position = UDim2.fromOffset(10, 6)
    stepLabel.Font = Enum.Font.GothamBold
    stepLabel.TextSize = 11
    stepLabel.TextColor3 = GOLD
    stepLabel.TextXAlignment = Enum.TextXAlignment.Left
    stepLabel.Parent = capsule

    titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -20, 0, 18)
    titleLabel.Position = UDim2.fromOffset(10, 21)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = capsule

    bodyLabel = Instance.new("TextLabel")
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Size = UDim2.new(1, -20, 0, 42)
    bodyLabel.Position = UDim2.fromOffset(10, 41)
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextSize = 12
    bodyLabel.TextWrapped = true
    bodyLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
    bodyLabel.Parent = capsule

    capsule.Parent = gui
    gui.Parent = pg
    require(script.Parent.Parent.UI.UIViewportScale).attach(capsule)

    -- Dock into the TopHudStack (above the quest tracker, same screen home as quests).
    -- The stack's capsule already carries a ViewportScale, so ours goes when we move in.
    task.spawn(function()
        local barGui = pg:WaitForChild("PlayerBar", 20)
        local cap = barGui and barGui:WaitForChild("Capsule", 10)
        local stack = cap and cap:WaitForChild("TopHudStack", 10)
        if not (stack and capsule) then
            return -- fallback: stays bottom-center in its own gui
        end
        local own = capsule:FindFirstChild("ViewportScale")
        if own then
            own:Destroy()
        end
        capsule.LayoutOrder = 0 -- above the quest tracker slot
        capsule.Parent = stack
        docked = true
        questPane = stack:FindFirstChild("quest_tracker_pane")
            or stack:WaitForChild("quest_tracker_pane", 15)
        if gui then
            gui:Destroy()
            gui = nil
        end
        syncQuestPane()
    end)
end

local pathFolder -- ground breadcrumb trail (egg steps)

local function clearGuidance()
    if beacon then
        beacon:Destroy()
        beacon = nil
    end
    if pulseStroke then
        pulseStroke:Destroy()
        pulseStroke = nil
    end
    if pulseArrow then
        pulseArrow:Destroy()
        pulseArrow = nil
    end
    if pathFolder then
        pathFolder:Destroy()
        pathFolder = nil
    end
end

-- prefer: optional hatcher-name match (e.g. "Grass") — the tutorial steers new
-- players to the STARTER egg, not just whatever egg is geometrically nearest (Jason:
-- "pointing over to the lava egg and not the actual earth egg"). Falls back to
-- any egg when no candidate matches.
local function nearestEgg(prefer)
    local char = Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil -- distance-0-for-everything would let ITERATION ORDER pick (sand bug)
    end
    local best, bestDist, bestPref, bestPrefDist
    local function matches(model)
        if not prefer then
            return false
        end
        local node = model
        for _ = 1, 4 do -- the hatcher folder is a near ancestor (Grass/PlacedEgg)
            if node and node.Name:find(prefer) then
                return true
            end
            node = node and node.Parent
        end
        return false
    end
    local function consider(model)
        local pivot = model:GetPivot().Position
        local d = (pivot - hrp.Position).Magnitude
        if not best or d < bestDist then
            best, bestDist = model, d
        end
        if matches(model) and (not bestPref or d < bestPrefDist) then
            bestPref, bestPrefDist = model, d
        end
    end
    -- authored egg stands (EggStandPlacement): Maps/**/PlacedEgg — the live map's eggs
    local maps = Workspace:FindFirstChild("Maps")
    if maps then
        for _, d in ipairs(maps:GetDescendants()) do
            if d:IsA("Model") and d.Name == "PlacedEgg" then
                consider(d)
            end
        end
    end
    -- legacy spawner eggs (EggSpawner): workspace children carrying EggInfo
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("EggInfo") then
            consider(child)
        end
    end
    return bestPref or best
end

-- Nearest SMALL crystal (Jason: "lead them to a small crystal first" — small = fast
-- break = fast first payout). Smallest MaxHP band in the area, nearest within the band.
local function nearestSmallCrystal()
    local char = Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end
    local game_ = Workspace:FindFirstChild("Game")
    local root = game_ and game_:FindFirstChild("Breakables")
    if not root then
        return nil
    end
    local best, bestHp, bestDist
    for _, m in ipairs(root:GetDescendants()) do
        if m:IsA("Model") and m:GetAttribute("MaxHP") and m:GetAttribute("Dead") ~= true then
            local hp = tonumber(m:GetAttribute("MaxHP")) or math.huge
            local d = (m:GetPivot().Position - hrp.Position).Magnitude
            if d < 400 then
                -- smaller wins; same size class (within 25%) -> nearer wins
                if not best or hp < bestHp * 0.75 or (hp <= bestHp * 1.25 and d < bestDist) then
                    best, bestHp, bestDist = m, hp, d
                end
            end
        end
    end
    return best
end

local function showEggBeacon(token, finder, label)
    finder = finder or nearestEgg
    beacon = Instance.new("BillboardGui")
    beacon.Name = "TutorialBeacon"
    beacon.Size = UDim2.fromOffset(120, 56)
    beacon.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
    beacon.AlwaysOnTop = true
    beacon.MaxDistance = 500
    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.fromScale(1, 1)
    arrow.Font = Enum.Font.GothamBlack
    arrow.TextSize = 22
    arrow.TextColor3 = GOLD
    arrow.TextStrokeTransparency = 0.4
    arrow.Text = label or "⬇ HATCH"
    arrow.Parent = beacon

    -- keep it on the NEAREST target + bob it (cheap: re-aim every 2s, bob via sine each frame)
    task.spawn(function()
        local t0 = os.clock()
        while token == stepToken and beacon do
            local egg = finder()
            if egg then
                beacon.Parent = egg
            end
            local reaim = os.clock() + 2
            while token == stepToken and beacon and os.clock() < reaim do
                beacon.StudsOffsetWorldSpace =
                    Vector3.new(0, 6 + math.sin((os.clock() - t0) * 3) * 0.8, 0)
                RunService.RenderStepped:Wait()
            end
        end
    end)
end

-- Breadcrumb trail on the GROUND from the player to the nearest egg (Jason: "a path on
-- the ground that the player follows... until the proximity menu appears"). Pathfinding
-- waypoints render as flat gold discs that ripple toward the egg; the trail recomputes as
-- the player moves and disappears inside prompt range (the ProximityPrompt takes over).
local PROMPT_RANGE = 12 -- studs: hide the trail once the hatch prompt is reachable
local REPLAN_SECONDS = 0.5 -- LIVE trail: full replan every cycle (Jason: "no matter where
-- the player moves... the trail's always correct"). No thresholds, no locked targets —
-- early-replication races, streaming, respawns all self-heal within one cycle.

local function showEggPath(token, finder)
    finder = finder or nearestEgg
    pathFolder = Instance.new("Folder")
    pathFolder.Name = "TutorialPath"
    pathFolder.Parent = Workspace

    local PathfindingService = game:GetService("PathfindingService")

    local function dot(pos, index)
        local d = Instance.new("Part")
        d.Shape = Enum.PartType.Cylinder
        d.Size = Vector3.new(0.2, 2.2, 2.2)
        d.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
        d.Anchored = true
        d.CanCollide = false
        d.CanQuery = false
        d.CastShadow = false
        d.Material = Enum.Material.Neon
        d.Color = GOLD
        d.Transparency = 0.35
        d:SetAttribute("TrailIndex", index)
        d.Parent = pathFolder
        return d
    end

    task.spawn(function()
        while token == stepToken and pathFolder do
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local egg = finder()
            if hrp and egg then
                local target = egg:GetPivot().Position
                local dist = (target - hrp.Position).Magnitude
                if dist <= PROMPT_RANGE then
                    -- close enough: the prompt is the guidance now
                    pathFolder:ClearAllChildren()
                else
                    -- CLEAR FIRST, every cycle. The old structure cleared only inside the
                    -- pathfind-SUCCESS branch and the fallback drew only into an EMPTY
                    -- folder — with NoPath (this map, always) the first boot-time plan
                    -- (drawn before the eggs even replicated) could never be redrawn.
                    -- THE frozen-wrong-trail bug, all builds, all day.
                    pathFolder:ClearAllChildren()
                    local path = PathfindingService:CreatePath({
                        AgentRadius = 2,
                        AgentCanJump = true,
                    })
                    local ok = pcall(function()
                        path:ComputeAsync(hrp.Position, target)
                    end)
                    if ok and path.Status == Enum.PathStatus.Success then
                        local n = 0
                        for _, wp in ipairs(path:GetWaypoints()) do
                            -- skip dots under the player's FEET (by distance, not waypoint
                            -- count — count-skipping ate most of a short route: Jason saw
                            -- "two dots in front of the hatch") and stop short of the egg
                            n += 1
                            if
                                (wp.Position - hrp.Position).Magnitude > 4
                                and (wp.Position - target).Magnitude > PROMPT_RANGE * 0.6
                            then
                                dot(wp.Position, n)
                            end
                        end
                    end
                    -- straight-line fallback when pathfinding drew nothing (NoPath) —
                    -- each dot raycast-snapped to the ground
                    if #pathFolder:GetChildren() == 0 and dist > PROMPT_RANGE then
                        local params = RaycastParams.new()
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        params.FilterDescendantsInstances = { char, pathFolder }
                        local dir = (target - hrp.Position) * Vector3.new(1, 0, 1)
                        local flat = dir.Magnitude
                        if flat > 1 then
                            dir = dir.Unit
                            local steps = math.min(14, math.floor(flat / 6))
                            for i = 2, steps do
                                local pos = hrp.Position + dir * (i * 6)
                                local hit = Workspace:Raycast(
                                    pos + Vector3.new(0, 10, 0),
                                    Vector3.new(0, -40, 0),
                                    params
                                )
                                if hit and (target - pos).Magnitude > PROMPT_RANGE * 0.6 then
                                    dot(hit.Position, i)
                                end
                            end
                        end
                    end
                end
            end
            -- ripple: pulse dots in sequence so the trail FLOWS toward the egg
            local nextPlan = os.clock() + REPLAN_SECONDS
            while token == stepToken and pathFolder and os.clock() < nextPlan do
                local t = os.clock() * 4
                for _, d in ipairs(pathFolder:GetChildren()) do
                    local i = d:GetAttribute("TrailIndex") or 0
                    d.Transparency = 0.25 + 0.45 * (0.5 + 0.5 * math.sin(t - i * 0.7))
                end
                task.wait(0.05)
            end
        end
    end)
end

-- withArrow: add a blinking ⬇ above the target (PRIMARY ui targets only). A secondary ui pulse (the
-- farm step's Farm-Near cue alongside the crystal beacon) gets just the stroke — an arrow there reads
-- as a second "do this" when the real target is the crystal (Jason: "you put an arrow at farm near").
local function showUiPulse(token, name, withArrow)
    task.spawn(function()
        local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
        -- the target may not exist yet (LevelUpButton appears with pending levels) — poll politely
        local target
        while token == stepToken and not target do
            target = pg:FindFirstChild(name, true)
            if not target then
                task.wait(1)
            end
        end
        if token ~= stepToken or not target then
            return
        end
        pulseStroke = Instance.new("UIStroke")
        pulseStroke.Color = GOLD
        pulseStroke.Thickness = 3
        pulseStroke.Parent = target

        if not withArrow then
            -- stroke-only cue; blink it and bail (no arrow for secondary targets)
            local t0 = os.clock()
            while token == stepToken and pulseStroke do
                pulseStroke.Transparency = 0.25
                    + 0.55 * (0.5 + 0.5 * math.sin((os.clock() - t0) * 4))
                RunService.RenderStepped:Wait()
            end
            return
        end

        -- A blinking arrow floating just above the target. The breathing stroke alone is easy to miss on
        -- a small button (e.g. the power bar's Edit), so this points right at it. Parented to the target
        -- so it tracks the button; bobs + blinks via the loop below.
        pulseArrow = Instance.new("TextLabel")
        pulseArrow.Name = "TutorialArrow"
        pulseArrow.BackgroundTransparency = 1
        pulseArrow.AnchorPoint = Vector2.new(0.5, 1)
        pulseArrow.Position = UDim2.new(0.5, 0, 0, -4) -- centered just above the target
        pulseArrow.Size = UDim2.fromOffset(48, 30)
        pulseArrow.Font = Enum.Font.GothamBlack
        pulseArrow.TextSize = 26
        pulseArrow.TextColor3 = GOLD
        pulseArrow.TextStrokeColor3 = Color3.new(0, 0, 0)
        pulseArrow.TextStrokeTransparency = 0.3
        pulseArrow.Text = "⬇"
        pulseArrow.ZIndex = 50
        pulseArrow.Parent = target

        local t0 = os.clock()
        while token == stepToken and pulseStroke do
            local s = 0.5 + 0.5 * math.sin((os.clock() - t0) * 4)
            pulseStroke.Transparency = 0.25 + 0.55 * s
            if pulseArrow then
                pulseArrow.TextTransparency = 0.05 + 0.55 * s -- blink
                pulseArrow.Position = UDim2.new(0.5, 0, 0, -4 - math.floor(6 * s)) -- bob
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

local function apply(state)
    stepToken += 1
    clearGuidance()
    if type(state) ~= "table" or state.done then
        local wasActive = tutorialActive
        tutorialActive = false
        if wasActive and capsule then
            -- LIVE completion (not a veteran/rejoin done-state): hold the spot for the
            -- handoff card — "quests unlocked, climb to Level 2" — then yield to quests.
            -- The celebration stinger/burst rides the tutorial_complete game event.
            local doneCfg = (TUTORIAL_CFG and TUTORIAL_CFG.completion) or {}
            local token = stepToken
            stepLabel.Text = "TUTORIAL COMPLETE"
            titleLabel.Text = doneCfg.title or "🎉 QUESTS UNLOCKED!"
            bodyLabel.Text = doneCfg.body or "Your missions are in the tracker up top!"
            capsule.Visible = true
            task.delay(tonumber(doneCfg.show_seconds) or 8, function()
                if stepToken == token and capsule then
                    capsule.Visible = false
                    syncQuestPane()
                end
            end)
            return
        end
        if capsule then
            capsule.Visible = false
        end
        syncQuestPane() -- hand the spot back to quests
        return
    end
    tutorialActive = true
    syncQuestPane()
    stepLabel.Text = ("TUTORIAL  %d / %d"):format(state.index or 1, state.total or 1)
        .. (
            (state.need or 1) > 1 and ("   ·   %d / %d"):format(state.count or 0, state.need) or ""
        )
    titleLabel.Text = state.title or ""
    bodyLabel.Text = state.body or ""
    capsule.Visible = true

    local target = state.target or {}
    if target.kind == "egg" then
        local finder = function()
            return nearestEgg(target.prefer)
        end
        showEggBeacon(stepToken, finder)
        showEggPath(stepToken, finder)
    elseif target.kind == "crystal" then
        showEggBeacon(stepToken, nearestSmallCrystal, "⬇ MINE")
        showEggPath(stepToken, nearestSmallCrystal)
    elseif target.kind == "ui" and type(target.name) == "string" then
        showUiPulse(stepToken, target.name, true) -- primary ui target → arrow
    end
    if target.ui and type(target.ui) == "string" then
        showUiPulse(stepToken, target.ui) -- secondary UI pulse alongside a world target — stroke only
    end
end

-- bumped per behavior change: printed at start so a LIVE session's running BYTECODE is
-- identifiable (rojo syncs Source into running sessions but required modules never
-- re-execute — we chased "stale build vs real bug" three times today)
local BUILD = "trail-live-replan v5 short-range (2026-06-10)"

function TutorialController.start()
    if started then
        return
    end
    started = true
    print("[TutorialController] build:", BUILD)
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    buildCapsule(pg)
    Signals.TutorialState.OnClientEvent:Connect(apply)
    -- pull current state — the server's join-time push may predate this connection
    Signals.TutorialState:FireServer()
end

return TutorialController
