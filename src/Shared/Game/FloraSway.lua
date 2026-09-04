--!strict

-- Pure rustle sampler for map flora. The client tilts nearby plants around
-- their base; this module decides who moves and by how much so headless tests
-- can lock the classification without Roblox APIs.

local FloraSway = {}

export type SwayConfig = {
    enabled: boolean?,
    radius: number?,
    tree_degrees: number?,
    plant_degrees: number?,
    cactus_degrees: number?,
    banner_degrees: number?,
    speed: number?,
}

export type Sample = {
    pitch: number,
    roll: number,
}

local SKIP_TOKENS = {
    "altar",
    "board",
    "boulder",
    "bridge",
    "cannon",
    "egg",
    "floor",
    "fountain",
    "foundation",
    "gate",
    "geode",
    "hatch",
    "lantern",
    "nugget",
    "pad",
    "pebble",
    "quartz",
    "rock",
    "stone",
    "throne",
    "tower",
    "trim",
    "wall",
}

local SOFT_TOKENS = {
    "anemone",
    "baobab",
    "bloom",
    "bramble",
    "brush",
    "bush",
    "cactus",
    "canopy",
    "cherry",
    "fern",
    "flower",
    "grass",
    "hibiscus",
    "moss",
    "oak",
    "orchid",
    "pine",
    "pitcher",
    "plant",
    "reed",
    "sapling",
    "shrub",
    "thorn",
    "tree",
    "tuft",
    "vine",
    "willow",
}

local HARD_KINDS = {
    rock = true,
}

local SOFT_KINDS = {
    banner = true,
    cactus = true,
    plant = true,
    tree = true,
}

local function lowerName(value: any): string
    return string.lower(tostring(value or ""))
end

local function containsToken(haystack: string, token: string): boolean
    local startAt = 1
    while true do
        local first, last = string.find(haystack, token, startAt, true)
        if not first or not last then
            return false
        end
        local before = first == 1
            or string.match(string.sub(haystack, first - 1, first - 1), "%w") == nil
        local after = last == #haystack
            or string.match(string.sub(haystack, last + 1, last + 1), "%w") == nil
        if before and after then
            return true
        end
        startAt = first + 1
    end
end

function FloraSway.kindOf(name: any, kind: any): string?
    local explicit = lowerName(kind)
    if explicit ~= "" then
        if HARD_KINDS[explicit] or SOFT_KINDS[explicit] then
            return explicit
        end
        -- Authored kinds are authoritative. A wall decoration named Banner is
        -- still wall decor, not flora, and must never be pivoted by this client.
        return nil
    end
    local haystack = lowerName(name)
    if containsToken(haystack, "cactus") then
        return "cactus"
    end
    if
        containsToken(haystack, "tree")
        or containsToken(haystack, "sapling")
        or containsToken(haystack, "pine")
        or containsToken(haystack, "oak")
        or containsToken(haystack, "cherry")
        or containsToken(haystack, "canopy")
        or containsToken(haystack, "baobab")
        or containsToken(haystack, "willow")
    then
        return "tree"
    end
    for _, token in ipairs(SOFT_TOKENS) do
        if containsToken(haystack, token) then
            return "plant"
        end
    end
    return nil
end

function FloraSway.shouldSway(name: any, kind: any): boolean
    local resolved = FloraSway.kindOf(name, kind)
    if not resolved or HARD_KINDS[resolved] then
        return false
    end
    local haystack = lowerName(name)
    for _, token in ipairs(SKIP_TOKENS) do
        if containsToken(haystack, token) then
            return false
        end
    end
    return SOFT_KINDS[resolved] == true
end

function FloraSway.amplitude(name: any, kind: any, config: SwayConfig?): number
    if not FloraSway.shouldSway(name, kind) then
        return 0
    end
    local data = config or {}
    local resolved = FloraSway.kindOf(name, kind)
    local degrees = tonumber(data.plant_degrees) or 2.6
    if resolved == "tree" then
        degrees = tonumber(data.tree_degrees) or 1.3
    elseif resolved == "cactus" then
        degrees = tonumber(data.cactus_degrees) or 1.8
    elseif resolved == "banner" then
        degrees = tonumber(data.banner_degrees) or 4.5
    end
    return math.rad(math.max(0, degrees))
end

function FloraSway.speed(config: SwayConfig?): number
    local data = config or {}
    return math.max(0.2, tonumber(data.speed) or 1.15)
end

function FloraSway.radius(config: SwayConfig?): number
    local data = config or {}
    return math.max(8, tonumber(data.radius) or 80)
end

function FloraSway.phase(x: number, z: number): number
    return (x * 0.37 + z * 0.21) % (math.pi * 2)
end

function FloraSway.sample(time: number, phase: number, amplitude: number, speed: number): Sample
    local t = time * speed + phase
    return {
        pitch = amplitude * (0.68 * math.sin(t) + 0.32 * math.sin(t * 2.17 + 0.4)),
        roll = amplitude * 0.42 * math.sin(t * 1.31 + 1.1),
    }
end

return FloraSway
