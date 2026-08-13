--[[
    PromoCodeService — server-authoritative public reward-code redemption.

    Definitions are config-driven; grants terminate in RewardService. Per-player claim records live
    in the ProfileStore profile and use the stable definition id, never the public spelling. Roblox
    LaunchData (`code=...`) only prefills the panel and records campaign attribution — it never
    silently redeems a reward.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PromoCodeLogic = require(ReplicatedStorage.Shared.Game.PromoCodeLogic)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local PromoCodeService = {}
PromoCodeService.__index = PromoCodeService

local MESSAGES = {
    disabled = "Codes are temporarily unavailable.",
    invalid = "That code isn't valid.",
    not_started = "That code isn't active yet.",
    expired = "That code has expired.",
    level_required = "Reach the required level before redeeming this code.",
    already_claimed = "You already redeemed this code.",
    busy = "That code is already being checked. Please wait.",
    rate_limited = "Too many attempts. Please wait a few seconds.",
    data_not_loaded = "Your profile is still loading. Please try again.",
    grant_failed = "The reward could not be granted. Please try again.",
}

function PromoCodeService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._rewardService = self._modules and self._modules.RewardService
    self._progressionService = self._modules and self._modules.PlayerProgressionService
    self._statsService = self._modules and self._modules.StatsService
    self._config = self._configLoader:LoadConfig("promo_codes")
    self._locks = setmetatable({}, { __mode = "k" })
    self._attempts = setmetatable({}, { __mode = "k" })
    self._launch = setmetatable({}, { __mode = "k" })
end

function PromoCodeService:Start()
    local function capture(player)
        self:_captureLaunchAttribution(player)
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
                self:_persistLaunchAttribution(player)
            end
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        capture(player)
    end
    Players.PlayerAdded:Connect(capture)
    Players.PlayerRemoving:Connect(function(player)
        self._locks[player] = nil
        self._attempts[player] = nil
        self._launch[player] = nil
    end)
end

function PromoCodeService:_root(data)
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    data.GameData.PromoCodes = type(data.GameData.PromoCodes) == "table"
            and data.GameData.PromoCodes
        or {}
    local root = data.GameData.PromoCodes
    root.claims = type(root.claims) == "table" and root.claims or {}
    root.attribution = type(root.attribution) == "table" and root.attribution or {}
    return root
end

function PromoCodeService:_claimedLevel(player)
    if self._progressionService and self._progressionService.GetClaimedLevel then
        return self._progressionService:GetClaimedLevel(player)
    end
    local data = self._dataService and self._dataService:GetData(player)
    return math.max(1, tonumber(data and data.Stats and data.Stats.ClaimedLevel) or 1)
end

function PromoCodeService:_captureLaunchAttribution(player)
    local ok, joinData = pcall(function()
        return player:GetJoinData()
    end)
    local raw = ok and type(joinData) == "table" and joinData.LaunchData or nil
    local normalized = PromoCodeLogic.extractLaunchCode(raw, self._config.input)
    local id, definition = PromoCodeLogic.find(self._config, normalized)
    if not id then
        return
    end
    self._launch[player] = {
        id = id,
        code = normalized,
        campaign = definition.campaign or id,
        seenAt = os.time(),
    }
end

function PromoCodeService:_writeAttribution(root, player)
    local launch = self._launch[player]
    if not launch or next(root.attribution) ~= nil then
        return false
    end
    root.attribution = {
        first_code_id = launch.id,
        first_campaign = launch.campaign,
        first_seen_at = launch.seenAt,
    }
    return true
end

function PromoCodeService:_persistLaunchAttribution(player)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return false
    end
    local root = self:_root(data)
    if not self:_writeAttribution(root, player) then
        return false
    end
    local launch = self._launch[player]
    self._dataService:RequestSave(player, "promo_link_attribution", { critical = true })
    fireGameEvent(player, "promo_link_attributed", {
        codeId = launch.id,
        campaign = launch.campaign,
    })
    return true
end

function PromoCodeService:_consumeAttempt(player)
    local rules = type(self._config.attempts) == "table" and self._config.attempts or {}
    local now = os.clock()
    local window = tonumber(rules.window_seconds) or 60
    local maximum = tonumber(rules.max_per_window) or 10
    local cooldown = tonumber(rules.cooldown_seconds) or 10
    local state = self._attempts[player]
    if not state or now - state.startedAt >= window then
        state = { startedAt = now, count = 0, blockedUntil = 0 }
        self._attempts[player] = state
    end
    if now < (state.blockedUntil or 0) then
        return false
    end
    state.count += 1
    if state.count > maximum then
        state.blockedUntil = now + cooldown
        return false
    end
    return true
end

function PromoCodeService:GetStatus(player)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded", message = MESSAGES.data_not_loaded }
    end
    self:_persistLaunchAttribution(player)
    local launch = self._launch[player]
    return {
        ok = true,
        enabled = self._config.enabled ~= false,
        prefill = launch and launch.code or "",
        campaign = launch and launch.campaign or nil,
    }
end

function PromoCodeService:_message(reason, definition)
    if reason == "level_required" and definition then
        return string.format(
            "Reach level %d before redeeming this code.",
            tonumber(definition.minimum_level) or 1
        )
    end
    return MESSAGES[reason] or MESSAGES.invalid
end

function PromoCodeService:Redeem(player, rawCode)
    if self._config.enabled == false then
        return { ok = false, reason = "disabled", message = MESSAGES.disabled }
    end
    if not self:_consumeAttempt(player) then
        return { ok = false, reason = "rate_limited", message = MESSAGES.rate_limited }
    end

    local normalized = PromoCodeLogic.normalize(rawCode, self._config.input)
    local id, definition = PromoCodeLogic.find(self._config, normalized)
    if not id then
        return { ok = false, reason = "invalid", message = MESSAGES.invalid }
    end

    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded", message = MESSAGES.data_not_loaded }
    end
    self:_persistLaunchAttribution(player)
    local root = self:_root(data)
    local claim = type(root.claims[id]) == "table" and root.claims[id] or {}
    local allowed, reason = PromoCodeLogic.evaluate(definition, {
        now = os.time(),
        isStudio = RunService:IsStudio(),
        level = self:_claimedLevel(player),
        claimedCount = claim.count,
    })
    if not allowed then
        return { ok = false, reason = reason, message = self:_message(reason, definition) }
    end

    self._locks[player] = self._locks[player] or {}
    if self._locks[player][id] then
        return { ok = false, reason = "busy", message = MESSAGES.busy }
    end
    self._locks[player][id] = true

    local ok, result = pcall(function()
        return self._rewardService:Grant(player, definition.reward, "promo:" .. id)
    end)
    self._locks[player][id] = nil
    if not ok or type(result) ~= "table" or result.ok ~= true then
        if self._logger then
            self._logger:Warn("Promo code reward grant failed", {
                player = player.UserId,
                codeId = id,
                error = ok and tostring(result and result.reason) or tostring(result),
            })
        end
        return { ok = false, reason = "grant_failed", message = MESSAGES.grant_failed }
    end

    local now = os.time()
    claim.count = (tonumber(claim.count) or 0) + 1
    claim.first_claimed_at = tonumber(claim.first_claimed_at) or now
    claim.last_claimed_at = now
    claim.campaign = definition.campaign or id
    claim.code_version = tonumber(self._config.version) or 1
    root.claims[id] = claim

    if self._statsService then
        pcall(function()
            self._statsService:Increment(player, "promo_codes_redeemed", 1)
        end)
    end
    self._dataService:RequestSave(player, "promo_code:" .. id, { critical = true })

    local message = definition.success_message or "🎁 CODE REDEEMED!"
    fireGameEvent(player, "promo_code_redeemed", {
        name = message,
        codeId = id,
        campaign = definition.campaign or id,
    })

    return {
        ok = true,
        codeId = id,
        campaign = definition.campaign or id,
        message = message,
        granted = result.granted,
        claimCount = claim.count,
    }
end

function PromoCodeService:ResetForTesting(player)
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    data.GameData.PromoCodes = { claims = {}, attribution = {} }
    self._attempts[player] = nil
    self._locks[player] = nil
    self._dataService:RequestSave(player, "promo_code_test_reset", { critical = true })
    return { ok = true }
end

return PromoCodeService
