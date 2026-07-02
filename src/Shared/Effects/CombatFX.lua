--[[
    CombatFX — client effect FACADE for Halo & Horns.

    One entry point that turns an effect SPEC into the right visual, so powers/pets declare
    intent and don't hand-pick modules:

        CombatFX.play({
            pattern    = "st_attack" | "st_aoe" | "pbaoe" | "attached" | "impact",
            origin     = "ranged" | "upfront",                 -- caster delivery (st_* only)
            category   = "damage" | "heal" | "buff" | "debuff" | "shield",
            element    = "grass" | "lava" | "ice" | "desert",  -- biome origin (its own look)
            crit       = bool,                                  -- st_attack impact tier
            duration   = number,                                -- attached lifetime
            variant    = "targeted" | "pit",                    -- st_aoe shape (pit = lingering pool)
            projectile = "rock" | "frost" | "lightning" | …,    -- st_attack: force a specific bolt
            impact     = "shatter" | "dust" | "big" | "bloom",  -- impact pattern: which point-burst
        }, { caster = Instance, target = Instance, point = Vector3 })

    Routing:
      st_attack -> RangedFX (ranged = element projectile/bolt; upfront = "melee" impact)
      st_aoe    -> AreaFX (variant "targeted" = strike at a point; "pit" = lingering pool)
      pbaoe     -> AreaFX self (burst around the caster)
      attached  -> CombatFX's own follow-an-entity engine below (auras + shield bubble)
      impact    -> RangedFX.playImpact (a bare point-burst from the impact library, no projectile)

    The `attached` pattern is the new capability: a continual effect welded/parented to an
    entity for a duration. Returns a handle { stop() } so callers can end it early.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RangedFX = require(ReplicatedStorage.Shared.Effects.RangedFX)
local AreaFX = require(ReplicatedStorage.Shared.Effects.AreaFX)

local CombatFX = {}

local config = require(ReplicatedStorage.Configs:WaitForChild("combat_fx"))
-- RangedFX/AreaFX read their own existing configs; the facade just passes them through.
local rangedCfg = require(ReplicatedStorage.Configs:WaitForChild("pet_follow")).ranged_bolt
local areaCfg = require(ReplicatedStorage.Configs:WaitForChild("area_fx"))

-- element biome -> ranged projectile kind (damage). Upfront/melee + heal handled separately.
local RANGED_KIND = { grass = "lightning", lava = "fireball", ice = "frost", desert = "rock" }

local function toColor(rgb, fallback)
    if typeof(rgb) == "Color3" then
        return rgb
    end
    if type(rgb) == "table" and rgb[1] then
        return Color3.fromRGB(rgb[1], rgb[2] or 0, rgb[3] or 0)
    end
    return fallback or Color3.fromRGB(255, 255, 255)
end

local function partOf(inst)
    if typeof(inst) ~= "Instance" then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst
    end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

-- Parent for point-anchored ground fields (momentary AoEs that don't follow a pet).
local function fieldFolder()
    local f = Workspace:FindFirstChild("CombatFXFields")
    if not f then
        f = Instance.new("Folder")
        f.Name = "CombatFXFields"
        f.Parent = Workspace
    end
    return f
end

-- ===== Attached pattern: aura (buff/debuff/damage/heal) =====
-- A ParticleEmitter parented to the entity's body part, so it follows the model automatically.
-- rise = float up (buff/heal) or sink (debuff). Runs for `duration`, then stops + GCs.
local function spawnAura(pp, theme, duration)
    local c1 = toColor(theme.colors and theme.colors[1])
    local c2 = toColor(theme.colors and theme.colors[2], c1)
    local rise = theme.rise ~= false
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(c1, c2)
    e.LightEmission = theme.light_emission or 0.4
    e.Lifetime = NumberRange.new(theme.life_min or 0.6, theme.life_max or 1.2)
    e.Rate = theme.rate or 14
    e.Speed = NumberRange.new(theme.speed_min or 2, theme.speed_max or 5)
    e.SpreadAngle = Vector2.new(theme.spread or 18, theme.spread or 18)
    e.Rotation = NumberRange.new(0, 360)
    e.Acceleration = Vector3.new(0, rise and 3 or -3, 0)
    e.EmissionDirection = rise and Enum.NormalId.Top or Enum.NormalId.Bottom
    local sz = theme.size or 0.8
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, sz),
        NumberSequenceKeypoint.new(1, 0),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Parent = pp

    local stopped = false
    local function stop()
        if stopped then
            return
        end
        stopped = true
        e.Enabled = false
        Debris:AddItem(e, (theme.life_max or 1.2) + 0.25) -- let in-flight particles finish
    end
    if duration and duration > 0 then
        task.delay(duration, stop)
    end
    return { stop = stop }
end

-- ===== Attached pattern: shield bubble =====
-- A ForceField sphere sized to the model, WeldConstraint'd to its body so it follows. Pops
-- (expand + fade) on stop / when the duration ends.
local function spawnShield(pp, theme, duration)
    local model = pp.Parent
    local diam = 6
    local okE, sz = pcall(function()
        return model and model:IsA("Model") and model:GetExtentsSize()
    end)
    if okE and sz then
        diam = math.max(sz.X, sz.Y, sz.Z) * 1.25
    end
    local bubble = Instance.new("Part")
    bubble.Shape = Enum.PartType.Ball
    bubble.Material = Enum.Material.ForceField
    bubble.Color = toColor(theme.colors and theme.colors[1])
    bubble.Transparency = theme.transparency or 0.5
    bubble.Anchored = false
    bubble.CanCollide = false
    bubble.CanQuery = false
    bubble.CastShadow = false
    bubble.Massless = true
    bubble.Size = Vector3.new(diam, diam, diam)
    bubble.CFrame = (okE and model:GetPivot()) or pp.CFrame
    bubble.Parent = model
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = pp
    weld.Part1 = bubble
    weld.Parent = bubble

    local full = bubble.Size
    bubble.Size = full * 0.2
    TweenService
        :Create(bubble, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = full,
        })
        :Play()

    local stopped = false
    local function stop()
        if stopped then
            return
        end
        stopped = true
        TweenService
            :Create(bubble, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = full * 1.25,
                Transparency = 1,
            })
            :Play()
        Debris:AddItem(bubble, 0.4)
    end
    if duration and duration > 0 then
        task.delay(duration, stop)
    end
    return { stop = stop }
end

-- ===== Attached pattern: AURA FIELD (ground AoE) =====
-- A persistent, ground-hugging field that FOLLOWS the pet — the bear's "get close and everything
-- burns" aura. Built the layered-VFX way (two ParticleEmitters on a flat invisible holder welded to
-- the pet's base) instead of one tweened Neon dome that read as a plastic blob:
--   (1) leafy motes rising across the whole field area  — the body
--   (2) low flecks hugging the ground                   — the edge / footprint
-- Particles emit from the holder's flat box volume (no Disc-shape orientation fuss). Textures default
-- to the soft built-in particle; drop real leaf art in via the config `texture` knob later.
-- Reusable ground-field engine. opts:
--   follow   = a BasePart to track every frame (the pet's root) — a persistent aura, OR
--   point    = a fixed Vector3 — a momentary AoE anchored at a spot
--   duration = seconds, then auto-stop (0/nil = persistent; caller stops)
--   burst    = one-shot: motes Emit() at once + the rim ring EXPANDS out + the disc flashes, for a
--              mechanically-instant AoE that still reads. The theme (element look) is unchanged.
-- radius sizes EVERYTHING (so the visual always matches the real AoE radius). Returns { stop() }.
local function spawnAuraField(theme, radius, opts)
    opts = opts or {}
    radius = tonumber(radius) or tonumber(theme.radius) or 10
    local follow = opts.follow -- BasePart to track (pet root), or nil
    local point = opts.point -- fixed Vector3 (momentary), or nil
    local duration = opts.duration
    local burst = opts.burst == true
    -- parent the (anchored) parts to the pet model when following — so they GC with it — else to a
    -- dedicated Workspace folder for point-anchored bursts.
    local model = (follow and follow.Parent) or fieldFolder()
    local yoff = 0 -- a fixed point sits at ground level already
    if follow then
        local okE, sz = pcall(function()
            local m = follow.Parent
            return m and m:IsA("Model") and m:GetExtentsSize()
        end)
        if okE and sz then
            -- sit the emission slab just above the pet's feet (lifting ~0.5 keeps motes off the floor)
            yoff = (sz.Y * 0.5) - 0.5
        end
    end
    local function originPos()
        return (follow and follow.Parent and follow.Position) or point or Vector3.new()
    end
    local c1 = toColor(theme.colors and theme.colors[1])
    local c2 = toColor(theme.colors and theme.colors[2], c1)

    -- flat, invisible emission holder. ANCHORED (not welded): pets HOVER, so a welded field floats
    -- above the ground with the pet — instead we raycast to the floor each frame (below) and sit it
    -- on the real ground under the pet.
    local holder = Instance.new("Part")
    holder.Name = "AuraField"
    holder.Shape = Enum.PartType.Cylinder -- cosmetic (invisible); emission is the emitter's Cylinder shape
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanQuery = false
    holder.CastShadow = false
    holder.Transparency = 1
    -- Same recipe as AuraFieldRim: a Cylinder sized (thin X, 2r, 2r), oriented rz=90 below so the
    -- round face lies FLAT — the emitter's Cylinder volume then fills the circle (no square corners).
    holder.Size = Vector3.new(0.3, radius * 2, radius * 2)
    holder.CFrame = CFrame.new(originPos()) * CFrame.Angles(0, 0, math.rad(90))
    holder.Parent = model

    local emitters = {} -- the field-mote emitters (for the burst pop); the rim is handled separately
    local function mkEmitter(o)
        local e = Instance.new("ParticleEmitter")
        -- emit from a CYLINDER volume on the rz=90 flat-cylinder host so particles fill the round
        -- field, not the square box's corners (Jason: "the part actually matters"). The Acceleration
        -- (world up) carries them upward regardless of the rotated EmissionDirection.
        e.Shape = Enum.ParticleEmitterShape.Cylinder
        e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        e.Color = ColorSequence.new(c1, c2)
        e.LightEmission = o.light_emission or theme.light_emission or 0.3
        e.LightInfluence = 0 -- keep the green constant under the area's (lava-red) lighting
        local tex = o.texture or theme.texture
        if tex and tex ~= "" and not tostring(tex):match("^rbxassetid://") then
            tex = "rbxassetid://" .. tex -- config stores bare ids; ParticleEmitter needs the prefix
        end
        e.Texture = tex or ""
        e.Lifetime = NumberRange.new(o.life_min, o.life_max)
        e.Rate = o.rate
        e.Speed = NumberRange.new(o.speed_min, o.speed_max)
        e.SpreadAngle = Vector2.new(o.spread or 25, o.spread or 25)
        -- DIRECTIONAL textures (e.g. up-pointing flames) must NOT tumble — keep them upright. Radially
        -- symmetric motes (leaves, snowflakes, crystals) spin for life. theme.upright = no spin.
        if o.upright or theme.upright then
            e.Rotation = NumberRange.new(0, 0)
            e.RotSpeed = NumberRange.new(0, 0)
        else
            e.Rotation = NumberRange.new(0, 360)
            e.RotSpeed = NumberRange.new(-60, 60)
        end
        e.Acceleration = Vector3.new(0, o.accel_y or 0, 0)
        e.EmissionDirection = Enum.NormalId.Top
        e.Drag = o.drag or 1.5
        -- grow in, shrink out (never pop); fade both ends (research: 80% of the look is these curves)
        e.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.25, o.size),
            NumberSequenceKeypoint.new(1, 0),
        })
        e.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, o.transparency or 0.25),
            NumberSequenceKeypoint.new(0.85, o.transparency or 0.25),
            NumberSequenceKeypoint.new(1, 1),
        })
        e.Parent = holder
        emitters[#emitters + 1] = e
        return e
    end

    -- Density scales with the field's AREA (≈ radius²), not its radius — a wide field needs far more
    -- particles to read. Capped so a huge-radius aura can't blow the particle budget.
    local area = radius * radius
    -- (1) body: leafy motes rising across the whole field
    local rises = mkEmitter({
        rate = math.min(280, area * (theme.rate or 1.0)),
        size = theme.size or 1.4,
        life_min = theme.life_min or 0.8,
        life_max = theme.life_max or 1.6,
        speed_min = theme.speed_min or 1.5,
        speed_max = theme.speed_max or 4,
        accel_y = (theme.rise ~= false) and 2 or -2,
        spread = 22,
        transparency = theme.transparency or 0.15,
    })
    -- (2) edge: low flecks hugging the ground for the footprint
    local g = theme.ground or {}
    local floor = mkEmitter({
        rate = math.min(150, area * (g.rate or 0.5)),
        size = g.size or 0.6,
        life_min = g.life_min or 0.4,
        life_max = g.life_max or 0.9,
        speed_min = g.speed_min or 0.5,
        speed_max = g.speed_max or 2,
        accel_y = -1,
        spread = 60,
        transparency = g.transparency or 0.2,
    })
    -- (2b) accent: a SPARSER second mote (e.g. glowing flower sparkles over the drifting leaves) —
    -- variety so the field doesn't read as one repeated shape. Own texture + glow. Optional.
    local acc = theme.accent
    if type(acc) == "table" and acc.texture and acc.texture ~= "" then
        mkEmitter({
            texture = acc.texture,
            light_emission = acc.light_emission, -- nil => theme default
            rate = math.min(120, area * (acc.rate or 0.3)),
            size = acc.size or 1.0,
            life_min = acc.life_min or 0.7,
            life_max = acc.life_max or 1.4,
            speed_min = acc.speed_min or 1.5,
            speed_max = acc.speed_max or 4,
            accel_y = (theme.rise ~= false) and 2 or -2,
            spread = 22,
            transparency = acc.transparency or 0.15,
        })
    end

    -- (3) ground disc: a flat CIRCLE on the floor (EffectTextureMaker WaterTurbulence / Squiggles),
    -- tinted to the element + slowly spinning. This is the contrast layer — a textured footprint
    -- reads on ANY ground colour (green motes vanish on green grass). A SurfaceGui ImageLabel clipped
    -- to a circle (UICorner 0.5) gives the round footprint; GUI colour also ignores world lighting,
    -- so the green stays constant. Only built when a texture id is set; the grayscale art tints to
    -- the theme colour. NOTE: the texture needs a transparent alpha or its black fill shows.
    local disc, discImg
    local groundTex = theme.ground_texture
    if type(groundTex) == "string" and groundTex ~= "" then
        if not groundTex:match("^rbxassetid://") then
            groundTex = "rbxassetid://" .. groundTex
        end
        disc = Instance.new("Part")
        disc.Name = "AuraFieldDisc"
        disc.Shape = Enum.PartType.Block
        disc.Anchored = true -- positioned on the floor each frame (below), not welded to the pet
        disc.CanCollide = false
        disc.CanQuery = false
        disc.CastShadow = false
        disc.Transparency = 1 -- invisible host; only the SurfaceGui image shows
        disc.Size = Vector3.new(radius * 2, 0.05, radius * 2)
        disc.CFrame = CFrame.new(originPos())
        disc.Parent = model
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 12
        sg.Parent = disc
        discImg = Instance.new("ImageLabel")
        discImg.Size = UDim2.fromScale(1, 1)
        discImg.BackgroundTransparency = 1
        discImg.Image = groundTex
        discImg.ImageColor3 = toColor(theme.ground_color or (theme.colors and theme.colors[1]))
        discImg.ImageTransparency = theme.ground_transparency or 0.35
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0) -- full round => circular footprint
        corner.Parent = discImg
        discImg.Parent = sg
    end

    -- (4) green spirit-FIRE wisps around the rim (Roblox Fire = dynamic flicker no particle can fake).
    -- Each is an invisible part with a tinted Fire; positioned on the floor ring each frame below.
    local fireParts = {}
    local fc = theme.fire
    if type(fc) == "table" then
        for _ = 1, math.floor(fc.count or 6) do
            local p = Instance.new("Part")
            p.Name = "AuraFireWisp"
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CastShadow = false
            p.Transparency = 1
            p.Size = Vector3.new(0.4, 0.4, 0.4)
            p.Parent = model
            local f = Instance.new("Fire")
            f.Color = toColor(fc.color or (theme.colors and theme.colors[1]))
            f.SecondaryColor = toColor(fc.secondary or (theme.colors and theme.colors[2]))
            f.Size = fc.size or 4
            f.Heat = fc.heat or 6
            f.Parent = p
            fireParts[#fireParts + 1] = p
        end
    end

    -- (5) orbiting TRAIL-orbs: glowing motes circling the pet, each leaving a light-ribbon (Trail) —
    -- the only layer with real motion. Positioned in a ring each frame below.
    local orbitOrbs = {}
    local oc = theme.orbit
    if type(oc) == "table" then
        for _ = 1, math.floor(oc.count or 3) do
            local orb = Instance.new("Part")
            orb.Name = "AuraOrbitOrb"
            orb.Shape = Enum.PartType.Ball
            orb.Material = Enum.Material.Neon
            orb.Color = toColor(oc.color or (theme.colors and theme.colors[2]))
            orb.Anchored = true
            orb.CanCollide = false
            orb.CanQuery = false
            orb.CastShadow = false
            orb.Size = Vector3.new(oc.orb_size or 0.6, oc.orb_size or 0.6, oc.orb_size or 0.6)
            orb.Parent = model
            local a0 = Instance.new("Attachment")
            a0.Position = Vector3.new(0, 0.3, 0)
            a0.Parent = orb
            local a1 = Instance.new("Attachment")
            a1.Position = Vector3.new(0, -0.3, 0)
            a1.Parent = orb
            local tr = Instance.new("Trail")
            tr.Attachment0, tr.Attachment1 = a0, a1
            tr.Color = ColorSequence.new(toColor(oc.color or (theme.colors and theme.colors[2])))
            tr.Lifetime = oc.life or 0.6
            tr.LightEmission = 1
            tr.FaceCamera = true
            tr.WidthScale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, oc.width or 1.2),
                NumberSequenceKeypoint.new(1, 0),
            })
            tr.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(1, 1),
            })
            tr.Parent = orb
            orbitOrbs[#orbitOrbs + 1] = orb
        end
    end

    -- (6) RIM feather: a flat ring of sparkles emitted from the disc's edge (Disc emission shape,
    -- Surface + Outward) so the hard circular boundary dissolves instead of cutting. On its own part
    -- oriented disc-flat (front = up), grounded each frame below.
    local rimPart
    local rc = theme.rim
    if type(rc) == "table" then
        rimPart = Instance.new("Part")
        rimPart.Name = "AuraFieldRim"
        rimPart.Shape = Enum.PartType.Cylinder -- invisible host; the ring is the emitter's Disc shape
        rimPart.Anchored = true
        rimPart.CanCollide = false
        rimPart.CanQuery = false
        rimPart.CastShadow = false
        rimPart.Transparency = 1
        -- Jason's live tune: a thin CYLINDER emission shape (not Disc — Disc left a flat-chord edge).
        -- The host is a tall-`thickness` disc sized to the field; oriented vertical (rz=90 below) it
        -- emits a clean dense ring from its curved surface. radius_frac scales the ring to the field.
        local rfrac = tonumber(rc.radius_frac) or 1.0
        rimPart.Size = Vector3.new(rc.thickness or 1, radius * 2 * rfrac, radius * 2 * rfrac)
        rimPart.Parent = model
        local e = Instance.new("ParticleEmitter")
        local okShape, shp = pcall(function()
            return Enum.ParticleEmitterShape[rc.shape or "Cylinder"]
        end)
        e.Shape = (okShape and shp) or Enum.ParticleEmitterShape.Cylinder
        e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface -- emit from the curved surface = a ring
        e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        e.Color = ColorSequence.new(toColor(rc.color or (theme.colors and theme.colors[2])))
        e.LightEmission = 1
        e.LightInfluence = 0
        e.Lifetime = NumberRange.new(rc.life_min or 0.4, rc.life_max or 0.8)
        e.Rate = math.min(12000, tonumber(rc.rate) or 2000)
        e.Speed = NumberRange.new(rc.speed_min or 0.5, rc.speed_max or 2)
        e.SpreadAngle = Vector2.new(rc.spread or 8, rc.spread or 8)
        e.Acceleration = Vector3.new(0, rc.accel_y or 1, 0)
        e.Drag = 2
        local rsz = rc.size or 0.8
        e.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, rsz),
            NumberSequenceKeypoint.new(1, 0),
        })
        e.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, rc.transparency or 0.2),
            NumberSequenceKeypoint.new(0.85, rc.transparency or 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        e.Parent = rimPart
    end

    -- Keep the field ON THE FLOOR under the pet. Pets HOVER, so a welded field floats with them; we
    -- raycast straight down each frame and sit the emission slab + disc on the real ground beneath
    -- the pet (and spin the disc). Excludes the pet, other pets, and enemies so the ray finds terrain.
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true
    do
        local excl = { model }
        local pets = Workspace:FindFirstChild("PlayerPets")
        if pets then
            excl[#excl + 1] = pets
        end
        local gameF = Workspace:FindFirstChild("Game")
        local enemies = gameF and gameF:FindFirstChild("Enemies")
        if enemies then
            excl[#excl + 1] = enemies
        end
        rayParams.FilterDescendantsInstances = excl
    end
    local spin = tonumber(theme.ground_spin) or 0
    local fireAng, orbitAng = 0, 0 -- slow rotation phases for the fire ring + orbit
    local groundConn
    groundConn = RunService.Heartbeat:Connect(function(dt)
        if follow and not follow.Parent then -- the pet went away; stop following
            groundConn:Disconnect()
            return
        end
        local origin = originPos()
        local hit =
            Workspace:Raycast(origin + Vector3.new(0, 4, 0), Vector3.new(0, -120, 0), rayParams)
        local floorY = (hit and hit.Position.Y) or (origin.Y - yoff)
        -- rz=90 keeps the cylinder's round face FLAT (same as the rim) so the emitters fill the circle
        holder.CFrame = CFrame.new(origin.X, floorY + 0.6, origin.Z)
            * CFrame.Angles(0, 0, math.rad(90))
        if disc then
            disc.CFrame = CFrame.new(origin.X, floorY + 0.08, origin.Z) -- disc lies on the floor
            if discImg and spin ~= 0 then
                discImg.Rotation = (discImg.Rotation + spin * dt) % 360
            end
        end
        if #fireParts > 0 then
            fireAng = fireAng + (fc.spin or 0.4) * dt
            local rf = (fc.ring_frac or 0.8) * radius
            for i, p in ipairs(fireParts) do
                local a = fireAng + (i / #fireParts) * math.pi * 2
                p.CFrame = CFrame.new(
                    origin.X + math.cos(a) * rf,
                    floorY + 0.5,
                    origin.Z + math.sin(a) * rf
                )
            end
        end
        if #orbitOrbs > 0 then
            orbitAng = orbitAng + (oc.speed or 1.6) * dt
            local rr = (oc.radius_frac or 0.75) * radius
            local h = oc.height or 1.5
            for i, orb in ipairs(orbitOrbs) do
                local a = orbitAng + (i / #orbitOrbs) * math.pi * 2
                orb.CFrame =
                    CFrame.new(origin.X + math.cos(a) * rr, floorY + h, origin.Z + math.sin(a) * rr)
            end
        end
        if rimPart then -- cylinder vertical (long axis up) — Jason's hunch on the rim edge
            rimPart.CFrame = CFrame.new(origin.X, floorY + 0.3, origin.Z)
                * CFrame.Angles(0, 0, math.rad(90))
        end
    end)

    -- BURST (momentary AoE): one-shot instead of a steady field. The motes pop once, the rim ring
    -- EXPANDS 0->full (a shockwave) while still emitting, and the disc flashes in. Then `duration`
    -- (default 0.6s) stops it. Sized to the same radius, so it reads as an instant hit of that area.
    if burst then
        duration = tonumber(duration) or 0.6
        for _, e in ipairs(emitters) do
            local r = e.Rate
            e.Rate = 0 -- no continuous stream; the Emit() IS the burst
            pcall(function()
                e:Emit(math.max(8, math.floor(r * 0.4)))
            end)
        end
        if rimPart then -- keep emitting while it grows => an expanding ring
            local full = rimPart.Size
            rimPart.Size = Vector3.new(full.X, full.Y * 0.1, full.Z * 0.1)
            TweenService:Create(rimPart, TweenInfo.new(duration * 0.6), { Size = full }):Play()
        end
        if discImg then -- flash the footprint in
            local tgt = theme.ground_transparency or 0.35
            discImg.ImageTransparency = 1
            TweenService:Create(discImg, TweenInfo.new(0.1), { ImageTransparency = tgt }):Play()
        end
        -- DETONATION core: a rapid expanding NEON SPHERE (a swelling fireball that fades) and, when the
        -- theme opts in, a real Roblox Explosion flash. Sized to the field radius so the pop reads as an
        -- instant hit of the whole area. theme.burst = { explosion, sphere_color, sphere_frac,
        -- sphere_time }. Both are point-anchored cosmetics (no physics) parented to the FX folder.
        local bopt = theme.burst or {}
        local center = originPos() + Vector3.new(0, math.max(2, radius * 0.4), 0)
        do -- rapid expanding sphere (the "really quick" expansion Jason wanted)
            local sphere = Instance.new("Part")
            sphere.Shape = Enum.PartType.Ball
            sphere.Material = Enum.Material.Neon
            sphere.Color = toColor(bopt.sphere_color, c1)
            sphere.Transparency = 0.2
            sphere.Anchored = true
            sphere.CanCollide = false
            sphere.CanQuery = false
            sphere.CastShadow = false
            sphere.Massless = true
            sphere.Size = Vector3.new(2, 2, 2)
            sphere.CFrame = CFrame.new(center)
            sphere.Parent = fieldFolder()
            local full = (radius * 2) * (tonumber(bopt.sphere_frac) or 1.1)
            local t = tonumber(bopt.sphere_time) or 0.28
            TweenService:Create(
                sphere,
                TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Size = Vector3.new(full, full, full), Transparency = 1 }
            ):Play()
            -- a colored light PULSE inside the sphere — the "flash" punch, element-tinted (the built-in
            -- Roblox Explosion is orange-only; this gives every element its own colored flash).
            local light = Instance.new("PointLight")
            light.Color = sphere.Color
            light.Brightness = 8
            light.Range = math.clamp(radius * 1.5, 8, 60)
            light.Parent = sphere
            TweenService:Create(light, TweenInfo.new(t), { Brightness = 0 }):Play()
            Debris:AddItem(sphere, t + 0.15)
        end
        if bopt.explosion then -- classic Roblox Explosion flash — visual only (no fling, no joint break)
            local ex = Instance.new("Explosion")
            ex.Position = center
            ex.BlastRadius = math.max(4, radius)
            ex.BlastPressure = 0
            ex.DestroyJointRadiusPercent = 0
            ex.Visible = true
            ex.Parent = Workspace
        end
    end

    local stopped = false
    local function stop()
        if stopped then
            return
        end
        stopped = true
        rises.Enabled = false
        floor.Enabled = false
        if groundConn then
            groundConn:Disconnect()
        end
        if disc then
            if discImg then
                TweenService:Create(discImg, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
            end
            Debris:AddItem(disc, 0.5)
        end
        for _, p in ipairs(fireParts) do
            local f = p:FindFirstChildOfClass("Fire")
            if f then
                TweenService:Create(f, TweenInfo.new(0.35), { Size = 0 }):Play()
            end
            Debris:AddItem(p, 0.6)
        end
        for _, orb in ipairs(orbitOrbs) do
            local tr = orb:FindFirstChildOfClass("Trail")
            if tr then
                tr.Enabled = false
            end
            Debris:AddItem(orb, (oc and oc.life or 0.6) + 0.2)
        end
        if rimPart then
            local e = rimPart:FindFirstChildOfClass("ParticleEmitter")
            if e then
                e.Enabled = false
            end
            Debris:AddItem(rimPart, (rc and rc.life_max or 0.8) + 0.3)
        end
        Debris:AddItem(holder, (theme.life_max or 1.6) + 0.3) -- let in-flight particles finish
    end
    if duration and duration > 0 then
        task.delay(duration, stop)
    end
    return { stop = stop }
end

-- Attach a continual effect to an entity for a duration. Returns { stop() } or nil.
local function materialEnum(name)
    local ok, m = pcall(function()
        return Enum.Material[name]
    end)
    return (ok and m) or Enum.Material.Slate
end

-- Temporarily RESKIN a model (e.g. Stone Skin -> Slate stone): swap every BasePart's Material +
-- Color, strip MeshPart textures + decals, saving originals. Returns a stop() that restores.
-- opts = { material = "Slate", color = {r,g,b}, hide_decals = true }.
-- Note: "rainbow"/"golden" variant pets re-apply their colours each frame, so Color is fought
-- (Material still changes); plain pets stone out fully. Suspending the variant skin is a follow-up.
local function reskinEntity(model, opts)
    opts = opts or {}
    local mat = materialEnum(opts.material or "Slate")
    local color = toColor(opts.color, Color3.fromRGB(120, 114, 105))
    local saved = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            local rec = { inst = d, material = d.Material, color = d.Color }
            d.Material = mat
            d.Color = color
            if d:IsA("MeshPart") and d.TextureID ~= "" then
                rec.texture = d.TextureID
                d.TextureID = ""
            end
            saved[#saved + 1] = rec
        elseif (d:IsA("Decal") or d:IsA("Texture")) and opts.hide_decals ~= false then
            saved[#saved + 1] = { inst = d, transparency = d.Transparency }
            d.Transparency = 1
        end
    end
    local stopped = false
    return function()
        if stopped then
            return
        end
        stopped = true
        for _, rec in ipairs(saved) do
            local d = rec.inst
            if d and d.Parent then
                if rec.material then
                    d.Material = rec.material
                    d.Color = rec.color
                    if rec.texture then
                        d.TextureID = rec.texture
                    end
                else
                    d.Transparency = rec.transparency
                end
            end
        end
    end
end

-- Attach a continual effect to an entity for a duration. Returns { stop() } or nil.
-- spec.reskin (or the theme's reskin) temporarily retextures the whole model (Stone Skin).
function CombatFX.attach(entity, spec)
    spec = spec or {}
    local pp = partOf(entity)
    if not pp then
        return nil
    end
    local cfg = config.attached or {}
    local theme = cfg.themes
        and cfg.themes[spec.element]
        and cfg.themes[spec.element][spec.category]
    local reskinCfg = spec.reskin or (theme and theme.reskin)
    if not theme and not reskinCfg then
        return nil -- nothing to show for this element/category
    end
    local duration = spec.duration or cfg.duration or 5

    local reskinStop = reskinCfg and reskinEntity(pp.Parent, reskinCfg) or nil
    local handle
    if theme then
        if spec.category == "shield" then
            handle = spawnShield(pp, theme, duration)
        elseif spec.category == "aurafield" then
            handle = spawnAuraField(theme, spec.radius, { follow = pp, duration = duration })
        else
            handle = spawnAura(pp, theme, duration)
        end
    end

    if not reskinStop then
        return handle
    end
    if duration and duration > 0 then
        task.delay(duration, reskinStop)
    end
    return {
        stop = function()
            if handle and handle.stop then
                handle.stop()
            end
            reskinStop()
        end,
    }
end

-- Public, reusable ground-AoE field. One entry point for both the persistent pet aura AND momentary
-- targeted AoEs, themed per element and sized to the REAL AoE radius.
--   spec = {
--     element  = "grass" | "lava" | "ice" | "desert",  -- picks themes[element].field (aurafield)
--     radius   = number,                                -- the actual AoE radius (sizes everything)
--     anchor   = <pet/part to FOLLOW>  OR  <Vector3 point to sit at>,
--     duration = seconds (0/nil = persistent; caller stops),
--     burst    = bool (one-shot: pop + expanding ring + disc flash — a mechanically-instant AoE),
--   }
-- Returns { stop() } (or nil if the element has no field theme).
function CombatFX.groundField(spec)
    spec = spec or {}
    local element = spec.element or "grass"
    local cfg = config.attached or {}
    local theme = cfg.themes
        and cfg.themes[element]
        and (cfg.themes[element].field or cfg.themes[element].aurafield)
    if not theme then
        return nil
    end
    local radius = tonumber(spec.radius) or tonumber(theme.radius) or 10
    local opts = { duration = spec.duration, burst = spec.burst }
    local a = spec.anchor
    if typeof(a) == "Vector3" then
        opts.point = a
    elseif a then
        opts.follow = partOf(a)
    end
    return spawnAuraField(theme, radius, opts)
end

-- Element-themed DoT BURN tell: a small rising-flame ParticleEmitter pinned on a burning enemy, from
-- configs/combat_fx.lua attached.burn[element] (colors + alpha texture). Replaces the old hardcoded
-- orange Roblox Fire so a frost burn reads blue, a wither burn green, etc. `host` = the BasePart to
-- pin to; `sizeHint` scales the flame (≈ enemy extent). Falls back to lava. Returns the emitter so
-- the caller manages its lifetime (Destroy when the burn lapses). nil if no host.
function CombatFX.enemyBurn(host, element, sizeHint)
    if not host then
        return nil
    end
    local burnCfg = (config.attached and config.attached.burn) or {}
    local t = burnCfg[element] or burnCfg.lava or {}
    -- small motes; DENSITY (rate) reads as a burn, not a few giant leaves. Lightly size-scaled +
    -- capped low so a big enemy doesn't get absurd motes (halved from the first pass — leaves AND
    -- snowflakes read better small).
    local sz = math.clamp((tonumber(sizeHint) or 5) * 0.16, 0.7, 1.9)
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(
        toColor(t.color, Color3.fromRGB(255, 120, 30)),
        toColor(t.secondary, Color3.fromRGB(255, 210, 120))
    )
    e.LightEmission = 0.8
    e.LightInfluence = 0
    local tex = t.texture
    if tex and tex ~= "" and not tostring(tex):match("^rbxassetid://") then
        tex = "rbxassetid://" .. tex
    end
    e.Texture = tex or ""
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, sz * 0.6),
        NumberSequenceKeypoint.new(0.3, sz),
        NumberSequenceKeypoint.new(1, 0),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Lifetime = NumberRange.new(0.5, 1.1)
    e.Rate = 34 -- MORE small motes (density reads as a burn, not a few giant leaves)
    e.Speed = NumberRange.new(4, 8)
    e.SpreadAngle = Vector2.new(20, 20)
    e.Acceleration = Vector3.new(0, 13, 0) -- launch higher so the burn rises well up the enemy
    e.Rotation = NumberRange.new(0, 0)
    e.RotSpeed = NumberRange.new(0, 0)
    e.EmissionDirection = Enum.NormalId.Top
    e.Parent = host
    return e
end

-- Resolve the RangedFX kind for a single-target attack spec.
local function rangedKind(spec)
    if spec.category == "heal" then
        -- per-biome heal-bolt tint (heal_lava/...) if defined, else the generic green heal bolt
        local k = "heal_" .. tostring(spec.element)
        if rangedCfg.projectile and rangedCfg.projectile[k] then
            return k
        end
        return "heal"
    end
    if spec.origin == "upfront" then
        return "melee" -- biome-distinct via RangedFX melee_by_element (element passed below)
    end
    return RANGED_KIND[spec.element] or "fireball"
end

-- AreaFX shape for an area spec: heal uses the dedicated "heal" nova/splash shapes; everything
-- else uses the biome element's own effect.
local function areaElement(spec)
    if spec.category == "heal" then
        return "heal"
    end
    return spec.element
end

-- Per-biome heal tint (reuses the heal shapes with a biome colour) so heal honours
-- "every origin unique graphics". nil for non-heal (the biome theme is used as-is).
local function healOverride(spec)
    if spec.category ~= "heal" then
        return nil
    end
    local tints = areaCfg.heal_tints
    return (tints and spec.element and tints[spec.element]) or nil
end

-- Play a one-shot or attached effect from a spec. ctx = { caster, target, point }.
function CombatFX.play(spec, ctx)
    spec = type(spec) == "table" and spec or {}
    ctx = type(ctx) == "table" and ctx or {}
    local pattern = spec.pattern

    if pattern == "attached" then
        return CombatFX.attach(ctx.target or ctx.caster, spec)
    end

    local casterPart = ctx.caster and partOf(ctx.caster)
    local targetPart = ctx.target and partOf(ctx.target)

    if pattern == "st_attack" then
        if not (ctx.caster and ctx.target) then
            return false
        end
        -- spec.projectile forces a specific RangedFX kind (boulder/frost_shard/arc/laser) regardless
        -- of element; without it the element picks the default projectile.
        local kind = spec.projectile or rangedKind(spec)
        return RangedFX.Play(
            ctx.caster,
            rangedCfg,
            ctx.target,
            kind,
            spec.crit == true,
            spec.element
        )
    elseif pattern == "impact" then
        -- A bare point-impact from the RangedFX library (shatter/dust/big/bloom/…), no projectile —
        -- coloured by the element's area theme. For hit-flashes decoupled from a travelling bolt.
        local tp = ctx.point
            or (targetPart and targetPart.Position)
            or (casterPart and casterPart.Position)
        if not tp then
            return false
        end
        local theme = areaCfg.themes and areaCfg.themes[areaElement(spec)]
        local c1 = toColor(theme and theme.color, Color3.fromRGB(255, 255, 255))
        local c2 = toColor(theme and theme.color2, c1)
        return RangedFX.playImpact(spec.impact or "small", tp, c1, c2, { crit = spec.crit == true })
    elseif pattern == "st_aoe" then
        local tp = ctx.point
            or (targetPart and targetPart.Position)
            or (casterPart and casterPart.Position)
        if not tp then
            return false
        end
        -- Upfront = slam at the adjacent target: origin == target suppresses AreaFX's ranged
        -- cast beam. Ranged keeps the beam from the caster.
        local cp = (spec.origin == "upfront") and tp or ((casterPart and casterPart.Position) or tp)
        -- spec.variant selects the AreaFX shape: "targeted" (slam/eruption, default) or "pit" (a
        -- lingering bubbling pool — DoT/brand ground hazard).
        return AreaFX.Play(
            areaCfg,
            areaElement(spec),
            spec.variant or "targeted",
            cp,
            tp,
            healOverride(spec)
        )
    elseif pattern == "pbaoe" then
        local cp = (casterPart and casterPart.Position) or ctx.point
        if not cp then
            return false
        end
        -- spec.no_ring strips the encircling ground/radial ring, keeping the on-caster core.
        return AreaFX.Play(areaCfg, areaElement(spec), "self", cp, nil, healOverride(spec), {
            no_ring = spec.no_ring,
        })
    end

    return false
end

return CombatFX
