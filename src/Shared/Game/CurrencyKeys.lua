--[[
    CurrencyKeys — normalize a profile's Currencies map to canonical (lowercase) keys.

    Legacy saves can carry case-variant duplicates of the same currency: e.g. a leftover "Gems"
    from before the lowercase rename, frozen at its rename-time value (80), sitting alongside the
    live canonical "gems" (which credits actually write, climbing to 820+). The duplicate is
    invisible to normal credit (every writer uses the lowercase id) but it:
      • trips the DataService currency watchdog, which connects a listener for WHATEVER keys exist
        at load — it latches onto "Gems"=80 and then screams "changed externally" forever, and
      • can resurface anywhere that iterates raw Currencies keys.

    normalize() collapses every key to lowercase, MERGING duplicates by MAX so the real (largest)
    balance always wins — currency is never lost and never double-counted (summing would gift the
    stale snapshot's value). Pure + deterministic; the load path saves the deduped result so the
    legacy key is gone for good after one session.
]]

local CurrencyKeys = {}

-- normalize(currencies) -> new table with lowercase keys; case/duplicate variants merged by max.
function CurrencyKeys.normalize(currencies)
    local out = {}
    if type(currencies) ~= "table" then
        return out
    end
    for key, value in pairs(currencies) do
        local canon = tostring(key):lower()
        out[canon] = math.max(tonumber(out[canon]) or 0, tonumber(value) or 0)
    end
    return out
end

return CurrencyKeys
