-- Client-only scrolling of authored pool textures. No geometry generation.
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local active = {}
local function bind(instance)
    if
        not instance:IsA("Model")
        or instance:GetAttribute("ConfluenceSurfaceFlow") ~= true
        or active[instance]
    then
        return
    end
    local data = instance:FindFirstChild("SurfaceFlowConfig")
    local folder = instance:FindFirstChild("AnimatedPoolSurfaces")
    if not data or not folder then
        return
    end
    local cfg = game.HttpService:JSONDecode(data.Value)
    local textures = {}
    for _, t in ipairs(folder:GetDescendants()) do
        if t:IsA("Texture") then
            table.insert(
                textures,
                {
                    texture = t,
                    spec = cfg[t:GetAttribute("Side")],
                    u = t:GetAttribute("PhaseU"),
                    v = t:GetAttribute("PhaseV"),
                }
            )
        end
    end
    active[instance] = { cfg = cfg, textures = textures, elapsed = 0 }
end
for _, m in ipairs(workspace:GetDescendants()) do
    bind(m)
end
workspace.DescendantAdded:Connect(function(m)
    if m:IsA("Model") then
        task.defer(bind, m)
    end
end)
RunService.Heartbeat:Connect(function(dt)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local now = workspace:GetServerTimeNow()
    for model, state in pairs(active) do
        if not model.Parent then
            active[model] = nil
        else
            state.elapsed += dt
            if
                root
                and state.elapsed >= 1 / state.cfg.update_hz
                and (model:GetPivot().Position - root.Position).Magnitude < state.cfg.view_radius
            then
                state.elapsed = 0
                for _, item in ipairs(state.textures) do
                    local spec = item.spec
                    item.texture.OffsetStudsU = (item.u + now * spec.speed_u) % spec.tile_studs
                    item.texture.OffsetStudsV = (item.v + now * spec.speed_v) % spec.tile_studs
                end
            end
        end
    end
end)
