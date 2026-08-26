--[[
    MergeEggPrototypeObserver — Phase 6 combat, hatch telemetry, and world progression.

    The player's ordinary SquadHud remains reserved for their own deployable team. This Studio-only
    rail renders one column per hatcher NPC from replicated folder/model attributes: tier-scaled pet
    slots, endurance, current target, assigned-enemy count, team lifecycle, and wave progress.
    Combat observation remains read-only. The only control is a Studio-only per-captain egg-source
    progression action; the first source creates the team and later sources affect replacements.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HudCard = require(script.Parent.Parent.UI.HudCard)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local CONFIG = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local COMBAT = require(ReplicatedStorage.Configs:WaitForChild("combat"))
local PET_ROLES = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))

local MergeEggPrototypeObserver = {}

local localPlayer = Players.LocalPlayer
local PANEL_WIDTH = 214
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
local EGG_THEME = {
    grass_egg = Color3.fromRGB(90, 205, 105),
    ice_egg = Color3.fromRGB(105, 205, 255),
    lava_egg = Color3.fromRGB(255, 120, 55),
    desert_egg = Color3.fromRGB(255, 205, 80),
    bloom_egg = Color3.fromRGB(140, 235, 145),
    aurora_egg = Color3.fromRGB(155, 225, 255),
    solar_egg = Color3.fromRGB(255, 175, 75),
    gilded_egg = Color3.fromRGB(255, 220, 105),
}

local function prettyName(value)
    local text = tostring(value or "Pet"):gsub("_", " ")
    return text:gsub("^%l", string.upper)
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
    local maps = Workspace:FindFirstChild((CONFIG.world or {}).maps_root or "Maps")
    local world = maps
        and maps:FindFirstChild((CONFIG.world or {}).model_name or "MergeEggPrototype")
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
        tostring(world:GetAttribute("ProgressionStageName") or "Home"),
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
    local teamRailWidth = (#(CONFIG.teams or {}) * PANEL_WIDTH)
        + (math.max(0, #(CONFIG.teams or {}) - 1) * 4)
    frame.Position = UDim2.new(0.5, -math.floor(teamRailWidth * 0.5), 0, 88)
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
    if wave <= 0 then
        local waitingForFirstEgg = state == "AwaitingFirstEgg"
        meter.title.Text = string.upper(stageName)
            .. " • "
            .. (waitingForFirstEgg and "INSTALL FIRST EGG" or "READY TO HATCH")
        meter.detail.Text = string.format(
            "%d-WAVE ENDURANCE TEST • %.0f× COMBAT\n%s • EGGS %d/%d • FIFO READY",
            waveCount,
            COMBAT_CADENCE_MULTIPLIER,
            waitingForFirstEgg
                    and string.format(
                        "WAVE 1 HELD • %d/%d HATCHERS ONLINE",
                        initializedHatchers,
                        #(CONFIG.teams or {})
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
            "%d / %d • %d %s • %d HATCHERS • %d ACTIVE / %d BEHIND (PEAK %d) • %s • %.0f× COMBAT\nEGGS %d/%d • Q%d/P%d/H%d • PICKS %d/%d G%d/R%d/H%d • FIRST BREACH %s • %s",
            wave,
            waveCount,
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
    meter.fill.Size = UDim2.fromScale(math.clamp(wave / math.max(1, waveCount), 0, 1), 1)
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
    header.Size = UDim2.fromOffset(PANEL_WIDTH, 46)
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

    return title, summary
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
    layout.Padding = UDim.new(0, 4)
    layout.Parent = frame

    local title, summary =
        createHeader(frame, tostring(teamCfg.display_name or ("NPC Team " .. id)):upper())
    return {
        id = id,
        config = teamCfg,
        frame = frame,
        title = title,
        summary = summary,
        cards = {},
    }
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
    panel.summary.Text = string.format(
        "%s %d/%d • Q%d/H%d • G%d/R%d • F%d/P%d • W%d/%d%s",
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
        waveCount,
        lossText
    )
    panel.summary.TextColor3 = state == "DEFEATED" and Color3.fromRGB(240, 105, 95)
        or state == "ENGAGED" and Color3.fromRGB(245, 190, 75)
        or Color3.fromRGB(175, 205, 230)

    local bySlot = {}
    local queuedSlots = {}
    for value in
        string.gmatch(tostring(folder:GetAttribute("MergeEggReplacementSlots") or ""), "[^,]+")
    do
        queuedSlots[tonumber(value)] = true
    end
    for _, pet in ipairs(folder:GetChildren()) do
        if pet:IsA("Model") then
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

local function hatcherPrincipal(teamId)
    for _, child in ipairs(Workspace:GetChildren()) do
        if
            child:IsA("Model")
            and child:GetAttribute("MergeEggPrototypeNpc") == true
            and tonumber(child:GetAttribute("MergeEggTeamId")) == teamId
        then
            return child
        end
    end
    return nil
end

local function createEggProgressionBillboard(teamId, principal)
    local adornee = principal:FindFirstChild("Head", true)
        or principal:FindFirstChild("HumanoidRootPart", true)
        or principal.PrimaryPart
    if not (adornee and adornee:IsA("BasePart")) then
        return nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MergeEggHatcherEggProgression_" .. teamId
    billboard.Adornee = adornee
    billboard.Active = true
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 240
    billboard.Size = UDim2.fromOffset(230, 72)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
    billboard.ResetOnSpawn = false
    billboard.Parent = localPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "EggProgressionCard"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(22, 28, 40)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(105, 205, 255)
    stroke.Transparency = 0.1
    stroke.Thickness = 2
    stroke.Parent = frame

    local current = Instance.new("TextLabel")
    current.Name = "CurrentEgg"
    current.BackgroundTransparency = 1
    current.Position = UDim2.fromOffset(8, 4)
    current.Size = UDim2.new(1, -16, 0, 19)
    current.Font = Enum.Font.GothamBold
    current.Text = "CURRENT: NO EGG"
    current.TextColor3 = Color3.fromRGB(225, 235, 248)
    current.TextSize = 12
    current.Parent = frame

    local button = Instance.new("TextButton")
    button.Name = "AdvanceEggButton"
    button.Position = UDim2.fromOffset(7, 27)
    button.Size = UDim2.new(1, -14, 0, 38)
    button.BackgroundColor3 = Color3.fromRGB(50, 145, 205)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamBlack
    button.Text = "CREATE → EARTH EGG"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 15
    button.Parent = frame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 7)
    buttonCorner.Parent = button

    local control = {
        teamId = teamId,
        principal = principal,
        folder = nil,
        billboard = billboard,
        stroke = stroke,
        current = current,
        button = button,
        lockedUntil = 0,
    }
    button.Activated:Connect(function()
        local folder = control.folder
        if
            os.clock() < control.lockedUntil
            or not (folder and folder.Parent)
            or folder:GetAttribute("MergeEggCanAdvance") ~= true
        then
            return
        end
        control.lockedUntil = os.clock() + 0.6
        button.Text = "CREATING EGG..."
        Signals.MergeEggPrototypeUpgrade:FireServer({ teamId = teamId })
    end)
    return control
end

local function destroyEggProgressionBillboards(controls)
    for id, control in pairs(controls) do
        if control.billboard then
            control.billboard:Destroy()
        end
        controls[id] = nil
    end
end

local function updateEggProgressionBillboard(controls, teamId, folder)
    if not folder then
        local stale = controls[teamId]
        if stale then
            stale.billboard:Destroy()
            controls[teamId] = nil
        end
        return
    end
    local principal = hatcherPrincipal(teamId)
    if not principal then
        local stale = controls[teamId]
        if stale then
            stale.billboard:Destroy()
            controls[teamId] = nil
        end
        return
    end
    local control = controls[teamId]
    if not control or not control.billboard.Parent or control.principal ~= principal then
        if control and control.billboard then
            control.billboard:Destroy()
        end
        control = createEggProgressionBillboard(teamId, principal)
        controls[teamId] = control
    end
    if not control then
        return
    end
    control.folder = folder

    local currentName = tostring(folder:GetAttribute("MergeEggSourceName") or "No Egg")
    local nextName = folder:GetAttribute("MergeEggNextSourceName")
    local nextId = folder:GetAttribute("MergeEggNextSourceId")
    local nextCost = math.max(0, tonumber(folder:GetAttribute("MergeEggNextEggCost")) or 0)
    local currentDraftRolls =
        math.max(0, math.floor(tonumber(folder:GetAttribute("MergeEggDraftRolls")) or 0))
    local nextDraftRolls =
        math.max(0, math.floor(tonumber(folder:GetAttribute("MergeEggNextDraftRolls")) or 0))
    local needsRebuild = folder:GetAttribute("MergeEggNeedsRebuild") == true
    local eggHealth = math.max(0, tonumber(folder:GetAttribute("MergeEggInstalledHealth")) or 0)
    local eggMaxHealth =
        math.max(1, tonumber(folder:GetAttribute("MergeEggInstalledMaxHealth")) or 1)
    local canAdvance = folder:GetAttribute("MergeEggCanAdvance") == true and nextName ~= nil
    local color = EGG_THEME[tostring(nextId)] or Color3.fromRGB(135, 145, 165)
    control.current.Text = needsRebuild and "EGG DESTROYED • REBUILD REQUIRED"
        or string.format(
            "CURRENT: %s • %d/%d HP • %d PICK%s",
            string.upper(currentName),
            eggHealth,
            eggMaxHealth,
            currentDraftRolls,
            currentDraftRolls == 1 and "" or "S"
        )
    control.stroke.Color = color
    if canAdvance then
        control.button.Active = true
        control.button.AutoButtonColor = true
        control.button.BackgroundColor3 = color
        if os.clock() >= control.lockedUntil then
            control.button.Text = string.format(
                "%s %s • %d • %d PICKS",
                needsRebuild and "REBUILD" or "CREATE",
                string.upper(tostring(nextName)),
                nextCost,
                nextDraftRolls
            )
        end
    else
        control.button.Active = false
        control.button.AutoButtonColor = false
        control.button.BackgroundColor3 = Color3.fromRGB(65, 72, 84)
        control.button.Text = string.upper(currentName) .. " • MAX"
    end
end

function MergeEggPrototypeObserver.start()
    if not RunService:IsStudio() then
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MergeEggPrototypeObserver"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 41
    gui.Enabled = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Name = "TeamRail"
    root.AnchorPoint = Vector2.new(1, 0)
    root.Position = UDim2.new(1, -8, 0, 8)
    root.Size = UDim2.fromOffset(10, 10)
    root.AutomaticSize = Enum.AutomaticSize.XY
    root.BackgroundTransparency = 1
    root.Parent = gui
    require(script.Parent.Parent.UI.UIViewportScale).attach(root)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = root

    local panels = {}
    for order, teamCfg in ipairs(CONFIG.teams or {}) do
        local panel = createPanel(root, teamCfg, order)
        panels[panel.id] = panel
    end

    local waveMeter = createWaveMeter(gui)
    local eggProgressionBillboards = {}
    local lastWave = 0
    local announceUntil = 0
    local factor = tonumber(COMBAT.pet_down_threshold_factor) or 1
    local elapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0

        local observing = localPlayer:GetAttribute("InMergeEggPrototype") == true
        gui.Enabled = observing
        if not observing then
            waveMeter.frame.Visible = false
            destroyEggProgressionBillboards(eggProgressionBillboards)
            lastWave = 0
            announceUntil = 0
            for _, panel in pairs(panels) do
                clearCards(panel)
            end
            return
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
            updateEggProgressionBillboard(eggProgressionBillboards, id, folders[id])
        end
    end)
end

return MergeEggPrototypeObserver
