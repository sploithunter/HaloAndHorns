--[[
    Command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.Phase5AutoSystemsSmoke).runText()

    Verifies Phase 5 server decisions: target mode selection, persisted choices,
    hatch auto-delete filters, protected-rarity behavior, and profile restore.
]]

local Phase5AutoSystemsSmoke = {}

local function getRemote()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remote = ReplicatedStorage:WaitForChild("StudioSmokeTest", 10)
    assert(remote, "StudioSmokeTest remote not found")
    return remote
end

function Phase5AutoSystemsSmoke.run(options)
    local remote = getRemote()
    local result = remote:InvokeServer("RunPhase5AutoSystemsSmoke", options or {})
    assert(result and result.ok, result and result.error or "Phase5AutoSystemsSmoke failed")
    return result
end

function Phase5AutoSystemsSmoke.runText(options)
    local result = Phase5AutoSystemsSmoke.run(options)
    local data = result.result or {}
    local modes = data.modeResults or {}
    local autoDelete = data.autoDelete or {}
    return string.format(
        "Phase5AutoSystemsSmoke complete: nearest=%s high=%s weak=%s strong=%s currency=%s deleteCommon=%s deleteType=%s deleteVariant=%s protectExclusive=%s restored=%s",
        tostring(modes.nearest or "-"),
        tostring(modes.highest_value or "-"),
        tostring(modes.weakest or "-"),
        tostring(modes.strongest or "-"),
        tostring(modes.selected_currency or "-"),
        tostring(autoDelete.commonBear == true),
        tostring(autoDelete.doggy == true),
        tostring(autoDelete.goldenBunny == true),
        tostring(autoDelete.protectedColorado == false),
        tostring(result.restored == true)
    )
end

return Phase5AutoSystemsSmoke
