-- Read-only matched old/new presentation lookup test against actual client targets.
-- Six non-blocking samples; no movement, service initialization or profile writes.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsClient(), "Studio Client only")
local player = game.Players.LocalPlayer
local gui = player:FindFirstChildOfClass("PlayerGui")
assert(gui and not gui:FindFirstChild("_FrameTargetProbe"), "probe already installed")
local source = player.PlayerScripts.Client.Systems.PetFollowController.Source
local first = assert(source:find("local function findBreakable(", 1, true))
local last = assert(source:find("function PetFollowController.start()", first, true))
local indexedSource = source:sub(first, last - 1)
local baselineSource, replacements = indexedSource:gsub(
    "return lookup:find%((%w+), id%)",
    function(scope)
        return "for _, desc in ipairs("
            .. scope
            .. [[:GetDescendants()) do
            if desc.Name == "BreakableID" and desc:IsA("NumberValue") and desc.Value == id then
                return desc.Parent
            end
        end
        return nil]]
    end
)
assert(replacements == 2, "production lookup integration changed; review baseline")
local factory = Instance.new("ModuleScript")
factory.Name = "IsolatedFrameTargetFactory"
factory.Source = "return function(Workspace) "
    .. indexedSource
    .. " local indexed = findBreakable\n"
    .. baselineSource
    .. " return indexed, findBreakable end"
factory.Parent = gui
local pure = game.ReplicatedStorage.Shared.Game.FrameTargetLookup:Clone()
pure.Parent = factory
local Lookup = require(pure)
local indexed, baseline = require(factory)(workspace)
local control = Instance.new("BindableFunction")
control.Name = "_FrameTargetProbe"
control.Parent = gui
local result = { running = true, samples = {} }
local connection
local function finish(reason)
    result.running = false
    result.reason = reason
    if connection then
        connection:Disconnect()
    end
    factory:Destroy()
end
control.OnInvoke = function(action)
    if action == "stop" then
        finish("stopped")
    end
    return game:GetService("HttpService"):JSONEncode(result)
end
local elapsed = 0
connection = RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 1 then
        return
    end
    elapsed = 0
    local ok, failure = pcall(function()
        local requests = {}
        for _, folder in ipairs(workspace.PlayerPets:GetChildren()) do
            for _, pet in ipairs(folder:GetChildren()) do
                local id = pet:FindFirstChild("TargetID")
                if
                    pet:IsA("Model")
                    and id
                    and id.Value ~= 0
                    and not pet:GetAttribute("MergePresentationHidden")
                then
                    local kind = pet:FindFirstChild("TargetType")
                    local world = pet:FindFirstChild("TargetWorld")
                    requests[#requests + 1] =
                        { kind and kind.Value, world and world.Value, id.Value }
                end
            end
        end
        local expected, actual = {}, {}
        local row = { requests = #requests, utcUnix = DateTime.now().UnixTimestampMillis / 1000 }
        local function measure(useIndex)
            local lookup = Lookup.new()
            local fn = useIndex and indexed or baseline
            local answers = useIndex and actual or expected
            local started = os.clock()
            for i, request in ipairs(requests) do
                answers[i] = fn(lookup, request[1], request[2], request[3]) or false
            end
            row[useIndex and "indexedSeconds" or "baselineSeconds"] = os.clock() - started
            if useIndex then
                local scopes = 0
                for _ in pairs(lookup.scopes) do
                    scopes += 1
                end
                row.scopes = scopes
            end
        end
        local indexFirst = #result.samples % 2 == 0
        measure(indexFirst)
        measure(not indexFirst)
        for i = 1, #requests do
            assert(actual[i] == expected[i], "presentation target differs at request " .. i)
        end
        row.matched = true
        result.samples[#result.samples + 1] = row
        if #result.samples == 6 then
            finish("completed")
        end
    end)
    if not ok then
        result.error = tostring(failure)
        finish("failed")
    end
end)
return "Started six matched live-target samples; poll PlayerGui._FrameTargetProbe"
