-- Execute in Studio Edit. Clones only the harness; no live service/profile initialization.
local source = game:GetService("ServerScriptService").Server.MergeStressHarness
local copy = source:Clone()
copy.Parent = game:GetService("ServerStorage")
local ok, result = pcall(function()
    local Harness = require(copy)
    local original = function(_, value)
        return value, nil, "tail"
    end
    local enemy = { _combatTick = original }
    local service = {
        _modules = { MergeEggPrototypeService = { _enemyService = enemy } },
        _config = { studio_stress = { profile_seconds = 20 } },
        _workers = {},
    }
    local harness = Harness.new(service)
    for _, methods in ipairs({ { "_combatTick", "missing" }, { "_combatTick", "_combatTick" } }) do
        local accepted = pcall(function()
            harness:profile({ EnemyService = methods })
        end)
        assert(not accepted and enemy._combatTick == original, "partial or duplicate install")
    end
    local status = harness:profile({ EnemyService = { "_combatTick" } })
    assert(status.running)
    local first, middle, last = enemy:_combatTick(42)
    assert(first == 42 and middle == nil and last == "tail", "return tuple changed")
    local overlapping = pcall(function()
        harness:profile({ EnemyService = { "_combatTick" } })
    end)
    assert(not overlapping, "overlapping capture allowed")
    harness:stop()
    assert(enemy._combatTick == original, "wrapper not restored")
    status = harness:profileStatus()
    assert(not status.running and status.reason == "stress_stopped")
    assert(status.counters["EnemyService._combatTick"].calls == 1)
    harness:profile({ EnemyService = { "_combatTick" } })
    harness:_finishProfile("completed")
    assert(enemy._combatTick == original, "completion did not restore identity")
    return "PASS: validation, tuple preservation, reentrancy, stop/completion cleanup, repeat capture"
end)
copy:Destroy()
assert(ok, result)
return result
