-- Passive bounded Studio diagnostic; no service requires, profile writes, or model changes.
-- Execute separately in Server and Client; poll the local _MergeMemoryProbe BindableFunction.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio diagnostics only")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local root = RunService:IsClient() and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    or game:GetService("ServerStorage")
assert(root, "probe root unavailable")
local prior = root:FindFirstChild("_MergeMemoryProbe")
if prior then
    return prior:Invoke("status")
end
local control = Instance.new("BindableFunction")
control.Name = "_MergeMemoryProbe"
control.Parent = root
local samples, started = {}, os.clock()
local frames, frameSum, frameMax, slowFrames = 0, 0, 0, 0
local elapsed = 0
local connection
local function capture()
    local row = {
        elapsed = os.clock() - started,
        utcUnix = DateTime.now().UnixTimestampMillis / 1000,
        luaGcKb = gcinfo(),
        totalMb = Stats:GetTotalMemoryUsageMb(),
        instanceCount = Stats.InstanceCount,
        frameMeanMs = frames > 0 and 1000 * frameSum / frames or 0,
        frameMaxMs = frameMax * 1000,
        frames = frames,
        framesOver100ms = slowFrames,
        memory = {},
        folders = 0,
        pets = 0,
        downed = 0,
        npcSquads = 0,
        bays = {},
    }
    for _, tag in ipairs(Enum.DeveloperMemoryTag:GetEnumItems()) do
        local ok, amount = pcall(Stats.GetMemoryUsageMbForTag, Stats, tag)
        if ok then
            row.memory[tag.Name] = amount
        end
    end
    local playerPets = workspace:FindFirstChild("PlayerPets")
    for _, folder in ipairs(playerPets and playerPets:GetChildren() or {}) do
        row.folders += 1
        if folder:GetAttribute("NpcSquad") then
            row.npcSquads += 1
        end
        for _, pet in ipairs(folder:GetChildren()) do
            if pet:IsA("Model") then
                row.pets += 1
                if pet:GetAttribute("CombatDowned") then
                    row.downed += 1
                end
            end
        end
    end
    local maps = workspace:FindFirstChild("Maps")
    local realm = maps and maps:FindFirstChild("MergeEggRealm")
    local bays = realm and realm:FindFirstChild("Bays")
    for _, bay in ipairs(bays and bays:GetChildren() or {}) do
        local owner = bay:GetAttribute("MergeEggBayOwnerUserId")
        if owner and owner ~= 0 then
            row.bays[#row.bays + 1] = {
                id = bay:GetAttribute("MergeEggBayId"),
                owner = owner,
                wave = bay:GetAttribute("CurrentWave"),
                state = bay:GetAttribute("PrototypeState"),
                activeEnemies = bay:GetAttribute("ActiveEnemies"),
                replacements = bay:GetAttribute("ReplacementsHatched"),
            }
        end
    end
    frames, frameSum, frameMax, slowFrames = 0, 0, 0, 0
    samples[#samples + 1] = row
    if #samples > 240 then
        table.remove(samples, 1)
    end
    return row
end
capture()
connection = RunService.Heartbeat:Connect(function(dt)
    frames += 1
    frameSum += dt
    frameMax = math.max(frameMax, dt)
    if dt > 0.1 then
        slowFrames += 1
    end
    elapsed += dt
    if elapsed >= 5 then
        elapsed = 0
        capture()
    end
end)
control.OnInvoke = function(action)
    if action == "stop" then
        connection:Disconnect()
    end
    if action == "all" then
        return samples
    end
    return {
        sampleCount = #samples,
        latest = samples[#samples],
        side = RunService:IsClient() and "Client" or "Server",
    }
end
return control:Invoke("status")
