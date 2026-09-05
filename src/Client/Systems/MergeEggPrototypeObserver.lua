--[[
    MergeEggPrototypeObserver — Phase 6 combat, hatch telemetry, and world progression.

    The player's ordinary SquadHud remains reserved for their own deployable team. Nine floor-mounted
    SurfaceGuis sit on the player side of the hatcher eggs and render each NPC squad's tier, endurance,
    target, lifecycle, and wave progress without covering the management HUD. The wave bar sits in the
    Farm quest-pill chrome slot (upper-right) and camera-facing per-captain egg placement controls
    remain screen-readable. Crafted board eggs rotate locally while their inventory and placement
    remain server-authoritative.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HudCard = require(script.Parent.Parent.UI.HudCard)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local StatusBadges = require(script.Parent.Parent.UI.StatusBadges)
local WorldChevron = require(script.Parent.Parent.UI.WorldChevron)
local MergeBulwarkMenu = require(script.Parent.Parent.UI.Components.MergeBulwarkMenu)
local MergeCannonMenu = require(script.Parent.Parent.UI.Components.MergeCannonMenu)
local MergeDefenseModeNotice = require(script.Parent.Parent.UI.Components.MergeDefenseModeNotice)
local QuartermasterServicesMenu =
    require(script.Parent.Parent.UI.Components.QuartermasterServicesMenu)
local MergeEggCostFormat = require(ReplicatedStorage.Shared.Game.MergeEggCostFormat)
local MergeBulwarkModels = require(ReplicatedStorage.Shared.Game.MergeBulwarkModels)
local MergeTutorialHud = require(ReplicatedStorage.Shared.Game.MergeTutorialHud)
local MergeEggBoardTapPolicy = require(script.Parent.MergeEggBoardTapPolicy)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local EggHatchingService = require(ReplicatedStorage.Shared.Services.EggHatchingService)
local UIViewportScale = require(script.Parent.Parent.UI.UIViewportScale)

local CONFIG = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local COMBAT = require(ReplicatedStorage.Configs:WaitForChild("combat"))
local PET_ROLES = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
local PETS = require(ReplicatedStorage.Configs:WaitForChild("pets"))
local PLACES = require(ReplicatedStorage.Configs:WaitForChild("places"))
local EGG_HEALTH_BILLBOARD = assert(
    (CONFIG.ui or {}).egg_health_billboard,
    "merge_egg_prototype.ui.egg_health_billboard is required"
)
local TUTORIAL_CLICK_CUE =
    assert((CONFIG.tutorial or {}).click_cue, "merge_egg_prototype.tutorial.click_cue is required")
local TUTORIAL_CARD_LAYOUT = assert(
    (CONFIG.tutorial or {}).card_layout,
    "merge_egg_prototype.tutorial.card_layout is required"
)
local TUTORIAL_ACTIVITY_FEEDBACK = assert(
    (CONFIG.tutorial or {}).activity_feedback,
    "merge_egg_prototype.tutorial.activity_feedback is required"
)
local TUTORIAL_ACTIVITY_COPIES = assert(
    TUTORIAL_ACTIVITY_FEEDBACK.copies,
    "merge_egg_prototype.tutorial.activity_feedback.copies is required"
)
local TUTORIAL_ACTIVITY_DEFAULT_SECONDS = assert(
    tonumber(TUTORIAL_ACTIVITY_FEEDBACK.default_duration_seconds),
    "merge_egg_prototype.tutorial.activity_feedback.default_duration_seconds is required"
)
local TUTORIAL_EGG_UPGRADED_SECONDS = assert(
    tonumber(TUTORIAL_ACTIVITY_FEEDBACK.egg_upgrade_duration_seconds),
    "merge_egg_prototype.tutorial.activity_feedback.egg_upgrade_duration_seconds is required"
)
local TUTORIAL_ACTIVITY_MAXIMUM_QUEUE = assert(
    tonumber(TUTORIAL_ACTIVITY_FEEDBACK.maximum_queue),
    "merge_egg_prototype.tutorial.activity_feedback.maximum_queue is required"
)

local MergeEggPrototypeObserver = {}
MergeEggPrototypeObserver.MonetizationCatalog =
    require(ReplicatedStorage.Shared.Game.MonetizationCatalog)
MergeEggPrototypeObserver.GamePassPurchasePrompt =
    require(script.Parent.Parent.UI.Components.GamePassPurchasePrompt)
MergeEggPrototypeObserver.autoMergeConfig = assert(
    ((CONFIG.team or {}).merge_board or {}).auto_merge,
    "merge_egg_prototype.team.merge_board.auto_merge is required"
)
MergeEggPrototypeObserver.autoMergePassId = assert(
    MergeEggPrototypeObserver.autoMergeConfig.pass_id,
    "merge_egg_prototype.team.merge_board.auto_merge.pass_id is required"
)
MergeEggPrototypeObserver.autoMergeLabels = assert(
    MergeEggPrototypeObserver.autoMergeConfig.labels,
    "merge_egg_prototype.team.merge_board.auto_merge.labels is required"
)
MergeEggPrototypeObserver.autoMergeOwned = false

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
local STATUS_BADGE_GUTTER = 40
local STATUS_BADGE_BLINK_LEAD = tonumber((COMBAT.status_badges or {}).blink_lead_seconds) or 5
local STATUS_BADGE_BLINK_PERIOD = tonumber((COMBAT.status_badges or {}).blink_period_seconds) or 0.5
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
    auto_merge_pass_required = assert(
        MergeEggPrototypeObserver.autoMergeConfig.pass_required_copy,
        "merge_egg_prototype.team.merge_board.auto_merge.pass_required_copy is required"
    ),
    bulwark_locked = "BULWARK UNLOCKED AT ITS WAVE MILESTONE",
    bulwark_slot_rebirth_locked = "THIS BULWARK LINE UNLOCKS AT A LATER REBIRTH",
    bulwark_station_too_far = "MOVE CLOSER TO A BULWARK EDGE",
    bulwark_already_selected = "THAT BULWARK IS ALREADY INSTALLED",
    bulwark_already_unlocked = "THAT BULWARK IS ALREADY UNLOCKED",
    bulwark_not_owned = "BUY THAT BULWARK FIRST",
    bulwark_not_installed = "INSTALL A BULWARK FIRST",
    bulwark_maxed = "BULWARK IS ALREADY MAXIMUM TIER",
    cannon_locked = "ARTILLERY UNLOCKED AT ITS WAVE MILESTONE",
    cannon_slot_rebirth_locked = "THIS CANNON PAD UNLOCKS AT A LATER REBIRTH",
    cannon_station_too_far = "MOVE CLOSER TO THE ARTILLERY COMMANDER",
    cannon_already_selected = "THAT CANNON IS ALREADY INSTALLED",
    cannon_already_unlocked = "THAT CANNON IS ALREADY UNLOCKED",
    cannon_state_changed = "CANNON STATE CHANGED — TRY AGAIN",
    cannon_not_owned = "BUY THAT CANNON FIRST",
    cannon_not_installed = "INSTALL A CANNON FIRST",
    cannon_maxed = "CANNON IS ALREADY MAXIMUM TIER",
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
local TUTORIAL_WORKSHOP_ORDER = {
    collect_workshop_coins = 1,
    talk_engineer = 2,
    unlock_bulwark = 3,
    install_bulwark = 4,
}
local TUTORIAL_WORKSHOP_COUNT = 4
local TUTORIAL_CANNON_ORDER = {
    collect_cannon_coins = 1,
    collect_cannon_gem = 2,
    talk_commander = 3,
    unlock_cannon = 4,
    install_cannon = 5,
}
local TUTORIAL_CANNON_COUNT = 5
local TUTORIAL_UPGRADE_ORDER = {
    collect_upgrade_coins = 1,
    upgrade_eggs = 2,
}
local TUTORIAL_UPGRADE_COUNT = 2
local TUTORIAL_QUARTERMASTER_ORDER = {
    talk_quartermaster = 1,
}
local TUTORIAL_QUARTERMASTER_COUNT = 1
local TUTORIAL_FINAL_WAVE = assert(
    tonumber((CONFIG.tutorial or {}).pause_after_quartermaster_wave),
    "merge_egg_prototype.tutorial.pause_after_quartermaster_wave is required"
)
local TUTORIAL_HOTBAR_COVER_ATTRIBUTE = "MergeTutorialHotbarCovered"

local function layoutVector(spec, field)
    local value = assert(spec[field], ("tutorial.card_layout.%s is required"):format(field))
    return Vector2.new(
        assert(tonumber(value.x), ("tutorial.card_layout.%s.x is required"):format(field)),
        assert(tonumber(value.y), ("tutorial.card_layout.%s.y is required"):format(field))
    )
end

local function layoutSizeVector(spec, field)
    local value = assert(spec[field], ("tutorial.card_layout.%s is required"):format(field))
    return Vector2.new(
        assert(tonumber(value.width), ("tutorial.card_layout.%s.width is required"):format(field)),
        assert(tonumber(value.height), ("tutorial.card_layout.%s.height is required"):format(field))
    )
end

local function createTutorialCard(parent)
    local frame = Instance.new("Frame")
    frame.Name = "MergeEggTutorial"
    frame.AnchorPoint = Vector2.zero
    frame.Position = UDim2.fromScale(0.2, 0.78)
    frame.Size = UDim2.fromScale(0.6, 0.18)
    frame.BackgroundColor3 = Color3.fromRGB(24, 29, 40)
    frame.BackgroundTransparency = assert(
        tonumber(TUTORIAL_CARD_LAYOUT.background_transparency),
        "tutorial.card_layout.background_transparency is required"
    )
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 30
    frame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.09, 0)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 194, 62)
    stroke.Thickness = 3
    stroke.Parent = frame
    local progress = Instance.new("TextLabel")
    progress.Name = "Progress"
    progress.Position = UDim2.fromScale(0.035, 0.08)
    progress.Size = UDim2.fromScale(0.93, 0.17)
    progress.BackgroundTransparency = 1
    progress.Font = Enum.Font.GothamBold
    progress.Text = "MERGE DEFENSE TUTORIAL"
    progress.TextColor3 = Color3.fromRGB(255, 194, 62)
    progress.TextScaled = true
    progress.TextXAlignment = Enum.TextXAlignment.Left
    progress.ZIndex = 31
    progress.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromScale(0.035, 0.27)
    title.Size = UDim2.fromScale(0.93, 0.25)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.fromRGB(245, 248, 255)
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 31
    title.Parent = frame

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Position = UDim2.fromScale(0.035, 0.55)
    body.Size = UDim2.fromScale(0.93, 0.35)
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.GothamMedium
    body.TextColor3 = Color3.fromRGB(218, 226, 240)
    body.TextScaled = true
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.ZIndex = 31
    body.Parent = frame
    return {
        frame = frame,
        progress = progress,
        title = title,
        body = body,
    }
end

local function layoutResponsiveDockSurface(frame, aspect, sizeConstraint, displayOrder)
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    local hotbarGui = playerGui and playerGui:FindFirstChild("HotbarBar")
    local responsiveDock = hotbarGui and hotbarGui:FindFirstChild("ResponsiveDock")
    if not (hotbarGui and responsiveDock and responsiveDock:IsA("GuiObject")) then
        frame.Visible = false
        return false
    end

    local class = localPlayer:GetAttribute("HudLayoutResolved") == "compact" and "compact"
        or "classic"
    local relative = assert(
        TUTORIAL_CARD_LAYOUT.relative,
        "merge_egg_prototype.tutorial.card_layout.relative is required"
    )
    local spec = assert(relative[class], "tutorial card relative layout is required")
    local anchor = layoutVector(spec, "anchor")
    local position = layoutVector(spec, "position")
    local size = layoutVector(spec, "size")
    frame.Parent = responsiveDock
    frame.AnchorPoint = anchor
    frame.Position = UDim2.fromScale(position.X, position.Y)
    frame.Size = UDim2.fromScale(size.X, size.Y)
    aspect.AspectRatio = assert(
        tonumber(spec.aspect_ratio),
        "tutorial.card_layout.relative aspect_ratio is required"
    )
    local bounds = assert(
        TUTORIAL_CARD_LAYOUT.size_constraint,
        "merge_egg_prototype.tutorial.card_layout.size_constraint is required"
    )
    sizeConstraint.MinSize = layoutSizeVector(bounds, "minimum")
    sizeConstraint.MaxSize = layoutSizeVector(bounds, "maximum")
    hotbarGui.DisplayOrder = displayOrder
    return true
end

local function setHotbarDisplayOrder(displayOrder)
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    local hotbarGui = playerGui and playerGui:FindFirstChild("HotbarBar")
    if hotbarGui and hotbarGui:IsA("ScreenGui") then
        hotbarGui.DisplayOrder = displayOrder
    end
end

local function layoutTutorialCardOverHotbar(card)
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    local hotbarGui = playerGui and playerGui:FindFirstChild("HotbarBar")
    local greaterHotbar = hotbarGui and hotbarGui:FindFirstChild("GreaterHotbarFrame")
    local bar = greaterHotbar and greaterHotbar:FindFirstChild("Bar")
    local centralContent = bar and bar:FindFirstChild("CentralContent")
    local pillFrame = centralContent and centralContent:FindFirstChild("PillFrame")
    if not (hotbarGui and bar and pillFrame and pillFrame:IsA("GuiObject")) then
        card.frame.Visible = false
        return false
    end

    -- The tutorial replaces only the white pill. Copy its relative UDim contract, never its
    -- rendered pixel bounds; the outer hotbar scale then moves and resizes both surfaces together.
    card.frame.Parent = bar
    card.frame.AnchorPoint = pillFrame.AnchorPoint
    card.frame.Position = pillFrame.Position
    card.frame.Size = pillFrame.Size
    hotbarGui.DisplayOrder = assert(
        tonumber(TUTORIAL_CARD_LAYOUT.display_order),
        "tutorial.card_layout.display_order is required"
    )
    return true
end

local function setTutorialHotbarCovered(world, observing)
    local currentWave = world and world:GetAttribute("CurrentWave") or 0
    local tutorialRequired = world and world:GetAttribute("MergeEggTutorialRequired") == true
    local covered =
        MergeTutorialHud.coversHotbar(observing, currentWave, TUTORIAL_FINAL_WAVE, tutorialRequired)
    if localPlayer:GetAttribute(TUTORIAL_HOTBAR_COVER_ATTRIBUTE) ~= covered then
        localPlayer:SetAttribute(TUTORIAL_HOTBAR_COVER_ATTRIBUTE, covered)
    end
    return covered
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

local function tutorialClickCueScale()
    local scales = assert(
        TUTORIAL_CLICK_CUE.display_scale,
        "merge_egg_prototype.tutorial.click_cue.display_scale is required"
    )
    local displayClass = tostring(localPlayer:GetAttribute("DisplayClass") or "desktop")
    return assert(
        tonumber(scales[displayClass] or scales.desktop),
        "tutorial.click_cue display scale is required"
    )
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
    local displayScale = tutorialClickCueScale()
    local targetGap =
        assert(tonumber(TUTORIAL_CLICK_CUE.target_gap), "tutorial.click_cue.target_gap is required")

    -- Match the established tutorial callout: a pulsing gold target outline with a dark
    -- CLICK HERE pill and a downward pointer. Parenting it to the real SurfaceGui button keeps
    -- the cue exact at every camera distance instead of approximating the management wall center.
    local pulse = Instance.new("UIStroke")
    pulse.Name = "TutorialClickPulse"
    pulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pulse.Color = Color3.fromRGB(255, 215, 70)
    pulse.Thickness = assert(
        tonumber(TUTORIAL_CLICK_CUE.target_stroke_thickness),
        "tutorial.click_cue.target_stroke_thickness is required"
    ) * displayScale
    pulse.Transparency = 0.05
    pulse.ZIndex = 30
    pulse.Parent = target

    local callout = Instance.new("TextLabel")
    callout.Name = "MergeEggTutorialClickHere"
    callout.AnchorPoint = Vector2.new(0.5, 1)
    callout.Position = UDim2.new(0.5, 0, 0, -targetGap * displayScale)
    callout.Size = UDim2.fromOffset(
        assert(tonumber(TUTORIAL_CLICK_CUE.width), "tutorial.click_cue.width is required")
            * displayScale,
        assert(tonumber(TUTORIAL_CLICK_CUE.height), "tutorial.click_cue.height is required")
            * displayScale
    )
    callout.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
    callout.BackgroundTransparency = 0.08
    callout.BorderSizePixel = 0
    callout.Font = Enum.Font.GothamBlack
    callout.Text = "CLICK HERE\n\226\150\188"
    callout.TextColor3 = Color3.new(1, 1, 1)
    callout.TextSize = assert(
        tonumber(TUTORIAL_CLICK_CUE.text_size),
        "tutorial.click_cue.text_size is required"
    ) * displayScale
    callout.TextStrokeColor3 = Color3.new(0, 0, 0)
    callout.TextStrokeTransparency = 0.3
    callout.TextWrapped = true
    callout.ZIndex = 31
    callout:SetAttribute("TutorialClickCueScale", displayScale)
    callout.Parent = target

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(
        0,
        assert(
            tonumber(TUTORIAL_CLICK_CUE.corner_radius),
            "tutorial.click_cue.corner_radius is required"
        ) * displayScale
    )
    corner.Parent = callout

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 70)
    stroke.Thickness = assert(
        tonumber(TUTORIAL_CLICK_CUE.callout_stroke_thickness),
        "tutorial.click_cue.callout_stroke_thickness is required"
    ) * displayScale
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
    local displayScale = assert(
        tonumber(tutorialClickCue:GetAttribute("TutorialClickCueScale")),
        "TutorialClickCueScale is required"
    )
    local targetGap =
        assert(tonumber(TUTORIAL_CLICK_CUE.target_gap), "tutorial.click_cue.target_gap is required")
    local pulseTravel = assert(
        tonumber(TUTORIAL_CLICK_CUE.pulse_travel),
        "tutorial.click_cue.pulse_travel is required"
    )
    tutorialClickCue.Position =
        UDim2.new(0.5, 0, 0, -math.floor((targetGap + pulseTravel * phase) * displayScale))
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

local function openingDropPart(drop)
    return drop.PrimaryPart or drop:FindFirstChildWhichIsA("BasePart", true)
end

local function isOwnedOpeningDrop(drop, reason)
    return drop:IsA("Model")
        and tonumber(drop:GetAttribute("DropOwner")) == localPlayer.UserId
        and drop:GetAttribute("DropSource") == "merge_egg_prototype"
        and drop:GetAttribute("DropReason") == reason
end

local function nearestOwnedOpeningDrop(reason)
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    local drops = Workspace:FindFirstChild("CoinDrops")
    local nearest
    local nearestDistance = math.huge
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if isOwnedOpeningDrop(drop, reason) then
            local part = openingDropPart(drop)
            local distance = root and part and (part.Position - root.Position).Magnitude
                or math.huge
            if distance < nearestDistance then
                nearest = part
                nearestDistance = distance
            end
        end
    end
    return nearest
end

local function openingDropCounts()
    local drops = Workspace:FindFirstChild("CoinDrops")
    local coins = 0
    local gems = 0
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if isOwnedOpeningDrop(drop, "opening") then
            coins += 1
        elseif isOwnedOpeningDrop(drop, "opening_gem") then
            gems += 1
        end
    end
    return coins, gems
end

-- Closest remaining Waycoin stack first. The gem is a second walk, skipped
-- when that drop is already gone.
local function openingCollectTarget()
    return nearestOwnedOpeningDrop("opening") or nearestOwnedOpeningDrop("opening_gem")
end

local function cannonGemCollectTarget()
    return nearestOwnedOpeningDrop("cannon_gem")
end

local function nearestOwnedWaycoinDrop()
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    local drops = Workspace:FindFirstChild("CoinDrops")
    local nearest
    local nearestDistance = math.huge
    for _, drop in ipairs(drops and drops:GetChildren() or {}) do
        if
            drop:IsA("Model")
            and tonumber(drop:GetAttribute("DropOwner")) == localPlayer.UserId
            and drop:GetAttribute("DropSource") == "merge_egg_prototype"
            and drop:GetAttribute("DropCurrency") == "hall_coins"
        then
            local part = openingDropPart(drop)
            local distance = root and part and (part.Position - root.Position).Magnitude
                or math.huge
            if distance < nearestDistance then
                nearest = part
                nearestDistance = distance
            end
        end
    end
    return nearest
end

local function tutorialTarget(world, targetKind)
    if targetKind == "coins" then
        return openingCollectTarget()
    elseif targetKind == "stage_coins" then
        return nearestOwnedWaycoinDrop()
    elseif targetKind == "buy_egg" then
        local host = world
            and world:FindFirstChild(
                (CONFIG.world or {}).egg_merge_control or "EggMergeControl",
                true
            )
        if host and host:IsA("BasePart") then
            -- BUY EGG is the lower half of the large left action panel. Front-face SurfaceGui X
            -- runs opposite local X from the player side, so the visual-left panel lives at +X.
            return host.CFrame:PointToWorldSpace(
                Vector3.new(host.Size.X * 0.34, -host.Size.Y * 0.25, -host.Size.Z / 2 - 0.2)
            )
        end
        return host
    elseif targetKind == "equip_best" then
        return world and world:FindFirstChild(CONFIG.world.equip_best_control, true)
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
    elseif targetKind == "engineer" then
        local slot = tostring((CONFIG.tutorial or {}).workshop_slot or "lane")
        local folder = world and world:FindFirstChild("MergeEggBulwarks")
        local named = folder and folder:FindFirstChild("MergeBulwarkEngineer_" .. slot)
        if named and named:GetAttribute("MergeVendorPosted") == true then
            return named
        end
        for _, child in ipairs(folder and folder:GetChildren() or {}) do
            if
                child:GetAttribute("MergeBulwarkEngineer") == true
                and tostring(child:GetAttribute("MergeBulwarkSlot") or "") == slot
                and child:GetAttribute("MergeVendorPosted") == true
            then
                return child
            end
        end
        local stand = world and world:GetAttribute("MergeEggTutorialEngineerAt")
        if typeof(stand) == "Vector3" then
            return stand
        end
        return nil
    elseif targetKind == "upgrade_coins" then
        return nearestOwnedWaycoinDrop()
    elseif targetKind == "cannon_gem" then
        return cannonGemCollectTarget()
    elseif targetKind == "commander" then
        local slot = tostring((CONFIG.tutorial or {}).workshop_cannon_slot or "right")
        local folder = world and world:FindFirstChild("MergeEggTowers")
        local named = folder and folder:FindFirstChild("MergeArtilleryCommander_" .. slot)
        if named and named:GetAttribute("MergeVendorPosted") == true then
            return named
        end
        for _, child in ipairs(folder and folder:GetChildren() or {}) do
            if
                child:GetAttribute("MergeArtilleryCommander") == true
                and tostring(child:GetAttribute("MergeTowerSlot") or "") == slot
                and child:GetAttribute("MergeVendorPosted") == true
            then
                return child
            end
        end
        local stand = world and world:GetAttribute("MergeEggTutorialCommanderAt")
        if typeof(stand) == "Vector3" then
            return stand
        end
        return nil
    elseif targetKind == "quartermaster" then
        local folder = world and world:FindFirstChild("MergeEggQuartermaster")
        local named = folder and folder:FindFirstChild("MergeQuartermaster")
        if named and named:GetAttribute("MergeVendorPosted") == true then
            return named
        end
        for _, child in ipairs(folder and folder:GetChildren() or {}) do
            if
                child:GetAttribute("MergeQuartermaster") == true
                and child:GetAttribute("MergeVendorPosted") == true
            then
                return child
            end
        end
        local stand = world and world:GetAttribute("MergeEggTutorialQuartermasterAt")
        if typeof(stand) == "Vector3" then
            return stand
        end
        return nil
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
    if not world or world:GetAttribute("MergeEggTutorialActive") ~= true then
        return false
    end
    local step = tostring(world:GetAttribute("MergeEggTutorialStep") or "")
    local tutorial = type(CONFIG.tutorial) == "table" and CONFIG.tutorial or {}
    local rebirthCount =
        math.max(0, math.floor(tonumber(world:GetAttribute("MergeDefenseRebirthCount")) or 0))
    if tutorial.disable_after_rebirth == true and rebirthCount > 0 then
        return false
    end
    if step == "upgrade_eggs" then
        local created = math.max(
            0,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialUpgradeCreated")) or 0)
        )
        local need = math.max(
            1,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialUpgradeCreateNeed")) or 2)
        )
        return created < need
    end
    if step ~= "create_five" then
        return false
    end
    local cuePurchaseCount =
        math.max(0, math.floor(tonumber(tutorial.click_cue_purchase_count) or 3))
    local eggsCreated =
        math.max(0, math.floor(tonumber(world:GetAttribute("MergeEggTutorialEggsCreated")) or 0))
    return eggsCreated < cuePurchaseCount
end

local function updateTutorialCard(card, world, observing, bulwarkMenu, cannonMenu)
    local tutorial = type(CONFIG.tutorial) == "table" and CONFIG.tutorial or {}
    local active = observing and world and world:GetAttribute("MergeEggTutorialActive") == true
    local step = active and tostring(world:GetAttribute("MergeEggTutorialStep") or "") or ""
    local spec = type(tutorial.steps) == "table" and tutorial.steps[step] or nil
    if not (active and type(spec) == "table") then
        clearTutorialEggFocus()
        clearTutorialClickChevron()
        local autoCollector = world
            and world:GetAttribute("MergeEggTutorialUsesAutoCollector") == true
        local drop = not autoCollector and openingCollectTarget() or nil
        if drop then
            tutorialPathTarget = drop
            updateTutorialPath(drop)
        else
            tutorialPathTarget = nil
            clearTutorialPath()
        end
        local combatSpec = localPlayer:GetAttribute(TUTORIAL_HOTBAR_COVER_ATTRIBUTE) == true
                and MergeTutorialHud.combatCard(
                    tutorial,
                    world and world:GetAttribute("CurrentWave")
                )
            or nil
        if type(combatSpec) == "table" then
            card.frame.Visible = true
            card.progress.Text = tostring(combatSpec.progress or "MERGE DEFENSE TUTORIAL")
            card.title.Text = tostring(combatSpec.title or "DEFEND THE HATCHERS")
            card.body.Text = tostring(combatSpec.body or "Hold the line until the next lesson.")
        else
            card.frame.Visible = false
        end
        return
    end
    local autoCollector = world:GetAttribute("MergeEggTutorialUsesAutoCollector") == true
    card.frame.Visible = true
    local workshopOrder = TUTORIAL_WORKSHOP_ORDER[step]
    local cannonOrder = TUTORIAL_CANNON_ORDER[step]
    local upgradeOrder = TUTORIAL_UPGRADE_ORDER[step]
    local quartermasterOrder = TUTORIAL_QUARTERMASTER_ORDER[step]
    card.progress.Text = workshopOrder
            and string.format(
                "BULWARK TUTORIAL  •  %d / %d",
                workshopOrder,
                TUTORIAL_WORKSHOP_COUNT
            )
        or cannonOrder and string.format(
            "CANNON TUTORIAL  •  %d / %d",
            cannonOrder,
            TUTORIAL_CANNON_COUNT
        )
        or upgradeOrder and string.format(
            "EGG UPGRADES  •  %d / %d",
            upgradeOrder,
            TUTORIAL_UPGRADE_COUNT
        )
        or quartermasterOrder and string.format(
            "QUARTERMASTER  •  %d / %d",
            quartermasterOrder,
            TUTORIAL_QUARTERMASTER_COUNT
        )
        or string.format(
            "MERGE DEFENSE TUTORIAL  •  %d / %d",
            TUTORIAL_STEP_ORDER[step] or 1,
            TUTORIAL_STEP_COUNT
        )
    card.title.Text = tostring(spec.title or "MERGE DEFENSE")
    card.body.Text = tostring(autoCollector and spec.auto_body or spec.body or "")
    if step == "collect_setup" and not autoCollector then
        local coinsLeft, gemsLeft = openingDropCounts()
        if coinsLeft > 0 then
            card.title.Text = string.format(
                "PICK UP %d MORE WAYCOIN STACK%s",
                coinsLeft,
                coinsLeft == 1 and "" or "S"
            )
            card.body.Text = "Follow the chevrons to the closest stack."
        elseif gemsLeft > 0 then
            card.title.Text = "NOW PICK UP THE GEM"
            card.body.Text =
                "Follow the chevrons to the gem in front of the second Bulwark Engineer."
        end
    end
    if step == "collect_upgrade_coins" and not autoCollector then
        local target = math.max(
            1,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialUpgradeCoinTarget")) or 600)
        )
        local wallet = math.max(
            0,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialUpgradeWallet")) or 0)
        )
        local remaining = math.max(0, target - wallet)
        if remaining > 0 then
            card.title.Text = string.format("PICK UP %d MORE WAYCOINS", remaining)
            card.body.Text =
                "Follow the chevrons to coins on the field. About 600 is enough for six eggs."
        end
    end
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
            or "FIVE EARTH EGGS CREATED"
        card.body.Text = "Click the highlighted BUY EGG button again."
    end
    if step == "upgrade_eggs" then
        local created = math.max(
            0,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialUpgradeCreated")) or 0)
        )
        local need = math.max(
            1,
            math.floor(tonumber(world:GetAttribute("MergeEggTutorialUpgradeCreateNeed")) or 2)
        )
        local remaining = math.max(0, need - created)
        if remaining > 0 then
            card.title.Text = remaining == 1 and "CREATE ONE MORE EGG"
                or string.format("CREATE %d MORE EGGS", remaining)
            card.body.Text = "Click BUY EGG. Then upgrade one or place one on the line."
        else
            card.title.Text = "UPGRADE OR PLACE ONE"
            card.body.Text = "Merge two matching eggs, or drag one onto the line."
        end
    end
    local targetKind = tostring(spec.target or "none")
    if step == "upgrade_eggs" and not tutorialBuyEggCueAllowed(world) then
        targetKind = "board_egg"
    end
    local menuOpen = bulwarkMenu and bulwarkMenu.isOpen and bulwarkMenu:isOpen() == true
    local cannonMenuOpen = cannonMenu and cannonMenu.isOpen and cannonMenu:isOpen() == true
    if autoCollector and targetKind == "coins" then
        tutorialPathTarget = nil
        tutorialFocusTarget = nil
        clearTutorialPath()
        clearTutorialEggFocus()
        clearTutorialClickChevron()
    elseif (targetKind == "bulwark_unlock" or targetKind == "bulwark_install") and menuOpen then
        tutorialPathTarget = nil
        tutorialClickTarget = nil
        tutorialFocusTarget = nil
        clearTutorialPath()
        clearTutorialEggFocus()
        clearTutorialClickChevron()
        local cueKind = targetKind == "bulwark_unlock" and "unlock" or "install"
        setTutorialClickCueTarget(bulwarkMenu:tutorialCueButton(cueKind))
    elseif (targetKind == "cannon_unlock" or targetKind == "cannon_install") and cannonMenuOpen then
        tutorialPathTarget = nil
        tutorialClickTarget = nil
        tutorialFocusTarget = nil
        clearTutorialPath()
        clearTutorialEggFocus()
        clearTutorialClickChevron()
        local cueKind = targetKind == "cannon_unlock" and "unlock" or "install"
        setTutorialClickCueTarget(cannonMenu:tutorialCueButton(cueKind))
    else
        if targetKind == "bulwark_unlock" or targetKind == "bulwark_install" then
            targetKind = "engineer"
        end
        if targetKind == "cannon_unlock" or targetKind == "cannon_install" then
            targetKind = "commander"
        end
        tutorialPathTarget = tutorialTarget(world, targetKind)
        tutorialClickTarget = (
            (targetKind == "buy_egg" and tutorialBuyEggCueAllowed(world))
            or targetKind == "equip_best"
            or targetKind == "engineer"
            or targetKind == "commander"
            or targetKind == "quartermaster"
        )
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

local function tutorialActivityCopy(copyId, ...)
    local template = assert(
        TUTORIAL_ACTIVITY_COPIES[copyId],
        string.format(
            "merge_egg_prototype.tutorial.activity_feedback.copies.%s is required",
            copyId
        )
    )
    return string.format(tostring(template), ...)
end

local function createBoardActionFeedback(parent)
    local label = Instance.new("TextLabel")
    label.Name = "BoardActionFeedback"
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.72)
    label.Size = UDim2.new(0.9, 0, 0, 64)
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
    -- Feedback is presentation only. Roblox's Interactable property defaults true even on
    -- TextLabels; explicitly disabling both input flags prevents this full-width surface from
    -- swallowing the workshop button underneath it.
    label.Active = false
    label.Interactable = false
    label.Parent = parent
    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MinSize = Vector2.new(240, 56)
    sizeConstraint.MaxSize = Vector2.new(520, 64)
    sizeConstraint.Parent = label
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.Name = "ResponsiveAspect"
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = label
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = label
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(95, 230, 135)
    stroke.Thickness = 3
    stroke.Parent = label
    return label, stroke, sizeConstraint, aspect
end

local function layoutBoardActionFeedback(label, sizeConstraint, aspect, belowWorkshop)
    -- Unlocking immediately repaints the open workshop with its enabled Install action. Keep that
    -- duplicate celebration below the menu until it closes, so neither the label nor the shared
    -- HotbarBar ScreenGui can cover Install. Failures still use feedback_display_order above the
    -- workshop because their refusal copy must remain readable.
    local displayOrder = belowWorkshop and TUTORIAL_CARD_LAYOUT.display_order
        or TUTORIAL_CARD_LAYOUT.feedback_display_order
    layoutResponsiveDockSurface(
        label,
        aspect,
        sizeConstraint,
        assert(
            tonumber(displayOrder),
            belowWorkshop and "tutorial.card_layout.display_order is required"
                or "tutorial.card_layout.feedback_display_order is required"
        )
    )
end

local function unlockFeedbackBehindOpenWorkshop(item, bulwarkMenu, cannonMenu)
    if type(item) ~= "table" or item.success ~= true then
        return false
    end
    local key = tostring(item.key or "")
    return (key:find("bulwark_unlocked:", 1, true) == 1 and bulwarkMenu and bulwarkMenu:isOpen())
        or (key:find("cannon_unlocked:", 1, true) == 1 and cannonMenu and cannonMenu:isOpen())
end

local function boardActionFailureCopy(result)
    local reason = tostring(result.reason or "action_refused")
    return BOARD_ACTION_FAILURE_COPY[reason] or string.upper(reason:gsub("_", " "))
end

local function ordinal(value)
    local numeric = tonumber(value)
    if not numeric then
        return tostring(value)
    end
    local whole = math.max(0, math.floor(numeric))
    local finalTwo = whole % 100
    local suffix = "TH"
    if finalTwo < 11 or finalTwo > 13 then
        local final = whole % 10
        suffix = final == 1 and "ST" or final == 2 and "ND" or final == 3 and "RD" or "TH"
    end
    return tostring(whole) .. suffix
end

local function milestoneResultFeedback(value)
    local milestone = tostring(value.milestone or "")
    local eggName = string.upper(tostring(value.eggName or "EGG"))
    if milestone == "egg_created" then
        return "egg_created:" .. tostring(value.toTier or value.eggTier or eggName),
            tutorialActivityCopy("egg_created", eggName)
    elseif milestone == "generator_unlocked" then
        return "generator_unlocked:" .. tostring(value.toTier or eggName),
            tutorialActivityCopy("generator_unlocked", eggName)
    elseif milestone == "bulwark_unlocked" then
        return "bulwark_unlocked:" .. tostring(value.family or "bulwark"),
            tutorialActivityCopy("bulwark_unlocked")
    elseif milestone == "cannon_unlocked" then
        return "cannon_unlocked:" .. tostring(value.family or value.leftFamily or "cannon"),
            tutorialActivityCopy("cannon_unlocked")
    elseif milestone == "quartermaster_ready" then
        return "quartermaster_ready", tutorialActivityCopy("quartermaster_ready")
    end
    return nil, nil
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

-- Saw Blade bulwarks are anchored presentation rigs. Animate their independently pivoted rotors
-- locally so a ten-tile line never spends server replication budget on sixty-per-second CFrames.
-- Only the active player's bay is scanned; no Workspace-wide mechanism loop is allowed here.
local sawBladeRigs = {}
local landSharkRigs = {}
local sawBladeScanElapsed = 0
local SAW_BLADE_SPIN_MULT = 2
local sawShredSeen = {}
local FLESH_CHIP_COLORS = {
    Color3.fromRGB(196, 78, 72),
    Color3.fromRGB(232, 176, 118),
    Color3.fromRGB(240, 214, 186),
}

local function collectShredColors(model)
    local colors = { FLESH_CHIP_COLORS[1], FLESH_CHIP_COLORS[2] }
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Transparency < 0.85 then
            colors[#colors + 1] = desc.Color
        end
    end
    return colors
end

local function shredBitsFolder()
    local folder = Workspace:FindFirstChild("MergeSawShredBits")
    if folder then
        return folder
    end
    folder = Instance.new("Folder")
    folder.Name = "MergeSawShredBits"
    folder.Parent = Workspace
    return folder
end

-- Tiny local cubes, colored from the chewed model plus a couple flesh chips so a dark mesh
-- still reads as body bits. Client-only so a rapid shred line does not replicate debris.
local function spraySawShredChunks(model, count)
    local origin = model:GetAttribute("MoveTarget")
    if typeof(origin) ~= "Vector3" then
        origin = model:GetPivot().Position
    end
    local colors = collectShredColors(model)
    local folder = shredBitsFolder()
    count = math.clamp(math.floor(tonumber(count) or 7), 4, 14)
    for _ = 1, count do
        local size = 0.14 + math.random() * 0.16
        local bit = Instance.new("Part")
        bit.Name = "MergeSawShredBit"
        bit.Shape = Enum.PartType.Block
        bit.Anchored = false
        bit.CanCollide = false
        bit.CanQuery = false
        bit.CanTouch = false
        bit.Massless = true
        bit.CastShadow = false
        bit.Material = Enum.Material.SmoothPlastic
        bit.Color = colors[math.random(1, #colors)]
        bit.Size = Vector3.new(size, size, size)
        bit.CFrame = CFrame.new(
            origin
                + Vector3.new(
                    (math.random() - 0.5) * 1.4,
                    0.55 + math.random() * 0.9,
                    (math.random() - 0.5) * 1.4
                )
        ) * CFrame.Angles(
            math.random() * math.pi,
            math.random() * math.pi,
            math.random() * math.pi
        )
        bit.AssemblyLinearVelocity = Vector3.new(
            (math.random() - 0.5) * 30,
            12 + math.random() * 20,
            (math.random() - 0.5) * 30
        )
        bit.AssemblyAngularVelocity = Vector3.new(
            (math.random() - 0.5) * 26,
            (math.random() - 0.5) * 26,
            (math.random() - 0.5) * 26
        )
        bit.Parent = folder
        Debris:AddItem(bit, 0.4 + math.random() * 0.22)
    end
end

local function pulseSawShredModel(model)
    if not (model and model:IsA("Model")) then
        return
    end
    local pulse = tonumber(model:GetAttribute("MergeSawShredPulse")) or 0
    local seen = sawShredSeen[model] or 0
    if pulse > seen then
        sawShredSeen[model] = pulse
        spraySawShredChunks(model, model:GetAttribute("MergeSawShredChunks"))
    elseif pulse <= 0 and seen > 0 then
        sawShredSeen[model] = nil
    end
end

local function updateSawShredChunks(observing)
    if not observing then
        for model in pairs(sawShredSeen) do
            sawShredSeen[model] = nil
        end
        return
    end
    local gameFolder = Workspace:FindFirstChild("Game")
    local enemies = gameFolder and gameFolder:FindFirstChild("Enemies")
    for _, model in ipairs(enemies and enemies:GetChildren() or {}) do
        pulseSawShredModel(model)
    end
    -- Pets use the same pulse if they ever take a shred tick, so chips can be body bits of
    -- either side without a second VFX path.
    local pets = gameFolder and gameFolder:FindFirstChild("Pets")
    for _, model in ipairs(pets and pets:GetChildren() or {}) do
        pulseSawShredModel(model)
    end
    for model in pairs(sawShredSeen) do
        if not model.Parent then
            sawShredSeen[model] = nil
        end
    end
end

local function sawBladeRotation(axis, angle)
    if axis == "X" then
        return CFrame.Angles(angle, 0, 0)
    elseif axis == "Y" then
        return CFrame.Angles(0, angle, 0)
    end
    return CFrame.Angles(0, 0, angle)
end

local function registerSawBladeRig(model)
    local blades = {}
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") and string.match(descendant.Name, "^Blade%d+$") then
            blades[#blades + 1] = {
                part = descendant,
                startCFrame = descendant.CFrame,
                axis = tostring(
                    descendant:GetAttribute("RotationAxis")
                        or model:GetAttribute("RotationAxis")
                        or "Z"
                ),
                direction = tonumber(descendant:GetAttribute("RotationDirection")) or 1,
            }
        end
    end
    if #blades > 0 then
        -- Authored deck speeds stay 180 / 360 (T2 and T4 already twice T1 / T3). Presentation
        -- is 2× that so the line actually reads as a chew. Each tile starts at a random
        -- phase so ten identical rotors do not lockstep.
        local startAngle = math.random() * math.pi * 2
        local speedDegrees = math.max(
            0,
            tonumber(model:GetAttribute("SawBladeSpeedDegrees"))
                or tonumber(model:GetAttribute("PreviewSpeedDegrees"))
                or 180
        ) * SAW_BLADE_SPIN_MULT
        sawBladeRigs[model] = {
            model = model,
            blades = blades,
            angle = startAngle,
            speedDegrees = speedDegrees,
        }
        for _, blade in ipairs(blades) do
            if blade.part.Parent then
                blade.part.CFrame = blade.startCFrame
                    * sawBladeRotation(blade.axis, startAngle * blade.direction)
            end
        end
    end
end

local function planarUnit(value, fallback)
    if typeof(value) ~= "Vector3" then
        return fallback
    end
    local flat = Vector3.new(value.X, 0, value.Z)
    if flat.Magnitude < 0.001 then
        return fallback
    end
    return flat.Unit
end

local function inferLandSharkField(model, along)
    local folder = model.Parent
    local bay = folder and folder.Parent
    if not (bay and along) then
        return nil
    end
    local bayId = bay:GetAttribute("MergeEggBayId")
    local roots = { bay }
    local map = Workspace:FindFirstChild("GeneratedMap_MergeEggVoxel")
    local stations = map and map:FindFirstChild("BulwarkStations")
    if stations then
        roots[#roots + 1] = stations
    end
    local minDot, maxDot = math.huge, -math.huge
    local acc = Vector3.zero
    local count = 0
    local look = nil
    local tile = 9.4
    for _, root in ipairs(roots) do
        for _, descendant in ipairs(root:GetDescendants()) do
            if
                descendant:IsA("BasePart")
                and string.match(descendant.Name, "^BulwarkAnchor_%d+$")
                and (bayId == nil or descendant:GetAttribute("MergeEggBayId") == bayId)
            then
                local position = descendant.Position
                local dot = position:Dot(along)
                minDot = math.min(minDot, dot)
                maxDot = math.max(maxDot, dot)
                acc += Vector3.new(position.X, 0, position.Z)
                count += 1
                look = look
                    or Vector3.new(
                        descendant.CFrame.LookVector.X,
                        0,
                        descendant.CFrame.LookVector.Z
                    )
                tile = tonumber(descendant:GetAttribute("MergeBulwarkTileLength")) or tile
            end
        end
        if count >= 2 then
            break
        end
    end
    if count < 2 then
        return nil
    end
    local depth = planarUnit(look, Vector3.new(-along.Z, 0, along.X))
    depth = planarUnit(depth - along * depth:Dot(along), Vector3.new(-along.Z, 0, along.X))
    return {
        center = acc / count,
        depth = depth,
        width = math.max(24, (maxDot - minDot) + tile - 16),
        depthStuds = 7,
    }
end

local function landSharkWander(time, phase, seed)
    local along = math.sin(time * 0.23 + phase * 6.1 + seed) * 0.56
        + math.sin(time * 0.39 + phase * 3.7 + seed * 1.8) * 0.29
        + math.sin(time * 0.61 + phase * 2.2 + seed * 0.7) * 0.15
    local depth = math.sin(time * 0.31 + phase * 5.4 + seed * 1.3) * 0.67
        + math.sin(time * 0.54 + phase * 2.9 + seed * 0.4) * 0.33
    return along, depth
end

local function requiredLandSharkNumber(model, attribute)
    local value = tonumber(model:GetAttribute(attribute))
    assert(value ~= nil, "Missing Land Shark tuning attribute: " .. attribute)
    return value
end

local function registerLandSharkRig(model)
    local direction =
        planarUnit(model:GetAttribute("MergeLandSharkTrackDirection"), Vector3.new(1, 0, 0))
    local field = inferLandSharkField(model, direction)
    local center = model:GetAttribute("MergeLandSharkFieldCenter")
    if typeof(center) ~= "Vector3" then
        center = field and field.center or model:GetPivot().Position
    end
    local depth = planarUnit(
        model:GetAttribute("MergeLandSharkDepthDirection"),
        field and field.depth or Vector3.new(-direction.Z, 0, direction.X)
    )
    local pivotY = model:GetPivot().Position.Y
    landSharkRigs[model] = {
        model = model,
        baseCFrame = model:GetPivot(),
        center = Vector3.new(center.X, pivotY, center.Z),
        direction = direction,
        depth = depth,
        halfWidth = requiredLandSharkNumber(model, "MergeLandSharkFieldWidth") * 0.5,
        halfDepth = requiredLandSharkNumber(model, "MergeLandSharkFieldDepth") * 0.5,
        seed = tonumber(model:GetAttribute("MergeLandSharkPatrolIndex")) or 1,
        trackStuds = requiredLandSharkNumber(model, "MergeLandSharkTrackStuds"),
        speedStuds = requiredLandSharkNumber(model, "MergeLandSharkSpeedStuds"),
        tempoDivisor = requiredLandSharkNumber(model, "MergeLandSharkTempoDivisor"),
        chaseSpeedStuds = requiredLandSharkNumber(model, "MergeLandSharkChaseSpeedStuds"),
        dragSpeedStuds = requiredLandSharkNumber(model, "MergeLandSharkDragSpeedStuds"),
        returnSpeedStuds = requiredLandSharkNumber(model, "MergeLandSharkReturnSpeedStuds"),
        huntBlendRate = requiredLandSharkNumber(model, "MergeLandSharkHuntBlendRate"),
        sampleLeadSeconds = requiredLandSharkNumber(model, "MergeLandSharkSampleLeadSeconds"),
        proximityPollSeconds = requiredLandSharkNumber(model, "MergeLandSharkProximityPollSeconds"),
        surfaceDistance = requiredLandSharkNumber(model, "MergeLandSharkSurfaceDistance"),
        surfaceRise = requiredLandSharkNumber(model, "MergeLandSharkSurfaceRise"),
        bitePeriod = requiredLandSharkNumber(model, "MergeLandSharkBitePeriodSeconds"),
        phase = tonumber(model:GetAttribute("MergeLandSharkPhase")) or 0,
        breachPeriod = requiredLandSharkNumber(model, "MergeLandSharkBreachPeriodSeconds"),
        breachDuration = requiredLandSharkNumber(model, "MergeLandSharkBreachDurationSeconds"),
        breachRise = requiredLandSharkNumber(model, "MergeLandSharkBreachRiseStuds"),
        breachPitch = math.rad(requiredLandSharkNumber(model, "MergeLandSharkBreachPitchDegrees")),
        surfaced = 0,
        proximityElapsed = 0,
        nearestEnemy = math.huge,
    }
end

local function nearestEnemyDistance(position)
    local gameFolder = Workspace:FindFirstChild("Game")
    local enemies = gameFolder and gameFolder:FindFirstChild("Enemies")
    local nearest = math.huge
    for _, enemy in ipairs(enemies and enemies:GetChildren() or {}) do
        if enemy:IsA("Model") then
            local enemyPosition = enemy:GetPivot().Position
            local planar =
                Vector3.new(enemyPosition.X - position.X, 0, enemyPosition.Z - position.Z)
            nearest = math.min(nearest, planar.Magnitude)
        end
    end
    return nearest
end

local function enemyByTargetId(targetId)
    targetId = tonumber(targetId)
    if not targetId then
        return nil
    end
    local gameFolder = Workspace:FindFirstChild("Game")
    local enemies = gameFolder and gameFolder:FindFirstChild("Enemies")
    for _, enemy in ipairs(enemies and enemies:GetChildren() or {}) do
        local id = enemy:FindFirstChild("BreakableID")
        if id and tonumber(id.Value) == targetId then
            return enemy
        end
    end
    return nil
end

local function updateLandSharkRigs(dt)
    local now = os.clock()
    for model, rig in pairs(landSharkRigs) do
        if not model.Parent then
            landSharkRigs[model] = nil
        else
            local tempo = rig.speedStuds / rig.tempoDivisor
            local along, across = landSharkWander(now * tempo, rig.phase, rig.seed)
            local nextAlong, nextAcross =
                landSharkWander(now * tempo + rig.sampleLeadSeconds, rig.phase, rig.seed)
            local patrolPosition = rig.center
                + rig.direction * (along * rig.halfWidth)
                + rig.depth * (across * rig.halfDepth)
            local ahead = rig.center
                + rig.direction * (nextAlong * rig.halfWidth)
                + rig.depth * (nextAcross * rig.halfDepth)
            local patrolHeading = ahead - patrolPosition
            if patrolHeading.Magnitude < 0.05 then
                patrolHeading = rig.lastHeading or rig.direction
            else
                patrolHeading = Vector3.new(patrolHeading.X, 0, patrolHeading.Z)
                if patrolHeading.Magnitude < 0.001 then
                    patrolHeading = rig.lastHeading or rig.direction
                else
                    patrolHeading = patrolHeading.Unit
                    rig.lastHeading = patrolHeading
                end
            end
            local huntAim = model:GetAttribute("MergeLandSharkHuntAim")
            local huntState = tostring(model:GetAttribute("MergeLandSharkHuntState") or "")
            local huntEnemy = enemyByTargetId(model:GetAttribute("MergeLandSharkHuntTargetId"))
            if huntEnemy then
                huntAim = huntEnemy:GetPivot().Position
            end
            local hunting = typeof(huntAim) == "Vector3"
            rig.huntBlend = rig.huntBlend or 0
            rig.huntBlend += ((hunting and 1 or 0) - rig.huntBlend) * math.min(
                1,
                dt * rig.huntBlendRate
            )
            if hunting then
                if typeof(rig.huntPos) ~= "Vector3" then
                    rig.huntPos = patrolPosition
                end
                local dest = Vector3.new(huntAim.X, rig.center.Y, huntAim.Z)
                local chaseSpeed = if huntState == "drag"
                    then rig.dragSpeedStuds
                    else rig.chaseSpeedStuds
                local to = dest - rig.huntPos
                if to.Magnitude > 0.05 then
                    rig.huntPos += to.Unit * math.min(to.Magnitude, chaseSpeed * dt)
                    local huntHeading = Vector3.new(to.X, 0, to.Z)
                    if huntHeading.Magnitude > 0.05 then
                        rig.lastHeading = huntHeading.Unit
                    end
                end
            elseif typeof(rig.huntPos) == "Vector3" then
                local back = patrolPosition - rig.huntPos
                if back.Magnitude <= 0.4 then
                    rig.huntPos = nil
                else
                    rig.huntPos += back.Unit * math.min(back.Magnitude, rig.returnSpeedStuds * dt)
                end
            end
            local position = patrolPosition
            local heading = patrolHeading
            if (rig.huntBlend > 0.02) and typeof(rig.huntPos) == "Vector3" then
                position = patrolPosition:Lerp(rig.huntPos, rig.huntBlend)
                heading = rig.lastHeading or patrolHeading
            end
            local patrolCFrame = CFrame.lookAt(position, position + heading, Vector3.yAxis)
            rig.proximityElapsed -= dt
            if rig.proximityElapsed <= 0 then
                rig.proximityElapsed = rig.proximityPollSeconds
                rig.nearestEnemy = nearestEnemyDistance(patrolCFrame.Position)
            end
            local wantsSurface = (not hunting) and rig.nearestEnemy <= rig.surfaceDistance
            -- Patrol bite-rise stays visual. A published hunt leaves the wander, then grab/drag
            -- dives with the marcher the server is pulling under.
            local bitePhase = ((now / rig.bitePeriod) + rig.phase) % 1
            local bite = if wantsSurface then math.sin(math.pi * bitePhase) ^ 2 else 0
            local breachClock = (now + rig.phase * rig.breachPeriod) % rig.breachPeriod
            local breach = 0
            local pitch = 0
            if (not hunting) and breachClock < rig.breachDuration then
                local t = breachClock / rig.breachDuration
                breach = math.sin(math.pi * t)
                pitch = rig.breachPitch * math.cos(math.pi * t)
            elseif huntState == "chase" then
                bite = 0.85
                pitch = -0.18
            elseif huntState == "drag" then
                bite = 0.15
                pitch = 0.55 + 0.12 * math.sin(now * 9)
            end
            local targetHeight = rig.surfaceRise * bite + rig.breachRise * breach
            if huntState == "drag" and typeof(huntAim) == "Vector3" then
                targetHeight = math.min(0, huntAim.Y - rig.center.Y)
            end
            rig.surfaced += (targetHeight - rig.surfaced) * math.min(1, dt * 10)
            model:PivotTo(
                (patrolCFrame * CFrame.Angles(-pitch, 0, 0)) + Vector3.new(0, rig.surfaced, 0)
            )
        end
    end
end

local function updateSawBladeRigs(dt, observing)
    if not observing then
        return
    end
    local world = prototypeWorld()
    local folder = world and world:FindFirstChild("MergeEggBulwarks")
    sawBladeScanElapsed += dt
    if sawBladeScanElapsed >= 0.25 then
        sawBladeScanElapsed = 0
        for model in pairs(sawBladeRigs) do
            if not (folder and model.Parent and model:IsDescendantOf(folder)) then
                sawBladeRigs[model] = nil
            end
        end
        for model in pairs(landSharkRigs) do
            if not (folder and model.Parent and model:IsDescendantOf(folder)) then
                landSharkRigs[model] = nil
            end
        end
        for _, child in ipairs(folder and folder:GetChildren() or {}) do
            if
                child:IsA("Model")
                and child:GetAttribute("MergeBulwarkSpawned") == true
                and child:GetAttribute("MergeBulwarkFamily") == "saw_blade"
            then
                if sawBladeRigs[child] == nil then
                    registerSawBladeRig(child)
                else
                    local _, size = child:GetBoundingBox()
                    local longest = math.max(size.X, size.Y, size.Z)
                    local target = 10
                        * (tonumber(child:GetAttribute("MergeBulwarkSpawnScale")) or 1)
                    if longest > target * 1.5 then
                        sawBladeRigs[child] = nil
                        registerSawBladeRig(child)
                    end
                end
            end
            if
                child:IsA("Model")
                and child:GetAttribute("MergeBulwarkSpawned") == true
                and child:GetAttribute("MergeBulwarkFamily") == "land_shark"
                and child:GetAttribute("MergeLandSharkPatrol") == true
                and landSharkRigs[child] == nil
            then
                registerLandSharkRig(child)
            end
        end
    end
    for model, rig in pairs(sawBladeRigs) do
        if not model.Parent then
            sawBladeRigs[model] = nil
        else
            rig.angle = (rig.angle + math.rad(rig.speedDegrees) * dt) % (math.pi * 2)
            for _, blade in ipairs(rig.blades) do
                if blade.part.Parent then
                    blade.part.CFrame = blade.startCFrame
                        * sawBladeRotation(blade.axis, rig.angle * blade.direction)
                end
            end
        end
    end
    updateLandSharkRigs(dt)
    updateSawShredChunks(observing)
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
    -- Same upper-right chrome slot as the Farm quest pill (people_list
    -- 397×4px inset, 14px top). Keeps wave status out of the playfield.
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -4, 0, 14)
    frame.Size = UDim2.fromOffset(397, 78)
    frame.BackgroundColor3 = Color3.fromRGB(24, 30, 43)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = parent
    UIViewportScale.attach(frame)

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
    if state == "TutorialIntermission" then
        local step = world and tostring(world:GetAttribute("MergeEggTutorialStep") or "") or ""
        if TUTORIAL_CANNON_ORDER[step] then
            meter.title.Text = string.upper(stageName) .. " • COMMANDER ARRIVED"
            meter.detail.Text = step == "collect_cannon_coins"
                    and "WAVES PAUSED — PICK UP A WAYCOIN PILE"
                or step == "collect_cannon_gem" and "WAVES PAUSED — PICK UP THE GEM"
                or "WAVES PAUSED — TALK TO THE ARTILLERY COMMANDER"
        elseif TUTORIAL_UPGRADE_ORDER[step] then
            meter.title.Text = string.upper(stageName) .. " • STRENGTHEN THE LINE"
            meter.detail.Text = step == "collect_upgrade_coins"
                    and "WAVES PAUSED — PICK UP ABOUT 600 WAYCOINS"
                or "WAVES PAUSED — CREATE A COUPLE, THEN UPGRADE OR PLACE ONE"
        elseif TUTORIAL_QUARTERMASTER_ORDER[step] then
            meter.title.Text = string.upper(stageName) .. " • QUARTERMASTER ARRIVED"
            meter.detail.Text = "WAVES PAUSED — TALK TO MACROS AT THE POTION TENT"
        else
            meter.title.Text = string.upper(stageName) .. " • ENGINEER ARRIVED"
            meter.detail.Text = step == "collect_workshop_coins"
                    and "WAVES PAUSED — PICK UP A WAYCOIN PILE"
                or "WAVES PAUSED — TALK TO THE GOLD-LINE ENGINEER"
        end
        return
    end
    if wave <= 0 then
        local waitingForFirstEgg = state == "AwaitingFirstEgg"
        local waitingForCollect = world
                and (world:GetAttribute("MergeEggTutorialStep") == "collect_setup" or openingCollectTarget() ~= nil)
            or false
        meter.title.Text = string.upper(stageName)
            .. " • "
            .. (
                waitingForCollect and "COLLECT WAYCOINS"
                or waitingForFirstEgg and "INSTALL FIRST EGG"
                or "READY TO HATCH"
            )
        meter.detail.Text = string.format(
            "%s • %.0f× COMBAT\n%s • EGGS %d/%d • FIFO READY",
            endless and "ENDLESS DEFENSE" or string.format("%d-WAVE ENDURANCE TEST", waveCount),
            COMBAT_CADENCE_MULTIPLIER,
            waitingForCollect and "PICK UP THE PILES — KEEP DOING THIS"
                or waitingForFirstEgg and string.format(
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
        surface.CanvasSize = Vector2.new(PANEL_WIDTH + STATUS_BADGE_GUTTER, logicalHeight)
        surface.ClipsDescendants = false
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
        panel.frame.Position = UDim2.fromOffset(STATUS_BADGE_GUTTER, 0)
        panel.frame.ClipsDescendants = false
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
    card.frame.ClipsDescendants = false
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
    -- Same player/pet brew vocabulary as SquadHud. Flask Berserk comes from
    -- the owner; a Rage cannon circle stamps only the pet models it hits.
    StatusBadges.update(
        card,
        pet and StatusBadges.resolve("pet", { pet = pet, player = localPlayer }, os.time()) or {},
        STATUS_BADGE_BLINK_LEAD
    )
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
    billboard.MaxDistance = assert(
        tonumber(EGG_HEALTH_BILLBOARD.max_distance),
        "egg_health_billboard.max_distance is required"
    )
    billboard.Size = UDim2.fromOffset(
        assert(tonumber(EGG_HEALTH_BILLBOARD.width), "egg_health_billboard.width is required"),
        assert(tonumber(EGG_HEALTH_BILLBOARD.height), "egg_health_billboard.height is required")
    )
    billboard.StudsOffsetWorldSpace = Vector3.new(
        0,
        objective:GetExtentsSize().Y * 0.5
            + assert(
                tonumber(EGG_HEALTH_BILLBOARD.vertical_gap),
                "egg_health_billboard.vertical_gap is required"
            ),
        0
    )
    billboard.ResetOnSpawn = false
    billboard.Parent = localPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "EggHealthBar"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(27, 31, 39)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    UIViewportScale.attach(frame, {
        min = assert(
            tonumber(EGG_HEALTH_BILLBOARD.viewport_scale_min),
            "egg_health_billboard.viewport_scale_min is required"
        ),
        max = assert(
            tonumber(EGG_HEALTH_BILLBOARD.viewport_scale_max),
            "egg_health_billboard.viewport_scale_max is required"
        ),
    })

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
    label.TextSize = assert(
        tonumber(EGG_HEALTH_BILLBOARD.label_text_size),
        "egg_health_billboard.label_text_size is required"
    )
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
    -- A full row of healthy objectives obscures the battlefield without communicating danger.
    -- Keep the control alive so the first replicated damage update can reveal it immediately,
    -- then hide it again if an objective is restored to full health.
    control.billboard.Enabled = eggHealth < eggMaxHealth
    control.billboard.StudsOffsetWorldSpace = Vector3.new(
        0,
        objective:GetExtentsSize().Y * 0.5
            + assert(
                tonumber(EGG_HEALTH_BILLBOARD.vertical_gap),
                "egg_health_billboard.vertical_gap is required"
            ),
        0
    )
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
    -- The authored host is 14×8 studs. Match that aspect exactly so neither panel nor its text is
    -- stretched when projected onto the wall.
    surface.CanvasSize = Vector2.new(1400, 800)
    surface.LightInfluence = 0
    surface.AlwaysOnTop = false
    surface.Active = true
    surface.Enabled = false
    -- Interactive world-space GUI belongs under PlayerGui with an Adornee. Keeping it under the
    -- physical part made Roblox silently stop routing pointer input as the camera zoomed away.
    surface.Parent = playerGui

    local background = Instance.new("Frame")
    background.Name = "ManagementPanels"
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundTransparency = 1
    background.BorderSizePixel = 0
    background.Parent = surface

    local content = Instance.new("Frame")
    content.Name = "PanelContent"
    content.Position = UDim2.fromOffset(16, 16)
    content.Size = UDim2.new(1, -32, 1, -32)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = background

    local split = Instance.new("UIListLayout")
    split.FillDirection = Enum.FillDirection.Horizontal
    split.HorizontalAlignment = Enum.HorizontalAlignment.Center
    split.Padding = UDim.new(0, 16)
    split.SortOrder = Enum.SortOrder.LayoutOrder
    split.VerticalAlignment = Enum.VerticalAlignment.Center
    split.Parent = content

    local function createPanel(name, widthScale, layoutOrder, columns, rows)
        local panel = Instance.new("Frame")
        panel.Name = name
        panel.LayoutOrder = layoutOrder
        panel.Size = UDim2.new(widthScale, -8, 1, 0)
        panel.BackgroundColor3 = Color3.fromRGB(24, 29, 40)
        panel.BackgroundTransparency = 0.02
        panel.BorderSizePixel = 0
        panel.Parent = content

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 18)
        corner.Parent = panel

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(68, 82, 108)
        stroke.Thickness = 5
        stroke.Parent = panel

        local panelPadding = Instance.new("UIPadding")
        panelPadding.PaddingLeft = UDim.new(0, 14)
        panelPadding.PaddingRight = UDim.new(0, 14)
        panelPadding.PaddingTop = UDim.new(0, 14)
        panelPadding.PaddingBottom = UDim.new(0, 14)
        panelPadding.Parent = panel

        local grid = Instance.new("UIGridLayout")
        local panelInset = 28
        local cellGap = 12
        grid.CellPadding = UDim2.fromOffset(cellGap, cellGap)
        grid.CellSize = UDim2.new(
            1 / columns,
            -((panelInset + cellGap * (columns - 1)) / columns),
            1 / rows,
            -((panelInset + cellGap * (rows - 1)) / rows)
        )
        grid.FillDirection = Enum.FillDirection.Horizontal
        grid.FillDirectionMaxCells = columns
        grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.VerticalAlignment = Enum.VerticalAlignment.Center
        grid.Parent = panel
        return panel
    end

    -- Rebirth and Buy Egg are the large, high-consequence actions. The independent upgrade panel
    -- keeps eight smaller durable/progression controls in a legible 2×4 grid.
    local actionPanel = createPanel("Actions", 0.32, 1, 1, 2)
    local upgradePanel = createPanel("Upgrades", 0.68, 2, 2, 4)

    local cards = {
        {
            id = "rebirth",
            panel = actionPanel,
            color = Color3.fromRGB(245, 145, 45),
            action = { action = "rebirth" },
        },
        {
            id = "buy_egg",
            panel = actionPanel,
            color = Color3.fromRGB(52, 183, 225),
            action = { action = "create", managementBoard = true },
        },
        {
            id = "coin_value",
            panel = upgradePanel,
            color = Color3.fromRGB(225, 162, 45),
            action = { action = "purchase_upgrade", upgradeId = "coin_value" },
        },
        {
            id = "damage",
            panel = upgradePanel,
            color = Color3.fromRGB(70, 177, 235),
            action = { action = "purchase_upgrade", upgradeId = "damage" },
        },
        {
            id = "fire_rate",
            panel = upgradePanel,
            color = Color3.fromRGB(235, 82, 91),
            action = { action = "purchase_upgrade", upgradeId = "fire_rate" },
        },
        {
            id = "active_slots",
            panel = upgradePanel,
            color = Color3.fromRGB(125, 104, 235),
            action = { action = "purchase_upgrade", upgradeId = "active_slots" },
        },
        {
            id = "egg_health",
            panel = upgradePanel,
            color = Color3.fromRGB(225, 72, 112),
            action = { action = "purchase_upgrade", upgradeId = "egg_health" },
        },
        {
            id = "spawn_level",
            panel = upgradePanel,
            color = Color3.fromRGB(82, 205, 105),
            action = { action = "upgrade_base", managementBoard = true },
        },
        {
            id = "pet_endurance",
            panel = upgradePanel,
            color = Color3.fromRGB(177, 82, 225),
            action = { action = "purchase_upgrade", upgradeId = "pet_endurance" },
        },
        {
            id = "focus_regen",
            panel = upgradePanel,
            color = Color3.fromRGB(84, 198, 210),
            action = { action = "purchase_upgrade", upgradeId = "focus_regen" },
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
        button.Parent = card.panel

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
    button.Text = CONFIG.team.merge_board.equip_best_label
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

function MergeEggPrototypeObserver._createAutoCombineSurface(host)
    if not (host and host:IsA("BasePart")) then
        return nil
    end
    for _, child in ipairs(host:GetChildren()) do
        if child:IsA("SurfaceGui") then
            child.Enabled = false
        end
    end
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("MergeEggAutoCombineSurface")
    if existing then
        existing:Destroy()
    end

    local surface = Instance.new("SurfaceGui")
    surface.Name = "MergeEggAutoCombineSurface"
    surface.Adornee = host
    surface.Face = Enum.NormalId.Top
    surface.CanvasSize = Vector2.new(600, 300)
    surface.LightInfluence = 0
    surface.AlwaysOnTop = false
    surface.Active = true
    surface.Enabled = false
    surface.Parent = playerGui

    local button = Instance.new("TextButton")
    button.Name = "AutoCombine"
    button.Size = UDim2.fromScale(1, 1)
    button.Rotation = tonumber(
        ((CONFIG.team or {}).merge_board or {}).equip_best_text_rotation_degrees
    ) or 180
    button.BackgroundColor3 = Color3.fromRGB(177, 82, 225)
    button.BackgroundTransparency = 0.03
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Active = true
    button.Font = Enum.Font.GothamBlack
    button.Text = tostring(MergeEggPrototypeObserver.autoMergeLabels.locked)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextScaled = true
    button.TextStrokeColor3 = Color3.fromRGB(30, 16, 38)
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
    stroke.Color = Color3.fromRGB(225, 174, 255)
    stroke.Thickness = 7
    stroke.Parent = button

    button.Activated:Connect(function()
        if MergeEggPrototypeObserver.autoMergeOwned or button:GetAttribute("PassOwned") == true then
            Signals.MergeEggPrototypeBoardAction:FireServer({ action = "toggle_auto" })
        else
            MergeEggPrototypeObserver.GamePassPurchasePrompt.show({
                passId = MergeEggPrototypeObserver.autoMergePassId,
                presentation = MergeEggPrototypeObserver.autoMergeConfig.purchase_menu,
            }, function(purchase, entry)
                if purchase then
                    Signals.InitiatePurchase:FireServer({
                        productId = entry.id,
                        productType = entry.kind,
                    })
                end
            end)
        end
    end)
    return { surface = surface, host = host, button = button, stroke = stroke }
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
    local autoCombineHost =
        world:FindFirstChild(worldCfg.auto_combine_control or "AutoCombineControl", true)
    return {
        world = world,
        board = createManagementBoardSurface(host),
        equipBest = createEquipBestSurface(equipBestHost),
        autoCombine = MergeEggPrototypeObserver._createAutoCombineSurface(autoCombineHost),
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
        equipBest.button.Text = CONFIG.team.merge_board.equip_best_label
        local host = equipBest.host
        if host and host:IsA("BasePart") then
            host.Color = stateColor
        end
    end
    local autoCombine = controls.autoCombine
    if autoCombine then
        local autoEnabled = world and world:GetAttribute("AutoCombineEnabled") == true
        local passOwned = MergeEggPrototypeObserver.autoMergeOwned
            or (world and world:GetAttribute("AutoMergeOwned") == true)
        local stateColor = autoEnabled and Color3.fromRGB(75, 190, 105)
            or passOwned and Color3.fromRGB(177, 82, 225)
            or Color3.fromRGB(70, 74, 84)
        autoCombine.surface.Enabled = observing
        autoCombine.button.Active = observing
        autoCombine.button.AutoButtonColor = observing
        autoCombine.button.BackgroundColor3 = stateColor
        autoCombine.stroke.Color = if autoEnabled
            then Color3.fromRGB(150, 255, 180)
            else passOwned and Color3.fromRGB(225, 174, 255) or Color3.fromRGB(132, 138, 151)
        autoCombine.button.Text = if not passOwned
            then tostring(MergeEggPrototypeObserver.autoMergeLabels.locked)
            else autoEnabled and tostring(MergeEggPrototypeObserver.autoMergeLabels.on) or tostring(
                MergeEggPrototypeObserver.autoMergeLabels.off
            )
        autoCombine.button:SetAttribute("PassOwned", passOwned)
        autoCombine.button:SetAttribute("AutoMergeEnabled", autoEnabled)
        local host = autoCombine.host
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
    local baseName = tostring(world and world:GetAttribute("BaseEggSourceName") or "Earth Egg")
    local upgradeData = {
        coin_value = { title = "COIN VALUE", attribute = "CoinValue", suffix = "%" },
        damage = { title = "DAMAGE", attribute = "Damage", suffix = "%" },
        fire_rate = { title = "FIRE RATE", attribute = "FireRate", suffix = "%" },
        egg_health = { title = "EGG HP", attribute = "EggHealth", suffix = "%" },
        pet_endurance = { title = "PET ENDURANCE", attribute = "PetEndurance", suffix = "%" },
        focus_regen = { title = "FOCUS REGEN", attribute = "FocusRegen", suffix = "%" },
    }
    for id, data in pairs(upgradeData) do
        local card = buttons[id]
        local prefix = "Management" .. data.attribute
        local step = math.max(0, tonumber(world:GetAttribute(prefix .. "Step")) or 0)
        local stepPercent = math.floor(step * 100 + 0.5)
        local currentPercent =
            math.max(0, math.floor(tonumber(world:GetAttribute(prefix .. "Percent")) or 100))
        local nextPercent = math.max(
            currentPercent,
            math.floor(
                tonumber(world:GetAttribute(prefix .. "NextPercent"))
                    or (currentPercent + stepPercent)
            )
        )
        local cost = world:GetAttribute(prefix .. "Cost")
        local maxed = world:GetAttribute(prefix .. "Maxed") == true
        setManagementCard(card, observing, {
            title = string.format("%s %d%s", data.title, currentPercent, data.suffix),
            detail = maxed and "MAX" or string.format(
                "+%d%s → %d%s",
                stepPercent,
                data.suffix,
                nextPercent,
                data.suffix
            ),
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
    local personalEggName =
        tostring(world:GetAttribute("MergeDefensePersonalEggName") or "PERSONAL EGG")
    local nextPersonalEggName =
        tostring(world:GetAttribute("MergeDefenseNextPersonalEggName") or "NEXT EGG")
    local rebirthCard = buttons.rebirth
    local rebirthAvailable = observing and not rebirthMaxed and rebirthRequirementMet
    if rebirthMaxed then
        setManagementCard(rebirthCard, observing, {
            title = string.format("REBIRTH R%d", rebirthRank),
            detail = string.format(
                "%s • %s DAMAGE • MAX",
                string.upper(personalEggName),
                formatDamageMultiplier(alliedDamageMultiplier)
            ),
            available = false,
            pillText = "MAX",
            showIcon = false,
        })
    elseif not rebirthRequirementMet then
        setManagementCard(rebirthCard, observing, {
            title = string.format("REBIRTH R%d", rebirthRank),
            detail = string.format(
                "NEXT R%d · ALL EGGS NEED TIER %d",
                rebirthRank + 1,
                math.max(1, math.floor(tonumber(rebirthMinimumTier) or 1))
            ),
            available = false,
            pillText = MergeEggCostFormat.format(rebirthCost),
            showIcon = true,
        })
    elseif os.clock() < rebirthConfirmUntil then
        setManagementCard(rebirthCard, observing, {
            title = "CONFIRM REBIRTH",
            detail = string.format("UNLOCK %s • RESET RUN", string.upper(nextPersonalEggName)),
            available = rebirthAvailable,
            currency = "rebirth",
            pillText = "CLICK AGAIN",
            showIcon = false,
        })
    else
        setManagementCard(rebirthCard, observing, {
            title = string.format("REBIRTH R%d", rebirthRank),
            detail = string.format(
                "NEXT R%d · %s + %s DAMAGE",
                rebirthRank + 1,
                string.upper(nextPersonalEggName),
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

local function deploymentTargetAtScreenPoint(screenPoint)
    local world = prototypeWorld()
    local pads = world and world:FindFirstChild("MergeEggDeploymentPads")
    local includedPads = {}
    for _, pad in ipairs(pads and pads:GetChildren() or {}) do
        if pad:IsA("BasePart") and pad:GetAttribute("MergeEggDeploymentAvailable") == true then
            includedPads[#includedPads + 1] = pad
        end
    end
    local instance = includedInstanceAtScreenPoint(screenPoint, includedPads)
    local teamId = deploymentTeamFromInstance(instance)
    local pad = teamId and deploymentPadForTeam(teamId) or nil
    if not pad then
        return nil
    end
    return {
        kind = "deployment",
        adornee = pad,
        teamId = teamId,
        deployedTier = math.max(
            0,
            math.floor(tonumber(pad:GetAttribute("MergeEggDeploymentTier")) or 0)
        ),
    }
end

local function tapTargetAtScreenPoint(screenPoint)
    local egg = boardEggAtScreenPoint(screenPoint, nil)
    if egg then
        return {
            kind = "board_egg",
            model = egg,
            slot = tonumber(egg:GetAttribute("MergeEggBoardSlot")),
            tier = tonumber(egg:GetAttribute("MergeEggSourceTier")),
        }
    end
    return deploymentTargetAtScreenPoint(screenPoint)
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
    if not (drag and drag.mode == "drag" and drag.model and drag.model.Parent and camera) then
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
        mode = "drag",
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

local function handleBoardTap(input)
    if localPlayer:GetAttribute("InMergeEggPrototype") ~= true then
        return
    end
    local interaction = boardDrag
    if interaction and interaction.mode ~= "tap" then
        return
    end
    local target = tapTargetAtScreenPoint(input.Position)
    local selection = interaction
            and {
                sourceSlot = interaction.sourceSlot,
                sourceTier = interaction.sourceTier,
            }
        or nil
    local result = MergeEggBoardTapPolicy.resolve(selection, target)
    if interaction then
        destroyBoardDrag(interaction, true)
        boardDrag = nil
    end
    if result.kind == "select" and target and target.model then
        beginBoardDrag(input)
        if boardDrag then
            boardDrag.mode = "tap"
            boardDrag.input = nil
        end
    elseif result.request then
        Signals.MergeEggPrototypeBoardAction:FireServer(result.request)
    end
end

local function finishBoardDrag(input)
    local drag = boardDrag
    if
        not drag
        or drag.mode ~= "drag"
        or not drag.input
        or drag.input.UserInputType ~= input.UserInputType
    then
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

    local pg = localPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "MergeEggPrototypeObserver"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 41
    gui.Enabled = false
    gui.Parent = pg
    -- The card is created here, then mounted over HotbarBar.Bar's exact PillFrame UDim geometry.
    -- Persistent flank controls remain siblings under GreaterHotbarFrame and stay interactive.
    local tutorialGui = Instance.new("ScreenGui")
    tutorialGui.Name = "MergeEggTutorialHud"
    tutorialGui.ResetOnSpawn = false
    tutorialGui.IgnoreGuiInset = true
    tutorialGui.DisplayOrder = 100
    tutorialGui.Enabled = false
    tutorialGui.Parent = pg
    -- Own inset-ignored surface so the wave bar can sit in the quest-pill
    -- slot (DisplayOrder 90) without shifting the rest of this observer HUD.
    local waveGui = Instance.new("ScreenGui")
    waveGui.Name = "MergeWaveBar"
    waveGui.ResetOnSpawn = false
    waveGui.IgnoreGuiInset = true
    waveGui.DisplayOrder = 90
    waveGui.Enabled = false
    waveGui.Parent = pg
    -- Workshop menus are their own ScreenGui at DisplayOrder 120. Keep this
    -- toast above that layer so Install/Upgrade refusals are readable.
    local feedbackGui = Instance.new("ScreenGui")
    feedbackGui.Name = "MergeEggBoardFeedback"
    feedbackGui.ResetOnSpawn = false
    feedbackGui.IgnoreGuiInset = true
    feedbackGui.DisplayOrder = 130
    feedbackGui.Enabled = false
    feedbackGui.Parent = pg
    local boardActionFeedback, boardActionFeedbackStroke, boardActionFeedbackSizeConstraint, boardActionFeedbackAspect =
        createBoardActionFeedback(feedbackGui)
    local tutorialCard = createTutorialCard(tutorialGui)
    local boardActionFeedbackUntil = 0
    local activeFeedback = nil
    local feedbackQueue = {}
    local function milestoneFeedbackAllowed()
        return localPlayer:GetAttribute("InMergeEggPrototype") == true
    end
    local function showFeedback(item)
        activeFeedback = item
        if not item then
            boardActionFeedback.Visible = false
            return
        end
        boardActionFeedback.Text = item.text
        boardActionFeedback.TextColor3 = item.success and Color3.fromRGB(190, 255, 205)
            or Color3.fromRGB(255, 205, 105)
        boardActionFeedbackStroke.Color = item.success and Color3.fromRGB(95, 230, 135)
            or Color3.fromRGB(245, 170, 60)
        boardActionFeedback.Visible = true
        boardActionFeedbackUntil = os.clock() + item.duration
    end
    local function showNextFeedback()
        showFeedback(table.remove(feedbackQueue, 1))
    end
    local function enqueueFeedback(key, copy, success, duration)
        if not copy or copy == "" then
            return
        end
        local item = {
            key = key,
            text = copy,
            success = success,
            duration = math.max(0.1, duration),
        }
        if activeFeedback and activeFeedback.key == key then
            showFeedback(item)
            return
        end
        for index, queued in ipairs(feedbackQueue) do
            if queued.key == key then
                feedbackQueue[index] = item
                return
            end
        end
        feedbackQueue[#feedbackQueue + 1] = item
        while #feedbackQueue > math.max(1, math.floor(TUTORIAL_ACTIVITY_MAXIMUM_QUEUE)) do
            table.remove(feedbackQueue, 1)
        end
        if not activeFeedback then
            showNextFeedback()
        end
    end
    local bulwarkMenu = MergeBulwarkMenu.new(gui, function(action)
        Signals.MergeEggPrototypeBoardAction:FireServer(action)
    end)
    local cannonMenu = MergeCannonMenu.new(gui, function(action)
        Signals.MergeEggPrototypeBoardAction:FireServer(action)
    end)
    local function openQuartermasterPasses(value)
        local menuManager = _G.MenuManager
        if not menuManager then
            return
        end
        local function open()
            menuManager:OpenShopPanel("scale_in", {
                title = tostring(value.title or "QUARTERMASTER PASSES"),
                subtitle = tostring(
                    value.subtitle or "Permanent upgrades selected for Merge Defense"
                ),
                passIds = type(value.passIds) == "table" and value.passIds or {},
                showProducts = false,
                showFoundersChoice = false,
            })
        end
        if menuManager:GetPanel("Shop") then
            task.defer(open)
        else
            menuManager:OnPanelRegistered("Shop", open)
        end
    end
    Signals.MergeEggPrototypeBoardResult.OnClientEvent:Connect(function(result)
        if localPlayer:GetAttribute("InMergeEggPrototype") ~= true or type(result) ~= "table" then
            return
        end
        local action = tostring(result.action or "")
        if action == "open_bulwark_menu" and result.ok == true then
            cannonMenu:hide()
            bulwarkMenu:show(result.value, true)
            return
        end
        if action == "open_cannon_menu" and result.ok == true then
            bulwarkMenu:hide()
            cannonMenu:show(result.value, true)
            return
        end
        local success = result.ok == true
        local operation = type(result.value) == "table" and tostring(result.value.operation or "")
            or ""
        if action == "quartermaster_talk" and success and operation == "quartermaster_services" then
            bulwarkMenu:hide()
            cannonMenu:hide()
            QuartermasterServicesMenu.show(result.value, function(choice)
                Signals.MergeEggPrototypeBoardAction:FireServer({
                    action = "quartermaster",
                    choice = choice,
                })
            end)
        elseif action == "quartermaster" and success then
            QuartermasterServicesMenu.hide()
            if operation == "game_passes_opened" and type(result.value) == "table" then
                openQuartermasterPasses(result.value)
            end
            return
        end
        local placed = operation == "installed"
            or operation == "replaced"
            or operation == "equipped"
        if action == "bulwark" and success and type(result.value) == "table" then
            if placed then
                bulwarkMenu:hide()
            else
                bulwarkMenu:show(result.value)
            end
        end
        if action == "cannon" and success and type(result.value) == "table" then
            if placed then
                cannonMenu:hide()
            else
                cannonMenu:show(result.value)
            end
        end
        if success and not milestoneFeedbackAllowed() then
            return
        end
        local tutorialEggUpgrade = success and result.tutorialEggUpgrade == true
        local value = type(result.value) == "table" and result.value or {}
        if not success then
            enqueueFeedback(
                string.format("failure:%s:%s", action, tostring(result.reason or "action_refused")),
                boardActionFailureCopy(result),
                false,
                TUTORIAL_ACTIVITY_DEFAULT_SECONDS
            )
            return
        end
        local key, copy
        if tutorialEggUpgrade then
            key = "tutorial_egg_upgraded"
            copy = tutorialActivityCopy(
                "tutorial_egg_upgraded",
                string.upper(tostring(value.eggName or "EGG"))
            )
        else
            key, copy = milestoneResultFeedback(value)
        end
        if key then
            enqueueFeedback(
                key,
                copy,
                true,
                tutorialEggUpgrade and TUTORIAL_EGG_UPGRADED_SECONDS
                    or TUTORIAL_ACTIVITY_DEFAULT_SECONDS
            )
        end
        local petSlots = tonumber(value.petSlotMilestone)
        if petSlots then
            enqueueFeedback(
                "pet_slot_unlocked:" .. tostring(petSlots),
                tutorialActivityCopy("pet_slot_unlocked", ordinal(petSlots)),
                true,
                TUTORIAL_ACTIVITY_DEFAULT_SECONDS
            )
        end
        for _, automaticMilestone in
            ipairs(type(value.milestones) == "table" and value.milestones or {})
        do
            if type(automaticMilestone) == "table" then
                local automaticKey, automaticCopy = milestoneResultFeedback(automaticMilestone)
                if automaticKey then
                    enqueueFeedback(
                        automaticKey,
                        automaticCopy,
                        true,
                        TUTORIAL_ACTIVITY_DEFAULT_SECONDS
                    )
                end
                local automaticPetSlots = tonumber(automaticMilestone.petSlotMilestone)
                if automaticPetSlots then
                    enqueueFeedback(
                        "pet_slot_unlocked:" .. tostring(automaticPetSlots),
                        tutorialActivityCopy("pet_slot_unlocked", ordinal(automaticPetSlots)),
                        true,
                        TUTORIAL_ACTIVITY_DEFAULT_SECONDS
                    )
                end
            end
        end
    end)
    localPlayer:GetAttributeChangedSignal("InMergeEggPrototype"):Connect(function()
        if localPlayer:GetAttribute("InMergeEggPrototype") ~= true then
            bulwarkMenu:hide()
            cannonMenu:hide()
            QuartermasterServicesMenu.hide()
            activeFeedback = nil
            table.clear(feedbackQueue)
            showFeedback(nil)
        end
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
    Signals.OwnedPasses.OnClientEvent:Connect(function(snapshot)
        MergeEggPrototypeObserver.autoMergeOwned = MergeEggPrototypeObserver.MonetizationCatalog.ownedSet(
            snapshot
        )[MergeEggPrototypeObserver.autoMergePassId] == true
    end)
    Signals.GetOwnedPasses:FireServer()
    local touchCfg = (((CONFIG.team or {}).merge_board or {}).touch_input or {})
    local maximumTapMovement = assert(
        tonumber(touchCfg.max_movement_pixels),
        "merge_egg_prototype.team.merge_board.touch_input.max_movement_pixels is required"
    )
    local maximumTapDuration = assert(
        tonumber(touchCfg.max_duration_seconds),
        "merge_egg_prototype.team.merge_board.touch_input.max_duration_seconds is required"
    )
    local activeTouchCount = 0
    local boardTouchCandidate = nil

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.Touch then
            activeTouchCount += 1
            if activeTouchCount == 1 and not gameProcessed then
                boardTouchCandidate = {
                    input = input,
                    position = Vector2.new(input.Position.X, input.Position.Y),
                    beganAt = os.clock(),
                    cancelled = false,
                }
            elseif boardTouchCandidate then
                boardTouchCandidate.cancelled = true
            end
            return
        end
        if gameProcessed then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            beginBoardDrag(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local candidate = boardTouchCandidate
            local matches = candidate and candidate.input == input
            if matches then
                boardTouchCandidate = nil
            end
            activeTouchCount = math.max(0, activeTouchCount - 1)
            if matches and candidate.cancelled ~= true and activeTouchCount == 0 then
                local releasedAt = Vector2.new(input.Position.X, input.Position.Y)
                local movement = (releasedAt - candidate.position).Magnitude
                local duration = os.clock() - candidate.beganAt
                if movement <= maximumTapMovement and duration <= maximumTapDuration then
                    handleBoardTap(input)
                end
            end
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            finishBoardDrag(input)
        end
    end)

    local waveMeter = createWaveMeter(waveGui)
    local eggHealthBillboards = {}
    local lastWave = 0
    local announceUntil = 0
    local factor = tonumber(COMBAT.pet_down_threshold_factor) or 1
    local elapsed = 0
    local rotationElapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        local observing = localPlayer:GetAttribute("InMergeEggPrototype") == true
        if observing then
            for _, panel in pairs(panels) do
                StatusBadges.applyBlink(panel.cards, STATUS_BADGE_BLINK_PERIOD)
            end
        end
        updateSawBladeRigs(dt, observing)
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
        if activeFeedback and os.clock() >= boardActionFeedbackUntil then
            activeFeedback = nil
            showNextFeedback()
        end
        if observing and boardDrag and boardDrag.model and boardDrag.model.Parent then
            if boardDrag.mode == "drag" then
                updateBoardDrag()
            else
                updateEggFocusVisual(boardDrag.sourceFocus, boardDrag.model)
                setDragTarget(boardDrag, nil)
            end
        elseif not observing and boardDrag then
            destroyBoardDrag(boardDrag, true)
            boardDrag = nil
        elseif boardDrag then
            destroyBoardDrag(boardDrag, false)
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
        tutorialGui.Enabled = observing
        waveGui.Enabled = observing
        feedbackGui.Enabled = observing
        if not boardWallControls or not boardWallControls.world.Parent then
            boardWallControls = createBoardWallControls()
        end
        updateBoardWallControls(boardWallControls, observing)
        if not observing then
            setTutorialHotbarCovered(nil, false)
            setHotbarDisplayOrder(
                assert(
                    tonumber(TUTORIAL_CARD_LAYOUT.inactive_display_order),
                    "tutorial.card_layout.inactive_display_order is required"
                )
            )
            activeFeedback = nil
            table.clear(feedbackQueue)
            showFeedback(nil)
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
        setTutorialHotbarCovered(world, true)
        updateTutorialCard(tutorialCard, world, true, bulwarkMenu, cannonMenu)
        if tutorialCard.frame.Visible then
            layoutTutorialCardOverHotbar(tutorialCard)
        end
        if boardActionFeedback.Visible then
            layoutBoardActionFeedback(
                boardActionFeedback,
                boardActionFeedbackSizeConstraint,
                boardActionFeedbackAspect,
                unlockFeedbackBehindOpenWorkshop(activeFeedback, bulwarkMenu, cannonMenu)
            )
        elseif not tutorialCard.frame.Visible then
            setHotbarDisplayOrder(
                assert(
                    tonumber(TUTORIAL_CARD_LAYOUT.inactive_display_order),
                    "tutorial.card_layout.inactive_display_order is required"
                )
            )
        end
        local tutorialStep = world and tostring(world:GetAttribute("MergeEggTutorialStep") or "")
        if
            tutorialStep ~= "unlock_bulwark"
            and tutorialStep ~= "install_bulwark"
            and tutorialStep ~= "unlock_cannon"
            and tutorialStep ~= "install_cannon"
        then
            local tutorialBuyingEggs = tutorialBuyEggCueAllowed(world)
            local buyEggCard = boardWallControls
                and boardWallControls.board
                and boardWallControls.board.buttons
                and boardWallControls.board.buttons.buy_egg
            setTutorialClickCueTarget(
                tutorialBuyingEggs and buyEggCard and buyEggCard.button
                    or world and world:GetAttribute("MergeEggTutorialActive") == true and (tutorialStep == "combine_once" or tutorialStep == "deploy_one") and boardWallControls and boardWallControls.equipBest and boardWallControls.equipBest.button
                    or nil
            )
        end

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
