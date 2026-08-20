--[[
    ElementResonance (pure) — Feature 6.

    Looks up the element resonance multiplier for a pet element in a realm
    alignment ("heaven" / "hell" / "neutral") from configs/elements.lua. Unknown
    element or realm defaults to 1.0 (no effect).
]]

local ElementResonance = {}

function ElementResonance.multiplier(element, realmAlignment, config)
    local resonance = config and config.resonance
    local row = resonance and resonance[element]
    if not row then
        return 1.0
    end
    return row[realmAlignment] or 1.0
end

-- Cross-realm multiplier for a PET BY ITS SPECIES REALM standing in a realm. Maps the pet's realm
-- to its alignment (heaven -> light, hell -> shadow, anything else -> neutral) then looks up the
-- resonance. ONE source of truth shared by the server damage path (PetFollowService) and the client
-- inventory card, so the displayed power == the dealt power (Jason: "the card is literally the
-- power — always show the true number").
function ElementResonance.petRealmMultiplier(petRealm, playerRealm, config)
    local alignment = (petRealm == "heaven" and "light")
        or (petRealm == "hell" and "shadow")
        or "neutral"
    return ElementResonance.multiplier(alignment, playerRealm or "neutral", config)
end

-- BIOME RPS (Jason): petElement vs the zone the player stands in.
-- advantage in the zone your element beats, disadvantage in the zone that beats
-- you, 1.0 everywhere else — including unknown/special zones (map miss = neutral).
function ElementResonance.biomeMultiplier(petElement, zoneElement, cfg)
    local biome = cfg and cfg.biome
    if type(biome) ~= "table" or type(biome.beats) ~= "table" then
        return 1
    end
    petElement = tostring(petElement or "")
    zoneElement = tostring(zoneElement or "")
    if petElement == "" or zoneElement == "" then
        return 1
    end
    local special = biome.special
    local specialRow = type(special) == "table" and special[petElement] or nil
    local specialValue = type(specialRow) == "table" and tonumber(specialRow[zoneElement]) or nil
    if specialValue then
        return specialValue
    end
    if biome.beats[petElement] == zoneElement then
        return tonumber(biome.advantage) or 1
    end
    if biome.beats[zoneElement] == petElement then
        return tonumber(biome.disadvantage) or 1
    end
    return 1
end

-- Home World enchant: preserve the ordinary biome RPS result unless the pet's rolled,
-- type-scaled enchant is better. The floor is intentionally limited to the four authored Home
-- biome ids (the keys of `biome.beats`), so Heaven/Hell and special zones retain their normal realm
-- behavior. Examples for an Exclusive pet: Copper +5%, Silver +15%, Onyx +25%.
function ElementResonance.biomeMultiplierWithFloor(petElement, zoneElement, cfg, homeWorldBonus)
    local normal = ElementResonance.biomeMultiplier(petElement, zoneElement, cfg)
    local biome = cfg and cfg.biome
    local beats = biome and biome.beats
    local bonus = math.max(0, tonumber(homeWorldBonus) or 0)
    if type(beats) ~= "table" or bonus <= 0 then
        return normal
    end
    zoneElement = tostring(zoneElement or "")
    if beats[zoneElement] == nil then
        return normal
    end
    return math.max(normal, 1 + bonus)
end

return ElementResonance
