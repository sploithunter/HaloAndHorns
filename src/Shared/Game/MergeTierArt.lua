-- Pure resolver for the config-owned merge tier art registry. Asset ids live in
-- configs/merge_tier_art.lua; this module only provides deterministic lookup.

local MergeTierArt = {}

function MergeTierArt.entry(config, kind, family, tier)
    config = type(config) == "table" and config or {}
    local registry = if kind == "cannon" then config.cannons else config.bulwarks
    local tiers = if type(registry) == "table"
        then registry[string.lower(tostring(family or ""))]
        else nil
    local resolvedTier = math.clamp(math.floor(tonumber(tier) or 1), 1, 4)
    return type(tiers) == "table" and tiers[resolvedTier] or nil
end

function MergeTierArt.previewAssetIds(config, kind, family)
    local field = if kind == "cannon" then "modelAssetId" else "previewDecalId"
    local ids = {}
    for tier = 1, 4 do
        local value = MergeTierArt.entry(config, kind, family, tier)
        assert(value ~= nil, string.format("Missing merge tier art: %s.%s[%d]", kind, family, tier))
        ids[tier] = value[field]
        assert(
            ids[tier] ~= nil,
            string.format("Missing merge tier preview: %s.%s[%d]", kind, family, tier)
        )
    end
    return ids
end

return MergeTierArt
