-- Isolated production route/leash/march blocks; no running services or account data.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local source = game.ServerScriptService.Server.Services.EnemyService.Source
local function section(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a, true))
    return source:sub(a, b - 1)
end
local fixture = Instance.new("Folder")
fixture.Name = "IsolatedMergeChaseSmoke"
fixture.Parent = game.ServerStorage
for _, name in ipairs({ "EnemyLeash", "EnemyMarchGoal", "CrowdControl", "OnHitEffects" }) do
    game.ReplicatedStorage.Shared.Game[name]:Clone().Parent = fixture
end
local factory = Instance.new("ModuleScript")
factory.Source = [[
local EnemyLeash = require(script.Parent.EnemyLeash)
local EnemyMarchGoal = require(script.Parent.EnemyMarchGoal)
local CrowdControl = require(script.Parent.CrowdControl)
local OnHitEffects = require(script.Parent.OnHitEffects)
local EnemyService = {}
]] .. section(
    "function EnemyService:_leashToHomeArea(",
    "function EnemyService:_outsideMovementLeash("
) .. section("function EnemyService:_clearChasePath(", "-- Compute/follow a Roblox navmesh route") .. section(
    "function EnemyService:_followAuthoredMarchGoal(",
    "function EnemyService:_loiter("
) .. [[
function EnemyService:route(entry, ePos, targetPos, eng, chaseTo)
local model, targetId = entry.model, 1
]] .. section('    local route = "direct"', "    local np = EnemyAI.chaseStep(") .. [[
return chaseTo, route
end
return EnemyService
]]
factory.Parent = fixture
local ok, result = pcall(function()
    local service = require(factory)
    local model = Instance.new("Model")
    model.Parent = fixture
    local entry = { model = model, chasePath = { "old" }, pos = Vector3.zero }
    local rayCalls, pathCalls, dropCalls = 0, 0, 0
    local pathFails = false
    function service:_directChaseBlocked()
        rayCalls += 1
        return true
    end
    function service:_chasePathWaypoint()
        pathCalls += 1
        if pathFails then
            return nil, "NoPath"
        end
        return Vector3.new(5, 0, 5), "path"
    end
    function service:_dropUnreachableEngagement()
        dropCalls += 1
    end
    function service:_groundedY(_, _, _, fallback)
        return fallback
    end
    service._leashRegions = {}
    service._combatConfig = require(game.ReplicatedStorage.Configs.combat)
    local eng = service._combatConfig.engagement
    local destination = Vector3.new(100, 3, 100)
    model:SetAttribute("MergeEggPrototypeEnemy", true)
    local point, route = service:route(entry, Vector3.zero, destination, eng, destination)
    assert(point == destination and route == "direct")
    assert(rayCalls == 0 and pathCalls == 0 and dropCalls == 0, "Merge queried obstacles")
    assert(entry.chasePath == nil, "old route retained")
    model:SetAttribute("MergeEggPrototypeEnemy", nil)
    point, route = service:route(entry, Vector3.zero, destination, eng, destination)
    assert(point == Vector3.new(5, 0, 5) and route == "path", "other-world routing changed")
    assert(rayCalls == 1 and pathCalls == 1)
    pathFails = true
    assert(service:route(entry, Vector3.zero, destination, eng, destination) == nil)
    assert(dropCalls == 1, "unreachable non-Merge target no longer released")
    pathFails = false
    model:SetAttribute("MergeEggPrototypeEnemy", true)
    local rollback = table.clone(eng)
    rollback.pathfinding = table.clone(eng.pathfinding)
    rollback.pathfinding.merge_enabled = true
    _, route = service:route(entry, Vector3.zero, destination, rollback, destination)
    assert(route == "path", "config rollback ignored")
    -- The actual bay leash preserves Y and clamps both X/Z, including an inset.
    entry.movementLeash = {
        shapes = { { kind = "box", cx = 0, cz = 0, halfX = 10, halfZ = 20 } },
        inset = 2,
    }
    local clamped = service:_leashToHomeArea(entry, destination)
    assert(clamped == Vector3.new(8, 3, 18), "pursuit escaped its bay")
    -- The spawn march is the same directional mover, still clamped and control-gated.
    entry.pos = Vector3.zero
    entry.marchGoal = { destination = { x = 100, z = 0 }, speed = 100, arriveDistance = 0 }
    assert(service:_followAuthoredMarchGoal(entry, 1, model, entry.pos, 1))
    assert(entry.pos == Vector3.new(8, 0, 0), "march escaped its bay")
    model:SetAttribute("HeldUntil", os.time() + 30)
    entry.pos = Vector3.zero
    entry.marchGoal = { destination = { x = 5, z = 0 }, speed = 10, arriveDistance = 0 }
    assert(service:_followAuthoredMarchGoal(entry, 1, model, entry.pos, 1))
    assert(entry.pos == Vector3.zero, "held marcher moved")
    return "PASS: Merge direct/no obstacle calls; other-world routing/failure; rollback; chase/march bay clamp; held march"
end)
fixture:Destroy()
assert(ok, result)
return result
