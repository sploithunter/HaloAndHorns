-- Run once in Edit with configs/leaderboards.lua; keeps the removed preview art recoverable.
return function(config)
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play before binding podiums")
    local cfg = config.crossroads_podiums
    local root = workspace
    for _, name in ipairs(cfg.root_path) do
        root = assert(root:FindFirstChild(name), "Missing " .. name)
    end
    local parent = game.ServerStorage:FindFirstChild("CrossroadsAuthoringR11")
    local archive = parent:FindFirstChild("BeforeLivePodiums") or Instance.new("Folder")
    archive.Name = "BeforeLivePodiums"
    archive.Parent = parent
    local audience = cfg.audience
    if audience and audience.enabled then
        local preview = workspace
        for _, name in ipairs(audience.preview_path) do
            preview = preview and preview:FindFirstChild(name)
        end
        if preview then
            preview.Parent = archive
        end
    end
    local dummies = root:FindFirstChild("PodiumHeightDummies")
    if dummies then
        dummies.Parent = archive
    end
    for _, definition in ipairs(cfg.boards) do
        local bay = root[cfg.alcoves_name][definition.alcove]
        local backup = archive:FindFirstChild(bay.Name) or Instance.new("Folder")
        backup.Name = bay.Name
        backup.Parent = archive
        for _, child in ipairs(bay:GetChildren()) do
            -- The header is a separate model; these direct children spell PREVIEW only.
            if child:IsA("UnionOperation") and child.Name:match("^Letter_[PREVIW]$") then
                child.Parent = backup
            end
        end
        bay:SetAttribute("RankingsConnected", true)
        bay.AwardPodiumHook:SetAttribute("PreviewOnly", false)
    end
end
