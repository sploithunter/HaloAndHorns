--[[
    EnemyAI — pure functional core for moving/chasing enemies + perception + aggro
    (Feature 10, slice 2). No Roblox APIs, no requires (headless-testable).

    Three concerns, all pure (the service supplies positions, dt, and random rolls):

      chaseStep(from, to, speed, dt, stopRange)
          Kinematic horizontal step from `from` toward `to`, capped by speed*dt and
          halted at stopRange. Preserves from.y (anchored enemies are moved server-
          side by CFrame, so they never fall). Returns (newPos, distanceBefore).

      noticeProbability(distance, range) / shouldNotice(distance, range, roll)
          Perception: the chance per check that an enemy NOTICES a target. Linear
          falloff — certain on top of it, zero at/beyond `range`. shouldNotice turns
          a passed-in roll in [0,1) into a decision (deterministic for tests; the
          service passes math.random()).

      threatScore(threat, distance, range) / selectThreatTarget(candidates, range)
          Aggro: the enemy bites the highest-THREAT pet in range, not merely the
          closest — so a high-threat "tank" pulls aggro off squishier pets. Distance
          modulates threat but does not dominate it (a real tank out-threats a closer
          glass cannon). candidates are { { threat = n, distance = n }, ... }.
]]

local EnemyAI = {}

local function dist2D(ax, az, bx, bz)
    local dx, dz = bx - ax, bz - az
    return math.sqrt(dx * dx + dz * dz)
end

-- Move horizontally toward `to`, capped by speed*dt, stopping at stopRange.
-- Returns the new position table {x,y,z} and the distance BEFORE moving.
function EnemyAI.chaseStep(from, to, speed, dt, stopRange)
    local d = dist2D(from.x, from.z, to.x, to.z)
    local stop = stopRange or 0
    if d <= stop or d < 1e-4 then
        return { x = from.x, y = from.y, z = from.z }, d
    end
    local step = math.min((speed or 0) * (dt or 0), d - stop)
    if step < 0 then
        step = 0
    end
    local ux, uz = (to.x - from.x) / d, (to.z - from.z) / d
    return { x = from.x + ux * step, y = from.y, z = from.z + uz * step }, d
end

-- Perception falloff: 1 on top of the target, 0 at/beyond range.
function EnemyAI.noticeProbability(distance, range)
    if not range or range <= 0 then
        return 0
    end
    local p = 1 - (distance / range)
    if p < 0 then
        return 0
    end
    if p > 1 then
        return 1
    end
    return p
end

-- Decision given a roll in [0,1): noticed when roll < probability.
function EnemyAI.shouldNotice(distance, range, roll)
    return (roll or 0) < EnemyAI.noticeProbability(distance, range)
end

-- Threat a pet exerts on an enemy. Threat dominates; proximity only nudges it
-- (a tank that is a little farther still out-pulls a closer squishy pet).
function EnemyAI.threatScore(threat, distance, range)
    local prox = EnemyAI.noticeProbability(distance, range) -- 1 near -> 0 far
    return (threat or 1) * (0.5 + 0.5 * prox)
end

-- Index of the highest-threat candidate within range (nil if none in range).
function EnemyAI.selectThreatTarget(candidates, range)
    local bestI, bestScore
    for i, c in ipairs(candidates or {}) do
        if c.distance <= range then
            local s = EnemyAI.threatScore(c.threat, c.distance, range)
            if not bestScore or s > bestScore then
                bestI, bestScore = i, s
            end
        end
    end
    return bestI, bestScore
end

return EnemyAI
