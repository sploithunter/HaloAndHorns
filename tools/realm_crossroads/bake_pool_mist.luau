-- Authored ambient effect: no gameplay or global lighting changes.
return function(world, cfg)
    local pool = world.CrossroadsFishingR10.HellFishingPool
    local old = pool:FindFirstChild("GreenPoolMist")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "GreenPoolMist"
    folder.Parent = pool
    local c = cfg.hell_mist
    local p = cfg.ponds[2]
    local count = 0
    for x = -p.radii[1] + c.inset, p.radii[1] - c.inset, c.spacing do
        for z = -p.radii[2] + c.inset, p.radii[2] - c.inset, c.spacing do
            if (x / (p.radii[1] - c.inset)) ^ 2 + (z / (p.radii[2] - c.inset)) ^ 2 <= 1 then
                local source = Instance.new("Part")
                source.Name = "MistSource"
                source.Size = Vector3.new(1, 1, 1)
                source.Anchored = true
                source.Transparency = 1
                source.CanCollide = false
                source.CanTouch = false
                source.CanQuery = false
                source.CastShadow = false
                source.Position =
                    Vector3.new(p.center[1] + x, p.surface + c.height, p.center[2] + z)
                source.Parent = folder
                local mist = Instance.new("ParticleEmitter")
                mist.Name = "SulfurMist"
                mist.Texture = c.texture
                mist.Rate = c.rate
                mist.Lifetime = NumberRange.new(unpack(c.lifetime))
                mist.Speed = NumberRange.new(unpack(c.speed))
                mist.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, c.size[1]),
                    NumberSequenceKeypoint.new(0.45, c.size[2]),
                    NumberSequenceKeypoint.new(1, c.size[3]),
                })
                mist.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.15, 1 - c.opacity),
                    NumberSequenceKeypoint.new(0.65, 1 - c.opacity),
                    NumberSequenceKeypoint.new(1, 1),
                })
                mist.Color = ColorSequence.new(
                    Color3.fromRGB(unpack(c.color_start)),
                    Color3.fromRGB(unpack(c.color_end))
                )
                mist.Acceleration = Vector3.new(unpack(c.acceleration))
                mist.LightEmission = c.light_emission
                mist.Rotation = NumberRange.new(0, 360)
                mist.RotSpeed = NumberRange.new(-12, 12)
                mist.SpreadAngle = Vector2.new(25, 25)
                mist.Parent = source
                count += 1
            end
        end
    end
    return count
end
