--[[
    LeaderboardScoring — pure score derivation for the four origin boards.

    The global leaderboard service never scans saved profiles. It asks this module to derive
    the score for the one profile that just joined or changed, then replaces that user's
    OrderedDataStore value. This module deliberately knows nothing about DataStoreService.
]]

local LeaderboardScoring = {}

local function quantity(record)
    return math.max(1, math.floor(tonumber(record and record.quantity) or 1))
end

local function petItems(data)
    local pets = data and data.Inventory and data.Inventory.pets
    return (pets and type(pets.items) == "table" and pets.items) or {}
end

-- Dragonlord and similar boards match families by id/display-name tokens
-- ("dragon", "wyrm", "drake") so a renamed Abyssal Wyrm still counts.
function LeaderboardScoring.nameMatchesTokens(petId, displayName, tokens)
    if type(tokens) ~= "table" then
        return false
    end
    local haystack = string.lower(tostring(petId or "") .. " " .. tostring(displayName or ""))
    for _, token in ipairs(tokens) do
        if type(token) == "string" and token ~= "" then
            if string.find(haystack, string.lower(token), 1, true) then
                return true
            end
        end
    end
    return false
end

function LeaderboardScoring.idsMatchingTokens(pets, tokens)
    local ids = {}
    if type(pets) ~= "table" then
        return ids
    end
    for petId, family in pairs(pets) do
        local displayName = type(family) == "table" and family.display_name
        if LeaderboardScoring.nameMatchesTokens(petId, displayName, tokens) then
            table.insert(ids, petId)
        end
    end
    table.sort(ids)
    return ids
end

function LeaderboardScoring.taxonomyIds(score, pets)
    local seen = {}
    local ids = {}
    local function add(petId)
        if type(petId) == "string" and petId ~= "" and not seen[petId] then
            seen[petId] = true
            table.insert(ids, petId)
        end
    end
    if type(score) == "table" then
        for _, petId in ipairs(score.pet_ids or {}) do
            add(petId)
        end
        for _, petId in ipairs(LeaderboardScoring.idsMatchingTokens(pets, score.pet_name_tokens)) do
            add(petId)
        end
    end
    return ids
end

function LeaderboardScoring.countTaxonomy(data, acceptedIds)
    local accepted = {}
    for _, petId in ipairs(acceptedIds or {}) do
        accepted[petId] = true
    end

    local count = 0
    for _, record in pairs(petItems(data)) do
        if type(record) == "table" and accepted[record.id] then
            count += quantity(record)
        end
    end
    return count
end

function LeaderboardScoring.strongestLegalSquad(data, maxSlots, powerForRecord)
    local powers = {}
    for _, record in pairs(petItems(data)) do
        if type(record) == "table" then
            local power = math.max(0, tonumber(powerForRecord(record)) or 0)
            for _ = 1, quantity(record) do
                table.insert(powers, power)
            end
        end
    end

    table.sort(powers, function(a, b)
        return a > b
    end)

    local total = 0
    local slots = math.max(0, math.floor(tonumber(maxSlots) or 0))
    for index = 1, math.min(slots, #powers) do
        total += powers[index]
    end
    return math.floor(total + 0.5)
end

function LeaderboardScoring.counter(data, counterId)
    local counters = data and data.Stats and data.Stats.Counters
    return math.max(0, tonumber(counters and counters[counterId]) or 0)
end

-- Internal accounts stay in the OrderedDataStore. hide=true drops them from
-- the public page AND the reward roster. Display and payouts share this list.
function LeaderboardScoring.visibleEntries(entries, hiddenIds, hide)
    if hide ~= true then
        return entries
    end
    hiddenIds = type(hiddenIds) == "table" and hiddenIds or {}
    local visible = {}
    for _, entry in ipairs(type(entries) == "table" and entries or {}) do
        local userId = tonumber(entry and entry.userId)
        if userId and hiddenIds[userId] ~= true then
            visible[#visible + 1] = entry
        end
    end
    return visible
end

local function copyEntry(entry)
    local copy = {}
    for key, value in pairs(entry) do
        copy[key] = value
    end
    return copy
end

-- Ranked public top N. This is the board you see and the only list that
-- may be paid. Hidden IDs never get a place when hide is on.
function LeaderboardScoring.publicTop(entries, hiddenIds, hide, limit)
    local visible = LeaderboardScoring.visibleEntries(entries, hiddenIds, hide)
    local cap = math.max(1, math.floor(tonumber(limit) or #visible))
    local out = {}
    for index = 1, math.min(cap, #visible) do
        local row = copyEntry(visible[index])
        row.rank = index
        out[index] = row
    end
    return out
end

function LeaderboardScoring.rewardRoster(entries, hiddenIds, hide, limit)
    return LeaderboardScoring.publicTop(entries, hiddenIds, hide, limit)
end

return LeaderboardScoring
