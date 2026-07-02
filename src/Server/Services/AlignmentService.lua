--[[
    AlignmentService — server owner of the Soul stat (Feature 2, Halo & Horns).

    Wraps the pure SoulMath core over real profile state: reads/writes
    profile.Soul / LastConqueredBiome / ConqueredBiomes through DataService, and
    builds the RingTopology from config. Soul fields are lazy-initialized
    (default 0 / nil) so no ProfileStore schema migration is needed; written
    fields persist via ProfileStore (Feature 2: "Soul persists across sessions").

    Conquest is currently driven by the test-only `game.conquer` command (real
    conquest triggers arrive with combat in Phase 4).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RingTopology = require(ReplicatedStorage.Shared.Game.RingTopology)
local SoulMath = require(ReplicatedStorage.Shared.Game.SoulMath)

local AlignmentService = {}
AlignmentService.__index = AlignmentService

function AlignmentService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService

    self._biomeConfig = self._configLoader:LoadConfig("biomes")
    self._soulConfig = self._configLoader:LoadConfig("soul")
    self._topology = RingTopology.new(self._biomeConfig)

    if self._logger then
        self._logger:Info("AlignmentService initialized", { biomes = self._topology:count() })
    end
end

function AlignmentService:GetTopology()
    return self._topology
end

local function stateFromData(data)
    return {
        soul = data.Soul or 0,
        last_conquered_biome = data.LastConqueredBiome,
        conquered_biomes = data.ConqueredBiomes or {},
    }
end

-- Read the player's alignment view.
function AlignmentService:GetState(player)
    local data = self._dataService:GetData(player)
    if not data then
        return nil
    end
    local state = stateFromData(data)
    return {
        soul = state.soul,
        last_conquered_biome = state.last_conquered_biome,
        alignment = SoulMath.alignment(state.soul, self._soulConfig),
    }
end

-- Reset alignment state to a fresh profile (test/dev affordance).
function AlignmentService:Reset(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    data.Soul = 0
    data.LastConqueredBiome = nil
    data.ConqueredBiomes = {}
    self._dataService:RequestSave(player, "alignment_reset", { critical = true })
    return { ok = true, soul = 0 }
end

-- Apply a biome conquest: shift Soul per SoulMath and persist.
function AlignmentService:ApplyConquest(player, conqueredBiome)
    if not self._topology:has(conqueredBiome) then
        return { ok = false, reason = "unknown_biome", biome = conqueredBiome }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end

    local newState, result = SoulMath.applyConquest(
        stateFromData(data),
        conqueredBiome,
        self._topology,
        self._soulConfig
    )

    data.Soul = newState.soul
    data.LastConqueredBiome = newState.last_conquered_biome
    data.ConqueredBiomes = newState.conquered_biomes
    self._dataService:RequestSave(player, "alignment_conquest", { critical = true })

    -- World S3: a conquest also grants realm tokens keyed to the player's current realm
    -- (no-op at base / if LayerService isn't wired). Best-effort; never blocks the conquest.
    local layerService = self._modules and self._modules.LayerService
    if layerService and layerService.GrantConquestTokens then
        pcall(function()
            layerService:GrantConquestTokens(player)
        end)
    end

    if self._logger and result.fired then
        self._logger:Info("Conquest applied", {
            player = player.Name,
            biome = conqueredBiome,
            delta = result.delta,
            soul = newState.soul,
        })
    end

    return {
        ok = true,
        soul = newState.soul,
        last_conquered_biome = newState.last_conquered_biome,
        delta = result.delta,
        fired = result.fired,
        alignment = SoulMath.alignment(newState.soul, self._soulConfig),
    }
end

return AlignmentService
