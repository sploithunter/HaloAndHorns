--[[
    TutorialUnlock — AND-list of named checks for tutorial door / step gates.

    Config rows point at checks[name]. The snapshot is a plain table (no Instances)
    so headless tests can evaluate without Studio. Unknown check names fail closed.

    Snapshot:
      {
        hotbar = { ["1"] = { type = "power", target = "heal" }, ... },
        hotbarEditing = boolean,
        equippedSlots = { [1] = { id = "bear", ... }, ... },
        maxSlots = 3,
        rolesByType = { bear = "tank", ... },
        defaultRole = "melee",
      }

    Row:
      { check = "pets_equipped", count = 1, fail_nudge = "Go equip pets.", fail_plate = "EQUIP PETS" }
]]

local TutorialUnlock = {}

local function equippedCount(snapshot)
    local n = 0
    for _, desc in pairs((snapshot and snapshot.equippedSlots) or {}) do
        if desc then
            n += 1
        end
    end
    return n
end

local function roleOf(snapshot, petId)
    local roles = (snapshot and snapshot.rolesByType) or {}
    local role = roles[tostring(petId or "")]
    if type(role) == "string" and role ~= "" then
        return role
    end
    return tostring((snapshot and snapshot.defaultRole) or "melee")
end

-- Named check blocks. Add new kinds here; configs only name the check.
TutorialUnlock.checks = {
    hotbar_bound = function(snapshot, cond)
        local bindType = tostring((cond and cond.type) or "power")
        local target = tostring((cond and cond.target) or "")
        if target == "" then
            return false
        end
        for _, bind in pairs((snapshot and snapshot.hotbar) or {}) do
            if
                type(bind) == "table"
                and tostring(bind.type) == bindType
                and tostring(bind.target) == target
            then
                return true
            end
        end
        return false
    end,

    hotbar_not_editing = function(snapshot)
        return not (snapshot and snapshot.hotbarEditing == true)
    end,

    pets_equipped = function(snapshot, cond)
        local need = math.max(1, math.floor(tonumber(cond and cond.count) or 1))
        return equippedCount(snapshot) >= need
    end,

    squad_full = function(snapshot)
        local maxSlots = math.max(0, math.floor(tonumber(snapshot and snapshot.maxSlots) or 0))
        if maxSlots <= 0 then
            return false
        end
        local slots = (snapshot and snapshot.equippedSlots) or {}
        for index = 1, maxSlots do
            if not slots[index] then
                return false
            end
        end
        return true
    end,

    squad_has_role = function(snapshot, cond)
        local want = tostring((cond and cond.role) or "")
        if want == "" then
            return false
        end
        for _, desc in pairs((snapshot and snapshot.equippedSlots) or {}) do
            if desc and roleOf(snapshot, desc.id) == want then
                return true
            end
        end
        return false
    end,
}

function TutorialUnlock.hasCheck(name)
    return type(name) == "string" and type(TutorialUnlock.checks[name]) == "function"
end

function TutorialUnlock.isMet(cond, snapshot)
    if type(cond) ~= "table" then
        return false
    end
    local fn = TutorialUnlock.checks[tostring(cond.check or "")]
    if type(fn) ~= "function" then
        return false
    end
    return fn(snapshot, cond) == true
end

function TutorialUnlock.firstFailure(conditions, snapshot)
    if type(conditions) ~= "table" then
        return nil
    end
    for _, cond in ipairs(conditions) do
        if not TutorialUnlock.isMet(cond, snapshot) then
            return cond
        end
    end
    return nil
end

function TutorialUnlock.allMet(conditions, snapshot)
    return TutorialUnlock.firstFailure(conditions, snapshot) == nil
end

function TutorialUnlock.concat(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        if type(list) == "table" then
            for _, cond in ipairs(list) do
                out[#out + 1] = cond
            end
        end
    end
    return out
end

return TutorialUnlock
