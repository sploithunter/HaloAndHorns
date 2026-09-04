-- Compact presentation for Merge Defense costs.
--
-- Costs remain ordinary numeric Waycoin/Gem amounts. Only their labels are abbreviated. Million
-- scale is where an exact digit run stops being useful in the compact boards and management menus;
-- familiar early-game prices remain exact and comma-separated.

local MergeEggCostFormat = {}

local SUFFIXES = {
    { threshold = 1e15, suffix = "Q" },
    { threshold = 1e12, suffix = "T" },
    { threshold = 1e9, suffix = "B" },
    { threshold = 1e6, suffix = "M" },
}

local function wholeNumber(value)
    local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
    return text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function trimFraction(text)
    return text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
end

function MergeEggCostFormat.format(value)
    local amount = math.max(0, tonumber(value) or 0)
    for _, notation in ipairs(SUFFIXES) do
        if amount >= notation.threshold then
            local scaled = amount / notation.threshold
            local decimals = scaled >= 100 and 0 or (scaled >= 10 and 1 or 2)
            local text = string.format("%." .. decimals .. "f", scaled)
            return trimFraction(text) .. notation.suffix
        end
    end
    return wholeNumber(amount)
end

return MergeEggCostFormat
