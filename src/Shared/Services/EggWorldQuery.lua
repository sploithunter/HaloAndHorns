local CollectionService = game:GetService("CollectionService")

local EggWorldQuery = {}

local EGGS_TAG = "EggStand"
-- How often to re-scan tagged eggs after init, so eggs that stream in late (teleporting to a
-- StreamingEnabled world) get registered once their attributes/anchor have replicated.
local RESYNC_INTERVAL = 2

local eggs = {}
local eggsByInstance = {}
local eggsByType = {}
local initialized = false

local function isUsable(instance)
    return instance and instance:IsDescendantOf(workspace)
end

local function readStringValue(instance, name)
    local child = instance:FindFirstChild(name)
    if child and child:IsA("StringValue") then
        return child.Value
    end
    return nil
end

local function findStandUiAnchor(instance)
    local current = instance
    while current and current ~= workspace do
        local uiAnchor = current:FindFirstChild("UIanchor")
        if uiAnchor and uiAnchor:IsA("BasePart") and isUsable(uiAnchor) then
            return uiAnchor
        end
        current = current.Parent
    end
    return nil
end

function EggWorldQuery.GetEggType(instance)
    if not instance then
        return nil
    end

    local eggType = instance:GetAttribute("EggType")
        or instance:GetAttribute("EggId")
        or readStringValue(instance, "EggType")
        or readStringValue(instance, "EggId")

    if type(eggType) == "string" and eggType ~= "" then
        return eggType
    end

    return nil
end

function EggWorldQuery.GetAnchor(instance)
    if not instance then
        return nil
    end

    local spawnPointRef = instance:FindFirstChild("SpawnPoint")
    if spawnPointRef and spawnPointRef:IsA("ObjectValue") and isUsable(spawnPointRef.Value) then
        return spawnPointRef.Value
    end

    local standUiAnchor = findStandUiAnchor(instance)
    if standUiAnchor then
        return standUiAnchor
    end

    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        local uiAnchor = instance:FindFirstChild("UIanchor")
        if uiAnchor and uiAnchor:IsA("BasePart") then
            return uiAnchor
        end
        if instance.PrimaryPart then
            return instance.PrimaryPart
        end
        return instance:FindFirstChildWhichIsA("BasePart", true)
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function removeFromList(list, record)
    for index, entry in ipairs(list) do
        if entry == record then
            local lastIndex = #list
            list[index] = list[lastIndex]
            list[lastIndex] = nil
            return
        end
    end
end

local function unregister(instance)
    local record = eggsByInstance[instance]
    if not record then
        return
    end

    eggsByInstance[instance] = nil
    removeFromList(eggs, record)

    local typed = eggsByType[record.eggType]
    if typed then
        removeFromList(typed, record)
        if #typed == 0 then
            eggsByType[record.eggType] = nil
        end
    end
end

local function register(instance)
    if not isUsable(instance) then
        unregister(instance)
        return
    end

    local eggType = EggWorldQuery.GetEggType(instance)
    local anchor = eggType and EggWorldQuery.GetAnchor(instance)
    if not (eggType and anchor) then
        unregister(instance)
        return
    end

    local existing = eggsByInstance[instance]
    if existing then
        if existing.eggType ~= eggType then
            unregister(instance)
        else
            existing.anchor = anchor
            return
        end
    end

    local record = {
        instance = instance,
        eggType = eggType,
        anchor = anchor,
    }

    eggsByInstance[instance] = record
    eggs[#eggs + 1] = record

    local typed = eggsByType[eggType]
    if not typed then
        typed = {}
        eggsByType[eggType] = typed
    end
    typed[#typed + 1] = record
end

local function isEggCandidate(instance)
    return instance:IsA("Model") or instance:IsA("BasePart")
end

local function maybeRegisterCandidate(instance)
    if not isEggCandidate(instance) then
        return
    end

    if CollectionService:HasTag(instance, EGGS_TAG) or EggWorldQuery.GetEggType(instance) then
        register(instance)
    end
end

local function resyncAll()
    for _, instance in ipairs(CollectionService:GetTagged(EGGS_TAG)) do
        register(instance)
    end

    for instance in pairs(eggsByInstance) do
        if not isUsable(instance) then
            unregister(instance)
        else
            register(instance)
        end
    end
end

local function ensureInitialized()
    if initialized then
        return
    end
    initialized = true

    resyncAll()

    CollectionService:GetInstanceAddedSignal(EGGS_TAG):Connect(register)
    CollectionService:GetInstanceRemovedSignal(EGGS_TAG):Connect(unregister)

    workspace.DescendantAdded:Connect(maybeRegisterCandidate)
    workspace.DescendantRemoving:Connect(function(instance)
        unregister(instance)
    end)

    -- EggStandPlacement tags eggs shortly after play starts; resync catches that race.
    task.defer(resyncAll)
    task.delay(2, resyncAll)
    task.delay(5, resyncAll)

    -- LATE STREAM-INS (StreamingEnabled world teleports): an egg in another world (e.g. the Heaven_1
    -- solar egg) isn't replicated to the client at boot, so every resync above misses it. When the
    -- player teleports up and it streams in, the tag/DescendantAdded signals can fire BEFORE its
    -- EggId attribute or stand UIanchor have replicated — register() then bails (it needs both) and
    -- never retries (the #eggs==0 guard in GetEggs stops firing once Home eggs are registered). A
    -- light recurring resync self-heals: register() is idempotent and cheap for a handful of stands.
    task.spawn(function()
        while true do
            task.wait(RESYNC_INTERVAL)
            resyncAll()
        end
    end)
end

function EggWorldQuery.GetEggs()
    ensureInitialized()
    if #eggs == 0 then
        resyncAll()
    end
    return eggs
end

function EggWorldQuery.GetEggsByType(eggType)
    ensureInitialized()
    if #eggs == 0 then
        resyncAll()
    end
    return eggsByType[eggType] or {}
end

function EggWorldQuery.FindEggByType(eggType)
    local typed = EggWorldQuery.GetEggsByType(eggType)
    return typed[1] and typed[1].instance or nil
end

function EggWorldQuery.FindClosestEgg(playerPosition, eggTypes, maxDistance)
    local allowed = {}
    if type(eggTypes) == "table" then
        for _, eggType in ipairs(eggTypes) do
            allowed[eggType] = true
        end
    end

    local closest = nil
    local closestDistance = maxDistance or math.huge

    for _, egg in ipairs(EggWorldQuery.GetEggs()) do
        if (not eggTypes or allowed[egg.eggType]) and egg.anchor then
            local distance = (egg.anchor.Position - playerPosition).Magnitude
            if distance <= closestDistance then
                closest = egg
                closestDistance = distance
            end
        end
    end

    return closest, closestDistance
end

function EggWorldQuery.IsNearEggType(eggType, position, maxDistance)
    for _, egg in ipairs(EggWorldQuery.GetEggsByType(eggType)) do
        if egg.anchor and (position - egg.anchor.Position).Magnitude <= maxDistance then
            return true, egg.instance
        end
    end

    return false, nil
end

function EggWorldQuery.ShouldSpawnVisualAtHook(hook, spawnPointName)
    if not hook or not hook:IsA("BasePart") then
        return false
    end

    local spawnMode = hook:GetAttribute("SpawnMode")
    if spawnMode == "authored" or hook:GetAttribute("AuthoredVisual") == true then
        return false
    end

    if spawnMode == "spawn_model" or hook:GetAttribute("Synthetic") == true then
        return true
    end

    if spawnPointName and hook.Name == spawnPointName then
        return hook.Transparency >= 0.95
    end

    return hook.Transparency >= 0.95
end

return EggWorldQuery
