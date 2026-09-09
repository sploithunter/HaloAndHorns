-- Edit-time alternate upper-tier route. Geometry and source removals are prepared before commit.
return function(world, cfg)
    assert(
        game.PlaceId == 0 and not game:GetService("RunService"):IsRunning(),
        "Ramp requires stopped unpublished preview"
    )
    local function resolve(path)
        local p = world
        for _, name in ipairs(path) do
            p = assert(p:FindFirstChild(name), "Missing " .. name)
        end
        return p
    end
    local stand, rails, flora =
        resolve(cfg.stand_path), resolve(cfg.rail_path), resolve(cfg.flora_path)
    local storage = game:GetService("ServerStorage")
    local archive = storage:FindFirstChild(cfg.backup_name)
    local saved, seats, visitors = {}, 0, 0
    for _, p in ipairs(stand:GetDescendants()) do
        if p:IsA("Seat") then
            seats += 1
            visitors += p.Disabled and 0 or 1
            table.insert(saved, { p = p, cf = p.CFrame, size = p.Size })
        end
    end
    assert(
        seats == cfg.expected_seats and visitors == cfg.expected_visitor_seats,
        "Seat inventory changed"
    )
    local function match(parent, spec, model)
        local found
        for _, p in ipairs(parent:GetChildren()) do
            if
                p.Name == spec.name
                and (model and p:IsA("Model") or not model and p:IsA("BasePart"))
            then
                local pos = model and p:GetPivot().Position or p.Position
                if (pos - Vector3.new(unpack(spec.position))).Magnitude < cfg.tolerance then
                    assert(not found, "Ambiguous source " .. spec.name)
                    found = p
                end
            end
        end
        return found
    end
    local removals, originals = {}, {}
    for _, spec in ipairs(cfg.end_rails) do
        local p = match(rails, spec, false) or archive and match(archive, spec, false)
        assert(
            p and (p.Size - Vector3.new(unpack(spec.size))).Magnitude < cfg.tolerance,
            "Missing original upper end rail"
        )
        table.insert(originals, p)
        if p.Parent == rails then
            table.insert(removals, p)
        end
    end
    for _, spec in ipairs(cfg.archive_flora) do
        local p = match(flora, spec, true) or archive and match(archive, spec, true)
        assert(p, "Missing surveyed interfering flora " .. spec.name)
        if p.Parent == flora then
            table.insert(removals, p)
        end
    end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = { workspace.Terrain }
    for _, q in ipairs(cfg.terrain_samples) do
        local h = workspace:Raycast(
            Vector3.new(q[1], cfg.upper_y + cfg.rail_height, q[2]),
            Vector3.new(0, -cfg.upper_y * 2, 0),
            ray
        )
        assert(h and math.abs(h.Position.Y - cfg.floor_y) < cfg.tolerance, "Ramp ground changed")
    end
    local colors = {}
    for k, rgb in pairs(cfg.palette) do
        colors[k] = Color3.fromRGB(unpack(rgb))
    end
    local out = Instance.new("Model")
    out.Name = cfg.output_name .. "Preparing"
    local count = 0
    local function part(name, size, cf, key, collide)
        local p = Instance.new("Part")
        p.Name, p.Size, p.CFrame = name, size, cf
        p.Color, p.Material = colors[key], Enum.Material[cfg.material[key]]
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, collide ~= false, true, false
        p.TopSurface, p.BottomSurface, p.CastShadow =
            Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth, false
        p.Parent = out
        count += 1
        return p
    end
    local function bar(name, a, b, width, depth, key)
        return part(
            name,
            Vector3.new(width, depth, (b - a).Magnitude),
            CFrame.lookAt((a + b) / 2, b),
            key
        )
    end
    local guardPosts = {}
    local function guard(a, b)
        for _, height in ipairs({ cfg.midrail_height, cfg.rail_height }) do
            bar(
                "GuardRail",
                a + Vector3.yAxis * height,
                b + Vector3.yAxis * height,
                cfg.rail_width,
                cfg.rail_width,
                "metal"
            )
        end
        local n = math.ceil((b - a).Magnitude / cfg.post_spacing)
        for i = 0, n do
            local p = a:Lerp(b, i / n)
            local key = string.format("%.4f/%.4f/%.4f", p.X, p.Y, p.Z)
            if not guardPosts[key] then
                guardPosts[key] = true
                part(
                    "GuardPost",
                    Vector3.new(cfg.post_width, cfg.rail_height, cfg.post_width),
                    CFrame.new(p + Vector3.yAxis * cfg.rail_height / 2),
                    "metal"
                )
            end
        end
    end
    local ok, err = pcall(function()
        for _, f in ipairs(cfg.flights) do
            local a, b = Vector3.new(unpack(f.a)), Vector3.new(unpack(f.b))
            local d = b - a
            assert(
                math.abs(d.Y) / Vector3.new(d.X, 0, d.Z).Magnitude <= 1 / 8 + cfg.tolerance,
                "Ramp exceeds1:8"
            )
            local cf = CFrame.lookAt((a + b) / 2, b)
            part(
                f.name,
                Vector3.new(cfg.width, cfg.slab_depth, d.Magnitude),
                cf * CFrame.new(0, -cfg.slab_depth / 2, 0),
                "stone"
            )
            for _, sign in ipairs({ -1, 1 }) do
                local side = Vector3.xAxis * sign * (cfg.width / 2 + cfg.rail_offset)
                guard(a + side, b + side)
                bar(
                    "SlopingStringer",
                    a + side - Vector3.yAxis * (cfg.slab_depth + cfg.stringer_depth / 2),
                    b + side - Vector3.yAxis * (cfg.slab_depth + cfg.stringer_depth / 2),
                    cfg.support_width,
                    cfg.stringer_depth,
                    "trim"
                )
            end
        end
        for _, l in ipairs(cfg.landings) do
            local c = Vector3.new(unpack(l.center))
            part(
                l.name,
                Vector3.new(l.size[1], cfg.slab_depth, l.size[2]),
                CFrame.new(c - Vector3.yAxis * cfg.slab_depth / 2),
                "stone"
            )
        end
        local turn = cfg.landings[1]
        local x0, x1 = turn.center[1] - turn.size[1] / 2, turn.center[1] + turn.size[1] / 2
        local z0, z1 = turn.center[3] - turn.size[2] / 2, turn.center[3] + turn.size[2] / 2
        guard(
            Vector3.new(x0 - cfg.rail_offset, turn.center[2], z0),
            Vector3.new(x0 - cfg.rail_offset, turn.center[2], z1)
        )
        guard(
            Vector3.new(x1 + cfg.rail_offset, turn.center[2], z0),
            Vector3.new(x1 + cfg.rail_offset, turn.center[2], z1)
        )
        guard(
            Vector3.new(x0 - cfg.rail_offset, turn.center[2], z0 - cfg.rail_offset),
            Vector3.new(x1 + cfg.rail_offset, turn.center[2], z0 - cfg.rail_offset)
        )
        local bridge = cfg.landings[2]
        for _, sign in ipairs({ -1, 1 }) do
            local x = bridge.center[1] + sign * (bridge.size[1] / 2 + cfg.rail_offset)
            guard(
                Vector3.new(x, cfg.upper_y, bridge.center[3] - bridge.size[2] / 2),
                Vector3.new(x, cfg.upper_y, bridge.center[3] + bridge.size[2] / 2)
            )
        end
        -- Grounded columns support the elevated turn, kept north of the public end walk.
        for _, x in ipairs({ x0 + cfg.support_width / 2, x1 - cfg.support_width / 2 }) do
            for _, z in ipairs({ z0 + cfg.support_width / 2, z1 - cfg.support_width / 2 }) do
                local h = turn.center[2] - cfg.slab_depth - cfg.floor_y
                part(
                    "TurnSupport",
                    Vector3.new(cfg.support_width, h, cfg.support_width),
                    CFrame.new(x, cfg.floor_y + h / 2, z),
                    "stone"
                )
            end
        end
        for _, f in ipairs(cfg.flights) do
            local a, b = Vector3.new(unpack(f.a)), Vector3.new(unpack(f.b))
            local mid = (a + b) / 2
            for _, sign in ipairs({ -1, 1 }) do
                local height = mid.Y - cfg.slab_depth - cfg.floor_y
                part(
                    "FlightSupport",
                    Vector3.new(cfg.support_width, height, cfg.support_width),
                    CFrame.new(
                        mid.X + sign * (cfg.width / 2 - cfg.support_width / 2),
                        cfg.floor_y + height / 2,
                        mid.Z
                    ),
                    "stone"
                )
            end
        end
        for _, sign in ipairs({ -1, 1 }) do
            local height = cfg.upper_y - cfg.slab_depth - cfg.floor_y
            part(
                "BridgeAbutment",
                Vector3.new(cfg.support_width, height, cfg.support_width),
                CFrame.new(
                    bridge.center[1] + sign * (cfg.width / 2 - cfg.support_width / 2),
                    cfg.floor_y + height / 2,
                    bridge.center[3] - bridge.size[2] / 2
                ),
                "stone"
            )
        end
        for _, p in ipairs(originals) do
            local lo, hi = p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2
            for _, span in ipairs({ { lo, cfg.opening_x[1] }, { cfg.opening_x[2], hi } }) do
                assert(span[2] > span[1], "Opening exceeds original rail")
                part(
                    "FittedEndRailReturn",
                    Vector3.new(span[2] - span[1], p.Size.Y, p.Size.Z),
                    CFrame.new((span[1] + span[2]) / 2, p.Position.Y, p.Position.Z),
                    "metal"
                )
            end
        end
        for _, p in ipairs(out:GetChildren()) do
            for _, x in ipairs({ -1, 1 }) do
                for _, y in ipairs({ -1, 1 }) do
                    for _, z in ipairs({ -1, 1 }) do
                        local q = p.CFrame:PointToWorldSpace(p.Size * Vector3.new(x, y, z) / 2)
                        assert(q.X < cfg.max_x, "Ramp invades Hell passage")
                    end
                end
            end
        end
        for _, s in ipairs(saved) do
            assert(s.p.CFrame == s.cf and s.p.Size == s.size, "Seat changed during preparation")
        end
    end)
    if not ok then
        out:Destroy()
        error(err)
    end
    if not archive then
        archive = Instance.new("Folder")
        archive.Name = cfg.backup_name
        archive.Parent = storage
    end
    for _, p in ipairs(removals) do
        local pos = p:IsA("Model") and p:GetPivot().Position or p.Position
        local retained =
            match(archive, { name = p.Name, position = { pos.X, pos.Y, pos.Z } }, p:IsA("Model"))
        if retained then
            -- A prior upstream bake recreated an identical source; keep the first backup only.
            p:Destroy()
        else
            p:SetAttribute("ArenaAccessOriginalParent", p.Parent:GetFullName())
            p.Parent = archive
        end
    end
    local old = world:FindFirstChild(cfg.output_name)
    if old then
        old:Destroy()
    end
    out.Name = cfg.output_name
    out:SetAttribute("GameplayConnected", false)
    out:SetAttribute("PreviewOnly", true)
    out:SetAttribute("ArtRevision", cfg.revision)
    out.Parent = world
    return {
        parts = count,
        flights = #cfg.flights,
        seatsPreserved = seats,
        archived = #removals,
        clearWidth = cfg.width,
    }
end
