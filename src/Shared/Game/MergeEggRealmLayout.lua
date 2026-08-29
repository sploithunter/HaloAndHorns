--[[
    MergeEggRealmLayout -- pure geometry/occupancy policy for the Merge Defense realm.

    Five raised Heaven bays face five raised Hell bays across a broad sunken public mall. The
    returned descriptors contain no Instances so layout, allocation, and future place extraction
    remain testable without Studio.
]]

local MergeEggRealmLayout = {}

local function positive(value, fallback)
    return math.max(1, tonumber(value) or fallback)
end

function MergeEggRealmLayout.bays(config)
    config = type(config) == "table" and config or {}
    local perSide = math.max(1, math.floor(tonumber(config.bays_per_side) or 5))
    local pitch = positive(config.bay_pitch, 136)
    local depth = positive(config.bay_depth, 300)
    local gap = positive(config.corridor_gap, 180)
    local centerX = tonumber(config.center_x) or -16000
    local centerZ = tonumber(config.center_z) or -325
    local middle = (perSide + 1) * 0.5
    local result = {}

    for _, side in ipairs({ "heaven", "hell" }) do
        local direction = side == "heaven" and 1 or -1
        for column = 1, perSide do
            local id = string.format("%s_%02d", side, column)
            result[#result + 1] = {
                id = id,
                side = side,
                column = column,
                index = #result + 1,
                centerX = centerX + (column - middle) * pitch,
                centerZ = centerZ + direction * (gap * 0.5 + depth * 0.5),
                yawDegrees = side == "heaven" and 0 or 180,
                displayName = string.format(
                    "%s Bay %d",
                    side == "heaven" and "Heaven" or "Hell",
                    column
                ),
            }
        end
    end
    return result
end

function MergeEggRealmLayout.byId(config, bayId)
    for _, bay in ipairs(MergeEggRealmLayout.bays(config)) do
        if bay.id == bayId then
            return bay
        end
    end
    return nil
end

-- `roll` is injectable for deterministic tests and is expected in [0, 1].
function MergeEggRealmLayout.pickAvailable(config, occupied, roll)
    occupied = type(occupied) == "table" and occupied or {}
    local available = {}
    for _, bay in ipairs(MergeEggRealmLayout.bays(config)) do
        if occupied[bay.id] == nil and occupied[bay.index] == nil then
            available[#available + 1] = bay
        end
    end
    if #available == 0 then
        return nil
    end
    local sample = math.clamp(tonumber(roll) or 0, 0, 0.999999)
    return available[math.floor(sample * #available) + 1]
end

return MergeEggRealmLayout
