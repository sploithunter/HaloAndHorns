--[[
    RangedFX — client-side ranged attack visuals for pets (and, later, enemies).

    A small dispatcher over interchangeable procedural effects so a pet's ranged "bolt"
    can be swapped from config without touching code. PetFollowController calls
    RangedFX.Play(originInstance, config, targetInstance, kind) on the firing cadence;
    `kind` selects the look:

      "lightning"                  -> the existing EnchantLightning arc (delegated)
      "fireball"/"plasma"/"frost"/
      "poison" (+ any config theme) -> a travelling glowing orb + trail + impact burst
                                       (one engine, themed by config.projectile[kind])
      "beam"                       -> an instant laser/energy beam that flashes + fades

    Add a theme by adding a block under config.ranged_bolt.projectile; add a whole new
    style by adding a branch here. Pure visual: damage + targeting stay server-side.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnchantLightning = require(ReplicatedStorage.Shared.Effects.EnchantLightning)
local SoundGroups = require(ReplicatedStorage.Shared.Effects.SoundGroups)

local RangedFX = {}

local function partOf(inst)
    if not inst then
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

local function toColor(rgb, fallback)
    if typeof(rgb) == "Color3" then
        return rgb
    end
    if type(rgb) == "table" and rgb[1] then
        return Color3.fromRGB(rgb[1], rgb[2] or 0, rgb[3] or 0)
    end
    return fallback or Color3.fromRGB(255, 255, 255)
end

local function toVec(t)
    if typeof(t) == "Vector3" then
        return t
    end
    if type(t) == "table" then
        return Vector3.new(t[1] or 0, t[2] or 0, t[3] or 0)
    end
    return Vector3.new(0, 0, 0)
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

-- Play a one-shot positional sound at `pos` from a config { id, volume, playback_speed }.
-- No-ops if the config or its id is empty (so sounds can be added later without code changes).
local function playSoundAt(pos, cfg)
    if type(cfg) ~= "table" or not cfg.id or cfg.id == "" then
        return
    end
    local holder = Instance.new("Part")
    holder.Transparency = 1
    holder.Size = Vector3.new(0.2, 0.2, 0.2)
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanQuery = false
    holder.CFrame = CFrame.new(pos)
    holder.Parent = fxFolder()
    local s = Instance.new("Sound")
    s.SoundId = cfg.id
    s.Volume = cfg.volume or 0.6
    s.PlaybackSpeed = cfg.playback_speed or 1
    s.RollOffMaxDistance = cfg.max_distance or 120
    SoundGroups.assign(s, "effects")
    s.Parent = holder
    s:Play()
    Debris:AddItem(holder, cfg.lifetime or 3)
end

-- ===================== Impact library =====================
-- A catalogue of named impact effects (RangedFX.IMPACTS), each played at a hit point. Grow
-- this table to build the library; reference an entry by name from a projectile theme
-- (theme.impact) or from mining_fx. Shared spawn helpers below keep each entry small.
--   c1 = core colour, c2 = debris/secondary colour, opts.scale + opts.sparks tune size/count.

-- A neon flash sphere that snaps out and fades, with a quick PointLight pop.
local function spawnFlash(pos, color, lightColor, size, life)
    local flash = Instance.new("Part")
    flash.Shape = Enum.PartType.Ball
    flash.Material = Enum.Material.Neon
    flash.Color = color
    flash.Anchored = true
    flash.CanCollide = false
    flash.CanQuery = false
    flash.CastShadow = false
    flash.Size = Vector3.new(0.5, 0.5, 0.5)
    flash.CFrame = CFrame.new(pos)
    flash.Parent = fxFolder()
    local light = Instance.new("PointLight")
    light.Color = lightColor
    light.Brightness = 7
    light.Range = size * 2.5
    light.Parent = flash
    TweenService
        :Create(flash, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(size, size, size),
            Transparency = 1,
        })
        :Play()
    TweenService:Create(light, TweenInfo.new(life * 0.9), { Brightness = 0 }):Play()
    Debris:AddItem(flash, life + 0.1)
end

-- A radial spray of neon bits that fly outward (with upward lift), shrink + fade.
local function spawnSparks(pos, c1, c2, count, bitSize, spread, life)
    count = math.max(0, math.floor(count))
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random() * 0.6
        local elev = 0.2 + math.random() * 0.6
        local dir = Vector3.new(math.cos(ang), elev, math.sin(ang)).Unit
        local bit = Instance.new("Part")
        bit.Shape = Enum.PartType.Ball
        bit.Material = Enum.Material.Neon
        bit.Color = (i % 2 == 0) and c1 or c2
        bit.Anchored = true
        bit.CanCollide = false
        bit.CanQuery = false
        bit.CastShadow = false
        bit.Size = Vector3.new(bitSize, bitSize, bitSize)
        bit.CFrame = CFrame.new(pos)
        bit.Parent = fxFolder()
        local dist = spread * (0.7 + math.random() * 0.9)
        local dest = pos + dir * dist - Vector3.new(0, spread * 0.25, 0)
        TweenService
            :Create(bit, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(dest),
                Size = Vector3.new(0.05, 0.05, 0.05),
                Transparency = 1,
            })
            :Play()
        Debris:AddItem(bit, life + 0.1)
    end
end

-- A flat neon disc that expands outward + fades — a ground shockwave.
local function spawnShockwave(pos, color, diameter, life)
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.CastShadow = false
    ring.Transparency = 0.2
    ring.Size = Vector3.new(0.4, 1, 1) -- X = thin height; Y/Z = diameter
    ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) -- lay flat (X -> up)
    ring.Parent = fxFolder()
    TweenService
        :Create(ring, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.2, diameter, diameter),
            Transparency = 1,
        })
        :Play()
    Debris:AddItem(ring, life + 0.1)
end

-- A puff that swells + rises + fades — lingering smoke (gray) or dust (tan via `color`).
local function spawnSmoke(pos, diameter, life, color)
    local s = Instance.new("Part")
    s.Shape = Enum.PartType.Ball
    s.Material = Enum.Material.SmoothPlastic
    s.Color = color or Color3.fromRGB(60, 55, 50)
    s.Anchored = true
    s.CanCollide = false
    s.CanQuery = false
    s.CastShadow = false
    s.Transparency = 0.45
    s.Size = Vector3.new(diameter * 0.4, diameter * 0.4, diameter * 0.4)
    s.CFrame = CFrame.new(pos + Vector3.new(0, diameter * 0.2, 0))
    s.Parent = fxFolder()
    TweenService:Create(s, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(diameter, diameter, diameter),
        Transparency = 1,
        CFrame = CFrame.new(pos + Vector3.new(0, diameter * 0.7, 0)),
    }):Play()
    Debris:AddItem(s, life + 0.1)
end

-- A vertical neon pillar that shoots up from the hit point and thins out as it fades.
local function spawnColumn(pos, color, height, life)
    local col = Instance.new("Part")
    col.Shape = Enum.PartType.Cylinder
    col.Material = Enum.Material.Neon
    col.Color = color
    col.Anchored = true
    col.CanCollide = false
    col.CanQuery = false
    col.CastShadow = false
    col.Transparency = 0.15
    local diam = height * 0.18
    col.Size = Vector3.new(1, diam, diam) -- X = length (vertical once rotated); Y/Z = diameter
    col.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    col.Parent = fxFolder()
    TweenService
        :Create(col, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(height, diam * 0.3, diam * 0.3),
            Transparency = 1,
            CFrame = CFrame.new(pos + Vector3.new(0, height * 0.5, 0))
                * CFrame.Angles(0, 0, math.rad(90)),
        })
        :Play()
    Debris:AddItem(col, life + 0.1)
end

-- Pointed glass shards that fly outward + tumble + fade — an icy shatter spray.
local function spawnShards(pos, c1, c2, count, len, spread, life)
    count = math.max(0, math.floor(count))
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random() * 0.6
        local elev = 0.2 + math.random() * 0.7
        local dir = Vector3.new(math.cos(ang), elev, math.sin(ang)).Unit
        local shard = Instance.new("Part")
        shard.Material = Enum.Material.Glass
        shard.Color = (i % 2 == 0) and c1 or c2
        shard.Transparency = 0.1
        shard.Reflectance = 0.3
        shard.Anchored = true
        shard.CanCollide = false
        shard.CanQuery = false
        shard.CastShadow = false
        shard.Size = Vector3.new(len * 0.22, len * 0.22, len) -- long axis = the point
        shard.CFrame = CFrame.new(pos, pos + dir)
        shard.Parent = fxFolder()
        local dist = spread * (0.7 + math.random() * 0.9)
        local dest = pos + dir * dist - Vector3.new(0, spread * 0.2, 0)
        TweenService
            :Create(shard, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(dest) * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
                Size = Vector3.new(0.05, 0.05, 0.05),
                Transparency = 1,
            })
            :Play()
        Debris:AddItem(shard, life + 0.1)
    end
end

RangedFX.IMPACTS = {
    -- small: a flash + light pop + a handful of embers (the original projectile impact).
    small = function(pos, c1, c2, opts)
        local scale = (opts and tonumber(opts.scale)) or 3
        local sparks = (opts and tonumber(opts.sparks)) or 7
        spawnFlash(pos, c2, c1, scale, 0.25)
        spawnSparks(pos, c1, c2, sparks, scale * 0.2, scale, 0.32)
    end,
    -- medium: a fat double flash + bright light + shockwave disc + heavy ember spray + smoke puff.
    medium = function(pos, c1, c2, opts)
        local scale = (opts and tonumber(opts.scale)) or 7
        local sparks = (opts and tonumber(opts.sparks)) or 18
        spawnFlash(pos, c2, c1, scale, 0.35)
        spawnFlash(pos, c1, c1, scale * 0.6, 0.22) -- inner core
        spawnShockwave(pos, c2, scale * 2.4, 0.4)
        spawnSparks(pos, c1, c2, sparks, scale * 0.22, scale * 1.6, 0.45)
        spawnSmoke(pos, scale * 1.2, 0.6)
    end,
    -- big: a really big blast — double flash + huge bright light + DOUBLE shockwave ring + a
    -- rising energy pillar + a thick ember storm + a big lingering smoke cloud.
    big = function(pos, c1, c2, opts)
        local scale = (opts and tonumber(opts.scale)) or 12
        local sparks = (opts and tonumber(opts.sparks)) or 32
        spawnFlash(pos, c2, c1, scale, 0.45)
        spawnFlash(pos, c1, c1, scale * 0.6, 0.3) -- inner core
        spawnShockwave(pos, c2, scale * 2.2, 0.45) -- inner ring
        spawnShockwave(pos, c1, scale * 3.6, 0.65) -- outer, wider, slower ring
        spawnColumn(pos, c1, scale * 2.2, 0.5) -- rising pillar
        spawnSparks(pos, c1, c2, sparks, scale * 0.22, scale * 2.0, 0.6)
        spawnSmoke(pos, scale * 1.7, 0.85)
    end,
    -- shatter (ICE): a quick flash + frost ring + a spray of glass shards. Crisp, not fiery.
    shatter = function(pos, c1, c2, opts)
        local scale = (opts and tonumber(opts.scale)) or 5
        local shards = (opts and tonumber(opts.sparks)) or 12
        spawnFlash(pos, c2, c1, scale * 0.8, 0.2)
        spawnShockwave(pos, c1, scale * 1.8, 0.4)
        spawnShards(pos, c1, c2, shards, scale * 0.5, scale * 1.4, 0.5)
    end,
    -- dust (DESERT): a low tan cloud + rubble bits + a ground ring. No bright flash — earthy.
    dust = function(pos, c1, c2, opts)
        local scale = (opts and tonumber(opts.scale)) or 5
        local bits = (opts and tonumber(opts.sparks)) or 10
        spawnShockwave(pos, c1, scale * 1.6, 0.45)
        spawnSparks(pos, c1, c2, bits, scale * 0.24, scale * 1.2, 0.5) -- rubble
        spawnSmoke(pos, scale * 1.5, 0.75, Color3.fromRGB(196, 170, 120)) -- tan dust cloud
    end,
    -- bloom (HEAL): a soft flash + gentle ring + sparkles — restorative, not explosive.
    bloom = function(pos, c1, c2, opts)
        local scale = (opts and tonumber(opts.scale)) or 3
        local sparks = (opts and tonumber(opts.sparks)) or 10
        spawnFlash(pos, c1, c2, scale * 0.8, 0.3)
        spawnShockwave(pos, c2, scale * 1.6, 0.45)
        spawnSparks(pos, c1, c2, sparks, scale * 0.16, scale * 1.0, 0.5)
    end,
}

-- Play a named impact at `pos`. c1/c2 accept Color3 or {r,g,b}. Unknown name -> small.
function RangedFX.playImpact(name, pos, c1, c2, opts)
    local fn = RangedFX.IMPACTS[name] or RangedFX.IMPACTS.small
    local col1 = toColor(c1)
    fn(pos, col1, toColor(c2, col1), opts)
end

-- Travelling orb (fireball / plasma / frost / poison): an emissive ball flies origin->target
-- with a colour trail, then bursts. Themed entirely by `theme` (colors/size/travel_time/burst).
-- isCrit -> a bigger orb + the crit impact tier (theme.impact_crit, default "big").
local function playProjectile(originPart, endPos, theme, isCrit, impactSound)
    local c1 = toColor(theme.colors and theme.colors[1], Color3.fromRGB(255, 150, 40))
    local c2 = toColor(theme.colors and theme.colors[2], c1)
    local size = (tonumber(theme.size) or 1.5) * (isCrit and 1.4 or 1)
    local travel = math.max(0.05, tonumber(theme.travel_time) or 0.18)
    local startPos = originPart.Position + Vector3.new(0, 1, 0)

    local orb = Instance.new("Part")
    orb.Shape = Enum.PartType.Ball
    orb.Material = Enum.Material.Neon
    orb.Color = c1
    orb.Anchored = true
    orb.CanCollide = false
    orb.CanQuery = false
    orb.CastShadow = false
    orb.Size = Vector3.new(size, size, size)
    orb.CFrame = CFrame.new(startPos)
    orb.Parent = fxFolder()

    local light = Instance.new("PointLight")
    light.Color = c1
    light.Brightness = 4
    light.Range = 12
    light.Parent = orb

    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 0, size * 0.5)
    a0.Parent = orb
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, 0, -size * 0.5)
    a1.Parent = orb
    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Lifetime = 0.2
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.Color = ColorSequence.new(c1, c2)
    trail.Transparency = NumberSequence.new(0.1, 1)
    trail.FaceCamera = true
    trail.Parent = orb

    local tween = TweenService:Create(
        orb,
        TweenInfo.new(travel, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { CFrame = CFrame.new(endPos) }
    )
    tween.Completed:Connect(function()
        if isCrit then
            -- Crit: the crit tier at its own (bigger) default size.
            RangedFX.playImpact(theme.impact_crit or "big", endPos, c1, c2, {
                scale = theme.crit_scale,
                sparks = theme.crit_sparks,
            })
        else
            RangedFX.playImpact(theme.impact or "small", endPos, c1, c2, {
                scale = (tonumber(theme.burst) or 3) * (size / 1.5),
                sparks = theme.sparks,
            })
        end
        playSoundAt(endPos, impactSound)
        orb:Destroy()
    end)
    tween:Play()
    Debris:AddItem(orb, travel + 0.6)
    return true
end

-- Instant laser/energy beam: a neon cylinder spanning origin->target that flashes then fades.
-- isCrit -> the crit impact tier at its end (theme.impact_crit, default "big").
local function playBeam(originPart, endPos, theme, isCrit, impactSound)
    local c1 = toColor(theme.colors and theme.colors[1], Color3.fromRGB(255, 70, 70))
    local thickness = tonumber(theme.thickness) or 0.5
    local duration = math.max(0.06, tonumber(theme.duration) or 0.18)
    local startPos = originPart.Position + Vector3.new(0, 1, 0)
    local dist = (endPos - startPos).Magnitude
    if dist < 0.1 then
        return false
    end

    local beam = Instance.new("Part")
    beam.Shape = Enum.PartType.Cylinder
    beam.Material = Enum.Material.Neon
    beam.Color = c1
    beam.Anchored = true
    beam.CanCollide = false
    beam.CanQuery = false
    beam.CastShadow = false
    beam.Size = Vector3.new(dist, thickness, thickness)
    beam.CFrame = CFrame.lookAt(startPos:Lerp(endPos, 0.5), endPos)
        * CFrame.Angles(0, math.rad(90), 0)
    beam.Parent = fxFolder()

    TweenService
        :Create(beam, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
            Size = Vector3.new(dist, 0.05, 0.05),
        })
        :Play()
    Debris:AddItem(beam, duration + 0.1)
    if isCrit then
        RangedFX.playImpact(theme.impact_crit or "big", endPos, c1, c1, {
            scale = theme.crit_scale,
            sparks = theme.crit_sparks,
        })
    else
        RangedFX.playImpact(theme.impact or "small", endPos, c1, c1, {
            scale = tonumber(theme.burst) or 2.5,
            sparks = theme.sparks or 5,
        })
    end
    playSoundAt(endPos, impactSound)
    return true
end

-- A cloneable single-part template for a model asset (e.g. the rock / a future cactus). The
-- SERVER preloads these into ReplicatedStorage.RangedFXAssets[tostring(assetId)] (InsertService
-- is server-only); the client just clones the replicated part. Returns nil until it replicates
-- (callers fall back to a procedural block meanwhile).
local function getModelPart(assetId)
    if not assetId then
        return nil
    end
    local folder = ReplicatedStorage:FindFirstChild("RangedFXAssets")
    return folder and folder:FindFirstChild(tostring(assetId)) or nil
end

-- Rock throw (DESERT): summon a boulder at the pet and hurl it, tumbling, at the target; it
-- lands with a dust impact. Uses the configured model_asset (a rock union; swap to a cactus id
-- + green colours later); falls back to a procedural Slate block until the asset loads.
-- isCrit -> bigger rock + the crit impact tier (theme.impact_crit, default "big").
local function playRock(originPart, endPos, theme, isCrit, impactSound)
    local c1 = toColor(theme.colors and theme.colors[1], Color3.fromRGB(120, 105, 90))
    local c2 = toColor(theme.colors and theme.colors[2], Color3.fromRGB(170, 145, 110))
    local crit = isCrit and 1.4 or 1
    local travel = math.max(0.08, tonumber(theme.travel_time) or 0.3)
    local startPos = originPart.Position + Vector3.new(0, 2, 0)

    local rock
    local template = getModelPart(tonumber(theme.model_asset))
    if template then
        rock = template:Clone()
        local nat = rock.Size
        local scaleFactor = (tonumber(theme.size) or 3) / math.max(nat.X, nat.Y, nat.Z, 0.1)
        rock.Size = nat * (scaleFactor * crit)
        pcall(function()
            rock.UsePartColor = true -- unions honour Color via this; tint for cacty variants
        end)
        rock.Color = c1
    else
        local s = (tonumber(theme.size) or 3) * crit
        rock = Instance.new("Part")
        rock.Material = Enum.Material.Slate
        rock.Color = c1
        rock.Size = Vector3.new(s, s * 0.85, s * 1.1)
    end
    rock.Anchored = true
    rock.CanCollide = false
    rock.CanQuery = false
    rock.CastShadow = false
    rock.CFrame = CFrame.new(startPos)
    rock.Parent = fxFolder()

    -- Quick "summon" pop-in, then hurl + tumble (end rotation interpolates into a tumble).
    local fullSize = rock.Size
    rock.Size = fullSize * 0.1
    TweenService:Create(rock, TweenInfo.new(0.08), { Size = fullSize }):Play()
    local dest = CFrame.new(endPos) * CFrame.Angles(math.rad(170), math.rad(140), math.rad(80))
    local tween = TweenService:Create(
        rock,
        TweenInfo.new(travel, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { CFrame = dest }
    )
    tween.Completed:Connect(function()
        local impactName = isCrit and (theme.impact_crit or "big") or (theme.impact or "dust")
        RangedFX.playImpact(impactName, endPos, c2, c1, {
            scale = isCrit and theme.crit_scale or theme.impact_scale,
            sparks = isCrit and theme.crit_sparks or theme.sparks,
        })
        playSoundAt(endPos, impactSound)
        rock:Destroy()
    end)
    tween:Play()
    Debris:AddItem(rock, travel + 0.7)
    return true
end

-- Fire a ranged effect of `kind` from origin to target. Falls back to lightning for an
-- unknown kind. config is the ranged_bolt block (target_offset already a Vector3 from caller).
-- isCrit (from the server's LastHitCrit on the firing pet) bumps the impact to its crit tier.
function RangedFX.Play(origin, config, target, kind, isCrit, element)
    config = type(config) == "table" and config or {}
    kind = kind or config.kind or "lightning"

    -- Delivery (launch) sound at the firing pet; impact sound rides each effect's hit.
    local sounds = config.sounds or {}
    local oPart = partOf(origin)
    if oPart then
        playSoundAt(oPart.Position + Vector3.new(0, 1, 0), sounds.delivery)
    end

    if kind == "lightning" then
        local ok = EnchantLightning.Play(origin, config, target)
        -- Also play a library impact at the strike point, tinted with the bolt's electric colours.
        -- Normal -> config.impact (none/small/medium/big); crit -> config.impact_crit (default big).
        local impactName = isCrit and (config.impact_crit or "big") or config.impact
        if impactName and impactName ~= "none" then
            local targetPart = partOf(target)
            if targetPart then
                local cols = config.colors or {}
                local opts = isCrit and { scale = config.crit_scale, sparks = config.crit_sparks }
                    or { scale = config.impact_scale, sparks = config.impact_sparks }
                RangedFX.playImpact(
                    impactName,
                    targetPart.Position + toVec(config.target_offset),
                    cols[1] or { 120, 150, 255 },
                    cols[2] or { 200, 235, 255 },
                    opts
                )
            end
        end
        local tp = partOf(target)
        if tp then
            playSoundAt(tp.Position + toVec(config.target_offset), sounds.impact)
        end
        return ok
    end

    local originPart = partOf(origin)
    local targetPart = partOf(target)
    if not originPart or not targetPart then
        return false
    end
    local endPos = targetPart.Position + toVec(config.target_offset)

    if kind == "beam" then
        return playBeam(originPart, endPos, config.beam or {}, isCrit, sounds.impact)
    end
    if kind == "rock" then
        return playRock(originPart, endPos, config.rock or {}, isCrit, sounds.impact)
    end
    -- Thrown-boulder variants (asteroid / boulder / ice_boulder): same tumbling-rock animation, own
    -- mesh + tint + impact, selected by kind.
    if config.boulders and config.boulders[kind] then
        return playRock(originPart, endPos, config.boulders[kind], isCrit, sounds.impact)
    end
    if kind == "melee" then
        -- Melee/mining hit: the pet is already adjacent, so no projectile — just an impact at the
        -- target + the hit sound. Tier scales with crit. Per-biome via melee_by_element[element]
        -- (so upfront grass != upfront lava); falls back to the generic config.melee.
        local m = (element and config.melee_by_element and config.melee_by_element[element])
            or config.melee
            or {}
        local cols = m.colors or {}
        local impactName = isCrit and (m.impact_crit or "medium") or (m.impact or "small")
        RangedFX.playImpact(
            impactName,
            endPos,
            cols[1] or { 255, 235, 190 },
            cols[2] or { 255, 210, 140 },
            {}
        )
        playSoundAt(endPos, sounds.impact)
        return true
    end

    -- Projectile family: theme comes from config.projectile[kind] (fireball/plasma/frost/...).
    local theme = (config.projectile and config.projectile[kind]) or {}
    return playProjectile(originPart, endPos, theme, isCrit, sounds.impact)
end

return RangedFX
