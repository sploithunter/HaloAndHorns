-- Explicitly fetch the mesh, texture, and flat-image dependencies on the player's bounded
-- warm shelf. Merely replicating an invisible template does not guarantee that Roblox fetches its
-- content before the pet hatches. Live Workspace pets are intentionally outside this controller:
-- they remain resident until the server removes them, regardless of unlock-frontier changes.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local config = require(ReplicatedStorage.Configs:WaitForChild("merge_egg_prototype"))
local farmConfig = require(ReplicatedStorage.Configs:WaitForChild("farm_asset_warmup"))
local places = require(ReplicatedStorage.Configs:WaitForChild("places"))
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)

local MergeAssetWarmup = {}
local started = false

local function requiredNumber(value, path)
    local resolved = tonumber(value)
    assert(resolved ~= nil, path .. " must be numeric")
    return resolved
end

local function isContentInstance(instance)
    return instance:IsA("MeshPart")
        or instance:IsA("SpecialMesh")
        or instance:IsA("Decal")
        or instance:IsA("Texture")
        or instance:IsA("SurfaceAppearance")
        or instance:IsA("Animation")
        or instance:IsA("Sound")
        or instance:IsA("ImageLabel")
        or instance:IsA("ImageButton")
end

function MergeAssetWarmup.start()
    if started then
        return
    end
    started = true

    local warmConfig = if PlaceRuntime.isMerge(game.PlaceId, places)
        then ((config.performance or {}).asset_warmup or {})
        else farmConfig
    if warmConfig.enabled ~= true then
        return
    end

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local cacheName = tostring(warmConfig.cache_folder or "MergeAssetWarmCache")
    local batchSize = math.max(
        1,
        math.floor(
            requiredNumber(
                warmConfig.preload_batch_size,
                "merge_egg_prototype.performance.asset_warmup.preload_batch_size"
            )
        )
    )
    local debounce = math.max(
        0,
        requiredNumber(
            warmConfig.preload_debounce_seconds,
            "merge_egg_prototype.performance.asset_warmup.preload_debounce_seconds"
        )
    )
    local seen = setmetatable({}, { __mode = "k" })
    local attempts = setmetatable({}, { __mode = "k" })
    local descendantConnection = nil
    local busy = false
    local pending = false
    local scheduled = false
    local scheduleConnection = nil
    local retryAt = math.huge
    local attachedCache

    local function fetch(batch)
        local failed = false
        local ok = pcall(function()
            ContentProvider:PreloadAsync(batch, function(_, status)
                if status.Name ~= "Success" then
                    failed = true
                end
            end)
        end)
        for _, instance in ipairs(batch) do
            attempts[instance] = (attempts[instance] or 0) + 1
            seen[instance] = ok and not failed
            if not seen[instance] and attempts[instance] < farmConfig.preload_max_attempts then
                retryAt = math.min(retryAt, os.clock() + farmConfig.preload_retry_seconds)
            end
        end
    end

    local function preload(cache)
        if busy then
            pending = true
            return
        end
        busy = true
        repeat
            pending = false
            local models = cache.Parent and cache
            local batch = {}
            if models then
                for _, instance in ipairs(models:GetDescendants()) do
                    if
                        isContentInstance(instance)
                        and not seen[instance]
                        and (attempts[instance] or 0) < farmConfig.preload_max_attempts
                    then
                        batch[#batch + 1] = instance
                        if #batch >= batchSize then
                            fetch(batch)
                            batch = {}
                        end
                    end
                end
            end
            if #batch > 0 then
                fetch(batch)
            end
        until pending ~= true or cache.Parent == nil
        busy = false
        if attachedCache ~= cache and attachedCache and attachedCache.Parent then
            retryAt = 0
        end
    end

    local function schedule(cache)
        if scheduled then
            pending = true
            return
        end
        scheduled = true
        local readyAt = os.clock() + debounce
        scheduleConnection = RunService.Heartbeat:Connect(function()
            if os.clock() < readyAt then
                return
            end
            scheduleConnection:Disconnect()
            scheduleConnection = nil
            scheduled = false
            local current = attachedCache or cache
            if current.Parent then
                task.spawn(preload, current)
            end
        end)
    end

    local function attach(cache)
        attachedCache = cache
        if descendantConnection then
            descendantConnection:Disconnect()
            descendantConnection = nil
        end
        descendantConnection = cache.DescendantAdded:Connect(function()
            schedule(cache)
        end)
        schedule(cache)
    end

    local existing = playerGui:FindFirstChild(cacheName)
    if existing then
        attach(existing)
    end
    playerGui.ChildAdded:Connect(function(child)
        if child.Name == cacheName then
            attach(child)
        end
    end)
    RunService.Heartbeat:Connect(function()
        if os.clock() >= retryAt then
            retryAt = math.huge
            if attachedCache and attachedCache.Parent then
                schedule(attachedCache)
            end
        end
    end)
end

return MergeAssetWarmup
