--[[
    HotbarLogic — pure functional core for the hotbar (Feature 16).

    No Roblox APIs. A hotbar is a map of slotIndex (1..slot_count) -> bind, where a
    bind is { type, target } or nil (empty). The service supplies the archetype's
    available powers for default layout.

      isValidSlot(index, config)                       -> boolean
      isValidBindType(bindType, config)                -> boolean
      defaultBindings(availablePowers, config)         -> { [index] = bind }
      canRebind(index, bind, config)                   -> { ok, reason? }  (nil bind clears)
      bindAt(hotbar, index)                            -> bind or nil
]]

local HotbarLogic = {}

function HotbarLogic.isValidSlot(index, config)
    local i = tonumber(index)
    return i ~= nil and i >= 1 and i <= (config.slot_count or 0) and i == math.floor(i)
end

function HotbarLogic.isValidBindType(bindType, config)
    for _, t in ipairs(config and config.bind_types or {}) do
        if t == bindType then
            return true
        end
    end
    return false
end

-- New-player layout: power slots -> archetype powers (in order), roster slots ->
-- placeholder roster macros, tactical slots -> configured tactical commands.
function HotbarLogic.defaultBindings(availablePowers, config)
    local bindings = {}

    -- [PROTOTYPE] Explicit override: a fixed, archetype-independent bar (config.default_binds).
    -- Each entry is { slot, type, target }; invalid slots are skipped. Wins over the pool fill.
    if type(config.default_binds) == "table" and #config.default_binds > 0 then
        for _, b in ipairs(config.default_binds) do
            if
                type(b) == "table"
                and HotbarLogic.isValidSlot(b.slot, config)
                and b.type
                and b.target
            then
                bindings[b.slot] = { type = b.type, target = b.target }
            end
        end
        return bindings
    end

    local defaults = config.defaults or {}

    for i, slot in ipairs(defaults.power_slots or {}) do
        local powerId = availablePowers and availablePowers[i]
        if powerId then
            bindings[slot] = { type = "power", target = powerId }
        end
    end
    for i, slot in ipairs(defaults.roster_slots or {}) do
        bindings[slot] = { type = "roster", target = "Roster " .. i }
    end
    for i, slot in ipairs(defaults.tactical_slots or {}) do
        local command = config.tactical_commands and config.tactical_commands[i]
        if command then
            bindings[slot] = { type = "tactical", target = command }
        end
    end
    return bindings
end

-- Validate a rebind. A nil bind clears the slot (always allowed on a valid slot).
function HotbarLogic.canRebind(index, bind, config)
    if not HotbarLogic.isValidSlot(index, config) then
        return { ok = false, reason = "invalid_slot" }
    end
    if bind == nil then
        return { ok = true } -- clear
    end
    if not HotbarLogic.isValidBindType(bind.type, config) then
        return { ok = false, reason = "invalid_bind_type" }
    end
    if type(bind.target) ~= "string" or bind.target == "" then
        return { ok = false, reason = "invalid_bind_target" }
    end
    return { ok = true }
end

function HotbarLogic.bindAt(hotbar, index)
    if type(hotbar) ~= "table" then
        return nil
    end
    return hotbar[index] or hotbar[tostring(index)]
end

return HotbarLogic
