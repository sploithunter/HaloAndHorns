-- Installs an explicitly local Studio interaction rehearsal, with no gameplay authority.
return function(world, cfg, clientSource)
    assert(game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(), "Edit preview only")
    local replicated = game:GetService("ReplicatedStorage")
    local old = replicated:FindFirstChild(cfg.runtime_folder)
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = cfg.runtime_folder
    folder:SetAttribute("PreviewOnly", true)
    folder.Parent = replicated
    local config = Instance.new("StringValue")
    config.Name = "Config"
    config.Value = game:GetService("HttpService"):JSONEncode(cfg)
    config.Parent = folder
    local scripts = game:GetService("StarterPlayer").StarterPlayerScripts
    old = scripts:FindFirstChild(cfg.runtime_folder)
    if old then
        old:Destroy()
    end
    local client = Instance.new("LocalScript")
    client.Name = cfg.runtime_folder
    client.Source = clientSource
    client.Parent = scripts
    local count = 0
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = { workspace.Terrain }
    for _, deck in ipairs(world:GetDescendants()) do
        if deck:IsA("BasePart") and deck:GetAttribute("StationKey") then
            local cast = deck:FindFirstChild("Cast")
            if cast and cast:IsA("Attachment") then
                local target = cast.WorldPosition
                local hit =
                    workspace:Raycast(target + Vector3.new(0, 16, 0), Vector3.new(0, -40, 0), ray)
                assert(
                    hit and hit.Material == Enum.Material.Water,
                    "Cast must reach water: " .. deck.Name
                )
                cast.WorldPosition = hit.Position + Vector3.new(0, cfg.fishing.water_offset, 0)
                deck:SetAttribute("PreviewWaterY", hit.Position.Y)
                count += 1
            end
        end
    end
    return { fishingStations = count, gameplayConnected = false }
end
