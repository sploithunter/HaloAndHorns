-- Edit-only authored markers for the configured arrival pattern and local Farm gate.
return function(areas, spread)
    assert(not game:GetService("RunService"):IsRunning(), "Stop Play")
    local cfg = areas.crossroads
    local root = assert(workspace:FindFirstChild(cfg.root_name), "Crossroads missing")
    local anchor = assert(root:FindFirstChild(cfg.spawn_name, true), "Spawn anchor missing")
    local folder = root:FindFirstChild(cfg.slots_folder)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name, folder.Parent = cfg.slots_folder, root
    end
    local points = spread.candidates(areas.player_spawn_spread)
    for i, point in ipairs(points) do
        local name = cfg.slot_prefix .. i
        local pad = folder:FindFirstChild(name) or Instance.new("SpawnLocation")
        assert(pad:IsA("SpawnLocation"), "Unexpected arrival slot type")
        pad.Name = name
        pad.Anchored, pad.CanCollide, pad.CanTouch, pad.CanQuery = true, false, false, false
        pad.Transparency = 1
        pad.Size = Vector3.new(unpack(cfg.slot_size))
        pad.CFrame = anchor.CFrame * CFrame.new(point.x, 0, point.z)
        pad.Neutral, pad.Enabled, pad.Duration = true, true, 0
        pad:SetAttribute("CrossroadsArrivalSlot", i)
        pad.Parent = folder
    end
    anchor.Enabled = false
    local gate = root
    for _, name in ipairs(cfg.gate_path) do
        gate = assert(gate:FindFirstChild(name), "Gate missing")
    end
    gate.Size = Vector3.new(unpack(cfg.gate_size))
    gate.CanCollide, gate.CanTouch, gate.Transparency = false, true, 1
    local prompt = assert(gate:FindFirstChild(cfg.prompt_name), "Prompt missing")
    prompt.ActionText, prompt.ObjectText = cfg.prompt_action, cfg.prompt_title
    prompt.HoldDuration, prompt.MaxActivationDistance = cfg.prompt_hold, cfg.prompt_distance
    prompt.RequiresLineOfSight, prompt.Enabled = false, true
    gate:SetAttribute("GameplayConnected", true)
    gate:SetAttribute("StubAction", nil)
    gate:SetAttribute("PreviewOnly", false)
    gate:SetAttribute("Destination", cfg.destination_area)
    root:SetAttribute("ArrivalConnected", true)
    root:SetAttribute("FarmGateConnected", true)
    return { slots = #points, gate = gate:GetFullName() }
end
