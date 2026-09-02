-- Compact, ProfileStore-safe checkpoint normalization for Merge Defense.

local MergeEggCheckpoint = {}

local function whole(value, minimum)
    return math.max(minimum or 0, math.floor(tonumber(value) or 0))
end

local function numericArray(raw, maximum, minimum)
    local result = {}
    for index = 1, math.max(0, whole(maximum, 0)) do
        local value =
            whole(type(raw) == "table" and (raw[index] or raw[tostring(index)]) or 0, minimum or 0)
        -- Dense numeric arrays remain unambiguous through Roblox DataStore/ProfileStore
        -- serialization; zero is the explicit empty slot.
        result[index] = value
    end
    return result
end

function MergeEggCheckpoint.normalize(raw, options)
    raw = type(raw) == "table" and raw or {}
    options = type(options) == "table" and options or {}
    local interval = math.max(1, whole(options.interval or 10, 1))
    local maximumTier = math.max(1, whole(options.maximumTier or 56, 1))
    local maximumTeams = math.max(1, whole(options.maximumTeams or 9, 1))
    local wave = whole(raw.wave, 0)
    wave -= wave % interval
    return {
        version = 1,
        wave = wave,
        currency = type(raw.currency) == "string" and raw.currency or "hall_coins",
        coins = whole(raw.coins, 0),
        objective_eggs = whole(raw.objective_eggs or raw.objectiveEggsRemaining, 0),
        base_egg_tier = math.clamp(whole(raw.base_egg_tier or raw.baseEggTier, 1), 1, maximumTier),
        egg_inventory = numericArray(raw.egg_inventory or raw.eggInventory, maximumTier, 0),
        deployed_egg_tiers = numericArray(
            raw.deployed_egg_tiers or raw.deployedEggTiers,
            maximumTeams,
            0
        ),
    }
end

function MergeEggCheckpoint.isUsable(raw, options)
    return MergeEggCheckpoint.normalize(raw, options).wave > 0
end

function MergeEggCheckpoint.fromRuntime(snapshot, teams, options)
    snapshot = type(snapshot) == "table" and snapshot or {}
    local deployed = {}
    for _, team in ipairs(type(teams) == "table" and teams or {}) do
        local id = whole(team.id, 0)
        local tier = whole(team.eggTier, 0)
        if tier <= 0 then
            -- Destroyed hatcher eggs are disabled only for the failed live attempt. Their durable
            -- deployment identity remains in resetEggTier so logout/rejoin can rebuild the same
            -- last-good egg at full health, just like the in-session checkpoint restart.
            tier = whole(team.resetEggTier, 0)
        end
        if id > 0 and tier > 0 then
            deployed[id] = tier
        end
    end
    return MergeEggCheckpoint.normalize({
        wave = snapshot.wave,
        currency = snapshot.currency,
        coins = snapshot.coins,
        objective_eggs = snapshot.objectiveEggsRemaining,
        base_egg_tier = snapshot.recordState and snapshot.recordState.baseEggTier,
        egg_inventory = snapshot.eggInventory,
        deployed_egg_tiers = deployed,
    }, options)
end

return MergeEggCheckpoint
