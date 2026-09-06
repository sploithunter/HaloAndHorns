-- Native isolated production-method test + matched indexed/fallback microbenchmark.
-- No service initialization, live enemy mutation, or profile access.
assert(game:GetService("RunService"):IsStudio(), "Studio diagnostics only")
local services = game.ServerScriptService.Server.Services
local followSource = services.PetFollowService.Source
local enemySource = services.EnemyService.Source
local function section(source, firstMarker, lastMarker)
    local first = assert(source:find(firstMarker, 1, true))
    local last = assert(source:find(lastMarker, first + #firstMarker, true))
    return source:sub(first, last - 1)
end
local module = Instance.new("ModuleScript")
module.Name = "IsolatedTargetLookupSmoke"
module.Source = "return function(Workspace) local PetFollowService = {}; local EnemyService = {};\n"
    .. section(
        followSource,
        "function PetFollowService:_findBreakable(",
        "function PetFollowService:_releaseMiningTarget("
    )
    .. section(
        enemySource,
        "function EnemyService:FindTargetModel(",
        "function EnemyService:_setAggroOwner("
    )
    .. [[
    local enemy = setmetatable({_enemies = {}}, {__index=EnemyService})
    local follow = setmetatable({enemy=enemy}, {__index=PetFollowService})
    function follow:_enemyService() return self.enemy end
    return follow, enemy
end
]]
module.Parent = game.ServerStorage
local root = Instance.new("Folder")
local gameFolder = Instance.new("Folder")
gameFolder.Name = "Game"
gameFolder.Parent = root
local enemies = Instance.new("Folder")
enemies.Name = "Enemies"
enemies.Parent = gameFolder
local function target(parent, id)
    local model = Instance.new("Model")
    local value = Instance.new("NumberValue")
    value.Name = "BreakableID"
    value.Value = id
    value.Parent = model
    model.Parent = parent
    return model, value
end
local ok, result = pcall(function()
    local follow, enemy = require(module)(root)
    for id = 1, 100 do
        local model = target(enemies, id)
        for _ = 1, 25 do
            local part = Instance.new("Part")
            part.Parent = model
        end
        enemy._enemies[id] = { model = model }
    end
    local first = enemy._enemies[1].model
    assert(follow:_findBreakable("Enemy", "", 1) == first)
    first:SetAttribute("HP", 0)
    assert(follow:_findBreakable("Enemy", "", 1) == first, "lookup changed HP/death policy")
    first.Parent = root
    assert(follow:_findBreakable("Enemy", "", 1) == nil, "stale cross-scope index accepted")
    first.Parent = enemies
    first.BreakableID.Value = 101
    assert(follow:_findBreakable("Enemy", "", 1) == nil, "changed id returned stale model")
    assert(follow:_findBreakable("Enemy", "", 101) == first, "authored fallback lost")
    first.BreakableID.Value = 1
    enemy._enemies[1] = nil
    assert(follow:_findBreakable("Enemy", "", 1) == first, "unregistered target lost")
    enemy._enemies[1] = { model = first }

    local breakables = Instance.new("Folder")
    breakables.Name = "Breakables"
    breakables.Parent = gameFolder
    local crystals = Instance.new("Folder")
    crystals.Name = "Crystals"
    crystals.Parent = breakables
    for _, name in ipairs({ "Earth", "Ice" }) do
        local world = Instance.new("Folder")
        world.Name = name
        world.Parent = crystals
        local model = target(world, 1)
        assert(
            follow:_findBreakable("Crystals", name, 1) == model,
            "world-scoped crystal lookup changed"
        )
    end

    local timings = {}
    for round = 1, 4 do
        for _, indexed in ipairs(round % 2 == 1 and { false, true } or { true, false }) do
            follow.enemy = indexed and enemy or nil
            local started = os.clock()
            for i = 1, 1000 do
                local id = (i - 1) % 100 + 1
                assert(follow:_findBreakable("Enemy", "", id) == enemy._enemies[id].model)
            end
            timings[#timings + 1] =
                { indexed = indexed, seconds = os.clock() - started, lookups = 1000 }
        end
    end
    follow.enemy = enemy
    first:Destroy()
    assert(follow:_findBreakable("Enemy", "", 1) == nil, "destroyed model returned")
    return { passed = true, timings = timings, descendants = #enemies:GetDescendants() }
end)
root:Destroy()
module:Destroy()
assert(ok, result)
return game:GetService("HttpService"):JSONEncode(result)
