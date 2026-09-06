-- Isolated engine tests. No live service initialization, profile mutation or remote sends.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(not game:GetService("RunService"):IsRunning(), "stop Play before this smoke")
local storage, replicated = game.ServerStorage, game.ReplicatedStorage
assert(not storage:FindFirstChild("_EffectPoolSmoke"), "smoke already exists")
local fixture = Instance.new("Folder")
fixture.Name = "_EffectPoolSmoke"
fixture.Parent = storage
local visualRoot = Instance.new("Folder")
visualRoot.Name = "_EffectPoolSmokeVisuals"
visualRoot.Parent = workspace
local function cloneModule(original, name, replaceFrom, replaceTo)
    local copy = Instance.new("ModuleScript")
    copy.Name = name
    local source = original.Source
    if replaceFrom then
        local a, b = assert(source:find(replaceFrom, 1, true))
        source = source:sub(1, a - 1) .. replaceTo .. source:sub(b + 1)
    end
    copy.Source = source
    copy.Parent = fixture
    return copy
end
cloneModule(replicated.Shared.Utils.LeasePool, "LeasePool")
local module = cloneModule(
    replicated.Shared.Effects.EffectPartPool,
    "EffectPartPool",
    "require(ReplicatedStorage.Shared.Utils.LeasePool)",
    "require(script.Parent.LeasePool)"
)
local rangedModule = cloneModule(
    replicated.Shared.Effects.RangedFX,
    "RangedFX",
    "require(ReplicatedStorage.Shared.Effects.EffectPartPool)",
    "require(script.Parent.EffectPartPool)"
)
local areaModule = cloneModule(
    replicated.Shared.Effects.AreaFX,
    "AreaFX",
    "require(ReplicatedStorage.Shared.Effects.EffectPartPool)",
    "require(script.Parent.EffectPartPool)"
)
-- Isolate all visual output from the real Effects folder, including legacy unpooled paths.
for _, target in { rangedModule, areaModule } do
    local a = assert(target.Source:find("local function fxFolder()", 1, true))
    local b = assert(target.Source:find("\nend", a, true)) + 3
    target.Source = target.Source:sub(1, a - 1)
        .. "local function fxFolder() return workspace._EffectPoolSmokeVisuals end"
        .. target.Source:sub(b + 1)
end
local pools = {}
local function cleanup()
    for _, pool in pools do
        pool.dispose()
    end
    visualRoot:Destroy()
    fixture:Destroy()
end
local ok, result = pcall(function()
    local Pool = require(module)
    local function new(capacity, enabled)
        local pool = Pool.new({ enabled = enabled ~= false, maximum_idle = capacity })
        pools[#pools + 1] = pool
        return pool
    end
    local pool = new(2)
    local part, old = pool.acquire()
    part.Parent = visualRoot
    part.Shape = Enum.PartType.Cylinder
    part.Material = Enum.Material.Glass
    part.MaterialVariant = "test"
    part.Reflectance = 0.6
    part.Transparency = 0.9
    part.LocalTransparencyModifier = 0.8
    part:SetAttribute("OldEffect", true)
    part:AddTag("EffectPoolSmokeTag")
    local light = Instance.new("PointLight")
    light.Parent = part
    local firstTween = pool.tween(part, old, part, TweenInfo.new(2), { Transparency = 1 })
    firstTween:Play()
    pool.retireAfter(part, old, 0.05)
    assert(pool.release(part, old))
    assert(firstTween.PlaybackState ~= Enum.PlaybackState.Playing, "old tween kept running")
    local reused, lease = pool.acquire()
    assert(reused == part and lease ~= old, "did not reuse with a new lease")
    local prototype = Instance.new("Part")
    for _, property in
        {
            "Shape",
            "Material",
            "MaterialVariant",
            "Reflectance",
            "Transparency",
            "LocalTransparencyModifier",
            "Color",
            "Size",
        }
    do
        assert(reused[property] == prototype[property], "reset failed: " .. property)
    end
    prototype:Destroy()
    assert(
        #reused:GetChildren() == 0
            and #reused:GetTags() == 0
            and next(reused:GetAttributes()) == nil,
        "old lease payload retained"
    )
    reused.Parent = visualRoot
    task.wait(0.1)
    assert(
        pool.isCurrent(reused, lease) and reused.Parent == visualRoot,
        "old timeout removed new effect"
    )
    pool.release(reused, lease)
    reused:Destroy()
    local replacement, replacementLease = pool.acquire()
    assert(replacement ~= reused, "destroyed idle object reused")
    replacement:Destroy()
    pool.release(replacement, replacementLease)
    assert(pool.stats().active == 0, "destroyed active object retained")
    local a, la = pool.acquire()
    local b, lb = pool.acquire()
    local c, lc = pool.acquire()
    pool.release(a, la)
    pool.release(b, lb)
    pool.release(c, lc)
    assert(pool.stats().idle == 2, "idle cap incorrect")
    local active, activeLease = pool.acquire()
    pool.retireAfter(active, activeLease, 0.05)
    pool.dispose()
    task.wait(0.1)
    assert(pool.stats().idle == 0 and pool.stats().active == 0, "dispose retained objects")

    local ranged, area = require(rangedModule), require(areaModule)
    local areaConfig = {
        themes = {
            grass = { color = { 80, 200, 80 }, color2 = { 160, 240, 120 }, material = "Neon" },
            ice = { color = { 80, 160, 240 }, color2 = { 180, 230, 255 }, material = "Glass" },
        },
        self = { radius = 6, duration = 0.25 },
    }
    local snapshots, comparisons = {}, {}
    local pos = workspace.CurrentCamera.CFrame.Position
        + workspace.CurrentCamera.CFrame.LookVector * 45
    for _, enabled in { false, true } do
        local effectPool = new(2048, enabled)
        Pool.shared = function()
            return effectPool
        end
        local counts = {}
        for pass = 1, 3 do
            math.randomseed(731)
            for _ = 1, 3 do
                for _, name in { "small", "medium", "big", "shatter", "dust", "bloom" } do
                    ranged.playImpact(name, pos, { 100, 150, 200 }, { 200, 240, 255 }, {})
                end
            end
            assert(area.Play(areaConfig, "grass", "self", pos))
            assert(area.Play(areaConfig, "ice", "self", pos))
            local signature = {}
            for _, p in visualRoot:GetChildren() do
                if p:IsA("Part") then
                    signature[#signature + 1] = table.concat({
                        p.Shape.Name,
                        p.Material.Name,
                        tostring(p.Size),
                        tostring(p.Color),
                        tostring(p.Transparency),
                        tostring(p.Reflectance),
                    }, "|")
                end
            end
            table.sort(signature)
            signature = table.concat(signature, "\n")
            local key = tostring(enabled) .. ":" .. pass
            snapshots[key] = signature
            -- The unchanged grass particle host outlives the pooled blades (1.5 + 0.5 s).
            task.wait(2.2)
            assert(effectPool.stats().active == 0, "completed effects retained active leases")
            local leftovers = {}
            for _, child in visualRoot:GetChildren() do
                leftovers[#leftovers + 1] = child.ClassName
                    .. ":"
                    .. child.Name
                    .. ":"
                    .. tostring(#child:GetChildren())
            end
            assert(
                #leftovers == 0,
                "completed visuals still in Workspace: " .. table.concat(leftovers, ",")
            )
            counts[#counts + 1] = effectPool.stats()
        end
        if enabled then
            for pass = 1, 3 do
                assert(
                    snapshots["false:" .. pass] == snapshots["true:" .. pass],
                    "pooled visual signature changed"
                )
            end
            assert(
                counts[3].created == counts[1].created and counts[3].reused > 0,
                "steady identical effects kept allocating"
            )
        end
        comparisons[#comparisons + 1] = { enabled = enabled, passes = counts }
        effectPool.dispose()
    end
    return { passed = true, visualParity = true, comparisons = comparisons }
end)
cleanup()
assert(ok, result)
return game.HttpService:JSONEncode(result)
