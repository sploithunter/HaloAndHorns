-- Native cached landscape dressing only. Build detached, validate, then replace atomically.
return function(world, cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Local Edit preview only"
    )
    assert(cfg.preview_only and world.Name == cfg.world_root, "Unexpected preview world")
    local landmark =
        assert(world:FindFirstChild(cfg.landmark), "Place the fossil before its setting")
    local landmarkBox = landmark:GetBoundingBox()
    local anchor = Vector3.new(cfg.anchor_xz[1], landmarkBox.Position.Y, cfg.anchor_xz[2])
    assert(
        (landmarkBox.Position - anchor).Magnitude <= cfg.anchor_tolerance,
        "Fossil moved: recompose setting"
    )
    local cache =
        assert(game.ServerStorage:FindFirstChild(cfg.template_cache), "Missing landscape cache")
    for _, item in ipairs(cfg.entries) do
        assert(
            cache:FindFirstChild(item.asset) and cache[item.asset]:IsA("Model"),
            "Missing cached model: " .. item.asset
        )
    end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = { workspace.Terrain }
    ray.IgnoreWater = false
    local function height(x, z)
        local hit = workspace:Raycast(
            Vector3.new(x, cfg.ground.ray_origin_y, z),
            Vector3.new(0, -cfg.ground.ray_depth, 0),
            ray
        )
        assert(hit and hit.Material ~= Enum.Material.Water, "Setting requires dry Terrain")
        assert(
            hit.Position.Y >= cfg.ground.min_y and hit.Position.Y <= cfg.ground.max_y,
            "Unexpected bank elevation"
        )
        return hit.Position.Y
    end
    local function bounds(model)
        local cf, size = model:GetBoundingBox()
        local lo = Vector3.new(math.huge, math.huge, math.huge)
        local hi = -lo
        for _, x in ipairs({ -1, 1 }) do
            for _, y in ipairs({ -1, 1 }) do
                for _, z in ipairs({ -1, 1 }) do
                    local p = cf:PointToWorldSpace(size * Vector3.new(x, y, z) / 2)
                    lo = lo:Min(p)
                    hi = hi:Max(p)
                end
            end
        end
        return lo, hi
    end
    local function overlaps(lo, hi, rect)
        return hi.X > rect[1] and lo.X < rect[2] and hi.Z > rect[3] and lo.Z < rect[4]
    end
    local root = Instance.new("Model")
    root.Name = cfg.root
    root:SetAttribute("CosmeticOnly", true)
    local report = { models = 0, base_parts = 0, samples = {}, terrain_changed = false }
    local ok, failure = pcall(function()
        for _, item in ipairs(cfg.entries) do
            local model = cache[item.asset]:Clone()
            model.Name, model.Parent = item.name, root
            local _, size = model:GetBoundingBox()
            model:ScaleTo(
                model:GetScale()
                    * math.min(item.height / size.Y, item.max_width / math.max(size.X, size.Z))
            )
            for _, child in ipairs(model:GetDescendants()) do
                if child:IsA("BasePart") then
                    child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery =
                        true, false, false, false
                    child.CastShadow = cfg.cast_shadow
                    report.base_parts += 1
                elseif
                    child:IsA("LuaSourceContainer")
                    or child:IsA("ProximityPrompt")
                    or child:IsA("ClickDetector")
                    or child:IsA("ParticleEmitter")
                    or child:IsA("Light")
                    or child:IsA("Sound")
                then
                    child:Destroy()
                end
            end
            local x, z = item.xz[1], item.xz[2]
            model:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(item.yaw), 0))
            local lo, hi = bounds(model)
            model:PivotTo(
                model:GetPivot() + Vector3.new(x - (lo.X + hi.X) / 2, 0, z - (lo.Z + hi.Z) / 2)
            )
            lo, hi = bounds(model)
            if item.max_world_width then
                assert(
                    math.max(hi.X - lo.X, hi.Z - lo.Z) <= item.max_world_width,
                    item.name .. " exceeds rotated canopy width"
                )
            end
            local extent = cfg.bounds_xz
            assert(
                lo.X >= extent[1] and hi.X <= extent[2] and lo.Z >= extent[3] and hi.Z <= extent[4],
                item.name .. " exceeds pocket"
            )
            assert(
                not overlaps(lo, hi, cfg.view_clearance_xz),
                item.name .. " occludes viewing window"
            )
            assert(
                not overlaps(lo, hi, cfg.landmark_clearance_xz),
                item.name .. " intersects fossil envelope"
            )
            local low, high = height(x, z), height(x, z)
            local fraction = item.support_footprint_fraction or cfg.ground.sample_footprint_fraction
            for _, dx in ipairs({ -1, 1 }) do
                for _, dz in ipairs({ -1, 1 }) do
                    local y = height(
                        x + dx * (hi.X - lo.X) * fraction / 2,
                        z + dz * (hi.Z - lo.Z) * fraction / 2
                    )
                    low, high = math.min(low, y), math.max(high, y)
                end
            end
            assert(high - low <= cfg.ground.max_sample_spread, item.name .. " crosses a steep bank")
            model:PivotTo(model:GetPivot() + Vector3.new(0, low - cfg.ground.embed - lo.Y, 0))
            model:SetAttribute("GroundSampleMin", low)
            model:SetAttribute("GroundSampleMax", high)
            model:SetAttribute("SourceAsset", item.asset)
            report.models += 1
            table.insert(report.samples, { name = item.name, ground_min = low, ground_max = high })
        end
        assert(report.base_parts <= cfg.max_base_parts, "Setting exceeds part budget")
    end)
    if not ok then
        root:Destroy()
        error(failure)
    end
    local old = world:FindFirstChild(cfg.root)
    if old then
        old:Destroy()
    end
    root.Parent = world
    return report
end
