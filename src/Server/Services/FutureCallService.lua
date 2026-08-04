--[[
    FutureCallService — Future Call consumable grants and activation.

    Grants:
      • five/four/three/two/one tokens when ClaimedLevel reaches 5/6/7/8/9;
      • existing profiles reconcile every missing milestone through named markers;
      • quest/admin rewards share a public non-milestone grant path;
      • the token auto-binds into the first free top-row slot, left to right.

    Activation:
      • spends one token only after the NPC principal successfully spawns;
      • manifests a future self five levels above the caller, capped at the game level cap;
      • always uses the same config-authored four-pet squad for 120 seconds;
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
    self._progressionConfig = self._configLoader:LoadConfig("player_progression")
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
    if reason == "progression" then
        name = ("🔮 FUTURE CALL TOKENS!\nYou received %d summon token%s."):format(
            count,
            count == 1 and "" or "s"
        )
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

-- Canonical non-milestone grant path. Quest rewards and admin testing use the same inventory,
-- auto-bind, hotbar refresh, persistence, and banner behavior as progression entitlements without
-- consuming any of the Level 5–9 milestone markers.
function FutureCallService:GrantTokens(player, count, reason)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then
        return { ok = false, reason = "invalid_count" }
    end
    count = math.clamp(count, 1, 99)
    local ok, err = self:_addTokens(player, count)
    if not ok then
        return { ok = false, reason = err }
    end
    self._dataService:RequestSave(player, "future_call_grant", { critical = true })
    self:_announceGrant(player, count, reason or "reward")
    return { ok = true, granted = count, count = self:_count(player) }
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
    local pending = FutureCallLogic.pendingGrants(data.GameData, claimed, self._config)
    if #pending.grants == 0 then
        return { ok = true, granted = 0, reconciled = false }
    end

    -- Mark every due milestone before inventory mutation: AddItem saves the whole shared
    -- profile. If the add fails, restore each prior marker value before any successful save
    -- can make the markers durable.
    FutureCallLogic.markPending(data.GameData, pending)
    local result = self:GrantTokens(player, pending.total, "progression")
    if not result.ok then
        FutureCallLogic.restorePending(data.GameData, pending)
        self:_log("Warn", "Future Call entitlement grant failed", {
            player = player.Name,
            reason = tostring(result.reason),
        })
        return { ok = false, reason = result.reason }
    end

    self:_log("Info", "Future Call entitlement granted", {
        player = player.Name,
        claimedLevel = claimed,
        count = pending.total,
        milestones = #pending.grants,
    })
    return {
        ok = true,
        granted = pending.total,
        milestones = #pending.grants,
        reconciled = true,
    }
end

-- Admin testing uses the real inventory + auto-bind + banner path, but deliberately
-- does not stamp the Level-5 marker. A low-level test account still earns its grant.
function FutureCallService:AdminGrant(player, count)
    count = math.clamp(math.floor(tonumber(count) or 3), 1, 20)
    return self:GrantTokens(player, count, "admin")
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

    local currentLevel = self._progressionService:GetEarnedLevel(player)
    local summonLevel =
        FutureCallLogic.summonLevel(currentLevel, self._config, self._progressionConfig)
    local definition = table.clone(self._config.principal)
    definition.level = summonLevel

    local ok, info = self._npcPrincipalService:Summon(player, "future_self", {
        definition = definition,
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
        level = summonLevel,
    })
    if type(info) == "table" then
        info.level = summonLevel
    end
    return {
        ok = true,
        type = "token",
        target = tokenId,
        remaining = self:_count(player),
        summon = info,
    }
end

return FutureCallService
