-- Studio-only isolated test of the actual _tick implementation, without starting
-- another service/module graph or touching live pets, combat, or profiles.
assert(game:GetService("RunService"):IsStudio(), "Studio diagnostics only")
local source = game.ServerScriptService.Server.Services.PetFollowService.Source
assert(
    source:find("if now >= readyAt then", 1, true),
    "Restart Play: cooldown cleanup source is not loaded"
)
local first = assert(source:find("function PetFollowService:_tick()", 1, true))
local last = assert(source:find("\nreturn PetFollowService", first, true))
local module = Instance.new("ModuleScript")
module.Name = "IsolatedCooldownSmoke"
module.Source = "local Principal = { all = function() return {} end }; local PRINCIPAL_CTX = {}; local PetFollowService = {};\n"
    .. source:sub(first, last - 1)
    .. "\nreturn PetFollowService"
module.Parent = game.ServerStorage
local retired = Instance.new("Model")
local temporarilyDetached = Instance.new("Model")
local ok, result = pcall(function()
    local service = require(module)
    local future = os.clock() + 3600
    local state = { _nextHit = { [retired] = 0, [temporarilyDetached] = future } }
    service._tick(state)
    assert(state._nextHit[retired] == nil, "expired key retained")
    assert(state._nextHit[temporarilyDetached] == future, "unexpired cooldown changed")
    state._nextHit[temporarilyDetached] = 0
    service._tick(state)
    assert(next(state._nextHit) == nil, "later expiry retained")
    return "PASS: expired keys released, unexpired detached-pet cooldown preserved"
end)
module:Destroy()
retired:Destroy()
temporarilyDetached:Destroy()
assert(ok, result)
return result
