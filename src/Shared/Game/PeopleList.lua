--[[
    PeopleList — pure presentation for the custom People list.

    One prefix only (first match in configs/people_list.lua). Status text
    stays in PlayerListStatus (no VIP/Founder icons — those sit on the name).
]]

local CombatRank = require(script.Parent.CombatRank)
local LeaderboardStatus = require(script.Parent.LeaderboardStatus)
local PlayerListStatus = require(script.Parent.PlayerListStatus)

local function titleCopy(entry)
    if type(entry) == "table" then
        local body = entry.body or entry.hover
        local hover = entry.hover or entry.body
        return {
            body = type(body) == "string" and body or nil,
            hover = type(hover) == "string" and hover or nil,
            icon = type(entry.icon) == "string" and entry.icon ~= "" and entry.icon or nil,
        }
    end
    if type(entry) == "string" and entry ~= "" then
        return { body = entry, hover = entry }
    end
    return { body = nil, hover = nil }
end

local function joinHover(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        if type(part) == "string" and part ~= "" then
            table.insert(parts, part)
        end
    end
    return table.concat(parts, ", ")
end

local PeopleList = {}

-- The watched roster is authoritative, not a GetPlayers snapshot inside PlayerRemoving:
-- Roblox can still include the departing Player until that callback returns.
function PeopleList.orderedRoster(watchedPlayers, localPlayer)
    local others = {}
    for player in pairs(watchedPlayers) do
        if player ~= localPlayer then
            table.insert(others, player)
        end
    end
    table.sort(others, function(a, b)
        local aName, bName = string.lower(a.DisplayName), string.lower(b.DisplayName)
        if aName == bName then
            return a.UserId < b.UserId
        end
        return aName < bName
    end)
    local list = {}
    if watchedPlayers[localPlayer] then
        table.insert(list, localPlayer)
    end
    for _, player in ipairs(others) do
        table.insert(list, player)
    end
    return list
end

function PeopleList.mergeStatus(config, state)
    state = state or {}
    if state.inMergePlace ~= true and state.area ~= "MergeEggPrototype" then
        return nil
    end
    local copy = config.merge_status
    local wave = tonumber(state.mergeHighestWave)
    return {
        title = wave and string.format(copy.format, math.max(0, math.floor(wave))) or copy.loading,
        body = copy.description,
    }
end

local function flagOn(flags, id, attribute)
    if type(flags) ~= "table" then
        return false
    end
    if flags[id] == true then
        return true
    end
    if type(attribute) == "string" and flags[attribute] == true then
        return true
    end
    return false
end

function PeopleList.prefix(config, flags)
    local rows = config and config.prefixes
    if type(rows) ~= "table" then
        return nil
    end
    for _, row in ipairs(rows) do
        if type(row) == "table" and flagOn(flags, row.id, row.attribute) then
            local glyph = type(row.glyph) == "string" and row.glyph or ""
            local icon = type(row.icon) == "table" and row.icon or nil
            if glyph ~= "" or icon then
                return {
                    id = row.id,
                    glyph = glyph,
                    icon = icon,
                    hover = type(row.hover) == "string" and row.hover or nil,
                    attribute = row.attribute,
                }
            end
        end
    end
    return nil
end

function PeopleList.prefixGlyphs(config, flags)
    local glyphs = {}
    local badge = PeopleList.prefix(config, flags)
    if badge and type(badge.glyph) == "string" and badge.glyph ~= "" then
        table.insert(glyphs, badge.glyph)
    end
    return glyphs
end

function PeopleList.prefixString(config, flags)
    return table.concat(PeopleList.prefixGlyphs(config, flags), " ")
end

function PeopleList.displayName(config, flags, name)
    local label = tostring(name or "")
    if label == "" then
        label = "Player"
    end
    local prefix = PeopleList.prefixString(config, flags)
    if prefix ~= "" then
        return prefix .. " " .. label
    end
    return label
end

function PeopleList.flagsFromPlayer(player)
    if not player then
        return {}
    end
    return {
        owner = player:GetAttribute("IsOwner") == true,
        developer = player:GetAttribute("IsAdmin") == true,
        content_creator = player:GetAttribute("IsCreator") == true,
        creator = player:GetAttribute("IsCreator") == true,
        tester = player:GetAttribute("IsBetaTester") == true,
        founder = player:GetAttribute("FounderLegacyActive") == true,
        vip = player:GetAttribute("HasVIPPass") == true,
        IsOwner = player:GetAttribute("IsOwner") == true,
        IsAdmin = player:GetAttribute("IsAdmin") == true,
        IsBetaTester = player:GetAttribute("IsBetaTester") == true,
        IsCreator = player:GetAttribute("IsCreator") == true,
        HasVIPPass = player:GetAttribute("HasVIPPass") == true,
        FounderLegacyActive = player:GetAttribute("FounderLegacyActive") == true,
    }
end

function PeopleList.titleIcon(peopleConfig, statusText)
    local inspect = peopleConfig and peopleConfig.inspect or {}
    local text = tostring(statusText or "")
    if text == "Huge Hatcher" then
        local icon = inspect.huge_hatcher_icon
        if type(icon) == "string" and icon ~= "" then
            return icon
        end
        return nil
    end
    local copy = titleCopy((inspect.level_titles or {})[text])
    return copy.icon
end

local function leaderboardTitle(playerState)
    local title = playerState and playerState.leaderboardTitle
    if type(title) == "string" and title ~= "" then
        return title
    end
    return nil
end

-- Worn or auto Farmer / Slayer / etc. Live rank wins over a stale
-- StatusBadgeSource that landed before LeaderboardStatusRank was set.
function PeopleList.leaderboardSource(playerState)
    playerState = playerState or {}
    local rank = tonumber(playerState.leaderboardRank)
    local title = playerState.leaderboardHoverTitle or playerState.leaderboardTitle
    if rank and type(title) == "string" and title ~= "" then
        return LeaderboardStatus.hoverLine(title, rank, playerState.leaderboardHoverBoard or "LB")
    end
    if type(playerState.chosenSource) == "string" and playerState.chosenSource ~= "" then
        return playerState.chosenSource
    end
    return leaderboardTitle(playerState)
end

function PeopleList.leaderboardShort(playerState)
    playerState = playerState or {}
    local rank = tonumber(playerState.leaderboardRank)
    local title = playerState.leaderboardHoverTitle or playerState.leaderboardTitle
    if rank and type(title) == "string" and title ~= "" then
        return string.format("%s #%d", title, rank)
    end
    return nil
end

function PeopleList.isLeaderboardStatus(playerState, statusText)
    playerState = playerState or {}
    if playerState.chosenKind == "leaderboard" then
        return true
    end
    local title = leaderboardTitle(playerState)
    if not title then
        return false
    end
    if type(playerState.chosenTitle) == "string" and playerState.chosenTitle ~= "" then
        return playerState.chosenTitle == title
    end
    local text = tostring(statusText or "")
    return text == "" or text == title
end

function PeopleList.inspect(ranksConfig, peopleConfig, combatRankId, statusText, playerState)
    playerState = playerState or {}
    local merge = PeopleList.mergeStatus(peopleConfig, playerState)
    if merge then
        return merge
    end
    local inspect = peopleConfig and peopleConfig.inspect or {}
    local text = tostring(statusText or playerState.chosenTitle or "")
    if PeopleList.isLeaderboardStatus(playerState, text) then
        local title = playerState.chosenTitle or leaderboardTitle(playerState) or text
        local body = PeopleList.leaderboardSource(playerState)
        if type(body) ~= "string" or body == "" then
            body = inspect.leaderboard
                or inspect.default_body
                or "Current top-100 world-board placement."
        end
        return {
            title = (type(title) == "string" and title ~= "" and title)
                or (inspect.default_title or "Status"),
            body = body,
        }
    end
    local titleIcon = PeopleList.titleIcon(peopleConfig, text)
    if titleIcon then
        local copy = titleCopy((inspect.level_titles or {})[text])
        local body = copy.body
        if text == "Huge Hatcher" then
            body = inspect.huge_hatcher
        end
        if type(body) ~= "string" or body == "" then
            body = inspect.default_body or "Progress title."
        end
        return {
            title = text ~= "" and text or (inspect.default_title or "Status"),
            body = body,
            icon = titleIcon,
        }
    end
    local rank = CombatRank.rankById(ranksConfig, combatRankId)
    local rankMatches = rank
        and (text == "" or rank.label == text or playerState.chosenKind == "combat")
    if rank and rankMatches then
        local body = rank.inspect
        if type(body) ~= "string" or body == "" then
            body = "Acquired in Combat Training."
        end
        return {
            title = rank.label or text,
            body = body,
            icon = CombatRank.iconAsset(rank),
        }
    end
    local titles = inspect.level_titles or {}
    local copy = titleCopy(titles[text])
    local body = copy.body
    if type(body) ~= "string" or body == "" then
        body = inspect.default_body or "Progress title."
    end
    return {
        title = text ~= "" and text or (inspect.default_title or "Status"),
        body = body,
        icon = copy.icon,
    }
end

local function entryLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end
    if type(entry.label) == "string" and entry.label ~= "" then
        return entry.label
    end
    if type(entry.hover) == "string" and entry.hover ~= "" then
        return entry.hover
    end
    local id = tostring(entry.id or "")
    if id == "" then
        return ""
    end
    return string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2)
end

function PeopleList.roleLabel(config, flags)
    local badge = PeopleList.prefix(config, flags)
    if not badge then
        return ""
    end
    if type(badge.hover) == "string" and badge.hover ~= "" then
        return badge.hover
    end
    return entryLabel(badge)
end

-- Every matching prefix for the slide-out card. The list row still
-- shows one mark. Founder already covers the VIP pass bundle.
function PeopleList.entitlements(config, flags)
    local rows = config and config.prefixes
    if type(rows) ~= "table" then
        return {}
    end
    local founder = flagOn(flags, "founder", "FounderLegacyActive")
    local out = {}
    for _, row in ipairs(rows) do
        if type(row) == "table" and flagOn(flags, row.id, row.attribute) then
            if not (row.id == "vip" and founder) then
                local label = entryLabel(row)
                if label ~= "" then
                    table.insert(out, {
                        id = row.id,
                        label = label,
                        glyph = type(row.glyph) == "string" and row.glyph or "",
                        icon = type(row.icon) == "table" and row.icon or nil,
                    })
                end
            end
        end
    end
    return out
end

function PeopleList.hoverStatus(config, ranksConfig, playerState)
    playerState = playerState or {}
    local merge = PeopleList.mergeStatus(config, playerState)
    if merge then
        return merge.title .. " — " .. merge.body
    end
    if PeopleList.isLeaderboardStatus(playerState, playerState.chosenTitle) then
        local line = PeopleList.leaderboardSource(playerState)
        if line then
            return line
        end
    end
    if type(playerState.chosenTitle) == "string" and playerState.chosenTitle ~= "" then
        if type(playerState.chosenSource) == "string" and playerState.chosenSource ~= "" then
            return playerState.chosenTitle .. " (" .. playerState.chosenSource .. ")"
        end
        return playerState.chosenTitle
    end
    local title = playerState.leaderboardTitle
    if type(title) == "string" and title ~= "" then
        return title
    end
    if type(playerState.combatRank) == "string" and playerState.combatRank ~= "" then
        local source = ranksConfig and ranksConfig.hover_source or "Combat Training 1"
        return playerState.combatRank .. " (" .. source .. ")"
    end
    if playerState.hugeHatcher == true then
        local inspect = config and config.inspect or {}
        local source = inspect.huge_hatcher or "Hatched a Huge"
        return "Huge Hatcher (" .. source .. ")"
    end
    local status = PlayerListStatus.status({
        level = playerState.level,
        hugeHatcher = playerState.hugeHatcher,
    })
    local inspect = config and config.inspect or {}
    local copy = titleCopy((inspect.level_titles or {})[status])
    local source = copy.hover
    if type(source) ~= "string" or source == "" then
        return status
    end
    return status .. " (" .. source .. ")"
end

function PeopleList.hover(config, ranksConfig, playerState)
    playerState = playerState or {}
    local name = tostring(playerState.displayName or "")
    if name == "" then
        name = "Player"
    end
    return joinHover(
        name,
        PeopleList.roleLabel(config, playerState.flags),
        PeopleList.hoverStatus(config, ranksConfig, playerState)
    )
end

local function requiredNumber(value, label)
    local number = tonumber(value)
    assert(number ~= nil, "Missing People list layout number: " .. label)
    return number
end

-- AbsolutePosition includes ScreenGui safe-area extension, while UDim scale placement is evaluated
-- in the ScreenGui's local viewport space. Normalize a rendered rectangle back into that local
-- space before using one ScreenGui surface to dock another.
function PeopleList.screenGuiLocalBounds(state)
    state = assert(state, "ScreenGui bounds state is required")
    local viewportWidth = requiredNumber(state.viewportWidth, "viewportWidth")
    local viewportHeight = requiredNumber(state.viewportHeight, "viewportHeight")
    local width = requiredNumber(state.width, "width")
    local height = requiredNumber(state.height, "height")
    local absoluteLeft = requiredNumber(state.absoluteLeft, "absoluteLeft")
    local absoluteTop = requiredNumber(state.absoluteTop, "absoluteTop")
    local anchorX = requiredNumber(state.anchorX, "anchorX")
    local anchorY = requiredNumber(state.anchorY, "anchorY")
    local authoredAnchorX = viewportWidth * requiredNumber(state.xScale, "xScale")
        + requiredNumber(state.xOffset, "xOffset")
    local authoredAnchorY = viewportHeight * requiredNumber(state.yScale, "yScale")
        + requiredNumber(state.yOffset, "yOffset")
    local screenGuiOriginX = absoluteLeft + anchorX * width - authoredAnchorX
    local screenGuiOriginY = absoluteTop + anchorY * height - authoredAnchorY
    local left = absoluteLeft - screenGuiOriginX
    local top = absoluteTop - screenGuiOriginY
    return {
        left = left,
        top = top,
        right = left + width,
        bottom = top + height,
    }
end

local function layoutMode(config, state)
    local layout = assert(config and config.layout, "people_list.layout is required")
    local modes = assert(layout.modes, "people_list.layout.modes is required")
    local displayClass = tostring(state and state.displayClass or "desktop")
    return assert(modes[displayClass] or modes.desktop, "People list layout mode is required"),
        layout
end

function PeopleList.layout(config, state)
    state = assert(state, "People list viewport state is required")
    local mode, layout = layoutMode(config, state)
    local viewportWidth = requiredNumber(state.viewportWidth, "viewportWidth")
    local viewportHeight = requiredNumber(state.viewportHeight, "viewportHeight")
    local mergeWaveWidth = tonumber(state.mergeWaveWidth)
    local mergeWaveHeight = tonumber(state.mergeWaveHeight)
    local mergeWaveRight = tonumber(state.mergeWaveRight)
    local followsMergeWave = state.mergePlace == true
        and mergeWaveWidth ~= nil
        and mergeWaveWidth > 0
        and mergeWaveHeight ~= nil
        and mergeWaveHeight > 0
    local top
    local topScale
    if state.tutorialOwnsCorner == true then
        top = math.floor(viewportHeight * requiredNumber(mode.tutorial_top, "tutorial_top") + 0.5)
    elseif state.mergePlace == true and tonumber(state.mergeWaveBottom) ~= nil then
        top = math.max(
            0,
            math.floor(
                requiredNumber(state.mergeWaveBottom, "mergeWaveBottom")
                    + viewportHeight * requiredNumber(layout.merge_wave_gap, "merge_wave_gap")
                    + 0.5
            )
        )
    else
        local topScale = if state.mergePlace == true
            then requiredNumber(mode.merge_top, "merge_top")
            else requiredNumber(mode.top, "top")
        top = math.floor(viewportHeight * topScale + 0.5)
    end
    topScale = topScale or (top / viewportHeight)

    local widthScale = requiredNumber(mode.width, "width")
    local rightScale = requiredNumber(mode.right, "right")
    local headerHeight =
        math.floor(viewportHeight * requiredNumber(mode.header_height, "header_height") + 0.5)
    local rowHeight =
        math.floor(viewportHeight * requiredNumber(mode.row_height, "row_height") + 0.5)
    local columnHeaderHeight = math.floor(
        viewportHeight
                * requiredNumber(mode.header_height, "header_height")
                * requiredNumber(layout.column_header_to_header, "column_header_to_header")
            + 0.5
    )
    if followsMergeWave then
        widthScale = mergeWaveWidth
            * requiredNumber(layout.merge_wave_width_ratio, "merge_wave_width_ratio")
            / viewportWidth
        headerHeight = math.floor(
            mergeWaveHeight
                    * requiredNumber(
                        layout.merge_wave_header_height_ratio,
                        "merge_wave_header_height_ratio"
                    )
                + 0.5
        )
        rowHeight = math.floor(
            mergeWaveHeight
                    * requiredNumber(
                        layout.merge_wave_row_height_ratio,
                        "merge_wave_row_height_ratio"
                    )
                + 0.5
        )
        columnHeaderHeight = math.floor(
            headerHeight * requiredNumber(layout.column_header_to_header, "column_header_to_header")
                + 0.5
        )
        if mergeWaveRight ~= nil then
            rightScale = math.max(0, (viewportWidth - mergeWaveRight) / viewportWidth)
        end
    end
    return {
        widthScale = widthScale,
        headerHeight = headerHeight,
        rowHeight = rowHeight,
        maximumBodyHeight = math.floor(
            viewportHeight * requiredNumber(mode.max_body_height, "max_body_height") + 0.5
        ),
        top = top,
        topScale = topScale,
        rightScale = rightScale,
        cardWidthScale = requiredNumber(mode.card_width, "card_width"),
        cardGapScale = requiredNumber(mode.card_gap, "card_gap"),
        cardHeadshotHeight = math.floor(
            viewportHeight * requiredNumber(mode.card_headshot_height, "card_headshot_height") + 0.5
        ),
        cardViewportHeight = math.floor(
            viewportHeight * requiredNumber(mode.card_viewport_height, "card_viewport_height") + 0.5
        ),
        columnHeaderHeight = columnHeaderHeight,
        columnGutter = requiredNumber(layout.column_gutter, "column_gutter"),
    }
end

function PeopleList.topOffset(config, state)
    return PeopleList.layout(config, state).top
end

function PeopleList.shouldShow(state)
    state = state or {}
    if state.largeMenuOpen == true then
        return false
    end
    return true
end

function PeopleList.row(config, ranksConfig, playerState)
    playerState = playerState or {}
    local title = PlayerListStatus.status({
        level = playerState.level,
        chosenTitle = playerState.chosenTitle,
        leaderboardTitle = playerState.leaderboardTitle,
        combatRank = playerState.combatRank,
        hugeHatcher = playerState.hugeHatcher,
    })
    local status = title
    if PeopleList.isLeaderboardStatus(playerState, title) then
        status = PeopleList.leaderboardShort(playerState) or title
    end
    local merge = PeopleList.mergeStatus(config, playerState)
    if merge then
        status = merge.title
    end
    return {
        name = PeopleList.displayName(config, playerState.flags, playerState.displayName),
        badge = PeopleList.prefix(config, playerState.flags),
        rank = PlayerListStatus.rank(
            playerState.level,
            playerState.veteranLevel,
            playerState.ascensionUnlocked
        ),
        status = status,
        location = PlayerListStatus.location({
            area = playerState.area,
            layer = playerState.layer,
            realm = playerState.realm,
            inMission = playerState.inMission,
        }),
        inspect = PeopleList.inspect(
            ranksConfig,
            config,
            playerState.combatRankId,
            title,
            playerState
        ),
        hover = PeopleList.hover(config, ranksConfig, playerState),
    }
end

function PeopleList.cardPlacement(config, state)
    local dimensions = PeopleList.layout(config, state)
    return {
        top = dimensions.top,
        rightScale = dimensions.rightScale + dimensions.widthScale + dimensions.cardGapScale,
        widthScale = dimensions.cardWidthScale,
        headshotHeight = dimensions.cardHeadshotHeight,
        viewportHeight = dimensions.cardViewportHeight,
    }
end

function PeopleList.hoverPlacement(config, state, rowMidY)
    local dimensions = PeopleList.layout(config, state)
    return {
        rightScale = dimensions.rightScale + dimensions.widthScale + dimensions.cardGapScale,
        top = dimensions.top + (tonumber(rowMidY) or 0),
    }
end

function PeopleList.profile(config, ranksConfig, playerState)
    playerState = playerState or {}
    local row = PeopleList.row(config, ranksConfig, playerState)
    local card = config and config.card or {}
    local displayName = tostring(playerState.displayName or "")
    if displayName == "" then
        displayName = "Player"
    end
    local username = tostring(playerState.username or "")
    return {
        displayName = displayName,
        username = username ~= "" and ("@" .. username) or "",
        badgeHeading = card.badge_heading or "How you get this",
        rolesHeading = card.roles_heading or "Roles",
        entitlements = PeopleList.entitlements(config, playerState.flags),
        examineLabel = card.examine_label or "Examine Avatar",
        inspect = row.inspect,
        status = row.status,
        badge = row.badge,
    }
end

-- Collapse once on entry, allow a manual peek, and restore the prior outside-training choice.
function PeopleList.trainingExpansion(expanded, previous, inTraining, enabled)
    if inTraining and enabled then
        if previous == nil then
            return false, expanded
        end
        return expanded, previous
    end
    if previous ~= nil then
        return previous, nil
    end
    return expanded, nil
end

return PeopleList
