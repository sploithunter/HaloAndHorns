-- DisplayPreferences.lua
--
-- Client-side utility for reading and updating display preferences.
-- Reads from replicated Player/Settings/DisplayPreferences folders created by SettingsService.
-- Sends preference updates to server via Signals for persistence in ProfileStore.
--
-- USAGE:
-- - DisplayPreferences.GetDisplayMethod("inventory") -> "images" | "viewports"
-- - DisplayPreferences.SetDisplayMethod("inventory", "viewports")
-- - DisplayPreferences.GetControllableContexts() -> {"inventory", "egg_preview"}
--
-- This utility handles the config fallback logic and communicates with the server-side
-- SettingsService for persistent storage without requiring direct DataService access.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locations = require(ReplicatedStorage.Shared.Locations)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local player = Players.LocalPlayer

local DisplayPreferences = {}

-- Get display preference for a context (inventory, egg_preview, etc.)
function DisplayPreferences.GetDisplayMethod(context)
    -- First try to read from replicated player folders
    local settingsFolder = player:FindFirstChild("Settings")
    if settingsFolder then
        local displayPrefFolder = settingsFolder:FindFirstChild("DisplayPreferences")
        if displayPrefFolder then
            local contextValue = displayPrefFolder:FindFirstChild(context)
            if contextValue and contextValue.Value ~= "" then
                return contextValue.Value
            end
        end
    end

    -- Fallback to config defaults
    local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
    local petsConfig = ConfigLoader:LoadConfig("pets")

    if petsConfig and petsConfig.ui_display and petsConfig.ui_display[context] then
        local contextConfig = petsConfig.ui_display[context]

        if contextConfig == "images" or contextConfig == "viewports" then
            return contextConfig
        elseif contextConfig == "user" then
            -- User choice - check defaults
            local userPrefs = petsConfig.ui_display.user_preferences
            if userPrefs and userPrefs.defaults and userPrefs.defaults[context] then
                return userPrefs.defaults[context]
            end
        end
    end

    -- Final fallback
    return "images"
end

-- Set display preference (sends to server via Signal)
function DisplayPreferences.SetDisplayMethod(context, method)
    print("📤 Sending display preference to server:", context, "=", method)

    -- Send to server via Signal
    Signals.SaveDisplayPreferences:FireServer({
        [context] = method,
    })
end

-- Get all user-controllable contexts from config
function DisplayPreferences.GetControllableContexts()
    local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
    local petsConfig = ConfigLoader:LoadConfig("pets")

    local controllable = {}

    if petsConfig and petsConfig.ui_display then
        for context, setting in pairs(petsConfig.ui_display) do
            if context ~= "user_preferences" and setting == "user" then
                -- Check if user control is allowed
                local userPrefs = petsConfig.ui_display.user_preferences
                if
                    userPrefs
                    and userPrefs.allow_user_control
                    and userPrefs.allow_user_control[context]
                then
                    table.insert(controllable, context)
                end
            end
        end
    end

    return controllable
end

return DisplayPreferences
