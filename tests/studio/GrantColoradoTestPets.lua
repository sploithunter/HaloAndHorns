--[[
    Studio command bar:
    return require(game:GetService("ReplicatedStorage").Tests.studio.GrantColoradoTestPets).runText()
]]

local GrantColoradoTestPets = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAME = "StudioSmokeTest"

local function waitForRemote(timeoutSeconds)
    local deadline = os.clock() + (timeoutSeconds or 20)
    repeat
        local instance = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
        if instance then
            return instance
        end
        task.wait(0.1)
    until os.clock() >= deadline

    error("Timed out waiting for " .. REMOTE_NAME)
end

function GrantColoradoTestPets.run(options)
    options = options or {}
    local remote = waitForRemote(options.timeoutSeconds)
    local result = remote:InvokeServer("GrantColoradoTestPets", {
        equip = options.equip ~= false,
    })

    assert(result and result.ok, result and result.error or "GrantColoradoTestPets failed")
    assert(result.normal and result.normal.petType == "colorado", "Normal Colorado was not granted")
    assert(result.huge and result.huge.huge == true, "Huge Colorado was not granted as huge")
    assert(type(result.huge.serial) == "number", "Huge Colorado did not receive a numeric serial")

    return result
end

function GrantColoradoTestPets.runText(options)
    local result = GrantColoradoTestPets.run(options)
    return string.format(
        "Granted Colorado test pets: normal=%s:%s uid=%s, huge=%s:%s #%s uid=%s serialSource=%s equipped=%s",
        result.normal.petType,
        result.normal.variant,
        result.normal.uid,
        result.huge.petType,
        result.huge.variant,
        tostring(result.huge.serial),
        result.huge.uid,
        tostring(result.huge.serialSource),
        tostring(result.equipped)
    )
end

return GrantColoradoTestPets
