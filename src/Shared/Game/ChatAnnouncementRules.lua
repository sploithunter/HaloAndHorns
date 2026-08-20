--[[
    Pure rules and copy for server-authored chat announcements.

    This module never calls Roblox services, so the rarity threshold, scope, pet naming,
    and sidekick-only team rule stay headless-testable.
]]

local ChatAnnouncementRules = {}

local DEFAULT_LEVEL_PREFIXES = { "Grats", "Congratulations", "GG" }

local DEFAULT_RARITY_ORDER = {
    "common",
    "uncommon",
    "rare",
    "epic",
    "legendary",
    "mythic",
    "secret",
    "exclusive",
    "huge",
}

local function rankMap(petsConfig)
    local ranks = {}
    for rank, rarityId in ipairs((petsConfig and petsConfig.rarity_order) or DEFAULT_RARITY_ORDER) do
        ranks[rarityId] = rank
    end
    return ranks
end

local function boundedString(value, fallback)
    if type(value) ~= "string" or value == "" then
        return fallback
    end
    return value
end

local function colorHex(color)
    if color == nil then
        return "#FFFFFF"
    end
    local red = tonumber(color.R or color.r)
    local green = tonumber(color.G or color.g)
    local blue = tonumber(color.B or color.b)
    if not red or not green or not blue then
        return "#FFFFFF"
    end
    return string.format(
        "#%02X%02X%02X",
        math.clamp(math.floor(red * 255 + 0.5), 0, 255),
        math.clamp(math.floor(green * 255 + 0.5), 0, 255),
        math.clamp(math.floor(blue * 255 + 0.5), 0, 255)
    )
end

local function effectiveRarityId(result, petsConfig)
    if result.huge == true or result.creator == true then
        return "huge"
    end
    local rarityId = result.RarityId or result.rarityId
    if rarityId == "creator" then
        return "huge"
    end
    if rarityId then
        return rarityId
    end

    -- Some inventory-held egg hatches intentionally return a compact payload with only the pet
    -- id, variant, and Huge flag. Recover the normal effective rarity from the authoritative pet
    -- family so an Exclusive cannot silently fall below the public-announcement threshold.
    local petId = result.Pet or result.pet
    local family = petsConfig and petsConfig.pets and petsConfig.pets[petId]
    return family and (family.rarity_id or family.rarity or family.category)
end

local function petName(petsConfig, result)
    local petId = result.Pet or result.pet
    local variantId = result.Type or result.variant or "basic"
    local family = petsConfig and petsConfig.pets and petsConfig.pets[petId]
    local familyName =
        boundedString(family and (family.display_name or family.name), boundedString(petId, "Pet"))

    local modifiers = {}
    local rarityId = effectiveRarityId(result, petsConfig)
    if rarityId == "huge" or rarityId == "creator" then
        modifiers[#modifiers + 1] = "Huge"
    end
    if variantId ~= "basic" then
        local variant = petsConfig and petsConfig.variants and petsConfig.variants[variantId]
        modifiers[#modifiers + 1] =
            boundedString(variant and variant.name, variantId:gsub("^%l", string.upper))
    end
    modifiers[#modifiers + 1] = familyName
    return table.concat(modifiers, " ")
end

function ChatAnnouncementRules.hatch(playerName, result, petsConfig, announcementConfig)
    result = result or {}
    local hatchConfig = announcementConfig and announcementConfig.hatch or {}
    local rarityId = effectiveRarityId(result, petsConfig)

    local ranks = rankMap(petsConfig)
    local minimum = hatchConfig.minimum_rarity or "mythic"
    if not rarityId or not ranks[rarityId] or not ranks[minimum] then
        return nil
    end
    if ranks[rarityId] < ranks[minimum] then
        return nil
    end

    local rarity = petsConfig and petsConfig.rarities and petsConfig.rarities[rarityId] or {}
    local rarityName = boundedString(rarity.name, rarityId:gsub("^%l", string.upper))
    local displayName = boundedString(playerName, "A player")
    local hatchedPet = petName(petsConfig, result)
    local globalRarity = hatchConfig.global_rarity or "huge"
    local isGlobal = rarityId == globalRarity

    local text
    if isGlobal then
        text = ("🌎 HUGE HATCH! %s hatched a %s!"):format(displayName, hatchedPet)
    else
        local article = rarityName:match("^[AEIOUaeiou]") and "an" or "a"
        text = ("✨ %s hatched %s %s %s!"):format(displayName, article, rarityName, hatchedPet)
    end

    return {
        kind = "hatch",
        scope = isGlobal and "global" or "server",
        rarityId = rarityId,
        colorHex = colorHex(rarity.color),
        text = text,
    }
end

function ChatAnnouncementRules.teamSidekick(
    joiningName,
    leadName,
    earnedLevel,
    effectiveLevel,
    announcementConfig
)
    local own = math.max(1, math.floor(tonumber(earnedLevel) or 1))
    local effective = math.max(1, math.floor(tonumber(effectiveLevel) or own))
    if effective <= own then
        return nil
    end
    return {
        kind = "team",
        scope = "server",
        colorHex = (
            announcementConfig
            and announcementConfig.team
            and announcementConfig.team.color_hex
        ) or "#62D8FF",
        text = ("🤝 %s joined %s — playing at level %d."):format(
            boundedString(joiningName, "A player"),
            boundedString(leadName, "their team leader"),
            effective
        ),
    }
end

function ChatAnnouncementRules.levelUp(playerName, level, announcementConfig, prefixIndex)
    local numericLevel = math.max(1, math.floor(tonumber(level) or 1))
    local levelConfig = announcementConfig and announcementConfig.level_up or {}
    local prefixes = type(levelConfig.prefixes) == "table" and levelConfig.prefixes
        or DEFAULT_LEVEL_PREFIXES
    if #prefixes == 0 then
        prefixes = DEFAULT_LEVEL_PREFIXES
    end
    local index = math.clamp(math.floor(tonumber(prefixIndex) or 1), 1, #prefixes)
    local prefix = boundedString(prefixes[index], DEFAULT_LEVEL_PREFIXES[1])
    return {
        kind = "level_up",
        scope = "server",
        colorHex = levelConfig.color_hex or "#FFD95A",
        text = ("🎉 %s to %s on making level %d!"):format(
            prefix,
            boundedString(playerName, "A player"),
            numericLevel
        ),
    }
end

function ChatAnnouncementRules.creatorLuck(playerName, multiplier, announcementConfig)
    local luckConfig = announcementConfig and announcementConfig.creator_luck or {}
    local activeMultiplier = math.max(1, tonumber(multiplier) or 2)
    return {
        kind = "creator_luck",
        scope = "server",
        colorHex = luckConfig.color_hex or "#AA5AFF",
        text = ("🍀 %s joined! Hatch luck is now %gx!!!"):format(
            boundedString(playerName, "A creator"),
            activeMultiplier
        ),
    }
end

function ChatAnnouncementRules.foundersLegacy(playerName, multiplier, announcementConfig)
    local legacyConfig = announcementConfig and announcementConfig.founders_legacy or {}
    local activeMultiplier = math.max(1, tonumber(multiplier) or 1.5)
    return {
        kind = "founders_legacy",
        scope = "server",
        colorHex = legacyConfig.color_hex or "#FFC637",
        text = ("👑 %s entered with Founder's Legacy! A %gx hatch-luck aura is active!"):format(
            boundedString(playerName, "A Founder"),
            activeMultiplier
        ),
    }
end

return ChatAnnouncementRules
