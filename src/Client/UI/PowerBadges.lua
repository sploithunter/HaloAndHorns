--[[
    PowerBadges — the ONE place that answers "which power badges are active on this entity right now?"

    Every badge surface (world-overhead billboards, HUD card, enemy nameplate) should read from here so a
    power can never display on one surface and be missed on another (the recurring bug class). A power's
    badge is "active" iff a timestamp source for it is in the FUTURE. Sources, deduped by power id:

      • the GENERIC set: every `Power_<id>_Until` attribute the server stamps (PowerService:_stampPowerBadge)
        — supports MULTIPLE simultaneous powers on one entity (e.g. blind + root).
      • the legacy single-value CHANNELS every power already sets, so existing powers work with no migration:
          DebuffPowerId + DebuffUntil           (enemy debuffs: vulnerable / root / blind / hold / …)
          CombatShieldPowerId + CombatShieldUntil (pet shield AND dodge — dodge sets the channel w/o a pool)
          DefenseBuffPowerId + DefenseBuffUntil   (pet armor / defense)

    The art SSOT is PetBadge.forPower(id) — one badge per power id, identical everywhere. This module only
    decides WHICH ids are live; the caller renders them.
]]

local PowerBadges = {}

-- legacy (powerId, untilAttr) pairs that already exist on entities today
local CHANNELS = {
    { idAttr = "DebuffPowerId", untilAttr = "DebuffUntil" },
    { idAttr = "CombatShieldPowerId", untilAttr = "CombatShieldUntil" },
    { idAttr = "DefenseBuffPowerId", untilAttr = "DefenseBuffUntil" },
}

-- Returns a deduped list { { powerId = <id>, untilT = <n> }, … } of powers whose badge is live on
-- `entity` at `now` (os.time()). Empty when nothing is active.
function PowerBadges.active(entity, now)
    if not entity then
        return {}
    end
    now = now or os.time()
    local seen, out = {}, {}
    local function add(id, t)
        t = tonumber(t)
        if id and id ~= "" and t and t > now and not seen[id] then
            seen[id] = true
            out[#out + 1] = { powerId = id, untilT = t }
        end
    end
    -- generic Power_<id>_Until set (multi-badge capable)
    local ok, attrs = pcall(function()
        return entity:GetAttributes()
    end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            local id = tostring(k):match("^Power_(.+)_Until$")
            if id then
                add(id, v)
            end
        end
    end
    -- legacy single-value channels (cover every current power without a server migration)
    for _, ch in ipairs(CHANNELS) do
        add(entity:GetAttribute(ch.idAttr), entity:GetAttribute(ch.untilAttr))
    end
    return out
end

-- The latest expiry across all active powers (for a single-timer self-expire), or 0 if none.
function PowerBadges.maxUntil(entity, now)
    local latest = 0
    for _, p in ipairs(PowerBadges.active(entity, now)) do
        if p.untilT > latest then
            latest = p.untilT
        end
    end
    return latest
end

return PowerBadges
