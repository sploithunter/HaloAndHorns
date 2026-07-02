--[[
    RingTopology (pure)

    Deterministic adjacency over a config-defined ring of biomes. Generic: it
    never hardcodes biome names — it reads `configs/biomes.lua` (order + biomes
    map). Adding/reordering biomes is a config change with no edits here
    (Feature 1, GWT_ACCEPTANCE_SPEC).

    Pure: standard Lua only, so it is unit-tested headless (`mise run test-headless`).

    Config shape:
        { order = { "earth", "ice", ... },
          biomes = { earth = { theme=, dichotomy=, currency= }, ... } }
]]

local RingTopology = {}
RingTopology.__index = RingTopology

-- Build a topology from a biome config table.
function RingTopology.new(config)
    assert(type(config) == "table", "RingTopology.new requires a config table")
    assert(
        type(config.order) == "table" and #config.order > 0,
        "config.order must be a non-empty array"
    )

    local self = setmetatable({}, RingTopology)
    self._order = config.order
    self._biomes = config.biomes or {}
    self._index = {} -- biome id -> position in clockwise order
    for i, id in ipairs(self._order) do
        self._index[id] = i
    end
    return self
end

-- Number of biomes in the ring.
function RingTopology:count()
    return #self._order
end

-- Whether a biome id exists in the ring.
function RingTopology:has(id)
    return self._index[id] ~= nil
end

-- The next biome clockwise (wraps last → first). nil if id unknown.
function RingTopology:clockwiseNeighbor(id)
    local i = self._index[id]
    if not i then
        return nil
    end
    local n = #self._order
    return self._order[(i % n) + 1]
end

-- The next biome counterclockwise (wraps first → last). nil if id unknown.
function RingTopology:counterclockwiseNeighbor(id)
    local i = self._index[id]
    if not i then
        return nil
    end
    local n = #self._order
    return self._order[((i - 2) % n) + 1]
end

-- Whether b is either neighbor of a.
function RingTopology:areAdjacent(a, b)
    if not self._index[a] or not self._index[b] then
        return false
    end
    return self:clockwiseNeighbor(a) == b or self:counterclockwiseNeighbor(a) == b
end

-- Config-driven theme of a biome (never inferred from the name).
function RingTopology:theme(id)
    local biome = self._biomes[id]
    return biome and biome.theme or nil
end

-- Config-driven dichotomy (mirror-opposite) partner; nil if none.
function RingTopology:dichotomyPartner(id)
    local biome = self._biomes[id]
    return biome and biome.dichotomy or nil
end

-- Config-driven themed reward currency for a biome.
function RingTopology:currency(id)
    local biome = self._biomes[id]
    return biome and biome.currency or nil
end

return RingTopology
