--[[
    PackScale — pure enemy-pack sizing for teamed fights (docs/TEAMING.md).

    Static spawns are tuned for ONE player's squad; with a team engaged, waves become packs:
        count = ceil(base * min(1 + (engaged-1) * count_per_extra, max_count_mult))
    Count scaling applies only to tiers listed in cfg.pack.count_scales_tiers (bosses get
    HP scaling only — that lives in PartyMath.scaledHp, applied by the caller).
]]

local PackScale = {}

--- base: the wave's configured count; engaged: team members in the fight (>=1);
--- tier: enemy tier id or nil; cfg: configs/teaming.lua. Returns the scaled count.
function PackScale.count(base, engaged, tier, cfg)
    base = tonumber(base) or 1
    engaged = math.max(tonumber(engaged) or 1, 1)
    local pack = (cfg and cfg.pack) or {}
    local scalesTiers = pack.count_scales_tiers
    if tier ~= nil and scalesTiers and not scalesTiers[tier] then
        return base
    end
    local perExtra = tonumber(pack.count_per_extra) or 0
    local maxMult = tonumber(pack.max_count_mult) or math.huge
    local mult = math.min(1 + (engaged - 1) * perExtra, maxMult)
    return math.ceil(base * mult)
end

return PackScale
