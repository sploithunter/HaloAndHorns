-- Exercise the actual controller reporting block without starting gameplay,
-- sending remotes, or touching player profiles. Works against Edit source.
assert(game:GetService("RunService"):IsStudio(), "Studio diagnostics only")
local source = game.StarterPlayer.StarterPlayerScripts.Client.Systems.PetFollowController.Source
local first =
    assert(source:find("            -- Throttled: report this player's pet positions", 1, true))
local last = assert(source:find("        end -- driveAnchor", first, true))
local fixture = Instance.new("ModuleScript")
fixture.Name = "IsolatedPetReportSmoke"
fixture.Source = [[
return function(npcCount)
    local reportAccum, reportInterval, calls = 0, 0.1, 0
    local meanderStates, pets, baseCF = {}, {}, {}
    local Signals = { PetReportPositions = { FireServer = function() calls += 1 end } }
    local function driveAnchor(dt, isLocal)
]] .. source:sub(first, last - 1) .. [[
    end
    for _ = 1, 500 do
        driveAnchor(0.02, true)
        for _ = 1, npcCount do driveAnchor(0.02, false) end
    end
    return calls
end
]]
fixture.Parent = game.ServerStorage
local ok, result = pcall(function()
    local run = require(fixture)
    local counts = {}
    for _, npcCount in ipairs({ 0, 9, 19, 79 }) do
        counts[#counts + 1] = { npcSquads = npcCount, reports = run(npcCount), seconds = 10 }
    end
    for _, row in ipairs(counts) do
        assert(row.reports == 100, "NPC squads changed the configured reporting cadence")
    end
    return counts
end)
fixture:Destroy()
assert(ok, result)
return result
