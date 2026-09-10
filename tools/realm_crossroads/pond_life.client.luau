local RunService = game:GetService("RunService")
local player = game:GetService("Players").LocalPlayer
local runtime = game:GetService("ReplicatedStorage"):WaitForChild(script.Name)
local cfg = game.HttpService:JSONDecode(runtime:WaitForChild("Config").Value)
if cfg.preview_only and (not RunService:IsStudio() or game.PlaceId ~= 0) then
    return
end
local world = workspace:WaitForChild(cfg.world)
local fxRuntime = game.ReplicatedStorage:WaitForChild(cfg.ripple_runtime)
local fxData = game.HttpService:JSONDecode(fxRuntime:WaitForChild("ConfigJSON").Value)
local ripple = require(fxRuntime:WaitForChild("WaterRipple")).create(workspace, fxData.ripple)
local settings = UserSettings():GetService("UserGameSettings")
local root = Instance.new("Folder")
root.Name = cfg.local_root
root:SetAttribute("CosmeticOnly", true)
root.Parent = workspace
local fish, connections = {}, {}
local elapsed, phase, motionTime, stopped = 0, 0, 0, false
for _, pond in ipairs(cfg.ponds) do
    for i, offset in ipairs(cfg.phases) do
        local model = runtime[cfg.template_name]:Clone()
        model.Name = pond.id .. "_" .. i
        table.insert(fish, {
            model = model,
            pond = pond,
            index = i,
            offset = offset,
            tail = model:FindFirstChild(cfg.tail.bone, true),
        })
    end
end
local function cleanup()
    if stopped then
        return
    end
    stopped = true
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    for _, item in ipairs(fish) do
        item.model:Destroy()
    end
    ripple:destroy()
    root:Destroy()
end
local function quality()
    local override = player:GetAttribute(cfg.quality_attribute)
    if cfg.count_by_quality[override] ~= nil then
        return override
    end
    local level = settings.SavedQualityLevel.Value
    if level > 0 then
        for _, tier in ipairs(cfg.graphics_tiers) do
            if level <= tier.maximum then
                return tier.quality
            end
        end
    end
    return cfg.default_quality
end
table.insert(
    connections,
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < cfg.update_interval then
            return
        end
        local reducedMotion = player:GetAttribute(cfg.reduced_motion_attribute) == true
        local override = cfg.preview_only and player:GetAttribute(cfg.preview_time_attribute)
        if type(override) == "number" then
            motionTime = math.max(0, override)
        elseif not reducedMotion then
            motionTime += elapsed
        end
        phase = motionTime * cfg.angular_speed
        local step = elapsed
        elapsed = 0
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local tier = quality()
        local count, visible = cfg.count_by_quality[tier], 0
        ripple:update(step, camera.CFrame.Position, tier, reducedMotion)
        for _, item in ipairs(fish) do
            local pond = item.pond
            local angle = phase + item.offset
            local center =
                Vector3.new(pond.center_xz[1], pond.water_y - cfg.depth, pond.center_xz[2])
            local near = (camera.CFrame.Position - center).Magnitude <= cfg.far_distance
            if item.index <= count and near then
                local lift, liftSpeed = 0, 0
                if not reducedMotion then
                    local delta = math.atan2(
                        math.sin(angle - cfg.breach.center_angle),
                        math.cos(angle - cfg.breach.center_angle)
                    )
                    if math.abs(delta) < cfg.breach.half_width then
                        local u = (delta + cfg.breach.half_width) / (2 * cfg.breach.half_width)
                        lift = cfg.breach.height * math.sin(math.pi * u) ^ 2
                        liftSpeed = cfg.breach.height
                            * math.pi
                            * math.sin(2 * math.pi * u)
                            * cfg.angular_speed
                            / (2 * cfg.breach.half_width)
                    end
                end
                local position = center
                    + Vector3.new(
                        math.sin(angle) * pond.radii[1],
                        math.sin(angle * 2) * cfg.vertical_drift + lift,
                        math.cos(angle) * pond.radii[2]
                    )
                local tangent = Vector3.new(
                    math.cos(angle) * pond.radii[1] * cfg.angular_speed,
                    liftSpeed + 2 * math.cos(angle * 2) * cfg.vertical_drift * cfg.angular_speed,
                    -math.sin(angle) * pond.radii[2] * cfg.angular_speed
                )
                item.model:PivotTo(
                    CFrame.lookAt(position, position + tangent)
                        * CFrame.Angles(0, math.rad(cfg.yaw_correction_degrees), 0)
                )
                if item.tail and item.tail:IsA("Bone") then
                    local bend = math.sin(motionTime * cfg.tail.angular_speed + item.offset)
                        * math.rad(cfg.tail.amplitude_degrees)
                    local axis = cfg.tail.axis
                    item.tail.Transform = CFrame.Angles(
                        axis == "X" and bend or 0,
                        axis == "Y" and bend or 0,
                        axis == "Z" and bend or 0
                    )
                end
                local above = position.Y > pond.water_y
                if not reducedMotion and item.above ~= nil and item.above ~= above then
                    ripple:trigger(
                        Vector3.new(position.X, pond.water_y, position.Z),
                        camera.CFrame.Position,
                        tier,
                        reducedMotion
                    )
                end
                item.above = above
                item.model:SetAttribute("Surfacing", lift > 0)
                item.model.Parent = root
                visible += 1
            else
                item.above = nil
                item.model.Parent = nil
            end
        end
        root:SetAttribute("ActiveRipples", ripple:status().active)
        root:SetAttribute("VisibleFish", visible)
        root:SetAttribute("Quality", tier)
        root:SetAttribute("ReducedMotion", reducedMotion)
        root:SetAttribute("Phase", phase)
    end)
)
table.insert(
    connections,
    world.AncestryChanged:Connect(function(_, parent)
        if not parent then
            cleanup()
        end
    end)
)
table.insert(
    connections,
    runtime.AncestryChanged:Connect(function(_, parent)
        if not parent then
            cleanup()
        end
    end)
)
table.insert(connections, script.Destroying:Connect(cleanup))
