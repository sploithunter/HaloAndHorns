-- Pure, seekable timeline. No frame-integrated particles or tweens: edits can
-- reshape a paused cast and seeking backward produces the same geometry.
local Timeline = {}

function Timeline.duration(p)
    return p.anticipation + p.stagger + p.rise + p.hold + p.fade
end

function Timeline.random(seed, index, channel)
    local n = math.sin(seed * 12.9898 + index * 78.233 + channel * 37.719) * 43758.5453
    return n - math.floor(n)
end

function Timeline.crystal(p, time, fraction)
    local age = time - p.anticipation - p.stagger * fraction
    local growth = math.clamp(age / p.rise, 0, 1)
    growth = 1 - (1 - growth) ^ 3
    local fade = math.clamp((age - p.rise - p.hold) / p.fade, 0, 1)
    return growth, fade
end

function Timeline.validate(p, schema)
    if type(p) ~= "table" or p.version ~= schema.version then
        return false, "Unsupported preset version"
    end
    local allowed = { version = true }
    for _, field in ipairs(schema.numbers) do
        allowed[field.key] = true
        local value = p[field.key]
        if type(value) ~= "number" or value ~= value or value < field.min or value > field.max then
            return false, "Invalid " .. field.key
        end
        if field.step == 1 and value % 1 ~= 0 then
            return false, "Expected integer " .. field.key
        end
    end
    for _, field in ipairs(schema.colors) do
        allowed[field.key] = true
        local rgb = p[field.key]
        if type(rgb) ~= "table" or #rgb ~= 3 then
            return false, "Invalid " .. field.key
        end
        for key, value in pairs(rgb) do
            if
                type(key) ~= "number"
                or key % 1 ~= 0
                or key < 1
                or key > 3
                or type(value) ~= "number"
                or value ~= value
                or value < 0
                or value > 255
                or value % 1 ~= 0
            then
                return false, "Invalid RGB " .. field.key
            end
        end
    end
    for key in pairs(p) do
        if not allowed[key] then
            return false, "Unknown preset key " .. tostring(key)
        end
    end
    return true
end

return Timeline
