-- Compact, ProfileStore-safe Merge Defense possessions saved independently of combat checkpoints.
-- A playstate may validly rewind to Wave 0 while still carrying a board, deployed eggs, and wallet.

local MergeEggCheckpoint = require(script.Parent.MergeEggCheckpoint)

local MergeEggPlaystate = {}

function MergeEggPlaystate.normalize(raw, options)
    raw = type(raw) == "table" and raw or {}
    local state = MergeEggCheckpoint.normalize(raw, options)
    state.version = 1
    state.saved = raw.saved == true
    return state
end

function MergeEggPlaystate.isUsable(raw, options)
    return MergeEggPlaystate.normalize(raw, options).saved == true
end

function MergeEggPlaystate.fromRuntime(snapshot, teams, options)
    local state = MergeEggCheckpoint.fromRuntime(snapshot, teams, options)
    state.saved = true
    return MergeEggPlaystate.normalize(state, options)
end

-- Older builds wrote a destroyed live egg as an empty deployment on logout. At the same wave-ten
-- boundary, the combat checkpoint still has the last-good deployment. Fill only missing slots so
-- the newer logout wallet, inventory, and upgraded live deployments remain authoritative.
function MergeEggPlaystate.recoverCheckpointDeployments(raw, rawCheckpoint, options)
    local state = MergeEggPlaystate.normalize(raw, options)
    local checkpoint = MergeEggCheckpoint.normalize(rawCheckpoint, options)
    if state.wave ~= checkpoint.wave then
        return state
    end
    for slot, checkpointTier in ipairs(checkpoint.deployed_egg_tiers) do
        if state.deployed_egg_tiers[slot] <= 0 and checkpointTier > 0 then
            state.deployed_egg_tiers[slot] = checkpointTier
        end
    end
    return state
end

return MergeEggPlaystate
