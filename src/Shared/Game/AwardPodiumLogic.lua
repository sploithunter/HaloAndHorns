--[[
    AwardPodiumLogic — layout and slot pick for 1st / 2nd / 3rd stands.

    Visual order from the front is 2, 1, 3. Rank 1 is center and tallest.
]]

local AwardPodiumLogic = {}

function AwardPodiumLogic.stepX(rank, width, gap)
    local span = (tonumber(width) or 4.4) + (tonumber(gap) or 0.4)
    if rank == 2 then
        return -span
    end
    if rank == 3 then
        return span
    end
    return 0
end

function AwardPodiumLogic.stepHeight(rank, heights)
    heights = type(heights) == "table" and heights or {}
    return tonumber(heights[rank]) or ({ 6.2, 4.1, 2.7 })[rank] or 2
end

function AwardPodiumLogic.slots(entries, extras, ranks)
    ranks = math.max(1, math.floor(tonumber(ranks) or 3))
    local used = {}
    local slots = {}
    local function add(entry)
        if type(entry) ~= "table" then
            return
        end
        local userId = tonumber(entry.userId)
        if not userId or used[userId] then
            return
        end
        used[userId] = true
        table.insert(slots, {
            rank = #slots + 1,
            userId = userId,
            name = entry.displayName or entry.name or ("Player " .. tostring(userId)),
            value = math.max(0, tonumber(entry.value) or 0),
        })
    end
    if type(entries) == "table" then
        for _, entry in ipairs(entries) do
            if #slots >= ranks then
                break
            end
            add(entry)
        end
    end
    if type(extras) == "table" then
        for _, entry in ipairs(extras) do
            if #slots >= ranks then
                break
            end
            add(entry)
        end
    end
    return slots
end

function AwardPodiumLogic.occupantKey(slots)
    local byRank = { "0", "0", "0" }
    for _, slot in ipairs(type(slots) == "table" and slots or {}) do
        local rank = tonumber(slot.rank)
        if rank and byRank[rank] then
            byRank[rank] = tostring(tonumber(slot.userId) or 0)
        end
    end
    return table.concat(byRank, ":")
end

function AwardPodiumLogic.pickClip(pool, avoid)
    local choices = {}
    for _, id in ipairs(type(pool) == "table" and pool or {}) do
        if type(id) == "string" and id ~= "" and id ~= avoid then
            table.insert(choices, id)
        end
    end
    if #choices == 0 then
        for _, id in ipairs(type(pool) == "table" and pool or {}) do
            if type(id) == "string" and id ~= "" then
                table.insert(choices, id)
            end
        end
    end
    if #choices == 0 then
        return nil
    end
    return choices[math.random(1, #choices)]
end

function AwardPodiumLogic.scoreKey(slots)
    local byRank = { "0", "0", "0" }
    for _, slot in ipairs(type(slots) == "table" and slots or {}) do
        local rank = tonumber(slot.rank)
        if rank and byRank[rank] then
            byRank[rank] = string.format(
                "%s/%s",
                tostring(tonumber(slot.userId) or 0),
                tostring(math.floor(tonumber(slot.value) or 0))
            )
        end
    end
    return table.concat(byRank, ":")
end

return AwardPodiumLogic
