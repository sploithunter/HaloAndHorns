--[[
    MergeEggPrototypeObserver — Phase 6 combat, hatch telemetry, and world progression.

    The player's ordinary SquadHud remains reserved for their own deployable team. Nine floor-mounted
    SurfaceGuis sit on the player side of the hatcher eggs and render each NPC squad's tier, endurance,
    target, lifecycle, and wave progress without covering the management HUD. The top wave meter and
    camera-facing per-captain egg placement controls remain screen-readable. Crafted board eggs rotate
    locally while their inventory and placement remain server-authoritative.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HudCard = require(script.Parent.Parent.UI.HudCard)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local WorldChevron = require(script.Parent.Parent.UI.WorldChevron)
local MergeDefenseModeNotice = require(script.Parent.Parent.UI.Components.MergeDefenseModeNotice)
local MergeEggCostFormat = require(ReplicatedStorage.Shared.Game.MergeEggCostFormat)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local EggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)

local CONFIG = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local COMBAT = require(ReplicatedStorage.Configs:WaitForChild("combat"))
local PET_ROLES = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
local PETS = require(ReplicatedStorage.Configs:WaitForChild("pets"))
local PLACES = require(ReplicatedStorage.Configs:WaitForChild("places"))

local MergeEggPrototypeObserver = {}

local localPlayer = Players.LocalPlayer
local boardDrag = nil
local rebirthConfirmUntil = 0
local playerHatchRevealQueue = {}
local playerHatchRevealRunning = false
local playerHatchRevealReadyConnection = nil
local prototypeWorld
local tutorialPathFolder
local tutorialPathMarkers = {}
local tutorialPathTarget
local tutorialFocusTarget
local tutorialFocusVisual
local tutorialClickTarget
local tutorialClickChevron
local tutorialClickCueTarget
local tutorialClickCue
local PANEL_WIDTH = 214
local GROUND_PANEL_GAP_BEHIND_EGG = 1
local PANEL_HEADER_HEIGHT = 61
local PANEL_CARD_HEIGHT = 44
local PANEL_ROW_GAP = 4
local WAYCOIN_ICON = "rbxthumb://type=Asset&id=124447234465235&w=150&h=150"
local AMETHYST_GEM_ICON = "rbxthumb://type=Asset&id=102357151476128&w=150&h=150"
local MANAGEMENT_PRICE_THEME = {
    gems = {
        fill = Color3.fromRGB(126, 62, 207),
        stroke = Color3.fromRGB(214, 157, 255),
        icon = AMETHYST_GEM_ICON,
    },
    waycoins = {
        fill = Color3.fromRGB(241, 164, 28),
        stroke = Color3.fromRGB(255, 229, 110),
        icon = WAYCOIN_ICON,
    },
    rebirth = {
        fill = Color3.fromRGB(226, 62, 105),
        stroke = Color3.fromRGB(255, 155, 184),
        icon = WAYCOIN_ICON,
    },
    unavailable = {
        fill = Color3.fromRGB(70, 74, 84),
        stroke = Color3.fromRGB(132, 138, 151),
    },
}
local COMBAT_CADENCE_MULTIPLIER =
    math.max(0.25, tonumber((CONFIG.combat or {}).attack_cadence_multiplier) or 1)
local WAVE_WORDS = {
    "ONE",
    "TWO",
    "THREE",
    "FOUR",
    "FIVE",
    "SIX",
    "SEVEN",
    "EIGHT",
    "NINE",
    "TEN",
    "ELEVEN",
    "TWELVE",
    "THIRTEEN",
    "FOURTEEN",
    "FIFTEEN",
    "SIXTEEN",
    "SEVENTEEN",
    "EIGHTEEN",
    "NINETEEN",
    "TWENTY",
}
local ROLE_THEME = {
    tank = { color = Color3.fromRGB(75, 145, 225), glyph = "T" },
    melee = { color = Color3.fromRGB(210, 80, 75), glyph = "M" },
    ranged = { color = Color3.fromRGB(225, 145, 65), glyph = "R" },
    support = { color = Color3.fromRGB(70, 185, 110), glyph = "+" },
    control = { color = Color3.fromRGB(155, 100, 215), glyph = "C" },
}
local BOARD_ACTION_FAILURE_COPY = {
    insufficient_currency = "NOT ENOUGH CURRENCY",
    merge_board_too_far = "MOVE CLOSER TO THE MERGE BOARD",
    egg_station_too_far = "MOVE CLOSER TO THE CONTROL",
    no_equip_best_action = "NO BOARD EGG CAN BE EQUIPPED",
    no_merge_available = "NO MATCHING EGGS TO MERGE",
    egg_tier_mismatch = "THOSE EGGS DO NOT MATCH",
    automation_owns_board = "AUTOMATION IS USING THE BOARD",
    automation_owns_hatchers = "AUTOMATION IS USING THE HATCHERS",
    automation_owns_upgrades = "AUTOMATION IS USING UPGRADES",
    automation_running = "AUTOMATION IS RUNNING",
    not_active_encounter = "CONTROL UNAVAILABLE RIGHT NOW",
    maximum_base_egg_reached = "SPAWN LEVEL IS MAXED",
    rebirth_confirmation_required = "CLICK REBIRTH AGAIN TO CONFIRM",
    rebirth_egg_requirement = "DEPLOYED EGGS DO NOT MEET THE REBIRTH REQUIREMENT",
    rebirth_maxed = "NO FURTHER REBIRTH IS AUTHORED YET",
    rebirth_action_in_progress = "FINISH THE CURRENT EGG ACTION FIRST",
    action_refused = "ACTION REFUSED",
}

local TUTORIAL_STEP_ORDER = {
    collect_setup = 1,
    create_five = 2,
    combine_once = 3,
    deploy_one = 4,
}
local TUTORIAL_STEP_COUNT = 4

local function createTutorialCard(parent)
    local frame = Instance.new("Frame")
    frame.Name = "MergeEggTutorial"
    frame.AnchorPoint = Vector2.new(0, 0.5)
    frame.Position = UDim2.new(0, 24, 0.5, -40)
    frame.Size = UDim2.fromOffset(430, 126)
    frame.BackgroundColor3 = Color3.fromRGB(24, 29, 40)
    frame.BackgroundTransparency = 0.04
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 30
    frame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 194, 62)
    stroke.Thickness = 3
    stroke.Parent = frame

    local progress = Instance.new("TextLabel")
    progress.Name = "Progress"
    progress.Position = UDim2.fromOffset(18, 10)
    progress.Size = UDim2.new(1, -36, 0, 20)
    progress.BackgroundTransparency = 1
    progress.Font = Enum.Font.GothamBold
    progress.Text = "MERGE DEFENSE TUTORIAL"
    progress.TextColor3 = Color3.fromRGB(255, 194, 62)
    progress.TextSize = 14
    progress.TextXAlignment = Enum.TextXAlignment.Left
    progress.ZIndex = 31
    progress.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(18, 31)
    title.Size = UDim2.new(1, -36, 0, 32)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.fromRGB(245, 248, 255)
    title.TextSize = 23
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 31
    title.Parent = frame

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Position = UDim2.fromOffset(18, 65)
    body.Size = UDim2.new(1, -36, 1, -75)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.GothamMedium
    body.TextColor3 = Color3.fromRGB(218, 226, 240)
    body.TextSize = 16
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.ZIndex = 31
    body.Parent = frame
    return { frame = frame, progress = progress, title = title, body = body }
end

local function setTutorialMarkerVisible(marker, visible)
    for _, child in ipairs(marker and marker:GetChildren() or {}) do
        if child:IsA("BasePart") and child.Name ~= "Root" then
            child.Transparency = visible and 0.08 or 1
        elseif child:IsA("Highlight") then
            child.Enabled = visible
        end
    end
end

local function clearTutorialPath()
    if tutorialPathFolder then
        tutorialPathFolder:Destroy()
        tutorialPathFolder = nil
    end
    tutorialPathMarkers = {}
end

local function clearTutorialClickChevron()
    tutorialClickTarget = nil
    if tutorialClickChevron then
        tutorialClickChevron:Destroy()
        tutorialClickChevron = nil
    end
end

local function clearTutorialClickCue()
    tutorialClickCueTarget = nil
    if tutorialClickCue then
        tutorialClickCue:Destroy()
        tutorialClickCue = nil
    end
end

local function setTutorialClickCueTarget(target)
    if tutorialClickCueTarget == target and tutorialClickCue and tutorialClickCue.Parent then
        return
    end
    clearTutorialClickCue()
    if not (target and target:IsA("GuiButton") and target.Parent) then
        return
    end

    tutorialClickCueTarget = target

    -- Match the established tutorial callout: a pulsing gold target outline with a dark
    -- CLICK HERE pill and a downward pointer. Parenting it to the real SurfaceGui button keeps
    -- the cue exact at every camera distance instead of approximating the management wall center.
    local pulse = Instance.new("UIStroke")
    pulse.Name = "TutorialClickPulse"
    pulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pulse.Color = Color3.fromRGB(255, 215, 70)
    pulse.Thickness = 12
    pulse.Transparency = 0.05
    pulse.ZIndex = 30
    pulse.Parent = target

    local callout = Instance.new("TextLabel")
    callout.Name = "MergeEggTutorialClickHere"
    callout.AnchorPoint = Vector2.new(0.5, 1)
    callout.Position = UDim2.new(0.5, 0, 0, -12)
    callout.Size = UDim2.fromOffset(330, 108)
    callout.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
    callout.BackgroundTransparency = 0.08
    callout.BorderSizePixel = 0
    callout.Font = Enum.Font.GothamBlack
    callout.Text = "CLICK HERE\n\226\150\188"
    callout.TextColor3 = Color3.new(1, 1, 1)
    callout.TextSize = 45
    callout.TextStrokeColor3 = Color3.new(0, 0, 0)
    callout.TextStrokeTransparency = 0.3
    callout.TextWrapped = true
    callout.ZIndex = 31
    callout.Parent = target

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = callout

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 70)
    stroke.Thickness = 7
    stroke.Parent = callout

    tutorialClickCue = callout
end

local function updateTutorialClickCue()
    if
        not (
            tutorialClickCueTarget
            and tutorialClickCueTarget.Parent
            and tutorialClickCue
            and tutorialClickCue.Parent
        )
    then
        clearTutorialClickCue()
        return
    end
    local pulse = tutorialClickCueTarget:FindFirstChild("TutorialClickPulse")
    local phase = 0.5 + 0.5 * math.sin(os.clock() * 4)
    if pulse and pulse:IsA("UIStroke") then
        pulse.Transparency = 0.05 + 0.45 * phase
    end
    tutorialClickCue.Position = UDim2.new(0.5, 0, 0, -12 - math.floor(12 * phase))
end

local function ensureTutorialPath()
    if tutorialPathFolder and tutorialPathFolder.Parent then
        return
    end
    clearTutorialPath()
    tutorialPathFolder = Instance.new("Folder")
    tutorialPathFolder.Name = "MergeEggTutorialPath"
    tutorialPathFolder.Parent = Workspace
    for index = 1, 12 do
        local marker = WorldChevron.create(tutorialPathFolder, {
            name = "MergeEggTutorialChevron",
            trailIndex = index,
            color = Color3.fromRGB(255, 224, 105),
        })
        tutorialPathMarkers[index] = marker
        setTutorialMarkerVisible(marker, false)
    end
end

local function boardEggBasePosition(model)
    if not (model and model:IsA("Model") and model.Parent) then
        return nil
    end
    local boxCFrame, boxSize = model:GetBoundingBox()
    return Vector3.new(
        boxCFrame.Position.X,
        boxCFrame.Position.Y - boxSize.Y * 0.5,
        boxCFrame.Position.Z
    )
end

local function createYellowSelectionSquare(name, size)
    local square = Instance.new("Part")
    square.Name = name
    square.Size = Vector3.new(size, 0.12, size)
    square.Anchored = true
    square.CanCollide = false
    square.CanTouch = false
    square.CanQuery = false
    square.CastShadow = false
    square.Material = Enum.Material.Neon
    square.Color = Color3.fromRGB(255, 213, 35)
    square.Transparency = 0.42
    square.Parent = Workspace

    local outline = Instance.new("SelectionBox")
    outline.Name = "Outline"
    outline.Adornee = square
    outline.Color3 = Color3.fromRGB(255, 245, 150)
    outline.LineThickness = 0.06
    outline.SurfaceColor3 = Color3.fromRGB(255, 220, 45)
    outline.SurfaceTransparency = 0.68
    outline.Parent = square
    return square
end

local function createEggFocusVisual(name)
    local boardCfg = ((CONFIG.team or {}).merge_board or {})
    local size = math.max(2, tonumber(boardCfg.slot_size) or 6.6) * 0.88
    return {
        square = createYellowSelectionSquare(name .. "Square", size),
        chevron = WorldChevron.create(Workspace, {
            name = name .. "Chevron",
            color = Color3.fromRGB(255, 222, 70),
            fillColor = Color3.fromRGB(255, 242, 155),
        }),
    }
end

local function updateEggFocusVisual(visual, model)
    local basePosition = boardEggBasePosition(model)
    if not (visual and visual.square and basePosition) then
        return
    end
    visual.square.CFrame = CFrame.new(basePosition + Vector3.new(0, 0.08, 0))
    if visual.chevron then
        local hover = basePosition + Vector3.new(0, 5.5 + math.sin(os.clock() * 5) * 0.35, 0)
        visual.chevron:PivotTo(CFrame.lookAt(hover, basePosition))
    end
end

local function destroyEggFocusVisual(visual)
    if not visual then
        return
    end
    if visual.square then
        visual.square:Destroy()
    end
    if visual.chevron then
        visual.chevron:Destroy()
    end
end

local function updateTutorialEggFocus()
    if not (tutorialFocusTarget and tutorialFocusTarget.Parent) or boardDrag then
        if tutorialFocusVisual then
            destroyEggFocusVisual(tutorialFocusVisual)
            tutorialFocusVisual = nil
        end
        return
    end
    if not tutorialFocusVisual then
        tutorialFocusVisual = createEggFocusVisual("MergeEggTutorialFocus")
    end
    updateEggFocusVisual(tutorialFocusVisual, tutorialFocusTarget)
end

local function clearTutorialEggFocus()
    tutorialFocusTarget = nil
    if tutorialFocusVisual then
        destroyEggFocusVisual(tutorialFocusVisual)
        tutorialFocusVisual = nil
    end
end

local function tutorialTarget(world, targetKind)
    if targetKind == "coins" then
        local root = localPlayer.Character
            and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        local drops = Workspace:FindFirstChild("CoinDrops")
        local nearest
        local nearestDistance = math.huge
        for _, drop in ipairs(drops and drops:GetChildren() or {}) do
            if
                drop:IsA("Model")
                and tonumber(drop:GetAttribute("DropOwner")) == localPlayer.UserId
                and drop:GetAttribute("DropSource") == "merge_egg_prototype"
            then
                local part = drop.PrimaryPart or drop:FindFirstChildWhichIsA("BasePart", true)
                local distance = root and part and (part.Position - root.Position).Magnitude
                    or math.huge
                if distance < nearestDistance then
                    nearest = part
                    nearestDistance = distance
                end
            end
        end
        return nearest
    elseif targetKind == "buy_egg" then
        local host = world
            and world:FindFirstChild(
                (CONFIG.world or {}).egg_merge_control or "EggMergeControl",
                true
            )
        if host and host:IsA("BasePart") then
            -- BUY EGG is row 3, column 1 of the symmetric 3x3 management SurfaceGui. Front-face
            -- SurfaceGui X runs opposite the part's local X when viewed from the player side, so
            -- the left card lives at +X. Resolve that card center instead of the wall origin.
            return host.CFrame:PointToWorldSpace(
                Vector3.new(host.Size.X / 3, -host.Size.Y / 3, -host.Size.Z / 2 - 0.2)
            )
        end
        return host
    elseif targetKind == "board_egg" then
        local board = world
            and world:FindFirstChild((CONFIG.world or {}).merge_board or "MergeBoard")
        local eggs = board and board:FindFirstChild("Eggs")
        for _, egg in ipairs(eggs and eggs:GetChildren() or {}) do
            if egg:IsA("Model") and egg:GetAttribute("MergeEggBoardEgg") == true then
                return egg
            end
        end
        return world
            and world:FindFirstChild(
                (CONFIG.world or {}).equip_best_control or "EquipBestControl",
                true
            )
    end
    return nil
end

local function tutorialTargetPosition(target)
    if typeof(target) == "Vector3" then
        return target
    elseif target and target:IsA("Model") then
        return target:GetPivot().Position
    elseif target and target:IsA("BasePart") then
        return target.Position
    end
    return nil
end

local function updateTutorialClickChevron()
    local targetPosition = tutorialTargetPosition(tutorialClickTarget)
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not (targetPosition and root) then
        clearTutorialClickChevron()
        return
    end
    if not (tutorialClickChevron and tutorialClickChevron.Parent) then
        tutorialClickChevron = WorldChevron.create(Workspace, {
            name = "MergeEggTutorialClickHere",
            color = Color3.fromRGB(255, 224, 80),
            fillColor = Color3.fromRGB(255, 244, 165),
        })
    end
    local towardPlayer = root.Position - targetPosition
    towardPlayer = towardPlayer.Magnitude > 0.001 and towardPlayer.Unit or Vector3.new(0, 0, 1)
    local hover = targetPosition
        + towardPlayer * (3.6 + math.sin(os.clock() * 5) * 0.3)
        + Vector3.new(0, 0.5, 0)
    tutorialClickChevron:PivotTo(CFrame.lookAt(hover, targetPosition))
end

local function updateTutorialPath(target)
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetPosition = tutorialTargetPosition(target)
    if not (root and targetPosition) then
        clearTutorialPath()
        return
    end
    local offset = targetPosition - root.Position
    local distance = offset.Magnitude
    if distance <= 9 then
        clearTutorialPath()
        return
    end
    ensureTutorialPath()
    local startDistance = 4.5
    local endDistance = distance - 7
    local usableDistance = math.max(0, endDistance - startDistance)
    if usableDistance <= 0.01 then
        clearTutorialPath()
        return
    end
    local markerCount =
        math.min(#tutorialPathMarkers, math.max(1, math.floor(usableDistance / 5.5)))
    local markerSpacing = usableDistance / markerCount
    local travel = (os.clock() * 8) % usableDistance
    for index, marker in ipairs(tutorialPathMarkers) do
        if index <= markerCount then
            local offset = (index - 1) * markerSpacing
            local along = startDistance + ((offset + travel) % usableDistance)
            local alpha = math.clamp(along / distance, 0, 1)
            local nextAlpha = math.min(1, alpha + 0.02)
            local position = root.Position:Lerp(targetPosition, alpha)
                + Vector3.new(0, 0.35 + math.sin(math.pi * alpha) * 1.25, 0)
            local nextPosition = root.Position:Lerp(targetPosition, nextAlpha)
                + Vector3.new(0, 0.35 + math.sin(math.pi * nextAlpha) * 1.25, 0)
            marker:PivotTo(CFrame.lookAt(position, nextPosition))
            setTutorialMarkerVisible(marker, true)
        else
            setTutorialMarkerVisible(marker, false)
        end
    end
end

local function tutorialBuyEggCueAllowed(world)
    if
        not world
        or world:GetAttribute("MergeEggTutorialActive") ~= true
        or world:GetAttribute("MergeEggTutorialStep") ~= "create_five"
    then
        return false
    end
    local tutorial = type(CONFIG.tutorial) == "table" and CONFIG.tutorial or {}
    local cuePurchaseCount =
        math.max(0, math.floor(tonumber(tutorial.click_cue_purchase_count) or 3))
    local eggsCreated =
        math.max(0, math.floor(tonumber(world:GetAttribute("MergeEggTutorialEggsCreated")) or 0))
    local rebirthCount =
        math.max(0, math.floor(tonumber(world:GetAttribute("MergeDefenseRebirthCount")) or 0))
    return eggsCreated < cuePurchaseCount
        and (tutorial.disable_after_rebirth ~= true or rebirthCount == 0)
end

local function updateTutorialCard(card, world, observing)
    local active = observing and world and world:GetAttribute("MergeEggTutorialActive") == true
    local step = active and tostring(world:GetAttribute("MergeEggTutorialStep") or "") or ""
    local spec = type((CONFIG.tutorial or {}).steps) == "table"
            and (CONFIG.tutorial or {}).steps[step]
        or nil
    if not (active and type(spec) == "table") then
        card.frame.Visible = false
        tutorialPathTarget = nil
        clearTutorialPath()
        clearTutorialEggFocus()
        clearTutorialClickChevron()
        return
    end
    local autoCollector = world:GetAttribute("MergeEggTutorialUsesAutoCollector") == true
    card.frame.Visible = true
    card.progress.Text = string.format(
        "MERGE DEFENSE TUTORIAL  •  %d / %d",
        TUTORIAL_STEP_ORDER[step] or 1,
        TUTORIAL_STEP_COUNT
    )
    card.title.Text = tostring(spec.title or "MERGE DEFENSE")
    card.body.Text = tostring(autoCollector and spec.auto_body or spec.body or "")
    if step == "create_five" then
        local required = math.max(
            1,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialRequiredEggs")) or 5)
        )
        local created = math.max(
            0,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialEggsCreated")) or 0)
        )
        local remaining = math.max(0, required - created)
        card.title.Text = remaining > 0
                and string.format(
                    "CREATE %d MORE EARTH EGG%s",
                    remaining,
                    remaining == 1 and "" or "S"
                )
            or "FIVE EARTH EGGS READY"
        card.body.Text = "Click the highlighted BUY EGG button again."
    end
    local targetKind = tostring(spec.target or "none")
    if autoCollector and targetKind == "coins" then
        tutorialPathTarget = nil
        tutorialFocusTarget = nil
        clearTutorialPath()
        clearTutorialEggFocus()
        clearTutorialClickChevron()
    else
        tutorialPathTarget = tutorialTarget(world, targetKind)
        tutorialClickTarget = targetKind == "buy_egg"
                and tutorialBuyEggCueAllowed(world)
                and tutorialPathTarget
            or nil
        if tutorialClickTarget then
            updateTutorialClickChevron()
        else
            clearTutorialClickChevron()
        end
        tutorialFocusTarget = targetKind == "board_egg"
                and tutorialPathTarget
                and tutorialPathTarget:IsA("Model")
                and tutorialPathTarget
            or nil
        if not tutorialFocusTarget then
            clearTutorialEggFocus()
        end
        updateTutorialPath(tutorialPathTarget)
        updateTutorialEggFocus()
    end
end

local function hatchModeEnabled(optionName, defaultValue)
    local settings = localPlayer:FindFirstChild("Settings")
    local auto = settings and settings:FindFirstChild("AutoSystems")
    local hatch = auto and auto:FindFirstChild("Hatch")
    local modes = hatch and hatch:FindFirstChild("Modes")
    local value = modes and modes:FindFirstChild(optionName)
    if value and value:IsA("BoolValue") then
        return value.Value == true
    end
    return defaultValue == true
end

local function processPlayerHatchRevealQueue()
    if playerHatchRevealRunning or #playerHatchRevealQueue == 0 then
        return
    end
    if not EggHatchingService:IsHatchReady() then
        if not playerHatchRevealReadyConnection then
            playerHatchRevealReadyConnection = RunService.Heartbeat:Connect(function()
                if EggHatchingService:IsHatchReady() then
                    playerHatchRevealReadyConnection:Disconnect()
                    playerHatchRevealReadyConnection = nil
                    processPlayerHatchRevealQueue()
                end
            end)
        end
        return
    end

    local result = table.remove(playerHatchRevealQueue, 1)
    if
        localPlayer:GetAttribute("InMergeEggPrototype") ~= true
        or not hatchModeEnabled("mergeDefenseReveal", true)
    then
        processPlayerHatchRevealQueue()
        return
    end

    playerHatchRevealRunning = true
    local petData = PETS.getPet and PETS.getPet(result.petType, result.variant or "basic") or {}
    local animation = EggHatchingService:StartHatchingAnimation({
        {
            eggType = result.eggType,
            imageId = "generated_image",
            petImageId = "generated_image",
            petType = result.petType,
            variant = result.variant or "basic",
            power = result.power or petData.power,
            rarityId = result.rarityId or petData.rarity_id,
            huge = result.huge == true,
            specialHatch = result.huge == true,
            newIndexEntry = true,
            petData = petData,
            hatchOptions = {
                passive = true,
                showHatch = true,
                silentHatch = hatchModeEnabled("silentHatch", false),
            },
        },
    }, function()
        playerHatchRevealRunning = false
        processPlayerHatchRevealQueue()
    end)
    if not animation or animation.skipped == true then
        playerHatchRevealRunning = false
        processPlayerHatchRevealQueue()
    end
end

local function createBoardActionFeedback(parent)
    local label = Instance.new("TextLabel")
    label.Name = "BoardActionFeedback"
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.72)
    label.Size = UDim2.fromOffset(520, 64)
    label.BackgroundColor3 = Color3.fromRGB(24, 29, 40)
    label.BackgroundTransparency = 0.08
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = Color3.fromRGB(190, 255, 205)
    label.TextScaled = true
    label.TextStrokeColor3 = Color3.fromRGB(8, 12, 18)
    label.TextStrokeTransparency = 0.15
    label.Visible = false
    label.ZIndex = 50
    label.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = label
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(95, 230, 135)
    stroke.Thickness = 3
    stroke.Parent = label
    return label, stroke
end

local function boardActionResultCopy(result)
    if result.ok == true then
        local action = tostring(result.action or "")
        if action == "equip_best" then
            return string.format(
                "EQUIPPED %d EGG%s",
                tonumber(result.value) or 0,
                tonumber(result.value) == 1 and "" or "S"
            )
        elseif action == "create" then
            local value = type(result.value) == "table" and result.value or {}
            local required = tonumber(value.tutorialRequiredEggs)
            local created = tonumber(value.eggsCreated)
            if required and created then
                local remaining = math.max(0, math.floor(required - created))
                if remaining > 0 then
                    return string.format("%d MORE EGG%s", remaining, remaining == 1 and "" or "S")
                end
                return "FIVE EARTH EGGS READY"
            end
            return "EGG ADDED TO BOARD"
        elseif action == "upgrade_base" then
            return "SPAWN LEVEL INCREASED"
        elseif action == "purchase_upgrade" then
            return "UPGRADE PURCHASED"
        elseif action == "toggle_auto" then
            return "AUTO-COMBINE UPDATED"
        elseif action == "merge_slots" then
            return "EGGS MERGED"
        elseif action == "deploy_to_hatcher" then
            return "EGG DEPLOYED"
        elseif action == "rebirth" then
            return string.format("REBIRTH %d ACTIVE", math.max(0, tonumber(result.value) or 0))
        end
        return "ACTION COMPLETE"
    end
    local reason = tostring(result.reason or "action_refused")
    return BOARD_ACTION_FAILURE_COPY[reason] or string.upper(reason:gsub("_", " "))
end

local function prettyName(value)
    local text = tostring(value or "Pet"):gsub("_", " ")
    return text:gsub("^%l", string.upper)
end

local function stationXOffset(teamConfig, fallbackSlot)
    local layout = type(CONFIG.station_layout) == "table" and CONFIG.station_layout or {}
    local total = math.max(1, math.floor(tonumber(layout.total_positions) or 9))
    local spacing = math.max(1, tonumber(layout.spacing) or 8)
    local slot = math.clamp(
        math.floor(tonumber(teamConfig and teamConfig.position_slot) or fallbackSlot or 1),
        1,
        total
    )
    return (slot - (total + 1) * 0.5) * spacing
end

local function activeTeamConfigs()
    local world = prototypeWorld()
    local layout = type(CONFIG.station_layout) == "table" and CONFIG.station_layout or {}
    local total = math.max(1, math.floor(tonumber(layout.total_positions) or 9))
    local owned = math.clamp(
        math.floor(tonumber(world and world:GetAttribute("OwnedHatcherSlots")) or 4),
        1,
        total
    )
    local positions = {}
    local seen = {}
    local function append(source)
        for _, rawSlot in ipairs(type(source) == "table" and source or {}) do
            local slot = math.clamp(math.floor(tonumber(rawSlot) or 1), 1, total)
            if not seen[slot] then
                seen[slot] = true
                positions[#positions + 1] = slot
            end
        end
    end
    append(layout.initial_position_slots)
    append(layout.unlock_position_slots)
    for slot = 1, total do
        if not seen[slot] then
            positions[#positions + 1] = slot
        end
    end
    local teams = {}
    for index = 1, math.min(owned, #positions) do
        local team = table.clone((CONFIG.teams or {})[index] or {})
        team.id = index
        team.position_slot = positions[index]
        team.display_name = "NPC Team " .. index
        teams[index] = team
    end
    return teams
end

local function groundPanelDimensions()
    local layout = type(CONFIG.station_layout) == "table" and CONFIG.station_layout or {}
    local panelCfg = type(layout.roster_panel) == "table" and layout.roster_panel or {}
    local spacing = math.max(1, tonumber(layout.spacing) or 8)
    local gap = math.clamp(tonumber(panelCfg.gap) or 0.5, 0, spacing - 0.1)
    local physicalWidth = spacing - gap
    local logicalSlots = math.max(1, math.floor(tonumber(panelCfg.logical_slots) or 4))
    local logicalHeight = PANEL_HEADER_HEIGHT
        + logicalSlots * PANEL_CARD_HEIGHT
        + logicalSlots * PANEL_ROW_GAP
    -- Keep every panel one station-cell wide. A minimum rearward footprint prevents the final
    -- six-slot canvas from becoming unreadably shallow when viewed from the management area.
    local minimumDepth = math.max(1, tonumber(panelCfg.minimum_depth) or 1)
    local physicalDepth = math.max(minimumDepth, physicalWidth * PANEL_WIDTH / logicalHeight)
    return physicalWidth, physicalDepth, logicalHeight
end

local function groundPanelDepth()
    local _, depth = groundPanelDimensions()
    return depth
end

local function groundPanelCenterBehindEgg()
    local layout = type(CONFIG.station_layout) == "table" and CONFIG.station_layout or {}
    local padCfg = type(layout.deployment_pads) == "table" and layout.deployment_pads or {}
    local eggOffset = tonumber(padCfg.egg_offset) or 3
    local padSize = math.max(2, tonumber(padCfg.size) or 6.6)
    return eggOffset + padSize * 0.5 + groundPanelDepth() * 0.5 + GROUND_PANEL_GAP_BEHIND_EGG
end

local function petSlot(pet)
    local position = pet and pet:FindFirstChild("PositionNumber")
    return math.max(1, math.floor(tonumber(position and position.Value) or 1))
end

local function petPower(pet)
    local power = pet and pet:FindFirstChild("Power")
    return math.max(
        1,
        tonumber(power and power.Value)
            or tonumber(pet and pet:GetAttribute("EffectivePower"))
            or tonumber(pet and pet:GetAttribute("BasePower"))
            or 1
    )
end

local function teamFolders()
    local found = {}
    local root = Workspace:FindFirstChild("PlayerPets")
    for _, folder in ipairs(root and root:GetChildren() or {}) do
        if
            folder:GetAttribute("MergeEggPrototypeTeam") == true
            and tonumber(folder:GetAttribute("MergeEggOwnerUserId")) == localPlayer.UserId
        then
            local id = tonumber(folder:GetAttribute("MergeEggTeamId"))
            if id then
                found[id] = folder
            end
        end
    end
    return found
end

prototypeWorld = function()
    local maps = Workspace:FindFirstChild((CONFIG.world or {}).maps_root or "Maps")
    if not maps then
        return nil
    end
    local bayId = localPlayer:GetAttribute("MergeEggBayId")
    if bayId then
        local hatcherName = (CONFIG.world or {}).hatcher_spawn or "HatcherSpawn"
        for _, candidate in ipairs(maps:GetDescendants()) do
            if
                candidate:IsA("Model")
                and candidate:GetAttribute("MergeEggBayId") == bayId
                and candidate:FindFirstChild(hatcherName, true) ~= nil
            then
                return candidate
            end
        end
    end
    return maps:FindFirstChild((CONFIG.world or {}).model_name or "MergeEggPrototype")
end

local function enemyName(targetId)
    local gameFolder = Workspace:FindFirstChild("Game")
    local enemies = gameFolder and gameFolder:FindFirstChild("Enemies")
    for _, model in ipairs(enemies and enemies:GetChildren() or {}) do
        local id = model:FindFirstChild("BreakableID")
        if id and tonumber(id.Value) == tonumber(targetId) then
            return tostring(
                model:GetAttribute("DisplayName") or model:GetAttribute("EnemyId") or "Enemy"
            )
        end
    end
    return "Enemy"
end

local function worldProgress()
    local world = prototypeWorld()
    if not world then
        local starting =
            math.max(1, math.floor(tonumber((CONFIG.objective or {}).starting_eggs) or 5))
        return 0,
            #(CONFIG.waves or {}),
            "ReadyToHatch",
            0,
            starting,
            starting,
            0,
            0,
            0,
            false,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            "Home",
            0,
            0,
            false,
            nil,
            0
    end
    return tonumber(world:GetAttribute("CurrentWave")) or 0,
        tonumber(world:GetAttribute("WaveCount")) or #(CONFIG.waves or {}),
        tostring(world:GetAttribute("PrototypeState") or "ReadyToHatch"),
        math.max(0, tonumber(world:GetAttribute("ActiveEnemies")) or 0),
        math.max(0, tonumber(world:GetAttribute("ObjectiveEggsRemaining")) or 0),
        math.max(1, tonumber(world:GetAttribute("ObjectiveEggsStarting")) or 5),
        math.max(0, tonumber(world:GetAttribute("ReplacementQueueDepth")) or 0),
        math.max(0, tonumber(world:GetAttribute("PeakReplacementQueueDepth")) or 0),
        math.max(0, tonumber(world:GetAttribute("ReplacementsHatched")) or 0),
        world:GetAttribute("EnemyPortalVisible") == true,
        math.max(0, tonumber(world:GetAttribute("WaveEnemiesPending")) or 0),
        math.max(0, tonumber(world:GetAttribute("WaveAttackGroups")) or 0),
        math.max(0, tonumber(world:GetAttribute("InitializedHatcherCount")) or 0),
        math.max(0, tonumber(world:GetAttribute("PrototypeEggRolls")) or 0),
        math.max(0, tonumber(world:GetAttribute("PrototypeGoldenRolls")) or 0),
        math.max(0, tonumber(world:GetAttribute("PrototypeRainbowRolls")) or 0),
        math.max(0, tonumber(world:GetAttribute("PrototypeHugeRolls")) or 0),
        tostring(
            world:GetAttribute("CombatLayerName")
                or world:GetAttribute("ProgressionStageName")
                or "Home"
        ),
        math.max(0, tonumber(world:GetAttribute("EnemiesPastBreachLine")) or 0),
        math.max(0, tonumber(world:GetAttribute("PeakEnemiesPastBreachLine")) or 0),
        world:GetAttribute("BreachOverrun") == true,
        tonumber(world:GetAttribute("FirstBreachWave")),
        math.max(0, tonumber(world:GetAttribute("PrototypeDraftCandidateRolls")) or 0)
end

local function waveWord(wave)
    return WAVE_WORDS[wave] or tostring(wave)
end

local function readableState(state)
    local spaced = tostring(state or ""):gsub("(%l)(%u)", "%1 %2")
    return spaced:upper()
end

local function createWaveMeter(parent)
    local frame = Instance.new("Frame")
    frame.Name = "WaveMeter"
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, -215, 0, 88)
    frame.Size = UDim2.fromOffset(430, 82)
    frame.BackgroundColor3 = Color3.fromRGB(24, 30, 43)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(245, 190, 75)
    stroke.Transparency = 0.15
    stroke.Thickness = 2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "WaveTitle"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 6)
    title.Size = UDim2.new(1, -24, 0, 27)
    title.Font = Enum.Font.GothamBlack
    title.Text = "READY TO HATCH"
    title.TextColor3 = Color3.fromRGB(255, 223, 125)
    title.TextSize = 21
    title.Parent = frame

    local detail = Instance.new("TextLabel")
    detail.Name = "WaveDetail"
    detail.BackgroundTransparency = 1
    detail.Position = UDim2.fromOffset(12, 33)
    detail.Size = UDim2.new(1, -24, 0, 34)
    detail.Font = Enum.Font.GothamBold
    detail.Text = "8-WAVE ENDURANCE TEST • 4× COMBAT"
    detail.TextColor3 = Color3.fromRGB(180, 200, 225)
    detail.TextSize = 11
    detail.TextWrapped = true
    detail.TextYAlignment = Enum.TextYAlignment.Top
    detail.Parent = frame

    local track = Instance.new("Frame")
    track.Name = "ProgressTrack"
    track.Position = UDim2.new(0, 12, 1, -9)
    track.Size = UDim2.new(1, -24, 0, 4)
    track.BackgroundColor3 = Color3.fromRGB(58, 68, 86)
    track.BorderSizePixel = 0
    track.Parent = frame

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Name = "ProgressFill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.fromRGB(245, 190, 75)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    return {
        frame = frame,
        stroke = stroke,
        title = title,
        detail = detail,
        fill = fill,
    }
end

local function updateWaveMeter(
    meter,
    wave,
    waveCount,
    state,
    activeEnemies,
    eggsRemaining,
    eggsStarting,
    queueDepth,
    peakQueueDepth,
    replacementsHatched,
    portalVisible,
    pendingEnemies,
    attackGroups,
    initializedHatchers,
    eggRolls,
    goldenRolls,
    rainbowRolls,
    hugeRolls,
    stageName,
    enemiesPastBreachLine,
    peakEnemiesPastBreachLine,
    breachOverrun,
    firstBreachWave,
    draftCandidateRolls,
    announcing
)
    meter.frame.Visible = true
    local world = prototypeWorld()
    local endless = world and world:GetAttribute("WavesEndless") == true or false
    if wave <= 0 then
        local waitingForFirstEgg = state == "AwaitingFirstEgg"
        meter.title.Text = string.upper(stageName)
            .. " • "
            .. (waitingForFirstEgg and "INSTALL FIRST EGG" or "READY TO HATCH")
        meter.detail.Text = string.format(
            "%s • %.0f× COMBAT\n%s • EGGS %d/%d • FIFO READY",
            endless and "ENDLESS DEFENSE" or string.format("%d-WAVE ENDURANCE TEST", waveCount),
            COMBAT_CADENCE_MULTIPLIER,
            waitingForFirstEgg
                    and string.format(
                        "WAVE 1 HELD • %d/%d HATCHERS ONLINE",
                        initializedHatchers,
                        math.max(
                            1,
                            math.floor(
                                tonumber(
                                    prototypeWorld()
                                        and prototypeWorld():GetAttribute("OwnedHatcherSlots")
                                ) or 4
                            )
                        )
                    )
                or "HATCHER EGG TIERS",
            eggsRemaining,
            eggsStarting
        )
    else
        local breachLabel = breachOverrun and " • OVERRUN"
            or enemiesPastBreachLine > 0 and " • BREACH"
            or ""
        meter.title.Text = string.upper(stageName) .. " • WAVE " .. waveWord(wave) .. breachLabel
        meter.detail.Text = string.format(
            "%s • %d %s • %d HATCHERS • %d ACTIVE / %d BEHIND (PEAK %d) • %s • %.0f× COMBAT\nEGGS %d/%d • Q%d/P%d/H%d • PICKS %d/%d G%d/R%d/H%d • FIRST BREACH %s • %s",
            endless and string.format("%d / ∞", wave) or string.format("%d / %d", wave, waveCount),
            attackGroups,
            attackGroups == 1 and "FRONT" or "FRONTS",
            initializedHatchers,
            activeEnemies,
            enemiesPastBreachLine,
            peakEnemiesPastBreachLine,
            readableState(state),
            COMBAT_CADENCE_MULTIPLIER,
            eggsRemaining,
            eggsStarting,
            queueDepth,
            peakQueueDepth,
            replacementsHatched,
            eggRolls,
            draftCandidateRolls,
            goldenRolls,
            rainbowRolls,
            hugeRolls,
            firstBreachWave and ("W" .. tostring(firstBreachWave)) or "—",
            portalVisible and string.format("PORTAL %d", pendingEnemies) or "PORTAL SEALED"
        )
    end
    local fillProgress = endless and (((math.max(1, wave) - 1) % 10) + 1) / 10
        or wave / math.max(1, waveCount)
    meter.fill.Size = UDim2.fromScale(math.clamp(fillProgress, 0, 1), 1)
    meter.title.TextSize = announcing and 25 or 21
    local warningColor = breachOverrun and Color3.fromRGB(235, 75, 75)
        or enemiesPastBreachLine > 0 and Color3.fromRGB(255, 165, 65)
        or Color3.fromRGB(245, 190, 75)
    meter.title.TextColor3 = warningColor
    meter.fill.BackgroundColor3 = warningColor
    meter.stroke.Color = warningColor
    meter.frame.BackgroundColor3 = breachOverrun and Color3.fromRGB(70, 25, 30)
        or enemiesPastBreachLine > 0 and Color3.fromRGB(68, 45, 22)
        or announcing and Color3.fromRGB(66, 50, 24)
        or Color3.fromRGB(24, 30, 43)
    meter.stroke.Thickness = announcing and 3 or 2
    meter.stroke.Transparency = announcing and 0 or 0.15
end

local function createHeader(parent, titleText)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEADER_HEIGHT)
    header.BackgroundColor3 = Color3.fromRGB(24, 30, 43)
    header.BackgroundTransparency = 0.05
    header.BorderSizePixel = 0
    header.LayoutOrder = 0
    header.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = header
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(85, 150, 225)
    stroke.Transparency = 0.25
    stroke.Thickness = 1.5
    stroke.Parent = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(10, 5)
    title.Size = UDim2.new(1, -20, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.Text = titleText
    title.TextColor3 = Color3.fromRGB(235, 244, 255)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local summary = Instance.new("TextLabel")
    summary.BackgroundTransparency = 1
    summary.Position = UDim2.fromOffset(10, 24)
    summary.Size = UDim2.new(1, -20, 0, 15)
    summary.Font = Enum.Font.Gotham
    summary.Text = "HATCH TO DEPLOY"
    summary.TextColor3 = Color3.fromRGB(175, 190, 210)
    summary.TextSize = 10
    summary.TextXAlignment = Enum.TextXAlignment.Left
    summary.Parent = header

    local eggStatus = Instance.new("TextLabel")
    eggStatus.BackgroundTransparency = 1
    eggStatus.Position = UDim2.fromOffset(10, 41)
    eggStatus.Size = UDim2.new(1, -20, 0, 15)
    eggStatus.Font = Enum.Font.GothamBold
    eggStatus.Text = "EGG: NOT INSTALLED"
    eggStatus.TextColor3 = Color3.fromRGB(175, 190, 210)
    eggStatus.TextSize = 10
    eggStatus.TextXAlignment = Enum.TextXAlignment.Left
    eggStatus.Parent = header

    return title, summary, eggStatus
end

local function createPanel(root, teamCfg, order)
    local id = math.max(1, math.floor(tonumber(teamCfg.id) or order))
    local frame = Instance.new("Frame")
    frame.Name = "Team_" .. id
    frame.Size = UDim2.fromOffset(PANEL_WIDTH, 10)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = order
    frame.Parent = root

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, PANEL_ROW_GAP)
    layout.Parent = frame

    local title, summary, eggStatus =
        createHeader(frame, tostring(teamCfg.display_name or ("NPC Team " .. id)):upper())
    return {
        id = id,
        config = teamCfg,
        frame = frame,
        title = title,
        summary = summary,
        eggStatus = eggStatus,
        cards = {},
    }
end

local function createGroundTeamPanels()
    local world = prototypeWorld()
    local spawn = world
        and world:FindFirstChild((CONFIG.world or {}).hatcher_spawn or "HatcherSpawn", true)
    if not (world and spawn and spawn:IsA("BasePart")) then
        return nil, nil
    end
    local old = world:FindFirstChild("MergeEggClientTeamDisplays")
    if old then
        old:Destroy()
    end
    local displayFolder = Instance.new("Folder")
    displayFolder.Name = "MergeEggClientTeamDisplays"
    displayFolder.Parent = world

    local panels = {}
    for order, teamCfg in ipairs(activeTeamConfigs()) do
        -- HatcherSpawn faces the battlefield. Lay each roster out behind its egg, toward the
        -- player, so rear-line management information never projects into the combat lane.
        local position = spawn.CFrame
            * CFrame.new(stationXOffset(teamCfg, order), 0, groundPanelCenterBehindEgg())
        local anchor = Instance.new("Part")
        anchor.Name = string.format("TeamDisplay%02d", order)
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        -- Rotate the floor canvas across the lane while preserving its rearward footprint. The
        -- -90-degree turn is the player-readable side of that orientation; +90 renders the entire
        -- roster upside down from the management area.
        local panelWidth, panelDepth, logicalHeight = groundPanelDimensions()
        anchor.Size = Vector3.new(panelDepth, 0.08, panelWidth)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.RespectCanCollide = true
        local excluded = { displayFolder }
        if localPlayer.Character then
            excluded[#excluded + 1] = localPlayer.Character
        end
        local playerPets = Workspace:FindFirstChild("PlayerPets")
        if playerPets then
            excluded[#excluded + 1] = playerPets
        end
        raycastParams.FilterDescendantsInstances = excluded
        local floorHit = Workspace:Raycast(
            position.Position + Vector3.new(0, 32, 0),
            Vector3.new(0, -128, 0),
            raycastParams
        )
        local floorY = floorHit and floorHit.Position.Y or spawn.Position.Y
        local anchorY = floorY + anchor.Size.Y * 0.5 + 0.01
        anchor.CFrame = CFrame.new(position.Position.X, anchorY, position.Position.Z)
            * spawn.CFrame.Rotation
            * CFrame.Angles(0, math.rad(-90), 0)
        anchor.Transparency = 1
        anchor.Parent = displayFolder

        local surface = Instance.new("SurfaceGui")
        surface.Name = "TeamSurface"
        surface.Face = Enum.NormalId.Top
        surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        surface.CanvasSize = Vector2.new(PANEL_WIDTH, logicalHeight)
        surface.LightInfluence = 0
        surface.AlwaysOnTop = false
        surface.ZOffset = 0
        surface.Parent = anchor

        local root = Instance.new("Frame")
        root.Name = "TeamPanelRoot"
        root.Size = UDim2.fromScale(1, 1)
        root.BackgroundTransparency = 1
        root.Parent = surface
        local panel = createPanel(root, teamCfg, order)
        panels[panel.id] = panel
    end
    return panels, displayFolder
end

local function destroyGroundTeamPanels(panels, displayFolder)
    for id in pairs(panels or {}) do
        panels[id] = nil
    end
    if displayFolder then
        displayFolder:Destroy()
    end
end

local function rotateBoardEggs(dt)
    local world = prototypeWorld()
    local board = world and world:FindFirstChild((CONFIG.world or {}).merge_board or "MergeBoard")
    local eggs = board and board:FindFirstChild("Eggs")
    local degrees = tonumber(((CONFIG.team or {}).merge_board or {}).rotate_degrees_per_second) or 0
    if not eggs or degrees == 0 then
        return
    end
    local rotation = CFrame.Angles(0, math.rad(degrees * dt), 0)
    for _, model in ipairs(eggs:GetChildren()) do
        if
            model:IsA("Model")
            and model:GetAttribute("MergeEggBoardEgg") == true
            and (not boardDrag or boardDrag.model ~= model)
        then
            model:PivotTo(model:GetPivot() * rotation)
        end
    end
end

local function clearCards(panel)
    for slot, card in pairs(panel.cards) do
        card.frame:Destroy()
        panel.cards[slot] = nil
    end
end

local function cardFor(panel, slot)
    local card = panel.cards[slot]
    if card then
        return card
    end
    card = HudCard.createCard(panel.frame, {
        name = string.format("NpcPet_%d_%d", panel.id, slot),
        layoutOrder = slot,
        width = PANEL_WIDTH,
        height = PANEL_CARD_HEIGHT,
    })
    card.frame.Active = false
    card.frame.Selectable = false
    HudCard.applyFunctionMark(card, nil)
    HudCard.applyHighlight(card, nil)
    panel.cards[slot] = card
    return card
end

local function updatePetCard(card, pet, authored, factor, queued, noEgg)
    authored = authored or {}
    local petType = pet and pet:GetAttribute("PetType") or authored.pet or "egg pet"
    local variant = tostring(
        pet and (pet:GetAttribute("PetVariant") or pet:GetAttribute("Variant"))
            or authored.variant
            or "basic"
    )
    local huge = pet and pet:GetAttribute("Huge") == true or authored.huge == true
    local displayName = prettyName(petType)
    if variant == "golden" then
        displayName = "Golden " .. displayName
        card.name.TextColor3 = Color3.fromRGB(255, 205, 72)
    elseif variant == "rainbow" then
        displayName = "Rainbow " .. displayName
        card.name.TextColor3 = Color3.fromRGB(100, 225, 255)
    else
        card.name.TextColor3 = Color3.fromRGB(238, 242, 250)
    end
    if huge then
        displayName = "HUGE " .. displayName
    end
    local roleId = pet and pet:GetAttribute("PetRole")
        or (PET_ROLES.by_type and PET_ROLES.by_type[petType])
        or PET_ROLES.default
        or "melee"
    local theme = ROLE_THEME[roleId] or ROLE_THEME.melee
    local hasBadge =
        PetBadge.apply(card.roleIcon, card.roleRing, PetBadge.elementForPetType(petType), roleId)
    card.roleChip.BackgroundColor3 = theme.color
    card.roleChip.BackgroundTransparency = hasBadge and 1 or 0
    card.roleGlyph.Visible = not hasBadge
    card.roleGlyph.Text = theme.glyph

    if noEgg then
        card.name.Text = "Empty pet position"
        card.name.TextColor3 = Color3.fromRGB(165, 175, 190)
        card.fill.Size = UDim2.fromScale(0, 1)
        card.fill.BackgroundColor3 = Color3.fromRGB(65, 72, 84)
        card.note.Text = "NO EGG"
    elseif pet then
        local fraction = PetEndurance.healthFraction(
            tonumber(pet:GetAttribute("CombatDamageTaken")) or 0,
            petPower(pet),
            factor
        )
        local targetText = ""
        local targetId = pet:FindFirstChild("TargetID")
        local targetType = pet:FindFirstChild("TargetType")
        if
            targetId
            and targetId.Value ~= 0
            and targetType
            and tostring(targetType.Value) == "Enemy"
        then
            targetText = " → " .. enemyName(targetId.Value)
        end
        card.name.Text = displayName .. targetText
        card.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
        card.fill.BackgroundColor3 = HudCard.healthColor(fraction)
        card.note.Text = string.format("%d%%", math.floor(fraction * 100 + 0.5))
    else
        card.name.Text = displayName
        card.fill.Size = UDim2.fromScale(0, 1)
        card.fill.BackgroundColor3 = queued and Color3.fromRGB(225, 145, 65) or HudCard.HP_RED
        card.note.Text = queued and "QUEUED" or "DEFEATED"
    end
end

local function updatePanel(panel, folder, wave, waveCount, factor)
    if not folder then
        panel.title.Text = tostring(panel.config.display_name or ("NPC Team " .. panel.id)):upper()
        panel.summary.Text = "HATCH TO DEPLOY"
        panel.summary.TextColor3 = Color3.fromRGB(175, 190, 210)
        panel.eggStatus.Text = "EGG: NOT INSTALLED"
        panel.eggStatus.TextColor3 = Color3.fromRGB(175, 190, 210)
        clearCards(panel)
        return
    end

    local squad = panel.config.squad or {}
    local expected = math.max(
        1,
        math.floor(
            tonumber(folder:GetAttribute("MergeEggExpectedPets"))
                or tonumber(((CONFIG.team or {}).positions_by_egg_tier or {})[1])
                or #squad
                or 5
        )
    )
    local active = math.max(0, tonumber(folder:GetAttribute("MergeEggActivePets")) or 0)
    local assigned = math.max(0, tonumber(folder:GetAttribute("MergeEggAssignedEnemies")) or 0)
    local peakAssigned =
        math.max(0, tonumber(folder:GetAttribute("MergeEggPeakAssignedEnemies")) or assigned)
    local firstLossWave = tonumber(folder:GetAttribute("MergeEggFirstLossWave"))
    local queueDepth =
        math.max(0, tonumber(folder:GetAttribute("MergeEggReplacementQueueDepth")) or 0)
    local replacementsHatched =
        math.max(0, tonumber(folder:GetAttribute("MergeEggReplacementsHatched")) or 0)
    local goldenRolls = math.max(0, tonumber(folder:GetAttribute("MergeEggGoldenRolls")) or 0)
    local rainbowRolls = math.max(0, tonumber(folder:GetAttribute("MergeEggRainbowRolls")) or 0)
    local lossText = firstLossWave and string.format(" • L%d", firstLossWave) or ""
    local state = readableState(folder:GetAttribute("MergeEggTeamState") or "Ready")
    local noEgg = folder:GetAttribute("MergeEggSourceId") == nil
    panel.title.Text = tostring(
        folder:GetAttribute("MergeEggTeamDisplayName") or ("NPC Team " .. panel.id)
    ):upper()
    local world = prototypeWorld()
    local waveLimit = world and world:GetAttribute("WavesEndless") == true and "∞"
        or tostring(waveCount)
    panel.summary.Text = string.format(
        "%s %d/%d • Q%d/H%d • G%d/R%d • F%d/P%d • W%d/%s%s",
        state,
        active,
        expected,
        queueDepth,
        replacementsHatched,
        goldenRolls,
        rainbowRolls,
        assigned,
        peakAssigned,
        wave,
        waveLimit,
        lossText
    )
    panel.summary.TextColor3 = state == "DEFEATED" and Color3.fromRGB(240, 105, 95)
        or state == "ENGAGED" and Color3.fromRGB(245, 190, 75)
        or state == "SUPPRESSED" and Color3.fromRGB(255, 175, 65)
        or Color3.fromRGB(175, 205, 230)
    local eggHealth = math.max(0, tonumber(folder:GetAttribute("MergeEggInstalledHealth")) or 0)
    local eggMaximum = math.max(1, tonumber(folder:GetAttribute("MergeEggInstalledMaxHealth")) or 1)
    local needsRebuild = folder:GetAttribute("MergeEggNeedsRebuild") == true
    local productionLocked = folder:GetAttribute("MergeEggProductionLocked") == true
    local productionLockRemaining =
        math.max(0, tonumber(folder:GetAttribute("MergeEggProductionLockRemaining")) or 0)
    if noEgg then
        panel.eggStatus.Text = needsRebuild and "EGG DESTROYED • REBUILD REQUIRED"
            or "EGG: NOT INSTALLED"
        panel.eggStatus.TextColor3 = needsRebuild and Color3.fromRGB(240, 105, 95)
            or Color3.fromRGB(175, 190, 210)
    else
        local eggFraction = math.clamp(eggHealth / eggMaximum, 0, 1)
        local eggName = string.upper(tostring(folder:GetAttribute("MergeEggSourceName") or "EGG"))
        local draftRolls =
            math.max(0, math.floor(tonumber(folder:GetAttribute("MergeEggDraftRolls")) or 0))
        panel.eggStatus.Text = string.format(
            "%s • %d/%d HP • %d PICK%s%s",
            eggName,
            math.floor(eggHealth + 0.5),
            math.floor(eggMaximum + 0.5),
            draftRolls,
            draftRolls == 1 and "" or "S",
            productionLocked
                    and string.format(" • PRODUCTION JAMMED %.1fs", productionLockRemaining)
                or ""
        )
        panel.eggStatus.TextColor3 = productionLocked and Color3.fromRGB(255, 175, 65)
            or HudCard.healthColor(eggFraction)
    end

    local bySlot = {}
    local queuedSlots = {}
    for value in
        string.gmatch(tostring(folder:GetAttribute("MergeEggReplacementSlots") or ""), "[^,]+")
    do
        queuedSlots[tonumber(value)] = true
    end
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet:GetAttribute("MergeEggObjective") ~= true then
            bySlot[petSlot(pet)] = pet
        end
    end
    for slot = 1, expected do
        local authored = squad[slot]
            or {
                pet = folder:GetAttribute("MergeEggSlotPet" .. slot),
                variant = folder:GetAttribute("MergeEggSlotVariant" .. slot),
                huge = folder:GetAttribute("MergeEggSlotHuge" .. slot) == true,
            }
        updatePetCard(
            cardFor(panel, slot),
            bySlot[slot],
            authored,
            factor,
            queuedSlots[slot] == true,
            noEgg
        )
    end
    for slot, card in pairs(panel.cards) do
        if slot > expected then
            card.frame:Destroy()
            panel.cards[slot] = nil
        end
    end
end

local function hatcherEggObjective(folder)
    for _, child in ipairs(folder and folder:GetChildren() or {}) do
        if child:IsA("Model") and child:GetAttribute("MergeEggObjective") == true then
            return child
        end
    end
    return nil
end

local function createEggHealthBillboard(teamId, objective)
    local adornee = objective and objective.PrimaryPart
    if not (adornee and adornee:IsA("BasePart")) then
        return nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MergeEggHatcherHealth_" .. teamId
    billboard.Adornee = adornee
    billboard.Active = false
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 180
    billboard.Size = UDim2.fromOffset(156, 18)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, objective:GetExtentsSize().Y * 0.5 + 0.8, 0)
    billboard.ResetOnSpawn = false
    billboard.Parent = localPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "EggHealthBar"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(27, 31, 39)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(18, 20, 26)
    stroke.Transparency = 0.05
    stroke.Thickness = 1.5
    stroke.Parent = frame

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = HudCard.HP_GREEN
    fill.BorderSizePixel = 0
    fill.Parent = frame
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = fill

    local label = Instance.new("TextLabel")
    label.Name = "Health"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = "5000 / 5000"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 11
    label.TextStrokeColor3 = Color3.fromRGB(20, 22, 28)
    label.TextStrokeTransparency = 0.25
    label.ZIndex = 2
    label.Parent = frame

    return {
        teamId = teamId,
        objective = objective,
        folder = nil,
        billboard = billboard,
        fill = fill,
        label = label,
    }
end

local function destroyEggHealthBillboards(controls)
    for id, control in pairs(controls) do
        if control.billboard then
            control.billboard:Destroy()
        end
        controls[id] = nil
    end
end

local function updateEggHealthBillboard(controls, teamId, folder)
    if not folder then
        local stale = controls[teamId]
        if stale then
            stale.billboard:Destroy()
            controls[teamId] = nil
        end
        return
    end
    local objective = hatcherEggObjective(folder)
    if not (objective and objective.PrimaryPart) then
        local stale = controls[teamId]
        if stale then
            stale.billboard:Destroy()
            controls[teamId] = nil
        end
        return
    end
    local control = controls[teamId]
    if not control or not control.billboard.Parent or control.objective ~= objective then
        if control and control.billboard then
            control.billboard:Destroy()
        end
        control = createEggHealthBillboard(teamId, objective)
        controls[teamId] = control
    end
    if not control then
        return
    end
    control.folder = folder

    local eggHealth = math.max(0, tonumber(folder:GetAttribute("MergeEggInstalledHealth")) or 0)
    local eggMaxHealth =
        math.max(1, tonumber(folder:GetAttribute("MergeEggInstalledMaxHealth")) or 1)
    local fraction = math.clamp(eggHealth / eggMaxHealth, 0, 1)
    control.billboard.StudsOffsetWorldSpace =
        Vector3.new(0, objective:GetExtentsSize().Y * 0.5 + 0.8, 0)
    control.fill.Size = UDim2.fromScale(fraction, 1)
    control.fill.BackgroundColor3 = HudCard.healthColor(fraction)
    control.label.Text =
        string.format("%d / %d", math.floor(eggHealth + 0.5), math.floor(eggMaxHealth + 0.5))
end

local function createManagementBoardSurface(host)
    if not (host and host:IsA("BasePart")) then
        return nil
    end
    for _, child in ipairs(host:GetChildren()) do
        if child:IsA("SurfaceGui") then
            child.Enabled = false
        end
    end
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("MergeEggManagementBoard")
    if existing then
        existing:Destroy()
    end

    local surface = Instance.new("SurfaceGui")
    surface.Name = "MergeEggManagementBoard"
    surface.Adornee = host
    surface.Face = Enum.NormalId.Front
    surface.CanvasSize = Vector2.new(1520, 720)
    surface.LightInfluence = 0
    surface.AlwaysOnTop = false
    surface.Active = true
    surface.Enabled = false
    -- Interactive world-space GUI belongs under PlayerGui with an Adornee. Keeping it under the
    -- physical part made Roblox silently stop routing pointer input as the camera zoomed away.
    surface.Parent = playerGui

    local background = Instance.new("Frame")
    background.Name = "Cards"
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(24, 29, 40)
    background.BackgroundTransparency = 0.02
    background.BorderSizePixel = 0
    background.Parent = surface

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 18)
    padding.PaddingRight = UDim.new(0, 18)
    padding.PaddingTop = UDim.new(0, 18)
    padding.PaddingBottom = UDim.new(0, 18)
    padding.Parent = background

    local grid = Instance.new("UIGridLayout")
    grid.CellPadding = UDim2.fromOffset(14, 14)
    grid.CellSize = UDim2.new(1 / 3, -10, 1 / 3, -10)
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.FillDirectionMaxCells = 3
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.VerticalAlignment = Enum.VerticalAlignment.Center
    grid.Parent = background

    local cards = {
        {
            id = "coin_value",
            color = Color3.fromRGB(225, 162, 45),
            action = { action = "purchase_upgrade", upgradeId = "coin_value" },
        },
        {
            id = "damage",
            color = Color3.fromRGB(70, 177, 235),
            action = { action = "purchase_upgrade", upgradeId = "damage" },
        },
        {
            id = "fire_rate",
            color = Color3.fromRGB(235, 82, 91),
            action = { action = "purchase_upgrade", upgradeId = "fire_rate" },
        },
        {
            id = "active_slots",
            color = Color3.fromRGB(125, 104, 235),
            action = { action = "purchase_upgrade", upgradeId = "active_slots" },
        },
        {
            id = "egg_health",
            color = Color3.fromRGB(225, 72, 112),
            action = { action = "purchase_upgrade", upgradeId = "egg_health" },
        },
        {
            id = "spawn_level",
            color = Color3.fromRGB(82, 205, 105),
            action = { action = "upgrade_base", managementBoard = true },
        },
        {
            id = "buy_egg",
            color = Color3.fromRGB(52, 183, 225),
            action = { action = "create", managementBoard = true },
        },
        {
            id = "auto_combine",
            color = Color3.fromRGB(177, 82, 225),
            action = { action = "toggle_auto" },
        },
        {
            id = "rebirth",
            color = Color3.fromRGB(245, 145, 45),
            action = { action = "rebirth" },
        },
    }
    local buttons = {}
    for order, card in ipairs(cards) do
        local button = Instance.new("TextButton")
        button.Name = card.id
        button.LayoutOrder = order
        button.BackgroundColor3 = card.color
        button.BackgroundTransparency = 0.04
        button.BorderSizePixel = 0
        button.AutoButtonColor = true
        button.Active = true
        button.ClipsDescendants = false
        button.Text = ""
        button.Parent = background

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 18)
        corner.Parent = button

        local stroke = Instance.new("UIStroke")
        stroke.Color = card.color:Lerp(Color3.new(1, 1, 1), 0.35)
        stroke.Thickness = 7
        stroke.Parent = button

        local inner = Instance.new("Frame")
        inner.Name = "Inset"
        inner.Position = UDim2.fromScale(0.035, 0.045)
        inner.Size = UDim2.fromScale(0.93, 0.77)
        inner.BackgroundColor3 = Color3.fromRGB(15, 18, 27)
        inner.BackgroundTransparency = 0.02
        inner.BorderSizePixel = 0
        inner.ZIndex = 2
        inner.Parent = button

        local innerCorner = Instance.new("UICorner")
        innerCorner.CornerRadius = UDim.new(0, 13)
        innerCorner.Parent = inner

        local innerStroke = Instance.new("UIStroke")
        innerStroke.Color = Color3.fromRGB(5, 7, 12)
        innerStroke.Thickness = 5
        innerStroke.Parent = inner

        local contentLabel = Instance.new("TextLabel")
        contentLabel.Name = "Content"
        contentLabel.Position = UDim2.fromScale(0.055, 0.055)
        contentLabel.Size = UDim2.fromScale(0.89, 0.77)
        contentLabel.BackgroundTransparency = 1
        contentLabel.Font = Enum.Font.GothamBlack
        contentLabel.Text = string.upper(card.id:gsub("_", " "))
        contentLabel.TextColor3 = Color3.new(1, 1, 1)
        contentLabel.TextScaled = true
        contentLabel.TextStrokeColor3 = Color3.fromRGB(5, 7, 12)
        contentLabel.TextStrokeTransparency = 0.15
        contentLabel.TextWrapped = true
        contentLabel.ZIndex = 3
        contentLabel.Parent = inner

        local pricePill = Instance.new("Frame")
        pricePill.Name = "PricePill"
        pricePill.AnchorPoint = Vector2.new(0.5, 0.5)
        pricePill.Position = UDim2.fromScale(0.5, 0.84)
        pricePill.Size = UDim2.fromScale(0.72, 0.24)
        pricePill.BackgroundColor3 = MANAGEMENT_PRICE_THEME.gems.fill
        pricePill.BorderSizePixel = 0
        pricePill.ZIndex = 5
        pricePill.Parent = button

        local pillCorner = Instance.new("UICorner")
        pillCorner.CornerRadius = UDim.new(1, 0)
        pillCorner.Parent = pricePill

        local pillStroke = Instance.new("UIStroke")
        pillStroke.Color = MANAGEMENT_PRICE_THEME.gems.stroke
        pillStroke.Thickness = 5
        pillStroke.Parent = pricePill

        local priceIcon = Instance.new("ImageLabel")
        priceIcon.Name = "CurrencyIcon"
        priceIcon.AnchorPoint = Vector2.new(0, 0.5)
        priceIcon.Position = UDim2.fromScale(0.055, 0.5)
        priceIcon.Size = UDim2.fromScale(0.21, 0.78)
        priceIcon.BackgroundTransparency = 1
        priceIcon.Image = AMETHYST_GEM_ICON
        priceIcon.ScaleType = Enum.ScaleType.Fit
        priceIcon.ZIndex = 6
        priceIcon.Parent = pricePill

        local priceLabel = Instance.new("TextLabel")
        priceLabel.Name = "Price"
        priceLabel.Position = UDim2.fromScale(0.25, 0.08)
        priceLabel.Size = UDim2.fromScale(0.69, 0.84)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Font = Enum.Font.GothamBlack
        priceLabel.Text = "0"
        priceLabel.TextColor3 = Color3.new(1, 1, 1)
        priceLabel.TextScaled = true
        priceLabel.TextStrokeColor3 = Color3.fromRGB(20, 12, 30)
        priceLabel.TextStrokeTransparency = 0.1
        priceLabel.ZIndex = 6
        priceLabel.Parent = pricePill

        local action = card.action
        button.Activated:Connect(function()
            if card.id ~= "rebirth" then
                Signals.MergeEggPrototypeBoardAction:FireServer(action)
                return
            end
            local now = os.clock()
            if now >= rebirthConfirmUntil then
                rebirthConfirmUntil = now + 4
                return
            end
            rebirthConfirmUntil = 0
            Signals.MergeEggPrototypeBoardAction:FireServer({
                action = "rebirth",
                confirm = true,
            })
        end)
        buttons[card.id] = {
            button = button,
            color = card.color,
            stroke = stroke,
            inner = inner,
            contentLabel = contentLabel,
            pricePill = pricePill,
            priceStroke = pillStroke,
            priceIcon = priceIcon,
            priceLabel = priceLabel,
        }
    end
    return { surface = surface, host = host, buttons = buttons }
end

local function createEquipBestSurface(host)
    if not (host and host:IsA("BasePart")) then
        return nil
    end
    for _, child in ipairs(host:GetChildren()) do
        if child:IsA("SurfaceGui") then
            child.Enabled = false
        end
    end
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("MergeEggEquipBestSurface")
    if existing then
        existing:Destroy()
    end

    local surface = Instance.new("SurfaceGui")
    surface.Name = "MergeEggEquipBestSurface"
    surface.Adornee = host
    surface.Face = Enum.NormalId.Top
    surface.CanvasSize = Vector2.new(600, 300)
    surface.LightInfluence = 0
    surface.AlwaysOnTop = false
    surface.Active = true
    surface.Enabled = false
    surface.Parent = playerGui

    local button = Instance.new("TextButton")
    button.Name = "EquipBest"
    button.Size = UDim2.fromScale(1, 1)
    button.Rotation = tonumber(
        ((CONFIG.team or {}).merge_board or {}).equip_best_text_rotation_degrees
    ) or 180
    button.BackgroundColor3 = Color3.fromRGB(75, 190, 105)
    button.BackgroundTransparency = 0.03
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Active = true
    button.Font = Enum.Font.GothamBlack
    button.Text = "EQUIP BEST"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextScaled = true
    button.TextStrokeColor3 = Color3.fromRGB(20, 35, 28)
    button.TextStrokeTransparency = 0.12
    button.TextWrapped = true
    button.Parent = surface

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0.06, 0)
    padding.PaddingRight = UDim.new(0.06, 0)
    padding.PaddingTop = UDim.new(0.08, 0)
    padding.PaddingBottom = UDim.new(0.08, 0)
    padding.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(185, 255, 205)
    stroke.Thickness = 7
    stroke.Parent = button

    button.Activated:Connect(function()
        Signals.MergeEggPrototypeBoardAction:FireServer({ action = "equip_best" })
    end)
    return { surface = surface, host = host, button = button }
end

local function createBoardWallControls()
    local world = prototypeWorld()
    if not world then
        return nil
    end
    local worldCfg = CONFIG.world or {}
    local host = world:FindFirstChild(worldCfg.egg_merge_control or "EggMergeControl", true)
    local equipBestHost =
        world:FindFirstChild(worldCfg.equip_best_control or "EquipBestControl", true)
    return {
        world = world,
        board = createManagementBoardSurface(host),
        equipBest = createEquipBestSurface(equipBestHost),
    }
end

local function setManagementCard(card, observing, presentation)
    if not card then
        return
    end
    presentation = presentation or {}
    local available = presentation.available ~= false
    local cardColor = available and card.color or Color3.fromRGB(70, 74, 84)
    card.button.Active = observing and available
    card.button.AutoButtonColor = observing and available
    card.button.BackgroundColor3 = cardColor
    card.stroke.Color = cardColor:Lerp(Color3.new(1, 1, 1), available and 0.35 or 0.18)
    card.inner.BackgroundColor3 = available and Color3.fromRGB(15, 18, 27)
        or Color3.fromRGB(31, 34, 41)
    card.contentLabel.Text = string.format(
        "%s\n%s",
        tostring(presentation.title or ""),
        tostring(presentation.detail or "")
    )

    local showPill = presentation.pillText ~= nil
    card.pricePill.Visible = showPill
    card.inner.Size = showPill and UDim2.fromScale(0.93, 0.77) or UDim2.fromScale(0.93, 0.9)
    card.contentLabel.Size = showPill and UDim2.fromScale(0.89, 0.77) or UDim2.fromScale(0.89, 0.89)
    if not showPill then
        return
    end

    local themeKey = available and tostring(presentation.currency or "gems") or "unavailable"
    local priceTheme = MANAGEMENT_PRICE_THEME[themeKey] or MANAGEMENT_PRICE_THEME.gems
    card.pricePill.BackgroundColor3 = priceTheme.fill
    card.priceStroke.Color = priceTheme.stroke
    card.priceLabel.Text = tostring(presentation.pillText)
    local showIcon = presentation.showIcon ~= false and priceTheme.icon ~= nil
    card.priceIcon.Visible = showIcon
    card.priceIcon.Image = priceTheme.icon or ""
    card.priceLabel.Position = showIcon and UDim2.fromScale(0.25, 0.08)
        or UDim2.fromScale(0.06, 0.08)
    card.priceLabel.Size = showIcon and UDim2.fromScale(0.69, 0.84) or UDim2.fromScale(0.88, 0.84)
end

local function formatDamageMultiplier(value)
    local formatted = string.format("%.2f", math.max(1, tonumber(value) or 1))
    formatted = string.gsub(formatted, "0+$", "")
    formatted = string.gsub(formatted, "%.$", "")
    return formatted .. "X"
end

local function updateBoardWallControls(controls, observing)
    if not controls then
        return
    end
    local world = controls.world
    local equipBest = controls.equipBest
    if equipBest then
        local available = world and world:GetAttribute("EquipBestAvailable") == true
        equipBest.surface.Enabled = observing
        equipBest.button.Active = observing and available
        equipBest.button.AutoButtonColor = observing and available
        local stateColor = available and Color3.fromRGB(75, 190, 105) or Color3.fromRGB(70, 74, 84)
        equipBest.button.BackgroundColor3 = stateColor
        equipBest.button.Text = "EQUIP BEST"
        local host = equipBest.host
        if host and host:IsA("BasePart") then
            host.Color = stateColor
        end
    end
    if not controls.board then
        return
    end
    local board = controls.board
    local buttons = board.buttons
    board.surface.Enabled = observing
    local autoEnabled = world and world:GetAttribute("AutoCombineEnabled") == true
    local baseName = tostring(world and world:GetAttribute("BaseEggSourceName") or "Earth Egg")
    local upgradeData = {
        coin_value = { title = "COIN VALUE", attribute = "CoinValue", suffix = "%" },
        damage = { title = "DAMAGE", attribute = "Damage", suffix = "%" },
        fire_rate = { title = "FIRE RATE", attribute = "FireRate", suffix = "%" },
        egg_health = { title = "EGG HP", attribute = "EggHealth", suffix = "%" },
    }
    for id, data in pairs(upgradeData) do
        local card = buttons[id]
        local prefix = "Management" .. data.attribute
        local step = math.max(0, tonumber(world:GetAttribute(prefix .. "Step")) or 0)
        local stepPercent = math.floor(step * 100 + 0.5)
        local cost = world:GetAttribute(prefix .. "Cost")
        local maxed = world:GetAttribute(prefix .. "Maxed") == true
        setManagementCard(card, observing, {
            title = data.title,
            detail = string.format("+%d%s", stepPercent, data.suffix),
            available = not maxed,
            currency = "gems",
            pillText = maxed and "MAX" or MergeEggCostFormat.format(cost),
            showIcon = not maxed,
        })
    end

    local slots = math.max(1, math.floor(tonumber(world:GetAttribute("OwnedHatcherSlots")) or 4))
    local maximumSlots =
        math.max(slots, math.floor(tonumber(world:GetAttribute("MaximumHatcherSlots")) or 9))
    local slotCost = world:GetAttribute("ManagementActiveSlotsCost")
    local slotMaxed = world:GetAttribute("ManagementActiveSlotsMaxed") == true
    local pending = world:GetAttribute("ActiveSlotDeploymentPending") == true
    setManagementCard(buttons.active_slots, observing, {
        title = "ACTIVE SLOTS",
        detail = slotMaxed and string.format("%d / %d", slots, maximumSlots) or string.format(
            "%d → %d / %d%s",
            slots,
            slots + 1,
            maximumSlots,
            pending and " • RESET" or ""
        ),
        available = not slotMaxed,
        currency = "gems",
        pillText = slotMaxed and "MAX" or MergeEggCostFormat.format(slotCost),
        showIcon = not slotMaxed,
    })

    local canUpgrade = world:GetAttribute("BaseEggCanUpgrade") == true
    local ready = world:GetAttribute("BaseEggUpgradeReady") == true
    local nextName = tostring(world:GetAttribute("BaseEggNextSourceName") or "Next Egg")
    local spawnCost =
        math.max(0, math.floor(tonumber(world:GetAttribute("BaseEggUpgradeCost")) or 0))
    if not canUpgrade then
        setManagementCard(buttons.spawn_level, observing, {
            title = "SPAWN LEVEL",
            detail = string.format("%s • MAX", string.upper(baseName)),
            available = false,
            pillText = "MAX",
            showIcon = false,
        })
    elseif not ready then
        setManagementCard(buttons.spawn_level, observing, {
            title = "SPAWN LEVEL",
            detail = string.format("FINISH %s HATCHERS", string.upper(baseName)),
            available = false,
            pillText = MergeEggCostFormat.format(spawnCost),
            showIcon = true,
        })
    else
        setManagementCard(buttons.spawn_level, observing, {
            title = "SPAWN LEVEL",
            detail = string.format("%s → %s", string.upper(baseName), string.upper(nextName)),
            available = true,
            currency = "waycoins",
            pillText = MergeEggCostFormat.format(spawnCost),
        })
    end

    local buyCost =
        math.max(0, math.floor(tonumber(world:GetAttribute("BaseEggCreationCost")) or 100))
    setManagementCard(buttons.buy_egg, observing, {
        title = "BUY EGG",
        detail = string.upper(baseName),
        available = true,
        currency = "waycoins",
        pillText = MergeEggCostFormat.format(buyCost),
    })
    setManagementCard(buttons.auto_combine, observing, {
        title = "AUTO-COMBINE",
        detail = string.format("%s\nFUTURE GAME PASS", autoEnabled and "ON" or "OFF"),
        available = true,
    })
    if autoEnabled then
        buttons.auto_combine.button.BackgroundColor3 = Color3.fromRGB(75, 190, 105)
        buttons.auto_combine.stroke.Color = Color3.fromRGB(150, 255, 180)
    end

    local rebirthCount =
        math.max(0, math.floor(tonumber(world:GetAttribute("MergeDefenseRebirthCount")) or 0))
    local rebirthRank = math.max(
        1,
        math.floor(tonumber(world:GetAttribute("MergeDefenseRebirthRank")) or (rebirthCount + 1))
    )
    local alliedDamageMultiplier =
        math.max(1, tonumber(world:GetAttribute("MergeDefenseRebirthDamageMultiplier")) or 1)
    alliedDamageMultiplier = math.max(
        alliedDamageMultiplier,
        tonumber(world:GetAttribute("MergeDefenseAlliedDamageMultiplier")) or alliedDamageMultiplier
    )
    local nextAlliedDamageMultiplier = math.max(
        alliedDamageMultiplier,
        tonumber(world:GetAttribute("MergeDefenseNextAlliedDamageMultiplier"))
            or alliedDamageMultiplier
    )
    local rebirthCost = world:GetAttribute("MergeDefenseRebirthCost")
    local rebirthMaxed = world:GetAttribute("MergeDefenseRebirthMaxed") == true
    local rebirthRequirementMet = world:GetAttribute("MergeDefenseRebirthRequirementMet") ~= false
    local rebirthMinimumTier = world:GetAttribute("MergeDefenseRebirthMinimumEggTier")
    local rebirthCard = buttons.rebirth
    local rebirthAvailable = observing and not rebirthMaxed and rebirthRequirementMet
    if rebirthMaxed then
        setManagementCard(rebirthCard, observing, {
            title = string.format("REBIRTH R%d", rebirthRank),
            detail = string.format(
                "%s DAMAGE • MAX",
                formatDamageMultiplier(alliedDamageMultiplier)
            ),
            available = false,
            pillText = "MAX",
            showIcon = false,
        })
    elseif not rebirthRequirementMet then
        setManagementCard(rebirthCard, observing, {
            title = string.format("REBIRTH R%d", rebirthRank + 1),
            detail = string.format(
                "ALL EGGS NEED TIER %d",
                math.max(1, math.floor(tonumber(rebirthMinimumTier) or 1))
            ),
            available = false,
            pillText = MergeEggCostFormat.format(rebirthCost),
            showIcon = true,
        })
    elseif os.clock() < rebirthConfirmUntil then
        setManagementCard(rebirthCard, observing, {
            title = "CONFIRM REBIRTH",
            detail = "RESETS RUN + WAYCOINS",
            available = rebirthAvailable,
            currency = "rebirth",
            pillText = "CLICK AGAIN",
            showIcon = false,
        })
    else
        setManagementCard(rebirthCard, observing, {
            title = string.format("REBIRTH R%d", rebirthRank + 1),
            detail = string.format(
                "%s TOTAL DAMAGE",
                formatDamageMultiplier(nextAlliedDamageMultiplier)
            ),
            available = rebirthAvailable,
            currency = "rebirth",
            pillText = MergeEggCostFormat.format(rebirthCost),
        })
    end
end

local function boardEggFromInstance(instance)
    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Model") and current:GetAttribute("MergeEggBoardEgg") == true then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function includedInstanceAtScreenPoint(screenPoint, includedInstances)
    local camera = Workspace.CurrentCamera
    if not camera or #includedInstances == 0 then
        return nil
    end
    -- InputObject.Position and GetMouseLocation are screen coordinates (including Roblox's top
    -- inset). ScreenPointToRay consumes that coordinate space; ViewportPointToRay caused the egg
    -- hit test to land above the cursor and made otherwise valid drags appear inert.
    local ray = camera:ScreenPointToRay(screenPoint.X, screenPoint.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = includedInstances
    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    return result and result.Instance or nil
end

local function boardEggAtScreenPoint(screenPoint, excludedEgg)
    local world = prototypeWorld()
    local board = world and world:FindFirstChild((CONFIG.world or {}).merge_board or "MergeBoard")
    local eggs = board and board:FindFirstChild("Eggs")
    local included = {}
    for _, egg in ipairs(eggs and eggs:GetChildren() or {}) do
        if egg:IsA("Model") and egg ~= excludedEgg then
            included[#included + 1] = egg
        end
    end
    return boardEggFromInstance(includedInstanceAtScreenPoint(screenPoint, included))
end

local function deploymentTeamFromInstance(instance)
    local current = instance
    while current and current ~= Workspace do
        if
            current:IsA("BasePart")
            and current:GetAttribute("MergeEggDeploymentPad") == true
            and current:GetAttribute("MergeEggDeploymentAvailable") == true
        then
            return tonumber(current:GetAttribute("MergeEggDeploymentTeamId"))
        end
        if current:IsA("Model") and current:GetAttribute("MergeEggObjective") == true then
            return tonumber(current:GetAttribute("MergeEggTeamId"))
        end
        current = current.Parent
    end
    return nil
end

local function deploymentPadForTeam(teamId)
    local world = prototypeWorld()
    local pads = world and world:FindFirstChild("MergeEggDeploymentPads")
    for _, pad in ipairs(pads and pads:GetChildren() or {}) do
        if
            pad:IsA("BasePart")
            and pad:GetAttribute("MergeEggDeploymentAvailable") == true
            and tonumber(pad:GetAttribute("MergeEggDeploymentTeamId")) == tonumber(teamId)
        then
            return pad
        end
    end
    return nil
end

local function createCompatibleDeploymentSquares(sourceTier)
    local world = prototypeWorld()
    local pads = world and world:FindFirstChild("MergeEggDeploymentPads")
    local squares = {}
    local targets = {}
    for _, pad in ipairs(pads and pads:GetChildren() or {}) do
        local deployedTier =
            math.max(0, math.floor(tonumber(pad:GetAttribute("MergeEggDeploymentTier")) or 0))
        if
            pad:IsA("BasePart")
            and pad:GetAttribute("MergeEggDeploymentAvailable") == true
            and (deployedTier == 0 or deployedTier == sourceTier)
        then
            local square = createYellowSelectionSquare(
                "MergeEggCompatibleDestination",
                math.max(2, math.min(pad.Size.X, pad.Size.Z) * 0.92)
            )
            square.CFrame = pad.CFrame * CFrame.new(0, 0.11, 0)
            square.Transparency = 0.56
            square:SetAttribute("MergeEggDropKind", "deploy")
            square:SetAttribute(
                "MergeEggDeploymentTeamId",
                pad:GetAttribute("MergeEggDeploymentTeamId")
            )
            squares[#squares + 1] = square
            targets[#targets + 1] = {
                kind = "deploy",
                adornee = pad,
                teamId = tonumber(pad:GetAttribute("MergeEggDeploymentTeamId")),
                empty = deployedTier == 0,
            }
        end
    end
    return squares, targets
end

local function dropTargetPosition(target)
    local adornee = target and target.adornee
    if adornee and adornee:IsA("Model") then
        return boardEggBasePosition(adornee) or adornee:GetPivot().Position
    elseif adornee and adornee:IsA("BasePart") then
        return adornee.Position
    end
    return nil
end

local function preferredDropTarget(targets, origin)
    local world = prototypeWorld()
    local tutorialStep = tostring(world and world:GetAttribute("MergeEggTutorialStep") or "")
    local tutorialWantsMerge = tutorialStep == "combine_once"
    local best
    local bestPriority = math.huge
    local bestDistance = math.huge
    for _, target in ipairs(targets or {}) do
        local priority
        if tutorialWantsMerge then
            priority = (target.kind == "merge" or target.empty == false) and 1 or 2
        elseif target.kind == "deploy" and target.empty == true then
            priority = 1
        elseif target.kind == "merge" then
            priority = 2
        else
            priority = 3
        end
        local position = dropTargetPosition(target)
        local distance = position and origin and (position - origin).Magnitude or math.huge
        if priority < bestPriority or priority == bestPriority and distance < bestDistance then
            best = target
            bestPriority = priority
            bestDistance = distance
        end
    end
    return best
end

local function createCompatibleMergeSquares(sourceTier, sourceSlot, sourceModel)
    local world = prototypeWorld()
    local board = world and world:FindFirstChild((CONFIG.world or {}).merge_board or "MergeBoard")
    local eggs = board and board:FindFirstChild("Eggs")
    local boardCfg = ((CONFIG.team or {}).merge_board or {})
    local squareSize = math.max(2, tonumber(boardCfg.slot_size) or 6.6) * 0.88
    local squares = {}
    local targets = {}
    for _, egg in ipairs(eggs and eggs:GetChildren() or {}) do
        local targetSlot = tonumber(egg:GetAttribute("MergeEggBoardSlot"))
        local targetTier = tonumber(egg:GetAttribute("MergeEggSourceTier"))
        local basePosition = boardEggBasePosition(egg)
        if
            egg:IsA("Model")
            and egg ~= sourceModel
            and targetSlot
            and targetSlot ~= sourceSlot
            and targetTier == sourceTier
            and basePosition
        then
            local square = createYellowSelectionSquare("MergeEggCompatibleDestination", squareSize)
            square.CFrame = CFrame.new(basePosition + Vector3.new(0, 0.08, 0))
            square.Transparency = 0.56
            square:SetAttribute("MergeEggDropKind", "merge")
            square:SetAttribute("MergeEggBoardSlot", targetSlot)
            squares[#squares + 1] = square
            targets[#targets + 1] = {
                kind = "merge",
                adornee = egg,
                targetSlot = targetSlot,
            }
        end
    end
    return squares, targets
end

local function dropTargetAtScreenPoint(screenPoint, drag)
    local draggedPosition = drag and drag.model and drag.model:GetPivot().Position
    local world = prototypeWorld()
    local nearestMerge
    local nearestMergeDistance = math.huge
    if draggedPosition then
        local boardCfg = ((CONFIG.team or {}).merge_board or {})
        local mergeSnapRadius = math.max(2, tonumber(boardCfg.slot_size) or 6.6) * 0.72
        for _, candidate in ipairs(drag.dropTargets or {}) do
            local candidatePosition = candidate.kind == "merge" and dropTargetPosition(candidate)
                or nil
            if candidatePosition then
                local horizontalDistance = (
                    Vector2.new(draggedPosition.X, draggedPosition.Z)
                    - Vector2.new(candidatePosition.X, candidatePosition.Z)
                ).Magnitude
                if
                    horizontalDistance <= mergeSnapRadius
                    and horizontalDistance < nearestMergeDistance
                then
                    nearestMerge = candidate
                    nearestMergeDistance = horizontalDistance
                end
            end
        end
    end
    if nearestMerge then
        return nearestMerge
    end

    local targetEgg = boardEggAtScreenPoint(screenPoint, drag and drag.model)
    if targetEgg then
        local targetSlot = tonumber(targetEgg:GetAttribute("MergeEggBoardSlot"))
        local targetTier = tonumber(targetEgg:GetAttribute("MergeEggSourceTier"))
        if
            drag.sourceSlot
            and targetSlot
            and drag.sourceSlot ~= targetSlot
            and drag.sourceTier == targetTier
        then
            return {
                kind = "merge",
                adornee = targetEgg,
                targetSlot = targetSlot,
            }
        end
        return nil
    end

    local pads = world and world:FindFirstChild("MergeEggDeploymentPads")
    local includedPads = {}
    local nearestPad
    local nearestDistance = math.huge
    for _, candidate in ipairs(pads and pads:GetChildren() or {}) do
        local deployedTier =
            math.max(0, math.floor(tonumber(candidate:GetAttribute("MergeEggDeploymentTier")) or 0))
        if
            candidate:IsA("BasePart")
            and candidate:GetAttribute("MergeEggDeploymentAvailable") == true
            and (deployedTier == 0 or deployedTier == drag.sourceTier)
        then
            includedPads[#includedPads + 1] = candidate
            if draggedPosition then
                local horizontalDistance = (
                    Vector2.new(draggedPosition.X, draggedPosition.Z)
                    - Vector2.new(candidate.Position.X, candidate.Position.Z)
                ).Magnitude
                local snapRadius = math.max(candidate.Size.X, candidate.Size.Z) * 0.72
                if horizontalDistance <= snapRadius and horizontalDistance < nearestDistance then
                    nearestPad = candidate
                    nearestDistance = horizontalDistance
                end
            end
        end
    end
    local pad = nearestPad
    if not pad then
        local instance = includedInstanceAtScreenPoint(screenPoint, includedPads)
        local teamId = deploymentTeamFromInstance(instance)
        pad = teamId and deploymentPadForTeam(teamId) or nil
    end
    if pad then
        local deployedTier =
            math.max(0, math.floor(tonumber(pad:GetAttribute("MergeEggDeploymentTier")) or 0))
        if deployedTier == 0 or deployedTier == drag.sourceTier then
            return {
                kind = "deploy",
                adornee = pad,
                teamId = tonumber(pad:GetAttribute("MergeEggDeploymentTeamId")),
            }
        end
    end
    return nil
end

local function setDragTarget(drag, target)
    drag.dropTarget = target
    for _, square in ipairs(drag.destinationSquares or {}) do
        local squareKind = tostring(square:GetAttribute("MergeEggDropKind") or "deploy")
        local selected = target
            and (
                squareKind == "deploy"
                    and target.kind == "deploy"
                    and tonumber(square:GetAttribute("MergeEggDeploymentTeamId")) == tonumber(
                        target.teamId
                    )
                or squareKind == "merge"
                    and target.kind == "merge"
                    and tonumber(square:GetAttribute("MergeEggBoardSlot")) == tonumber(
                        target.targetSlot
                    )
            )
        square.Color = selected and Color3.fromRGB(70, 255, 125) or Color3.fromRGB(255, 213, 35)
        square.Transparency = selected and 0.16 or 0.56
        local outline = square:FindFirstChild("Outline")
        if outline and outline:IsA("SelectionBox") then
            outline.Color3 = selected and Color3.fromRGB(205, 255, 215)
                or Color3.fromRGB(255, 245, 150)
            outline.SurfaceColor3 = selected and Color3.fromRGB(75, 255, 130)
                or Color3.fromRGB(255, 220, 45)
            outline.SurfaceTransparency = selected and 0.38 or 0.68
        end
    end
    if drag.targetHighlight then
        drag.targetHighlight.Adornee = target and target.adornee or nil
        drag.targetHighlight.Enabled = target ~= nil
    end
    local chevron = drag.chevron
    if not chevron then
        return
    end
    local guideTarget = target or drag.homeTarget
    local guideColor = target and Color3.fromRGB(75, 255, 130) or Color3.fromRGB(255, 222, 70)
    for _, descendant in ipairs(chevron:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
            descendant.Color = guideColor
            descendant.Transparency = guideTarget and 0.08 or 1
        elseif descendant:IsA("Highlight") then
            descendant.FillColor = guideColor
            descendant.OutlineColor = guideColor
            descendant.Enabled = guideTarget ~= nil
        end
    end
    if not guideTarget then
        return
    end
    local targetPosition = dropTargetPosition(guideTarget)
    if not targetPosition then
        return
    end
    local hover = targetPosition + Vector3.new(0, 5.5 + math.sin(os.clock() * 5) * 0.35, 0)
    chevron:PivotTo(CFrame.lookAt(hover, targetPosition))
end

local function destroyBoardDrag(drag, restore)
    if not drag then
        return
    end
    if restore and drag.model and drag.model.Parent then
        drag.model:PivotTo(drag.originalPivot)
    end
    for _, visual in ipairs({ drag.highlight, drag.targetHighlight, drag.chevron }) do
        if visual then
            visual:Destroy()
        end
    end
    destroyEggFocusVisual(drag.sourceFocus)
    for _, square in ipairs(drag.destinationSquares or {}) do
        square:Destroy()
    end
end

local function dragScreenPoint(drag)
    if drag and drag.input.UserInputType == Enum.UserInputType.Touch then
        return drag.input.Position
    end
    return UserInputService:GetMouseLocation()
end

local function updateBoardDrag()
    local drag = boardDrag
    local camera = Workspace.CurrentCamera
    if not (drag and drag.model and drag.model.Parent and camera) then
        return
    end
    local screenPoint = dragScreenPoint(drag)
    local ray = camera:ScreenPointToRay(screenPoint.X, screenPoint.Y)
    if math.abs(ray.Direction.Y) < 0.001 then
        return
    end
    local t = (drag.originalPivot.Position.Y - ray.Origin.Y) / ray.Direction.Y
    if t <= 0 then
        return
    end
    local point = ray.Origin + ray.Direction * t
    drag.model:PivotTo(CFrame.new(point.X, drag.originalPivot.Position.Y, point.Z) * drag.rotation)
    updateEggFocusVisual(drag.sourceFocus, drag.model)
    setDragTarget(drag, dropTargetAtScreenPoint(screenPoint, drag))
end

local function beginBoardDrag(input)
    if localPlayer:GetAttribute("InMergeEggPrototype") ~= true or boardDrag then
        return
    end
    local model = boardEggAtScreenPoint(input.Position, nil)
    if not model then
        return
    end
    local pivot = model:GetPivot()
    local highlight = Instance.new("Highlight")
    highlight.Name = "MergeEggDragHighlight"
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = Color3.fromRGB(255, 225, 90)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = model
    highlight.Parent = model
    local targetHighlight = Instance.new("Highlight")
    targetHighlight.Name = "MergeEggDropTargetHighlight"
    targetHighlight.FillColor = Color3.fromRGB(70, 255, 125)
    targetHighlight.FillTransparency = 0.24
    targetHighlight.OutlineColor = Color3.fromRGB(220, 255, 225)
    targetHighlight.OutlineTransparency = 0
    targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    targetHighlight.Enabled = false
    targetHighlight.Parent = Workspace
    local chevron = WorldChevron.create(Workspace, {
        name = "MergeEggDropChevron",
        color = Color3.fromRGB(255, 222, 70),
        fillColor = Color3.fromRGB(255, 242, 155),
    })
    local sourceTier = tonumber(model:GetAttribute("MergeEggSourceTier"))
    local sourceFocus = createEggFocusVisual("MergeEggHeldFocus")
    if sourceFocus.chevron then
        sourceFocus.chevron:Destroy()
        sourceFocus.chevron = nil
    end
    updateEggFocusVisual(sourceFocus, model)
    local sourceSlot = tonumber(model:GetAttribute("MergeEggBoardSlot"))
    local deploymentSquares, deploymentTargets = createCompatibleDeploymentSquares(sourceTier)
    local mergeSquares, mergeTargets = createCompatibleMergeSquares(sourceTier, sourceSlot, model)
    local destinationSquares = {}
    local dropTargets = {}
    for _, square in ipairs(deploymentSquares) do
        destinationSquares[#destinationSquares + 1] = square
    end
    for _, square in ipairs(mergeSquares) do
        destinationSquares[#destinationSquares + 1] = square
    end
    for _, target in ipairs(deploymentTargets) do
        dropTargets[#dropTargets + 1] = target
    end
    for _, target in ipairs(mergeTargets) do
        dropTargets[#dropTargets + 1] = target
    end
    boardDrag = {
        input = input,
        model = model,
        sourceSlot = sourceSlot,
        sourceTier = sourceTier,
        originalPivot = pivot,
        rotation = pivot.Rotation,
        highlight = highlight,
        targetHighlight = targetHighlight,
        chevron = chevron,
        sourceFocus = sourceFocus,
        destinationSquares = destinationSquares,
        dropTargets = dropTargets,
        homeTarget = preferredDropTarget(dropTargets, pivot.Position),
    }
    setDragTarget(boardDrag, nil)
end

local function finishBoardDrag(input)
    local drag = boardDrag
    if not drag or drag.input.UserInputType ~= input.UserInputType then
        return
    end
    local screenPoint = dragScreenPoint(drag)
    local target = dropTargetAtScreenPoint(screenPoint, drag)
    destroyBoardDrag(drag, true)
    boardDrag = nil

    if drag.sourceSlot and target and target.kind == "merge" then
        Signals.MergeEggPrototypeBoardAction:FireServer({
            action = "merge_slots",
            sourceSlot = drag.sourceSlot,
            targetSlot = target.targetSlot,
        })
    elseif drag.sourceSlot and target and target.kind == "deploy" then
        Signals.MergeEggPrototypeBoardAction:FireServer({
            action = "deploy_to_hatcher",
            sourceSlot = drag.sourceSlot,
            teamId = target.teamId,
        })
    end
end

function MergeEggPrototypeObserver.start()
    if not RunService:IsStudio() and not PlaceRuntime.isMerge(game.PlaceId, PLACES) then
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MergeEggPrototypeObserver"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 41
    gui.Enabled = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")
    local boardActionFeedback, boardActionFeedbackStroke = createBoardActionFeedback(gui)
    local tutorialCard = createTutorialCard(gui)
    local boardActionFeedbackUntil = 0
    Signals.MergeEggPrototypeBoardResult.OnClientEvent:Connect(function(result)
        if localPlayer:GetAttribute("InMergeEggPrototype") ~= true or type(result) ~= "table" then
            return
        end
        local success = result.ok == true
        boardActionFeedback.Text = boardActionResultCopy(result)
        boardActionFeedback.TextColor3 = success and Color3.fromRGB(190, 255, 205)
            or Color3.fromRGB(255, 205, 105)
        boardActionFeedbackStroke.Color = success and Color3.fromRGB(95, 230, 135)
            or Color3.fromRGB(245, 170, 60)
        boardActionFeedback.Visible = true
        boardActionFeedbackUntil = os.clock() + 2.5
    end)
    Signals.MergeEggPrototypePlayerHatch.OnClientEvent:Connect(function(result)
        if
            localPlayer:GetAttribute("InMergeEggPrototype") ~= true
            or type(result) ~= "table"
            or result.newIndexEntry ~= true
        then
            return
        end
        playerHatchRevealQueue[#playerHatchRevealQueue + 1] = result
        processPlayerHatchRevealQueue()
    end)
    Signals.MergeEggPrototypeModeNotice.OnClientEvent:Connect(function(notice)
        if localPlayer:GetAttribute("InMergeEggPrototype") ~= true then
            return
        end
        MergeDefenseModeNotice.show(notice, function(action)
            Signals.MergeEggPrototypeModeNoticeResponse:FireServer({ action = action })
        end)
    end)

    local panels = {}
    local teamDisplayFolder = nil
    local teamDisplayOwnedSlots = 0
    local boardWallControls = createBoardWallControls()

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            beginBoardDrag(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            finishBoardDrag(input)
        end
    end)

    local waveMeter = createWaveMeter(gui)
    local eggHealthBillboards = {}
    local lastWave = 0
    local announceUntil = 0
    local factor = tonumber(COMBAT.pet_down_threshold_factor) or 1
    local elapsed = 0
    local rotationElapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        local observing = localPlayer:GetAttribute("InMergeEggPrototype") == true
        if observing and tutorialPathTarget then
            updateTutorialPath(tutorialPathTarget)
        end
        if observing and tutorialClickTarget then
            updateTutorialClickChevron()
        end
        if tutorialClickCueTarget then
            updateTutorialClickCue()
        end
        if observing and tutorialFocusTarget and not boardDrag then
            updateTutorialEggFocus()
        elseif tutorialFocusVisual then
            destroyEggFocusVisual(tutorialFocusVisual)
            tutorialFocusVisual = nil
        end
        if boardActionFeedback.Visible and os.clock() >= boardActionFeedbackUntil then
            boardActionFeedback.Visible = false
        end
        if observing and boardDrag then
            updateBoardDrag()
        elseif not observing and boardDrag then
            destroyBoardDrag(boardDrag, true)
            boardDrag = nil
        end
        rotationElapsed += dt
        if observing and rotationElapsed >= 0.05 then
            rotateBoardEggs(rotationElapsed)
            rotationElapsed = 0
        elseif not observing then
            rotationElapsed = 0
        end
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0

        gui.Enabled = observing
        if not boardWallControls or not boardWallControls.world.Parent then
            boardWallControls = createBoardWallControls()
        end
        updateBoardWallControls(boardWallControls, observing)
        if not observing then
            updateTutorialCard(tutorialCard, nil, false)
            clearTutorialClickCue()
            waveMeter.frame.Visible = false
            destroyEggHealthBillboards(eggHealthBillboards)
            if teamDisplayFolder then
                destroyGroundTeamPanels(panels, teamDisplayFolder)
                teamDisplayFolder = nil
                teamDisplayOwnedSlots = 0
            end
            lastWave = 0
            announceUntil = 0
            return
        end

        local world = prototypeWorld()
        updateTutorialCard(tutorialCard, world, true)
        local tutorialBuyingEggs = tutorialBuyEggCueAllowed(world)
        local buyEggCard = boardWallControls
            and boardWallControls.board
            and boardWallControls.board.buttons
            and boardWallControls.board.buttons.buy_egg
        setTutorialClickCueTarget(tutorialBuyingEggs and buyEggCard and buyEggCard.button or nil)

        local ownedSlots = math.max(
            1,
            math.floor(tonumber(world and world:GetAttribute("OwnedHatcherSlots")) or 4)
        )
        if
            not teamDisplayFolder
            or not teamDisplayFolder.Parent
            or teamDisplayOwnedSlots ~= ownedSlots
        then
            if teamDisplayFolder then
                destroyGroundTeamPanels(panels, teamDisplayFolder)
            end
            panels, teamDisplayFolder = createGroundTeamPanels()
            panels = panels or {}
            teamDisplayOwnedSlots = ownedSlots
        end

        local folders = teamFolders()
        local wave, waveCount, state, activeEnemies, eggsRemaining, eggsStarting, queueDepth, peakQueueDepth, replacementsHatched, portalVisible, pendingEnemies, attackGroups, initializedHatchers, eggRolls, goldenRolls, rainbowRolls, hugeRolls, stageName, enemiesPastBreachLine, peakEnemiesPastBreachLine, breachOverrun, firstBreachWave, draftCandidateRolls =
            worldProgress()
        if wave > 0 and wave ~= lastWave then
            lastWave = wave
            announceUntil = os.clock() + 2.5
        elseif wave <= 0 then
            lastWave = 0
        end
        updateWaveMeter(
            waveMeter,
            wave,
            waveCount,
            state,
            activeEnemies,
            eggsRemaining,
            eggsStarting,
            queueDepth,
            peakQueueDepth,
            replacementsHatched,
            portalVisible,
            pendingEnemies,
            attackGroups,
            initializedHatchers,
            eggRolls,
            goldenRolls,
            rainbowRolls,
            hugeRolls,
            stageName,
            enemiesPastBreachLine,
            peakEnemiesPastBreachLine,
            breachOverrun,
            firstBreachWave,
            draftCandidateRolls,
            os.clock() < announceUntil
        )
        for id, panel in pairs(panels) do
            updatePanel(panel, folders[id], wave, waveCount, factor)
            updateEggHealthBillboard(eggHealthBillboards, id, folders[id])
        end
    end)
end

return MergeEggPrototypeObserver
