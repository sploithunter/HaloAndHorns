-- Presentation-only regions: no ownership, touch events, or saved progression.
local Zones = {}

function Zones.resolve(config, coordinate, previous)
    local offset = coordinate - config.center
    local edge, margin = config.mall_half_width, config.hysteresis
    if previous == "heaven" and offset >= edge - margin then
        return "heaven"
    elseif previous == "hell" and offset <= -edge + margin then
        return "hell"
    end
    local entry = edge + (previous == "mall" and margin or 0)
    if offset >= entry then
        return "heaven"
    elseif offset <= -entry then
        return "hell"
    end
    return "mall"
end

return Zones
