--[[
    PeopleListController — custom People list (replaces CoreGui PlayerList).

    Tab or the header toggles collapse (mobile uses the same header tap).
    A row opens a slide-out: headshot, how the Status title is earned,
    Examine Avatar (live in-game character), Friend / Block.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Locations = require(ReplicatedStorage.Shared.Locations)
local PeopleList = require(ReplicatedStorage.Shared.Game.PeopleList)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local POWER_ICONS = require(ReplicatedStorage.Configs:WaitForChild("power_icons"))
local placesConfig

local PeopleListController = {}
local started = false
local config
local ranksConfig
local gui
local root
local header
local headerLabel
local headerBar
local body
local columnHeader
local rowsFrame
local card
local cardPlayer
local cardTween
local characterSpin
local tooltip
local expanded = true
local rowGuis = {}
local watches = {}

local function rgb(color)
    if type(color) ~= "table" then
        return Color3.fromRGB(245, 248, 255)
    end
    return Color3.fromRGB(color[1] or 245, color[2] or 248, color[3] or 255)
end

local function look()
    return (config and config.look) or {}
end

local function disableCoreList()
    if not (config and config.disable_core_player_list == true) then
        return
    end
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    end)
end

local function isMergePlace()
    if placesConfig == nil then
        local configs = ReplicatedStorage:FindFirstChild("Configs")
        local places = configs and configs:FindFirstChild("places")
        if places then
            local ok, loaded = pcall(require, places)
            if ok then
                placesConfig = loaded
            end
        end
    end
    return placesConfig ~= nil and PlaceRuntime.isMerge(game.PlaceId, placesConfig)
end

local function dockState()
    local player = Players.LocalPlayer
    local camera = assert(Workspace.CurrentCamera, "People list requires CurrentCamera")
    local viewport = camera.ViewportSize
    return {
        tutorialOwnsCorner = player:GetAttribute("TutorialCornerOwned") == true,
        mergePlace = isMergePlace(),
        displayClass = tostring(player:GetAttribute("DisplayClass") or "desktop"),
        viewportWidth = viewport.X,
        viewportHeight = viewport.Y,
    }
end

local function listAllowed()
    local player = Players.LocalPlayer
    return PeopleList.shouldShow({
        largeMenuOpen = player:GetAttribute("LargeMenuOpen") == true,
        tutorialOwnsCorner = player:GetAttribute("TutorialCornerOwned") == true,
        peek = player:GetAttribute("PeopleListPeek") == true,
    })
end

local function cardSpec()
    return (config and config.card) or {}
end

local function hideTooltip()
    if tooltip then
        tooltip.Visible = false
    end
end

local function showTooltip(rowGui, text)
    if not (tooltip and rowGui and type(text) == "string" and text ~= "") then
        hideTooltip()
        return
    end
    tooltip.Text = text
    local rowMid = 0
    if root then
        -- Row Y inside the list. Both AbsolutePositions share inset space,
        -- so the difference is the offset from the list top.
        rowMid = (rowGui.AbsolutePosition.Y + rowGui.AbsoluteSize.Y * 0.5) - root.AbsolutePosition.Y
    end
    local place = PeopleList.hoverPlacement(config, dockState(), rowMid)
    tooltip.Position = UDim2.new(1 - place.rightScale, 0, 0, place.top)
    tooltip.Visible = true
end

local function hidePopover()
    if cardTween then
        cardTween:Cancel()
        cardTween = nil
    end
    if characterSpin then
        characterSpin:Disconnect()
        characterSpin = nil
    end
    if card then
        local viewport = card:FindFirstChild("CharacterView")
        if viewport then
            viewport.Visible = false
            for _, child in ipairs(viewport:GetChildren()) do
                child:Destroy()
            end
        end
        card.Visible = false
    end
    cardPlayer = nil
end

local function promptCore(name, player)
    local ok = pcall(function()
        StarterGui:SetCore(name, player)
    end)
    return ok
end

local function insideGui(guiObject, pos)
    if not (guiObject and guiObject.Visible) then
        return false
    end
    local p = guiObject.AbsolutePosition
    local s = guiObject.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function slideCard(visible)
    if not card then
        return
    end
    local place = PeopleList.cardPlacement(config, dockState())
    local shown = UDim2.new(1 - place.rightScale, 0, 0, place.top)
    local tucked = UDim2.new(1 - place.rightScale + place.widthScale, 0, 0, place.top)
    if cardTween then
        cardTween:Cancel()
        cardTween = nil
    end
    if visible then
        if not card.Visible then
            card.Position = tucked
            card.Visible = true
        end
        local tween = TweenService:Create(
            card,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = shown,
            }
        )
        cardTween = tween
        tween:Play()
    else
        hidePopover()
    end
end

local function fillHeadshot(image, userId)
    image.Image = ""
    task.spawn(function()
        local ok, thumb = pcall(function()
            return Players:GetUserThumbnailAsync(
                userId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)
        if ok and image.Parent and cardPlayer and cardPlayer.UserId == userId then
            image.Image = thumb
        end
    end)
end

local function clearCharacterView()
    if characterSpin then
        characterSpin:Disconnect()
        characterSpin = nil
    end
    if not card then
        return
    end
    local viewport = card:FindFirstChild("CharacterView")
    if not viewport then
        return
    end
    for _, child in ipairs(viewport:GetChildren()) do
        child:Destroy()
    end
    viewport.Visible = false
end

local function showLiveCharacter(player)
    if not card then
        return
    end
    local viewport = card:FindFirstChild("CharacterView")
    if not viewport then
        return
    end
    clearCharacterView()
    local character = player.Character
    if not character then
        viewport.Visible = true
        local missing = Instance.new("TextLabel")
        missing.BackgroundTransparency = 1
        missing.Size = UDim2.new(1, -12, 1, 0)
        missing.Position = UDim2.fromOffset(6, 0)
        missing.Font = Enum.Font.Gotham
        missing.TextSize = 12
        missing.TextWrapped = true
        missing.TextColor3 = rgb(look().muted)
        missing.Text = "They're not in the world right now."
        missing.Parent = viewport
        return
    end
    local oldArchivable = character.Archivable
    character.Archivable = true
    local ok, clone = pcall(function()
        return character:Clone()
    end)
    character.Archivable = oldArchivable
    if not ok or not clone then
        return
    end
    for _, descendant in ipairs(clone:GetDescendants()) do
        if
            descendant:IsA("BaseScript")
            or descendant:IsA("Tool")
            or descendant:IsA("BillboardGui")
            or descendant:IsA("Highlight")
        then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        elseif descendant:IsA("Humanoid") then
            descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    clone:PivotTo(CFrame.new())
    local world = Instance.new("WorldModel")
    world.Parent = viewport
    clone.Parent = world
    local cam = Instance.new("Camera")
    cam.Parent = viewport
    viewport.CurrentCamera = cam
    viewport.Visible = true
    local angle = 0
    characterSpin = RunService.RenderStepped:Connect(function(dt)
        angle += dt * 0.7
        cam.CFrame = CFrame.new(
            Vector3.new(math.sin(angle) * 6, 2.2, math.cos(angle) * 6),
            Vector3.new(0, 1.2, 0)
        )
    end)
end

local function setFriendLabel(button, player)
    button.Visible = player ~= Players.LocalPlayer
    button.Text = "Friend"
    if player == Players.LocalPlayer then
        return
    end
    task.spawn(function()
        local ok, isFriend = pcall(function()
            return Players.LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if button.Parent and cardPlayer == player then
            button.Text = (ok and isFriend) and "Unfriend" or "Friend"
        end
    end)
end

local function fillCard(player)
    if not card then
        return
    end
    local profile = PeopleList.profile(config, ranksConfig, {
        flags = PeopleList.flagsFromPlayer(player),
        displayName = player.DisplayName,
        username = player.Name,
        level = player:GetAttribute("ClaimedLevel"),
        ascensionUnlocked = player:GetAttribute("AscensionUnlocked") == true,
        veteranLevel = player:GetAttribute("VetLevel"),
        leaderboardTitle = player:GetAttribute("LeaderboardStatusTitle"),
        leaderboardRank = player:GetAttribute("LeaderboardStatusRank"),
        leaderboardHoverTitle = player:GetAttribute("LeaderboardStatusHoverTitle"),
        leaderboardHoverBoard = player:GetAttribute("LeaderboardStatusHoverBoard"),
        leaderboardBoardId = player:GetAttribute("LeaderboardStatusBoardId"),
        chosenTitle = player:GetAttribute("StatusBadgeLabel"),
        chosenKind = player:GetAttribute("StatusBadgeKind"),
        chosenSource = player:GetAttribute("StatusBadgeSource"),
        combatRank = player:GetAttribute("CombatRankLabel"),
        combatRankId = player:GetAttribute("CombatRank"),
        hugeHatcher = player:GetAttribute("HasHatchedHuge") == true,
        area = player:GetAttribute("CurrentArea"),
        layer = player:GetAttribute("CurrentLayer"),
        realm = player:GetAttribute("CurrentRealm"),
        inMission = player:GetAttribute("InMission") ~= nil,
    })
    local headshot = card:FindFirstChild("Headshot", true)
    local displayName = card:FindFirstChild("DisplayName", true)
    local username = card:FindFirstChild("Username", true)
    local heading = card:FindFirstChild("BadgeHeading", true)
    local statusTitle = card:FindFirstChild("StatusTitle", true)
    local statusBody = card:FindFirstChild("StatusBody", true)
    local crest = card:FindFirstChild("StatusCrest", true)
    local examine = card:FindFirstChild("Examine", true)
    local friendBtn = card:FindFirstChild("Friend", true)
    local blockBtn = card:FindFirstChild("Block", true)
    if headshot then
        fillHeadshot(headshot, player.UserId)
    end
    if displayName then
        displayName.Text = profile.displayName
    end
    if username then
        username.Text = profile.username
    end
    if heading then
        heading.Text = profile.badgeHeading
    end
    local rolesHeading = card:FindFirstChild("RolesHeading")
    local rolesList = card:FindFirstChild("Roles")
    local roles = profile.entitlements or {}
    if rolesHeading then
        rolesHeading.Text = profile.rolesHeading or "Roles"
        rolesHeading.Visible = #roles > 0
    end
    if rolesList then
        for _, child in ipairs(rolesList:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        rolesList.Visible = #roles > 0
        for index, entry in ipairs(roles) do
            local row = Instance.new("Frame")
            row.Name = "Role_" .. tostring(entry.id or index)
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(1, 0, 0, 18)
            row.LayoutOrder = index
            row.Parent = rolesList
            local mark = Instance.new("ImageLabel")
            mark.Name = "Icon"
            mark.BackgroundTransparency = 1
            mark.Size = UDim2.fromOffset(16, 16)
            mark.ScaleType = Enum.ScaleType.Fit
            mark.Parent = row
            local glyph = Instance.new("TextLabel")
            glyph.Name = "Glyph"
            glyph.BackgroundTransparency = 1
            glyph.Size = UDim2.fromOffset(16, 16)
            glyph.Font = Enum.Font.GothamBold
            glyph.TextSize = 12
            glyph.TextColor3 = rgb(look().text)
            glyph.Text = ""
            glyph.Parent = row
            local image = ""
            if type(entry.icon) == "table" then
                image = POWER_ICONS.discFor(entry.icon.element, entry.icon.symbol) or ""
            end
            if image ~= "" then
                mark.Image = image
                mark.Visible = true
                glyph.Visible = false
            else
                mark.Visible = false
                glyph.Text = type(entry.glyph) == "string" and entry.glyph or ""
                glyph.Visible = glyph.Text ~= ""
            end
            local name = Instance.new("TextLabel")
            name.BackgroundTransparency = 1
            name.Position = UDim2.fromOffset(20, 0)
            name.Size = UDim2.new(1, -20, 1, 0)
            name.Font = Enum.Font.Gotham
            name.TextSize = 12
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd
            name.TextColor3 = rgb(look().text)
            name.Text = tostring(entry.label or "")
            name.Parent = row
        end
    end
    if statusTitle then
        statusTitle.Text = profile.inspect.title
    end
    if statusBody then
        statusBody.Text = profile.inspect.body
    end
    if crest then
        local icon = profile.inspect.icon
        local hasIcon = type(icon) == "string" and icon ~= ""
        crest.Image = hasIcon and icon or ""
        crest.Visible = hasIcon
        if statusTitle then
            statusTitle.Position = UDim2.fromOffset(hasIcon and 22 or 0, 0)
            statusTitle.Size = UDim2.new(1, hasIcon and -22 or 0, 1, 0)
        end
    end
    if examine then
        examine.Text = profile.examineLabel
    end
    local social = (config and config.social) or {}
    if friendBtn then
        friendBtn.Visible = social.friend ~= false and player ~= Players.LocalPlayer
        setFriendLabel(friendBtn, player)
    end
    if blockBtn then
        blockBtn.Visible = social.block ~= false and player ~= Players.LocalPlayer
    end
    clearCharacterView()
end

local function openCard(player)
    if not card then
        return
    end
    if cardPlayer == player and card.Visible then
        hidePopover()
        return
    end
    cardPlayer = player
    fillCard(player)
    slideCard(true)
end

local function inspectPlayer(player)
    local flags = PeopleList.flagsFromPlayer(player)
    local row = PeopleList.row(config, ranksConfig, {
        flags = flags,
        displayName = player.DisplayName,
        level = player:GetAttribute("ClaimedLevel"),
        ascensionUnlocked = player:GetAttribute("AscensionUnlocked") == true,
        veteranLevel = player:GetAttribute("VetLevel"),
        leaderboardTitle = player:GetAttribute("LeaderboardStatusTitle"),
        leaderboardRank = player:GetAttribute("LeaderboardStatusRank"),
        leaderboardHoverTitle = player:GetAttribute("LeaderboardStatusHoverTitle"),
        leaderboardHoverBoard = player:GetAttribute("LeaderboardStatusHoverBoard"),
        leaderboardBoardId = player:GetAttribute("LeaderboardStatusBoardId"),
        chosenTitle = player:GetAttribute("StatusBadgeLabel"),
        chosenKind = player:GetAttribute("StatusBadgeKind"),
        chosenSource = player:GetAttribute("StatusBadgeSource"),
        combatRank = player:GetAttribute("CombatRankLabel"),
        combatRankId = player:GetAttribute("CombatRank"),
        hugeHatcher = player:GetAttribute("HasHatchedHuge") == true,
        area = player:GetAttribute("CurrentArea"),
        layer = player:GetAttribute("CurrentLayer"),
        realm = player:GetAttribute("CurrentRealm"),
        inMission = player:GetAttribute("InMission") ~= nil,
    })
    return row
end

local function applyNameBadge(nameBtn, row)
    local badge = row.badge
    local iconSpec = badge and badge.icon
    local image = ""
    if type(iconSpec) == "table" then
        image = POWER_ICONS.discFor(iconSpec.element, iconSpec.symbol) or ""
    end
    local icon = nameBtn:FindFirstChild("Badge")
    if not icon then
        icon = Instance.new("ImageLabel")
        icon.Name = "Badge"
        icon.BackgroundTransparency = 1
        icon.BorderSizePixel = 0
        icon.AnchorPoint = Vector2.new(0, 0.5)
        icon.Position = UDim2.new(0, 0, 0.5, 0)
        icon.Size = UDim2.fromOffset(16, 16)
        icon.ScaleType = Enum.ScaleType.Fit
        icon.ZIndex = nameBtn.ZIndex
        icon.Parent = nameBtn
    end
    local pad = nameBtn:FindFirstChild("BadgePad")
    if not pad then
        pad = Instance.new("UIPadding")
        pad.Name = "BadgePad"
        pad.Parent = nameBtn
    end
    if image ~= "" then
        icon.Image = image
        icon.Visible = true
        -- Sit in the left gutter so UIPadding does not shove the disc over the name.
        icon.Position = UDim2.new(0, -18, 0.5, 0)
        pad.PaddingLeft = UDim.new(0, 18)
    else
        icon.Image = ""
        icon.Visible = false
        icon.Position = UDim2.new(0, 0, 0.5, 0)
        pad.PaddingLeft = UDim.new(0, 0)
    end
end

local function applyRow(rowGui, player)
    local row = inspectPlayer(player)
    local nameBtn = rowGui:FindFirstChild("Name")
    local rankLabel = rowGui:FindFirstChild("Rank")
    local statusBtn = rowGui:FindFirstChild("Status")
    local locationLabel = rowGui:FindFirstChild("Location")
    if nameBtn then
        nameBtn.Text = row.name
        applyNameBadge(nameBtn, row)
    end
    if rankLabel then
        rankLabel.Text = row.rank
    end
    if statusBtn then
        statusBtn.Text = row.status
    end
    if locationLabel then
        locationLabel.Text = row.location
    end
    rowGui:SetAttribute("HoverText", row.hover or "")
end

local function columnWidths()
    local cols = (config and config.columns) or {}
    local total = 0
    for _, col in ipairs(cols) do
        total += math.max(0, tonumber(col.width) or 0)
    end
    assert(total > 0, "people_list.columns must contain positive viewport shares")
    local out = {}
    for _, col in ipairs(cols) do
        table.insert(out, math.max(0, tonumber(col.width) or 0) / total)
    end
    return out
end

local function makeText(className, name, parent, props)
    local inst = Instance.new(className)
    inst.Name = name
    inst.BackgroundTransparency = 1
    inst.BorderSizePixel = 0
    inst.Font = Enum.Font.Gotham
    inst.TextScaled = true
    inst.TextColor3 = rgb(look().text)
    inst.TextTruncate = Enum.TextTruncate.AtEnd
    inst.TextXAlignment = Enum.TextXAlignment.Left
    for key, value in pairs(props or {}) do
        inst[key] = value
    end
    inst.Parent = parent
    return inst
end

local function layoutRow(holder, widths)
    local gutter = PeopleList.layout(config, dockState()).columnGutter
    local x = gutter
    local kids = { "Name", "Rank", "Status", "Location" }
    for i, name in ipairs(kids) do
        local child = holder:FindFirstChild(name)
        local width = widths[i]
        if child then
            child.Position = UDim2.fromScale(x, 0.1)
            child.Size = UDim2.new(width - gutter, 0, 0.8, 0)
        end
        x += width
    end
end

local function ensureRow(player)
    local existing = rowGuis[player]
    if existing and existing.Parent then
        applyRow(existing, player)
        return existing
    end
    local height = PeopleList.layout(config, dockState()).rowHeight
    local widths = columnWidths()
    local row = Instance.new("Frame")
    row.Name = "Row_" .. player.UserId
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, height)
    row.Parent = rowsFrame

    local nameBtn = makeText("TextButton", "Name", row, {
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
    })
    makeText("TextLabel", "Rank", row, {
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local statusBtn = makeText("TextButton", "Status", row, {
        AutoButtonColor = false,
    })
    makeText("TextLabel", "Location", row, {
        TextColor3 = rgb(look().muted),
    })
    layoutRow(row, widths)
    applyRow(row, player)

    local function hover(on)
        row.BackgroundTransparency = on and (tonumber(look().row_hover_transparency) or 0.72) or 1
    end
    row.MouseEnter:Connect(function()
        hover(true)
        showTooltip(row, row:GetAttribute("HoverText"))
    end)
    row.MouseLeave:Connect(function()
        hover(false)
        hideTooltip()
    end)
    nameBtn.Activated:Connect(function()
        openCard(player)
    end)
    statusBtn.Activated:Connect(function()
        openCard(player)
    end)
    rowGuis[player] = row
    return row
end

local function orderedPlayers()
    local localPlayer = Players.LocalPlayer
    local others = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            table.insert(others, player)
        end
    end
    table.sort(others, function(a, b)
        return string.lower(a.DisplayName) < string.lower(b.DisplayName)
    end)
    local list = { localPlayer }
    for _, player in ipairs(others) do
        table.insert(list, player)
    end
    return list
end

local function refreshRows()
    if not rowsFrame then
        return
    end
    local seen = {}
    for index, player in ipairs(orderedPlayers()) do
        local row = ensureRow(player)
        row.LayoutOrder = index
        row.Visible = true
        seen[player] = true
    end
    for player, row in pairs(rowGuis) do
        if not seen[player] then
            row:Destroy()
            rowGuis[player] = nil
        end
    end
    local count = #Players:GetPlayers()
    if headerLabel then
        headerLabel.Text = ("Players  %d"):format(count)
    end
    if rowsFrame then
        local dimensions = PeopleList.layout(config, dockState())
        local rowH = dimensions.rowHeight
        local maxBody = dimensions.maximumBodyHeight
        rowsFrame.Size = UDim2.new(1, 0, 0, math.clamp(count * rowH, rowH, maxBody))
    end
end

local function applyExpanded()
    if body then
        body.Visible = expanded == true
    end
    if header then
        header.Text = expanded and "  ▾" or "  ▸"
    end
end

local function setExpanded(on)
    expanded = on == true
    hidePopover()
    hideTooltip()
    applyExpanded()
end

local function toggleExpanded()
    if UserInputService:GetFocusedTextBox() then
        return
    end
    if not listAllowed() then
        return
    end
    setExpanded(not expanded)
end

local function dockLayout()
    if not (root and config) then
        return
    end
    local player = Players.LocalPlayer
    local state = dockState()
    local dimensions = PeopleList.layout(config, state)
    root.Position = UDim2.new(1 - dimensions.rightScale, 0, 0, dimensions.top)
    root.Size = UDim2.new(dimensions.widthScale, 0, 0, dimensions.headerHeight)
    player:SetAttribute("PeopleListTop", dimensions.top)
    if headerBar then
        headerBar.Size = UDim2.new(1, 0, 0, dimensions.headerHeight)
    end
    if columnHeader then
        columnHeader.Size = UDim2.new(1, 0, 0, dimensions.columnHeaderHeight)
    end
    if rowsFrame then
        rowsFrame.Position = UDim2.new(0, 0, 0, dimensions.columnHeaderHeight)
    end
    local widths = columnWidths()
    if columnHeader then
        layoutRow(columnHeader, widths)
    end
    for _, row in pairs(rowGuis) do
        if row.Parent then
            row.Size = UDim2.new(1, 0, 0, dimensions.rowHeight)
            layoutRow(row, widths)
        end
    end
    if card then
        local place = PeopleList.cardPlacement(config, state)
        card.Position = UDim2.new(1 - place.rightScale, 0, 0, place.top)
        card.Size = UDim2.new(place.widthScale, 0, 0, 0)
    end
    refreshRows()
end

local function applyVisibility()
    disableCoreList()
    if not gui then
        return
    end
    local allowed = listAllowed()
    gui.Enabled = allowed
    if not allowed then
        hidePopover()
        hideTooltip()
    else
        dockLayout()
    end
end

local function watchPlayer(player)
    if watches[player] then
        return
    end
    local conns = {}
    local function bump()
        if rowGuis[player] then
            applyRow(rowGuis[player], player)
        else
            refreshRows()
        end
        if cardPlayer == player and card and card.Visible then
            fillCard(player)
        end
    end
    for _, name in ipairs({
        "IsOwner",
        "IsAdmin",
        "IsBetaTester",
        "IsCreator",
        "HasVIPPass",
        "FounderLegacyActive",
        "CombatRank",
        "CombatRankLabel",
        "StatusBadgeLabel",
        "StatusBadgeKind",
        "StatusBadgeSource",
        "LeaderboardStatusTitle",
        "LeaderboardStatusBoardId",
        "LeaderboardStatusRank",
        "LeaderboardStatusHoverTitle",
        "LeaderboardStatusHoverBoard",
        "HasHatchedHuge",
        "Level",
        "ClaimedLevel",
        "AscensionUnlocked",
        "VetLevel",
        "CurrentArea",
        "CurrentLayer",
        "CurrentRealm",
        "InMission",
    }) do
        table.insert(conns, player:GetAttributeChangedSignal(name):Connect(bump))
    end
    table.insert(conns, player:GetPropertyChangedSignal("DisplayName"):Connect(bump))
    watches[player] = conns
end

local function unwatchPlayer(player)
    local conns = watches[player]
    if conns then
        for _, conn in ipairs(conns) do
            conn:Disconnect()
        end
    end
    watches[player] = nil
    if cardPlayer == player then
        hidePopover()
    end
    if rowGuis[player] then
        rowGuis[player]:Destroy()
        rowGuis[player] = nil
    end
end

local function build()
    local player = Players.LocalPlayer
    local pg = player:WaitForChild("PlayerGui")
    local knobs = look()
    local state = dockState()
    local dimensions = PeopleList.layout(config, state)
    local headerH = dimensions.headerHeight
    local maxBody = dimensions.maximumBodyHeight

    gui = Instance.new("ScreenGui")
    gui.Name = "PeopleListGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    -- Above the quest pill (90) and Status chip (91) so a row hover
    -- that extends left of the list is not buried under those docks.
    gui.DisplayOrder = 92
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    root = Instance.new("Frame")
    root.Name = "Root"
    root.AnchorPoint = Vector2.new(1, 0)
    -- Under the quest pill. Tip may draw over this; quest tracker stays on top.
    root.Position = UDim2.new(1 - dimensions.rightScale, 0, 0, dimensions.top)
    player:SetAttribute("PeopleListTop", dimensions.top)
    root.Size = UDim2.new(dimensions.widthScale, 0, 0, headerH)
    root.AutomaticSize = Enum.AutomaticSize.Y
    root.BackgroundColor3 = rgb(knobs.background)
    root.BackgroundTransparency = tonumber(knobs.background_transparency) or 0.42
    root.BorderSizePixel = 0
    root.Parent = gui

    tooltip = Instance.new("TextLabel")
    tooltip.Name = "HoverTip"
    tooltip.Visible = false
    tooltip.ZIndex = 12
    tooltip.AnchorPoint = Vector2.new(1, 0.5)
    tooltip.AutomaticSize = Enum.AutomaticSize.XY
    tooltip.BackgroundColor3 = rgb(knobs.background)
    tooltip.BackgroundTransparency = 0.08
    tooltip.BorderSizePixel = 0
    tooltip.Font = Enum.Font.Gotham
    tooltip.TextSize = 12
    tooltip.TextColor3 = rgb(knobs.text)
    tooltip.TextXAlignment = Enum.TextXAlignment.Left
    tooltip.TextWrapped = true
    tooltip.Parent = gui
    local tipPad = Instance.new("UIPadding")
    tipPad.PaddingTop = UDim.new(0, 6)
    tipPad.PaddingBottom = UDim.new(0, 6)
    tipPad.PaddingLeft = UDim.new(0, 8)
    tipPad.PaddingRight = UDim.new(0, 8)
    tipPad.Parent = tooltip
    local tipLimit = Instance.new("UISizeConstraint")
    tipLimit.MaxSize = Vector2.new(280, 80)
    tipLimit.Parent = tooltip
    local tipCorner = Instance.new("UICorner")
    tipCorner.CornerRadius = UDim.new(0, 6)
    tipCorner.Parent = tooltip
    local tipStroke = Instance.new("UIStroke")
    tipStroke.Color = rgb(knobs.stroke)
    tipStroke.Transparency = 0.4
    tipStroke.Parent = tooltip

    local rootCorner = Instance.new("UICorner")
    rootCorner.CornerRadius = UDim.new(0, 8)
    rootCorner.Parent = root
    local stroke = Instance.new("UIStroke")
    stroke.Color = rgb(knobs.stroke)
    stroke.Transparency = tonumber(knobs.stroke_transparency) or 0.55
    stroke.Thickness = 1
    stroke.Parent = root
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = root

    header = Instance.new("TextButton")
    header.Name = "ToggleHint"
    header.AutoButtonColor = false
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(0.05, 0, 1, 0)
    header.Position = UDim2.fromScale(0.95, 0)
    header.Font = Enum.Font.GothamBold
    header.TextScaled = true
    header.TextColor3 = rgb(knobs.muted)
    header.Text = "  ▾"
    header.ZIndex = 2

    headerBar = Instance.new("TextButton")
    headerBar.Name = "Header"
    headerBar.AutoButtonColor = false
    headerBar.BackgroundColor3 = rgb(knobs.background)
    headerBar.BackgroundTransparency = tonumber(knobs.header_transparency) or 0.32
    headerBar.BorderSizePixel = 0
    headerBar.LayoutOrder = 1
    headerBar.Size = UDim2.new(1, 0, 0, headerH)
    headerBar.Parent = root
    header.Parent = headerBar
    headerLabel = Instance.new("TextLabel")
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size = UDim2.new(0.88, 0, 1, 0)
    headerLabel.Position = UDim2.fromScale(0.02, 0)
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextScaled = true
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.TextColor3 = rgb(knobs.text)
    headerLabel.Text = "Players"
    headerLabel.Parent = headerBar
    local tabHint = Instance.new("TextLabel")
    tabHint.BackgroundTransparency = 1
    tabHint.Size = UDim2.new(0.08, 0, 1, 0)
    tabHint.Position = UDim2.fromScale(0.87, 0)
    tabHint.Font = Enum.Font.Gotham
    tabHint.TextScaled = true
    tabHint.TextColor3 = rgb(knobs.muted)
    tabHint.Text = "Tab"
    tabHint.Parent = headerBar
    headerBar.Activated:Connect(toggleExpanded)

    body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.LayoutOrder = 2
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Parent = root

    columnHeader = Instance.new("Frame")
    columnHeader.Name = "Columns"
    columnHeader.BackgroundTransparency = 1
    columnHeader.Size = UDim2.new(1, 0, 0, dimensions.columnHeaderHeight)
    columnHeader.Parent = body
    local widths = columnWidths()
    local labels = { "Name", "Rank", "Status", "Location" }
    for i, name in ipairs(labels) do
        makeText("TextLabel", name, columnHeader, {
            Text = name,
            TextColor3 = rgb(knobs.muted),
            TextXAlignment = i == 2 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
        })
    end
    layoutRow(columnHeader, widths)

    rowsFrame = Instance.new("ScrollingFrame")
    rowsFrame.Name = "Rows"
    rowsFrame.BackgroundTransparency = 1
    rowsFrame.BorderSizePixel = 0
    rowsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rowsFrame.CanvasSize = UDim2.new()
    rowsFrame.ScrollBarThickness = 4
    rowsFrame.ScrollBarImageTransparency = 0.3
    rowsFrame.Size = UDim2.new(1, 0, 0, maxBody)
    rowsFrame.Position = UDim2.new(0, 0, 0, dimensions.columnHeaderHeight)
    rowsFrame.Parent = body
    local rowList = Instance.new("UIListLayout")
    rowList.SortOrder = Enum.SortOrder.LayoutOrder
    rowList.Parent = rowsFrame

    local place = PeopleList.cardPlacement(config, dockState())
    local spec = cardSpec()
    local headshotSize = place.headshotHeight
    local viewH = place.viewportHeight

    card = Instance.new("Frame")
    card.Name = "ProfileCard"
    card.Visible = false
    card.ZIndex = 10
    card.AnchorPoint = Vector2.new(1, 0)
    -- Sibling of Root so Root's UIListLayout cannot pull it into the row stack.
    -- Right inset is list width + gap + list right inset (PeopleList.cardPlacement).
    card.Position = UDim2.new(1 - place.rightScale, 0, 0, place.top)
    card.Size = UDim2.new(place.widthScale, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = rgb(knobs.background)
    card.BackgroundTransparency = 0.12
    card.BorderSizePixel = 0
    card.Parent = gui
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = rgb(knobs.stroke)
    cardStroke.Transparency = 0.4
    cardStroke.Parent = card
    local cardPad = Instance.new("UIPadding")
    cardPad.PaddingTop = UDim.new(0, 10)
    cardPad.PaddingBottom = UDim.new(0, 10)
    cardPad.PaddingLeft = UDim.new(0, 10)
    cardPad.PaddingRight = UDim.new(0, 10)
    cardPad.Parent = card
    local cardList = Instance.new("UIListLayout")
    cardList.FillDirection = Enum.FillDirection.Vertical
    cardList.SortOrder = Enum.SortOrder.LayoutOrder
    cardList.Padding = UDim.new(0, 8)
    cardList.Parent = card

    local headerRow = Instance.new("Frame")
    headerRow.Name = "HeaderRow"
    headerRow.BackgroundTransparency = 1
    headerRow.Size = UDim2.new(1, 0, 0, headshotSize)
    headerRow.LayoutOrder = 1
    headerRow.Parent = card

    local headshot = Instance.new("ImageLabel")
    headshot.Name = "Headshot"
    headshot.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
    headshot.Size = UDim2.fromOffset(headshotSize, headshotSize)
    headshot.ScaleType = Enum.ScaleType.Crop
    headshot.Parent = headerRow
    local headCorner = Instance.new("UICorner")
    headCorner.CornerRadius = UDim.new(0, 8)
    headCorner.Parent = headshot

    local names = Instance.new("Frame")
    names.BackgroundTransparency = 1
    names.Position = UDim2.fromOffset(headshotSize + 8, 6)
    names.Size = UDim2.new(1, -(headshotSize + 8), 1, -6)
    names.Parent = headerRow
    local displayName = Instance.new("TextLabel")
    displayName.Name = "DisplayName"
    displayName.BackgroundTransparency = 1
    displayName.Size = UDim2.new(1, 0, 0, 20)
    displayName.Font = Enum.Font.GothamBold
    displayName.TextSize = 15
    displayName.TextXAlignment = Enum.TextXAlignment.Left
    displayName.TextTruncate = Enum.TextTruncate.AtEnd
    displayName.TextColor3 = rgb(knobs.text)
    displayName.Text = ""
    displayName.Parent = names
    local username = Instance.new("TextLabel")
    username.Name = "Username"
    username.BackgroundTransparency = 1
    username.Position = UDim2.fromOffset(0, 22)
    username.Size = UDim2.new(1, 0, 0, 16)
    username.Font = Enum.Font.Gotham
    username.TextSize = 12
    username.TextXAlignment = Enum.TextXAlignment.Left
    username.TextTruncate = Enum.TextTruncate.AtEnd
    username.TextColor3 = rgb(knobs.muted)
    username.Text = ""
    username.Parent = names

    local rolesHeading = Instance.new("TextLabel")
    rolesHeading.Name = "RolesHeading"
    rolesHeading.BackgroundTransparency = 1
    rolesHeading.LayoutOrder = 2
    rolesHeading.Visible = false
    rolesHeading.Size = UDim2.new(1, 0, 0, 14)
    rolesHeading.Font = Enum.Font.GothamBold
    rolesHeading.TextSize = 11
    rolesHeading.TextXAlignment = Enum.TextXAlignment.Left
    rolesHeading.TextColor3 = rgb(knobs.muted)
    rolesHeading.Text = spec.roles_heading or "Roles"
    rolesHeading.Parent = card

    local rolesList = Instance.new("Frame")
    rolesList.Name = "Roles"
    rolesList.BackgroundTransparency = 1
    rolesList.LayoutOrder = 3
    rolesList.Visible = false
    rolesList.AutomaticSize = Enum.AutomaticSize.Y
    rolesList.Size = UDim2.new(1, 0, 0, 0)
    rolesList.Parent = card
    local rolesLayout = Instance.new("UIListLayout")
    rolesLayout.FillDirection = Enum.FillDirection.Vertical
    rolesLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rolesLayout.Padding = UDim.new(0, 2)
    rolesLayout.Parent = rolesList

    local heading = Instance.new("TextLabel")
    heading.Name = "BadgeHeading"
    heading.BackgroundTransparency = 1
    heading.LayoutOrder = 4
    heading.Size = UDim2.new(1, 0, 0, 14)
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 11
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.TextColor3 = rgb(knobs.muted)
    heading.Text = spec.badge_heading or "How you get this"
    heading.Parent = card

    local statusRow = Instance.new("Frame")
    statusRow.Name = "StatusRow"
    statusRow.BackgroundTransparency = 1
    statusRow.LayoutOrder = 5
    statusRow.Size = UDim2.new(1, 0, 0, 20)
    statusRow.Parent = card
    local crest = Instance.new("ImageLabel")
    crest.Name = "StatusCrest"
    crest.BackgroundTransparency = 1
    crest.Size = UDim2.fromOffset(18, 18)
    crest.ScaleType = Enum.ScaleType.Fit
    crest.Visible = false
    crest.Parent = statusRow
    local statusTitle = Instance.new("TextLabel")
    statusTitle.Name = "StatusTitle"
    statusTitle.BackgroundTransparency = 1
    statusTitle.Position = UDim2.fromOffset(22, 0)
    statusTitle.Size = UDim2.new(1, -22, 1, 0)
    statusTitle.Font = Enum.Font.GothamBold
    statusTitle.TextSize = 13
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    statusTitle.TextTruncate = Enum.TextTruncate.AtEnd
    statusTitle.TextColor3 = rgb(knobs.text)
    statusTitle.Text = ""
    statusTitle.Parent = statusRow

    local statusBody = Instance.new("TextLabel")
    statusBody.Name = "StatusBody"
    statusBody.BackgroundTransparency = 1
    statusBody.LayoutOrder = 6
    statusBody.AutomaticSize = Enum.AutomaticSize.Y
    statusBody.Size = UDim2.new(1, 0, 0, 0)
    statusBody.Font = Enum.Font.Gotham
    statusBody.TextSize = 12
    statusBody.TextWrapped = true
    statusBody.TextXAlignment = Enum.TextXAlignment.Left
    statusBody.TextYAlignment = Enum.TextYAlignment.Top
    statusBody.TextColor3 = rgb(knobs.text)
    statusBody.Text = ""
    statusBody.Parent = card

    local function makeAction(name, order, label)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.AutoButtonColor = true
        btn.LayoutOrder = order
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.TextColor3 = rgb(knobs.text)
        btn.Text = label
        btn.Parent = card
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        return btn
    end

    local examine = makeAction("Examine", 7, spec.examine_label or "Examine Avatar")
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "CharacterView"
    viewport.LayoutOrder = 8
    viewport.Visible = false
    viewport.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    viewport.BackgroundTransparency = 0.15
    viewport.BorderSizePixel = 0
    viewport.Size = UDim2.new(1, 0, 0, viewH)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.Ambient = Color3.fromRGB(180, 180, 190)
    viewport.Parent = card
    local viewCorner = Instance.new("UICorner")
    viewCorner.CornerRadius = UDim.new(0, 6)
    viewCorner.Parent = viewport

    local friendBtn = makeAction("Friend", 9, "Friend")
    local blockBtn = makeAction("Block", 10, "Block")

    examine.Activated:Connect(function()
        if not cardPlayer then
            return
        end
        if viewport.Visible then
            clearCharacterView()
        else
            showLiveCharacter(cardPlayer)
        end
    end)
    friendBtn.Activated:Connect(function()
        if not cardPlayer or cardPlayer == Players.LocalPlayer then
            return
        end
        if friendBtn.Text == "Unfriend" then
            promptCore("PromptUnfriend", cardPlayer)
        else
            promptCore("PromptSendFriendRequest", cardPlayer)
        end
    end)
    blockBtn.Activated:Connect(function()
        if not cardPlayer or cardPlayer == Players.LocalPlayer then
            return
        end
        promptCore("PromptBlockPlayer", cardPlayer)
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not card.Visible then
            return
        end
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        local pos = input.Position
        if insideGui(card, pos) or insideGui(root, pos) then
            return
        end
        hidePopover()
    end)
end

local function bindToggle()
    local keyName = config.toggle and config.toggle.key or "Tab"
    local key = Enum.KeyCode[keyName] or Enum.KeyCode.Tab
    ContextActionService:BindActionAtPriority("PeopleListToggle", function(_, state)
        if state ~= Enum.UserInputState.Begin then
            return Enum.ContextActionResult.Pass
        end
        toggleExpanded()
        return Enum.ContextActionResult.Sink
    end, false, 3000, key)
end

function PeopleListController.start()
    if started then
        return PeopleListController
    end
    started = true
    local ConfigLoader = require(Locations.ConfigLoader)
    config = ConfigLoader:LoadConfig("people_list")
    ranksConfig = ConfigLoader:LoadConfig("combat_ranks")
    if config.enabled ~= true then
        return PeopleListController
    end
    expanded = config.toggle == nil or config.toggle.start_expanded ~= false
    disableCoreList()
    build()
    applyExpanded()
    applyVisibility()
    bindToggle()

    local localPlayer = Players.LocalPlayer
    for _, name in ipairs({
        "LargeMenuOpen",
        "TutorialCornerOwned",
        "PeopleListPeek",
        "DisplayClass",
    }) do
        localPlayer:GetAttributeChangedSignal(name):Connect(applyVisibility)
    end
    local viewportConnection
    local function watchCamera(camera)
        if viewportConnection then
            viewportConnection:Disconnect()
            viewportConnection = nil
        end
        if camera then
            viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(dockLayout)
        end
        dockLayout()
    end
    watchCamera(Workspace.CurrentCamera)
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        watchCamera(Workspace.CurrentCamera)
    end)

    Players.PlayerAdded:Connect(function(player)
        watchPlayer(player)
        refreshRows()
    end)
    Players.PlayerRemoving:Connect(function(player)
        unwatchPlayer(player)
        refreshRows()
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        watchPlayer(player)
    end
    refreshRows()

    task.spawn(function()
        for _ = 1, 20 do
            disableCoreList()
            task.wait(0.25)
        end
    end)
    return PeopleListController
end

return PeopleListController
