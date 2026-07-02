--[[
    AreaFX — client-side AREA (AoE) effect library for Halo & Horns.

    The companion to RangedFX (single-target bolts). EIGHT distinct effects — two per element,
    each with its own visual motif so no two look alike:

      grass  self = Bloom      (blades sprout up in a ring)      targeted = Thornfield (angled thorns erupt)
      desert self = Sandstorm  (rising swirl of sand)            targeted = Quake      (ground cracks + burst)
      ice    self = Frost nova (radial ice crystals + ring)      targeted = Icefall    (icicles rain + column)
      lava   self = Fire ring  (flame columns circle the caster) targeted = Meteor     (ball drops + shockwave)

    Themed by configs/area_fx.lua (color / color2 / material per element). Targeted variants lead
    with a cast tell (beam from caster + ground telegraph) before the eruption. Purely visual.

      AreaFX.Play(config, element, "self",     originPos)
      AreaFX.Play(config, element, "targeted", originPos, targetPos)
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AreaFX = {}

local OUT = Enum.EasingStyle.Quad
local DIR_OUT = Enum.EasingDirection.Out
local DIR_IN = Enum.EasingDirection.In

local function ti(t, dir)
    return TweenInfo.new(t, OUT, dir or DIR_OUT)
end

local function toColor(rgb, fallback)
    if typeof(rgb) == "Color3" then
        return rgb
    end
    if type(rgb) == "table" and rgb[1] then
        return Color3.fromRGB(rgb[1], rgb[2] or 0, rgb[3] or 0)
    end
    return fallback or Color3.fromRGB(255, 255, 255)
end

local function materialOf(name)
    local ok, mat = pcall(function()
        return Enum.Material[name]
    end)
    return (ok and mat) or Enum.Material.Neon
end

local function fxFolder()
    local f = Workspace:FindFirstChild("Effects")
    if not f then
        f = Instance.new("Folder")
        f.Name = "Effects"
        f.Parent = Workspace
    end
    return f
end

local function newPart(shape, mat, color, transparency)
    local p = Instance.new("Part")
    p.Shape = shape
    p.Material = mat
    p.Color = color
    p.Transparency = transparency or 0
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CastShadow = false
    p.Parent = fxFolder()
    return p
end

local function tween(inst, t, props, dir)
    TweenService:Create(inst, ti(t, dir), props):Play()
    Debris:AddItem(inst, t + 0.15)
end

-- ===== Shared primitives =====

-- Flat disc on the ground that expands + fades (ring / telegraph / shockwave).
local function groundRing(pos, color, mat, diameter, life, startTransparency)
    local ring = newPart(Enum.PartType.Cylinder, mat, color, startTransparency or 0.15)
    ring.Size = Vector3.new(0.3, 1, 1)
    ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    tween(ring, life, { Size = Vector3.new(0.2, diameter, diameter), Transparency = 1 })
end

-- Translucent dome that swells over the point + fades.
local function dome(pos, color, mat, radius, life, startTransparency)
    local d = newPart(Enum.PartType.Ball, mat, color, startTransparency or 0.6)
    d.Size = Vector3.new(1, 1, 1)
    d.CFrame = CFrame.new(pos)
    tween(d, life, { Size = Vector3.new(radius * 2, radius * 2, radius * 2), Transparency = 1 })
end

-- Vertical column that strikes/rises at the point + thins out.
local function column(pos, color, mat, height, life)
    local diam = height * 0.22
    local c = newPart(Enum.PartType.Cylinder, mat, color, 0.1)
    c.Size = Vector3.new(1, diam, diam)
    c.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    tween(c, life, {
        Size = Vector3.new(height, diam * 0.3, diam * 0.3),
        Transparency = 1,
        CFrame = CFrame.new(pos + Vector3.new(0, height * 0.5, 0))
            * CFrame.Angles(0, 0, math.rad(90)),
    })
end

-- Slanted beam between two points (the cast line).
local function beam(a, b, color, mat, thickness, life)
    local dist = (b - a).Magnitude
    if dist < 0.1 then
        return
    end
    local bm = newPart(Enum.PartType.Cylinder, mat, color, 0)
    bm.Size = Vector3.new(dist, thickness, thickness)
    bm.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b) * CFrame.Angles(0, math.rad(90), 0)
    tween(bm, life, { Transparency = 1, Size = Vector3.new(dist, 0.05, 0.05) })
end

-- Low ground debris flung outward (rubble / sparks).
local function debris(pos, c1, c2, mat, count, spread, life)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random() * 0.6
        local dir = Vector3.new(math.cos(ang), 0.3 + math.random() * 0.5, math.sin(ang)).Unit
        local b = newPart(Enum.PartType.Ball, mat, (i % 2 == 0) and c1 or c2, 0)
        local s = spread * 0.12
        b.Size = Vector3.new(s, s, s)
        b.CFrame = CFrame.new(pos)
        tween(b, life, {
            CFrame = CFrame.new(pos + dir * (spread * (0.6 + math.random() * 0.7))),
            Transparency = 1,
            Size = Vector3.new(0.05, 0.05, 0.05),
        })
    end
end

-- ===== Distinct motif primitives =====

-- Elongated spikes pointing outward+up in a ring (ice crystals / thorns).
local function radialSpikes(pos, color, mat, count, radius, len, life, tiltDeg)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random() * 0.2
        local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
        local base = pos + dir * (radius * 0.5) + Vector3.new(0, 0.3, 0)
        local face = CFrame.lookAt(base, base + dir)
            * CFrame.Angles(math.rad(-(tiltDeg or 30)), 0, 0)
        local p = newPart(Enum.PartType.Block, mat, color, 0.1)
        p.Size = Vector3.new(len * 0.18, len * 0.18, 0.4)
        p.CFrame = face
        -- grow along forward (-Z) so it juts outward
        tween(p, life, {
            Size = Vector3.new(len * 0.18, len * 0.18, len),
            CFrame = face * CFrame.new(0, 0, -len * 0.45),
            Transparency = 1,
        })
    end
end

-- Motes that rise in a swirl (sandstorm / embers).
local function swirlMotes(pos, color, mat, count, radius, height, life)
    for i = 1, count do
        local ang0 = (i / count) * math.pi * 2 + math.random() * 0.5
        local r = radius * (0.5 + math.random() * 0.5)
        local start = pos + Vector3.new(math.cos(ang0) * r, 0.5, math.sin(ang0) * r)
        local ang1 = ang0 + 2.2 -- swirl ~125deg as it rises
        local dest = pos
            + Vector3.new(
                math.cos(ang1) * r * 0.7,
                height * (0.6 + math.random() * 0.5),
                math.sin(ang1) * r * 0.7
            )
        local m = newPart(Enum.PartType.Ball, mat, color, 0.2)
        local s = 0.3 + math.random() * 0.4
        m.Size = Vector3.new(s, s, s)
        m.CFrame = CFrame.new(start)
        tween(
            m,
            life,
            { CFrame = CFrame.new(dest), Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) }
        )
    end
end

-- Flat cracks radiating along the ground (quake).
local function groundCracks(pos, color, mat, count, len, life)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random() * 0.3
        local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
        local g = pos + Vector3.new(0, -0.1, 0)
        local face = CFrame.lookAt(g + dir * 0.5, g + dir)
        local p = newPart(Enum.PartType.Block, mat, color, 0)
        p.Size = Vector3.new(0.35, 0.2, 0.4)
        p.CFrame = face
        tween(p, life, {
            Size = Vector3.new(0.35, 0.2, len),
            CFrame = face * CFrame.new(0, 0, -len * 0.45),
            Transparency = 1,
        })
    end
end

-- Bits that fall from above onto the point (icicles / meteor shards). elongated -> tall slivers.
local function fallingBits(pos, color, mat, count, fromHeight, spread, life, elongated)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random()
        local off = Vector3.new(
            math.cos(ang) * spread * math.random(),
            0,
            math.sin(ang) * spread * math.random()
        )
        local p = newPart(Enum.PartType.Block, mat, color, 0.05)
        p.Size = elongated and Vector3.new(0.4, 2.2, 0.4) or Vector3.new(0.6, 0.6, 0.6)
        p.CFrame = CFrame.new(pos + off + Vector3.new(0, fromHeight, 0))
        tween(
            p,
            life,
            { CFrame = CFrame.new(pos + off + Vector3.new(0, 0.3, 0)), Transparency = 1 },
            DIR_IN
        )
    end
end

-- RICOCHET (impact): chunks fly IN, hit the target, bounce up+out, roll/tumble outward, then fade.
-- Pure animation — anchored, non-collidable parts (CanCollide=false), so they never touch anything.
-- Themed by the element (colour + material): earth chunks / sand rubble / ice shards. The phase
-- timings are fixed so the bounce reads physically regardless of `life`.
local function ricochet(pos, c1, c2, mat, count, spread)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.9
        local dir = Vector3.new(math.cos(ang), 0, math.sin(ang)).Unit
        local sz = spread * (0.07 + math.random() * 0.06)
        local chunk = newPart(Enum.PartType.Block, mat, (i % 2 == 0) and c1 or c2, 0.05)
        chunk.Size = Vector3.new(sz, sz * 0.8, sz * 1.1)
        local startPos = pos
            + dir * (spread * 0.2)
            + Vector3.new(0, spread * 0.55 + math.random() * 2, 0)
        local spin0 =
            CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
        chunk.CFrame = CFrame.new(startPos) * spin0
        local tumble = (math.random() < 0.5 and 1 or -1) * (8 + math.random() * 6)

        task.spawn(function()
            -- A) HIT — accelerate down into the contact point next to the target
            local hitPos = pos + dir * (spread * 0.12) + Vector3.new(0, 0.5, 0)
            TweenService:Create(
                chunk,
                TweenInfo.new(0.08, OUT, DIR_IN),
                { CFrame = CFrame.new(hitPos) * spin0 }
            ):Play()
            task.wait(0.08)
            -- B) BOUNCE — kick up and out, decelerating to an apex
            local apex = pos + dir * (spread * 0.5) + Vector3.new(0, spread * 0.3, 0)
            TweenService
                :Create(chunk, TweenInfo.new(0.15, OUT, DIR_OUT), {
                    CFrame = CFrame.new(apex) * spin0 * CFrame.Angles(0, 0, tumble * 0.4),
                })
                :Play()
            task.wait(0.15)
            -- C) ROLL — fall to the ground and tumble further outward
            local rest = pos
                + dir * (spread * (0.95 + math.random() * 0.4))
                + Vector3.new(0, 0.3, 0)
            TweenService
                :Create(chunk, TweenInfo.new(0.45, OUT, DIR_OUT), {
                    CFrame = CFrame.new(rest) * spin0 * CFrame.Angles(0, 0, tumble),
                })
                :Play()
            task.wait(0.42)
            -- D) FADE — shrink + vanish where it settled
            TweenService:Create(chunk, TweenInfo.new(0.28, OUT, DIR_OUT), {
                Transparency = 1,
                Size = Vector3.new(0.05, 0.05, 0.05),
            }):Play()
            task.wait(0.3)
            chunk:Destroy()
        end)
    end
end

-- Variation knobs for the fire ring — so repeated lava casts don't look stamped. One central
-- block of tunables (vs magic numbers per call site); all PURELY VISUAL, no gameplay effect.
local FIRE_RING_VAR = {
    rotation_jitter = true, -- random base rotation each cast (columns land at fresh angles)
    count_jitter = 2, -- ± columns added/removed from the requested count (uneven count)
    angle_jitter = 0.16, -- rad of per-column angular wobble (uneven spacing, not a clean clock)
    radius_wobble = 0.16, -- fraction of radius each column is pushed in/out (circle isn't perfect)
    height_jitter = 0.55, -- studs of per-column vertical offset (columns sit at varied heights)
    size_jitter = 0.35, -- fraction of the fire size varied per column
    heat_jitter = 6, -- ± Fire.Heat varied per column (flames flicker at different intensities)
    spin = true, -- slow orbital drift of the whole ring across its lifetime
    spin_max = 0.55, -- max radians the ring rotates over `life`
}

-- A ring of REAL Roblox Fire (not procedural) around the point — the lava look. Each cast is
-- randomized (base rotation + per-fire jitter + count/radius wobble + a slow orbital drift) so
-- firing it repeatedly never reads as the same stamped ring twice. Variation is tuned in
-- FIRE_RING_VAR above; pass `v = {}`-style overrides via the optional `varOverride` table.
local function fireRing(pos, count, radius, life, color, color2, varOverride)
    local v = FIRE_RING_VAR
    local function knob(name)
        if varOverride and varOverride[name] ~= nil then
            return varOverride[name]
        end
        return v[name]
    end

    -- Random base rotation so the fire columns don't sit at the same angles every cast.
    local baseAng = knob("rotation_jitter") and (math.random() * math.pi * 2) or 0
    -- Slight count variation so the circle isn't perfectly uniform run-to-run.
    local n = count
    local cj = knob("count_jitter") or 0
    if cj > 0 then
        n = math.max(4, count + math.random(-cj, cj))
    end
    -- One shared slow drift for this cast's ring (subtle orbital spin over its life), random sign.
    local spinAmt = 0
    if knob("spin") then
        local sign = (math.random() < 0.5) and 1 or -1
        spinAmt = (knob("spin_max") or 0) * sign * (0.55 + math.random() * 0.45)
    end

    local angJit = knob("angle_jitter") or 0
    local radWob = knob("radius_wobble") or 0
    local hJit = knob("height_jitter") or 0
    local szJit = knob("size_jitter") or 0
    local heatJit = knob("heat_jitter") or 0
    local baseSize = math.max(4, radius * 0.7)

    for i = 1, n do
        local ang = baseAng + (i / n) * math.pi * 2 + (math.random() - 0.5) * 2 * angJit
        local r = radius * (1 + (math.random() - 0.5) * 2 * radWob)
        local yOff = 0.5 + (math.random() - 0.5) * 2 * hJit
        local holder = Instance.new("Part")
        holder.Transparency = 1
        holder.Size = Vector3.new(1, 1, 1)
        holder.Anchored = true
        holder.CanCollide = false
        holder.CanQuery = false
        holder.CastShadow = false
        holder.CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * r, yOff, math.sin(ang) * r))
        holder.Parent = fxFolder()
        local fire = Instance.new("Fire")
        fire.Size = math.max(1, baseSize * (1 + (math.random() - 0.5) * 2 * szJit))
        fire.Heat = 10 + (math.random() - 0.5) * 2 * heatJit
        fire.Color = color
        fire.SecondaryColor = color2
        fire.Parent = holder
        local light = Instance.new("PointLight")
        light.Color = color
        light.Brightness = 3
        light.Range = radius
        light.Parent = holder
        TweenService:Create(fire, ti(life), { Size = 0 }):Play()
        TweenService:Create(light, ti(life), { Brightness = 0 }):Play()
        -- Subtle orbital drift: slide the column a little around the centre over its life so the
        -- ring breathes instead of standing dead-still.
        if spinAmt ~= 0 then
            local ang2 = ang + spinAmt
            local dest = pos + Vector3.new(math.cos(ang2) * r, yOff, math.sin(ang2) * r)
            TweenService:Create(holder, ti(life), { CFrame = CFrame.new(dest) }):Play()
        end
        Debris:AddItem(holder, life + 0.4)
    end
end

-- Variation knobs for the lightning storm — so repeated electric casts don't look stamped. The
-- lightning sibling of FIRE_RING_VAR; one central block of tunables, all PURELY VISUAL.
local LIGHTNING_VAR = {
    count_jitter = 2, -- ± bolts vs the requested count (storm density varies cast-to-cast)
    pos_jitter = 1.0, -- multiplier on the scatter radius of strike points
    seg_jitter = 0.2, -- lateral zigzag per bolt segment, as a fraction of radius (jagged, varied)
    segments_min = 5, -- fewest segments a bolt is broken into (more = more jagged)
    segments_extra = 3, -- up to this many extra segments added at random
    fork_chance = 0.55, -- chance a bolt sprouts a short branch fork off its middle
    stagger = 0.26, -- seconds over which the bolts land (a rolling storm, not one snap)
    bolt_life_min = 0.1, -- how long a single bolt flash lingers before snapping out
    bolt_life_max = 0.2,
    thickness_jitter = 0.4, -- ± per-bolt thickness (some bolts fat, some thin)
    white_core = true, -- draw a bright white core inside each coloured segment (hot lightning)
    white_bolt_chance = 0.3, -- chance a whole bolt flashes white-hot instead of the theme colour
}

local WHITE = Color3.fromRGB(255, 255, 255)

-- One jagged neon segment from `a` to `b` (cylinder long-axis = X, same convention as `beam`),
-- flashing at full brightness then snapping out. Optionally lays a thinner white core on top so
-- the bolt reads hot-cored like real lightning.
local function boltSegment(a, b, color, thickness, life, withCore)
    local d = b - a
    local len = d.Magnitude
    if len < 0.05 then
        return
    end
    local mid = a:Lerp(b, 0.5)
    local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
    local seg = newPart(Enum.PartType.Cylinder, Enum.Material.Neon, color, 0)
    seg.Size = Vector3.new(len, thickness, thickness)
    seg.CFrame = cf
    tween(seg, life, { Transparency = 1 })
    if withCore then
        local core = newPart(Enum.PartType.Cylinder, Enum.Material.Neon, WHITE, 0)
        core.Size = Vector3.new(len, thickness * 0.4, thickness * 0.4)
        core.CFrame = cf
        tween(core, life, { Transparency = 1 })
    end
end

-- A cluster of jagged lightning bolts crashing down within `radius` of `pos` — the reusable
-- electric AoE motif (storm strike). Randomized every cast: bolt count, strike points, per-segment
-- zigzag, fork branches, white-hot flashes, per-bolt thickness, and STAGGERED timing so the storm
-- rolls in rather than stamping all at once. The first bolt always lands near the centre as a
-- focal strike (+ a ground-flash disc and a light pulse under each impact). Pure tween/Debris (no
-- Heartbeat loop), matching the rest of AreaFX. Tuned via LIGHTNING_VAR; pass `varOverride` to tweak.
local function lightningStrikes(pos, count, radius, life, color, color2, varOverride)
    local v = LIGHTNING_VAR
    local function knob(name)
        if varOverride and varOverride[name] ~= nil then
            return varOverride[name]
        end
        return v[name]
    end

    local n = count
    local cj = knob("count_jitter") or 0
    if cj > 0 then
        n = math.max(1, count + math.random(-cj, cj))
    end
    local height = radius * 1.8
    local segMin = math.max(2, math.floor(knob("segments_min") or 5))
    local segExtra = math.max(0, math.floor(knob("segments_extra") or 0))
    local forkChance = knob("fork_chance") or 0
    local withCore = knob("white_core")
    local whiteChance = knob("white_bolt_chance") or 0
    local thJit = knob("thickness_jitter") or 0
    local zig = radius * (knob("seg_jitter") or 0)
    local posJit = knob("pos_jitter") or 1

    for i = 1, n do
        -- Strike point: bolt #1 lands near the centre (focal strike); the rest scatter across the
        -- disc (sqrt keeps them from clumping at the middle), so the storm fills the radius.
        local rr
        if i == 1 then
            rr = radius * 0.12
        else
            rr = radius * math.sqrt(math.random()) * posJit
        end
        local ang = math.random() * math.pi * 2
        local ground = pos + Vector3.new(math.cos(ang) * rr, 0.4, math.sin(ang) * rr)
        local top = ground
            + Vector3.new(
                (math.random() - 0.5) * radius * 0.4,
                height,
                (math.random() - 0.5) * radius * 0.4
            )
        local white = math.random() < whiteChance
        local col = white and WHITE or ((i % 2 == 0) and color2 or color)
        local focal = (i == 1)
        local thickness = radius
            * (focal and 0.085 or 0.06)
            * (1 + (math.random() - 0.5) * 2 * thJit)
        local boltLife = (knob("bolt_life_min") or 0.1)
            + math.random() * ((knob("bolt_life_max") or 0.2) - (knob("bolt_life_min") or 0.1))
        local delay = math.random() * (knob("stagger") or 0)

        task.delay(delay, function()
            local segs = segMin + math.random(0, segExtra)
            local prev = top
            local forkAt = math.random(2, math.max(2, segs - 1))
            for s = 1, segs do
                local alpha = s / segs
                local base = top:Lerp(ground, alpha)
                -- zigzag tapers to nothing at the impact so the last segment hits the point clean
                local off = (s < segs)
                        and Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2) * zig * (1 - alpha)
                    or Vector3.zero
                local pt = base + off
                boltSegment(prev, pt, col, thickness, boltLife, withCore)
                -- a short branch fork veering off the middle of the bolt
                if s == forkAt and math.random() < forkChance then
                    local fdir = Vector3.new(
                        (math.random() - 0.5) * 2,
                        -0.5 - math.random() * 0.6,
                        (math.random() - 0.5) * 2
                    ).Unit
                    local fork = pt + fdir * (radius * (0.25 + math.random() * 0.35))
                    boltSegment(pt, fork, col, thickness * 0.6, boltLife, withCore)
                end
                prev = pt
            end
            -- impact: a quick ground-flash disc + a light pulse where the bolt lands
            groundRing(ground, col, Enum.Material.Neon, radius * (focal and 0.9 or 0.5), 0.22, 0.15)
            local flash = newPart(Enum.PartType.Ball, Enum.Material.Neon, col, 0.35)
            local fs = focal and 2.4 or 1.4
            flash.Size = Vector3.new(fs, fs, fs)
            flash.CFrame = CFrame.new(ground + Vector3.new(0, 0.4, 0))
            local lt = Instance.new("PointLight")
            lt.Color = col
            lt.Brightness = focal and 8 or 5
            lt.Range = radius * (focal and 1.4 or 0.9)
            lt.Parent = flash
            tween(flash, boltLife + 0.05, {
                Transparency = 1,
                Size = Vector3.new(0.2, 0.2, 0.2),
            })
            TweenService:Create(lt, ti(boltLife + 0.05), { Brightness = 0 }):Play()
        end)
    end
end

-- One-shot ParticleEmitter burst (embers / sparks / smoke) via :Emit() — the proper Roblox way
-- vs tweening dozens of parts. opts: color1/color2, count, speed_min/max, life_min/max, size,
-- spread, accel_y, light_emission. Default (blank) texture = the soft round particle.
local function particleBurst(pos, opts)
    opts = opts or {}
    local holder = Instance.new("Part")
    holder.Transparency = 1
    holder.Size = Vector3.new(0.2, 0.2, 0.2)
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanQuery = false
    holder.CastShadow = false
    holder.CFrame = CFrame.new(pos)
    holder.Parent = fxFolder()
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(toColor(opts.color1), toColor(opts.color2, toColor(opts.color1)))
    e.LightEmission = opts.light_emission or 0.5
    e.Lifetime = NumberRange.new(opts.life_min or 0.4, opts.life_max or 0.9)
    e.Speed = NumberRange.new(opts.speed_min or 6, opts.speed_max or 14)
    e.SpreadAngle = Vector2.new(opts.spread or 180, opts.spread or 180)
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-120, 120)
    e.Acceleration = Vector3.new(0, opts.accel_y or -10, 0)
    e.Drag = opts.drag or 4
    local sz = opts.size or 1.2
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, sz),
        NumberSequenceKeypoint.new(1, 0),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Enabled = false
    e.Parent = holder
    e:Emit(opts.count or 24)
    Debris:AddItem(holder, (opts.life_max or 0.9) + 0.5)
end

-- Molten tar pit (lingering ground hazard): a dark pool disc + a continuous ParticleEmitter of
-- rising, glowing bubbles. Stays for `life` seconds, then stops emitting + fades out.
local function tarPit(pos, c1, c2, radius, life)
    local pool =
        newPart(Enum.PartType.Cylinder, Enum.Material.Glass, Color3.fromRGB(28, 20, 16), 0.15)
    pool.Reflectance = 0.05
    pool.Size = Vector3.new(0.3, 1, 1)
    pool.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
    TweenService:Create(pool, ti(0.5), { Size = Vector3.new(0.4, radius * 2, radius * 2) }):Play()
    local light = Instance.new("PointLight")
    light.Color = c1
    light.Brightness = 1.5
    light.Range = radius * 1.5
    light.Parent = pool

    -- Bubble emitter on a flat invisible holder so Top emits straight up.
    local holder = newPart(Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.new(), 1)
    holder.Size = Vector3.new(radius * 1.6, 0.2, radius * 1.6)
    holder.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0))
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 28, 20)),
        ColorSequenceKeypoint.new(0.6, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    e.LightEmission = 0.5
    e.Lifetime = NumberRange.new(1.0, 1.9)
    e.Rate = math.max(6, radius * 2)
    e.Speed = NumberRange.new(1, 3)
    e.SpreadAngle = Vector2.new(18, 18)
    e.Acceleration = Vector3.new(0, 1.5, 0)
    e.EmissionDirection = Enum.NormalId.Top
    e.Rotation = NumberRange.new(0, 360)
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, radius * 0.22),
        NumberSequenceKeypoint.new(1, 0),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.85, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Parent = holder

    task.delay(life, function()
        e.Enabled = false
        TweenService:Create(pool, ti(0.7), { Transparency = 1 }):Play()
        TweenService:Create(light, ti(0.7), { Brightness = 0 }):Play()
        Debris:AddItem(pool, 2.5)
        Debris:AddItem(holder, 2.5)
    end)
end

-- SCATTER (cast tell): chunks fly OUTWARD from the caster + a faint dome. One shape, skinned by the
-- element theme (colour + material) → lava embers / ice shards / sand grains / grass chunks. The
-- "stuff flying away from the player" cast — reusable across every origin by colour/material alone.
local function scatterEffect(pos, c1, c2, mat, radius, life)
    debris(pos, c1, c2, mat, 18, radius, life)
    dome(pos, c1, mat, radius * 0.35, life, 0.82)
end

-- RUBBLE (impact): chunks hit the target, bounce, roll away, fade (ricochet). Skinned by element.
local function rubbleEffect(pos, c1, c2, mat, radius)
    ricochet(pos, c1, c2, mat, 11, radius)
end

-- Variation knobs for the organic grass bloom — scattered clumps of blades, randomized every call
-- so the bear's AURA (which re-fires this each tick) never looks like the same stamped ring twice.
-- PURELY VISUAL.
local GRASS_BLOOM_VAR = {
    tufts = 11, -- clumps of blades scattered across the disc
    tuft_jitter = 4, -- ± clumps per call (uneven density run-to-run)
    blades_min = 2, -- blades per clump
    blades_max = 4,
    blade_height = 0.3, -- blade length as a fraction of radius
    height_jitter = 0.5, -- ± fraction of that per blade (uneven, not mown)
    lean_deg = 30, -- max random lean from vertical (blades flop, not soldier-straight)
    clump_spread = 0.1, -- blade scatter within a clump, as a fraction of radius
    mote_frac = 1.0, -- leafy motes ≈ radius * this
}

-- Organic grass bloom: clumps of thin green blades sprout at random points across the disc — each
-- blade a fresh height / shade / lean — plus a drift of leafy motes. Replaces the old rigid Neon
-- ring + dome (which read as a flat plastic blob). Blades use the textured Grass material (not Neon)
-- and grow from the ground up. Everything re-randomizes per call so a re-firing aura looks alive.
local function grassBloom(pos, c1, c2, radius, life)
    local v = GRASS_BLOOM_VAR
    local gmat = materialOf("Grass")
    local tufts = math.max(4, v.tufts + math.random(-v.tuft_jitter, v.tuft_jitter))
    for _ = 1, tufts do
        -- even area distribution (sqrt) so clumps fill the disc instead of piling at the centre
        local rr = radius * math.sqrt(math.random())
        local ca = math.random() * math.pi * 2
        local base = pos + Vector3.new(math.cos(ca) * rr, 0, math.sin(ca) * rr)
        local n = math.random(v.blades_min, v.blades_max)
        for _ = 1, n do
            local shade = c1:Lerp(c2, math.random()) -- a fresh green per blade
            local h = radius * v.blade_height * (1 + (math.random() - 0.5) * 2 * v.height_jitter)
            local w = math.max(0.1, radius * 0.035)
            local leanDir = math.random() * math.pi * 2
            local lean = math.rad((math.random() - 0.5) * 2 * v.lean_deg)
            local off = Vector3.new(
                (math.random() - 0.5) * radius * v.clump_spread,
                0.1,
                (math.random() - 0.5) * radius * v.clump_spread
            )
            local startCF = CFrame.new(base + off)
                * CFrame.Angles(0, leanDir, 0)
                * CFrame.Angles(lean, 0, 0)
            local blade = newPart(Enum.PartType.Block, gmat, shade, 0.05)
            blade.Size = Vector3.new(w, 0.2, w)
            blade.CFrame = startCF
            -- grow along the blade's OWN up-axis (startCF carries the lean) so the base stays
            -- planted as it shoots up — not sliding straight up out of the ground.
            tween(blade, life + 0.15, {
                Size = Vector3.new(w * 0.6, h, w * 0.6),
                CFrame = startCF * CFrame.new(0, h * 0.5, 0),
                Transparency = 1,
            })
        end
    end
    -- a soft drift of leafy motes/pollen — gentle rise then settle (drifting leaves, not a launch)
    particleBurst(pos + Vector3.new(0, 0.6, 0), {
        color1 = c1,
        color2 = c2,
        count = math.max(6, math.floor(radius * v.mote_frac)),
        speed_min = 2,
        speed_max = 6,
        accel_y = -3,
        size = math.max(0.5, radius * 0.1),
        life_min = 0.7,
        life_max = 1.5,
        spread = 80,
        drag = 3,
        light_emission = 0.25,
    })
end

-- ===== The eight effects =====

local EFFECTS = {
    grass_scatter = scatterEffect,
    lava_scatter = scatterEffect,
    ice_scatter = scatterEffect,
    desert_scatter = scatterEffect,
    grass_rubble = rubbleEffect,
    lava_rubble = rubbleEffect,
    ice_rubble = rubbleEffect,
    desert_rubble = rubbleEffect,
    -- GRASS self: Bloom — clumps of grass blades sprout at random across the field + leafy motes
    -- drift up. Organic (no flat Neon dome / rigid ring); re-randomizes every call so the bear's
    -- per-tick aura reads as ground continuously sprouting, not a stamped green blob (Jason).
    grass_self = function(pos, c1, c2, _mat, radius, life)
        grassBloom(pos, c1, c2, radius, life)
    end,
    -- GRASS targeted: Thornfield — angled thorns erupt outward from the point.
    grass_targeted = function(pos, c1, c2, mat, radius, life)
        radialSpikes(pos, c1, mat, 14, radius, radius * 0.6, life, 55)
        groundRing(pos, c2, mat, radius * 2, life)
        debris(pos, c1, c2, mat, 10, radius, life)
    end,
    -- DESERT self: Sandstorm — a rising swirl of sand + a faint dust ring.
    desert_self = function(pos, c1, c2, mat, radius, life, opts)
        if not (opts and opts.no_ring) then
            groundRing(pos, c1, mat, radius * 2, life, 0.55)
        end
        swirlMotes(pos, c1, mat, 24, radius, radius * 0.8, life + 0.2)
        swirlMotes(pos, c2, mat, 12, radius * 0.7, radius * 0.6, life + 0.1)
    end,
    -- DESERT targeted: Quake — ground cracks shoot out + rubble bursts up.
    desert_targeted = function(pos, c1, c2, mat, radius, life)
        groundCracks(pos, c2, mat, 10, radius * 1.8, life)
        debris(pos, c1, c2, mat, 18, radius, life)
        dome(pos, c1, mat, radius * 0.5, life, 0.75)
        groundRing(pos, c1, mat, radius * 1.6, life, 0.5)
    end,
    -- ICE self: Frost nova — radial ice crystals form in a ring + a pale flat nova.
    ice_self = function(pos, c1, c2, mat, radius, life, opts)
        if not (opts and opts.no_ring) then
            groundRing(pos, c2, mat, radius * 2.2, life)
            radialSpikes(pos, c1, mat, 12, radius * 0.7, radius * 0.35, life, 22)
        end
        dome(pos, c2, mat, radius * 0.55, life, 0.7)
    end,
    -- ICE targeted: Icefall — icicles rain down onto the point + an ice column.
    ice_targeted = function(pos, c1, c2, mat, radius, life)
        fallingBits(pos, c2, mat, 12, radius * 1.6, radius, life, true)
        column(pos, c1, mat, radius * 1.4, life * 0.8)
        groundRing(pos, c2, mat, radius * 2, life)
        debris(pos, c1, c2, mat, 10, radius, life)
    end,
    -- HEAL self: a gentle nova — soft dome + ring + rising sparkles (restorative, not explosive).
    heal_self = function(pos, c1, c2, mat, radius, life, opts)
        if not (opts and opts.no_ring) then
            groundRing(pos, c2, mat, radius * 1.9, life)
        end
        dome(pos, c1, mat, radius * 0.65, life, 0.72)
        swirlMotes(pos, c1, mat, 18, radius, radius * 0.9, life + 0.1)
    end,
    -- HEAL targeted: a soft uplift at the point — rising column + ring + sparkles (cast tell handled).
    heal_targeted = function(pos, c1, c2, mat, radius, life)
        column(pos, c1, mat, radius * 1.2, life * 0.7)
        groundRing(pos, c2, mat, radius * 2, life)
        swirlMotes(pos, c1, mat, 14, radius, radius * 0.9, life)
    end,
    -- LAVA self: Fire ring — a circle of REAL fire around the caster + an ember particle poof.
    lava_self = function(pos, c1, c2, mat, radius, life, opts)
        if not (opts and opts.no_ring) then
            groundRing(pos, c1, mat, radius * 1.7, life)
            fireRing(pos, 10, radius * 0.85, life + 0.4, c1, c2)
        end
        particleBurst(pos + Vector3.new(0, 1, 0), {
            color1 = c1,
            color2 = c2,
            count = 26,
            speed_min = 6,
            speed_max = 16,
            accel_y = -12,
            size = 1.4,
            life_min = 0.5,
            life_max = 1.1,
        })
    end,
    -- LAVA pit: a molten tar pit — a dark bubbling pool that lingers (web-sourced ParticleEmitter).
    lava_pit = function(pos, c1, c2, mat, radius, life)
        tarPit(pos, c1, c2, radius, life)
        groundRing(pos, c1, mat, radius * 2, 0.5)
        particleBurst(pos + Vector3.new(0, 1, 0), {
            color1 = c1,
            color2 = c2,
            count = 14,
            speed_min = 4,
            speed_max = 10,
            accel_y = -8,
            size = 1.4,
            life_min = 0.5,
            life_max = 1.0,
        })
    end,
    -- GRASS / ICE / DESERT pit: the same lingering bubbling pool, tinted by the element theme — a
    -- ground hazard for DoT/brand impacts (scorched/frozen/sodden patch). Reuses the tarPit shape.
    grass_pit = function(pos, c1, c2, _mat, radius, life)
        tarPit(pos, c1, c2, radius, life)
    end,
    ice_pit = function(pos, c1, c2, _mat, radius, life)
        tarPit(pos, c1, c2, radius, life)
    end,
    desert_pit = function(pos, c1, c2, _mat, radius, life)
        tarPit(pos, c1, c2, radius, life)
    end,
    -- LAVA targeted: Meteor — a ball drops from above, then real fire + shockwave erupt.
    lava_targeted = function(pos, c1, c2, mat, radius, life)
        local meteor = newPart(Enum.PartType.Ball, mat, c1, 0)
        local sz = radius * 0.5
        meteor.Size = Vector3.new(sz, sz, sz)
        meteor.CFrame = CFrame.new(pos + Vector3.new(0, radius * 2, 0))
        TweenService:Create(meteor, TweenInfo.new(0.18, OUT, DIR_IN), { CFrame = CFrame.new(pos) })
            :Play()
        Debris:AddItem(meteor, 0.4)
        task.delay(0.18, function()
            meteor:Destroy()
            fireRing(pos, 10, radius * 0.9, life + 0.4, c1, c2) -- fire around the impact zone
            column(pos, c2, mat, radius * 1.8, life * 0.7)
            groundRing(pos, c1, mat, radius * 2.6, life)
            groundRing(pos, c2, mat, radius * 3.6, life * 1.2)
            debris(pos, c1, c2, mat, 18, radius * 1.4, life)
        end)
    end,
    -- LIGHTNING self: Storm strike — jagged bolts crash down around the caster + an electric shock
    -- ring + a spark burst. Reuses lightningStrikes (the electric sibling of the lava fire ring);
    -- grass pets already throw lightning bolts, so a lightning-themed AoE pet passes element="lightning".
    lightning_self = function(pos, c1, c2, mat, radius, life, opts)
        if not (opts and opts.no_ring) then
            groundRing(pos, c2, mat, radius * 1.9, life, 0.2)
            lightningStrikes(pos, 7, radius * 0.85, life, c1, c2)
        end
        particleBurst(pos + Vector3.new(0, 1, 0), {
            color1 = c1,
            color2 = c2,
            count = 22,
            speed_min = 8,
            speed_max = 22,
            accel_y = -6,
            size = 0.9,
            life_min = 0.25,
            life_max = 0.6,
            light_emission = 1,
        })
    end,
    -- LIGHTNING pit: an electrified patch — the lingering bubbling pool tinted electric (same
    -- ground-hazard shape as the other element pits, reused via tarPit).
    lightning_pit = function(pos, c1, c2, _mat, radius, life)
        tarPit(pos, c1, c2, radius, life)
    end,
    -- LIGHTNING targeted: Thunderstrike — a focal bolt slams the point with satellite bolts + a
    -- brief electric flash column + a double shock ring. Cast tell (beam + telegraph) handled upstream.
    lightning_targeted = function(pos, c1, c2, mat, radius, life)
        lightningStrikes(pos, 6, radius * 0.9, life, c1, c2)
        column(pos, c2, mat, radius * 1.1, life * 0.45)
        groundRing(pos, c1, mat, radius * 2.4, life, 0.2)
        groundRing(pos, c2, mat, radius * 3.4, life * 1.2, 0.4)
        particleBurst(pos + Vector3.new(0, 1, 0), {
            color1 = c1,
            color2 = c2,
            count = 18,
            speed_min = 8,
            speed_max = 20,
            accel_y = -6,
            size = 0.8,
            life_min = 0.2,
            life_max = 0.5,
            light_emission = 1,
        })
    end,
}

-- Targeted variants lead with a cast tell (beam from caster + ground telegraph), then run.
local function castTell(c2, mat, origin, target, radius, castTime)
    beam(
        origin + Vector3.new(0, 2, 0),
        target + Vector3.new(0, 1, 0),
        c2,
        mat,
        0.35,
        castTime + 0.08
    )
    groundRing(target, c2, mat, radius * 1.6, castTime + 0.12, 0.55)
end

-- Play an area effect. element keys config.themes; variant is "self" or "targeted".
-- themeOverride (optional { color, color2, material }) reuses an effect's SHAPE with different
-- colours — e.g. the heal nova/splash shapes tinted per biome without new EFFECTS entries.
function AreaFX.Play(config, element, variant, originPos, targetPos, themeOverride, opts)
    config = type(config) == "table" and config or {}
    local theme = themeOverride or (config.themes and config.themes[element])
    if not theme then
        return false
    end
    variant = variant or "self"
    local fn = EFFECTS[element .. "_" .. variant]
    if not fn then
        return false
    end

    local c1 = toColor(theme.color)
    local c2 = toColor(theme.color2, c1)
    local mat = materialOf(theme.material)
    local params = config[variant] or config.self or {}
    -- opts.radius lets the CALLER size the effect to a real gameplay radius (e.g. an AoE pet's
    -- splash_radius), so the fire circle visually matches the actual damage zone instead of the
    -- config default. Falls back to the per-variant config radius.
    local radius = (opts and tonumber(opts.radius)) or tonumber(params.radius) or 10
    local life = tonumber(params.duration) or 0.6

    -- opts.no_ring strips the encircling ground/radial ring from a "self" burst, keeping the
    -- on-caster core (dome / rising motes / ember poof) — a contained cast tell, not an AoE ring.
    if variant == "targeted" then
        local target = targetPos or originPos
        local castTime = math.max(0.05, tonumber(params.cast_time) or 0.18)
        castTell(c2, mat, originPos, target, radius, castTime)
        task.delay(castTime, function()
            fn(target, c1, c2, mat, radius, life, opts)
        end)
    else
        fn(originPos, c1, c2, mat, radius, life, opts)
    end
    return true
end

return AreaFX
