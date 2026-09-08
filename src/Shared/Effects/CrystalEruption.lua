-- Renderer shared by CombatFX and the standalone lab. Cosmetic only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Timeline = require(script.Parent.CrystalTimeline)
local folder = ReplicatedStorage.Configs.vfx
local style = require(folder.crystal_style)
local schema = require(folder.crystal_schema)
local saved = require(folder.crystal_eruption)

local CrystalEruption = {}
local active = {}
local heartbeat

local function color(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function part(parent, className, material)
    local p = Instance.new(className)
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Material = Enum.Material[material]
    p.Transparency = 1
    p.Parent = parent
    return p
end

local function pyramid(wedges, first, frame, width, height, tint, alpha)
    -- A native CornerWedge's high corner is +X/-Z. Rotate four quarters
    -- around their shared apex to form a true four-sided crystal point.
    for corner = 0, 3 do
        local wedge = wedges[first + corner]
        wedge.Size = Vector3.new(width / 2, height, width / 2)
        wedge.CFrame = frame
            * CFrame.Angles(0, corner * math.pi / 2, 0)
            * CFrame.new(-width / 4, height / 2, width / 4)
        wedge.Color = tint
        wedge.Transparency = alpha
    end
end

local function rebuild(self)
    self.model:ClearAllChildren()
    self.crystals, self.ring, self.sparks = {}, {}, {}
    for i = 1, self.preset.count do
        local wedges = {}
        for j = 1, 12 do
            wedges[j] = part(
                self.model,
                "CornerWedgePart",
                j <= 8 and style.material or style.core_material
            )
            wedges[j].Name = "Crystal" .. i .. "Facet" .. j
        end
        self.crystals[i] = wedges
    end
    for i = 1, style.ring_segments do
        self.ring[i] = part(self.model, "Part", style.core_material)
        self.ring[i].Name = "Shockwave"
    end
    for i = 1, self.preset.spark_count do
        self.sparks[i] = part(self.model, "Part", style.core_material)
        self.sparks[i].Name = "Glint"
    end
end

local function render(self)
    if self.stopped then
        return
    end
    if not self.model.Parent then
        self:stop()
        return
    end
    local p, time = self.preset, self.time
    local primary, accent, core = color(p.primary), color(p.accent), color(p.core)
    for i, wedges in ipairs(self.crystals) do
        local radiusFraction = math.sqrt(Timeline.random(p.seed, i, 1))
        -- First shard anchors the composition; others fan outward.
        if i == 1 then
            radiusFraction = 0
        end
        local theta = i * math.pi * (3 - math.sqrt(5))
            + Timeline.random(p.seed, i, 2) * style.angle_jitter
        local growth, fade = Timeline.crystal(p, time, radiusFraction)
        local h = math.max(
            style.minimum_size,
            p.height
                * growth
                * (1 - fade)
                * (
                    style.height_min
                    + Timeline.random(p.seed, i, 3) * style.height_variation
                    + (1 - radiusFraction) * style.center_boost
                )
        )
        local w = p.width
            * (style.width_min + Timeline.random(p.seed, i, 4) * style.width_variation)
        local frame = CFrame.new(
            self.point
                + Vector3.new(
                    math.cos(theta) * p.radius * radiusFraction,
                    style.ground_lift,
                    math.sin(theta) * p.radius * radiusFraction
                )
        ) * CFrame.Angles(0, -theta, math.rad(p.lean) * radiusFraction * -1)
        local alpha = growth == 0 and 1
            or style.surface_transparency + (1 - style.surface_transparency) * fade
        local lower = h * (1 - style.tip_fraction)
        local waist = frame * CFrame.new(0, lower, 0)
        pyramid(wedges, 1, waist, w, h * style.tip_fraction, primary, alpha)
        pyramid(wedges, 5, waist * CFrame.Angles(math.pi, 0, 0), w, lower, primary, alpha)
        pyramid(
            wedges,
            9,
            waist,
            w * style.core_width,
            h * style.tip_fraction * style.core_height,
            core,
            growth == 0 and 1 or fade
        )
    end
    local age = time - p.anticipation
    local charge = math.clamp(time / p.anticipation, 0, 1)
    local radius = age < 0 and p.radius * (style.ring_start + (1 - style.ring_start) * charge)
        or p.radius + age * p.ring_speed
    local opacity = age < 0 and charge or 1 - math.clamp(age / style.ring_lifetime, 0, 1)
    for i, segment in ipairs(self.ring) do
        local theta = (i - 1) / #self.ring * math.pi * 2
        local theta2 = i / #self.ring * math.pi * 2
        local a = self.point
            + Vector3.new(math.cos(theta) * radius, style.ground_lift, math.sin(theta) * radius)
        local b = self.point
            + Vector3.new(math.cos(theta2) * radius, style.ground_lift, math.sin(theta2) * radius)
        segment.Size = Vector3.new(style.ring_thickness, style.ring_thickness, (b - a).Magnitude)
        segment.CFrame = CFrame.lookAt((a + b) / 2, b)
        segment.Color = accent
        segment.Transparency = 1 - opacity * style.ring_opacity
    end
    for i, spark in ipairs(self.sparks) do
        local t = math.clamp(age, 0, style.spark_lifetime)
        local theta = Timeline.random(p.seed, i, 5) * math.pi * 2
        local speed = style.spark_speed * Timeline.random(p.seed, i, 6)
        local offset = Vector3.new(
            math.cos(theta) * speed * t,
            style.spark_speed * t - style.spark_gravity * t * t / 2,
            math.sin(theta) * speed * t
        )
        spark.Size = Vector3.new(style.spark_size, style.spark_size, style.spark_size)
        spark.CFrame = CFrame.new(self.point + offset) * CFrame.Angles(theta + t, theta, t)
        spark.Color = accent
        spark.Transparency = age < 0 and 1 or math.clamp(age / style.spark_lifetime, 0, 1)
    end
end

function CrystalEruption.play(point, preview)
    if typeof(point) ~= "Vector3" then
        return false
    end
    -- Arbitrary preview settings and persistent handles are local Studio tools only.
    local editable = RunService:IsStudio() and type(preview) == "table"
    local preset = editable and preview.preset or saved
    local valid, err = Timeline.validate(preset, schema)
    if not valid then
        return false, err
    end
    if #active >= style.max_active then
        active[1]:stop()
    end
    local model = Instance.new("Model")
    model.Name = "CrystalEruptionFX"
    model.Parent = Workspace
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = { model }
    ray.RespectCanCollide = true
    local hit = Workspace:Raycast(
        point + Vector3.new(0, style.ray_height, 0),
        Vector3.new(0, -style.ray_depth, 0),
        ray
    )
    local self = {
        model = model,
        point = hit and hit.Position or point,
        preset = preset,
        time = 0,
        speed = 1,
        paused = false,
        persistent = editable and preview.persistent == true,
    }
    function self:stop()
        if self.stopped then
            return
        end
        self.stopped = true
        self.model:Destroy()
        local index = table.find(active, self)
        if index then
            table.remove(active, index)
        end
        if #active == 0 and heartbeat then
            heartbeat:Disconnect()
            heartbeat = nil
        end
    end
    function self:seek(time)
        if self.stopped or type(time) ~= "number" or time ~= time then
            return
        end
        self.time = math.clamp(time, 0, Timeline.duration(self.preset))
        render(self)
    end
    function self:update(nextPreset)
        if not editable or self.stopped then
            return false
        end
        local ok, message = Timeline.validate(nextPreset, schema)
        if not ok then
            return false, message
        end
        local topology = self.preset.count ~= nextPreset.count
            or self.preset.spark_count ~= nextPreset.spark_count
        self.preset = nextPreset
        if topology then
            rebuild(self)
        end
        self:seek(self.time)
        return true
    end
    rebuild(self)
    render(self)
    table.insert(active, self)
    if not heartbeat then
        heartbeat = RunService.Heartbeat:Connect(function(dt)
            -- Iterate a copy because lifetime completion removes active handles.
            for _, effect in ipairs(table.clone(active)) do
                if not effect.model.Parent then
                    effect:stop()
                end
                if not effect.paused then
                    effect.time += dt * effect.speed
                end
                if effect.time >= Timeline.duration(effect.preset) and not effect.persistent then
                    effect:stop()
                else
                    effect.time = math.min(effect.time, Timeline.duration(effect.preset))
                    if not effect.paused then
                        render(effect)
                    end
                end
            end
        end)
    end
    return self
end

function CrystalEruption.activeCount()
    return #active
end

return CrystalEruption
