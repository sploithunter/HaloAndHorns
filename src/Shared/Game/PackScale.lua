--[[
    PackScale — pure enemy-pack sizing for teamed fights and player-selected density
    (docs/TEAMING.md, docs/MISSION_WORLDGEN.md).

    Static spawns are tuned for ONE player's squad; with a team engaged, waves become packs:
        count = ceil(base * min(1 + (engaged-1) * count_per_extra, max_count_mult))
    Count scaling applies only to tiers listed in cfg.pack.count_scales_tiers (bosses get
    HP scaling only — that lives in PartyMath.scaledHp, applied by the caller).
]]

local PackScale = {}

local function scaleRules(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local minValue = tonumber(cfg.min) or 1
    local maxValue = math.max(minValue, tonumber(cfg.max) or minValue)
    local defaultValue = math.clamp(tonumber(cfg.default) or 1, minValue, maxValue)
    local step = math.max(0, tonumber(cfg.step) or 0)
    return {
        min = minValue,
        max = maxValue,
        default = defaultValue,
        step = step,
    }
end

--- Return normalized UI/server rules for a configured multiplier.
function PackScale.rules(cfg)
    return scaleRules(cfg)
end

--- Sanitize either a raw multiplier or a network payload against config-owned rules.
function PackScale.sanitizeMultiplier(value, cfg)
    if type(value) == "table" then
        value = value.scale or value.value or value.multiplier
    end
    local rules = scaleRules(cfg)
    local result = math.clamp(tonumber(value) or rules.default, rules.min, rules.max)
    if rules.step > 0 then
        result = math.floor(result / rules.step + 0.5) * rules.step
        result = math.floor(result * 1000000 + 0.5) / 1000000
        result = math.clamp(result, rules.min, rules.max)
    end
    return result
end

--- Automatic team-size multiplier. Accepts both configs/teaming.lua's pack shape and
--- configs/missions.lua's team_scaling shape so all pack consumers share one formula.
function PackScale.teamMultiplier(engaged, cfg)
    engaged = math.max(tonumber(engaged) or 1, 1)
    cfg = type(cfg) == "table" and cfg or {}
    local perExtra = tonumber(cfg.count_per_extra_member) or tonumber(cfg.count_per_extra) or 0
    local maxMult = tonumber(cfg.max_mult) or tonumber(cfg.max_count_mult) or math.huge
    return math.min(1 + (engaged - 1) * perExtra, maxMult)
end

--- base: the wave's configured count; engaged: team members in the fight (>=1);
--- tier: enemy tier id or nil; cfg: configs/teaming.lua. Returns the scaled count.
function PackScale.count(base, engaged, tier, cfg)
    base = tonumber(base) or 1
    local pack = (cfg and cfg.pack) or {}
    local scalesTiers = pack.count_scales_tiers
    if tier ~= nil and scalesTiers and not scalesTiers[tier] then
        return base
    end
    local mult = PackScale.teamMultiplier(engaged, pack)
    return math.ceil(base * mult)
end

return PackScale
