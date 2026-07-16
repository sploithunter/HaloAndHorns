--[[
    LayerService — server owner of layer access (Feature 3, Halo & Horns).

    Server-authoritative ascend/descend: validates Soul magnitude + token cost
    from config (never trusting the client), deducts the token cost via
    EconomyService, and sets profile.CurrentLayer (lazy-init, persists). The actual
    teleport to the layer's Y-offset geometry is deferred until the stacked
    layers are authored in the world; this service owns the logical layer + cost.

    Cross-path "visit" portals (ignore Soul) are tied to authored visit portals
    and are NOT exposed as a client-settable flag here (that would bypass Soul
    gating); the pure LayerAccess supports it for when visit portals are authored.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LayerAccess = require(ReplicatedStorage.Shared.Game.LayerAccess)
local RealmTokens = require(ReplicatedStorage.Shared.Game.RealmTokens)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local LayerService = {}
LayerService.__index = LayerService

function LayerService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._economyService = self._modules and self._modules.EconomyService
    self._layersConfig = self._configLoader:LoadConfig("layers")
end

-- On join, settle the player's layer + PUBLISH the layer attributes (CurrentLayer/CurrentRealm/
-- RealmHatchLuckBonus). Critical fix: those attributes were previously only set by UseLayer, so on
-- spawn the client realm skin + RealmHellFaces had nothing to react to — the realm never lit up
-- until you toggled a portal (and entry took two clicks). With boot_to_base on, we also reset to
-- base so realms are entered deliberately each session (and the first portal press descends).
function LayerService:_settleOnJoin(player)
    if not (player and player.Parent and self._dataService) then
        return
    end
    if not Readiness.awaitAttribute(player, "DataLoaded", true, 30) or not player.Parent then
        return
    end
    local data = self._dataService:GetData(player)
    if not data then
        return
    end
    if self._layersConfig.boot_to_base ~= false then
        data.CurrentLayer = "base"
    end
    self:_publishLayer(player, data.CurrentLayer or "base")
end

function LayerService:Start()
    -- SKY SINGLETON SWEEP (2026-07-16): a stray second Sky in Lighting
    -- (e.g. a hand-staged "_HawaiiPreviewSky" saved into the place) makes
    -- the engine's active-sky pick arbitrary, so RealmAtmosphere's
    -- per-layer skybox swap mutates a Sky the renderer may ignore — hell
    -- layers showed the base aurora everywhere. Keep the FIRST Sky, purge
    -- extras, loudly.
    do
        local Lighting = game:GetService("Lighting")
        local kept
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:IsA("Sky") then
                if not kept then
                    kept = c
                else
                    warn(
                        ("[LayerService] duplicate Sky '%s' removed from Lighting (keeping '%s') — "
                            .. "duplicates break the per-layer skybox swap"):format(c.Name, kept.Name)
                    )
                    c:Destroy()
                end
            end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:_settleOnJoin(player)
        end)
    end
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            self:_settleOnJoin(player)
        end)
    end)
end

function LayerService:GetCurrentLayer(player)
    local data = self._dataService:GetData(player)
    return (data and data.CurrentLayer) or "base"
end

function LayerService:_tokenBalances(player)
    return {
        light_tokens = self._dataService:GetCurrency(player, "light_tokens") or 0,
        shadow_tokens = self._dataService:GetCurrency(player, "shadow_tokens") or 0,
    }
end

-- Player level for the World-S3 requires_level gate: the published EffectiveLevel
-- (combat level the curves read; teaming will sync it), falling back to Level.
function LayerService:_playerLevel(player)
    if not player then
        return 0
    end
    local lvl = player:GetAttribute("EffectiveLevel") or player:GetAttribute("Level")
    return tonumber(lvl) or 0
end

function LayerService:AccessibleLayers(player)
    local data = self._dataService:GetData(player)
    if not data then
        return {}
    end
    return LayerAccess.accessibleLayers(
        data.Soul or 0,
        self:_tokenBalances(player),
        self._layersConfig,
        self:_playerLevel(player)
    )
end

-- Income/reward scaling for the player's current layer (layers.multipliers; 1.0 at base).
-- The reward for descending: deeper realm = bigger income (+ bigger token cut, which is a
-- fraction of that income).
function LayerService:GetRewardMultiplier(player)
    local layer = self:GetCurrentLayer(player)
    local m = self._layersConfig.multipliers and self._layersConfig.multipliers[layer]
    return tonumber(m) or 1
end

-- CONTENT LEVEL offset for the player's current layer (0 at base; layers.level_offsets). Added to
-- a crystal/enemy's target level in the XP diminishing so a realm RESCALES — a high-level player
-- isn't instantly floored on arrival the way they are at home.
function LayerService:GetLevelOffset(player)
    local layer = self:GetCurrentLayer(player)
    local o = self._layersConfig.level_offsets and self._layersConfig.level_offsets[layer]
    return tonumber(o) or 0
end

-- Depth-scaled hatch luck for the player's current layer (0 at base). Consumed by
-- HatchEntitlementService via the published RealmHatchLuckBonus attribute.
function LayerService:GetHatchLuckBonus(player)
    return RealmTokens.hatchLuck(self:GetCurrentLayer(player), self._layersConfig)
end

-- ===== Token-earning loop (World S3 / RealmTokens) =====
-- Tokens are earned only while the player is in a realm layer (heaven -> light_tokens,
-- hell -> shadow_tokens). These are no-ops at base, so callers can fire them unconditionally.

function LayerService:_depositGrant(player, grant, reason)
    if not grant or not player or not self._economyService then
        return nil
    end
    local deposited = self._economyService:AddCurrency(player, grant.currency, grant.amount, reason)
    return deposited and grant or nil
end

-- A cut of biome-coin income becomes the realm token (call from the mining/combat payout).
function LayerService:GrantIncomeCut(player, incomeAmount)
    local layer = self:GetCurrentLayer(player)
    local grant = RealmTokens.fromIncome(incomeAmount, layer, self._layersConfig)
    return self:_depositGrant(player, grant, "realm_income_cut")
end

-- Flat token grant for a conquest event, keyed to the player's current realm.
function LayerService:GrantConquestTokens(player)
    local layer = self:GetCurrentLayer(player)
    local grant = RealmTokens.flat("conquest", layer, self._layersConfig)
    return self:_depositGrant(player, grant, "realm_conquest_tokens")
end

-- Flat token grant for hatching an egg in a realm.
function LayerService:GrantHatchTokens(player)
    local layer = self:GetCurrentLayer(player)
    local grant = RealmTokens.flat("hatch", layer, self._layersConfig)
    return self:_depositGrant(player, grant, "realm_hatch_tokens")
end

-- Publish the player's layer state for clients (the RealmAtmosphere skin reads CurrentRealm)
-- + the depth-scaled hatch luck (S3.4).
function LayerService:_publishLayer(player, layerId)
    local realm = (
        self._layersConfig.realm_alignment and self._layersConfig.realm_alignment[layerId]
    ) or "neutral"
    player:SetAttribute("CurrentLayer", layerId)
    player:SetAttribute("CurrentRealm", realm)
    player:SetAttribute("RealmHatchLuckBonus", self:GetHatchLuckBonus(player))
end

-- Re-publish the layer-derived realm attributes from the SSOT (used by
-- MissionInstanceService to restore CurrentRealm after a mission overrode
-- it with the mission THEME).
function LayerService:RefreshRealmAttributes(player)
    self:_publishLayer(player, self:GetCurrentLayer(player))
end

-- Attempt to move the player to a layer. Server re-validates cost from config.
-- opts.force (test portals / dev) skips the soul/level/token gate AND the cost deduction —
-- a pure teleport into the realm state, so the realm is reachable for testing before the
-- economy is grindable. Production entry leaves force off.
function LayerService:UseLayer(player, layerId, opts)
    opts = opts or {}
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    if not (self._layersConfig.access and self._layersConfig.access[layerId]) then
        return { ok = false, reason = "unknown_layer" }
    end

    local fromLayer = data.CurrentLayer or "base" -- captured before we overwrite it (for the Y-move)
    local soul = data.Soul or 0
    local cost, currency = 0, nil

    if not opts.force then
        currency = self._layersConfig.token_currency and self._layersConfig.token_currency[layerId]
        local balance = currency and (self._dataService:GetCurrency(player, currency) or 0) or 0
        local decision = LayerAccess.canAccess(soul, balance, layerId, self._layersConfig, {
            playerLevel = self:_playerLevel(player),
            fromLayer = data.CurrentLayer or "base", -- applies the charge_on traversal sink
        })
        if not decision.ok then
            return {
                ok = false,
                reason = decision.reason,
                cost = decision.cost,
                currency = decision.currency,
            }
        end
        cost, currency = decision.cost, decision.currency
        -- Deduct the server-resolved cost (from config, not the client).
        if cost and cost > 0 and currency then
            local debited =
                self._economyService:RemoveCurrency(player, currency, cost, "layer_use_" .. layerId)
            if not debited then
                return {
                    ok = false,
                    reason = "currency_debit_failed",
                    cost = cost,
                    currency = currency,
                }
            end
        end
    end

    data.CurrentLayer = layerId
    self:_publishLayer(player, layerId)

    -- PHYSICAL MOVE to the layer's Y-offset geometry (the previously-deferred teleport): shift the
    -- character by the delta between the old and new layer's y_offset (base = 0). The stacked worlds
    -- are identical copies, so a pure Y shift lands the player at the SAME spot in the target realm.
    local access = self._layersConfig.access or {}
    local layerAccess = access[layerId] or {}
    local dy = (layerAccess.y_offset or 0) - ((access[fromLayer] or {}).y_offset or 0)

    local char = player.Character
    if char and char.PrimaryPart then
        -- Resolve the destination CFrame. PREFER the realm's named entry anchor — a Part in the
        -- destination map folder (workspace.Maps.<Folder>) — so each realm starts the player in a
        -- specific area (Heaven 1 -> Lava, where the Fire/Dragon roster lives). FALL BACK to a pure
        -- Y-shift from where they stood (the stacked copies are identical, so the same spot lands).
        local destCFrame
        if layerAccess.entry_anchor then
            local folderName = (layerId:gsub("^%l", string.upper)) -- heaven_1 -> Heaven_1
            local maps = workspace:FindFirstChild("Maps")
            local mapFolder = maps and maps:FindFirstChild(folderName)
            local anchor = mapFolder and mapFolder:FindFirstChild(layerAccess.entry_anchor, true)
            if anchor and anchor:IsA("BasePart") then
                destCFrame = anchor.CFrame + Vector3.new(0, 4, 0) -- stand just above the anchor
            elseif self._logger then
                self._logger:Warn("Layer entry_anchor not found; falling back to Y-shift", {
                    layer = layerId,
                    anchor = layerAccess.entry_anchor,
                    folder = folderName,
                })
            end
        end
        if not destCFrame and dy ~= 0 then
            destCFrame = char:GetPivot() + Vector3.new(0, dy, 0)
        end

        if destCFrame then
            pcall(function()
                local hrp = char.PrimaryPart

                -- StreamingEnabled gotcha (2026-07-08 fall-through report): the client OWNS
                -- character physics, so arriving before the destination streamed to that client
                -- means falling through geometry only the server has. Order matters:
                --   1. stream the destination BEFORE moving — the wait happens while they still
                --      stand at the portal (reads as the portal charging, not a hang). NOTE the
                --      API is RequestStreamAroundAsync; the old RequestStreamingAround call was
                --      a nonexistent method whose error a pcall silently ate, which is why the
                --      "hint" never worked.
                pcall(function()
                    player:RequestStreamAroundAsync(
                        destCFrame.Position,
                        self._layersConfig.stream_wait_seconds or 8
                    )
                end)

                --   2. move. Correctness is EVENT-BASED (Jason: "no timeout
                --      shenanigans"): the place property StreamingIntegrityMode =
                --      PauseOutsideLoadedArea freezes the client's physics in an
                --      unstreamed region and releases it the instant the geometry
                --      arrives — the old anchored tail (a timeout in a hat) is gone.
                char:PivotTo(destCFrame)
            end)
        end
    end

    self._dataService:RequestSave(player, "layer_use_" .. layerId, { critical = true })

    if self._logger then
        self._logger:Info("Layer changed", {
            player = player.Name,
            layer = layerId,
            cost = cost,
            currency = currency,
            forced = opts.force or nil,
        })
    end

    return {
        ok = true,
        layer = layerId,
        cost = cost,
        currency = currency,
        soul = soul,
        forced = opts.force or nil,
    }
end

return LayerService
