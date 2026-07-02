--[[
    PowerFXRender (client) — render one power-FX primitive on a real cast, with TBD placeholders.

        PowerFXRender.play({ primId, element, kind, caster, target, point })

    Resolves the `configs/power_fx.lua` primitive and plays it through the CombatFX facade, then plays
    its sound (PowerSound). Two independent placeholders, per design:
      • no primitive (or primId == "tbd")  → floating "(effect TBD)"
      • no sound for this phase/element     → floating "(sound TBD)"
    so unmapped powers and unauthored sounds are visibly flagged, not silently dropped.

    `kind` = "source" (on the caster) | "target" (at an enemy). Shared by PowerService's cast path
    (via the Power_AreaFx primId branch in PetFollowController).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFX = require(ReplicatedStorage.Shared.Effects.CombatFX)
local PowerSound = require(ReplicatedStorage.Shared.Effects.PowerSound)
local FloatingText = require(ReplicatedStorage.Shared.Effects.FloatingText)
local FX = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_fx"))

local PowerFXRender = {}

local function partOf(inst)
    if typeof(inst) ~= "Instance" then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst
    end
    return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
end

local function anchorPos(opts)
    if opts.point then
        return opts.point
    end
    local p = partOf(opts.target) or partOf(opts.caster)
    return p and p.Position or Vector3.new()
end

local function tbd(pos, text)
    pcall(function()
        -- Start near the caster (not high above) and drift up SLOWLY over a long duration so the
        -- placeholder is actually readable — the old +6 start / +5 fast rise shot it off the top of
        -- the close third-person camera in a split second.
        FloatingText.show(pos + Vector3.new(0, 2.5, 0), text, {
            color = Color3.fromRGB(255, 220, 120),
            size = 20,
            duration = 3.0,
            rise = 1.5,
            jitter = 0.6,
        })
    end)
end

function PowerFXRender.play(opts)
    opts = opts or {}
    local element = opts.element
    local pos = anchorPos(opts)
    local prim = opts.primId and opts.primId ~= "tbd" and FX.primitives[opts.primId] or nil

    -- effect
    if prim then
        local spec = {
            pattern = prim.pattern,
            element = element,
            origin = prim.origin,
            category = prim.category,
            duration = prim.duration,
            variant = prim.variant, -- st_aoe shape (pit)
            projectile = prim.projectile, -- st_attack explicit kind
            impact = prim.impact, -- impact-pattern point-burst name
            no_ring = prim.no_ring, -- pbaoe: drop the encircling ring, keep on-caster core
        }
        local ctx = { caster = opts.caster }
        if prim.pattern == "st_attack" then
            ctx.target = opts.target
        elseif prim.anchor == "target" then
            ctx.point = opts.point or pos
        end
        pcall(function()
            CombatFX.play(spec, ctx)
        end)
    else
        tbd(pos, "(effect TBD)")
    end

    -- sound (independent of the effect): an explicit soundPhase wins (buff/shield), else cast/impact.
    -- The "(sound TBD)" placeholder is INTENTIONAL — it reminds us an effect has no audio yet, even if
    -- its visual is done. Don't suppress it.
    local phase = (prim and prim.soundPhase) or (opts.kind == "target" and "impact") or "cast"
    local played = PowerSound.play(phase, element, pos)
    if not played then
        tbd(pos, "(sound TBD)")
    end
end

return PowerFXRender
