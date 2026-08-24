-- Pure nearby-slot selection for player arrivals. Runtime code supplies other
-- players' positions in spawn-local X/Z coordinates; this module owns only the
-- deterministic layout and clearance choice.

local PlayerSpawnSpread = {}

local DEFAULT_RING_SPACING = 8
local DEFAULT_RING_COUNT = 2
local DEFAULT_SLOTS_PER_RING = 8
local DEFAULT_MINIMUM_SEPARATION = 6

local function positiveNumber(value, fallback)
    value = tonumber(value)
    if value and value > 0 then
        return value
    end
    return fallback
end

local function positiveInteger(value, fallback)
    return math.max(1, math.floor(positiveNumber(value, fallback)))
end

function PlayerSpawnSpread.candidates(config)
    config = type(config) == "table" and config or {}
    local ringSpacing = positiveNumber(config.ring_spacing, DEFAULT_RING_SPACING)
    local ringCount = positiveInteger(config.ring_count, DEFAULT_RING_COUNT)
    local slotsPerRing = positiveInteger(config.slots_per_ring, DEFAULT_SLOTS_PER_RING)
    local candidates = {}

    for ring = 1, ringCount do
        local count = slotsPerRing * ring
        local radius = ringSpacing * ring
        -- Stagger outer rings so their radial lines do not form crowded lanes.
        local phase = ring % 2 == 0 and math.pi / count or 0
        for slot = 1, count do
            local angle = phase + ((slot - 1) / count) * math.pi * 2
            table.insert(candidates, {
                x = math.cos(angle) * radius,
                z = math.sin(angle) * radius,
            })
        end
    end

    return candidates
end

local function distance(a, b)
    local dx = (tonumber(a.x) or 0) - (tonumber(b.x) or 0)
    local dz = (tonumber(a.z) or 0) - (tonumber(b.z) or 0)
    return math.sqrt(dx * dx + dz * dz)
end

function PlayerSpawnSpread.choose(userId, occupied, config)
    config = type(config) == "table" and config or {}
    local candidates = PlayerSpawnSpread.candidates(config)
    if #candidates == 0 then
        return { x = 0, z = 0 }, 0
    end

    occupied = type(occupied) == "table" and occupied or {}
    local minimumSeparation = positiveNumber(config.minimum_separation, DEFAULT_MINIMUM_SEPARATION)
    local stableId = math.abs(math.floor(tonumber(userId) or 0))
    local preferredIndex = stableId % #candidates + 1
    local bestCandidate = candidates[preferredIndex]
    local bestIndex = preferredIndex
    local bestClearance = -math.huge

    for step = 0, #candidates - 1 do
        local index = (preferredIndex + step - 1) % #candidates + 1
        local candidate = candidates[index]
        local clearance = math.huge
        for _, position in ipairs(occupied) do
            clearance = math.min(clearance, distance(candidate, position))
        end
        if clearance >= minimumSeparation then
            return candidate, index
        end
        if clearance > bestClearance then
            bestClearance = clearance
            bestCandidate = candidate
            bestIndex = index
        end
    end

    -- A server larger than the configured pool still lands at its least-crowded
    -- slot instead of falling back to the exact shared anchor.
    return bestCandidate, bestIndex
end

return PlayerSpawnSpread
