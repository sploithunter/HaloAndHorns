--[[
    MissionSeed — seed derivation + deterministic PRNG for mission worldgen.

    PURE: no Roblox APIs. Determinism must hold across server, client, and the
    headless (lune) test runner, so randomness comes from our own mulberry32
    stream, NOT Random.new — Roblox's RNG is an implementation detail we don't
    want the map contract depending on.

    Seed scheme (docs/MISSION_WORLDGEN.md §3):
        seed       = fnv1a32(worldgenVersion .. "|" .. missionId .. "|" .. contextKey)
        streamSeed = fnv1a32(seed .. "|" .. phaseName)      -- "layout" | "decor" | "spawns"

    Per-phase streams are isolated: consuming extra draws in one phase can
    never shift another. `worldgenVersion` is folded in so a solver algorithm
    change deliberately invalidates old seeds instead of silently drifting.
]]

local MissionSeed = {}

local MOD32 = 4294967296 -- 2^32

-- (a * b) mod 2^32 without exceeding double-precision integer range.
-- Split both operands into 16-bit halves; the ahi*bhi term is ≡ 0 mod 2^32.
local function mul32(a, b)
    local alo = a % 65536
    local ahi = (a - alo) / 65536
    local blo = b % 65536
    local bhi = (b - blo) / 65536
    local mid = (ahi * blo + alo * bhi) % 65536
    return (mid * 65536 + alo * blo) % MOD32
end

-- FNV-1a 32-bit over a string. Stable, cheap, good dispersion for short keys.
function MissionSeed.fnv1a32(str)
    local hash = 2166136261
    for i = 1, #str do
        hash = bit32.bxor(hash, string.byte(str, i))
        hash = mul32(hash, 16777619)
    end
    return hash
end

-- Top-level mission seed. All inputs are folded as strings so callers can pass
-- numbers or strings without worrying about formatting drift.
function MissionSeed.seed(missionId, contextKey, worldgenVersion)
    return MissionSeed.fnv1a32(
        tostring(worldgenVersion) .. "|" .. tostring(missionId) .. "|" .. tostring(contextKey)
    )
end

-- Per-phase stream seed derived from the mission seed.
function MissionSeed.stream(seed, phaseName)
    return MissionSeed.fnv1a32(tostring(seed) .. "|" .. tostring(phaseName))
end

-- mulberry32: tiny, high-quality-enough 32-bit PRNG. Returns rng() -> [0, 1),
-- the same injected-rng shape SpawnSlots uses. Sequence is fully determined by
-- the seed and identical in every environment.
function MissionSeed.mulberry32(seed)
    local a = seed % MOD32
    return function()
        a = (a + 0x6D2B79F5) % MOD32
        local t = a
        t = mul32(bit32.bxor(t, bit32.rshift(t, 15)), bit32.bor(t, 1))
        t = bit32.bxor(t, (t + mul32(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % MOD32)
        return bit32.bxor(t, bit32.rshift(t, 14)) / MOD32
    end
end

return MissionSeed
