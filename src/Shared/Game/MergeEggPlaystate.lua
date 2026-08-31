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

return MergeEggPlaystate
