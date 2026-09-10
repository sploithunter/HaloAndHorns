return function(world, cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    local placement = cfg.placement
    local template = game.ServerStorage[placement.cache][placement.template]
    local model = template:Clone()
    model.Name = placement.root
    local size = model:GetExtentsSize()
    local limit = Vector3.new(unpack(cfg.max_size_xyz))
    assert(
        size.X <= limit.X + 0.01 and size.Y <= limit.Y + 0.01 and size.Z <= limit.Z + 0.01,
        "Fossil exceeds envelope"
    )
    local base = CFrame.new(unpack(placement.position))
        * CFrame.Angles(0, math.rad(placement.yaw), 0)
    model:PivotTo(base * CFrame.new(0, -placement.embed, 0) * model:GetPivot())
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.Color = Color3.fromRGB(unpack(cfg.mesh_color))
            part.CanCollide, part.CanTouch, part.CanQuery =
                cfg.can_collide, cfg.can_touch, cfg.can_query
        elseif part:IsA("LuaSourceContainer") then
            part:Destroy()
        end
    end
    local old = world:FindFirstChild(placement.root)
    if old then
        old:Destroy()
    end
    model:SetAttribute("CosmeticOnly", cfg.cosmetic_only)
    model:SetAttribute("ModelAssetId", cfg.model_asset_id)
    model.Parent = world
    return { landmark = model.Name, size = tostring(size) }
end
