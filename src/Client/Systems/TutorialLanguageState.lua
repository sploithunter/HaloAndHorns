-- TutorialLanguageState — persisted Auto (Roblox locale) / English tutorial preference.

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialLocalization = require(ReplicatedStorage.Shared.Game.TutorialLocalization)

local TutorialLanguageState = {}
local player = Players.LocalPlayer
local started = false
local observedLocaleId = "en-us"
local translatorConnection

local function normalizePreference(value)
    return if value == "en" then "en" else "auto"
end

local function callBus(name, args)
    local remote = ReplicatedStorage:WaitForChild("GameAPICommand")
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if ok and type(envelope) == "table" then
        return envelope.result
    end
    return nil
end

local function serviceLocale()
    local robloxLocale = LocalizationService.RobloxLocaleId
    if type(robloxLocale) == "string" and robloxLocale ~= "" then
        return robloxLocale
    end
    local systemLocale = LocalizationService.SystemLocaleId
    if type(systemLocale) == "string" and systemLocale ~= "" then
        return systemLocale
    end
    return "en-us"
end

local function refreshResolved()
    local preference = normalizePreference(player:GetAttribute("TutorialLanguagePreference"))
    player:SetAttribute("TutorialLanguagePreference", preference)
    player:SetAttribute(
        "TutorialLocaleId",
        if preference == "en" then "en-us" else observedLocaleId
    )
end

local function observeTranslator()
    task.spawn(function()
        local ok, translator = pcall(function()
            return LocalizationService:GetTranslatorForPlayerAsync(player)
        end)
        if not ok or not translator then
            return
        end

        local function readTranslatorLocale()
            local localeId = translator.LocaleId
            if type(localeId) == "string" and localeId ~= "" then
                observedLocaleId = localeId
                refreshResolved()
            end
        end
        readTranslatorLocale()
        if translatorConnection then
            translatorConnection:Disconnect()
        end
        translatorConnection =
            translator:GetPropertyChangedSignal("LocaleId"):Connect(readTranslatorLocale)
    end)
end

function TutorialLanguageState.start()
    if started then
        return
    end
    started = true
    observedLocaleId = serviceLocale()
    if player:GetAttribute("TutorialLanguagePreference") == nil then
        player:SetAttribute("TutorialLanguagePreference", "auto")
    end
    player:SetAttribute("TutorialLanguageReady", false)
    refreshResolved()

    player:GetAttributeChangedSignal("TutorialLanguagePreference"):Connect(refreshResolved)
    LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(function()
        observedLocaleId = serviceLocale()
        refreshResolved()
        observeTranslator()
    end)
    observeTranslator()

    task.spawn(function()
        local result = callBus("settings.get")
        if result and result.ok then
            player:SetAttribute(
                "TutorialLanguagePreference",
                normalizePreference(result.tutorialLanguage)
            )
        end
        player:SetAttribute("TutorialLanguageReady", true)
    end)
end

function TutorialLanguageState.getPreference()
    return normalizePreference(player:GetAttribute("TutorialLanguagePreference"))
end

function TutorialLanguageState.getLocaleId()
    return player:GetAttribute("TutorialLocaleId") or "en-us"
end

function TutorialLanguageState.getAutoDisplayName()
    return "Auto (" .. TutorialLocalization.displayName(observedLocaleId) .. ")"
end

function TutorialLanguageState.setPreference(preference)
    preference = normalizePreference(preference)
    player:SetAttribute("TutorialLanguagePreference", preference)
    task.spawn(function()
        callBus("settings.set", { tutorialLanguage = preference })
    end)
end

return TutorialLanguageState
