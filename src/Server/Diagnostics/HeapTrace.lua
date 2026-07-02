--[[
    HeapTrace — server Lua-heap LEAK FINDER.

    The "Server performance severely degraded" stalls (~0.9s heartbeats, sampled every 30s by the
    perf monitor) are GC pauses over a bloated LuaHeap (~841MB live, and growing — see the
    ramp). Roblox Studio can't introspect Lua tables, so this runs IN the game: every interval it
    crawls the live service graph (the ModuleLoader's loaded singletons + _G), records every table's
    entry count, and prints the tables that GREW since the last sample. An unbounded grower is the
    leak — a map keyed by transient ids (pets/enemies/crystals/connections) that never gets cleaned.

    Also prints total Lua MB + the Stats memory tags (LuaHeap / Signals / Instances / Script) and a
    few workspace folder counts, all with per-interval deltas, so you can see the growth RATE and
    whether it's Lua-side or instance-side.

    Studio-gated (started from init.server only under IsStudio). print()-based so the lines are easy
    to grep/paste: filter the Output on "[HeapTrace]".

    Usage: HeapTrace.start({ interval = 15, roots = { _G = _G, services = loader:GetLoadedModules() } })
]]

local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local HeapTrace = {}

local function luaMb()
    return collectgarbage("count") / 1024
end

local function tagMb(tag)
    local ok, mb = pcall(function()
        return Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag[tag])
    end)
    return (ok and mb) or 0
end

local function entryCount(t)
    local n = 0
    for _ in pairs(t) do
        n += 1
    end
    return n
end

-- Crawl Lua tables only (recurses solely on type == "table", so Instances/userdata are skipped
-- naturally). Bounded by depth + a global node budget + a visited set (no cycles, no double-count)
-- so the probe itself can never hitch. Records path -> entry count into `sizes`.
local function walk(node, path, depth, visited, sizes, budget)
    if budget.n <= 0 or type(node) ~= "table" or visited[node] then
        return
    end
    visited[node] = true
    budget.n -= 1
    sizes[path] = entryCount(node)
    if depth <= 0 or #path > 140 then
        return
    end
    for k, v in pairs(node) do
        if type(v) == "table" and not visited[v] then
            local key = (type(k) == "string") and k or ("[" .. tostring(k) .. "]")
            walk(v, path .. "." .. key, depth - 1, visited, sizes, budget)
        end
    end
end

local function folderCount(dotPath)
    local node = Workspace
    for seg in string.gmatch(dotPath, "[^%.]+") do
        node = node and node:FindFirstChild(seg)
    end
    return node and #node:GetDescendants() or 0
end

function HeapTrace.start(opts)
    opts = opts or {}
    local interval = opts.interval or 15
    local depth = opts.depth or 3
    local topN = opts.topN or 14
    local nodeBudget = opts.nodeBudget or 60000
    local minDelta = opts.minDelta or 1 -- only report tables that grew by at least this many entries
    local roots = opts.roots or {}
    local folders = opts.instanceFolders or { "Game.Breakables", "Game.Chaseables", "PlayerPets" }

    local prevSizes, prevLua, prevFolders = {}, nil, {}

    task.spawn(function()
        print(
            string.format(
                "[HeapTrace] started (interval=%ds, depth=%d, budget=%d)",
                interval,
                depth,
                nodeBudget
            )
        )
        while true do
            task.wait(interval)
            local ok, err = pcall(function()
                local lua = luaMb()
                local dLua = prevLua and (lua - prevLua) or 0
                prevLua = lua
                print(
                    string.format(
                        "[HeapTrace] LuaHeap=%.0fMB (%+.1f/%ds) | tags lua=%.0f signals=%.0f instances=%.0f script=%.0f",
                        lua,
                        dLua,
                        interval,
                        tagMb("LuaHeap"),
                        tagMb("Signals"),
                        tagMb("Instances"),
                        tagMb("Script")
                    )
                )

                local sizes = {}
                local visited = {}
                local budget = { n = nodeBudget }
                for name, t in pairs(roots) do
                    if type(t) == "table" then
                        walk(t, tostring(name), depth, visited, sizes, budget)
                    end
                end

                local growers = {}
                for path, count in pairs(sizes) do
                    local d = count - (prevSizes[path] or count)
                    if d >= minDelta then
                        growers[#growers + 1] = { path = path, count = count, delta = d }
                    end
                end
                table.sort(growers, function(a, b)
                    return a.delta > b.delta
                end)
                if #growers == 0 then
                    print(
                        "[HeapTrace]   (no table grew this interval — leak may be in a table not on the walked graph, or instance-side)"
                    )
                else
                    for i = 1, math.min(topN, #growers) do
                        local g = growers[i]
                        print(
                            string.format(
                                "[HeapTrace]   +%-6d now=%-8d %s",
                                g.delta,
                                g.count,
                                g.path
                            )
                        )
                    end
                end
                prevSizes = sizes
                print(
                    string.format(
                        "[HeapTrace]   (walked %d tables, budget left %d)",
                        nodeBudget - budget.n,
                        budget.n
                    )
                )

                for _, fpath in ipairs(folders) do
                    local n = folderCount(fpath)
                    local d = n - (prevFolders[fpath] or n)
                    prevFolders[fpath] = n
                    print(string.format("[HeapTrace]   inst %s = %d (%+d)", fpath, n, d))
                end
            end)
            if not ok then
                warn("[HeapTrace] error: " .. tostring(err))
            end
        end
    end)
end

return HeapTrace
