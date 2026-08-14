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

return LeaderboardScoring
