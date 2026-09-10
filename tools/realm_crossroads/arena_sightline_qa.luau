-- Deliberately separate from authoring registry; temporary client Play fixtures only.
return function(world, cfg)
    local run = game:GetService("RunService")
    assert(run:IsRunning() and run:IsClient() and game.PlaceId == 0, "Local isolated Play QA only")
    local old = world:FindFirstChild(cfg.root)
    if old then
        old:Destroy()
    end
    if cfg.action == "remove" then
        return { removed = true }
    end
    assert(cfg.action == "build", "Expected build/remove")
    local stand = world.CrossroadsLeisureR9.ArenaSpectatorStands
    local seat = stand:FindFirstChild(cfg.observer_seat)
    assert(seat and seat:IsA("Seat") and not seat.Disabled, "Expected visitor Seat")
    local eye = seat.Position + Vector3.new(unpack(cfg.eye_offset))
    local root = Instance.new("Model")
    root.Name, root.Parent = cfg.root, world
    root:SetAttribute("TemporaryQA", true)
    local count = 0
    local focus
    for _, target in ipairs(cfg.targets) do
        if target.name == cfg.active_target or cfg.active_target == "all" then
            focus = Vector3.new(target.xz[1], cfg.floor_y + cfg.height / 2, target.xz[2])
            local facing = Vector3.new(eye.X, focus.Y, eye.Z)
            local frame = CFrame.lookAt(focus, facing)
            for row = 1, cfg.rows do
                for col = 1, cfg.columns do
                    local p = Instance.new("Part")
                    p.Name = string.format("%s_R%d_C%d", target.name, row, col)
                    p.Size = Vector3.new(
                        cfg.width / cfg.columns - cfg.gap,
                        cfg.height / cfg.rows - cfg.gap,
                        cfg.depth
                    )
                    p.CFrame = frame
                        * CFrame.new(
                            (col - 0.5) * cfg.width / cfg.columns - cfg.width / 2,
                            (row - 0.5) * cfg.height / cfg.rows - cfg.height / 2,
                            0
                        )
                    p.Color =
                        Color3.fromRGB(unpack(cfg.palette[(row + col - 2) % #cfg.palette + 1]))
                    p.Material = Enum.Material.SmoothPlastic
                    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
                    p.CastShadow = false
                    p.Parent = root
                    count += 1
                end
            end
        end
    end
    assert(focus, "Unknown active target")
    if cfg.active_target == "all" then
        for _, target in ipairs(cfg.targets) do
            if target.name == "Center" then
                focus = Vector3.new(target.xz[1], cfg.floor_y + cfg.height / 2, target.xz[2])
            end
        end
    end
    return {
        target = cfg.active_target,
        cells = count,
        observer = cfg.observer_seat,
        eye = { eye.X, eye.Y, eye.Z },
        focus = { focus.X, focus.Y, focus.Z },
        floorY = cfg.floor_y,
        temporary = true,
    }
end
