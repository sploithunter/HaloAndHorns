--[[
    StatusBadge — which People-list / chip title the player chose to wear.

    Options come from earned Combat Training ranks, unlocked adventure
    titles, Huge Hatcher, and a current leaderboard placement. The pick
    is { kind, id } in GameData.StatusBadge. A newly earned option
    replaces that pick so ceremony / level / hatch / leaderboard titles
    land on the chip and nametag without opening the chooser.
]]

local CombatRank = require(script.Parent.CombatRank)
local PlayerListStatus = require(script.Parent.PlayerListStatus)

local StatusBadge = {}

local KINDS = {
    combat = true,
    adventure = true,
    huge = true,
    leaderboard = true,
}

function StatusBadge.normalize(pick)
    if type(pick) ~= "table" then
        return nil
    end
    local kind = pick.kind
    local id = pick.id
    if KINDS[kind] ~= true or type(id) ~= "string" or id == "" then
        return nil
    end
    return { kind = kind, id = id }
end

function StatusBadge.parseEarned(csv)
    local earned = {}
    if type(csv) ~= "string" or csv == "" then
        return earned
    end
    for id in string.gmatch(csv, "[^,]+") do
        if id ~= "" then
            earned[id] = true
        end
    end
    return earned
end

function StatusBadge.earnedCsv(state)
    local earned = {}
    local flags = type(state) == "table" and state.earned or {}
    for id, flag in pairs(flags) do
        if type(id) == "string" and id ~= "" and flag == true then
            table.insert(earned, id)
        end
    end
    table.sort(earned)
    return table.concat(earned, ",")
end

function StatusBadge.options(peopleConfig, ranksConfig, state)
    state = state or {}
    local options = {}
    local earned = state.earnedCombat
    if type(earned) ~= "table" then
        earned = StatusBadge.parseEarned(state.earnedCsv)
    end
    for _, rank in ipairs(CombatRank.ranks(ranksConfig)) do
        if earned[rank.id] == true then
            table.insert(options, {
                kind = "combat",
                id = rank.id,
                group = "Training",
                label = rank.label,
                color = rank.color,
                icon = CombatRank.iconAsset(rank),
                source = (ranksConfig and ranksConfig.hover_source) or "Combat Training 1",
            })
        end
    end
    local inspect = peopleConfig and peopleConfig.inspect or {}
    for _, title in ipairs(PlayerListStatus.unlockedTitles(state.level)) do
        local copy = (inspect.level_titles or {})[title.label]
        local hover = type(copy) == "table" and copy.hover or copy
        local icon = type(copy) == "table" and copy.icon or nil
        table.insert(options, {
            kind = "adventure",
            id = title.label,
            group = "Adventure",
            label = title.label,
            color = { 245, 220, 140 },
            icon = type(icon) == "string" and icon ~= "" and icon or nil,
            source = type(hover) == "string" and hover or title.label,
        })
    end
    if state.hugeHatcher == true then
        local hugeIcon = inspect.huge_hatcher_icon
        table.insert(options, {
            kind = "huge",
            id = "huge",
            group = "Adventure",
            label = "Huge Hatcher",
            color = { 255, 196, 92 },
            icon = type(hugeIcon) == "string" and hugeIcon ~= "" and hugeIcon or nil,
            source = inspect.huge_hatcher or "Hatched a Huge",
        })
    end
    if type(state.leaderboardTitle) == "string" and state.leaderboardTitle ~= "" then
        local boardId = state.leaderboardBoardId
        if type(boardId) ~= "string" or boardId == "" then
            boardId = state.leaderboardTitle
        end
        local rank = tonumber(state.leaderboardRank)
        local source = state.leaderboardTitle
        if rank then
            source = string.format(
                "%s #%d (#%d %s)",
                state.leaderboardHoverTitle or state.leaderboardTitle,
                rank,
                rank,
                state.leaderboardHoverBoard or "LB"
            )
        end
        table.insert(options, {
            kind = "leaderboard",
            id = boardId,
            group = "Leaderboard",
            label = state.leaderboardTitle,
            color = { 255, 191, 57 },
            source = source,
        })
    end
    return options
end

function StatusBadge.find(options, kind, id)
    for _, option in ipairs(options or {}) do
        if option.kind == kind and option.id == id then
            return option
        end
    end
    return nil
end

function StatusBadge.auto(options, state)
    state = state or {}
    local list = options or {}
    if type(state.leaderboardTitle) == "string" and state.leaderboardTitle ~= "" then
        for _, option in ipairs(list) do
            if option.kind == "leaderboard" then
                return option
            end
        end
    end
    if type(state.combatRankId) == "string" and state.combatRankId ~= "" then
        local combat = StatusBadge.find(list, "combat", state.combatRankId)
        if combat then
            return combat
        end
    end
    for i = #list, 1, -1 do
        if list[i].kind == "combat" then
            return list[i]
        end
    end
    local huge = StatusBadge.find(list, "huge", "huge")
    if huge then
        return huge
    end
    for i = #list, 1, -1 do
        if list[i].kind == "adventure" then
            return list[i]
        end
    end
    return list[1]
end

function StatusBadge.optionKey(option)
    if type(option) ~= "table" then
        return nil
    end
    if type(option.kind) ~= "string" or type(option.id) ~= "string" then
        return nil
    end
    if option.kind == "" or option.id == "" then
        return nil
    end
    return option.kind .. ":" .. option.id
end

function StatusBadge.parseSeen(seen)
    local set = {}
    if type(seen) ~= "table" then
        return set
    end
    for _, key in ipairs(seen) do
        if type(key) == "string" and key ~= "" then
            set[key] = true
        end
    end
    for key, flag in pairs(seen) do
        if type(key) == "string" and key ~= "" and flag == true then
            set[key] = true
        end
    end
    return set
end

function StatusBadge.seenList(options)
    local keys = {}
    local seen = {}
    for _, option in ipairs(options or {}) do
        local key = StatusBadge.optionKey(option)
        if key and not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

function StatusBadge.samePick(pick, option)
    local chosen = StatusBadge.normalize(pick)
    if not (chosen and option) then
        return false
    end
    return chosen.kind == option.kind and chosen.id == option.id
end

function StatusBadge.sameSeen(a, b)
    local left = StatusBadge.parseSeen(a)
    local right = StatusBadge.parseSeen(b)
    for key in pairs(left) do
        if right[key] ~= true then
            return false
        end
    end
    for key in pairs(right) do
        if left[key] ~= true then
            return false
        end
    end
    return true
end

function StatusBadge.freshOptions(options, seen)
    local seenSet = StatusBadge.parseSeen(seen)
    if next(seenSet) == nil then
        return {}
    end
    local fresh = {}
    for _, option in ipairs(options or {}) do
        local key = StatusBadge.optionKey(option)
        if key and seenSet[key] ~= true then
            table.insert(fresh, option)
        end
    end
    return fresh
end

function StatusBadge.preferFresh(fresh, state)
    state = state or {}
    local list = fresh or {}
    if type(state.combatRankId) == "string" and state.combatRankId ~= "" then
        local combat = StatusBadge.find(list, "combat", state.combatRankId)
        if combat then
            return combat
        end
    end
    for i = #list, 1, -1 do
        if list[i].kind == "combat" then
            return list[i]
        end
    end
    for _, option in ipairs(list) do
        if option.kind == "leaderboard" then
            return option
        end
    end
    local huge = StatusBadge.find(list, "huge", "huge")
    if huge then
        return huge
    end
    for i = #list, 1, -1 do
        if list[i].kind == "adventure" then
            return list[i]
        end
    end
    return list[1]
end

function StatusBadge.resolve(peopleConfig, ranksConfig, state, pick)
    local options = StatusBadge.options(peopleConfig, ranksConfig, state)
    local chosen = StatusBadge.normalize(pick)
    return StatusBadge.find(options, chosen and chosen.kind, chosen and chosen.id)
        or StatusBadge.auto(options, state)
end

function StatusBadge.choose(peopleConfig, ranksConfig, state, pick, seen)
    local options = StatusBadge.options(peopleConfig, ranksConfig, state)
    local fresh = StatusBadge.freshOptions(options, seen)
    local chosen
    if #fresh > 0 then
        chosen = StatusBadge.preferFresh(fresh, state)
    else
        local saved = StatusBadge.normalize(pick)
        chosen = StatusBadge.find(options, saved and saved.kind, saved and saved.id)
            or StatusBadge.auto(options, state)
    end
    return chosen, StatusBadge.seenList(options)
end

return StatusBadge
