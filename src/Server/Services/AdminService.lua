-- AdminService
-- Handles admin authorization and security
-- CRITICAL: This service must remain SERVER-SIDE ONLY to prevent client injection

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AdminService = {}
AdminService.__index = AdminService

function AdminService.new()
    local self = setmetatable({}, AdminService)
    self._logger = nil
    self._configLoader = nil
    self._adminConfig = nil

    return self
end

function AdminService:Init()
    -- Get dependencies
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader

    -- Load admin configuration
    local success, adminConfig = pcall(function()
        return self._configLoader:LoadConfig("admins")
    end)

    if success and adminConfig then
        self._adminConfig = adminConfig
        self._logger:Info("AdminService initialized", {
            authorizedUserCount = #adminConfig.authorizedUsers,
            securityEnabled = adminConfig.security.logAllAdminActions,
        })
    else
        self._logger:Error("Failed to load admin configuration", { error = adminConfig })
        -- Fail safe - no admins authorized if config fails
        self._adminConfig = {
            authorizedUsers = {},
            permissions = {},
            security = {
                logAllAdminActions = true,
                requireStudioForSensitiveOps = true,
                allowStudioAccess = false,
            },
        }
    end

    Players.PlayerAdded:Connect(function(player)
        self:_syncPlayerAdminAttributes(player)
    end)
end

function AdminService:Start()
    for _, player in ipairs(Players:GetPlayers()) do
        self:_syncPlayerAdminAttributes(player)
    end
end

function AdminService:_syncPlayerAdminAttributes(player)
    if not player then
        return
    end

    local isAdmin = self:IsAuthorized(player)
    player:SetAttribute("IsAdmin", isAdmin)

    if self._logger then
        self._logger:Info("Admin attributes synced", {
            player = player.Name,
            userId = player.UserId,
            isAdmin = isAdmin,
        })
    end
end

-- Check if a player is authorized as an admin
function AdminService:IsAuthorized(player)
    if not player or not self._adminConfig then
        return false
    end

    if
        RunService:IsStudio()
        and self._adminConfig.security
        and self._adminConfig.security.allowStudioAccess == true
    then
        return true
    end

    local userId = player.UserId

    -- Check if user is in authorized list
    for _, authorizedUserId in ipairs(self._adminConfig.authorizedUsers) do
        if userId == authorizedUserId then
            return true
        end
    end

    return false
end

-- Check if an admin has a specific permission
function AdminService:HasPermission(player, permission)
    if not self:IsAuthorized(player) then
        return false
    end

    if not self._adminConfig.permissions then
        return false
    end

    return self._adminConfig.permissions[permission] == true
end

-- Validate an admin action request (supports both self and target player actions)
function AdminService:ValidateAdminAction(player, action, data, source)
    -- Source can be "client" or "server"
    source = source or "unknown"

    -- Determine if this is a multi-player action
    local targetPlayerId = data and data.targetPlayerId
    local isMultiPlayerAction = targetPlayerId ~= nil and targetPlayerId ~= player.UserId
    local targetPlayer = nil

    -- If targeting another player, validate target exists
    if isMultiPlayerAction then
        targetPlayer = self:GetPlayerByUserId(targetPlayerId)
        if not targetPlayer then
            self._logger:Warn("🚨 ADMIN ACTION BLOCKED - INVALID TARGET", {
                admin = player.Name,
                adminId = player.UserId,
                action = action,
                targetUserId = targetPlayerId,
                reason = "Target player not found",
            })
            return false, "Target player not found"
        end
    end

    -- Log the admin action attempt
    if self._adminConfig.security.logAllAdminActions then
        self._logger:Info("🛡️ ADMIN ACTION ATTEMPT", {
            admin = player.Name,
            adminId = player.UserId,
            action = action,
            targetPlayer = targetPlayer and targetPlayer.Name or "self",
            targetUserId = targetPlayerId or player.UserId,
            isMultiPlayer = isMultiPlayerAction,
            data = data,
            source = source,
            timestamp = os.time(),
        })
    end

    -- Check if player is authorized
    if not self:IsAuthorized(player) then
        self._logger:Warn("🚨 UNAUTHORIZED ADMIN ACTION BLOCKED", {
            admin = player.Name,
            adminId = player.UserId,
            action = action,
            reason = "Not authorized as admin",
        })
        return false, "Not authorized"
    end

    -- Determine required permission based on target
    local requiredPermission = action
    if isMultiPlayerAction then
        -- Check if there's a specific "Others" permission for this action
        local othersPermission = action .. "Others"
        if self._adminConfig.permissions[othersPermission] ~= nil then
            requiredPermission = othersPermission
        end
    end

    -- Check specific permission
    if not self:HasPermission(player, requiredPermission) then
        self._logger:Warn("🚨 ADMIN ACTION BLOCKED - INSUFFICIENT PERMISSION", {
            admin = player.Name,
            adminId = player.UserId,
            action = action,
            requiredPermission = requiredPermission,
            isMultiPlayer = isMultiPlayerAction,
            reason = "Missing permission: " .. tostring(requiredPermission),
        })
        return false, "Insufficient permissions for target"
    end

    -- Check security restrictions
    if source == "client" and self._adminConfig.security.blockClientRequests then
        self._logger:Warn("🚨 ADMIN ACTION BLOCKED - CLIENT REQUESTS DISABLED", {
            admin = player.Name,
            adminId = player.UserId,
            action = action,
            reason = "Client requests blocked by security policy",
        })
        return false, "Client requests not allowed"
    end

    -- Check Studio requirement for sensitive operations
    local sensitiveOps =
        { "resetData", "setCurrency", "resetDataOthers", "setCurrencyOthers", "kickPlayers" }
    if self._adminConfig.security.requireStudioForSensitiveOps then
        for _, sensitiveOp in ipairs(sensitiveOps) do
            if
                (action == sensitiveOp or requiredPermission == sensitiveOp)
                and not RunService:IsStudio()
            then
                self._logger:Warn("🚨 SENSITIVE ADMIN ACTION BLOCKED - NOT IN STUDIO", {
                    admin = player.Name,
                    adminId = player.UserId,
                    action = action,
                    requiredPermission = requiredPermission,
                    reason = "Sensitive operation requires Studio environment",
                })
                return false, "Sensitive operations require Studio"
            end
        end
    end

    -- Action is authorized
    self._logger:Info("✅ ADMIN ACTION AUTHORIZED", {
        admin = player.Name,
        adminId = player.UserId,
        action = action,
        requiredPermission = requiredPermission,
        targetPlayer = targetPlayer and targetPlayer.Name or "self",
        isMultiPlayer = isMultiPlayerAction,
        source = source,
    })

    return true, "Authorized", targetPlayer
end

-- Get a player by their user ID
function AdminService:GetPlayerByUserId(userId)
    if not userId then
        return nil
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == userId then
            return player
        end
    end

    return nil
end

-- Get list of all players for admin UI
function AdminService:GetAllPlayers()
    local playerList = {}

    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(playerList, {
            userId = player.UserId,
            username = player.Name,
            displayName = player.DisplayName,
            isAdmin = self:IsAuthorized(player),
        })
    end

    return playerList
end

-- Get admin status for a player
function AdminService:GetAdminStatus(player)
    return {
        isAuthorized = self:IsAuthorized(player),
        permissions = self._adminConfig.permissions,
        userId = player.UserId,
    }
end

-- Network handler: Get all players for admin UI (renamed to avoid conflict)
function AdminService:GetAllPlayersForAdmin(adminPlayer, data)
    local authorized, reason =
        self:ValidateAdminAction(adminPlayer, "viewDebugInfoOthers", data, "client")
    if not authorized then
        self._logger:Warn("🚨 UNAUTHORIZED GetAllPlayers attempt blocked", {
            admin = adminPlayer.Name,
            reason = reason,
        })
        return
    end

    local players = self:GetAllPlayers()

    -- Return via network bridge if available
    if self._adminBridge then
        self._adminBridge:Fire(adminPlayer, "PlayerListUpdate", {
            players = players,
            timestamp = os.time(),
        })
    end

    return players
end

-- Teleport a player to a specific position
function AdminService:TeleportPlayer(adminPlayer, data)
    local authorized, reason, targetPlayer =
        self:ValidateAdminAction(adminPlayer, "teleportPlayers", data, "client")
    if not authorized then
        self._logger:Warn("🚨 UNAUTHORIZED TeleportPlayer attempt blocked", {
            admin = adminPlayer.Name,
            reason = reason,
            targetUserId = data.targetPlayerId,
        })
        return
    end

    if not targetPlayer then
        self._logger:Error("Target player not found for teleport", {
            admin = adminPlayer.Name,
            targetUserId = data.targetPlayerId,
        })
        return
    end

    -- Teleport the target player
    local character = targetPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local position = data.position
        character.HumanoidRootPart.CFrame = CFrame.new(position.x, position.y, position.z)

        self._logger:Info("✅ Admin: Player teleported", {
            admin = adminPlayer.Name,
            target = targetPlayer.Name,
            position = position,
        })
    else
        self._logger:Error("Cannot teleport player - no character or HumanoidRootPart", {
            admin = adminPlayer.Name,
            target = targetPlayer.Name,
        })
    end
end

-- Kick a player from the game
function AdminService:KickPlayer(adminPlayer, data)
    local authorized, reason, targetPlayer =
        self:ValidateAdminAction(adminPlayer, "kickPlayers", data, "client")
    if not authorized then
        self._logger:Warn("🚨 UNAUTHORIZED KickPlayer attempt blocked", {
            admin = adminPlayer.Name,
            reason = reason,
            targetUserId = data.targetPlayerId,
        })
        return
    end

    if not targetPlayer then
        self._logger:Error("Target player not found for kick", {
            admin = adminPlayer.Name,
            targetUserId = data.targetPlayerId,
        })
        return
    end

    -- Prevent admins from kicking other admins
    if self:IsAuthorized(targetPlayer) then
        self._logger:Warn("🚨 ADMIN KICK BLOCKED - Cannot kick another admin", {
            admin = adminPlayer.Name,
            target = targetPlayer.Name,
        })
        return
    end

    local kickReason = data.reason or "Kicked by admin"

    self._logger:Info("🔨 Admin: Kicking player", {
        admin = adminPlayer.Name,
        target = targetPlayer.Name,
        reason = kickReason,
    })

    -- Kick the player
    targetPlayer:Kick(kickReason)
end

return AdminService
