--[[
    EffectiveStatsService — publishes every derived player stat as an
    attribute (Jason's SSOT doctrine, 2026-07-14: "one source of truth...
    only ever reference that variable... listen for updates").

    The formulas live in Shared/Game/EffectiveStats (pure registry). This
    service computes each axis per player and publishes Eff_<Axis> attributes:
      - on join,
      - whenever any watched input attribute changes (subscription, no poll),
      - when the soonest timed source EXPIRES (attributes don't fire when a
        deadline passes — we schedule the republish ourselves).

    Consumers: gameplay folds build their stacks from the SAME registry;
    BuffStatsHud displays these attributes verbatim.

    Eff_Coin composes the buff-axis stack with the breakable_reward modifier
    pipeline (enchant coin_finder lives there), so the published number tracks
    what a payout actually multiplies by at the player level.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EffectiveStats = require(ReplicatedStorage.Shared.Game.EffectiveStats)

local EffectiveStatsService = {}
EffectiveStatsService.__index = EffectiveStatsService

function EffectiveStatsService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._modifierService = self._modules and self._modules.ModifierService
    self._buffsConfig = self._configLoader and self._configLoader:LoadConfig("buffs") or {}
    self._bound = setmetatable({}, { __mode = "k" }) -- [player] = { conns = {}, tokens = {} }
end

function EffectiveStatsService:Start()
    for _, player in ipairs(Players:GetPlayers()) do
        self:_bind(player)
    end
    Players.PlayerAdded:Connect(function(player)
        self:_bind(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        local rec = self._bound[player]
        if rec then
            for _, c in ipairs(rec.conns) do
                c:Disconnect()
            end
            self._bound[player] = nil
        end
    end)
    if self._logger then
        self._logger:Info("EffectiveStatsService started (SSOT stat publisher)")
    end
end

function EffectiveStatsService:_axisCfg(axisId)
    local axes = self._buffsConfig.axes or {}
    return axes[axisId] or { cap = self._buffsConfig.default_cap or 3.0 }
end

function EffectiveStatsService:_publish(player, axisId)
    local def = EffectiveStats.AXES[axisId]
    if not def or not player.Parent then
        return
    end
    local function get(name)
        return player:GetAttribute(name)
    end
    local now = os.time()
    local value
    if axisId == "recharge" then
        value = EffectiveStats.rechargeFraction(get, now)
    else
        value = EffectiveStats.multiplier(axisId, get, now, self:_axisCfg(axisId))
    end
    -- Compose pipeline-owned enchant modifiers with the attribute-owned buff axes exactly as their
    -- gameplay folds do. Tactics multiplies pet damage; Efficiency publishes its cadence multiple;
    -- hatch Luck adds to the boost fraction; breakable rewards multiply the coin payout.
    if self._modifierService and self._modifierService.Resolve then
        local pipelineKind
        local base
        local combine
        local context = {}
        if axisId == "coin_yield" then
            pipelineKind, base, combine = "breakable_reward", 1, "multiply"
            context.currency = "coins"
        elseif axisId == "crystal_yield" then
            pipelineKind, base, combine = "breakable_reward", 1, "replace"
            context.currency = "crystals"
        elseif axisId == "pet_damage" then
            pipelineKind, base, combine = "pet_damage", 1, "multiply"
        elseif axisId == "pet_efficiency" then
            pipelineKind, base, combine = "pet_efficiency", 1, "replace"
        elseif axisId == "luck" then
            pipelineKind, base, combine = "hatch_luck", 0, "add"
        end
        if pipelineKind then
            context.player = player
            context.kind = pipelineKind
            context.source = "EffectiveStatsService"
            local ok, resolved = pcall(function()
                return self._modifierService:Resolve(base, context)
            end)
            if ok and tonumber(resolved) then
                if combine == "multiply" then
                    value *= tonumber(resolved)
                elseif combine == "add" then
                    value += tonumber(resolved)
                else
                    value = tonumber(resolved)
                end
            end
        end
    end
    -- publish on change only (attribute writes replicate; don't spam)
    value = math.floor(value * 1000 + 0.5) / 1000
    if player:GetAttribute(def.attr) ~= value then
        player:SetAttribute(def.attr, value)
    end
    -- schedule the expiry republish (deadline passing fires no signal)
    local rec = self._bound[player]
    if rec then
        local expiry = EffectiveStats.nextExpiry(axisId, get, now)
        rec.tokens[axisId] = (rec.tokens[axisId] or 0) + 1
        if expiry then
            local myToken = rec.tokens[axisId]
            task.delay(math.max(expiry - now, 0) + 0.1, function()
                local cur = self._bound[player]
                if cur and cur.tokens[axisId] == myToken and player.Parent then
                    self:_publish(player, axisId)
                end
            end)
        end
    end
end

function EffectiveStatsService:_bind(player)
    if self._bound[player] then
        return
    end
    local rec = { conns = {}, tokens = {} }
    self._bound[player] = rec
    for axisId, def in pairs(EffectiveStats.AXES) do
        for _, attrName in ipairs(def.watch) do
            table.insert(
                rec.conns,
                player:GetAttributeChangedSignal(attrName):Connect(function()
                    self:_publish(player, axisId)
                end)
            )
        end
        self:_publish(player, axisId)
    end
end

return EffectiveStatsService
