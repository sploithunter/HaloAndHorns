--[[
    Validators (pure)

    Reusable argument validation for command specs. A command's `validate`
    delegates to Validators.fields(args, spec), keeping per-command boilerplate
    tiny and the rules headless-testable.

    A spec maps field → rule. A rule is either a type string ("string", "int",
    "number", "boolean") or a table:
        { type = "int", min = 1, max = 99, optional = true, oneOf = {...} }

    Returns (true) on success, or (false, message) on the first failing field.

    Purity contract: standard Lua only. Tested via `mise run test-headless`.
]]

local Validators = {}

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

local function checkRule(field, value, rule)
    local ruleType, min, max, optional, oneOf
    if type(rule) == "string" then
        ruleType = rule
    elseif type(rule) == "table" then
        ruleType, min, max, optional, oneOf =
            rule.type, rule.min, rule.max, rule.optional, rule.oneOf
    else
        return false, `invalid rule for "{field}"`
    end

    if value == nil then
        if optional then
            return true
        end
        return false, `missing required field "{field}"`
    end

    if ruleType == "string" then
        if type(value) ~= "string" then
            return false, `"{field}" must be a string`
        end
        if min and #value < min then
            return false, `"{field}" must be at least {min} characters`
        end
        if oneOf and not contains(oneOf, value) then
            return false, `"{field}" must be one of: {table.concat(oneOf, ", ")}`
        end
    elseif ruleType == "int" then
        if type(value) ~= "number" or value ~= math.floor(value) then
            return false, `"{field}" must be an integer`
        end
        if min and value < min then
            return false, `"{field}" must be >= {min}`
        end
        if max and value > max then
            return false, `"{field}" must be <= {max}`
        end
    elseif ruleType == "number" then
        if type(value) ~= "number" then
            return false, `"{field}" must be a number`
        end
        if min and value < min then
            return false, `"{field}" must be >= {min}`
        end
        if max and value > max then
            return false, `"{field}" must be <= {max}`
        end
    elseif ruleType == "boolean" then
        if type(value) ~= "boolean" then
            return false, `"{field}" must be a boolean`
        end
    elseif ruleType == "table" then
        if type(value) ~= "table" then
            return false, `"{field}" must be a table`
        end
    else
        return false, `unknown rule type "{tostring(ruleType)}" for "{field}"`
    end

    return true
end

-- Validate every field in `spec` against `args`. Returns (ok, errMessage).
function Validators.fields(args, spec)
    if type(args) ~= "table" then
        return false, "arguments must be a table"
    end
    for field, rule in pairs(spec) do
        local ok, err = checkRule(field, args[field], rule)
        if not ok then
            return false, err
        end
    end
    return true
end

-- Convenience single-value checks (return booleans), handy in handler bodies.
function Validators.isString(value)
    return type(value) == "string"
end

function Validators.isInt(value)
    return type(value) == "number" and value == math.floor(value)
end

return Validators
