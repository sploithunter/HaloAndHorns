-- Production client worker, mocked content delivery; no network calls or real PlayerGui changes.
local source = game.StarterPlayer.StarterPlayerScripts.Client.Systems.MergeAssetWarmup.Source
local first = assert(source:find("local MergeAssetWarmup =", 1, true))
local function fresh(module)
    return assert(loadstring(module.Source))()
end
local cfg = fresh(game.ReplicatedStorage.Configs.farm_asset_warmup)
local function signal()
    local listeners = {}
    return {
        Connect = function(_, fn)
            local conn = { Connected = true }
            function conn:Disconnect()
                self.Connected = false
            end
            listeners[conn] = fn
            return conn
        end,
        Fire = function(_, ...)
            local copy = table.clone(listeners)
            for conn, fn in pairs(copy) do
                if conn.Connected then
                    fn(...)
                end
            end
        end,
    }
end
local root = Instance.new("Folder")
local function shelf()
    local cache = Instance.new("Folder")
    cache.Name, cache.Parent = cfg.cache_folder, root
    local mesh = Instance.new("MeshPart")
    mesh.Parent = cache
    local image = Instance.new("ImageLabel")
    image.Parent = cache
    return cache
end
local cache, clock, calls, mode = shelf(), 0, 0, "fail"
local heartbeat, childAdded = signal(), signal()
local gui = {
    FindFirstChild = function()
        return cache
    end,
    ChildAdded = childAdded,
}
local player = {
    WaitForChild = function()
        return gui
    end,
}
local module = assert(
    loadstring(
        "local ContentProvider, Players, ReplicatedStorage, RunService, config, farmConfig, places, PlaceRuntime, game, task, os = ...\n"
            .. source:sub(first)
    )
)(
    {
        PreloadAsync = function(_, batch, callback)
            calls += 1
            assert(#batch == 2, "Both model and flat image must preload")
            callback("fixture", { Name = mode == "fail" and "Failure" or "Success" })
        end,
    },
    { LocalPlayer = player },
    {},
    { Heartbeat = heartbeat },
    {},
    cfg,
    {},
    {
        isMerge = function()
            return false
        end,
    },
    { PlaceId = 0 },
    {
        spawn = function(fn, ...)
            fn(...)
        end,
    },
    {
        clock = function()
            return clock
        end,
    }
)
local ok, result = pcall(function()
    module.start()
    local function advance(seconds)
        clock += seconds
        heartbeat:Fire()
        clock += cfg.preload_debounce_seconds
        heartbeat:Fire()
    end
    advance(1)
    assert(calls == 1, "Initial prefetch missing")
    mode = "success"
    advance(cfg.preload_retry_seconds + 1)
    assert(calls == 2, "Failed content was never retried")
    advance(cfg.preload_retry_seconds + 1)
    assert(calls == 2, "Successful content refetched")
    cache:Destroy()
    cache = shelf()
    mode = "fail"
    childAdded:Fire(cache)
    for _ = 1, cfg.preload_max_attempts + 2 do
        advance(cfg.preload_retry_seconds + 1)
    end
    assert(calls == 2 + cfg.preload_max_attempts, "Permanent failure retry budget exceeded")
    return "PASS: images and mesh prefetch together, transient retry succeeds, successful work deduplicates, replacement cache loads, permanent failure retries bounded"
end)
root:Destroy()
assert(ok, result)
return result
