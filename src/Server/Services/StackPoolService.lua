--[[
    StackPoolService — Feature 8 (Halo & Horns).

    Server owner of the stacked-pet token-bucket model (pure StackPool core). The
    pool math is fully exercised here via Simulate; binding ready_count/last_update
    onto live inventory stacks (and decrementing on combat downs) lands with combat
    in Phase 4. Exposed now so the model is server-verified end-to-end.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StackPool = require(ReplicatedStorage.Shared.Game.StackPool)

local StackPoolService = {}
StackPoolService.__index = StackPoolService

function StackPoolService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._config = self._configLoader:LoadConfig("stack_pool")
end

-- Run the pool model: refresh a stack state forward by `elapsed` seconds and
-- compute its combat contribution. Defaults recharge/curve from config.
function StackPoolService:Simulate(params)
    local recharge = params.recharge or self._config.recharge_per_instance_seconds
    local curve = params.curve or self._config.contribution_curve
    local stackState = {
        total_count = params.total,
        ready_count = params.ready,
        last_update = 0,
    }
    local refreshed = StackPool.refresh(stackState, params.elapsed or 0, recharge)
    local contribution = StackPool.contribution(refreshed, params.basePower or 0, curve)
    return {
        ok = true,
        ready = refreshed.ready_count,
        total = refreshed.total_count,
        contribution = contribution,
        curve = curve,
    }
end

return StackPoolService
