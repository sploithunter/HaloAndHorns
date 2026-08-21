--[[
    BreakableDensity — turn an authored field area into a target population.

    Count = round(area_studs² / 1000 * targets_per_1000_studs), then clamp.
    Worlds author the density; live geometry supplies the area so a 304-stud
    cap field and a 79×111 playfield stay equally populated.
]]

local BreakableDensity = {}

function BreakableDensity.count(area, perThousand, opts)
    opts = type(opts) == "table" and opts or {}
    local studs = math.max(0, tonumber(area) or 0)
    local density = math.max(0, tonumber(perThousand) or 0)
    local count = math.floor(studs / 1000 * density + 0.5)
    local minCount = math.max(1, math.floor(tonumber(opts.min) or 1))
    local ceiling = tonumber(opts.max)
    if count < minCount then
        count = minCount
    end
    if ceiling and count > ceiling then
        count = math.floor(ceiling)
    end
    return count
end

return BreakableDensity
