--[[
    PetFormation — pure functional core for pet-follow positioning (issue #4).

    No Roblox APIs. Computes where each equipped pet should sit relative to the
    player, from a config-driven formation. The service (PetFollowService) feeds
    it the player's frame each tick and drives an AlignPosition per pet to the
    returned world position — replacing the cloned control-box chain.

    A "frame" is a plain table describing the player's root orientation:
        { position = {x,y,z}, look = {x,y,z}, right = {x,y,z} }
    (look = unit forward, right = unit right; up is assumed world +Y.)

      slotOffset(index, count, formation)            -> { x, y, back }
          local offset: x = lateral (along right), y = height (up),
          back = distance behind the player (along -look). 1-based index.
      targetPosition(frame, index, count, formation)  -> { x, y, z } world
      floatOffset(phase, floatConfig)                 -> number (vertical bob)
]]

local PetFormation = {}

local function degToRad(d)
    return d * math.pi / 180
end

-- Local offset for pet `index` of `count`, per the formation mode.
function PetFormation.slotOffset(index, count, formation)
    local i = index - 1 -- 0-based
    if formation.mode == "circle" then
        local angle
        if count <= 1 then
            angle = 0
        else
            local t = i / (count - 1) -- 0..1
            local arc = degToRad(formation.arc_degrees)
            angle = -arc / 2 + t * arc
        end
        return {
            x = formation.radius * math.sin(angle),
            y = formation.height,
            back = formation.follow_distance + formation.radius * math.cos(angle),
        }
    end

    -- default: "rows" — a centered marching grid behind the player.
    local perRow = formation.per_row
    local row = math.floor(i / perRow)
    local col = i % perRow
    local petsInRow = math.min(perRow, count - row * perRow)
    local center = (petsInRow - 1) / 2
    return {
        x = (col - center) * formation.col_spacing,
        y = formation.height,
        back = formation.follow_distance + row * formation.row_spacing,
    }
end

-- World target for pet `index`, applying the local offset to the player frame.
-- world = position + right*x + up*y + (-look)*back
function PetFormation.targetPosition(frame, index, count, formation)
    local off = PetFormation.slotOffset(index, count, formation)
    local p, look, right = frame.position, frame.look, frame.right
    return {
        x = p.x + right.x * off.x - look.x * off.back,
        y = p.y + off.y - look.y * off.back + right.y * off.x,
        z = p.z + right.z * off.x - look.z * off.back,
    }
end

-- Attack offset RELATIVE TO the target center, so multiple pets attacking the same thing
-- arrange around it instead of stacking on one point. `phase` (elapsed seconds) drives the
-- animation. Returns { x, y, z } to add to the target's world position. 1-based index.
-- Styles (attack.style):
--   "orbit"       — evenly spaced ring, the whole wheel rotates over time
--   "static_ring" — evenly spaced ring, no rotation
--   "lunge"       — ring slots that rhythmically jab in toward the centre
--   "spiral"      — inner→outer spiral arm that slowly rotates (a mining vortex; rises with t)
--   "pincer"      — two arcs clamping the target from opposite sides, squeezing in/out
--   "firing_line" — a row on one side facing the target, staggered recoil (a volley)
--   "swarm"       — a deterministic jitter cloud buzzing around the target
-- Resolve which attack STYLE a single pet uses.
--   COMBAT enters its own "combat mode": the player's SAVED settings (their PetAttackStyle /
--   mining-formation pick) are OVERRIDDEN, and the squad runs the per-role styles — tank plants,
--   blaster lines up, melee weaves (attack.role_styles[role], with a per-species exception). Jason:
--   "during combat all saved settings get overridden and it goes into combat mode." (We may later
--   let saved prefs drive combat too; for now combat owns it.)
--   FARMING uses the player's pick: their saved PetAttackStyle is their mining formation, falling
--   back to the team style.
-- `isCombat` picks the lane (attack.mode.combat vs attack.mode.mining). Pure.
function PetFormation.resolveStyle(attack, role, isCombat, playerOverride, speciesStyle)
    attack = attack or {}
    local modeKey = isCombat and "combat" or "mining"
    local mode = (attack.mode and attack.mode[modeKey]) or "team"
    -- Mining only: the player's saved formation pick wins (ignored in combat — see above).
    if not isCombat and playerOverride and playerOverride ~= "" then
        return playerOverride
    end
    if mode == "individual" then
        return speciesStyle
            or (attack.role_styles and attack.role_styles[role])
            or attack.style
            or "orbit"
    end
    return attack.style or "orbit"
end

function PetFormation.attackOffset(index, count, phase, attack)
    local n = math.max(count, 1)
    local i = index - 1
    local style = attack.style or "orbit"
    local height = attack.ring_height or 0
    local R = attack.ring_radius or 6

    if style == "spiral" then
        local t = (n > 1) and (i / (n - 1)) or 0 -- 0 (inner) .. 1 (outer)
        -- Spin rate lerps inner -> outer: a faster inner ring (or, if the outer speed is
        -- negative, the two rings counter-rotate) gives the vortex more life.
        local inner = tonumber(attack.spiral_inner_speed) or 0
        local outer = tonumber(attack.spiral_outer_speed) or inner
        local spin = inner + (outer - inner) * t
        local angle = t * (attack.spiral_turns or 1.5) * 2 * math.pi + phase * spin
        local radius = R * (0.35 + 0.65 * t)
        return {
            x = radius * math.cos(angle),
            y = height + (attack.spiral_rise or 0) * t,
            z = radius * math.sin(angle),
        }
    elseif style == "pincer" then
        local half = math.ceil(n / 2)
        local firstHalf = i < half
        local k = firstHalf and i or (i - half)
        local cnt = firstHalf and half or (n - half)
        local spread = (cnt > 1) and (k / (cnt - 1) - 0.5) or 0
        local angle = (firstHalf and 0 or math.pi) + spread * math.rad(attack.pincer_arc or 80)
        local squeeze = (attack.pincer_squeeze or 0)
            * (0.5 + 0.5 * math.sin(phase * (attack.pincer_speed or 0)))
        local radius = R - squeeze
        return { x = radius * math.cos(angle), y = height, z = radius * math.sin(angle) }
    elseif style == "firing_line" then
        -- a row on the -z side; pets recoil toward the target (+z) in a staggered volley
        local recoil = (attack.line_recoil or 0)
            * math.max(0, math.sin(phase * (attack.line_speed or 0) - i * 0.5))
        return {
            x = (i - (n - 1) / 2) * (attack.line_spacing or 3),
            y = height,
            z = -R + recoil,
        }
    elseif style == "swarm" then
        local sx = math.sin((i + 1) * 12.9898) -- deterministic per-pet base in [-1,1]
        local sz = math.sin((i + 1) * 78.233)
        local jx = math.sin(phase * (attack.swarm_speed or 0) + i * 2.1)
        local jz = math.cos(phase * (attack.swarm_speed or 0) + i * 1.7)
        local rad = R * (attack.swarm_radius_frac or 0.85)
        return {
            x = (sx * 0.6 + jx * 0.4) * rad,
            y = height + math.sin(phase * 4 + i) * (attack.swarm_bob or 0),
            z = (sz * 0.6 + jz * 0.4) * rad,
        }
    end

    -- ring family: orbit (rotates) / static_ring / lunge (jabs in)
    local angle = (i / n) * 2 * math.pi
    if style == "orbit" then
        angle = angle + phase * (attack.orbit_speed or 0)
    end
    local radius = R
    if style == "lunge" then
        local jab = (attack.lunge_distance or 0)
            * (0.5 + 0.5 * math.sin(phase * (attack.lunge_speed or 0) + i))
        radius = radius - jab
    end
    return { x = radius * math.cos(angle), y = height, z = radius * math.sin(angle) }
end

-- ============================================================================
-- Size-aware formations (resolve). Each pet carries a `.footprint` (studs, e.g.
-- the model's XZ extent); huge pets have a larger footprint. resolve() sorts
-- smallest -> front, scales gaps by footprint so huge pets never overlap their
-- neighbours, and lays the pets out per the selected `formation.mode`:
--   "conga"  — single file; gap between pets grows with their footprints.
--   "risers" — tiered rows; front row smallest, huge anchored in the back row
--              with extra column spacing (size-aware evolution of "rows").
--   "arc"    — concave cradle behind the player; smallest at the centre-closest,
--              huge curling back at the horns.
-- ============================================================================

-- Stable ascending sort by footprint (smallest first = front). Returns a new array.
function PetFormation.sortBySize(pets)
    local indexed = {}
    for i, p in ipairs(pets) do
        indexed[i] = { p = p, i = i, f = tonumber(p.footprint) or 0 }
    end
    table.sort(indexed, function(a, b)
        if a.f ~= b.f then
            return a.f < b.f
        end
        return a.i < b.i
    end)
    local out = {}
    for i, e in ipairs(indexed) do
        out[i] = e.p
    end
    return out
end

local function footprintList(sorted)
    local f = {}
    for i, p in ipairs(sorted) do
        f[i] = tonumber(p.footprint) or 0
    end
    return f
end

-- conga: single file; back accumulates (f[i-1]+f[i])/2 + gap so bigger pets push more space.
local function congaOffsets(f, fm)
    local size = fm.size or {}
    local gap = tonumber(size.gap) or 1.5
    local height = fm.height or 0
    local d0 = fm.follow_distance or 0
    local offs, back = {}, d0
    for i = 1, #f do
        if i == 1 then
            back = d0 + f[1] / 2
        else
            back = back + (f[i - 1] + f[i]) / 2 + gap
        end
        offs[i] = { x = 0, y = height, back = back }
    end
    return offs
end

-- risers: rows of per_row; row depth + column spacing scale with that row's largest footprint.
local function risersOffsets(f, fm)
    local r = fm.risers or {}
    local perRow = math.max(1, math.floor(tonumber(r.per_row) or 3))
    local rowGap = tonumber(r.row_gap) or 2
    local colSpacing = tonumber(r.col_spacing) or 3
    local height = fm.height or 0
    local d0 = fm.follow_distance or 0
    local n = #f
    local rows = math.max(1, math.ceil(n / perRow))

    local rowMax = {}
    for row = 0, rows - 1 do
        local mx = 0
        for c = 0, perRow - 1 do
            local idx = row * perRow + c + 1
            if f[idx] then
                mx = math.max(mx, f[idx])
            end
        end
        rowMax[row] = mx
    end

    local rowBack = {}
    rowBack[0] = d0 + (rowMax[0] or 0) / 2
    for row = 1, rows - 1 do
        rowBack[row] = rowBack[row - 1] + (rowMax[row - 1] + rowMax[row]) / 2 + rowGap
    end

    local offs = {}
    for i = 1, n do
        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local inRow = math.min(perRow, n - row * perRow)
        local center = (inRow - 1) / 2
        offs[i] = {
            x = (col - center) * (colSpacing + (rowMax[row] or 0)),
            y = height,
            back = rowBack[row],
        }
    end
    return offs
end

-- arc: concave cradle. Center-out slot assignment (smallest near centre) on a back-curving arc.
local function arcOffsets(f, fm)
    local a = fm.arc or {}
    local R = tonumber(a.radius) or 11
    local step = degToRad(tonumber(a.arc_step_degrees) or 20)
    local spread = tonumber(a.spread_factor) or 0
    local depth = tonumber(a.depth_factor) or 0
    local height = fm.height or 0
    local d0 = fm.follow_distance or 0
    local n = #f
    local offs = {}
    for i = 1, n do
        -- center-out slot assignment, kept symmetric for BOTH parities:
        --   odd count  -> a centre pet (s=0) plus mirrored pairs ±1, ±2, ...
        --   even count -> straddle the centre (no centre pet): ±0.5, ±1.5, ...
        -- smallest pet (i=1, post-sort) sits nearest the centre either way.
        local s
        if n % 2 == 1 then
            if i == 1 then
                s = 0
            else
                local k = math.floor(i / 2)
                s = (i % 2 == 0) and k or -k
            end
        else
            local mag = math.ceil(i / 2) - 0.5 -- 0.5, 0.5, 1.5, 1.5, ...
            s = (i % 2 == 1) and mag or -mag
        end
        local ang = s * step
        local sign = (s > 0 and 1) or (s < 0 and -1) or 0
        offs[i] = {
            x = R * math.sin(ang) + sign * f[i] * spread,
            y = height,
            back = d0 + R * (1 - math.cos(ang)) + math.abs(s) * f[i] * depth,
        }
    end
    return offs
end

-- Resolve a full formation: sort by size, lay out per mode. `pets` is an array of tables each
-- carrying `.footprint`. Returns an array (front -> back) of { pet = <input>, slot, offset }.
function PetFormation.resolve(pets, formation)
    local sorted = PetFormation.sortBySize(pets)
    local f = footprintList(sorted)
    local mode = formation.mode
    local offs
    if mode == "conga" then
        offs = congaOffsets(f, formation)
    elseif mode == "arc" then
        offs = arcOffsets(f, formation)
    else
        offs = risersOffsets(f, formation) -- default size-aware layout
    end
    local out = {}
    for i, p in ipairs(sorted) do
        out[i] = { pet = p, slot = i, offset = offs[i] }
    end
    return out
end

-- Convert a local offset { x, y, back } to a world position against the player frame.
-- world = position + right*x + up*y + (-look)*back
function PetFormation.toWorld(frame, offset)
    local p, look, right = frame.position, frame.look, frame.right
    return {
        x = p.x + right.x * offset.x - look.x * offset.back,
        y = p.y + offset.y - look.y * offset.back + right.y * offset.x,
        z = p.z + right.z * offset.x - look.z * offset.back,
    }
end

-- Pet move-speed multiplier: base * player * pet, clamped to [min, max]. The controller
-- multiplies the follow/attack lerp rates by this so a higher PetMoveSpeed stat (or a fast
-- unique pet's MoveSpeedMult) makes pets keep up / reposition faster. Nil inputs default to 1.
function PetFormation.moveSpeedMultiplier(playerMult, petMult, speedConfig)
    speedConfig = type(speedConfig) == "table" and speedConfig or {}
    local base = tonumber(speedConfig.base) or 1
    local p = tonumber(playerMult) or 1
    local q = tonumber(petMult) or 1
    local lo = tonumber(speedConfig.min) or 0.1
    local hi = tonumber(speedConfig.max) or 10
    local m = base * p * q
    if m < lo then
        m = lo
    end
    if m > hi then
        m = hi
    end
    return m
end

-- Catch-up safety: true when a pet is so far from its target (e.g. the player just teleported
-- across the map) that it should snap directly there instead of slowly lerping across the world.
-- `threshold` in studs; a nil threshold never snaps. Normal walking never reaches the gap.
function PetFormation.shouldSnap(distance, threshold)
    local d = tonumber(distance) or 0
    local t = tonumber(threshold)
    if not t then
        return false
    end
    return d > t
end

-- Mining gate: whether a pet that is `distance` studs from its target may mine (within `range`).
-- A nil distance (no position reported yet) or nil range returns true — the gate is graceful and
-- never blocks the legacy "near the ore = mines" behaviour; it only withholds mining for a pet
-- that has a known position still too far from the target.
function PetFormation.inMiningRange(distance, range)
    local d = tonumber(distance)
    local r = tonumber(range)
    if not d or not r then
        return true
    end
    return d <= r
end

-- Vertical bob from a phase (e.g. elapsed time). Deterministic; no clock here.
function PetFormation.floatOffset(phase, floatConfig)
    if not floatConfig or floatConfig.amplitude == 0 then
        return 0
    end
    return floatConfig.amplitude * math.sin((2 * math.pi / floatConfig.period) * phase)
end

return PetFormation
