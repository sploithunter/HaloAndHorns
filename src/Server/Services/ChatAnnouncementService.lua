--[[
    Authoritative system-message spine for the Roblox chat window.

    Local Mythical+ hatch, level-up, and sidekick notices travel over ChatAnnouncement. Huge hatch
    notices additionally relay through MessagingService so every live server sees them.
    Cross-server delivery is best-effort; the source server always displays the notice first.
]]

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Game.ChatAnnouncementRules)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local ChatAnnouncementService = {}
ChatAnnouncementService.__index = ChatAnnouncementService

local function safeString(value, maximum)
    return type(value) == "string" and value ~= "" and #value <= maximum
end

function ChatAnnouncementService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._config = self._configLoader:LoadConfig("chat_announcements")
    self._petsConfig = self._configLoader:LoadConfig("pets")
    self._random = Random.new()
    self._seen = {}
    self._seenOrder = {}
end

function ChatAnnouncementService:_remember(announcementId)
    if self._seen[announcementId] then
        return false
    end
    self._seen[announcementId] = true
    self._seenOrder[#self._seenOrder + 1] = announcementId
    local limit = math.max(16, math.floor(tonumber(self._config.limits.remembered_ids) or 256))
    while #self._seenOrder > limit do
        local expired = table.remove(self._seenOrder, 1)
        self._seen[expired] = nil
    end
    return true
end

function ChatAnnouncementService:_validGlobal(payload)
    local limits = self._config.limits or {}
    local textLimit = math.max(1, math.floor(tonumber(limits.text_characters) or 240))
    local idLimit = math.max(1, math.floor(tonumber(limits.id_characters) or 128))
    return type(payload) == "table"
        and payload.version == self._config.version
        and payload.kind == "hatch"
        and payload.scope == "global"
        and payload.rarityId == (self._config.hatch.global_rarity or "huge")
        and safeString(payload.announcementId, idLimit)
        and safeString(payload.text, textLimit)
        and type(payload.colorHex) == "string"
        and payload.colorHex:match("^#%x%x%x%x%x%x$") ~= nil
end

function ChatAnnouncementService:_broadcast(payload)
    Signals.ChatAnnouncement:FireAllClients(payload)
end

function ChatAnnouncementService:Start()
    local topic = self._config.hatch.messaging_topic
    task.spawn(function()
        local ok, subscriptionOrError = pcall(function()
            return MessagingService:SubscribeAsync(topic, function(message)
                local payload = message and message.Data
                if self:_validGlobal(payload) and self:_remember(payload.announcementId) then
                    self:_broadcast(payload)
                end
            end)
        end)
        if ok then
            self._subscription = subscriptionOrError
        else
            self._logger:Warn("Global hatch chat subscription unavailable", {
                context = "ChatAnnouncementService",
                topic = topic,
                error = tostring(subscriptionOrError),
            })
        end
    end)
end

function ChatAnnouncementService:AnnounceHatches(player, results)
    if not player then
        return
    end
    local displayName = player.DisplayName or player.Name
    for _, result in ipairs(results or {}) do
        local payload = Rules.hatch(displayName, result, self._petsConfig, self._config)
        if payload then
            payload.version = self._config.version
            payload.announcementId = ("%s:%s"):format(
                game.JobId or "",
                HttpService:GenerateGUID(false)
            )
            payload.createdAt = os.time()
            self:_remember(payload.announcementId)
            self:_broadcast(payload)

            if payload.scope == "global" then
                task.spawn(function()
                    local ok, err = pcall(
                        MessagingService.PublishAsync,
                        MessagingService,
                        self._config.hatch.messaging_topic,
                        payload
                    )
                    if not ok then
                        self._logger:Warn("Global hatch chat publish unavailable", {
                            context = "ChatAnnouncementService",
                            player = player.Name,
                            error = tostring(err),
                        })
                    end
                end)
            end
        end
    end
end

function ChatAnnouncementService:AnnounceSidekick(player, lead, earnedLevel, effectiveLevel)
    if not player or not lead then
        return
    end
    local payload = Rules.teamSidekick(
        player.DisplayName or player.Name,
        lead.DisplayName or lead.Name,
        earnedLevel,
        effectiveLevel,
        self._config
    )
    if not payload then
        return
    end
    payload.version = self._config.version
    payload.announcementId = ("%s:%s"):format(game.JobId or "", HttpService:GenerateGUID(false))
    payload.createdAt = os.time()
    self:_remember(payload.announcementId)
    self:_broadcast(payload)
end

function ChatAnnouncementService:AnnounceLevel(player, level)
    if not player then
        return
    end
    local prefixes = self._config.level_up and self._config.level_up.prefixes or {}
    local prefixIndex = #prefixes > 0 and self._random:NextInteger(1, #prefixes) or 1
    local payload =
        Rules.levelUp(player.DisplayName or player.Name, level, self._config, prefixIndex)
    payload.version = self._config.version
    payload.announcementId = ("%s:%s"):format(game.JobId or "", HttpService:GenerateGUID(false))
    payload.createdAt = os.time()
    self:_remember(payload.announcementId)
    self:_broadcast(payload)
end

function ChatAnnouncementService:AnnounceCreatorLuck(player, multiplier)
    if not player then
        return
    end
    local payload = Rules.creatorLuck(player.DisplayName or player.Name, multiplier, self._config)
    payload.version = self._config.version
    payload.announcementId = ("%s:%s"):format(game.JobId or "", HttpService:GenerateGUID(false))
    payload.createdAt = os.time()
    self:_remember(payload.announcementId)
    self:_broadcast(payload)
end

function ChatAnnouncementService:Destroy()
    if self._subscription then
        self._subscription:Disconnect()
        self._subscription = nil
    end
end

return ChatAnnouncementService
