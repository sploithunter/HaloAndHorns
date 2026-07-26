-- Server-authored, rarity-colored system messages in Roblox's standard chat window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local ChatAnnouncements = {}
local enabled = true
local preferenceResolved = false
local userChanged = false
local pendingPayloads = {}
local MAX_PENDING_PAYLOADS = 20
local loadBusy = false
local loadAttempts = 0
local nextLoadAttemptAt = 0
local loadConnection = nil

local function callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result or envelope.data or envelope
end

local function escapeRichText(text)
    return tostring(text)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&apos;")
end

local function colorFromHex(colorHex)
    local red, green, blue = colorHex:match("^#(%x%x)(%x%x)(%x%x)$")
    if not red then
        return Color3.new(1, 1, 1)
    end
    return Color3.fromRGB(
        tonumber(red, 16) or 255,
        tonumber(green, 16) or 255,
        tonumber(blue, 16) or 255
    )
end

local function displayLegacy(text, colorHex)
    -- This place currently runs LegacyChatService. SetCore can race CoreScripts at join,
    -- so retry briefly instead of losing the first announcement of the session.
    local function attempt(remaining)
        local ok = pcall(StarterGui.SetCore, StarterGui, "ChatMakeSystemMessage", {
            Text = text,
            Color = colorFromHex(colorHex),
            Font = Enum.Font.GothamBold,
            TextSize = 18,
        })
        if ok then
            return
        end
        if remaining > 1 then
            task.defer(attempt, remaining - 1)
        end
    end
    attempt(5)
end

local function display(payload)
    if type(payload) ~= "table" or type(payload.text) ~= "string" then
        return
    end
    local colorHex = type(payload.colorHex) == "string"
            and payload.colorHex:match("^#%x%x%x%x%x%x$")
            and payload.colorHex
        or "#FFFFFF"
    if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
        displayLegacy(payload.text, colorHex)
        return
    end
    local channels = TextChatService:WaitForChild("TextChannels", 5)
    if not channels then
        return
    end
    local channel = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("RBXSystem")
    if not channel or not channel:IsA("TextChannel") then
        return
    end
    local richText = ('<font color="%s"><b>%s</b></font>'):format(
        colorHex,
        escapeRichText(payload.text)
    )
    channel:DisplaySystemMessage(
        richText,
        ("HaloAndHorns:%s:%s"):format(tostring(payload.kind), tostring(payload.scope))
    )
end

local function flushPending()
    local payloads = pendingPayloads
    pendingPayloads = {}
    if not enabled then
        return
    end
    for _, payload in ipairs(payloads) do
        task.spawn(display, payload)
    end
end

local function resolvePreference(value)
    if not userChanged then
        enabled = value ~= false
    end
    preferenceResolved = true
    if loadConnection then
        loadConnection:Disconnect()
        loadConnection = nil
    end
    flushPending()
end

local function requestPreference()
    if preferenceResolved or loadBusy then
        return
    end
    if loadAttempts >= 30 then
        -- Preserve the default-on behavior if settings never become available.
        resolvePreference(true)
        return
    end

    loadBusy = true
    loadAttempts += 1
    task.spawn(function()
        local result = callBus("settings.get")
        loadBusy = false
        if type(result) == "table" and result.ok ~= false then
            resolvePreference(result.displayChatAnnouncements ~= false)
            return
        end

        nextLoadAttemptAt = os.clock() + (loadAttempts <= 5 and 0.5 or 2)
    end)
end

function ChatAnnouncements.isEnabled()
    return enabled
end

function ChatAnnouncements.setEnabled(value)
    userChanged = true
    enabled = value ~= false
    preferenceResolved = true
    flushPending()
    task.spawn(function()
        callBus("settings.set", { displayChatAnnouncements = enabled })
    end)
end

function ChatAnnouncements.start()
    Signals.ChatAnnouncement.OnClientEvent:Connect(function(payload)
        if not preferenceResolved then
            if #pendingPayloads < MAX_PENDING_PAYLOADS then
                table.insert(pendingPayloads, payload)
            end
            return
        end
        if enabled then
            task.spawn(display, payload)
        end
    end)
    loadConnection = RunService.Heartbeat:Connect(function()
        if not preferenceResolved and not loadBusy and os.clock() >= nextLoadAttemptAt then
            requestPreference()
        end
    end)
    requestPreference()
end

return ChatAnnouncements
