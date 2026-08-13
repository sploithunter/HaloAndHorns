--[[
    PromoCodeLogic — pure rules for public reward-code redemption.

    Codes are intentionally case-insensitive and whitespace-tolerant at the input boundary, but
    definitions use one canonical uppercase spelling. The stable config key (not the public code)
    is the durable claim/analytics identity, so an alias or copy change cannot mint a second reward.
]]

local PromoCodeLogic = {}

local CODE_PATTERN = "^[A-Z0-9_-]+$"
local ID_PATTERN = "^[a-z][a-z0-9_]*$"

local function isInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

local function isArray(value)
    if type(value) ~= "table" then
        return false
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count += 1
    end
    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end
    return true
end

local function percentDecode(value)
    value = tostring(value or ""):gsub("%+", " ")
    return (
        value:gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
    )
end

function PromoCodeLogic.normalize(raw, limits)
    if type(raw) ~= "string" then
        return nil
    end
    limits = type(limits) == "table" and limits or {}
    local minimum = tonumber(limits.min_length) or 3
    local maximum = tonumber(limits.max_length) or 32
    local normalized = raw:upper():gsub("%s+", "")
    if #normalized < minimum or #normalized > maximum or not normalized:match(CODE_PATTERN) then
        return nil
    end
    return normalized
end

-- Roblox LaunchData may be a plain code or a query-string payload such as
-- `code=KADE&source=x`. Only the code/promo field is consumed; no arbitrary URL data is stored.
function PromoCodeLogic.extractLaunchCode(raw, limits)
    if type(raw) ~= "string" or raw == "" then
        return nil
    end
    for segment in raw:gmatch("[^&]+") do
        local key, value = segment:match("^([^=]+)=(.*)$")
        key = key and percentDecode(key):lower() or nil
        if key == "code" or key == "promo" then
            return PromoCodeLogic.normalize(percentDecode(value), limits)
        end
    end
    return PromoCodeLogic.normalize(percentDecode(raw), limits)
end

function PromoCodeLogic.find(config, normalizedCode)
    if type(config) ~= "table" or type(config.codes) ~= "table" then
        return nil
    end
    normalizedCode = PromoCodeLogic.normalize(normalizedCode, config.input)
    if not normalizedCode then
        return nil
    end
    for id, definition in pairs(config.codes) do
        if PromoCodeLogic.normalize(definition.code, config.input) == normalizedCode then
            return id, definition
        end
        for _, alias in ipairs(definition.aliases or {}) do
            if PromoCodeLogic.normalize(alias, config.input) == normalizedCode then
                return id, definition
            end
        end
    end
    return nil
end

function PromoCodeLogic.evaluate(definition, context)
    definition = type(definition) == "table" and definition or {}
    context = type(context) == "table" and context or {}
    if definition.enabled == false then
        return false, "disabled"
    end
    if definition.studio_only == true and context.isStudio ~= true then
        return false, "invalid"
    end
    local now = tonumber(context.now) or 0
    if tonumber(definition.starts_at) and now < definition.starts_at then
        return false, "not_started"
    end
    if tonumber(definition.ends_at) and now >= definition.ends_at then
        return false, "expired"
    end
    if (tonumber(context.level) or 1) < (tonumber(definition.minimum_level) or 1) then
        return false, "level_required"
    end
    if (tonumber(context.claimedCount) or 0) >= (tonumber(definition.per_player_limit) or 1) then
        return false, "already_claimed"
    end
    return true, "ok"
end

local function hasReward(reward)
    if type(reward) ~= "table" then
        return false
    end
    if (tonumber(reward.experience) or 0) > 0 then
        return true
    end
    for _, field in ipairs({ "currencies", "pets", "items", "effects", "titles", "slots" }) do
        if type(reward[field]) == "table" and next(reward[field]) ~= nil then
            return true
        end
    end
    return false
end

function PromoCodeLogic.validate(config)
    if type(config) ~= "table" then
        return false, "expected table"
    end
    if not isInteger(config.version) or config.version < 1 then
        return false, "version must be a positive integer"
    end
    if config.enabled ~= nil and type(config.enabled) ~= "boolean" then
        return false, "enabled must be boolean"
    end
    if type(config.codes) ~= "table" then
        return false, "codes must be a table"
    end

    local seen = {}
    for id, definition in pairs(config.codes) do
        local path = "codes." .. tostring(id)
        if type(id) ~= "string" or not id:match(ID_PATTERN) then
            return false, path .. " must use a stable lowercase id"
        end
        if type(definition) ~= "table" then
            return false, path .. " must be a table"
        end
        local canonical = PromoCodeLogic.normalize(definition.code, config.input)
        if canonical == nil or canonical ~= definition.code then
            return false, path .. ".code must be canonical uppercase letters/numbers/_/-"
        end
        if seen[canonical] then
            return false, path .. ".code duplicates " .. seen[canonical]
        end
        seen[canonical] = path .. ".code"
        if definition.aliases ~= nil and not isArray(definition.aliases) then
            return false, path .. ".aliases must be an array"
        end
        for index, alias in ipairs(definition.aliases or {}) do
            local normalized = PromoCodeLogic.normalize(alias, config.input)
            if normalized == nil or normalized ~= alias then
                return false, path .. ".aliases[" .. index .. "] must be canonical uppercase"
            end
            if seen[normalized] then
                return false, path .. ".aliases[" .. index .. "] duplicates " .. seen[normalized]
            end
            seen[normalized] = path .. ".aliases[" .. index .. "]"
        end
        if definition.enabled ~= nil and type(definition.enabled) ~= "boolean" then
            return false, path .. ".enabled must be boolean"
        end
        if definition.studio_only ~= nil and type(definition.studio_only) ~= "boolean" then
            return false, path .. ".studio_only must be boolean"
        end
        if
            definition.minimum_level ~= nil
            and (not isInteger(definition.minimum_level) or definition.minimum_level < 1)
        then
            return false, path .. ".minimum_level must be a positive integer"
        end
        if
            definition.per_player_limit ~= nil
            and (not isInteger(definition.per_player_limit) or definition.per_player_limit < 1)
        then
            return false, path .. ".per_player_limit must be a positive integer"
        end
        if definition.starts_at ~= nil and type(definition.starts_at) ~= "number" then
            return false, path .. ".starts_at must be a Unix timestamp"
        end
        if definition.ends_at ~= nil and type(definition.ends_at) ~= "number" then
            return false, path .. ".ends_at must be a Unix timestamp"
        end
        if
            definition.starts_at ~= nil
            and definition.ends_at ~= nil
            and definition.ends_at <= definition.starts_at
        then
            return false, path .. ".ends_at must be after starts_at"
        end
        if definition.campaign ~= nil and type(definition.campaign) ~= "string" then
            return false, path .. ".campaign must be a string"
        end
        if definition.success_message ~= nil and type(definition.success_message) ~= "string" then
            return false, path .. ".success_message must be a string"
        end
        if not hasReward(definition.reward) then
            return false, path .. ".reward must contain at least one reward"
        end
    end
    return true
end

return PromoCodeLogic
