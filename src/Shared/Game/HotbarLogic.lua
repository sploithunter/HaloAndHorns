--[[
    HotbarLogic — pure functional core for the hotbar (Feature 16).

    No Roblox APIs. A hotbar is a map of slotIndex (1..slot_count) -> bind, where a
    bind is { type, target } or nil (empty). The service supplies the archetype's
    available powers for default layout.

      isValidSlot(index, config)                       -> boolean
      isValidBindType(bindType, config)                -> boolean
      defaultBindings(availablePowers, config)         -> { [index] = bind }
      beginningBindings(config)                        -> { [index] = bind }
      canRebind(index, bind, config)                   -> { ok, reason? }  (nil bind clears)
      bindAt(hotbar, index)                            -> bind or nil
      ensureBindAt(hotbar, index, bind, config)        -> { ok, changed, movedFrom?, movedTo? }
      potionAutoBindSlot(hotbar, potionId, config)     -> slot or nil
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

-- Authored origin-free beginning layout. This is deliberately separate from defaultBindings:
-- reset/new-player state has no archetype yet, while tutorial utilities such as Rally still belong
-- on the bar. Invalid config rows are ignored so a typo cannot create an unusable persisted bind.
function HotbarLogic.beginningBindings(config)
    local bindings = {}
    for _, bind in ipairs((config and config.beginning_binds) or {}) do
        if
            type(bind) == "table"
            and HotbarLogic.isValidSlot(bind.slot, config)
            and HotbarLogic.isValidBindType(bind.type, config)
            and type(bind.target) == "string"
            and bind.target ~= ""
        then
            bindings[tonumber(bind.slot)] = { type = bind.type, target = bind.target }
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

local function sameBind(a, b)
    return type(a) == "table" and type(b) == "table" and a.type == b.type and a.target == b.target
end

local function writeSlot(hotbar, index, bind)
    -- Profiles persist string keys, but a few pure callers/tests use numeric keys. Normalize the
    -- write and remove the alternate representation so one logical slot can never hold two binds.
    hotbar[index] = nil
    hotbar[tostring(index)] = bind
end

-- Put a required bind at an authored slot without silently destroying a player's existing bind.
-- If the required bind already lives elsewhere, that old slot becomes the displacement target.
-- Otherwise we relocate the displaced bind to the first free slot in the same tray, then anywhere.
-- This is used by tutorial grants whose copy must match the UI target (for example Rally at slot 11).
function HotbarLogic.ensureBindAt(hotbar, index, bind, config)
    if type(hotbar) ~= "table" then
        return { ok = false, reason = "invalid_hotbar" }
    end
    local decision = HotbarLogic.canRebind(index, bind, config)
    if not decision.ok or bind == nil then
        return { ok = false, reason = decision.reason or "bind_required" }
    end

    index = tonumber(index)
    local current = HotbarLogic.bindAt(hotbar, index)
    if sameBind(current, bind) then
        return { ok = true, changed = false }
    end

    local slotCount = math.max(0, math.floor(tonumber(config and config.slot_count) or 0))
    local existingSlot
    for slot = 1, slotCount do
        if sameBind(HotbarLogic.bindAt(hotbar, slot), bind) then
            existingSlot = slot
            break
        end
    end

    local displaced = current
    if existingSlot and existingSlot ~= index then
        writeSlot(hotbar, existingSlot, nil)
    end

    local movedTo
    if displaced and not sameBind(displaced, bind) then
        if existingSlot and existingSlot ~= index then
            movedTo = existingSlot
        else
            local traySize = math.max(1, math.floor(slotCount / 2))
            local trayStart = index > traySize and traySize + 1 or 1
            local trayEnd = math.min(slotCount, trayStart + traySize - 1)
            for slot = trayStart, trayEnd do
                if slot ~= index and HotbarLogic.bindAt(hotbar, slot) == nil then
                    movedTo = slot
                    break
                end
            end
            if not movedTo then
                for slot = 1, slotCount do
                    if slot ~= index and HotbarLogic.bindAt(hotbar, slot) == nil then
                        movedTo = slot
                        break
                    end
                end
            end
        end
        if movedTo then
            writeSlot(hotbar, movedTo, displaced)
        end
    end

    writeSlot(hotbar, index, { type = bind.type, target = bind.target })
    return {
        ok = true,
        changed = true,
        movedFrom = existingSlot,
        movedTo = movedTo,
        displaced = displaced ~= nil and movedTo == nil,
    }
end

-- Potions fill the top row from right to left. Returning nil means either this
-- potion is already bound or the top row is full.
function HotbarLogic.potionAutoBindSlot(hotbar, potionId, config)
    if type(hotbar) ~= "table" or type(potionId) ~= "string" or potionId == "" then
        return nil
    end
    local slotCount = math.max(0, math.floor(tonumber(config and config.slot_count) or 0))
    for i = 1, slotCount do
        local bind = HotbarLogic.bindAt(hotbar, i)
        if type(bind) == "table" and bind.type == "potion" and bind.target == potionId then
            return nil
        end
    end
    local topRowStart = math.floor(slotCount / 2) + 1
    for i = slotCount, topRowStart, -1 do
        if HotbarLogic.bindAt(hotbar, i) == nil then
            return i
        end
    end
    return nil
end

return HotbarLogic
