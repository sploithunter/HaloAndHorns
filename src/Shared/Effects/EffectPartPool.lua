-- Private procedural Parts only. Never accept pets, authored models or borrowed parts.
-- All lifetimes use leases instead of Debris so an old timer cannot delete a reused effect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LeasePool = require(ReplicatedStorage.Shared.Utils.LeasePool)

local EffectPartPool = {}
local RESET_PROPERTIES = {
    "Name",
    "Shape",
    "Size",
    "CFrame",
    "Color",
    "Material",
    "MaterialVariant",
    "Transparency",
    "LocalTransparencyModifier",
    "Reflectance",
    "CastShadow",
    "PivotOffset",
    "TopSurface",
    "BottomSurface",
}

function EffectPartPool.new(config)
    config = config or {}
    local capacity = 0 -- Disabled means no idle retention, not a second tuning default.
    if config.enabled == true then
        assert(type(config.maximum_idle) == "number", "enabled effect pool needs maximum_idle")
        capacity = config.maximum_idle
    end
    local prototype = Instance.new("Part")
    local defaults = {}
    for _, property in ipairs(RESET_PROPERTIES) do
        defaults[property] = prototype[property]
    end
    prototype:Destroy()
    -- Private, unreplicated ownership marker. Destroy() clears Parent immediately even
    -- when Destroying notifications are deferred, so dead idle Parts cannot be reused.
    local idleRoot = Instance.new("Folder")
    idleRoot.Name = "IdleEffectParts"
    local records = {}
    local factory = {}
    function factory.create()
        local part = Instance.new("Part")
        local record = { tweens = {}, dead = false }
        records[part] = record
        record.destroying = part.Destroying:Connect(function()
            record.dead = true
        end)
        return part
    end
    function factory.usable(part)
        local record = records[part]
        return record ~= nil and not record.dead and part.Parent == idleRoot
    end
    function factory.reset(part)
        part.Parent = nil
        for _, property in ipairs(RESET_PROPERTIES) do
            part[property] = defaults[property]
        end
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end
    function factory.clean(part)
        local record = records[part]
        if not record then
            return
        end
        for _, tween in ipairs(record.tweens) do
            tween:Cancel()
            tween:Destroy()
        end
        table.clear(record.tweens)
        if not record.dead then
            local ok = pcall(function()
                part.Parent = idleRoot
            end)
            if not ok then
                record.dead = true
                return
            end
            part:ClearAllChildren()
            for name in pairs(part:GetAttributes()) do
                part:SetAttribute(name, nil)
            end
            for _, tag in ipairs(part:GetTags()) do
                part:RemoveTag(tag)
            end
        end
    end
    function factory.destroy(part)
        local record = records[part]
        if record then
            record.destroying:Disconnect()
            records[part] = nil
        end
        part:Destroy()
    end
    local pool = LeasePool.new(capacity, factory)
    local api = {}
    function api.acquire()
        return pool:acquire()
    end
    function api.isCurrent(part, lease)
        local record = records[part]
        return pool:isCurrent(part, lease) and record ~= nil and not record.dead
    end
    function api.release(part, lease)
        return pool:release(part, lease)
    end
    function api.retireAfter(part, lease, lifetime)
        -- Animation lifetime, not readiness polling. Lease identity fences late callbacks.
        task.delay(lifetime, function()
            pool:release(part, lease)
        end)
    end
    function api.tween(part, lease, target, info, properties)
        assert(api.isCurrent(part, lease), "effect lease is no longer active")
        assert(target == part or target:IsDescendantOf(part), "tween target is not lease-owned")
        local tween = TweenService:Create(target, info, properties)
        table.insert(records[part].tweens, tween)
        return tween
    end
    function api.stats()
        return pool:stats()
    end
    function api.dispose()
        pool:dispose()
        idleRoot:Destroy()
    end
    return api
end

local sharedPool
function EffectPartPool.shared()
    if not sharedPool then
        local config = require(ReplicatedStorage.Configs.combat_fx)
        sharedPool = EffectPartPool.new(config.part_pool)
    end
    return sharedPool
end

-- Read-only diagnostics; querying must not create the lazy pool.
function EffectPartPool.stats()
    return sharedPool and sharedPool.stats() or nil
end

return EffectPartPool
