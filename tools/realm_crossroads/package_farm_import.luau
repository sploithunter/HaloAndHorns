-- Run in the explicitly selected source Edit place. Returns an unparented portable package.
return function(cfg)
    assert(not game:GetService("RunService"):IsRunning(), "Stop source Play before packaging")
    local package = Instance.new("Folder")
    package.Name = "CrossroadsFarmTransfer"
    workspace[cfg.source_root]:Clone().Parent = package
    local terrain = workspace.Terrain:CopyRegion(
        Region3int16.new(
            Vector3int16.new(unpack(cfg.terrain_min_cell)),
            Vector3int16.new(unpack(cfg.terrain_max_cell))
        )
    )
    terrain.Name, terrain.Parent = "NativeTerrain", package
    for _, spec in ipairs({
        { "ReplicatedStorage", cfg.runtime_folders },
        { "StarterPlayerScripts", cfg.visual_clients },
    }) do
        local folder = Instance.new("Folder")
        folder.Name, folder.Parent = spec[1], package
        local service = spec[1] == "StarterPlayerScripts"
                and game.StarterPlayer.StarterPlayerScripts
            or game:GetService(spec[1])
        for _, name in ipairs(spec[2]) do
            assert(service:FindFirstChild(name), "Missing companion " .. name):Clone().Parent =
                folder
        end
    end
    local archive = Instance.new("Folder")
    archive.Name, archive.Parent = cfg.authoring_archive, package
    for _, object in ipairs(game.ServerStorage:GetChildren()) do
        if object.Archivable and object.Name ~= "CrossroadsTransferBuffer" then
            object:Clone().Parent = archive
        end
    end
    archive:SetAttribute("OriginalCoordinateAuthoringOnly", true)
    return package
end
