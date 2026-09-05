-- Edit-mode regression: real close/resume methods, isolated players and deterministic streaming.
-- No live profile, character, map, or mission is changed.
local services = game.ServerScriptService.Server.Services
local function method(name, class, member, prelude, ...)
    local source = services[name].Source
    local first = assert(source:find("function " .. class .. ":" .. member .. "(", 1, true))
    local last = source:find("\nfunction " .. class .. ":", first + 1, true) or #source + 1
    return assert(
        loadstring(
            (prelude or "")
                .. "\nlocal "
                .. class
                .. " = {}\n"
                .. source:sub(first, last - 1)
                .. "\nreturn "
                .. class
                .. "."
                .. member
        )
    )(...)
end

local cases = 0
for _, mode in ipairs({ "delayed", "timeout", "error", "no_character" }) do
    for _, occupied in ipairs({ false, true }) do
        local attrs = { InMission = "training" }
        local player = { UserId = 1, Name = "ReturningFixture", Parent = true }
        function player:GetAttribute(key)
            return attrs[key]
        end
        player.Character = mode ~= "no_character"
                and {
                    FindFirstChild = function()
                        return true
                    end,
                }
            or nil
        local location = "training"
        local active, pendingWarp, clock, resumes, attempts = nil, nil, 0, 0, 0
        local otherPlayerBay = { owner = "OtherFixture", eggs = 5 }
        local scheduler = {}
        function scheduler.spawn(fn)
            local thread = coroutine.create(fn)
            assert(coroutine.resume(thread))
            return thread
        end
        function scheduler.wait(dt)
            clock += dt
            assert(attrs.InMission == "training", "Readiness cleared while return still pending")
            assert(active == nil, "Merge resumed before old teleport finished")
            if mode == "delayed" and pendingWarp then
                pendingWarp.ready = true
                assert(coroutine.resume(pendingWarp.thread))
            end
        end
        local merge = { _combatTrainingReturns = { [player] = { bayId = "old" } } }
        merge._resumeAfterCombatTraining = method(
            "MergeEggPrototypeService",
            "MergeEggPrototypeService",
            "_resumeAfterCombatTraining",
            "local task = ...",
            scheduler
        )
        function merge:_recordFor()
            return active
        end
        function merge:_begin(who, bay)
            assert(who == player)
            attempts += 1
            if occupied and bay == "old" then
                return false, "bay_occupied"
            end
            active = { bayId = bay or "free" }
            location = active.bayId
            resumes += 1
            return true
        end
        function merge:_log()
            error("Unexpected Merge failure")
        end
        local record = {
            instanceId = "training",
            teamKey = "fixture",
            returnCFrames = { [player.UserId] = "old" },
        }
        local mission = { _instances = { training = record } }
        mission._close = method(
            "MissionInstanceService",
            "MissionInstanceService",
            "_close",
            "local membersOf, task, os, STREAM_WAIT = ...",
            function()
                return { player }
            end,
            scheduler,
            {
                clock = function()
                    return clock
                end,
            },
            0
        )
        function mission:_releaseEnterGate() end
        function mission:_log() end
        function mission:_cancelStream()
            if pendingWarp then
                local pending = pendingWarp
                pendingWarp = nil
                pending.ready = false
                assert(coroutine.resume(pending.thread))
            end
        end
        function mission:_safeWarp(_, back)
            if mode == "error" then
                error("Injected streaming failure")
            end
            local pending = { thread = coroutine.running(), ready = false }
            pendingWarp = pending
            coroutine.yield()
            if pending.ready then
                location = back
            end
            pendingWarp = nil
            return pending.ready
        end
        function mission:_clearMemberMissionState()
            assert(pendingWarp == nil, "Stale return could overwrite reclaimed bay")
            attrs.InMission = nil
            merge:_resumeAfterCombatTraining(player, "mission_closed")
        end
        assert(mission:_close("training", "abandon"))
        merge:_resumeAfterCombatTraining(player, "duplicate_signal")
        assert(resumes == 1, "Missing or duplicate bay restoration")
        assert(attempts == (occupied and 2 or 1), "Wrong occupied-bay fallback")
        assert(location == (occupied and "free" or "old"), "Player ended in the wrong bay")
        assert(otherPlayerBay.owner == "OtherFixture" and otherPlayerBay.eggs == 5)
        assert(mission._instances.training == nil and attrs.InMission == nil)
        cases += 1
    end
end
return { ok = true, cases = cases }
