--[[
    FutureCallService — Level-5 consumable entitlement and activation.

    Progression grant:
      • three tokens when ClaimedLevel first reaches 5;
      • existing level-5+ profiles reconcile once through a named marker;
      • the token auto-binds into the first free top-row slot, left to right.

    Activation:
      • spends one token only after the NPC principal successfully spawns;
      • manifests the config-authored Level-10 future-self squad for 120 seconds;
      • a second activation while that player's future self is active is rejected.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FutureCallLogic = require(ReplicatedStorage.Shared.Game.FutureCallLogic)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local FutureCallService = {}
FutureCallService.__index = FutureCallService

function FutureCallService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._progressionService = self._modules and self._modules.PlayerProgressionService
    self._npcPrincipalService = self._modules and self._modules.NpcPrincipalService
    self._config = self._configLoader:LoadConfig("future_call")
    self._connections = setmetatable({}, { __mode = "k" })
end

function FutureCallService:BindPeerServices(services)
    self._hotbarService = services and services.HotbarService
end

function FutureCallService:Start()
    local function watch(player)
        if self._connections[player] then
            return
        end
        self._connections[player] = player
            :GetAttributeChangedSignal("ClaimedLevel")
            :Connect(function()
                self:Reconcile(player)
            end)
        task.spawn(function()
            if Readiness.awaitAttribute(player, "DataLoaded", true, 15) then
                self:Reconcile(player)
            end
        end)
    end

    Players.PlayerAdded:Connect(watch)
    Players.PlayerRemoving:Connect(function(player)
        local conn = self._connections[player]
        if conn then
            conn:Disconnect()
        end
        self._connections[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        watch(player)
    end
end

function FutureCallService:_log(level, message, data)
    if self._logger and self._logger[level] then
        self._logger[level](self._logger, message, data)
    end
end

function FutureCallService:_tokenId()
    return tostring(self._config.token and self._config.token.id or "future_call_token")
end

function FutureCallService:_count(player)
    local data = self._dataService:GetData(player)
    local bucket = data and data.Inventory and data.Inventory.consumables
    local item = bucket and bucket.items and bucket.items[self:_tokenId()]
    return math.max(0, math.floor(tonumber(item and item.quantity) or 0))
end

function FutureCallService:GetState(player)
    local token = self._config.token or {}
    local principalName = FutureCallLogic.principalName(player and player.Name, self._config)
    local active = self._npcPrincipalService
            and self._npcPrincipalService.IsActive
            and self._npcPrincipalService:IsActive(principalName)
        or false
    return {
        ok = true,
        tokens = {
            {
                id = self:_tokenId(),
                count = self:_count(player),
                name = token.display_name or "Future Call",
                type = token.type or "Summon token",
                description = token.description or "",
                icon_power = token.icon_power or "world_travel",
                duration = tonumber(token.duration) or 120,
                active = active == true,
            },
        },
    }
end

function FutureCallService:_pushHotbar(player)
    local hotbar = self._hotbarService
    if hotbar and hotbar.PushState then
        hotbar:PushState(player)
    end
end

function FutureCallService:_announceGrant(player, count, reason)
    local name
    if reason == "level5" then
        name = ("🔮 FUTURE CALL UNLOCKED!\nYou received %d summon tokens."):format(count)
    else
        name = ("🔮 %d Future Call token%s granted!"):format(count, count == 1 and "" or "s")
    end
    fireGameEvent(player, "future_call_awarded", {
        name = name,
        count = count,
        reason = reason,
    })
end

function FutureCallService:_addTokens(player, count)
    count = math.clamp(math.floor(tonumber(count) or 0), 1, 99)
    local uid, err = self._inventoryService:AddItem(player, "consumables", {
        id = self:_tokenId(),
        quantity = count,
        obtained_at = os.time(),
    })
    if not uid then
        return false, err or "inventory_add_failed"
    end
    local hotbar = self._hotbarService
    if hotbar and hotbar.AutoBindToken then
        hotbar:AutoBindToken(player, self:_tokenId())
    end
    self:_pushHotbar(player)
    return true
end

-- Existing and newly-claimed profiles take this same idempotent path.
function FutureCallService:Reconcile(player)
    if self._config.enabled == false or not (player and player.Parent) then
        return { ok = false, reason = "disabled_or_left" }
    end
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local claimed = self._progressionService:GetClaimedLevel(player)
    if not FutureCallLogic.shouldGrant(data.GameData, claimed, self._config) then
        return { ok = true, granted = 0, reconciled = false }
    end

    -- Mark before inventory mutation: AddItem saves the whole shared profile. If the
    -- add fails, roll the marker back before any successful save can make it durable.
    local marker = FutureCallLogic.markGranted(data.GameData, self._config, true)
    local count = math.max(
        1,
        math.floor(tonumber(self._config.entitlement and self._config.entitlement.grant_count) or 3)
    )
    local ok, err = self:_addTokens(player, count)
    if not ok then
        data.GameData.FutureCall[marker] = nil
        self:_log("Warn", "Future Call entitlement grant failed", {
            player = player.Name,
            reason = tostring(err),
        })
        return { ok = false, reason = err }
    end

    self._dataService:RequestSave(player, "future_call_level5_entitlement", { critical = true })
    self:_announceGrant(player, count, "level5")
    self:_log("Info", "Future Call entitlement granted", {
        player = player.Name,
        claimedLevel = claimed,
        count = count,
    })
    return { ok = true, granted = count, reconciled = true }
end

-- Admin testing uses the real inventory + auto-bind + banner path, but deliberately
-- does not stamp the Level-5 marker. A low-level test account still earns its grant.
function FutureCallService:AdminGrant(player, count)
    count = math.clamp(math.floor(tonumber(count) or 3), 1, 20)
    local ok, err = self:_addTokens(player, count)
    if not ok then
        return { ok = false, reason = err }
    end
    self:_announceGrant(player, count, "admin")
    return { ok = true, granted = count, count = self:_count(player) }
end

-- The explicit admin "Reset to Beginning" is a reproducible new-player run, so
-- it re-arms the Level-5 entitlement and removes any test stock. Normal respecs
-- do neither.
function FutureCallService:ResetForBeginning(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    data.GameData.FutureCall = {}
    local count = self:_count(player)
    if count > 0 then
        local removed =
            self._inventoryService:RemoveItem(player, "consumables", self:_tokenId(), count)
        if not removed then
            return { ok = false, reason = "token_remove_failed" }
        end
    end
    local principalName = FutureCallLogic.principalName(player.Name, self._config)
    self._npcPrincipalService:Despawn(principalName)
    self:_pushHotbar(player)
    return { ok = true, removed = count }
end

function FutureCallService:Use(player, tokenId)
    if self._config.enabled == false then
        return { ok = false, reason = "disabled" }
    end
    if tokenId ~= self:_tokenId() then
        return { ok = false, reason = "unknown_token" }
    end
    if self:_count(player) <= 0 then
        return { ok = false, reason = "none_left" }
    end
    local principalName = FutureCallLogic.principalName(player.Name, self._config)
    if self._npcPrincipalService:IsActive(principalName) then
        return { ok = false, reason = "already_active" }
    end

    local ok, info = self._npcPrincipalService:Summon(player, "future_self", {
        definition = self._config.principal,
        duration = tonumber(self._config.token and self._config.token.duration) or 120,
    })
    if not ok then
        return { ok = false, reason = tostring(info) }
    end

    local removed, err =
        self._inventoryService:RemoveItem(player, "consumables", self:_tokenId(), 1)
    if not removed then
        self._npcPrincipalService:Despawn(principalName)
        return { ok = false, reason = err or "consume_failed" }
    end
    self:_pushHotbar(player)
    fireGameEvent(player, "future_call_used", {
        name = "🔮 Your future squad answered the call!",
        seconds = tonumber(self._config.token and self._config.token.duration) or 120,
    })
    return {
        ok = true,
        type = "token",
        target = tokenId,
        remaining = self:_count(player),
        summon = info,
    }
end

return FutureCallService
