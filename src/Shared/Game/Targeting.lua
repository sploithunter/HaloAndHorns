--[[
    Targeting — pure functional core for combat target selection (Feature 10).

    No Roblox APIs. Positions are plain { x, y, z } tables. Enemies are plain
    records: { id, position, hp }. Self-contained (no module requires) so it runs
    headlessly; the service feeds it live positions/hp.

      nearestEnemy(from, enemies)  -> enemy record (lowest distance, hp > 0) or nil
      livingEnemies(enemies)       -> array of enemies with hp > 0
]]

local Targeting = {}

local function distanceSq(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

function Targeting.livingEnemies(enemies)
    local out = {}
    for _, e in ipairs(enemies) do
        if (e.hp or 0) > 0 then
            table.insert(out, e)
        end
    end
    return out
end

-- Nearest living enemy to `from`. Ties resolve to the earlier index (stable).
function Targeting.nearestEnemy(from, enemies)
    local best, bestDist = nil, nil
    for _, e in ipairs(enemies) do
        if (e.hp or 0) > 0 and e.position then
            local d = distanceSq(from, e.position)
            if bestDist == nil or d < bestDist then
                best, bestDist = e, d
            end
        end
    end
    return best
end

return Targeting
