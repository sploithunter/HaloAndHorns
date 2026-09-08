-- Edit-time surface overlay using masks sampled from the source pool meshes.
return function(model, config, tiles)
    local previous = model:FindFirstChild("AnimatedPoolSurfaces")
    if previous then
        previous:Destroy()
    end
    local root = Instance.new("Folder")
    root.Name = "AnimatedPoolSurfaces"
    root.Parent = model
    model:SetAttribute("ConfluenceSurfaceFlow", true)
    local data = model:FindFirstChild("SurfaceFlowConfig") or Instance.new("StringValue")
    data.Name = "SurfaceFlowConfig"
    data.Value = game.HttpService:JSONEncode(config.surface_flow)
    data.Parent = model
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("MeshPart") and p.Name:find("_Pool_", 1, true) then
            p.Transparency = 1
            p.CastShadow = false
        end
    end
    for _, tile in ipairs(tiles.tiles) do
        local spec = config.surface_flow[tile.side]
        local p = Instance.new("Part")
        p.Name = tile.side .. "_Surface"
        p.Size = Vector3.new(unpack(tile.size))
        p.CFrame = model:GetPivot() * CFrame.new(unpack(tile.position))
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Material = tile.side == "lava" and Enum.Material.Neon or Enum.Material.SmoothPlastic
        p.Color = Color3.fromRGB(unpack(spec.color))
        p.Parent = root
        local texture = Instance.new("Texture")
        texture.Name = "ScrollingFluid"
        texture.Face = Enum.NormalId.Top
        texture.Texture = "rbxassetid://" .. tostring(config.texture_ids[tile.side])
        texture.Transparency = spec.transparency
        texture.StudsPerTileU = spec.tile_studs
        texture.StudsPerTileV = spec.tile_studs
        texture:SetAttribute("Side", tile.side)
        local u = tile.position[1] - tile.size[1] / 2
        local v = tile.position[3] - tile.size[3] / 2
        texture:SetAttribute("PhaseU", u)
        texture:SetAttribute("PhaseV", v)
        texture.OffsetStudsU = u
        texture.OffsetStudsV = v
        texture.Parent = p
    end
    return #root:GetChildren()
end
