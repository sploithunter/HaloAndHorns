-- Synthetic snapshots only; never changes a player's ownership, profile, or saved preferences.
local Smoke = {}
function Smoke.run()
    assert(
        game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient(),
        "Studio Client only"
    )
    local Comments = require(
        game:GetService("Players").LocalPlayer.PlayerScripts.Client.Systems.CollectorComments
    )
    local report = { cases = 0 }
    local function new()
        local voice = { calls = 0 }
        function voice:_play(cue)
            self.calls += 1
            self.current = { cue = cue }
            return true
        end
        function voice:cancel()
            self.current = nil
        end
        function voice:destroy()
            self:cancel()
        end
        return Comments.new({ voice = voice }), voice
    end
    for _, side in { "heaven", "hell" } do
        local c, v = new()
        local s = { eligible = true, collector = false, side = side }
        c:receive(s, 0)
        c:step(s, 1)
        assert(
            v.current.cue == "collector_comment." .. (side == "hell" and "demon" or "angel"),
            "Wrong speaker"
        )
        c:receive(s, 2)
        c:step(s, 3)
        assert(v.calls == 1, "Repeated comment")
        s.collector = true
        c:step(s, 4)
        assert(not v.current and not c.pendingUntil, "Purchase did not cancel")
        c:destroy()
        report.cases += 1
    end
    for _, s in
        { { collector = false }, { eligible = false }, { eligible = true, collector = true } }
    do
        local c, v = new()
        c:receive(s, 0)
        c:step(s, 1)
        assert(v.calls == 0 and not c.pendingUntil, "Owner or unknown queued")
        c:destroy()
        report.cases += 1
    end
    local c, v = new()
    local s = { eligible = true, side = "hell", blocked = true }
    c:receive(s, 0)
    c:step(s, 1)
    assert(v.calls == 0, "Blocked comment played")
    s.eligible = false
    c:step(s, 2)
    s.eligible, s.blocked = true, false
    c:step(s, 3)
    assert(v.calls == 0, "Cancelled queued comment resumed")
    c:receive(s, 4)
    c:step(s, 9999)
    assert(v.calls == 0, "Expired comment played")
    c:receive(s, 10000)
    c:step(s, 10001)
    s.side = "heaven"
    c:step(s, 10002)
    assert(v.calls == 1 and not v.current, "Wrong realm speech continued")
    c:destroy()
    report.cases += 1
    return report
end
return Smoke
