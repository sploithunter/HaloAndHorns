--[[
    AmplifiedBurst (pure) — the firewall-safe "player damage" primitive (design §16.5 / §17.8).

    Player powers never deal standalone damage. A "damage" capstone (Cataclysm) instead unleashes a
    burst whose size is an AMPLIFICATION of the squad's own attack power — so a weak squad means a
    weak meteor, and the damage is credited to the pets. This module owns the pure arithmetic:

      total(squadAttack, multiplier)        -> the burst each centred enemy takes (squadAttack x mult)
      falloff(dist, radius, edgeFraction)    -> radial scale in [edgeFraction, 1] (centre = full)
      atDistance(squadAttack, mult, dist, radius, edgeFraction) -> the floored burst at `dist`

    Pure + Roblox-free; the service supplies the squad-attack total and the per-enemy distance.
]]

local AmplifiedBurst = {}

-- The full-strength burst: the squad's combined attack scaled by the power's multiplier.
function AmplifiedBurst.total(squadAttack, multiplier)
    local atk = tonumber(squadAttack) or 0
    local mult = tonumber(multiplier) or 0
    if atk <= 0 or mult <= 0 then
        return 0
    end
    return atk * mult
end

-- Radial falloff: 1.0 at the centre, linearly down to `edgeFraction` at `radius` (and held there
-- beyond). edgeFraction defaults to 0.5; clamped to [0, 1]. dist/radius guarded.
function AmplifiedBurst.falloff(dist, radius, edgeFraction)
    local r = tonumber(radius) or 0
    if r <= 0 then
        return 1
    end
    local d = math.max(0, tonumber(dist) or 0)
    local edge = tonumber(edgeFraction) or 0.5
    edge = math.clamp(edge, 0, 1)
    local t = math.min(d / r, 1) -- 0 at centre, 1 at/beyond edge
    return 1 + (edge - 1) * t
end

-- The floored burst an enemy at `dist` takes from a centre burst (total x falloff).
function AmplifiedBurst.atDistance(squadAttack, multiplier, dist, radius, edgeFraction)
    local total = AmplifiedBurst.total(squadAttack, multiplier)
    if total <= 0 then
        return 0
    end
    return math.floor(total * AmplifiedBurst.falloff(dist, radius, edgeFraction) + 0.5)
end

return AmplifiedBurst
