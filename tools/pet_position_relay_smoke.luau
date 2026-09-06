-- Execute actual relay method against isolated eight-viewer fixtures; no real remotes/profiles.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local source = game.ServerScriptService.Server.Services.PetFollowService.Source
local first = assert(source:find("function PetFollowService:_onPetPositions(", 1, true))
local last = assert(source:find("function PetFollowService:GetReportedPosition(", first, true))
local cleanup =
    assert(source:match("Players%.PlayerRemoving:Connect%(function%(player%)\n(.-)\n    end%)"))
local fixture = Instance.new("Folder")
fixture.Name = "IsolatedPetRelaySmoke"
fixture.Parent = game.ServerStorage
local policy = game.ReplicatedStorage.Shared.Game.PetPositionRelayBudget:Clone()
policy.Parent = fixture
local factory = Instance.new("ModuleScript")
factory.Source = [[
local PetPositionRelayBudget = require(script.Parent.PetPositionRelayBudget)
return function(Workspace, Players, Signals, clock)
local os = {clock = clock}
local PetFollowService = {}
]] .. source:sub(first, last - 1) .. "\nfunction PetFollowService:_dropRelayPlayer(player)\n" .. cleanup .. "\nend\n" .. [[
return setmetatable({_petPos={}, _relayLastSent={}}, {__index=PetFollowService})
end]]
factory.Parent = fixture
local root = Instance.new("Folder")
root.Parent = fixture
local pets = Instance.new("Folder")
pets.Name = "PlayerPets"
pets.Parent = root
local ownerFolder = Instance.new("Folder")
ownerFolder.Name = "Owner"
ownerFolder.Parent = pets
local viewers, roots, models = {}, {}, {}
for i = 1, 8 do
    local character = Instance.new("Model")
    character.Parent = fixture
    local part = Instance.new("Part")
    part.Name = "HumanoidRootPart"
    part.Anchored = true
    part.Parent = character
    viewers[i] = { Name = i == 1 and "Owner" or "Viewer" .. i, Character = character }
    roots[i] = part
end
for _ = 1, 11 do
    local model = Instance.new("Model")
    model.Parent = ownerFolder
    models[#models + 1] = model
end
local ok, result = pcall(function()
    local now, sends, records, perViewer = 0, 0, 0, {}
    local signals = { PetPositionsRelay = {} }
    function signals.PetPositionsRelay:FireClient(viewer, entries)
        assert(viewer ~= viewers[1], "owner echo")
        sends += 1
        records += #entries
        perViewer[viewer.Name] = (perViewer[viewer.Name] or 0) + 1
        for _, entry in ipairs(entries) do
            assert(entry.extra == nil, "unexpected client fields relayed")
            assert(
                math.abs(entry.cf.Position.X - now) < 0.00001,
                "coarse relay sent an old queued transform"
            )
        end
    end
    local players = {
        GetPlayers = function()
            return viewers
        end,
    }
    local service = require(factory)(root, players, signals, function()
        return now
    end)
    local config = require(game.ReplicatedStorage.Configs.pet_follow)
    service._config = config
    local function run(nearAll, approach)
        service._relayLastSent = {}
        sends, records, perViewer = 0, 0, {}
        for i, part in ipairs(roots) do
            part.Position = Vector3.new((i <= 2 or nearAll) and 0 or 1000, 0, 0)
        end
        for tick = 0, 99 do
            now = tick / 10
            if approach and tick == 50 then
                roots[3].Position = Vector3.zero
            end
            local report = {}
            for _, model in ipairs(models) do
                report[#report + 1] =
                    { pet = model, cf = CFrame.new(now, 0, 0), extra = { unneeded = "data" } }
            end
            service:_onPetPositions(viewers[1], report)
            for _, model in ipairs(models) do
                assert(service._petPos[model].t == now, "observer budget delayed combat positions")
            end
        end
        return { sends = sends, records = records, viewers = table.clone(perViewer) }
    end
    local near = run(true, false)
    assert(near.sends == 700 and near.records == 7700)
    local mixed = run(false, false)
    assert(mixed.sends == 160 and mixed.records == 1760)
    local approach = run(false, true)
    assert(approach.viewers.Viewer3 == 55, "approaching viewer did not immediately resume")
    -- Owner is far away, but this viewer is close to the actual pet fight.
    roots[1].Position = Vector3.new(1000, 0, 0)
    roots[3].Position = Vector3.zero
    service._relayLastSent[viewers[1]][viewers[3]] = now
    local before = perViewer.Viewer3
    service:_onPetPositions(viewers[1], { { pet = models[1], cf = CFrame.new(now, 0, 0) } })
    assert(perViewer.Viewer3 == before + 1, "near-pet helper filtered by owner location")
    service:_dropRelayPlayer(viewers[3])
    assert(service._relayLastSent[viewers[1]][viewers[3]] == nil, "departed viewer retained")
    service:_dropRelayPlayer(viewers[1])
    assert(service._relayLastSent[viewers[1]] == nil, "departed owner retained")
    return { passed = true, near = near, mixed = mixed, approach = approach }
end)
fixture:Destroy()
assert(ok, result)
return game:GetService("HttpService"):JSONEncode(result)
