-- Authored coin garden and featured egg; wallet collection and hatching keep their shared authorities.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local Garden = {}
Garden.__index = Garden
function Garden.new()
    return setmetatable({}, Garden)
end
function Garden:Init()
    self.cfg = self._modules.ConfigLoader:LoadConfig("crossroads_garden")
    self.pets = self._modules.ConfigLoader:LoadConfig("pets")
    self.places = self._modules.ConfigLoader:LoadConfig("places")
    self.nextSpawn = 0
    self.targets = {}
    self.rng = Random.new()
end
function Garden:_root()
    local node = workspace
    for _, name in ipairs(self.cfg.root_path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end
function Garden:_bind(root)
    local cfg = self.cfg
    local stand, anchor = root:FindFirstChild(cfg.stand_name), root:FindFirstChild(cfg.anchor_name)
    if not stand or not anchor then
        return false
    end
    local def = assert(self.pets.egg_sources[cfg.egg.id], "Missing featured egg offer")
    local model =
        assert(MeshAssembly.build(def.mesh_asset, def.texture_asset, { modelName = "PlacedEgg" }))
    local height = model:GetExtentsSize().Y
    model:ScaleTo(model:GetScale() * cfg.egg.height / height)
    local box, size = model:GetBoundingBox()
    local center = anchor.Position + Vector3.new(0, size.Y / 2, 0)
    model:PivotTo(model:GetPivot() + center - box.Position)
    local old = stand:FindFirstChild("PlacedEgg")
    if old then
        old:Destroy()
    end
    local preview = root:FindFirstChild(cfg.preview_name)
    if preview then
        preview.Parent = ServerStorage -- preserve the authored specimen for this session
    end
    local ui = stand:FindFirstChild("UIanchor") or Instance.new("Part")
    ui.Name = "UIanchor"
    ui.Anchored, ui.CanCollide, ui.CanTouch, ui.CanQuery = true, false, false, false
    ui.Transparency = 1
    ui.Position = center
    ui.Parent = stand
    model.Parent = stand
    model:SetAttribute("EggId", cfg.egg.id)
    CollectionService:AddTag(model, "EggStand")
    stand:SetAttribute("EggId", cfg.egg.id)
    CollectionService:AddTag(stand, "EggStand")
    anchor:SetAttribute("GameplayConnected", true)
    root:SetAttribute("FeaturedEggSource", cfg.egg.source)
    self.bound = root
    return true
end
function Garden:_tick()
    local root = self:_root()
    if not root then
        return
    end
    if self.bound ~= root and not self:_bind(root) then
        return
    end
    local cfg = self.cfg
    local field, floor = root:FindFirstChild(cfg.field_name), root:FindFirstChild(cfg.floor_name)
    if not field or not floor then
        return
    end
    field:SetAttribute("GameplayConnected", true)
    local active = false
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if
            hrp
            and hum
            and hum.Health > 0
            and math.abs(hrp.Position.Y - field.Position.Y) <= cfg.vertical_range
            and (Vector2.new(hrp.Position.X, hrp.Position.Z) - Vector2.new(
                field.Position.X,
                field.Position.Z
            )).Magnitude <= cfg.nearby_radius
            and self._modules.DataService:GetData(player)
        then
            active = true
            break
        end
    end
    for i = #self.targets, 1, -1 do
        local model = self.targets[i]
        if not active or not model.Parent then
            model:Destroy()
            table.remove(self.targets, i)
        end
    end
    if not active or #self.targets >= cfg.max_targets or os.clock() < self.nextSpawn then
        return
    end
    self.nextSpawn = os.clock() + cfg.spawn_seconds
    local point
    for _ = 1, cfg.placement_attempts do
        local candidate = field.CFrame:PointToWorldSpace(
            Vector3.new(
                self.rng:NextNumber(
                    -field.Size.X / 2 + cfg.field_inset,
                    field.Size.X / 2 - cfg.field_inset
                ),
                0,
                self.rng:NextNumber(
                    -field.Size.Z / 2 + cfg.field_inset,
                    field.Size.Z / 2 - cfg.field_inset
                )
            )
        )
        local clear = true
        for _, model in ipairs(self.targets) do
            local p = model:GetPivot().Position
            if
                (Vector2.new(p.X, p.Z) - Vector2.new(candidate.X, candidate.Z)).Magnitude
                < cfg.min_spacing
            then
                clear = false
                break
            end
        end
        if clear then
            point = candidate
            break
        end
    end
    if not point then
        return
    end
    local weight = 0
    for _, target in ipairs(cfg.targets) do
        weight += target.weight
    end
    local roll, selected = self.rng:NextNumber(0, weight), cfg.targets[#cfg.targets]
    for _, target in ipairs(cfg.targets) do
        roll -= target.weight
        if roll <= 0 then
            selected = target
            break
        end
    end
    local floorY = floor.Position.Y + floor.Size.Y / 2
    local model = self._modules.BreakableSpawner:SpawnActivityBreakable(
        cfg.world,
        selected.id,
        Vector3.new(point.X, floorY, point.Z),
        floorY
    )
    if model then
        table.insert(self.targets, model)
    end
end
function Garden:Start()
    if not self.cfg.enabled or PlaceRuntime.isMerge(game.PlaceId, self.places) then
        return
    end
    local elapsed, busy = 0, false
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= self.cfg.poll_seconds and not busy then
            elapsed, busy = 0, true
            local ok, err = pcall(function()
                self:_tick()
            end)
            busy = false
            if not ok then
                self._modules.Logger:Warn(
                    "Crossroads garden unavailable",
                    { error = tostring(err) }
                )
            end
        end
    end)
end
return Garden
