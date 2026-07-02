--[[
    OnHitEffects — pure math for a pet's ON-HIT enemy effects (Halo & Horns S-tier kit).

    These are ORTHOGONAL modifiers, like the DoT/spread axes: a pet's swing can carry any of them on
    top of its hit geometry (single / targeted_aoe / aura). The combat loop applies them to each enemy
    the swing touches; this module owns only the arithmetic so it's headless-testable and the runtime
    just stamps attributes.

      • CONTROL (slow/root/hold)  -> slowSpeed: how much an enemy's move speed drops while slowed.
      • SHRED (vulnerability)     -> vulnerable: the multiplier an enemy takes from EVERYONE (team amp).
      • EXECUTE (reaper)          -> executeBonus: finishing damage on a low-HP enemy.

    Root/hold are binary (handled by the consumer as speed 0 / full mez); slow is the graded one, so
    only it needs a number here. Vulnerability composes with existing power vulnerability by keeping
    the STRONGER active mult (never weakens an enemy already shredded harder). Execute is a clean
    threshold finisher: below `threshold` of max HP, deal the rest.

      OnHitEffects.slowSpeed(baseSpeed, factor)               -> number
      OnHitEffects.vulnerable(curMult, curActive, addFrac)    -> number
      OnHitEffects.executeBonus(hpRemaining, maxHp, threshold)-> number (extra damage; 0 = no execute)
]]

local OnHitEffects = {}

local function clamp(x, lo, hi)
    if x < lo then
        return lo
    elseif x > hi then
        return hi
    end
    return x
end

-- Slowed move speed = base × clamp(factor, 0, 1). factor 1 = no slow, 0 = full root (the consumer
-- treats a real root via RootedUntil; this is the graded middle). Negative/garbage clamps to a stop.
function OnHitEffects.slowSpeed(baseSpeed, factor)
    local b = tonumber(baseSpeed) or 0
    local f = tonumber(factor)
    if f == nil then
        return b -- no slow configured
    end
    return b * clamp(f, 0, 1)
end

-- Vulnerability multiplier after a shred hit: enemies take ×mult from everyone. Keep the STRONGER of
-- the currently-active mult and (1 + addFrac), so a small pet shred never overwrites a big power
-- shred — and stacking the same shred just refreshes, it doesn't compound. curActive=false means no
-- live debuff (treat current as 1×). addFrac is the fraction (+0.3 = +30% damage taken).
function OnHitEffects.vulnerable(curMult, curActive, addFrac)
    local add = tonumber(addFrac) or 0
    local incoming = 1 + math.max(0, add)
    local current = (curActive and tonumber(curMult)) or 1
    return math.max(current, incoming)
end

-- Weaken multiplier after a CURSE (Hell's combat-debuff supports): a cursed enemy DEALS ×mult of its
-- damage (mult < 1 weakens). Mirror of `vulnerable` but for a REDUCING debuff, so "keep the stronger"
-- means keep the LOWER mult — a small curse never overwrites a big one, and re-cursing refreshes
-- without compounding. curActive=false means no live curse (treat current as 1×). mult is the absolute
-- factor (0.7 = enemy deals -30%), clamped to [0,1] (a curse can't buff the enemy).
function OnHitEffects.weaken(curMult, curActive, mult)
    local m = tonumber(mult) or 1
    if m < 0 then
        m = 0
    elseif m > 1 then
        m = 1
    end
    local current = (curActive and tonumber(curMult)) or 1
    return math.min(current, m)
end

-- Execute finisher: if an enemy is at or below `threshold` of its max HP (and still alive), return
-- the HP needed to drop it — an instant reap of the wounded. Returns 0 when it's above the threshold,
-- already dead, or maxHp is unknown (never executes from bad data).
function OnHitEffects.executeBonus(hpRemaining, maxHp, threshold)
    local hp = tonumber(hpRemaining) or 0
    local max = tonumber(maxHp) or 0
    local thr = tonumber(threshold) or 0
    if hp <= 0 or max <= 0 or thr <= 0 then
        return 0
    end
    if hp / max <= thr then
        return hp -- finish it
    end
    return 0
end

return OnHitEffects
