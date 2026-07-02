-- AdminChecker - Client-side admin authorization utility
-- Reads from the same config as server-side AdminService for single source of truth

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Locations = require(ReplicatedStorage.Shared.Locations)

local AdminChecker = {}

-- Cache the admin config to avoid repeated loading
local adminConfig = nil
local configLoaded = false

-- Load admin configuration (same as server-side AdminService)
local function loadAdminConfig()
    if configLoaded then
        return adminConfig
    end

    local success, result = pcall(function()
        local ConfigLoader = require(Locations.ConfigLoader)
        return ConfigLoader:LoadConfig("admins")
    end)

    if success and result then
        adminConfig = result
        configLoaded = true
        -- quiet: config loaded
    else
        -- Do not permanently cache failures; Configs can arrive after early client UI boot.
        adminConfig = {
            authorizedUsers = {},
            security = {
                allowStudioAccess = RunService:IsStudio(),
            },
        }
        configLoaded = false
        -- quiet: error suppressed in console
    end

    return adminConfig
end

-- Check if the current player is authorized as an admin
function AdminChecker.IsCurrentPlayerAdmin()
    local config = loadAdminConfig()
    local player = Players.LocalPlayer

    if not player or not config then
        return false
    end

    local serverValue = player:GetAttribute("IsAdmin")
    if serverValue ~= nil then
        return serverValue == true
    end

    if RunService:IsStudio() then
        return true
    end

    local userId = player.UserId

    -- quiet: status check

    -- Check if user is in authorized list
    for _, authorizedUserId in ipairs(config.authorizedUsers) do
        if userId == authorizedUserId then
            return true
        end
    end

    return false
end

-- Check if a specific User ID is authorized (for future use)
function AdminChecker.IsUserIdAdmin(userId)
    local config = loadAdminConfig()

    if not config then
        return false
    end

    for _, authorizedUserId in ipairs(config.authorizedUsers) do
        if userId == authorizedUserId then
            return true
        end
    end

    return false
end

-- Get the current admin status with details (useful for debugging)
function AdminChecker.GetAdminStatus()
    local config = loadAdminConfig()
    local player = Players.LocalPlayer

    return {
        isAdmin = AdminChecker.IsCurrentPlayerAdmin(),
        userId = player and player.UserId or nil,
        userName = player and player.Name or nil,
        configLoaded = configLoaded,
        authorizedUserCount = config and #config.authorizedUsers or 0,
    }
end

return AdminChecker
