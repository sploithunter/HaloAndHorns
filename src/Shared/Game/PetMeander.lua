--[[
    PetMeander — idle wander offsets for follower pets (pure).

    Jason: "Pets should meander... near their group location so they don't just
    stand there doing nothing — they're basically frozen statues unless they're
    engaged with combat."

    Each idle pet keeps a tiny state machine: PAUSE at its formation slot, pick a
    random point within `radius` of it, AMBLE there at `speed`, pause again. The
    output is a horizontal OFFSET from the formation slot — the caller adds it to
    the slot position and the existing moveToward/gait pipeline does the rest
    (distance-driven waddle + face-the-walk-direction come free; keep `speed`
    above movement.face_move_speed so the pet heads where it strolls).

    Pure: state in, state mutated, offset out. `rand` is injected (math.random
    in the client, a scripted sequence in specs). The CALLER decides when a pet
    may meander (player still, pet untargeted) and calls reset() otherwise so
    the pet glides home and the next idle period starts fresh.

    Consumed by PetFollowController (client). Config: configs/pet_follow.lua
    `meander`. Spec: tests/headless/specs/pet_meander.spec.luau.
]]

local PetMeander = {}

-- Fresh state: parked on the slot, first stroll after a short randomized pause
-- (so a squad released into idle doesn't step off in lockstep).
function PetMeander.newState(cfg, rand)
    local pmin = tonumber(cfg and cfg.pause_min) or 1.5
    local pmax = math.max(pmin, tonumber(cfg and cfg.pause_max) or 4)
    return {
        x = 0,
        z = 0, -- current offset from the formation slot
        gx = nil,
        gz = nil, -- stroll goal (nil = pausing)
        wait = pmin + (pmax - pmin) * rand(),
    }
end

-- Back to the slot (the caller's moveToward glides the model home); next idle
-- period starts with a fresh pause.
function PetMeander.reset(state, cfg, rand)
    state.x, state.z = 0, 0
    state.gx, state.gz = nil, nil
    local pmin = tonumber(cfg and cfg.pause_min) or 1.5
    local pmax = math.max(pmin, tonumber(cfg and cfg.pause_max) or 4)
    state.wait = pmin + (pmax - pmin) * rand()
end

-- Advance one frame; returns the offset (x, z) to add to the formation slot.
function PetMeander.step(state, dt, cfg, rand)
    dt = tonumber(dt) or 0
    local radius = tonumber(cfg and cfg.radius) or 6
    local speed = tonumber(cfg and cfg.speed) or 4

    if state.gx == nil then
        -- pausing at the current spot
        state.wait = (state.wait or 0) - dt
        if state.wait <= 0 then
            -- pick the next stroll goal: a point within the meander disc around the
            -- SLOT (not around the pet), so drift can never accumulate past radius
            local ang = rand() * 2 * math.pi
            local dist = radius * (0.3 + 0.7 * rand()) -- skip the dead-center shuffle
            state.gx = math.cos(ang) * dist
            state.gz = math.sin(ang) * dist
        end
        return state.x, state.z
    end

    -- ambling toward the goal at a fixed stroll speed
    local dx, dz = state.gx - state.x, state.gz - state.z
    local distLeft = math.sqrt(dx * dx + dz * dz)
    local stepLen = speed * dt
    if stepLen >= distLeft or distLeft < 1e-4 then
        state.x, state.z = state.gx, state.gz
        state.gx, state.gz = nil, nil
        local pmin = tonumber(cfg and cfg.pause_min) or 1.5
        local pmax = math.max(pmin, tonumber(cfg and cfg.pause_max) or 4)
        state.wait = pmin + (pmax - pmin) * rand()
    else
        state.x = state.x + dx / distLeft * stepLen
        state.z = state.z + dz / distLeft * stepLen
    end
    return state.x, state.z
end

-- Soft separation (Jason: "we're not going to prevent overlap via collisions —
-- they'll kind of move away from each other so the other system can take over").
-- One relaxation pass over TARGET points: any pair closer than minDist gets
-- pushed apart along their connecting axis, half each. The caller adds the push
-- to each pet's goal and the normal moveToward smoothing walks them apart — no
-- physics, no hard constraint, well-spaced formations are untouched (no-op past
-- minDist). Coincident points tie-break on a per-index golden-angle direction.
-- points: array of { x, z }; returns a parallel array of { x, z } pushes.
function PetMeander.separate(points, minDist)
    local push = {}
    for i = 1, #points do
        push[i] = { x = 0, z = 0 }
    end
    minDist = tonumber(minDist) or 0
    if minDist <= 0 then
        return push
    end
    for i = 1, #points - 1 do
        for j = i + 1, #points do
            local dx = points[j].x - points[i].x
            local dz = points[j].z - points[i].z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < minDist then
                local ux, uz
                if dist > 1e-4 then
                    ux, uz = dx / dist, dz / dist
                else
                    local ang = i * 2.399963 -- golden angle: stable, spread-out tie-break
                    ux, uz = math.cos(ang), math.sin(ang)
                end
                local half = (minDist - dist) / 2
                push[i].x -= ux * half
                push[i].z -= uz * half
                push[j].x += ux * half
                push[j].z += uz * half
            end
        end
    end
    return push
end

return PetMeander
