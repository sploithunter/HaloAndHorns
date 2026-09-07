-- Execute in Studio Edit. Isolated fixtures exercise the actual client inventory/collector.
local source = game.StarterPlayer.StarterPlayerScripts.Client.Systems.ArchLightning
local module = Instance.new("ModuleScript")
module.Name = "_ArchInventorySmokeModule"
module.Source = source.Source:gsub(
    "return ArchLightning%s*$",
    "ArchLightning.index = indexCandidates\nArchLightning.collect = collectMarkers\nreturn ArchLightning"
)
module.Parent = game.ReplicatedStorage
local controller = require(module)
local cfg = table.clone(require(game.ReplicatedStorage.Configs.hall_of_worlds).arch_lightning)
cfg.host_names = { "_SmokeArchHost" }
cfg.host_tag = "_SmokeArchTag"
local root = Instance.new("Folder")
root.Name = "_ArchInventorySmoke"
root.Parent = workspace
local release
local function count(set)
    local n = 0
    for _ in pairs(set) do
        n += 1
    end
    return n
end
local function part(parent, name, x)
    local object = Instance.new("Part")
    object.Name = name
    object.Anchored = true
    object.Position = Vector3.new(x, -1000, 0)
    object.Parent = parent
    return object
end
local ok, result = xpcall(function()
    for i = 1, 1000 do
        part(root, "Unrelated", i)
    end
    local host = Instance.new("Model")
    host.Name = "_SmokeArchHost"
    part(host, "Frame", 0).Size = Vector3.new(20, 30, 2)
    host.Parent = root
    local markers, hosts
    markers, hosts, release = controller.index(root, cfg)
    assert(count(hosts) == 1 and count(markers) == 0, "irrelevant objects entered inventory")
    local groups = controller.collect(cfg, markers, hosts)
    assert(#groups == 1 and #groups[1] >= 2, "missing generated endpoints")
    task.wait()
    local initialMarkers = count(markers)
    assert(initialMarkers == #groups[1], "generated endpoints were not registered")
    local firstMarker = groups[1][1]
    groups = controller.collect(cfg, markers, hosts)
    assert(count(markers) == initialMarkers and firstMarker.Parent, "reconcile restamped endpoints")

    local looseA = part(root, "lightning91", 500)
    part(root, "lightning92", 510)
    task.wait()
    assert(markers[looseA], "late streamed endpoint missing")
    assert(#controller.collect(cfg, markers, hosts) == 2, "loose endpoint cluster missing")
    looseA:Destroy()
    task.wait()
    assert(not markers[looseA], "removed endpoint retained")

    host.Parent = nil
    task.wait()
    assert(not hosts[host] and not markers[firstMarker], "streamed-out host retained")
    host.Parent = root
    task.wait()
    assert(hosts[host] and markers[firstMarker], "streamed-in host missing")

    local tagged = Instance.new("Model")
    tagged.Name = "_TagOnly"
    part(tagged, "Frame", 1000)
    tagged.Parent = root
    game.CollectionService:AddTag(tagged, cfg.host_tag)
    task.wait()
    assert(hosts[tagged], "late host tag missing")
    game.CollectionService:RemoveTag(tagged, cfg.host_tag)
    task.wait()
    assert(not hosts[tagged], "removed host tag retained")

    local excluded = Instance.new("Model")
    excluded.Name = "HellGateCrisp_Smoke"
    part(excluded, "lightning101", 2000)
    part(excluded, "lightning102", 2010)
    game.CollectionService:AddTag(excluded, cfg.host_tag)
    excluded.Parent = root
    task.wait()
    for _, group in ipairs(controller.collect(cfg, markers, hosts)) do
        for _, endpoint in ipairs(group) do
            assert(not endpoint:IsDescendantOf(excluded), "dedicated Hell endpoints were adopted")
        end
    end
    return { ok = true, unrelated = 1000, generatedEndpoints = initialMarkers }
end, debug.traceback)
if release then
    release()
end
root:Destroy()
module:Destroy()
assert(ok, result)
return result
