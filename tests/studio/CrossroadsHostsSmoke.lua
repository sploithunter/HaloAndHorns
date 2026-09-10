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
    -- Use the real demon cue policy with the angel snapshot slot to avoid live arena entry audio.
    client = Client.new()
    snapshot.cfg, snapshot.activity, snapshot.inActivity = config.hosts.demon, "arena", true
    snapshot.gateDistance, snapshot.relevant = 100, true
    client._snapshot = function(_, speaker)
        return speaker == "angel" and snapshot or nil
    end
    attributes.HostFightActive = false
    client:nextRequest(0, true)
    attributes.HostReaction, attributes.HostReactionToken = config.hosts.demon.defeated_cue, 2
    attributes.HostReactionAt = workspace:GetServerTimeNow()
    assert(
        client:nextRequest(1, false).cues[1] == config.hosts.demon.defeated_cue,
        "First defeat missing"
    )
    attributes.HostReactionToken = 3
    assert(client:nextRequest(2, false) == nil, "Repeated defeat taunt")
    snapshot.relevant = false -- Host left for another player's gate; listener stayed in arena.
    client:nextRequest(3, true)
    snapshot.relevant = true
    client:nextRequest(4, true)
    attributes.HostReactionToken = 4
    local resumed = client:nextRequest(5, false)
    assert(
        not resumed or resumed.cues[1] ~= config.hosts.demon.defeated_cue,
        "Host return reset listener visit"
    )
    attributes.HostReaction, attributes.HostReactionToken = config.hosts.demon.victory_cue, 5
    assert(
        client:nextRequest(6, false).cues[1] == config.hosts.demon.victory_cue,
        "Defeat suppression blocked victory"
    )
    snapshot.inActivity, snapshot.relevant = false, false
    client:nextRequest(7, true)
    snapshot.inActivity, snapshot.relevant = true, true
    client:nextRequest(8, true)
    attributes.HostReaction, attributes.HostReactionToken = config.hosts.demon.defeated_cue, 6
    assert(client:nextRequest(9, true) == nil, "Blocked cue consumed")
    assert(
        client:nextRequest(10, false).cues[1] == config.hosts.demon.defeated_cue,
        "New visit did not rearm"
    )
    return { passed = true, checks = 18 }
end
return Smoke
