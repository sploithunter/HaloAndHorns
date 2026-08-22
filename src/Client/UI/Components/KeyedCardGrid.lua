--[[
    KeyedCardGrid keeps GUI card controllers alive across authoritative list snapshots.

    A controller returned by `create` must expose:
      frame                         -- the GuiObject owned by this grid
      update(item, order, context)  -- patch mutable presentation/behavior
      destroy()                     -- release connections and destroy the frame

    Stable keys are intentionally supplied by the consumer because inventory stacks,
    unique records, and aggregated trade offers have different identity rules.
]]

local KeyedCardGrid = {}
KeyedCardGrid.__index = KeyedCardGrid

function KeyedCardGrid.new(parent, create)
    assert(parent ~= nil, "KeyedCardGrid requires a parent")
    assert(type(create) == "function", "KeyedCardGrid requires a controller factory")
    return setmetatable({
        parent = parent,
        _create = create,
        _entries = {},
    }, KeyedCardGrid)
end

function KeyedCardGrid:update(items, keyFor, context)
    assert(type(keyFor) == "function", "KeyedCardGrid requires a key resolver")

    local stale = self._entries
    local nextEntries = {}
    for order, item in ipairs(items or {}) do
        local key = keyFor(item, order)
        assert(type(key) == "string" and key ~= "", "KeyedCardGrid key must be a string")
        assert(nextEntries[key] == nil, "duplicate KeyedCardGrid key: " .. key)

        local controller = stale[key]
        if controller then
            stale[key] = nil
        else
            controller = self._create(self.parent, item, order, context)
        end

        controller.frame.Parent = self.parent
        controller.frame.LayoutOrder = order
        controller:update(item, order, context)
        nextEntries[key] = controller
    end

    for _, controller in pairs(stale) do
        controller:destroy()
    end
    self._entries = nextEntries
end

function KeyedCardGrid:destroy()
    for _, controller in pairs(self._entries) do
        controller:destroy()
    end
    self._entries = {}
end

return KeyedCardGrid
