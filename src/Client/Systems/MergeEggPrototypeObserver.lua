--[[
    MergeEggPrototypeObserver — read-only Phase 2 combat telemetry.

    The player's ordinary SquadHud remains reserved for their own deployable team. This Studio-only
    rail observes the one hatcher NPC squad directly from replicated folder/model attributes: five
    stable pet slots, endurance, current target, team lifecycle, and wave progress. It sends no
    remotes and cannot focus enemies or command the NPC team.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HudCard = require(script.Parent.Parent.UI.HudCard)
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)

local CONFIG = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local COMBAT = require(ReplicatedStorage.Configs:WaitForChild("combat"))
local PET_ROLES = require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))

local MergeEggPrototypeObserver = {}

local localPlayer = Players.LocalPlayer
local ROLE_THEME = {
    tank = { color = Color3.fromRGB(75, 145, 225), glyph = "T" },
    melee = { color = Color3.fromRGB(210, 80, 75), glyph = "M" },
    ranged = { color = Color3.fromRGB(225, 145, 65), glyph = "R" },
    support = { color = Color3.fromRGB(70, 185, 110), glyph = "+" },
    control = { color = Color3.fromRGB(155, 100, 215), glyph = "C" },
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

local function teamFolder()
    local root = Workspace:FindFirstChild("PlayerPets")
    for _, folder in ipairs(root and root:GetChildren() or {}) do
        if
            folder:GetAttribute("MergeEggPrototypeTeam") == true
            and tonumber(folder:GetAttribute("MergeEggOwnerUserId")) == localPlayer.UserId
        then
            return folder
        end
    end
    return nil
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
        return 0, #(CONFIG.waves or {})
    end
    return tonumber(world:GetAttribute("CurrentWave")) or 0,
        tonumber(world:GetAttribute("WaveCount")) or #(CONFIG.waves or {})
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
    root.Name = "Rail"
    root.AnchorPoint = Vector2.new(1, 0)
    root.Position = UDim2.new(1, -8, 0, 8)
    root.Size = UDim2.fromOffset(214, 10)
    root.AutomaticSize = Enum.AutomaticSize.Y
    root.BackgroundTransparency = 1
    root.Parent = gui
    require(script.Parent.Parent.UI.UIViewportScale).attach(root)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = root

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.fromOffset(214, 46)
    header.BackgroundColor3 = Color3.fromRGB(24, 30, 43)
    header.BackgroundTransparency = 0.05
    header.BorderSizePixel = 0
    header.LayoutOrder = 0
    header.Parent = root
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 7)
    headerCorner.Parent = header
    local headerStroke = Instance.new("UIStroke")
    headerStroke.Color = Color3.fromRGB(85, 150, 225)
    headerStroke.Transparency = 0.25
    headerStroke.Thickness = 1.5
    headerStroke.Parent = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(10, 5)
    title.Size = UDim2.new(1, -20, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.Text = "NPC TEAM 1"
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
    summary.TextSize = 11
    summary.TextXAlignment = Enum.TextXAlignment.Left
    summary.Parent = header

    local cards = {}
    local function clearCards()
        for slot, card in pairs(cards) do
            card.frame:Destroy()
            cards[slot] = nil
        end
    end

    local function cardFor(slot)
        local card = cards[slot]
        if card then
            return card
        end
        card = HudCard.createCard(root, {
            name = "NpcPet_" .. slot,
            layoutOrder = slot,
            width = 214,
        })
        card.frame.Active = false
        card.frame.Selectable = false
        HudCard.applyFunctionMark(card, nil)
        HudCard.applyHighlight(card, nil)
        cards[slot] = card
        return card
    end

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
            clearCards()
            return
        end

        local folder = teamFolder()
        if not folder then
            title.Text = tostring((CONFIG.team or {}).display_name or "NPC Team 1"):upper()
            summary.Text = "HATCH TO DEPLOY"
            clearCards()
            return
        end

        local expected = math.max(
            1,
            math.floor(
                tonumber(folder:GetAttribute("MergeEggExpectedPets")) or #(CONFIG.squad or {})
            )
        )
        local active = math.max(0, tonumber(folder:GetAttribute("MergeEggActivePets")) or 0)
        local state = tostring(folder:GetAttribute("MergeEggTeamState") or "Ready"):upper()
        local wave, waveCount = worldProgress()
        title.Text =
            tostring(folder:GetAttribute("MergeEggTeamDisplayName") or "NPC Team 1"):upper()
        summary.Text = string.format(
            "%s  •  %d/%d PETS  •  WAVE %d/%d",
            state,
            active,
            expected,
            wave,
            waveCount
        )
        summary.TextColor3 = state == "DEFEATED" and Color3.fromRGB(240, 105, 95)
            or state == "ENGAGED" and Color3.fromRGB(245, 190, 75)
            or Color3.fromRGB(175, 205, 230)

        local bySlot = {}
        for _, pet in ipairs(folder:GetChildren()) do
            if pet:IsA("Model") then
                bySlot[petSlot(pet)] = pet
            end
        end

        for slot = 1, expected do
            local card = cardFor(slot)
            local pet = bySlot[slot]
            local authored = (CONFIG.squad or {})[slot] or {}
            local petType = pet and pet:GetAttribute("PetType") or authored.pet or "pet"
            local roleId = pet and pet:GetAttribute("PetRole")
                or (PET_ROLES.by_type and PET_ROLES.by_type[petType])
                or PET_ROLES.default
                or "melee"
            local theme = ROLE_THEME[roleId] or ROLE_THEME.melee
            local hasBadge = PetBadge.apply(
                card.roleIcon,
                card.roleRing,
                PetBadge.elementForPetType(petType),
                roleId
            )
            card.roleChip.BackgroundColor3 = theme.color
            card.roleChip.BackgroundTransparency = hasBadge and 1 or 0
            card.roleGlyph.Visible = not hasBadge
            card.roleGlyph.Text = theme.glyph

            if pet then
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
                card.name.Text = prettyName(petType) .. targetText
                card.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
                card.fill.BackgroundColor3 = HudCard.healthColor(fraction)
                card.note.Text = string.format("%d%%", math.floor(fraction * 100 + 0.5))
            else
                card.name.Text = prettyName(petType)
                card.fill.Size = UDim2.fromScale(0, 1)
                card.fill.BackgroundColor3 = HudCard.HP_RED
                card.note.Text = "DEFEATED"
            end
        end
        for slot, card in pairs(cards) do
            if slot > expected then
                card.frame:Destroy()
                cards[slot] = nil
            end
        end
    end)
end

return MergeEggPrototypeObserver
