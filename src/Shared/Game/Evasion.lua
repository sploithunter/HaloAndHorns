--[[
    Evasion — PURE math for TRUE avoidance (the third defensive pillar).

    Shield = an absorb POOL that depletes (soaks damage). Armor = % MITIGATION on every hit that lands
    (never depletes). Evasion is neither: a CHANCE to avoid the hit ENTIRELY — take zero — rolled per
    incoming hit while the buff is up. High-variance: brilliant against a swarm of small hits (each can
    whiff), a coin-flip against one big one. The City of Heroes "Defense" pillar.

    This module is the arithmetic only (Roblox-free, headless-testable). The roll itself (math.random)
    lives in EnemyService; this decides the clamped chance + the avoid/hit verdict for a given roll.

    Run: mise run test-headless
]]

local Evasion = {}

-- Never 100%: a sliver always lands, so no buff confers permanent immunity. Tunable.
Evasion.DEFAULT_MAX = 0.95

-- Clamp a raw avoidance chance (base magnitude × any potency boost) to [0, cap]. cap defaults to
-- DEFAULT_MAX so even fully-slotted evasion leaves a gap.
function Evasion.chance(raw, cap)
    local c = tonumber(raw) or 0
    local maxc = tonumber(cap) or Evasion.DEFAULT_MAX
    if c < 0 then
        c = 0
    elseif c > maxc then
        c = maxc
    end
    return c
end

-- Did this hit get avoided? `roll` is a uniform [0,1) sample (math.random()). Avoided iff
-- roll < clampedChance. (roll defaults to 1 → never avoid, the safe/no-buff case.)
function Evasion.evaded(rawChance, roll, cap)
    return (tonumber(roll) or 1) < Evasion.chance(rawChance, cap)
end

return Evasion
