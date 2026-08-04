local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FriendBoost = require(ReplicatedStorage.Shared.Game.FriendBoost)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local FriendBoostService = {}
FriendBoostService.__index = FriendBoostService

local function pairKey(a, b)
    local low = math.min(a.UserId, b.UserId)
    local high = math.max(a.UserId, b.UserId)
    return tostring(low) .. ":" .. tostring(high)
end

function FriendBoostService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._modifierService = self._modules.ModifierService
    self._config = self._configLoader:LoadConfig("friend_boost")
    self._friends = {}
    self._pairStatus = {}
    self._pairUsers = {}
    self._pairPending = {}
    self._readinessConnections = {}

    if self._modifierService and self._modifierService.RegisterProvider then
        self._modifierService:RegisterProvider("boosts", function(context)
            return self:_modifierContributions(context)
        end)
    end
end

function FriendBoostService:IsEnabled()
    return self._config and self._config.enabled ~= false
end

function FriendBoostService:_bonuses(player)
    return FriendBoost.bonuses(
        self._config,
        player and player:GetAttribute("FriendBoostCount") or 0
    )
end

function FriendBoostService:_setAttributes(player)
    if not player or not player.Parent then
        return nil
    end
    local rawCount = 0
    for friend in pairs(self._friends[player] or {}) do
        if friend.Parent then
            rawCount += 1
        end
    end
    local bonuses = FriendBoost.bonuses(self._config, rawCount)
    player:SetAttribute("FriendBoostEnabled", self:IsEnabled())
    player:SetAttribute("FriendBoostPhase", bonuses.phase)
    player:SetAttribute("FriendBoostCount", bonuses.friendCount)
    player:SetAttribute("FriendHatchLuckBonus", bonuses.hatchLuck)
    player:SetAttribute("FriendXPBonus", bonuses.xp)
    player:SetAttribute("FriendCoinBonus", bonuses.coins)
    return bonuses
end

function FriendBoostService:_bannerText(bonuses)
    if bonuses.friendCount <= 0 then
        local one = FriendBoost.bonuses(self._config, 1)
        return string.format(
            "👥 FRIEND BOOST! Bring up to %d friends — each adds +%d%% Hatch Luck and +%d%% XP & Coins!",
            math.max(0, math.floor(tonumber(self._config.max_friends) or 4)),
            math.floor(one.hatchLuck * 100 + 0.5),
            math.floor(one.xp * 100 + 0.5)
        )
    end
    return string.format(
        "🎉 FRIEND BOOST ACTIVE — %d friend%s: +%d%% Hatch Luck · +%d%% XP & Coins!",
        bonuses.friendCount,
        bonuses.friendCount == 1 and "" or "s",
        math.floor(bonuses.hatchLuck * 100 + 0.5),
        math.floor(bonuses.xp * 100 + 0.5)
    )
end

function FriendBoostService:_announce(player, bonuses, delayed)
    bonuses = bonuses or self:_setAttributes(player)
    if not bonuses or not player.Parent or not self:IsEnabled() then
        return
    end
    local function send()
        if player.Parent then
            fireGameEvent(player, "friend_boost_active", {
                name = self:_bannerText(bonuses),
                friendCount = bonuses.friendCount,
                hatchLuck = bonuses.hatchLuck,
                xp = bonuses.xp,
                coins = bonuses.coins,
                phase = bonuses.phase,
            })
        end
    end
    if not delayed or player:GetAttribute("DataLoaded") == true then
        send()
        return
    end

    local oldConnection = self._readinessConnections[player]
    if oldConnection then
        oldConnection:Disconnect()
    end
    local connection
    connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
        if player:GetAttribute("DataLoaded") ~= true then
            return
        end
        connection:Disconnect()
        self._readinessConnections[player] = nil
        task.defer(send)
    end)
    self._readinessConnections[player] = connection
end

function FriendBoostService:_setPair(a, b, areFriends)
    if not (a and b and a.Parent and b.Parent) then
        return
    end
    self._friends[a] = self._friends[a] or {}
    self._friends[b] = self._friends[b] or {}
    if areFriends then
        self._friends[a][b] = true
        self._friends[b][a] = true
    else
        self._friends[a][b] = nil
        self._friends[b][a] = nil
    end
end

function FriendBoostService:_resolvePair(a, b, onComplete)
    local key = pairKey(a, b)
    if self._pairStatus[key] ~= nil then
        self:_setPair(a, b, self._pairStatus[key])
        onComplete(self._pairStatus[key])
        return
    end
    if self._pairPending[key] then
        table.insert(self._pairPending[key], onComplete)
        return
    end
    self._pairPending[key] = { onComplete }
    task.spawn(function()
        local ok, result = pcall(function()
            return a:IsFriendsWith(b.UserId)
        end)
        local areFriends = ok and result == true
        self._pairStatus[key] = areFriends
        self._pairUsers[key] = { a.UserId, b.UserId }
        self:_setPair(a, b, areFriends)
        local callbacks = self._pairPending[key] or {}
        self._pairPending[key] = nil
        for _, callback in ipairs(callbacks) do
            callback(areFriends)
        end
        if not ok and self._logger then
            self._logger:Warn("FriendBoost friendship check failed", {
                first = a.UserId,
                second = b.UserId,
                error = tostring(result),
            })
        end
    end)
end

function FriendBoostService:_playerAdded(player)
    self._friends[player] = self._friends[player] or {}
    self:_setAttributes(player)
    if not self:IsEnabled() then
        return
    end

    local peers = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            table.insert(peers, other)
        end
    end
    if #peers == 0 then
        self:_announce(player, self:_setAttributes(player), true)
        return
    end

    local remaining = #peers
    for _, other in ipairs(peers) do
        self:_resolvePair(player, other, function(areFriends)
            if areFriends then
                local otherBonuses = self:_setAttributes(other)
                self:_announce(other, otherBonuses, false)
            end
            remaining -= 1
            if remaining == 0 then
                self:_announce(player, self:_setAttributes(player), true)
            end
        end)
    end
end

function FriendBoostService:_playerRemoving(player)
    local readinessConnection = self._readinessConnections[player]
    if readinessConnection then
        readinessConnection:Disconnect()
        self._readinessConnections[player] = nil
    end
    for other in pairs(self._friends[player] or {}) do
        if self._friends[other] then
            self._friends[other][player] = nil
            self:_setAttributes(other)
        end
    end
    self._friends[player] = nil
    for key, ids in pairs(self._pairUsers) do
        if ids[1] == player.UserId or ids[2] == player.UserId then
            self._pairUsers[key] = nil
            self._pairStatus[key] = nil
            self._pairPending[key] = nil
        end
    end
end

function FriendBoostService:_modifierContributions(context)
    if not self:IsEnabled() or type(context) ~= "table" or not context.player then
        return {}
    end
    local bonuses = self:_bonuses(context.player)
    if context.kind == "hatch_luck" and bonuses.hatchLuck > 0 then
        return {
            {
                id = "friend_hatch_luck",
                label = "Friends",
                amount = bonuses.hatchLuck,
                combine = "add",
            },
        }
    end
    if
        (context.kind == "breakable_reward" or context.kind == "earned_currency")
        and FriendBoost.isCoinCurrency(context.currency)
        and bonuses.coins > 0
    then
        return {
            {
                id = "friend_coin_bonus",
                label = "Friends",
                amount = 1 + bonuses.coins,
                combine = "multiply",
            },
        }
    end
    return {}
end

function FriendBoostService:Start()
    Players.PlayerAdded:Connect(function(player)
        self:_playerAdded(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self:_playerRemoving(player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        self:_playerAdded(player)
    end
    if self._logger then
        local phaseId, phase = FriendBoost.phase(self._config)
        self._logger:Info("FriendBoostService started", {
            phase = phaseId,
            maxFriends = self._config.max_friends,
            hatchLuckPerFriend = phase.hatch_luck_per_friend,
            xpPerFriend = phase.xp_per_friend,
            coinsPerFriend = phase.coins_per_friend,
            launchPlayTarget = self._config.launch_play_target,
        })
    end
end

return FriendBoostService
