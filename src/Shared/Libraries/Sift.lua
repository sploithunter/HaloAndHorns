-- Basic Sift implementation for array and dictionary utilities
local Sift = {}

-- Array utilities
function Sift.Array.filter(array, predicate)
    local result = {}
    for i, value in ipairs(array) do
        if predicate(value, i) then
            table.insert(result, value)
        end
    end
    return result
end

function Sift.Array.map(array, mapper)
    local result = {}
    for i, value in ipairs(array) do
        result[i] = mapper(value, i)
    end
    return result
end

function Sift.Array.find(array, predicate)
    for i, value in ipairs(array) do
        if predicate(value, i) then
            return value, i
        end
    end
    return nil
end

-- Dictionary utilities
function Sift.Dictionary.filter(dict, predicate)
    local result = {}
    for key, value in pairs(dict) do
        if predicate(value, key) then
            result[key] = value
        end
    end
    return result
end

function Sift.Dictionary.map(dict, mapper)
    local result = {}
    for key, value in pairs(dict) do
        result[key] = mapper(value, key)
    end
    return result
end

-- Initialize sub-modules
Sift.Array = Sift.Array or {}
Sift.Dictionary = Sift.Dictionary or {}

return Sift
