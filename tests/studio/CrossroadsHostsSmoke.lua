-- Client-only queue checks; no progress, inventory or audio playback is changed.
local Smoke = {}
function Smoke.run()
    local Players = game:GetService("Players")
    local config = require(game.ReplicatedStorage.Configs.crossroads_hosts)
    local Client = require(Players.LocalPlayer.PlayerScripts.Client.Systems.CrossroadsHostClient)
    local client = Client.new()
    local attributes = { HostRushed = true, HostReactionToken = 0 }
    local face = {
        GetAttribute = function(_, key)
            return attributes[key]
        end,
    }
    local snapshot = {
        face = face,
        cfg = config.hosts.angel,
        activity = "garden",
        relevant = true,
        gateDistance = 100,
        ready = true,
    }
    client._snapshot = function(_, speaker)
        return speaker == "angel" and snapshot or nil
    end
    assert(client:nextRequest(0, true) == nil, "Menu allowed a new line")
    local request = client:nextRequest(1, false)
    assert(request.cues[1] == config.hosts.angel.approach_cue, "Garden approach missing")
    assert(client:nextRequest(2, false) == nil, "Approach repeated")
    attributes.HostWorkingAt = workspace:GetServerTimeNow()
    assert(client:nextRequest(30, false), "Actual work did not enable encouragement")
    snapshot.activity = "egg"
    client:nextRequest(31, true)
    attributes.HostReactionToken = 1
    attributes.HostReaction = config.hosts.angel.hatch_cue
    attributes.HostReactionAt = workspace:GetServerTimeNow()
    attributes.HostReactionUserId = Players.LocalPlayer.UserId
    assert(client:nextRequest(32, true) == nil, "Hatch reveal allowed overlapping speech")
    assert(
        client:nextRequest(33, false).cues[1] == config.hosts.angel.hatch_cue,
        "Hatch reaction was lost while blocked"
    )
    snapshot.activity, snapshot.gateDistance = "gate", 10
    assert(not client:valid(request), "Departed activity stayed valid")
    assert(client:gatePriority(), "Gate did not interrupt activity")
    request = client:nextRequest(34, false)
    assert(request.cues[1] == config.hosts.angel.return_cue, "Rushed return missing")
    assert(request.cues[2] == config.hosts.angel.greeting[2], "Gate advice missing")
    assert(client:nextRequest(35, false) == nil, "Lingering at gate repeated greeting")
    snapshot.relevant, snapshot.gateDistance = false, 100
    client:nextRequest(36, true)
    snapshot.relevant, snapshot.gateDistance = true, 10
    assert(client:nextRequest(37, false), "Returning visitor was not greeted")
    return { passed = true, checks = 12 }
end
return Smoke
