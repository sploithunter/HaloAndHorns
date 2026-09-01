-- Walk-up bulwark management menu. All state and purchases remain server-authoritative; this
-- component only presents the state returned by MergeEggPrototypeService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CURRENCIES = require(ReplicatedStorage.Configs:WaitForChild("currencies"))

local MergeBulwarkMenu = {}

local function currencyThumbnail(currencyId)
    for _, currency in ipairs(CURRENCIES) do
        if currency.id == currencyId then
            local raw = tostring(currency.icon_asset or currency.icon or "")
            local assetId = string.match(raw, "(%d+)")
            if assetId then
                return string.format("rbxthumb://type=Asset&id=%s&w=150&h=150", assetId)
            end
            return nil
        end
    end
    error("Currency config is missing: " .. currencyId)
end

local WAYCOIN_ICON = currencyThumbnail("hall_coins")
local GEM_ICON = currencyThumbnail("gems")
local FAMILY_COLORS = {
    Color3.fromRGB(210, 145, 55),
    Color3.fromRGB(125, 135, 155),
    Color3.fromRGB(42, 145, 170),
    Color3.fromRGB(220, 70, 75),
    Color3.fromRGB(70, 170, 90),
    Color3.fromRGB(125, 90, 205),
}

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius or 12)
    value.Parent = parent
    return value
end

local function stroke(parent, color, thickness)
    local value = Instance.new("UIStroke")
    value.Color = color
    value.Thickness = thickness or 2
    value.Parent = parent
    return value
end

local function padScale(parent, left, right, top, bottom)
    local value = Instance.new("UIPadding")
    value.PaddingLeft = UDim.new(left, 0)
    value.PaddingRight = UDim.new(right, 0)
    value.PaddingTop = UDim.new(top, 0)
    value.PaddingBottom = UDim.new(bottom, 0)
    value.Parent = parent
    return value
end

local function fill(parent)
    local item = Instance.new("UIFlexItem")
    item.FlexMode = Enum.UIFlexMode.Fill
    item.Parent = parent
    return item
end

local function aspect(parent, ratio)
    local value = Instance.new("UIAspectRatioConstraint")
    value.AspectRatio = ratio
    value.Parent = parent
    return value
end

local function textLimit(parent, maxSize)
    local value = Instance.new("UITextSizeConstraint")
    value.MaxTextSize = maxSize
    value.MinTextSize = 10
    value.Parent = parent
    return value
end

local function label(parent, name, text, size, bold)
    local value = Instance.new("TextLabel")
    value.Name = name
    value.Size = size or UDim2.fromScale(1, 1)
    value.BackgroundTransparency = 1
    value.Font = bold and Enum.Font.GothamBlack or Enum.Font.Gotham
    value.Text = text
    value.TextColor3 = Color3.new(1, 1, 1)
    value.TextScaled = true
    value.TextWrapped = true
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.Parent = parent
    return value
end

-- The preview art was authored and uploaded specifically to show every static bulwark in the same
-- long, side-to-side presentation. Land Sharks intentionally use their own presentation. Do not
-- rebuild these cards from live 3D models: a generic viewport camera silently destroys that visual
-- contract whenever a mesh pivot, bounds, or import orientation changes.
local function makePreviewImage(parent, name)
    local pane = Instance.new("Frame")
    pane.Name = name
    pane.Size = UDim2.fromScale(1, 1)
    pane.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
    pane.BorderSizePixel = 0
    pane.ClipsDescendants = true
    pane.Parent = parent
    corner(pane, 10)

    local image = Instance.new("ImageLabel")
    image.Name = "Preview"
    image.Size = UDim2.fromScale(1, 1)
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.ScaleType = Enum.ScaleType.Fit
    image.ResampleMode = Enum.ResamplerMode.Default
    image.Parent = pane

    return {
        pane = pane,
        image = image,
        key = "",
    }
end

local function showPreview(slot, family, tier)
    local familyId = type(family) == "table" and family.id or nil
    local resolvedTier = math.max(0, math.floor(tonumber(tier) or 0))
    local previewIds = type(family) == "table" and family.previewAssetIds or nil
    local assetId = type(previewIds) == "table" and previewIds[resolvedTier] or nil
    local key =
        string.format("%s:%d:%s", tostring(familyId or ""), resolvedTier, tostring(assetId or ""))
    if key == slot.key then
        return
    end
    slot.key = key
    slot.image.Image = if assetId and tostring(assetId) ~= ""
        then string.format("rbxthumb://type=Asset&id=%s&w=420&h=420", tostring(assetId))
        else ""
end

function MergeBulwarkMenu.new(parent, onAction)
    local controller = {}
    local playerGui = parent
    if parent and parent:IsA("LayerCollector") then
        playerGui = parent.Parent
    elseif parent then
        playerGui = parent:FindFirstAncestorWhichIsA("PlayerGui") or parent
    end

    local screen = Instance.new("ScreenGui")
    screen.Name = "MergeBulwarkMenuGui"
    screen.IgnoreGuiInset = true
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 120
    screen.Enabled = true
    screen.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Name = "MergeBulwarkMenu"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(4, 7, 14)
    overlay.BackgroundTransparency = 0.35
    overlay.BorderSizePixel = 0
    overlay.Visible = false
    overlay.Active = true
    overlay.Parent = screen

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromScale(0.86, 0.84)
    panel.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = overlay
    corner(panel, 18)
    stroke(panel, Color3.fromRGB(245, 190, 65), 4)
    padScale(panel, 0.018, 0.018, 0.018, 0.018)
    local column = Instance.new("UIListLayout")
    column.FillDirection = Enum.FillDirection.Vertical
    column.Padding = UDim.new(0.01, 0)
    column.SortOrder = Enum.SortOrder.LayoutOrder
    column.Parent = panel

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0.068, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.LayoutOrder = 1
    titleBar.Parent = panel
    local titleSplit = Instance.new("UIListLayout")
    titleSplit.FillDirection = Enum.FillDirection.Horizontal
    titleSplit.VerticalAlignment = Enum.VerticalAlignment.Center
    titleSplit.Padding = UDim.new(0.012, 0)
    titleSplit.SortOrder = Enum.SortOrder.LayoutOrder
    titleSplit.Parent = titleBar

    local title = label(titleBar, "Title", "BULWARK WORKSHOP", UDim2.new(1, 0, 1, 0), true)
    title.LayoutOrder = 1
    title.TextColor3 = Color3.fromRGB(255, 211, 95)
    fill(title)
    textLimit(title, 28)

    local walletFrame = Instance.new("Frame")
    walletFrame.Name = "Wallet"
    walletFrame.Size = UDim2.fromScale(0.26, 1)
    walletFrame.BackgroundTransparency = 1
    walletFrame.LayoutOrder = 2
    walletFrame.Parent = titleBar
    local walletSplit = Instance.new("UIListLayout")
    walletSplit.FillDirection = Enum.FillDirection.Horizontal
    walletSplit.HorizontalAlignment = Enum.HorizontalAlignment.Right
    walletSplit.VerticalAlignment = Enum.VerticalAlignment.Center
    walletSplit.Padding = UDim.new(0.04, 0)
    walletSplit.SortOrder = Enum.SortOrder.LayoutOrder
    walletSplit.Parent = walletFrame
    local walletCaption =
        label(walletFrame, "WalletCaption", "WALLET", UDim2.new(0.42, 0, 0.7, 0), true)
    walletCaption.LayoutOrder = 1
    walletCaption.TextXAlignment = Enum.TextXAlignment.Right
    walletCaption.TextColor3 = Color3.fromRGB(205, 220, 235)
    textLimit(walletCaption, 16)
    local walletCoin = Instance.new("ImageLabel")
    walletCoin.Name = "WalletCoin"
    walletCoin.Size = UDim2.fromScale(0.16, 0.72)
    walletCoin.BackgroundTransparency = 1
    walletCoin.Image = WAYCOIN_ICON
    walletCoin.ScaleType = Enum.ScaleType.Fit
    walletCoin.LayoutOrder = 2
    walletCoin.Parent = walletFrame
    aspect(walletCoin, 1)
    local walletAmount = label(walletFrame, "WalletAmount", "0", UDim2.new(0.22, 0, 0.7, 0), true)
    walletAmount.LayoutOrder = 3
    walletAmount.TextColor3 = Color3.fromRGB(255, 211, 95)
    textLimit(walletAmount, 18)

    local close = Instance.new("TextButton")
    close.Name = "Close"
    close.Size = UDim2.fromScale(0.07, 1)
    close.BackgroundColor3 = Color3.fromRGB(105, 50, 60)
    close.BorderSizePixel = 0
    close.Font = Enum.Font.GothamBlack
    close.Text = "X"
    close.TextColor3 = Color3.new(1, 1, 1)
    close.TextScaled = true
    close.LayoutOrder = 3
    close.Parent = titleBar
    corner(close, 8)
    aspect(close, 1)
    textLimit(close, 20)

    local selectedHeader = Instance.new("Frame")
    selectedHeader.Name = "SelectedHeader"
    selectedHeader.Size = UDim2.new(1, 0, 0.062, 0)
    selectedHeader.BackgroundTransparency = 1
    selectedHeader.LayoutOrder = 2
    selectedHeader.Parent = panel
    local headerSplit = Instance.new("UIListLayout")
    headerSplit.FillDirection = Enum.FillDirection.Horizontal
    headerSplit.VerticalAlignment = Enum.VerticalAlignment.Center
    headerSplit.Padding = UDim.new(0.014, 0)
    headerSplit.SortOrder = Enum.SortOrder.LayoutOrder
    headerSplit.Parent = selectedHeader
    local selectedName =
        label(selectedHeader, "SelectedName", "CHOOSE A FAMILY", UDim2.new(0.58, 0, 1, 0), true)
    selectedName.LayoutOrder = 1
    textLimit(selectedName, 24)
    local ownedBadge =
        label(selectedHeader, "OwnedBadge", "LOCKED", UDim2.new(0.24, 0, 0.78, 0), true)
    ownedBadge.LayoutOrder = 2
    ownedBadge.BackgroundTransparency = 0
    ownedBadge.BackgroundColor3 = Color3.fromRGB(42, 51, 68)
    ownedBadge.TextXAlignment = Enum.TextXAlignment.Center
    corner(ownedBadge, 12)
    textLimit(ownedBadge, 14)

    local hint = label(
        panel,
        "Hint",
        "Placeable from Wave 1 • Impaler unlocks for 1 Gem • Other changes 1 Waycoin",
        UDim2.new(1, 0, 0.03, 0),
        false
    )
    hint.TextColor3 = Color3.fromRGB(175, 190, 208)
    hint.LayoutOrder = 3
    textLimit(hint, 15)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, 0, 0.7, 0)
    body.BackgroundTransparency = 1
    body.LayoutOrder = 4
    body.Parent = panel
    fill(body)
    local bodySplit = Instance.new("UIListLayout")
    bodySplit.FillDirection = Enum.FillDirection.Horizontal
    bodySplit.Padding = UDim.new(0.014, 0)
    bodySplit.SortOrder = Enum.SortOrder.LayoutOrder
    bodySplit.Parent = body

    local detail = Instance.new("Frame")
    detail.Name = "Detail"
    detail.Size = UDim2.new(0.62, 0, 1, 0)
    detail.BackgroundTransparency = 1
    detail.LayoutOrder = 1
    detail.Parent = body
    fill(detail)
    local detailCol = Instance.new("UIListLayout")
    detailCol.FillDirection = Enum.FillDirection.Vertical
    detailCol.Padding = UDim.new(0.016, 0)
    detailCol.SortOrder = Enum.SortOrder.LayoutOrder
    detailCol.Parent = detail

    local ownedPane = Instance.new("Frame")
    ownedPane.Name = "OwnedPane"
    ownedPane.Size = UDim2.new(1, 0, 0.54, 0)
    ownedPane.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
    ownedPane.BorderSizePixel = 0
    ownedPane.LayoutOrder = 1
    ownedPane.Parent = detail
    fill(ownedPane)
    corner(ownedPane, 14)
    stroke(ownedPane, Color3.fromRGB(61, 75, 98), 2)
    padScale(ownedPane, 0.03, 0.03, 0.04, 0.05)
    local ownedCol = Instance.new("UIListLayout")
    ownedCol.FillDirection = Enum.FillDirection.Vertical
    ownedCol.Padding = UDim.new(0.03, 0)
    ownedCol.SortOrder = Enum.SortOrder.LayoutOrder
    ownedCol.Parent = ownedPane

    local ownedHead = Instance.new("Frame")
    ownedHead.Name = "OwnedHead"
    ownedHead.Size = UDim2.new(1, 0, 0.12, 0)
    ownedHead.BackgroundTransparency = 1
    ownedHead.LayoutOrder = 1
    ownedHead.Parent = ownedPane
    local ownedHeadSplit = Instance.new("UIListLayout")
    ownedHeadSplit.FillDirection = Enum.FillDirection.Horizontal
    ownedHeadSplit.VerticalAlignment = Enum.VerticalAlignment.Center
    ownedHeadSplit.Padding = UDim.new(0.02, 0)
    ownedHeadSplit.SortOrder = Enum.SortOrder.LayoutOrder
    ownedHeadSplit.Parent = ownedHead
    local ownedTitle =
        label(ownedHead, "OwnedTitle", "CURRENTLY OWNED", UDim2.new(1, 0, 1, 0), true)
    ownedTitle.LayoutOrder = 1
    ownedTitle.TextColor3 = Color3.fromRGB(72, 196, 176)
    fill(ownedTitle)
    textLimit(ownedTitle, 16)
    local installedBadge =
        label(ownedHead, "InstalledBadge", "INSTALLED", UDim2.new(0.28, 0, 0.9, 0), true)
    installedBadge.LayoutOrder = 2
    installedBadge.BackgroundTransparency = 0
    installedBadge.BackgroundColor3 = Color3.fromRGB(58, 68, 84)
    installedBadge.TextXAlignment = Enum.TextXAlignment.Center
    corner(installedBadge, 10)
    textLimit(installedBadge, 13)

    local ownedPreview = makePreviewImage(ownedPane, "OwnedPreview")
    ownedPreview.pane.Size = UDim2.new(1, 0, 0.52, 0)
    ownedPreview.pane.LayoutOrder = 2
    fill(ownedPreview.pane)

    local ownedEmpty =
        label(ownedPreview.pane, "OwnedEmpty", "LOCKED", UDim2.fromScale(1, 1), true)
    ownedEmpty.TextXAlignment = Enum.TextXAlignment.Center
    ownedEmpty.TextColor3 = Color3.fromRGB(132, 146, 164)
    textLimit(ownedEmpty, 18)

    local selectedRole = label(ownedPane, "SelectedRole", "", UDim2.new(0.22, 0, 0.1, 0), true)
    selectedRole.LayoutOrder = 3
    selectedRole.BackgroundTransparency = 0
    selectedRole.BackgroundColor3 = Color3.fromRGB(42, 51, 68)
    selectedRole.TextColor3 = Color3.fromRGB(255, 211, 95)
    selectedRole.TextXAlignment = Enum.TextXAlignment.Center
    corner(selectedRole, 10)
    textLimit(selectedRole, 13)

    local selectedDescription =
        label(ownedPane, "SelectedDescription", "", UDim2.new(1, 0, 0.18, 0), false)
    selectedDescription.LayoutOrder = 4
    selectedDescription.TextColor3 = Color3.fromRGB(197, 208, 222)
    selectedDescription.TextYAlignment = Enum.TextYAlignment.Top
    textLimit(selectedDescription, 15)

    local nextPane = Instance.new("Frame")
    nextPane.Name = "NextPane"
    nextPane.Size = UDim2.new(1, 0, 0.44, 0)
    nextPane.BackgroundColor3 = Color3.fromRGB(15, 22, 34)
    nextPane.BorderSizePixel = 0
    nextPane.LayoutOrder = 2
    nextPane.Parent = detail
    fill(nextPane)
    corner(nextPane, 14)
    stroke(nextPane, Color3.fromRGB(61, 75, 98), 2)
    padScale(nextPane, 0.03, 0.03, 0.05, 0.05)
    local nextCol = Instance.new("UIListLayout")
    nextCol.FillDirection = Enum.FillDirection.Vertical
    nextCol.Padding = UDim.new(0.04, 0)
    nextCol.SortOrder = Enum.SortOrder.LayoutOrder
    nextCol.Parent = nextPane

    local nextTitle = label(nextPane, "NextTitle", "NEXT UPGRADE", UDim2.new(1, 0, 0.12, 0), true)
    nextTitle.LayoutOrder = 1
    nextTitle.TextColor3 = Color3.fromRGB(72, 196, 176)
    textLimit(nextTitle, 16)

    local nextBody = Instance.new("Frame")
    nextBody.Name = "NextBody"
    nextBody.Size = UDim2.new(1, 0, 0.84, 0)
    nextBody.BackgroundTransparency = 1
    nextBody.LayoutOrder = 2
    nextBody.Parent = nextPane
    fill(nextBody)
    local nextSplit = Instance.new("UIListLayout")
    nextSplit.FillDirection = Enum.FillDirection.Horizontal
    nextSplit.Padding = UDim.new(0.03, 0)
    nextSplit.SortOrder = Enum.SortOrder.LayoutOrder
    nextSplit.Parent = nextBody

    local nextPreviewCol = Instance.new("Frame")
    nextPreviewCol.Name = "NextPreviewCol"
    nextPreviewCol.Size = UDim2.new(0.4, 0, 1, 0)
    nextPreviewCol.BackgroundTransparency = 1
    nextPreviewCol.LayoutOrder = 1
    nextPreviewCol.Parent = nextBody
    local nextPreviewSplit = Instance.new("UIListLayout")
    nextPreviewSplit.FillDirection = Enum.FillDirection.Vertical
    nextPreviewSplit.Padding = UDim.new(0.04, 0)
    nextPreviewSplit.SortOrder = Enum.SortOrder.LayoutOrder
    nextPreviewSplit.Parent = nextPreviewCol
    local nextCaption =
        label(nextPreviewCol, "NextCaption", "TIER 2", UDim2.new(0.55, 0, 0.16, 0), true)
    nextCaption.LayoutOrder = 1
    nextCaption.BackgroundTransparency = 0
    nextCaption.BackgroundColor3 = Color3.fromRGB(236, 240, 246)
    nextCaption.TextColor3 = Color3.fromRGB(20, 26, 38)
    nextCaption.TextXAlignment = Enum.TextXAlignment.Center
    corner(nextCaption, 8)
    textLimit(nextCaption, 13)
    local nextPreview = makePreviewImage(nextPreviewCol, "NextPreview")
    nextPreview.pane.Size = UDim2.new(1, 0, 0.8, 0)
    nextPreview.pane.LayoutOrder = 2
    fill(nextPreview.pane)

    local nextInfo = Instance.new("Frame")
    nextInfo.Name = "NextInfo"
    nextInfo.Size = UDim2.new(0.6, 0, 1, 0)
    nextInfo.BackgroundTransparency = 1
    nextInfo.LayoutOrder = 2
    nextInfo.Parent = nextBody
    fill(nextInfo)
    local nextInfoCol = Instance.new("UIListLayout")
    nextInfoCol.FillDirection = Enum.FillDirection.Vertical
    nextInfoCol.Padding = UDim.new(0.05, 0)
    nextInfoCol.SortOrder = Enum.SortOrder.LayoutOrder
    nextInfoCol.Parent = nextInfo

    local bullets = {}
    for index = 1, 3 do
        local line = label(nextInfo, "UpgradeNote" .. index, "", UDim2.new(1, 0, 0.16, 0), true)
        line.LayoutOrder = index
        line.TextColor3 = Color3.fromRGB(140, 220, 160)
        textLimit(line, 15)
        bullets[index] = line
    end

    local upgradeFrame = Instance.new("Frame")
    upgradeFrame.Name = "UpgradeFrame"
    upgradeFrame.Size = UDim2.new(1, 0, 0.34, 0)
    upgradeFrame.BackgroundTransparency = 1
    upgradeFrame.LayoutOrder = 4
    upgradeFrame.Parent = nextInfo
    fill(upgradeFrame)

    local list = Instance.new("ScrollingFrame")
    list.Name = "Families"
    list.Size = UDim2.new(0.38, 0, 1, 0)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ClipsDescendants = true
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.fromScale(0, 0)
    list.ScrollBarImageColor3 = Color3.fromRGB(255, 211, 95)
    list.ScrollBarThickness = 8
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    list.LayoutOrder = 2
    list.Parent = body
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0.02, 0)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    local cards = {}

    local function makeCard(index)
        local button = Instance.new("TextButton")
        button.Name = "Family" .. index
        button.LayoutOrder = index
        button.Size = UDim2.new(1, 0, 0.185, 0)
        button.BackgroundColor3 = Color3.fromRGB(28, 36, 51)
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Text = ""
        button.Parent = list
        corner(button, 10)
        local cardStroke = stroke(button, Color3.fromRGB(61, 75, 98), 2)
        padScale(button, 0.03, 0.03, 0.14, 0.14)
        local rowSplit = Instance.new("UIListLayout")
        rowSplit.FillDirection = Enum.FillDirection.Horizontal
        rowSplit.VerticalAlignment = Enum.VerticalAlignment.Center
        rowSplit.Padding = UDim.new(0.025, 0)
        rowSplit.SortOrder = Enum.SortOrder.LayoutOrder
        rowSplit.Parent = button

        local pointer = Instance.new("Frame")
        pointer.Name = "Pointer"
        pointer.Size = UDim2.fromScale(0.03, 0.55)
        pointer.BackgroundColor3 = Color3.fromRGB(255, 211, 95)
        pointer.BorderSizePixel = 0
        pointer.LayoutOrder = 1
        pointer.Parent = button
        corner(pointer, 3)

        local swatch = Instance.new("Frame")
        swatch.Name = "Swatch"
        swatch.Size = UDim2.fromScale(0.12, 1)
        swatch.BackgroundColor3 = FAMILY_COLORS[((index - 1) % #FAMILY_COLORS) + 1]
        swatch.BorderSizePixel = 0
        swatch.LayoutOrder = 2
        swatch.Parent = button
        corner(swatch, 8)
        aspect(swatch, 1)

        local copy = Instance.new("Frame")
        copy.Name = "Copy"
        copy.Size = UDim2.fromScale(0.48, 1)
        copy.BackgroundTransparency = 1
        copy.LayoutOrder = 3
        copy.Parent = button
        fill(copy)
        local copySplit = Instance.new("UIListLayout")
        copySplit.FillDirection = Enum.FillDirection.Vertical
        copySplit.VerticalAlignment = Enum.VerticalAlignment.Center
        copySplit.Padding = UDim.new(0.06, 0)
        copySplit.Parent = copy
        local familyName = label(copy, "FamilyName", "BULWARK", UDim2.new(1, 0, 0.56, 0), true)
        familyName.LayoutOrder = 1
        textLimit(familyName, 15)
        local role = label(copy, "Role", "", UDim2.new(1, 0, 0.38, 0), false)
        role.LayoutOrder = 2
        role.TextColor3 = Color3.fromRGB(175, 190, 208)
        textLimit(role, 12)

        local status = Instance.new("Frame")
        status.Name = "Status"
        status.Size = UDim2.fromScale(0.3, 1)
        status.BackgroundTransparency = 1
        status.LayoutOrder = 4
        status.Parent = button
        local statusSplit = Instance.new("UIListLayout")
        statusSplit.FillDirection = Enum.FillDirection.Horizontal
        statusSplit.HorizontalAlignment = Enum.HorizontalAlignment.Right
        statusSplit.VerticalAlignment = Enum.VerticalAlignment.Center
        statusSplit.Padding = UDim.new(0.06, 0)
        statusSplit.SortOrder = Enum.SortOrder.LayoutOrder
        statusSplit.Parent = status
        local statusText =
            label(status, "StatusText", "LOCKED", UDim2.new(0.72, 0, 0.7, 0), true)
        statusText.LayoutOrder = 1
        statusText.TextXAlignment = Enum.TextXAlignment.Right
        statusText.TextColor3 = Color3.fromRGB(175, 190, 208)
        textLimit(statusText, 11)
        local statusIcon = Instance.new("ImageLabel")
        statusIcon.Name = "Cost"
        statusIcon.Size = UDim2.fromScale(0.22, 0.7)
        statusIcon.BackgroundTransparency = 1
        statusIcon.Image = WAYCOIN_ICON
        statusIcon.ScaleType = Enum.ScaleType.Fit
        statusIcon.LayoutOrder = 2
        statusIcon.Parent = status
        aspect(statusIcon, 1)
        local statusMark = label(status, "StatusMark", "✓", UDim2.new(0.18, 0, 0.7, 0), true)
        statusMark.LayoutOrder = 3
        statusMark.TextXAlignment = Enum.TextXAlignment.Center
        statusMark.TextColor3 = Color3.fromRGB(90, 210, 130)
        statusMark.Visible = false
        textLimit(statusMark, 16)

        button.Activated:Connect(function()
            local card = cards[index]
            if card and card.family then
                controller.selectedId = card.family.id
                controller:_paint()
            end
        end)

        return {
            button = button,
            pointer = pointer,
            swatch = swatch,
            familyName = familyName,
            role = role,
            statusText = statusText,
            statusIcon = statusIcon,
            statusMark = statusMark,
            stroke = cardStroke,
        }
    end

    local function syncCards(families)
        while #cards > #families do
            local card = table.remove(cards)
            if card and card.button then
                card.button:Destroy()
            end
        end
        while #cards < #families do
            cards[#cards + 1] = makeCard(#cards + 1)
        end
    end

    local function pricedContents(parent, name)
        local row = Instance.new("Frame")
        row.Name = name
        row.Size = UDim2.fromScale(1, 1)
        row.BackgroundTransparency = 1
        row.Parent = parent
        local split = Instance.new("UIListLayout")
        split.FillDirection = Enum.FillDirection.Horizontal
        split.HorizontalAlignment = Enum.HorizontalAlignment.Center
        split.VerticalAlignment = Enum.VerticalAlignment.Center
        split.Padding = UDim.new(0.02, 0)
        split.SortOrder = Enum.SortOrder.LayoutOrder
        split.Parent = row
        local verb = label(row, "Verb", "UNLOCK", UDim2.new(0.4, 0, 0.7, 0), true)
        verb.LayoutOrder = 1
        verb.TextXAlignment = Enum.TextXAlignment.Right
        textLimit(verb, 20)
        local coin = Instance.new("ImageLabel")
        coin.Name = "Coin"
        coin.Size = UDim2.fromScale(0.16, 0.7)
        coin.BackgroundTransparency = 1
        coin.Image = WAYCOIN_ICON
        coin.ScaleType = Enum.ScaleType.Fit
        coin.LayoutOrder = 2
        coin.Parent = row
        aspect(coin, 1)
        local amount = label(row, "Amount", "1", UDim2.new(0.14, 0, 0.7, 0), true)
        amount.LayoutOrder = 3
        amount.TextXAlignment = Enum.TextXAlignment.Left
        textLimit(amount, 20)
        return { row = row, verb = verb, coin = coin, amount = amount }
    end

    local function paintPriced(contents, verbText, showPrice, costAmount, ink, currencyId)
        contents.verb.Text = verbText
        contents.verb.TextColor3 = ink
        contents.verb.Size = showPrice and UDim2.new(0.4, 0, 0.7, 0) or UDim2.new(0.8, 0, 0.7, 0)
        contents.verb.TextXAlignment = showPrice and Enum.TextXAlignment.Right
            or Enum.TextXAlignment.Center
        contents.coin.Visible = showPrice
        contents.coin.Image = currencyId == "gems" and GEM_ICON or WAYCOIN_ICON
        contents.amount.Visible = showPrice
        contents.amount.Text = tostring(costAmount)
        contents.amount.TextColor3 = ink
    end

    local upgrade = Instance.new("TextButton")
    upgrade.Name = "Upgrade"
    upgrade.Size = UDim2.fromScale(1, 1)
    upgrade.BackgroundColor3 = Color3.fromRGB(75, 175, 95)
    upgrade.BorderSizePixel = 0
    upgrade.Font = Enum.Font.GothamBlack
    upgrade.Text = ""
    upgrade.AutoButtonColor = false
    upgrade.Parent = upgradeFrame
    corner(upgrade, 12)
    local upgradeStroke = stroke(upgrade, Color3.fromRGB(180, 255, 195), 2)
    local purchase = pricedContents(upgrade, "Purchase")
    upgrade.Activated:Connect(function()
        if not controller.selectedFamily then
            return
        end
        if controller.buyActive then
            onAction({
                action = "bulwark",
                bulwarkAction = "unlock",
                family = controller.selectedFamily.id,
                slot = controller.state and controller.state.slot,
            })
        elseif controller.upgradeActive then
            onAction({
                action = "bulwark",
                bulwarkAction = "upgrade",
                family = controller.selectedFamily.id,
                slot = controller.state and controller.state.slot,
            })
        end
    end)

    local install = Instance.new("TextButton")
    install.Name = "Install"
    install.Size = UDim2.new(1, 0, 0.078, 0)
    install.BackgroundColor3 = Color3.fromRGB(225, 151, 22)
    install.BorderSizePixel = 0
    install.Font = Enum.Font.GothamBlack
    install.Text = ""
    install.TextColor3 = Color3.fromRGB(26, 18, 4)
    install.TextScaled = true
    install.LayoutOrder = 5
    install.Parent = panel
    corner(install, 14)
    local installStroke = stroke(install, Color3.fromRGB(255, 229, 110), 3)
    local installPurchase = pricedContents(install, "Purchase")
    install.Activated:Connect(function()
        if controller.installActive and controller.selectedFamily then
            onAction({
                action = "bulwark",
                bulwarkAction = "select",
                family = controller.selectedFamily.id,
                slot = controller.state and controller.state.slot,
            })
        end
    end)

    local function paintNotes(family, targetTier, atMaximum)
        local notes = type(family.upgradeNotes) == "table" and family.upgradeNotes[targetTier]
            or nil
        if atMaximum then
            bullets[1].Text = "Already at maximum."
            bullets[1].Visible = true
            bullets[2].Visible = false
            bullets[3].Visible = false
            return
        end
        for index = 1, 3 do
            local text = notes and notes[index]
            bullets[index].Text = type(text) == "string" and text or ""
            bullets[index].Visible = type(text) == "string" and text ~= ""
        end
    end

    function controller:_paint()
        local state = type(controller.state) == "table" and controller.state or {}
        local families = type(state.families) == "table" and state.families or {}
        local installed = state.installed == true and type(state.family) == "string"
        local unlocked = state.unlocked == true
        local maximumTier = math.max(1, math.floor(tonumber(state.maximumTier) or 4))
        local cost = math.max(0, math.floor(tonumber(state.actionCost) or 0))
        local wallet = math.max(0, math.floor(tonumber(state.wallet) or 0))
        local gemWallet = math.max(0, math.floor(tonumber(state.gemWallet) or 0))
        local unlockCosts = type(state.unlockCosts) == "table" and state.unlockCosts or {}
        syncCards(families)
        walletCoin.Image = WAYCOIN_ICON
        walletAmount.Text = tostring(wallet)

        hint.Text = state.playtestUnlock == true
                and "Placeable from Wave 1 • Impaler unlocks for 1 Gem • Other changes 1 Waycoin"
            or string.format(
                "Unlocks at Wave %d • Tutorial during the milestone intermission",
                tonumber(state.productionUnlockWave) or 20
            )

        local owned = type(state.owned) == "table" and state.owned or {}
        local selected
        for index, card in ipairs(cards) do
            local family = families[index]
            card.family = family
            card.button.Visible = family ~= nil
            if family then
                if controller.selectedId == family.id or (selected == nil and index == 1) then
                    selected = family
                end
                local ownedTier = math.max(0, math.floor(tonumber(owned[family.id]) or 0))
                local current = installed and family.id == state.family
                local chosen = controller.selectedId == family.id
                local atMax = ownedTier >= maximumTier
                local locked = family.canInstall == false
                card.familyName.Text = string.upper(tostring(family.name or family.id))
                card.role.Text = string.upper(tostring(family.role or ""))
                card.swatch.BackgroundColor3 = FAMILY_COLORS[((index - 1) % #FAMILY_COLORS) + 1]
                card.pointer.BackgroundTransparency = chosen and 0 or 1
                if locked then
                    card.statusText.Text =
                        string.upper(tostring(family.installHint or "LOCKED LINE"))
                    card.statusText.TextColor3 = Color3.fromRGB(196, 150, 255)
                    card.statusIcon.Visible = false
                    card.statusMark.Text = "!"
                    card.statusMark.TextColor3 = Color3.fromRGB(196, 150, 255)
                    card.statusMark.Visible = true
                elseif ownedTier == 0 then
                    card.statusText.Text = "LOCKED"
                    card.statusText.TextColor3 = Color3.fromRGB(175, 190, 208)
                    card.statusIcon.Visible = true
                    card.statusMark.Visible = false
                elseif current and atMax then
                    card.statusText.Text = "MAX"
                    card.statusText.TextColor3 = Color3.fromRGB(196, 150, 255)
                    card.statusIcon.Visible = false
                    card.statusMark.Text = "★"
                    card.statusMark.TextColor3 = Color3.fromRGB(196, 150, 255)
                    card.statusMark.Visible = true
                elseif current then
                    card.statusText.Text = string.format("TIER %d", ownedTier)
                    card.statusText.TextColor3 = Color3.fromRGB(140, 220, 160)
                    card.statusIcon.Visible = false
                    card.statusMark.Text = "✓"
                    card.statusMark.TextColor3 = Color3.fromRGB(90, 210, 130)
                    card.statusMark.Visible = true
                else
                    card.statusText.Text = "UNLOCKED"
                    card.statusText.TextColor3 = Color3.fromRGB(140, 220, 160)
                    card.statusIcon.Visible = false
                    card.statusMark.Text = "✓"
                    card.statusMark.TextColor3 = Color3.fromRGB(90, 210, 130)
                    card.statusMark.Visible = true
                end
                card.button.BackgroundColor3 = chosen and Color3.fromRGB(42, 36, 20)
                    or Color3.fromRGB(28, 36, 51)
                card.stroke.Color = chosen and Color3.fromRGB(255, 229, 110)
                    or (current and Color3.fromRGB(190, 255, 205) or Color3.fromRGB(61, 75, 98))
            end
        end
        if selected == nil then
            selected = families[1]
        end
        controller.selectedFamily = selected
        if selected then
            controller.selectedId = selected.id
            local ownedTier = math.max(0, math.floor(tonumber(owned[selected.id]) or 0))
            local unlockPrice = ownedTier == 0 and unlockCosts[selected.id] or nil
            local unlockCurrency = unlockPrice and unlockPrice.currency or state.currency
            local unlockAmount = unlockPrice
                    and math.max(0, math.floor(tonumber(unlockPrice.amount) or cost))
                or cost
            walletCoin.Image = unlockCurrency == "gems" and GEM_ICON or WAYCOIN_ICON
            walletAmount.Text = tostring(unlockCurrency == "gems" and gemWallet or wallet)
            local current = installed and selected.id == state.family
            local atMaximum = ownedTier >= maximumTier
            local nextTier = ownedTier == 0 and 1
                or (not current and 1)
                or (atMaximum and ownedTier or math.min(maximumTier, ownedTier + 1))
            selectedName.Text = string.upper(tostring(selected.name or selected.id))
            if ownedTier == 0 then
                ownedBadge.Text = "LOCKED"
                ownedBadge.BackgroundColor3 = Color3.fromRGB(42, 51, 68)
                ownedBadge.TextColor3 = Color3.fromRGB(205, 220, 235)
            elseif atMaximum and current then
                ownedBadge.Text = "MAX"
                ownedBadge.BackgroundColor3 = Color3.fromRGB(74, 52, 110)
                ownedBadge.TextColor3 = Color3.fromRGB(226, 196, 255)
            elseif current then
                ownedBadge.Text = string.format("TIER %d", ownedTier)
                ownedBadge.BackgroundColor3 = Color3.fromRGB(46, 92, 68)
                ownedBadge.TextColor3 = Color3.fromRGB(190, 255, 205)
            else
                ownedBadge.Text = "UNLOCKED"
                ownedBadge.BackgroundColor3 = Color3.fromRGB(46, 92, 68)
                ownedBadge.TextColor3 = Color3.fromRGB(190, 255, 205)
            end
            ownedBadge.Visible = true
            installedBadge.Visible = current
            installedBadge.Text = "INSTALLED"
            if ownedTier == 0 then
                ownedTitle.Text = "LOCKED"
                ownedEmpty.Text = "LOCKED"
            elseif current then
                ownedTitle.Text = "CURRENTLY OWNED"
            else
                ownedTitle.Text = "UNLOCKED"
            end
            selectedRole.Text = string.upper(tostring(selected.role or ""))
            selectedDescription.Text = tostring(selected.description or "")
            if ownedTier > 0 then
                showPreview(ownedPreview, selected, ownedTier)
                ownedEmpty.Visible = false
            else
                showPreview(ownedPreview, nil, 0)
                ownedEmpty.Visible = true
            end
            showPreview(nextPreview, selected, nextTier)
            nextCaption.Text = atMaximum and "MAX" or string.format("TIER %d", nextTier)
            nextCaption.Visible = true
            nextTitle.Text = ownedTier == 0 and "UNLOCK"
                or (not current and "INSTALL")
                or (atMaximum and "MAXIMUM" or "NEXT UPGRADE")
            paintNotes(selected, nextTier, atMaximum)
            local canInstall = selected.canInstall ~= false
            controller.buyActive = unlocked and ownedTier == 0 and canInstall
            controller.upgradeActive = unlocked and current and not atMaximum
            controller.installActive = unlocked and ownedTier > 0 and not current and canInstall
            local purchaseActive = controller.buyActive or controller.upgradeActive
            if atMaximum and current then
                paintPriced(purchase, "MAXED", false, cost, Color3.fromRGB(213, 219, 227))
            elseif current and ownedTier > 0 then
                paintPriced(purchase, "UPGRADE", true, cost, Color3.fromRGB(26, 18, 4))
            elseif ownedTier > 0 then
                paintPriced(purchase, "", false, cost, Color3.fromRGB(213, 219, 227))
            else
                paintPriced(
                    purchase,
                    "UNLOCK",
                    true,
                    unlockAmount,
                    Color3.fromRGB(26, 18, 4),
                    unlockCurrency
                )
            end
            upgrade.Active = purchaseActive
            upgrade.AutoButtonColor = purchaseActive
            upgrade.BackgroundColor3 = purchaseActive
                    and (ownedTier > 0 and Color3.fromRGB(75, 175, 95) or Color3.fromRGB(225, 151, 22))
                or Color3.fromRGB(68, 74, 86)
            upgradeStroke.Color = purchaseActive
                    and (ownedTier > 0 and Color3.fromRGB(180, 255, 195) or Color3.fromRGB(255, 229, 110))
                or Color3.fromRGB(110, 118, 132)
            if current then
                paintPriced(installPurchase, "INSTALLED", false, cost, Color3.fromRGB(213, 219, 227))
            elseif controller.installActive then
                paintPriced(installPurchase, "INSTALL", true, cost, Color3.fromRGB(26, 18, 4))
            else
                paintPriced(installPurchase, "INSTALL", false, cost, Color3.fromRGB(213, 219, 227))
            end
        else
            showPreview(ownedPreview, nil, 0)
            showPreview(nextPreview, nil, 0)
            ownedEmpty.Visible = true
            ownedBadge.Visible = false
            installedBadge.Visible = false
            selectedName.Text = "CHOOSE A FAMILY"
            selectedRole.Text = ""
            selectedDescription.Text = ""
            ownedTitle.Text = "CURRENTLY OWNED"
            ownedEmpty.Text = "LOCKED"
            nextCaption.Visible = false
            nextTitle.Text = "NEXT UPGRADE"
            paintNotes({}, 0, false)
            controller.buyActive = false
            controller.upgradeActive = false
            controller.installActive = false
            paintPriced(purchase, "UNLOCK", true, cost, Color3.fromRGB(213, 219, 227))
            upgrade.Active = false
            upgrade.AutoButtonColor = false
            upgrade.BackgroundColor3 = Color3.fromRGB(68, 74, 86)
            upgradeStroke.Color = Color3.fromRGB(110, 118, 132)
            paintPriced(installPurchase, "INSTALL", false, cost, Color3.fromRGB(213, 219, 227))
        end
        install.Active = controller.installActive == true
        install.AutoButtonColor = controller.installActive == true
        install.BackgroundColor3 = controller.installActive == true and Color3.fromRGB(225, 151, 22)
            or Color3.fromRGB(68, 74, 86)
        installStroke.Color = controller.installActive == true and Color3.fromRGB(255, 229, 110)
            or Color3.fromRGB(110, 118, 132)
    end

    function controller:isOpen()
        return overlay.Visible == true
    end

    function controller:tutorialCueButton(kind)
        if kind == "unlock" then
            return upgrade
        elseif kind == "install" then
            return install
        end
        return nil
    end

    function controller:hide()
        overlay.Visible = false
    end

    function controller:show(state)
        state = type(state) == "table" and state or {}
        controller.state = state
        local families = type(state.families) == "table" and state.families or {}
        local stillThere = false
        for _, family in ipairs(families) do
            if family and family.id == controller.selectedId then
                stillThere = true
                break
            end
        end
        if not stillThere then
            controller.selectedId = state.installed == true and state.family
                or (families[1] and families[1].id)
        end
        controller:_paint()
        overlay.Visible = true
    end

    close.Activated:Connect(function()
        controller:hide()
    end)
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
            controller:hide()
        end
    end)
    return controller
end

return MergeBulwarkMenu
