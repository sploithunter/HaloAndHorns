--[[
    TutorialController (client) — renders the server-pushed tutorial state (Signals.TutorialState,
    TutorialFlow.stateFor shape). Three guidance surfaces, all torn down between steps:

      capsule  — the objective card. Lives in a responsive upper-right dock so it does not cover
                 the center playfield. It HIDES the quest_tracker_pane while active; quests
                 reappear there when done. Full-size menus temporarily hide the capsule.
      beacon   — target.kind == "egg": pulsing BillboardGui over the NEAREST world egg (egg models
                 carry an EggInfo child — same detection as the BootLoader gate), re-aimed every 2s
      pulse    — target.kind == "ui": breathing gold UIStroke around the named GuiObject, found
                 recursively in PlayerGui with retry (e.g. LevelUpButton only exists when pending)

    Progress is server-authoritative; this never advances anything.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local CoreGuiStateGuard = require(script.Parent.Parent.UI.CoreGuiStateGuard)
local WorldChevron = require(script.Parent.Parent.UI.WorldChevron)
local GameEvents = require(script.Parent.GameEvents)
local TutorialLanguageState = require(script.Parent.TutorialLanguageState)
local TutorialLocalization = require(ReplicatedStorage.Shared.Game.TutorialLocalization)
local TUTORIAL_CFG
pcall(function()
    TUTORIAL_CFG = require(ReplicatedStorage.Configs:WaitForChild("tutorial"))
end)
local COMBAT_TUTORIAL_CFG
pcall(function()
    COMBAT_TUTORIAL_CFG = require(ReplicatedStorage.Configs:WaitForChild("combat_tutorial"))
end)

local GOLD = Color3.fromRGB(255, 205, 70)
local PLAYER_LIST_PEEK_SECONDS = 10

local TutorialController = {}
local started = false

local gui -- ScreenGui (capsule lives here)
local capsule, stepLabel, titleLabel, bodyLabel
local beacon -- BillboardGui (parented to the current nearest egg)
local pulseStroke -- UIStroke on the current ui target
local pulseArrow -- blinking arrow floating above the current ui target (small buttons need a louder cue)
local pulseTarget -- exact GuiObject currently highlighted
local pulseTargetWasClipped -- restored when guidance ends
local cueOverlay -- ScreenGui above menus so inventory-clipped callouts stay visible
local stepToken = 0 -- bumps every state push; loops check it to die
local pulseGeneration = 0 -- invalidates an in-step cue when a multi-phase lesson changes target

local tutorialActive = false
local currentState
local completionCardVisible = false
local languageBannerShown = false
local capsuleWantedVisible = false
local handoffGui, handoffTitle, handoffBody, handoffOk, laterBtn
local showHandoffBanner
local playerListPeekUntil = 0
local playerListPeekConnection
local playerListGuard = CoreGuiStateGuard.new(function()
    return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
end, function(enabled)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, enabled)
end)

local function syncCapsuleVisibility()
    if not capsule then
        return
    end
    local player = Players.LocalPlayer
    local tutorialOwnsCorner = capsuleWantedVisible
        and player:GetAttribute("InPrologue") ~= true
        and player:GetAttribute("LargeMenuOpen") ~= true
    local peekingAtPlayers = tutorialOwnsCorner and os.clock() < playerListPeekUntil
    capsule.Visible = tutorialOwnsCorner and not peekingAtPlayers

    player:SetAttribute("PeopleListPeek", peekingAtPlayers == true)

    if tutorialOwnsCorner and not peekingAtPlayers then
        local suppressed, suppressError = playerListGuard:Suppress()
        if not suppressed then
            warn(
                "[TutorialController] Could not temporarily hide Roblox player list:",
                suppressError
            )
        end
    else
        local restored, restoreError = playerListGuard:Restore()
        if not restored then
            warn("[TutorialController] Could not restore Roblox player list:", restoreError)
        end
    end
end

local function setCapsuleWantedVisible(visible)
    capsuleWantedVisible = visible == true
    -- QuestTrackerStyle uses this ownership signal rather than inferring from the step id. It
    -- remains true through the tutorial-complete handoff card, so the two upper-right surfaces
    -- can never overlap.
    Players.LocalPlayer:SetAttribute("TutorialCornerOwned", capsuleWantedVisible)
    syncCapsuleVisibility()
end

local function showPlayerListTemporarily()
    if not capsuleWantedVisible or capsule.Visible ~= true then
        return
    end

    playerListPeekUntil = os.clock() + PLAYER_LIST_PEEK_SECONDS
    syncCapsuleVisibility()

    if playerListPeekConnection then
        playerListPeekConnection:Disconnect()
    end
    playerListPeekConnection = RunService.Heartbeat:Connect(function()
        if os.clock() < playerListPeekUntil then
            return
        end
        playerListPeekConnection:Disconnect()
        playerListPeekConnection = nil
        playerListPeekUntil = 0
        syncCapsuleVisibility()
    end)
end

local function buildCapsule(pg)
    gui = Instance.new("ScreenGui")
    gui.Name = "TutorialGui"
    gui.ResetOnSpawn = false
    -- Above the regular HUD (PlayerBar=80, BuffStats=100) so the full-card tap target cannot be
    -- intercepted by a transparent HUD surface. Full menus remain above it at 120 and hide it.
    gui.DisplayOrder = 110
    gui.IgnoreGuiInset = true

    -- Keep the screen-edge anchor outside the scaled card. UIScale scales a root's anchored
    -- placement as well as its contents on small viewports, which left a large false margin on
    -- phones. This dock must remain at the exact, scale-only upper-right corner; do not add pixel
    -- offsets here. The card hangs left from the dock and handles its own responsive scale.
    local dock = Instance.new("Frame")
    dock.Name = "TutorialDock"
    dock.AnchorPoint = Vector2.new(1, 0)
    dock.Position = UDim2.fromScale(1, 0)
    dock.Size = UDim2.fromOffset(0, 0)
    dock.BackgroundTransparency = 1
    dock.ClipsDescendants = false
    dock.Parent = gui

    capsule = Instance.new("Frame")
    capsule.Name = "Objective"
    capsule.AnchorPoint = Vector2.new(1, 0)
    capsule.Position = UDim2.fromOffset(0, 0)
    -- Mobile can shrink this HUD root to nearly half size. Keep the supporting copy at 18px and
    -- the title at 20px so the objective remains readable on a physical phone.
    capsule.Size = UDim2.fromOffset(420, 124)
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
    stepLabel.Size = UDim2.new(1, -20, 0, 18)
    stepLabel.Position = UDim2.fromOffset(10, 6)
    stepLabel.Font = Enum.Font.GothamBold
    stepLabel.TextSize = 18
    stepLabel.TextColor3 = GOLD
    stepLabel.TextXAlignment = Enum.TextXAlignment.Left
    stepLabel.Parent = capsule

    titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -20, 0, 22)
    titleLabel.Position = UDim2.fromOffset(10, 26)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = capsule

    bodyLabel = Instance.new("TextLabel")
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Size = UDim2.new(1, -20, 0, 68)
    bodyLabel.Position = UDim2.fromOffset(10, 50)
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextSize = 18
    bodyLabel.TextWrapped = true
    bodyLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
    bodyLabel.Parent = capsule

    local peekButton = Instance.new("TextButton")
    peekButton.Name = "ShowPlayersTemporarily"
    peekButton.Size = UDim2.fromScale(1, 1)
    peekButton.BackgroundTransparency = 1
    peekButton.Text = ""
    peekButton.AutoButtonColor = false
    peekButton.ZIndex = 10
    peekButton.Parent = capsule
    peekButton.Activated:Connect(showPlayerListTemporarily)

    laterBtn = Instance.new("TextButton")
    laterBtn.Name = "Later"
    laterBtn.AnchorPoint = Vector2.new(1, 1)
    laterBtn.Position = UDim2.new(1, -10, 1, -8)
    laterBtn.Size = UDim2.fromOffset(88, 28)
    laterBtn.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
    laterBtn.BorderSizePixel = 0
    laterBtn.AutoButtonColor = true
    laterBtn.Visible = false
    laterBtn.ZIndex = 20
    laterBtn.Font = Enum.Font.GothamBold
    laterBtn.TextSize = 16
    laterBtn.TextColor3 = Color3.fromRGB(28, 22, 16)
    laterBtn.Text = "Later"
    laterBtn.Parent = capsule
    local laterCorner = Instance.new("UICorner")
    laterCorner.CornerRadius = UDim.new(0, 8)
    laterCorner.Parent = laterBtn
    laterBtn.Activated:Connect(function()
        if type(currentState) == "table" then
            showHandoffBanner(currentState)
        end
    end)

    capsule.Parent = dock
    gui.Parent = pg
    require(script.Parent.Parent.UI.UIViewportScale).attach(capsule)

    handoffGui = Instance.new("ScreenGui")
    handoffGui.Name = "TutorialHandoffGui"
    handoffGui.ResetOnSpawn = false
    handoffGui.IgnoreGuiInset = true
    handoffGui.DisplayOrder = 125
    handoffGui.Enabled = false
    handoffGui.Parent = pg

    local scrim = Instance.new("Frame")
    scrim.Name = "Scrim"
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
    scrim.BackgroundTransparency = 0.28
    scrim.BorderSizePixel = 0
    scrim.Parent = handoffGui

    local card = Instance.new("Frame")
    card.Name = "Banner"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.42)
    card.Size = UDim2.new(0.72, 0, 0, 280)
    card.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
    card.BackgroundTransparency = 0.04
    card.BorderSizePixel = 0
    card.Parent = handoffGui
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 22)
    cardCorner.Parent = card
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = GOLD
    cardStroke.Thickness = 4
    cardStroke.Parent = card
    require(script.Parent.Parent.UI.UIViewportScale).attach(card)

    handoffTitle = Instance.new("TextLabel")
    handoffTitle.BackgroundTransparency = 1
    handoffTitle.Size = UDim2.new(1, -48, 0, 72)
    handoffTitle.Position = UDim2.fromOffset(24, 22)
    handoffTitle.Font = Enum.Font.GothamBlack
    handoffTitle.TextSize = 42
    handoffTitle.TextWrapped = true
    handoffTitle.TextColor3 = GOLD
    handoffTitle.TextXAlignment = Enum.TextXAlignment.Center
    handoffTitle.TextYAlignment = Enum.TextYAlignment.Center
    handoffTitle.Parent = card

    handoffBody = Instance.new("TextLabel")
    handoffBody.BackgroundTransparency = 1
    handoffBody.Size = UDim2.new(1, -56, 0, 96)
    handoffBody.Position = UDim2.fromOffset(28, 100)
    handoffBody.Font = Enum.Font.GothamBold
    handoffBody.TextSize = 26
    handoffBody.TextWrapped = true
    handoffBody.TextColor3 = Color3.fromRGB(236, 236, 244)
    handoffBody.TextXAlignment = Enum.TextXAlignment.Center
    handoffBody.TextYAlignment = Enum.TextYAlignment.Top
    handoffBody.Parent = card

    handoffOk = Instance.new("TextButton")
    handoffOk.Name = "Okay"
    handoffOk.AnchorPoint = Vector2.new(0.5, 1)
    handoffOk.Position = UDim2.new(0.5, 0, 1, -22)
    handoffOk.Size = UDim2.fromOffset(220, 56)
    handoffOk.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
    handoffOk.BorderSizePixel = 0
    handoffOk.AutoButtonColor = true
    handoffOk.Font = Enum.Font.GothamBlack
    handoffOk.TextSize = 26
    handoffOk.TextColor3 = Color3.fromRGB(28, 22, 16)
    handoffOk.Text = "Okay"
    handoffOk.Parent = card
    local okCorner = Instance.new("UICorner")
    okCorner.CornerRadius = UDim.new(0, 14)
    okCorner.Parent = handoffOk
    handoffOk.Activated:Connect(function()
        Signals.TutorialCombatTrainingAck:FireServer()
    end)
end

local function hideHandoffBanner()
    Players.LocalPlayer:SetAttribute("TutorialHandoffOpen", false)
    if handoffGui then
        handoffGui.Enabled = false
    end
end

showHandoffBanner = function(state)
    if not handoffGui then
        return
    end
    local localeId = TutorialLanguageState.getLocaleId()
    local spec = state.handoff or {}
    local baseKey = state.localization_key or "tutorial.first_fight"
    if type(state.id) == "string" then
        baseKey = "tutorial." .. state.id
    end
    handoffTitle.Text = TutorialLocalization.text(
        localeId,
        baseKey .. ".handoff.title",
        spec.title or "TO CONTINUE THE TUTORIAL"
    )
    handoffBody.Text = TutorialLocalization.text(
        localeId,
        baseKey .. ".handoff.body",
        spec.body or "It's in Quest."
    )
    handoffOk.Text =
        TutorialLocalization.text(localeId, baseKey .. ".handoff.ok", spec.ok_label or "Okay")
    handoffGui.Enabled = true
    Players.LocalPlayer:SetAttribute("TutorialHandoffOpen", true)
    if Players.LocalPlayer:GetAttribute("InputMode") == "gamepad" then
        GuiService.SelectedObject = handoffOk
    end
end

local pathFolder -- ground breadcrumb trail (egg steps)

local function clearUiGuidance()
    pulseGeneration += 1
    if pulseStroke then
        pulseStroke:Destroy()
        pulseStroke = nil
    end
    if pulseArrow then
        pulseArrow:Destroy()
        pulseArrow = nil
    end
    if pulseTarget and pulseTarget.Parent and pulseTargetWasClipped ~= nil then
        pulseTarget.ClipsDescendants = pulseTargetWasClipped
    end
    pulseTarget = nil
    pulseTargetWasClipped = nil
end

local function clearGuidance()
    if beacon then
        beacon:Destroy()
        beacon = nil
    end
    clearUiGuidance()
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
        if tostring(model:GetAttribute("EggId") or "") == tostring(prefer) then
            return true
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

-- Named world-part finder (target.kind == "part"): resolves a BasePart by
-- name. Prefer an authored root (Maps.Home for the Earth cave) so realm-layer
-- clones of BaddieSpawnerEarth don't steal the FIGHT arrow.
local function namedPartFinder(name, rootPath)
    return function()
        if type(rootPath) == "string" and rootPath ~= "" then
            local node = Workspace
            for segment in string.gmatch(rootPath, "[^.]+") do
                node = node and node:FindFirstChild(segment)
            end
            local rooted = node and node:FindFirstChild(name, true)
            if rooted then
                return rooted
            end
        end
        local maps = Workspace:FindFirstChild("Maps")
        local home = maps and maps:FindFirstChild("Home")
        local inHome = home and home:FindFirstChild(name, true)
        if inHome then
            return inHome
        end
        local inMaps = maps and maps:FindFirstChild(name, true)
        if inMaps then
            return inMaps
        end
        -- Combat training (and other door missions) stamp tiles under
        -- MissionInstances, not Workspace.Maps.
        local missions = Workspace:FindFirstChild("MissionInstances")
        return missions and missions:FindFirstChild(name, true)
    end
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

-- World-space breadcrumb trail from the player to the current objective. This is intentionally a
-- live direct line, not a navigation path: the endpoints are sampled every rendered frame, so
-- player/objective movement updates it continuously without pathfinding or a periodic replan.
-- Floating 3D chevrons flow toward the objective and disappear once its prompt is reachable.
local PROMPT_RANGE = 12 -- studs: hide the trail once the hatch prompt is reachable
local TRAIL_SPACING = 5.5
local TRAIL_MAX_MARKERS = 12
local TRAIL_START_DISTANCE = 4.5
local TRAIL_ARC_HEIGHT = 2.25
local TRAIL_TRAVEL_SPEED = 8 -- studs per second toward the objective

local function showEggPath(token, finder)
    finder = finder or nearestEgg
    pathFolder = Instance.new("Folder")
    pathFolder.Name = "TutorialPath"
    pathFolder.Parent = Workspace

    local function chevron(index)
        -- clearGuidance can nil pathFolder between frames; skip an orphaned marker.
        if not pathFolder then
            return nil
        end
        return WorldChevron.create(pathFolder, {
            name = "TutorialChevron",
            trailIndex = index,
        })
    end

    local markers = {}
    local function setMarkerVisual(marker, visible, fade)
        if not marker then
            return
        end
        for _, child in ipairs(marker:GetChildren()) do
            if child:IsA("BasePart") and child.Name ~= "Root" then
                child.Transparency = visible and (0.08 + (1 - fade) * 0.72) or 1
            elseif child:IsA("Highlight") then
                child.Enabled = visible
                if visible then
                    child.FillTransparency = 0.62 + (1 - fade) * 0.28
                    child.OutlineTransparency = 0.08 + (1 - fade) * 0.6
                end
            end
        end
    end

    for markerIndex = 1, TRAIL_MAX_MARKERS do
        local marker = chevron(markerIndex)
        markers[markerIndex] = marker
        setMarkerVisual(marker, false, 0)
    end

    task.spawn(function()
        while token == stepToken and pathFolder do
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local egg = finder()
            local canShow = hrp ~= nil and egg ~= nil
            local start = canShow and hrp.Position or Vector3.zero
            local target = canShow and egg:GetPivot().Position or Vector3.zero
            local distance = (target - start).Magnitude
            local endDistance = distance - PROMPT_RANGE * 0.6
            local travelLength = endDistance - TRAIL_START_DISTANCE

            if canShow and distance > PROMPT_RANGE and travelLength > 0.01 then
                local markerCount = math.min(
                    TRAIL_MAX_MARKERS,
                    math.max(1, math.floor(travelLength / TRAIL_SPACING))
                )
                local markerSeparation = travelLength / markerCount
                local now = os.clock()
                local travel = (now * TRAIL_TRAVEL_SPEED) % travelLength

                local function positionAt(alpha)
                    local point = start:Lerp(target, alpha)
                    return point + Vector3.new(0, math.sin(math.pi * alpha) * TRAIL_ARC_HEIGHT, 0)
                end

                for index, marker in ipairs(markers) do
                    if index <= markerCount and marker and marker.Parent then
                        local offset = (index - 1) * markerSeparation
                        local along = TRAIL_START_DISTANCE + ((offset + travel) % travelLength)
                        local alpha = math.clamp(along / distance, 0, 1)
                        local nextAlpha = math.clamp((along + 0.35) / distance, 0, 1)
                        local position = positionAt(alpha)
                        local nextPosition = positionAt(nextAlpha)
                        local facing = nextPosition - position
                        local edgeFade = math.min(
                            math.clamp((along - TRAIL_START_DISTANCE) / TRAIL_SPACING, 0, 1),
                            math.clamp((endDistance - along) / TRAIL_SPACING, 0, 1)
                        )
                        if facing.Magnitude > 0.01 then
                            marker:PivotTo(CFrame.lookAt(position, position + facing.Unit))
                            setMarkerVisual(marker, true, edgeFade)
                        else
                            setMarkerVisual(marker, false, 0)
                        end
                    else
                        setMarkerVisual(marker, false, 0)
                    end
                end
            else
                for _, marker in ipairs(markers) do
                    setMarkerVisual(marker, false, 0)
                end
            end

            RunService.RenderStepped:Wait()
        end
    end)
end

-- options.arrow: add a visible pointer above the target (PRIMARY ui targets only). A secondary ui pulse (the
-- farm step's Farm-Near cue alongside the crystal beacon) gets just the stroke — an arrow there reads
-- as a second "do this" when the real target is the crystal (Jason: "you put an arrow at farm near").
local function resolveInjuredSlot(pg)
    local slot = tonumber(Players.LocalPlayer:GetAttribute("CombatTutorialWoundSlot"))
    if slot and slot > 0 then
        return pg:FindFirstChild("Slot_" .. slot, true)
    end
    return nil
end

local function resolveTutorialEnemy(pg)
    local bid = tonumber(Players.LocalPlayer:GetAttribute("CombatTutorialTargetEnemy"))
    if bid and bid > 0 then
        return pg:FindFirstChild("Enemy_" .. bid, true)
    end
    return nil
end

local function ancestorClips(object)
    local node = object and object.Parent
    while node and not node:IsA("LayerCollector") do
        if node:IsA("GuiObject") and node.ClipsDescendants then
            return true
        end
        node = node.Parent
    end
    return false
end

local function ensureCueOverlay(pg)
    if cueOverlay and cueOverlay.Parent then
        return cueOverlay
    end
    cueOverlay = Instance.new("ScreenGui")
    cueOverlay.Name = "TutorialCueOverlay"
    cueOverlay.ResetOnSpawn = false
    -- Same inset space as MenuOverlay so AbsolutePosition on a card maps 1:1.
    cueOverlay.IgnoreGuiInset = false
    -- MenuOverlay is 120; inventory lives there. Sit above that so TAKE OFF
    -- is the same on-top sign as Pets / Activate, not a clipped triangle.
    cueOverlay.DisplayOrder = 130
    cueOverlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    cueOverlay.Parent = pg
    return cueOverlay
end

local function findUiTarget(pg, name, options)
    if options.hotbarTarget then
        local hotbar = pg:FindFirstChild("HotbarBar")
        if hotbar then
            for _, candidate in ipairs(hotbar:GetDescendants()) do
                if
                    candidate:IsA("GuiObject")
                    and candidate:GetAttribute("HotbarBindTarget") == options.hotbarTarget
                    and (
                        not options.hotbarType
                        or candidate:GetAttribute("HotbarBindType") == options.hotbarType
                    )
                then
                    return candidate
                end
            end
        end
        return nil
    end
    if name == "InjuredSlot" or options.injuredSlot then
        return resolveInjuredSlot(pg)
    end
    if name == "TutorialEnemy" then
        return resolveTutorialEnemy(pg)
    end
    if options.tutorialGuide then
        for _, candidate in ipairs(pg:GetDescendants()) do
            if
                candidate:IsA("GuiObject")
                and candidate:GetAttribute("TutorialGuide") == options.tutorialGuide
                and candidate.AbsoluteSize.X > 0
            then
                return candidate
            end
        end
        return nil
    end
    if type(name) == "string" and name ~= "" then
        return pg:FindFirstChild(name, true)
    end
    return nil
end

local function showUiPulse(token, name, options)
    options = options or {}
    pulseGeneration += 1
    local generation = pulseGeneration
    task.spawn(function()
        local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
        -- the target may not exist yet (LevelUpButton appears with pending levels) — poll politely
        local target
        while token == stepToken and generation == pulseGeneration and not target do
            target = findUiTarget(pg, name, options)
            if not target then
                -- InjuredSlot waits on a server attribute; poll faster than hotbar/Edit.
                task.wait(
                    (
                        name == "InjuredSlot"
                        or name == "TutorialEnemy"
                        or options.injuredSlot
                        or options.tutorialGuide
                    )
                            and 0.2
                        or 1
                )
            end
        end
        if token ~= stepToken or generation ~= pulseGeneration or not target then
            return
        end
        pulseStroke = Instance.new("UIStroke")
        pulseStroke.Color = GOLD
        pulseStroke.Thickness = options.clickCue and 5 or 3
        pulseStroke.Parent = target

        if not options.arrow then
            -- stroke-only cue; blink it and bail (no arrow for secondary targets)
            local t0 = os.clock()
            while token == stepToken and generation == pulseGeneration and pulseStroke do
                pulseStroke.Transparency = 0.25
                    + 0.55 * (0.5 + 0.5 * math.sin((os.clock() - t0) * 4))
                RunService.RenderStepped:Wait()
            end
            return
        end

        -- Parent the callout to the resolved object itself, so it cannot drift from the binding on
        -- scaled/mobile layouts. Hotbar slots normally clip their icon to a circle; temporarily
        -- release that clip so the callout can sit outside, then restore it in clearGuidance.
        -- Inventory cards live in a ScrollingFrame: parenting there clips the sign to a sliver.
        -- Lift those onto a DisplayOrder overlay so the same TAKE OFF / CLICK HERE sign sits
        -- on top of the menu (Jason: keep the sign consistent; do the Z work).
        pulseTarget = target
        -- Boolean: the card lives under a ScrollingFrame (or other clipper). Do not treat this
        -- as the ScreenGui — indexing that flag for GuiInset crashed and hid TAKE OFF / CLICK HERE.
        local useOverlay = ancestorClips(target)
        if not useOverlay then
            pulseTargetWasClipped = target.ClipsDescendants
            target.ClipsDescendants = false
        end

        local cueSide = options.cueSide
        local isLeft = cueSide == "left"
        local isRight = cueSide == "right"
        -- Side-of-bar: sit just outside BarBg so the callout names that card.
        -- BarBg is a 40px inset on HudCard; the 6–8px gap is a local alignment nudge.
        local bar = (isLeft or isRight) and target:FindFirstChild("BarBg")
        local barLeft = (bar and bar.Position.X.Offset) or 0
        local leftX = barLeft - 6
        local cueText = tostring(options.cueText or "CLICK HERE")
        local sideCue = isLeft or isRight

        pulseArrow = Instance.new("TextLabel")
        pulseArrow.Name = "TutorialArrow"
        pulseArrow.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
        pulseArrow.BackgroundTransparency = if options.clickCue then 0.08 else 1
        pulseArrow.AnchorPoint = if isLeft
            then Vector2.new(1, 0.5)
            elseif isRight then Vector2.new(0, 0.5)
            else Vector2.new(0.5, 1)
        pulseArrow.Position = if isLeft
            then UDim2.new(0, leftX, 0.5, 0)
            elseif isRight then UDim2.new(1, 8, 0.5, 0)
            else UDim2.new(0.5, 0, 0, -6)
        pulseArrow.Size = if options.clickCue
            then (if sideCue then UDim2.fromOffset(150, 44) else UDim2.fromOffset(150, 68))
            else UDim2.fromOffset(68, 44)
        pulseArrow.Font = Enum.Font.GothamBlack
        pulseArrow.TextSize = if options.clickCue then 23 else 38
        pulseArrow.TextColor3 = if options.clickCue then Color3.new(1, 1, 1) else GOLD
        pulseArrow.TextStrokeColor3 = Color3.new(0, 0, 0)
        pulseArrow.TextStrokeTransparency = 0.3
        pulseArrow.Text = if options.clickCue
            then (if isLeft
                then cueText .. "  ►"
                elseif isRight then "◄  " .. cueText
                else cueText .. "\n▼")
            else "⬇"
        pulseArrow.ZIndex = if useOverlay then 20 else 50
        pulseArrow.Parent = if useOverlay then ensureCueOverlay(pg) else target
        if options.clickCue then
            local calloutCorner = Instance.new("UICorner")
            calloutCorner.CornerRadius = UDim.new(0, 12)
            calloutCorner.Parent = pulseArrow
            local calloutStroke = Instance.new("UIStroke")
            calloutStroke.Color = GOLD
            calloutStroke.Thickness = 4
            calloutStroke.Parent = pulseArrow
        end

        local function placeOverlay(bob)
            if not (pulseArrow and target.Parent) then
                return
            end
            local abs = target.AbsolutePosition
            -- MenuOverlay does not ignore the topbar. AbsolutePosition is inset-relative.
            -- TutorialCueOverlay matches that (IgnoreGuiInset=false). Read the ScreenGui
            -- parent — never the useOverlay boolean (that error hid CLICK HERE).
            local host = pulseArrow.Parent
            if host and host:IsA("LayerCollector") and host.IgnoreGuiInset then
                abs += GuiService:GetGuiInset()
            end
            local size = target.AbsoluteSize
            if isLeft then
                pulseArrow.Position = UDim2.fromOffset(abs.X - 6 - bob, abs.Y + size.Y * 0.5)
            elseif isRight then
                pulseArrow.Position =
                    UDim2.fromOffset(abs.X + size.X + 8 + bob, abs.Y + size.Y * 0.5)
            else
                pulseArrow.Position = UDim2.fromOffset(abs.X + size.X * 0.5, abs.Y - 6 - bob)
            end
        end
        if useOverlay then
            placeOverlay(0)
        end

        local t0 = os.clock()
        while token == stepToken and generation == pulseGeneration and pulseStroke do
            local s = 0.5 + 0.5 * math.sin((os.clock() - t0) * 4)
            pulseStroke.Transparency = 0.25 + 0.55 * s
            if pulseArrow then
                -- Keep the instruction legible throughout the pulse. The older full fade was
                -- nearly invisible against Grass/Home's bright ground at the exact moment a new
                -- player needed it.
                pulseArrow.TextTransparency = if options.clickCue then 0 else 0.05 + 0.55 * s
                local bob = math.floor(8 * s)
                if useOverlay then
                    placeOverlay(bob)
                elseif isLeft then
                    pulseArrow.Position = UDim2.new(0, leftX - bob, 0.5, 0)
                elseif isRight then
                    pulseArrow.Position = UDim2.new(1, 8 + bob, 0.5, 0)
                else
                    pulseArrow.Position = UDim2.new(0.5, 0, 0, -6 - bob)
                end
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

-- Set your power is a three-phase interaction. A single cue attached to the Edit/Done button
-- incorrectly survived while the player was choosing a slot and obscured the picker's own guides.
-- Resolve each phase from live UI state instead:
--   Edit (not editing, no Resonance) -> no callout while choosing -> Done after Resonance is bound.
-- Power up Resonance is five clicks. A single PowersButton cue dies once the
-- menu opens. Walk live PowerChoice state the same way bind-power walks Edit:
--   Powers -> Resonance row -> empty slot -> Potency -> Apply
local function showSlotPowerGuidance(token)
    local cueText = TutorialLocalization.text(
        TutorialLanguageState.getLocaleId(),
        "tutorial.cue.click_here",
        "CLICK HERE"
    )
    task.spawn(function()
        local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
        local phase
        while token == stepToken do
            local menuOpen = _G.PowerChoiceMenuOpen == true
            local menu = menuOpen and pg:FindFirstChild("PowerChoiceMenu", true)
            local enhanceFor = menu and menu:GetAttribute("EnhanceFor")
            local targetSlot = menu and tonumber(menu:GetAttribute("EnhanceTargetSlot")) or 0
            local stagedType = menu and menu:GetAttribute("EnhanceStagedType")
            if type(stagedType) ~= "string" or stagedType == "" then
                stagedType = nil
            end
            local nextPhase
            if not menuOpen then
                nextPhase = "open"
            elseif type(enhanceFor) ~= "string" or enhanceFor == "" then
                nextPhase = "pick_power"
            elseif stagedType then
                nextPhase = "apply"
            elseif targetSlot > 0 then
                nextPhase = "pick_potency"
            else
                nextPhase = "pick_slot"
            end

            local targetGone = pulseTarget ~= nil and pulseTarget.Parent == nil
            if nextPhase ~= phase or targetGone then
                phase = nextPhase
                clearUiGuidance()
                if phase == "open" then
                    showUiPulse(token, "PowersButton", {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                    })
                elseif phase == "pick_power" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "Resonance",
                    })
                elseif phase == "pick_slot" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "EnhanceEmptySlot",
                    })
                elseif phase == "pick_potency" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "EnhancePotency",
                    })
                elseif phase == "apply" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "EnhanceApply",
                    })
                end
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

local function showBindPowerGuidance(token, powerId)
    powerId = powerId or "resonance"
    task.spawn(function()
        local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
        local phase
        while token == stepToken do
            local hotbar = pg:FindFirstChild("HotbarBar")
            local editButton = hotbar and hotbar:FindFirstChild("Edit", true)
            local editing = editButton and editButton:GetAttribute("HotbarEditing") == true
            local powerBound = findUiTarget(pg, nil, {
                hotbarType = "power",
                hotbarTarget = powerId,
            }) ~= nil
            local nextPhase
            if editing and powerBound then
                nextPhase = "done"
            elseif not editing and not powerBound then
                nextPhase = "edit"
            else
                nextPhase = "choose"
            end

            if nextPhase ~= phase then
                phase = nextPhase
                clearUiGuidance()
                if phase == "edit" or phase == "done" then
                    showUiPulse(token, "Edit", {
                        arrow = true,
                        clickCue = true,
                        cueText = TutorialLocalization.text(
                            TutorialLanguageState.getLocaleId(),
                            "tutorial.cue.click_here",
                            "CLICK HERE"
                        ),
                    })
                end
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

local configuredStep

local function tankLessonGuide(step)
    local guide = type(step) == "table" and step.guide or nil
    return type(guide) == "table" and guide or {}
end

local function applyTankLessonCapsule(state, step, phase)
    if not (titleLabel and bodyLabel) then
        return
    end
    local localeId = TutorialLanguageState.getLocaleId()
    local entry = tankLessonGuide(step)[phase]
    if type(entry) ~= "table" then
        return
    end
    local baseKey = (step.localization_key or "combat_tutorial.ready_tank") .. ".guide." .. phase
    titleLabel.Text =
        TutorialLocalization.text(localeId, baseKey .. ".title", entry.title or state.title or "")
    local useGamepad = Players.LocalPlayer:GetAttribute("InputMode") == "gamepad"
        and entry.body_gamepad
    bodyLabel.Text = TutorialLocalization.text(
        localeId,
        useGamepad and (baseKey .. ".body_gamepad") or (baseKey .. ".body"),
        useGamepad and entry.body_gamepad or entry.body or ""
    )
end

-- Open Pets → take off the last/weakest doggy → click the strongest tank (or
-- Best Pets → Tank) → Activate (closes Pets) → ENTER. Inventory draft is
-- client-local until Activate, so this walks live UI the same way bind-power does.
local function showEquipTankGuidance(token, state)
    local step = configuredStep(state and state.id) or {}
    local guide = tankLessonGuide(step)
    task.spawn(function()
        local phase
        local showingDoor = false
        while token == stepToken do
            local player = Players.LocalPlayer
            local menuOpen = player:GetAttribute("LargeMenuOpen") == true
            local tankReady = player:GetAttribute("CombatTutorialTankReady") == true
            local draftHasTank = player:GetAttribute("CombatTutorialDraftHasTank") == true
            local draftFull = player:GetAttribute("CombatTutorialDraftFull") == true
            local draftDirty = player:GetAttribute("CombatTutorialDraftDirty") == true
            local nextPhase
            if not menuOpen then
                if tankReady or (draftHasTank and not draftDirty) then
                    nextPhase = "enter"
                else
                    nextPhase = "open"
                end
            elseif draftHasTank and not draftDirty then
                nextPhase = "close"
            elseif draftHasTank then
                nextPhase = "activate"
            elseif draftFull then
                nextPhase = "unequip"
            else
                nextPhase = "pick"
            end

            local targetGone = pulseTarget ~= nil and pulseTarget.Parent == nil
            if nextPhase ~= phase or targetGone then
                phase = nextPhase
                clearGuidance()
                showingDoor = false
                applyTankLessonCapsule(state, step, phase)
                local entry = guide[phase] or {}
                local cueText = TutorialLocalization.text(
                    TutorialLanguageState.getLocaleId(),
                    "tutorial.cue.click_here",
                    entry.cue_text or "CLICK HERE"
                )
                if phase == "open" then
                    showUiPulse(token, "PetsButton", {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                    })
                elseif phase == "unequip" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "UnequipWeakest",
                    })
                elseif phase == "pick" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "StrongestTank",
                    })
                elseif phase == "activate" then
                    showUiPulse(token, "ActivateDraft", {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                    })
                elseif phase == "close" then
                    showUiPulse(token, "CloseButton", {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                    })
                elseif phase == "enter" then
                    local finder = namedPartFinder("CombatTutorialDoorSeal")
                    showEggBeacon(
                        token,
                        finder,
                        TutorialLocalization.text(
                            TutorialLanguageState.getLocaleId(),
                            "tutorial.target.go",
                            "⬇ ENTER"
                        )
                    )
                    showEggPath(token, finder)
                    showingDoor = true
                end
            elseif not showingDoor then
                applyTankLessonCapsule(state, step, phase)
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

-- Open Pets → take one off the equipped row → click the strongest inventory
-- pet (Rainbow Kitty) → Activate. Completes only after that swap is committed.
local function showEquipSquadGuidance(token, state)
    local step = configuredStep(state and state.id) or {}
    local guide = tankLessonGuide(step)
    task.spawn(function()
        local phase
        while token == stepToken do
            local player = Players.LocalPlayer
            local menuOpen = player:GetAttribute("LargeMenuOpen") == true
            local didUnequip = player:GetAttribute("TutorialSquadDidUnequip") == true
            local didEquip = player:GetAttribute("TutorialSquadDidEquip") == true
            local nextPhase
            if not menuOpen then
                nextPhase = "open"
            elseif not didUnequip then
                nextPhase = "unequip"
            elseif not didEquip then
                nextPhase = "pick"
            else
                nextPhase = "activate"
            end

            local targetGone = pulseTarget ~= nil and pulseTarget.Parent == nil
            if nextPhase ~= phase or targetGone then
                phase = nextPhase
                clearGuidance()
                applyTankLessonCapsule(state, step, phase)
                local entry = guide[phase] or {}
                local cueText = TutorialLocalization.text(
                    TutorialLanguageState.getLocaleId(),
                    "tutorial.cue.click_here",
                    entry.cue_text or "CLICK HERE"
                )
                if phase == "open" then
                    showUiPulse(token, "PetsButton", {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                    })
                elseif phase == "unequip" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "UnequipWeakest",
                    })
                elseif phase == "pick" then
                    showUiPulse(token, nil, {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                        tutorialGuide = "StrongestPet",
                    })
                elseif phase == "activate" then
                    showUiPulse(token, "ActivateDraft", {
                        arrow = true,
                        clickCue = true,
                        cueText = cueText,
                    })
                end
            else
                applyTankLessonCapsule(state, step, phase)
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

-- KILL THIS on the marked healer until they click it. Hide after click.
-- Show again only when the server says pets left that healer (not when HUD
-- assist expires).
local function showHealerFocusGuidance(token, state)
    local target = state.target or {}
    local cueText = TutorialLocalization.text(
        TutorialLanguageState.getLocaleId(),
        "tutorial.cue.click_here",
        target.cue_text or "KILL THIS"
    )
    task.spawn(function()
        local showing
        while token == stepToken do
            -- Strict true: nil after the healer dies used to keep polling Enemy_<bid>
            -- for a card that no longer exists (pets can auto-kill without a click).
            local want = Players.LocalPlayer:GetAttribute("CombatTutorialHealerCue") == true
            local bid = tonumber(Players.LocalPlayer:GetAttribute("CombatTutorialTargetEnemy"))
            if not bid or bid <= 0 then
                want = false
            end
            local targetGone = pulseTarget ~= nil and pulseTarget.Parent == nil
            if want ~= showing or (want and targetGone) then
                showing = want
                clearUiGuidance()
                if want then
                    showUiPulse(token, target.name or "TutorialEnemy", {
                        arrow = true,
                        clickCue = true,
                        cueSide = target.cue_side,
                        cueText = cueText,
                    })
                end
            end
            RunService.RenderStepped:Wait()
        end
    end)
end

configuredStep = function(stepId)
    for _, step in ipairs((TUTORIAL_CFG and TUTORIAL_CFG.steps) or {}) do
        if step.id == stepId then
            return step
        end
    end
    for _, step in ipairs((COMBAT_TUTORIAL_CFG and COMBAT_TUTORIAL_CFG.steps) or {}) do
        if step.id == stepId then
            return step
        end
    end
    return nil
end

local function renderActiveState(state)
    local localeId = TutorialLanguageState.getLocaleId()
    local step = configuredStep(state.id) or {}
    local baseKey = step.localization_key or ("tutorial." .. tostring(state.id))
    local progress = TutorialLocalization.format(
        localeId,
        "tutorial.progress",
        "TUTORIAL  %d / %d",
        state.index or 1,
        state.total or 1
    )
    if (state.need or 1) > 1 then
        progress ..= ("   ·   %d / %d"):format(state.count or 0, state.need)
    end
    stepLabel.Text = progress
    titleLabel.Text = TutorialLocalization.text(
        localeId,
        state.title_key or (baseKey .. ".title"),
        state.title or step.title or ""
    )

    local bodyKey = state.body_key or (baseKey .. ".body")
    local body = state.body or step.body or ""
    if Players.LocalPlayer:GetAttribute("InputMode") == "gamepad" and step.body_gamepad then
        bodyKey = baseKey .. ".body_gamepad"
        body = step.body_gamepad
    end
    bodyLabel.Text = TutorialLocalization.text(localeId, bodyKey, body)
end

local function activeCompletionConfig()
    if Players.LocalPlayer:GetAttribute("InCombatTutorial") == true then
        return (COMBAT_TUTORIAL_CFG and COMBAT_TUTORIAL_CFG.completion) or {}
    end
    return (TUTORIAL_CFG and TUTORIAL_CFG.completion) or {}
end

local function renderCompletionState()
    local doneCfg = activeCompletionConfig()
    local baseKey = doneCfg.localization_key or "tutorial.completion"
    local localeId = TutorialLanguageState.getLocaleId()
    stepLabel.Text =
        TutorialLocalization.text(localeId, "tutorial.complete_label", "TUTORIAL COMPLETE")
    titleLabel.Text = TutorialLocalization.text(
        localeId,
        baseKey .. ".title",
        doneCfg.title or "🎉 QUESTS UNLOCKED!"
    )
    bodyLabel.Text = TutorialLocalization.text(
        localeId,
        baseKey .. ".body",
        doneCfg.body or "Your missions are in the tracker up top!"
    )
end

local function maybeShowLanguageBanner()
    local player = Players.LocalPlayer
    local localeId = TutorialLanguageState.getLocaleId()
    if
        languageBannerShown
        or not tutorialActive
        or player:GetAttribute("TutorialLanguageReady") ~= true
        or TutorialLanguageState.getPreference() ~= "auto"
        or not TutorialLocalization.isTranslated(localeId)
    then
        return
    end

    languageBannerShown = true
    local languageName = TutorialLocalization.displayName(localeId)
    GameEvents.showBanner(
        TutorialLocalization.format(
            localeId,
            "tutorial.language_banner",
            "Your tutorial language is %s. You can switch to English in Settings.",
            languageName
        ),
        { seconds = 6, color = { 75, 175, 255 } }
    )
end

local function apply(state)
    stepToken += 1
    clearGuidance()
    currentState = state
    if type(state) ~= "table" or state.done then
        if laterBtn then
            laterBtn.Visible = false
        end
        hideHandoffBanner()
        Players.LocalPlayer:SetAttribute("TutorialStepId", nil)
        local wasActive = tutorialActive
        tutorialActive = false
        if wasActive and capsule then
            -- LIVE completion (not a veteran/rejoin done-state): hold the spot for the
            -- handoff card — "quests unlocked, climb to Level 2" — then yield to quests.
            -- The celebration stinger/burst rides the tutorial_complete game event.
            local doneCfg = activeCompletionConfig()
            local token = stepToken
            completionCardVisible = true
            renderCompletionState()
            setCapsuleWantedVisible(true)
            task.delay(tonumber(doneCfg.show_seconds) or 8, function()
                if stepToken == token and capsule then
                    completionCardVisible = false
                    setCapsuleWantedVisible(false)
                end
            end)
            return
        end
        if capsule then
            completionCardVisible = false
            setCapsuleWantedVisible(false)
        end
        return
    end
    Players.LocalPlayer:SetAttribute("TutorialStepId", state.id)
    tutorialActive = true
    completionCardVisible = false
    local inCave = Players.LocalPlayer:GetAttribute("InCombatTutorial") == true
    if laterBtn then
        laterBtn.Visible = type(state.handoff) == "table" and not inCave
        if laterBtn.Visible then
            local spec = state.handoff or {}
            laterBtn.Text = TutorialLocalization.text(
                TutorialLanguageState.getLocaleId(),
                "tutorial." .. tostring(state.id) .. ".handoff.later",
                spec.later_label or "Later"
            )
        end
    end
    if
        type(state.handoff) == "table"
        and not inCave
        and Players.LocalPlayer:GetAttribute("TutorialHandoffOpen") == true
    then
        showHandoffBanner(state)
    else
        hideHandoffBanner()
    end
    renderActiveState(state)
    setCapsuleWantedVisible(true)
    maybeShowLanguageBanner()

    local target = state.target or {}
    if target.kind == "egg" then
        local finder = function()
            return nearestEgg(target.prefer)
        end
        showEggBeacon(
            stepToken,
            finder,
            TutorialLocalization.text(
                TutorialLanguageState.getLocaleId(),
                "tutorial.target.hatch",
                "⬇ HATCH"
            )
        )
        showEggPath(stepToken, finder)
    elseif target.kind == "crystal" then
        showEggBeacon(
            stepToken,
            nearestSmallCrystal,
            TutorialLocalization.text(
                TutorialLanguageState.getLocaleId(),
                "tutorial.target.mine",
                "⬇ MINE"
            )
        )
        showEggPath(stepToken, nearestSmallCrystal)
    elseif target.kind == "part" and type(target.name) == "string" then
        local finder = namedPartFinder(target.name, target.root)
        local targetKey = if state.id == "first_fight"
            then "tutorial.target.fight"
            else "tutorial.target.go"
        showEggBeacon(
            stepToken,
            finder,
            TutorialLocalization.text(
                TutorialLanguageState.getLocaleId(),
                targetKey,
                target.label or "⬇ GO"
            )
        )
        showEggPath(stepToken, finder)
    elseif target.kind == "ui" and target.cue == "bind" then
        showBindPowerGuidance(stepToken, target.hotbar_target)
    elseif state.id == "bind_power" then
        showBindPowerGuidance(stepToken, "resonance")
    elseif state.id == "slot_power" then
        showSlotPowerGuidance(stepToken)
    elseif target.kind == "ui" and target.cue == "equip_tank" then
        showEquipTankGuidance(stepToken, state)
    elseif target.kind == "ui" and target.cue == "equip_squad" then
        showEquipSquadGuidance(stepToken, state)
    elseif target.kind == "ui" and target.cue == "healer_focus" then
        showHealerFocusGuidance(stepToken, state)
    elseif target.kind == "ui" then
        showUiPulse(stepToken, target.name, {
            arrow = true,
            clickCue = target.cue == "click",
            cueSide = target.cue_side,
            injuredSlot = target.injured_slot == true,
            cueText = TutorialLocalization.text(
                TutorialLanguageState.getLocaleId(),
                "tutorial.cue.click_here",
                target.cue_text or "CLICK HERE"
            ),
            hotbarType = target.hotbar_type,
            hotbarTarget = target.hotbar_target,
        }) -- primary ui target → arrow/callout
    end
    if target.ui and type(target.ui) == "string" then
        showUiPulse(stepToken, target.ui, {}) -- secondary UI pulse alongside a world target — stroke only
    end
end

-- bumped per behavior change: printed at start so a LIVE session's running BYTECODE is
-- identifiable (rojo syncs Source into running sessions but required modules never
-- re-execute — we chased "stale build vs real bug" three times today)
local BUILD = "combat-training later handoff (2026-08-25)"

function TutorialController.start()
    if started then
        return
    end
    started = true
    print("[TutorialController] build:", BUILD)
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    buildCapsule(pg)

    -- THE PROLOGUE OWNS THE SCREEN (docs/PROLOGUE.md). While InPrologue is set, the tutorial
    -- renders NOTHING — capsule hidden, breadcrumb cleared — and whatever state arrives is
    -- parked for the warp-out. This is the client-side half of the ordering: the server gate
    -- holds the initial push, but a state that already rendered (or slips any race) must be
    -- RETRACTED, not just not-sent (Jason: tutorial 1/10 + a breadcrumb to nowhere, drawn
    -- inside the mezzanine toward an egg 8000 studs above).
    local me = Players.LocalPlayer
    local parked = nil
    local function inPrologue()
        return me:GetAttribute("InPrologue") == true
    end
    local function gatedApply(state)
        if inPrologue() then
            parked = state
            clearGuidance()
            hideHandoffBanner()
            if capsule then
                syncCapsuleVisibility()
            end
            return
        end
        apply(state)
    end
    me:GetAttributeChangedSignal("InputMode"):Connect(function()
        if not inPrologue() then
            Signals.TutorialStateRequest:FireServer()
        end
    end)
    me:GetAttributeChangedSignal("InPrologue"):Connect(function()
        if inPrologue() then
            clearGuidance()
            if capsule then
                syncCapsuleVisibility()
            end
        elseif parked then
            local state = parked
            parked = nil
            apply(state)
        else
            Signals.TutorialStateRequest:FireServer() -- nothing parked: pull fresh
        end
    end)
    me:GetAttributeChangedSignal("LargeMenuOpen"):Connect(function()
        if me:GetAttribute("LargeMenuOpen") == true then
            -- Yield before MenuManager captures the current People-list state for its modal.
            syncCapsuleVisibility()
        else
            -- MenuManager restores its captured CoreGui state after publishing
            -- LargeMenuOpen=false. Reclaim the corner only after that restoration finishes.
            task.defer(syncCapsuleVisibility)
        end
    end)
    me:GetAttributeChangedSignal("TutorialLocaleId"):Connect(function()
        if completionCardVisible then
            renderCompletionState()
        elseif tutorialActive and type(currentState) == "table" then
            apply(currentState)
        end
        maybeShowLanguageBanner()
    end)
    me:GetAttributeChangedSignal("TutorialLanguageReady"):Connect(maybeShowLanguageBanner)
    me:GetAttributeChangedSignal("InCombatTutorial"):Connect(function()
        if type(currentState) == "table" and not currentState.done then
            gatedApply(currentState)
        else
            hideHandoffBanner()
        end
    end)

    Signals.TutorialState.OnClientEvent:Connect(gatedApply)
    -- pull current state — the server's join-time push may predate this connection
    Signals.TutorialStateRequest:FireServer()
end

return TutorialController
