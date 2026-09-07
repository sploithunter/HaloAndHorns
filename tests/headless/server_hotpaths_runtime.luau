-- Execute production hot paths with isolated doubles; no services, profiles or live actors.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local function method(class, name, env)
    local source = fs.readFile("src/Server/Services/" .. class .. ".lua")
    local first = assert(source:find("function " .. class .. ":" .. name .. "(", 1, true))
    local last = source:find("\nfunction ", first + 1, true) or (#source + 1)
    return luau.load(
        "local "
            .. class
            .. "={}\n"
            .. source:sub(first, last - 1)
            .. "\nreturn "
            .. class
            .. "."
            .. name,
        { environment = env }
    )()
end
local function object(kind, attrs)
    local obj =
        { attrs = attrs or {}, children = {}, scans = 0, reads = {}, hooks = {}, Parent = true }
    function obj:IsA(name)
        return name == kind
    end
    function obj:GetAttribute(name)
        self.reads[name] = (self.reads[name] or 0) + 1
        return self.attrs[name]
    end
    function obj:SetAttribute(name, value)
        self.attrs[name] = value
    end
    function obj:GetChildren()
        return self.children
    end
    function obj:GetDescendants()
        self.scans += 1
        return self.children
    end
    obj.DescendantAdded = {
        Connect = function(_, fn)
            table.insert(obj.hooks, fn)
        end,
    }
    function obj:add(child)
        table.insert(self.children, child)
        for _, hook in ipairs(self.hooks) do
            hook(child)
        end
    end
    return obj
end

local setPosted = method("MergeEggPrototypeService", "_setVendorPosted", { Enum = roblox.Enum })
local service, rig = {}, object("Model")
local part, prompt, humanoid = object("BasePart"), object("ProximityPrompt"), object("Humanoid")
part.Transparency = 0.25
rig:add(part)
rig:add(prompt)
rig:add(humanoid)
setPosted(service, rig, true)
assert(part.Transparency == 0.25 and prompt.Enabled and part.CanCollide == false)
for _ = 1, 100 do
    setPosted(service, rig, true)
end
assert(rig.scans == 1 and #rig.hooks == 1, "unchanged vendors must not traverse or reconnect")
setPosted(service, rig, false)
assert(part.Transparency == 1 and not prompt.Enabled)
assert(humanoid.DisplayDistanceType == roblox.Enum.HumanoidDisplayDistanceType.None)
local late = object("BasePart")
late.Transparency = 0.4
rig:add(late)
assert(late.Transparency == 1, "late descendants must inherit hidden state")
setPosted(service, rig, true)
assert(part.Transparency == 0.25 and late.Transparency == 0.4 and prompt.Enabled)
assert(humanoid.DisplayDistanceType == roblox.Enum.HumanoidDisplayDistanceType.Viewer)
-- Cloning copies attributes, but not live event connections or weak cache ownership.
local clone = object("Model", table.clone(rig.attrs))
setPosted(service, clone, true)
assert(clone.scans == 1 and #clone.hooks == 1)
local clonePart = object("BasePart")
clonePart.Transparency = 0.7
clone:add(clonePart)
setPosted(service, clone, false)
assert(clonePart.Transparency == 1 and part.Transparency == 0.25)
assert(getmetatable(service._vendorPostedStates).__mode == "k")

local AggroTable = luau.load(fs.readFile("src/Shared/Game/AggroTable.lua"))()
local AggroModel = luau.load(fs.readFile("src/Shared/Game/AggroModel.lua"))()
local cfg = luau.load(fs.readFile("configs/aggro.lua"))()
local pets, folder = object("Folder"), object("Folder")
pets:add(folder)
local aggroPass = method("EnemyService", "_petAggroPass", {
    Workspace = {
        FindFirstChild = function()
            return pets
        end,
    },
    AggroTable = AggroTable,
    AggroModel = AggroModel,
})
local enemyService = { _enemies = {}, _petCombat = {} }
function enemyService:_petFollowService() end
function enemyService:_playerForPetFolder()
    return {}
end
function enemyService:_petPosition(pet)
    return pet.pos
end
function enemyService:_petAggroTable(pet)
    self._petCombat[pet] = self._petCombat[pet] or { threat = AggroTable.new() }
    return self._petCombat[pet].threat
end
function enemyService:_petHostileToEnemy(_, entry)
    return entry.hostile ~= false
end
local radius = cfg.base.seed_radius
for i, row in ipairs({
    { 0, 0, 0, true, 10 },
    { -radius, 0, 0, true, 10 },
    { 0, radius + 1, 0, true, 10 },
    { radius + 1, 0, 0, true, 10 },
    { 0, 0, 0, false, 10 },
    { 0, 0, 0, true, 0 },
}) do
    enemyService._enemies[i] = {
        pos = roblox.Vector3.new(row[1], row[2], row[3]),
        hostile = row[4],
        model = object("Model", { HP = row[5] }),
    }
end
local detached = object("Model", { HP = 10 })
detached.Parent = nil
enemyService._enemies[7] = { pos = roblox.Vector3.zero, model = detached }
for _ = 1, 80 do
    local pet = object("Model")
    pet.PrimaryPart = true
    pet.pos = roblox.Vector3.zero
    folder:add(pet)
end
local dt = 0.1
aggroPass(enemyService, 0, dt, cfg)
local seed = AggroModel.seedThreat(cfg, "pet", dt)
assert(seed > 0)
for _, pet in ipairs(folder.children) do
    local threat = enemyService:_petAggroTable(pet)
    assert(AggroTable.get(threat, 1) == seed and AggroTable.get(threat, 2) == seed)
    for id = 3, 7 do
        assert(AggroTable.get(threat, id) == 0, "range, hostility and liveness must be preserved")
    end
end
assert(enemyService._enemies[1].model.reads.HP == 1, "one HP read per enemy, not per pet")
enemyService._enemies[1].model.attrs.HP = 0
enemyService._enemies[2].pos = roblox.Vector3.new(radius + 1, 0, 0)
enemyService._enemies[4].pos = roblox.Vector3.zero
aggroPass(enemyService, dt, dt, cfg)
for _, pet in ipairs(folder.children) do
    local threat = enemyService:_petAggroTable(pet)
    assert(AggroTable.get(threat, 1) < seed and AggroTable.get(threat, 2) < seed)
    assert(AggroTable.get(threat, 4) == seed, "liveness and movement must be refreshed next pass")
end
print(
    "PASS: vendor transitions, late descendants, clones, weak ownership; 80-pet aggro range/liveness/movement and bounded HP reads"
)

local CommandBus = luau.load(fs.readFile("src/Shared/API/CommandBus.lua"))()
local bus = CommandBus.new()
local api = fs.readFile("src/Server/Services/GameAPIService.lua")
local first = assert(api:find('    bus:register("power.menu.get",', 1, true))
local last = assert(api:find("\n    bus:register(", first + 1, true))
luau.load(api:sub(first, last - 1), { environment = { bus = bus } })()
local caller = { player = {}, origin = CommandBus.Origin.Network, isTest = false }
local states = {
    ["archetype.get"] = { ok = true, archetype = "cryomancer" },
    ["levelup.getState"] = {
        ok = true,
        state = {
            claimedLevel = 12,
            pendingLevels = 1,
            canClaim = true,
            nextLevel = 13,
            nextEntry = { slots = 2 },
        },
    },
    ["power.get"] = { ok = true, powers = { "heal", "swift" } },
    ["augment.get"] = { ok = true, slots = { heal = { {}, {} }, swift = { {} } } },
    ["enh.get"] = { ok = true, slots = { heal = { { enh = { type = "heal" } } } } },
    ["enhancement.shop.upgrade_all_preview"] = { ok = true, count = 1, cost = 10 },
}
local calls = 0
for name, state in pairs(states) do
    bus:register(name, {
        handler = function(context, args)
            assert(
                context == caller and next(args) == nil,
                "reads must retain caller and ignore client overrides"
            )
            calls += 1
            return state
        end,
    })
end
local snapshot =
    bus:execute(caller, "power.menu.get", { player = {}, level = 50, commands = { "reset" } })
assert(snapshot.ok and snapshot.result.ok and calls == 6)
assert(snapshot.result.enhancements == states["enh.get"])
assert(snapshot.result.upgradePreview == states["enhancement.shop.upgrade_all_preview"])
states["augment.get"].ok = false
states["augment.get"].reason = "data_not_loaded"
local failed = bus:execute(caller, "power.menu.get", {})
assert(failed.ok and not failed.result.ok and failed.result.reason == "data_not_loaded")
states["augment.get"].ok = true
local menuSource = fs.readFile("src/Client/UI/Menus/PowerChoiceMenu.lua")
first = assert(menuSource:find("function PowerChoiceMenu:_loadLive()", 1, true))
last = assert(menuSource:find("\nfunction PowerChoiceMenu:", first + 1, true))
local requests, available = 0, true
local loadLive = luau.load(
    "local PowerChoiceMenu={}\n"
        .. menuSource:sub(first, last - 1)
        .. "\nreturn PowerChoiceMenu._loadLive",
    {
        environment = {
            MAX_LEVEL = 50,
            callBus = function(name)
                assert(name == "power.menu.get")
                requests += 1
                return available and bus:execute(caller, name, {}).result or nil
            end,
        },
    }
)()
local menu = { staged = { "discard" } }
assert(loadLive(menu) and requests == 1)
assert(menu.archetype == "cryomancer" and menu.level == 13 and menu.claimedLevel == 12)
assert(
    menu.pendingSlots == 2 and menu.owned.heal == 2 and menu.owned.swift == 1 and #menu.staged == 0
)
assert(menu.enhSlots == states["enh.get"].slots and menu.upgradePreview.cost == 10)
available = false
assert(not loadLive(menu))
print(
    "PASS: fixed authoritative snapshot, caller isolation, failure propagation and single-request Powers menu hydration"
)
